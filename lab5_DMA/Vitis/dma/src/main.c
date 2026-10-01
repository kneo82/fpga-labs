/*
 * Lab 5: MicroBlaze + frame_rx + AXI DMA + axi4_full_ram
 *
 * Приймання кадру 320x200 (8 біт на піксель) із зовнішнього джерела в
 * пам'ять через DMA. Прийом стартує не після reset, а лише після
 * натискання кнопки.
 *
 * Послідовність важлива:
 *
 *   1. DMA озброюється ПЕРШИМ. Як тільки frame_rx отримає start, дані
 *      підуть незалежно від того, чи готовий хтось їх приймати, і FIFO
 *      переповниться. Зворотний порядок втрачає початок кадру.
 *   2. Тільки потім виставляється start.
 *   3. Очікування завершення DMA.
 *   4. start знімається, щоб наступне натискання дало новий кадр
 *      (frame_rx ловить наростаючий фронт, а не рівень).
 *
 * Збірка з -DSIM_BUILD дає симуляційний образ: кадр зменшено до розміру,
 * заданого параметрами frame_rx у block design, а діагностичний вивід
 * вимкнено -- MDM UART у симуляції не має хоста, який вичитує FIFO, тому
 * xil_printf може заблокуватися назавжди.
 */

#include "xparameters.h"
#include "xaxidma.h"
#include "xgpio.h"
#include "xil_io.h"
#include "xil_printf.h"
#include "xil_assert.h"

/* ------------------------------------------------------------------------
 * Hardware ids - confirm every macro against the BSP's xparameters.h.
 * The GPIO instance names follow the block design.
 * ---------------------------------------------------------------------- */
#define DMA_ID          XPAR_AXI_DMA_0_BASEADDR
#define GPIO_BTN_ID     XPAR_AXI_GPIO_1_BASEADDR          /* external button, input  */
#define GPIO_START_ID   XPAR_START_BASEADDR        /* -> frame_rx.start       */
#define GPIO_DONE_ID    XPAR_AXI_GPIO_0_BASEADDR   /* <- frame_rx.frame_done  */

#define RAM_BASE        0xC0000000u

#define CH_ONLY         1u

/* ------------------------------------------------------------------------
 * Frame geometry. MUST match the FRAME_WIDTH / FRAME_HEIGHT parameters of
 * the frame_rx instance in the block design: the module marks the last word
 * with tlast, and the DMA transfer length has to agree with it. A mismatch
 * either truncates the transfer or leaves the DMA waiting forever.
 * ---------------------------------------------------------------------- */

#define FRAME_WIDTH   320u
#define FRAME_HEIGHT  200u


#define sim_printf(...)    do { } while (0)
#define result_printf(...) xil_printf(__VA_ARGS__)

#define FRAME_PIXELS    (FRAME_WIDTH * FRAME_HEIGHT)
#define FRAME_BYTES     FRAME_PIXELS
#define FRAME_WORDS     (FRAME_PIXELS / 4u)

/* Button is active low (pull-up on the pin, closed to ground when pressed). */
#define BTN_MASK        0x01u

static XAxiDma g_dma;
static XGpio   g_gpioBtn;
static XGpio   g_gpioStart;
static XGpio   g_gpioDone;

/* ------------------------------------------------------------------------
 * Diagnostics
 * ---------------------------------------------------------------------- */

static void AssertHandler(const char8 *file, s32 line)
{
    xil_printf("\r\n*** ASSERT FAILED: %s:%d ***\r\n", file, (int)line);
}

/* ------------------------------------------------------------------------
 * Initialisation
 * ---------------------------------------------------------------------- */

static int InitDma(void)
{
    XAxiDma_Config *cfg;
    int status;

    cfg = XAxiDma_LookupConfig(DMA_ID);
    if (cfg == NULL) {
        sim_printf("dma lookup   ... FAILED\r\n");
        return XST_FAILURE;
    }

    status = XAxiDma_CfgInitialize(&g_dma, cfg);
    if (status != XST_SUCCESS) {
        sim_printf("dma init     ... FAILED (%d)\r\n", status);
        return status;
    }

    if (XAxiDma_HasSg(&g_dma)) {
        sim_printf("dma is in SG mode, simple mode expected\r\n");
        return XST_FAILURE;
    }

    /* Polling only: no interrupt handler is registered in this design. */
    XAxiDma_IntrDisable(&g_dma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DEVICE_TO_DMA);

    sim_printf("dma          ... ok\r\n");
    return XST_SUCCESS;
}

static int InitGpio(void)
{
    int status;

    status = XGpio_Initialize(&g_gpioBtn, GPIO_BTN_ID);
    if (status != XST_SUCCESS) {
        sim_printf("gpio button  ... FAILED (%d)\r\n", status);
        return status;
    }
    XGpio_SetDataDirection(&g_gpioBtn, CH_ONLY, 0xFFFFFFFFu);

    status = XGpio_Initialize(&g_gpioStart, GPIO_START_ID);
    if (status != XST_SUCCESS) {
        sim_printf("gpio start   ... FAILED (%d)\r\n", status);
        return status;
    }
    XGpio_SetDataDirection(&g_gpioStart, CH_ONLY, 0x00000000u);
    XGpio_DiscreteWrite(&g_gpioStart, CH_ONLY, 0x00000000u);

    status = XGpio_Initialize(&g_gpioDone, GPIO_DONE_ID);
    if (status != XST_SUCCESS) {
        sim_printf("gpio done    ... FAILED (%d)\r\n", status);
        return status;
    }
    XGpio_SetDataDirection(&g_gpioDone, CH_ONLY, 0xFFFFFFFFu);

    sim_printf("gpio         ... ok\r\n");
    return XST_SUCCESS;
}

/* ------------------------------------------------------------------------
 * Button
 * ---------------------------------------------------------------------- */

static u32 ButtonPressed(void)
{
    /* Active low, so invert before masking. */
    return (~XGpio_DiscreteRead(&g_gpioBtn, CH_ONLY)) & BTN_MASK;
}

/*
 * Waits for a press edge with a crude software debounce: the level has to
 * read the same way several times in a row before it is believed.
 */
static void WaitForButtonPress(void)
{
    const u32 STABLE = 100u;
    u32 count;

    /* Make sure the button starts released, otherwise a button already held
     * down at reset would fire immediately. */
    count = 0u;
    while (count < STABLE) {
        count = ButtonPressed() ? 0u : (count + 1u);
    }

    count = 0u;
    while (count < STABLE) {
        count = ButtonPressed() ? (count + 1u) : 0u;
    }
}

/* ------------------------------------------------------------------------
 * Frame capture
 * ---------------------------------------------------------------------- */

static int CaptureFrame(void)
{
    int status;

    /* 1. Arm the DMA before anything can be sent. */
    status = XAxiDma_SimpleTransfer(&g_dma, (UINTPTR)RAM_BASE,
                                    FRAME_BYTES, XAXIDMA_DEVICE_TO_DMA);
    if (status != XST_SUCCESS) {
        sim_printf("dma transfer ... FAILED (%d)\r\n", status);
        return status;
    }

    /* 2. Release the capture module. It triggers on the rising edge. */
    XGpio_DiscreteWrite(&g_gpioStart, CH_ONLY, 0x00000001u);

    /* 3. Wait for the DMA to see tlast and finish the write. */
    while (XAxiDma_Busy(&g_dma, XAXIDMA_DEVICE_TO_DMA)) {
        /* polling */
    }

    /* 4. Drop start so the next press captures a fresh frame. */
    XGpio_DiscreteWrite(&g_gpioStart, CH_ONLY, 0x00000000u);

    return XST_SUCCESS;
}

/*
 * Reads back the first and last words. With an incrementing test pattern
 * (pixel value = pixel index & 0xFF) the expected little-endian word is
 * known, which turns the check into a real verification rather than a dump.
 */
static void VerifyFrame(void)
{
    u32 first    = Xil_In32(RAM_BASE);
    u32 last     = Xil_In32(RAM_BASE + (FRAME_WORDS - 1u) * 4u);
    u32 expFirst = 0x03020100u;

    result_printf("frame_done   = %d\r\n",
               (int)(XGpio_DiscreteRead(&g_gpioDone, CH_ONLY) & 1u));
    result_printf("word[0]      = 0x%08X (expected 0x%08X)\r\n",
               (unsigned int)first, (unsigned int)expFirst);
    result_printf("word[%d] = 0x%08X\r\n",
               (int)(FRAME_WORDS - 1u), (unsigned int)last);

    if (first == expFirst) {
        result_printf("PASS: first word matches the test pattern\r\n");
    } else {
        result_printf("FAIL: first word does not match\r\n");
    }
}

/* ------------------------------------------------------------------------
 * Entry point
 * ---------------------------------------------------------------------- */

int main(void)
{
    Xil_AssertSetCallback(AssertHandler);

    sim_printf("\r\n=== frame capture  build %s %s ===\r\n", __DATE__, __TIME__);
    sim_printf("frame %dx%d = %d bytes = %d words into 0x%08X\r\n",
               (int)FRAME_WIDTH, (int)FRAME_HEIGHT,
               (int)FRAME_BYTES, (int)FRAME_WORDS, (unsigned int)RAM_BASE);

    if (InitGpio() != XST_SUCCESS || InitDma() != XST_SUCCESS) {
        sim_printf("init failed, stopping\r\n");
        while (1) {
            /* hold so the failure stays on screen */
        }
    }

    while (1) {
        sim_printf("waiting for button...\r\n");
        WaitForButtonPress();

        sim_printf("capturing...\r\n");
        if (CaptureFrame() == XST_SUCCESS) {
            VerifyFrame();
        }
    }

    return XST_SUCCESS;
}
/*
 * Z7-Lite (XC7Z010) - Lab 1: Zynq PS + AXI GPIO + AXI Timer
 *
 * Running light on four LEDs.
 *   - one lit LED walks the ring LED0 -> LED1 -> LED2 -> LED3 -> LED0
 *   - the step interval is produced by AXI Timer 0, never by a software delay
 *   - the switch picks the direction
 *   - BTN0 faster, BTN1 slower, BTN2 stop/resume, BTN3 reset to defaults
 *
 * Both timers live inside the single axi_timer IP and share one interrupt
 * line into IRQ_F2P:
 *   timer 0  variable period   advances the ring
 *   timer 1  fixed 5 ms tick    samples and debounces the inputs
 *
 * A separate poll timer matters: sampling the buttons from the step
 * interrupt would make them respond once every 5 s at the slowest setting.
 *
 * Block design layout (three AXI GPIO instances, one channel each):
 *   axi_gpio_0   4-bit output   LEDs, active high
 *   axi_gpio_1   4-bit input    buttons, active low
 *   axi_gpio_2   1-bit input    direction switch, active low
 *
 * main() does no work at all - everything happens in interrupt context.
 */

#include "xparameters.h"
#include "xgpio.h"
#include "xtmrctr.h"
#include "xscugic.h"
#include "xil_exception.h"
#include "xil_printf.h"
#include "xil_assert.h"
#include "xinterrupt_wrap.h"

/* ------------------------------------------------------------------------
 * Hardware ids - confirm every macro against the BSP's xparameters.h
 * ---------------------------------------------------------------------- */
#define GPIO_LED_ID     XPAR_AXI_GPIO_0_BASEADDR
#define GPIO_KEY_ID     XPAR_AXI_GPIO_1_BASEADDR
#define GPIO_SW_ID      XPAR_AXI_GPIO_2_BASEADDR
#define TIMER_ID        XPAR_AXI_TIMER_0_BASEADDR

#define CH_ONLY         1u      /* every GPIO instance has a single channel */

#define LED_COUNT       4u
#define KEY_COUNT       4u
#define KEY_MASK        0x0Fu
#define SW_MASK         0x01u

/* Button roles. */
#define KEY_FASTER      0u
#define KEY_SLOWER      1u
#define KEY_TOGGLE      2u
#define KEY_RESET       3u

/* The two timers inside the axi_timer IP. */
#define TMR_STEP        0u
#define TMR_POLL        1u

/* FCLK_CLK0 feeding the AXI fabric. Adjust if the block design differs. */
#define AXI_CLK_HZ      50000000u

/* Poll tick: 5 ms. Four stable samples = 20 ms of debounce. */
#define POLL_PERIOD     (AXI_CLK_HZ / 200u)
#define DEBOUNCE_TICKS  4u

/* Step periods in AXI clock cycles, slowest first. */
static const u32 kStepPeriods[] = {
    AXI_CLK_HZ * 5u,        /* 5.00 s */
    AXI_CLK_HZ * 4u,        /* 4.00 s */
    AXI_CLK_HZ * 3u,        /* 3.00 s */
    AXI_CLK_HZ * 2u,        /* 2.00 s */
    AXI_CLK_HZ,             /* 1.00 s */
    AXI_CLK_HZ / 2u,        /* 0.50 s */
    AXI_CLK_HZ / 4u,        /* 0.25 s */
    AXI_CLK_HZ / 10u        /* 0.10 s */
};
#define SPEED_LEVELS    (sizeof(kStepPeriods) / sizeof(kStepPeriods[0]))

#define SPEED_DEFAULT   4u      /* 1.00 s */

static XGpio   g_gpioLed;
static XGpio   g_gpioKey;
static XGpio   g_gpioSw;
static XTmrCtr g_timer;

/* Shared with the interrupt handlers. */
static volatile u32 g_position   = 0u;
static volatile u32 g_speedIndex = SPEED_DEFAULT;
static volatile u32 g_running    = 1u;

/* Debounce state, touched only from the poll interrupt. */
static u32 g_keyStable[KEY_COUNT];
static u32 g_keyCount[KEY_COUNT];

/* ------------------------------------------------------------------------
 * Diagnostics
 * ---------------------------------------------------------------------- */

static void AssertHandler(const char8 *file, s32 line)
{
    xil_printf("\r\n*** ASSERT FAILED: %s:%d ***\r\n", file, (int)line);
}

/* ------------------------------------------------------------------------
 * Running light
 * ---------------------------------------------------------------------- */

static void ShowPosition(void)
{
    /* LEDs are active high in this wiring, so no inversion is needed. */
    XGpio_DiscreteWrite(&g_gpioLed, CH_ONLY, 1u << g_position);
}

static void ApplySpeed(void)
{
    XTmrCtr_Stop(&g_timer, TMR_STEP);
    XTmrCtr_SetResetValue(&g_timer, TMR_STEP, kStepPeriods[g_speedIndex]);
    XTmrCtr_Reset(&g_timer, TMR_STEP);
    XTmrCtr_Start(&g_timer, TMR_STEP);
}

static void ResetToDefaults(void)
{
    g_position   = 0u;
    g_speedIndex = SPEED_DEFAULT;
    g_running    = 1u;

    ApplySpeed();
    ShowPosition();

    xil_printf("reset: speed=%d dir=switch running=1\r\n", (int)g_speedIndex);
}

/* Called from the step timer interrupt. One move of the lit LED. */
static void AdvanceRunningLight(void)
{
    u32 forward;

    if (!g_running) {
        return;
    }

    /* Switch is active low: open (1) = forward, closed to GND (0) = reverse. */
    forward = (~XGpio_DiscreteRead(&g_gpioSw, CH_ONLY)) & SW_MASK;

    if (forward == 0u) {
        g_position = (g_position + 1u) % LED_COUNT;
    } else {
        g_position = (g_position + LED_COUNT - 1u) % LED_COUNT;
    }

    ShowPosition();
}

/* ------------------------------------------------------------------------
 * Input handling - runs from the 5 ms poll interrupt
 * ---------------------------------------------------------------------- */

static void OnKeyPressed(u32 index)
{
    switch (index) {
    case KEY_FASTER:
        if (g_speedIndex + 1u < SPEED_LEVELS) {
            g_speedIndex++;
            ApplySpeed();
            xil_printf("speed -> %d\r\n", (int)g_speedIndex);
        }
        break;

    case KEY_SLOWER:
        if (g_speedIndex > 0u) {
            g_speedIndex--;
            ApplySpeed();
            xil_printf("speed -> %d\r\n", (int)g_speedIndex);
        }
        break;

    case KEY_TOGGLE:
        g_running = !g_running;
        xil_printf("running -> %d\r\n", (int)g_running);
        break;

    case KEY_RESET:
        ResetToDefaults();
        break;

    default:
        break;
    }
}

/*
 * Sample all four buttons and accept a new level only after it has held
 * steady for DEBOUNCE_TICKS in a row. Acts on the press edge only.
 */
static void PollKeys(void)
{
    u32 raw = (~XGpio_DiscreteRead(&g_gpioKey, CH_ONLY)) & KEY_MASK;

    for (u32 i = 0u; i < KEY_COUNT; i++) {
        u32 level = (raw >> i) & 1u;

        if (level == g_keyStable[i]) {
            g_keyCount[i] = 0u;
            continue;
        }

        g_keyCount[i]++;
        if (g_keyCount[i] < DEBOUNCE_TICKS) {
            continue;
        }

        g_keyCount[i]  = 0u;
        g_keyStable[i] = level;

        if (level != 0u) {
            OnKeyPressed(i);
        }
    }
}

/* ------------------------------------------------------------------------
 * Interrupt handling
 *
 * XTmrCtr_InterruptHandler acks the hardware and calls this callback once
 * per expired timer, passing the timer number.
 * ---------------------------------------------------------------------- */

static void TimerCallback(void *callbackRef, u8 timerNumber)
{
    (void)callbackRef;

    if (timerNumber == TMR_STEP) {
        AdvanceRunningLight();
    } else if (timerNumber == TMR_POLL) {
        PollKeys();
    }
}

/* ------------------------------------------------------------------------
 * Initialisation
 * ---------------------------------------------------------------------- */

static int InitOneGpio(XGpio *instance, UINTPTR id, u32 direction,
                       const char *label)
{
    int status = XGpio_Initialize(instance, id);
    if (status != XST_SUCCESS) {
        xil_printf("%s ... FAILED (%d)\r\n", label, status);
        return status;
    }
    XGpio_SetDataDirection(instance, CH_ONLY, direction);
    xil_printf("%s ... ok\r\n", label);
    return XST_SUCCESS;
}

static int InitGpio(void)
{
    int status;

    status = InitOneGpio(&g_gpioLed, GPIO_LED_ID, 0x00000000u, "axi_gpio_0 (leds)  ");
    if (status != XST_SUCCESS) {
        return status;
    }
    XGpio_DiscreteWrite(&g_gpioLed, CH_ONLY, 0x00000000u);

    status = InitOneGpio(&g_gpioKey, GPIO_KEY_ID, 0xFFFFFFFFu, "axi_gpio_1 (keys)  ");
    if (status != XST_SUCCESS) {
        return status;
    }

    status = InitOneGpio(&g_gpioSw, GPIO_SW_ID, 0xFFFFFFFFu, "axi_gpio_2 (switch)");
    if (status != XST_SUCCESS) {
        return status;
    }

    return XST_SUCCESS;
}

static int InitTimers(void)
{
    int status = XTmrCtr_Initialize(&g_timer, TIMER_ID);
    if (status != XST_SUCCESS) {
        xil_printf("axi_timer_0        ... FAILED (%d)\r\n", status);
        return status;
    }

    XTmrCtr_SetHandler(&g_timer, TimerCallback, NULL);

    /* Step timer: interrupt on expiry, auto reload, counting down. */
    XTmrCtr_SetOptions(&g_timer, TMR_STEP,
                       XTC_INT_MODE_OPTION | XTC_AUTO_RELOAD_OPTION |
                       XTC_DOWN_COUNT_OPTION);
    XTmrCtr_SetResetValue(&g_timer, TMR_STEP, kStepPeriods[g_speedIndex]);

    /* Poll timer: same mode, fixed 5 ms period. */
    XTmrCtr_SetOptions(&g_timer, TMR_POLL,
                       XTC_INT_MODE_OPTION | XTC_AUTO_RELOAD_OPTION |
                       XTC_DOWN_COUNT_OPTION);
    XTmrCtr_SetResetValue(&g_timer, TMR_POLL, POLL_PERIOD);

    xil_printf("axi_timer_0        ... ok\r\n");
    return XST_SUCCESS;
}

/*
 * XSetupInterruptSystem reads the interrupt id and parent straight out of
 * the driver config, so no XPAR_FABRIC_* macro has to be hardcoded here.
 * It also initialises the GIC and enables exceptions.
 */
static int InitInterrupts(void)
{
    xil_printf("IntrId=%d IntrParent=0x%08X\r\n",
           (int)g_timer.Config.IntrId, (unsigned int)g_timer.Config.IntrParent);
    int status = XSetupInterruptSystem(&g_timer,
                                       (void *)XTmrCtr_InterruptHandler,
                                       g_timer.Config.IntrId,
                                       g_timer.Config.IntrParent,
                                       XINTERRUPT_DEFAULT_PRIORITY);
    if (status != XST_SUCCESS) {
        xil_printf("interrupt system   ... FAILED (%d)\r\n", status);
        return status;
    }

    xil_printf("interrupt system   ... ok\r\n");
    return XST_SUCCESS;
}

/* ------------------------------------------------------------------------
 * Entry point
 * ---------------------------------------------------------------------- */

int main(void)
{
    Xil_AssertSetCallback(AssertHandler);

    xil_printf("\r\n=== Z7-Lite running light  build %s %s ===\r\n",
               __DATE__, __TIME__);

    if (InitGpio() != XST_SUCCESS ||
        InitTimers() != XST_SUCCESS ||
        InitInterrupts() != XST_SUCCESS) {
        xil_printf("init failed, stopping\r\n");
        while (1) {
            /* hold so the failure stays on screen */
        }
    }

    /* Seed the debounce state from the current input levels. */
    {
        u32 raw = (~XGpio_DiscreteRead(&g_gpioKey, CH_ONLY)) & KEY_MASK;
        for (u32 i = 0u; i < KEY_COUNT; i++) {
            g_keyStable[i] = (raw >> i) & 1u;
            g_keyCount[i]  = 0u;
        }
    }

    ShowPosition();

    XTmrCtr_Start(&g_timer, TMR_POLL);
    XTmrCtr_Start(&g_timer, TMR_STEP);

    xil_printf("running: BTN0 faster, BTN1 slower, BTN2 stop, BTN3 reset\r\n");

    while (1) {
        /* Everything runs from interrupt context. Nothing to do here. */
    }

    return XST_SUCCESS;
}
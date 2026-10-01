`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 30.09.2026 18:09:59
// Design Name: 
// Module Name: frame_rx
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

// frame_rx.v
//
// Приймач кадру: 8 біт на такт із зовнішнього джерела -> 32-бітний
// AXI4-Stream master для підключення до AXI DMA (S_AXIS_S2MM).
//
// Зовнішнє джерело живе у власному тактовому домені (pix_clk) і не вміє
// зупинятися -- сигналу ready у його бік не передбачено. Тому:
//   * синхронізація доменів виконується асинхронним FIFO;
//   * якщо FIFO переповнився, слово ВІДКИДАЄТЬСЯ, а лічильник втрат
//     зростає. Спотворити потік було б гірше, ніж втратити слово й
//     чесно про це повідомити.
//
// Порядок байтів -- little-endian: перший прийнятий байт потрапляє в
// tdata[7:0]. Це узгоджено з AXI (специфікація little-endian), з тим,
// як DMA пише слово в пам'ять, і з тим, як Xil_In32 читає його назад.
//
// Прийом починається лише за наростаючим фронтом start (від MicroBlaze
// через AXI GPIO). До цього вхідні порти повністю ігноруються.
//
// Розмір кадру параметризовано навмисно: повний кадр 320x200 -- це
// 64 000 тактів pix_clk, що робить behavioral-симуляцію нереальною за
// часом. Testbench інстанціює модуль з маленьким кадром; логіка при
// цьому та сама, змінюються лише числа.

module frame_rx #(
    parameter integer FRAME_WIDTH  = 320,
    parameter integer FRAME_HEIGHT = 200,
    parameter integer FIFO_DEPTH   = 512
) (
    // ---- External frame source, its own clock domain ----
    input  wire        pix_clk,
    input  wire [7:0]  pix_data,
    input  wire        pix_valid,

    // ---- AXI clock domain ----
    input  wire        aclk,
    input  wire        aresetn,

    input  wire        start,          // from AXI GPIO output channel
    output wire        frame_done,     // to AXI GPIO input channel
    output wire [31:0] dropped_words,  // to AXI GPIO input channel

    // ---- AXI4-Stream master ----
    output wire [31:0] m_axis_tdata,
    output wire [3:0]  m_axis_tkeep,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready,
    output wire        m_axis_tlast
);

    // ------------------------------------------------------------------
    // Derived sizes
    // ------------------------------------------------------------------
    localparam integer FRAME_PIXELS = FRAME_WIDTH * FRAME_HEIGHT;
    localparam integer FRAME_WORDS  = FRAME_PIXELS / 4;
    localparam integer WORD_CNT_W   = 24;   // plenty for 16000 words
    localparam integer FIFO_CNT_W   = 10;

    // ------------------------------------------------------------------
    // start / reset crossing into the pixel clock domain
    // ------------------------------------------------------------------
    wire start_sync;
    wire rst_pix;

    xpm_cdc_single #(
        .DEST_SYNC_FF   (4),
        .INIT_SYNC_FF   (0),
        .SIM_ASSERT_CHK (0),
        .SRC_INPUT_REG  (0)
    ) u_start_cdc (
        .dest_out (start_sync),
        .dest_clk (pix_clk),
        .src_clk  (1'b0),
        .src_in   (start)
    );

    xpm_cdc_single #(
        .DEST_SYNC_FF   (4),
        .INIT_SYNC_FF   (0),
        .SIM_ASSERT_CHK (0),
        .SRC_INPUT_REG  (0)
    ) u_rst_cdc (
        .dest_out (rst_pix),
        .dest_clk (pix_clk),
        .src_clk  (1'b0),
        .src_in   (~aresetn)
    );

    // ------------------------------------------------------------------
    // Capture side: byte packing, frame counting, overflow accounting
    // ------------------------------------------------------------------
    reg        start_d    = 1'b0;
    reg        capturing  = 1'b0;
    reg [1:0]  byte_idx   = 2'd0;
    reg [23:0] word_shift = 24'd0;   // holds the first three bytes

    reg [WORD_CNT_W-1:0] word_cnt = {WORD_CNT_W{1'b0}};
    reg [31:0]           drop_cnt = 32'd0;
    reg                  done_pix = 1'b0;

    reg        fifo_wr_en = 1'b0;
    reg [32:0] fifo_din   = 33'd0;   // bit 32 = last word of the frame

    wire fifo_full;
    wire start_rise = start_sync & ~start_d;

    // A word is complete on every fourth accepted byte.
    wire byte_taken = capturing & pix_valid;
    wire word_ready = byte_taken & (byte_idx == 2'd3);
    wire is_last    = (word_cnt == FRAME_WORDS - 1);

    always @(posedge pix_clk) begin
        if (rst_pix) begin
            start_d    <= 1'b0;
            capturing  <= 1'b0;
            byte_idx   <= 2'd0;
            word_shift <= 24'd0;
            word_cnt   <= {WORD_CNT_W{1'b0}};
            drop_cnt   <= 32'd0;
            done_pix   <= 1'b0;
            fifo_wr_en <= 1'b0;
            fifo_din   <= 33'd0;
        end else begin
            start_d    <= start_sync;
            fifo_wr_en <= 1'b0;

            // A rising edge on start arms a fresh frame.
            if (start_rise) begin
                capturing <= 1'b1;
                byte_idx  <= 2'd0;
                word_cnt  <= {WORD_CNT_W{1'b0}};
                drop_cnt  <= 32'd0;
                done_pix  <= 1'b0;
            end else if (byte_taken) begin
                byte_idx <= byte_idx + 2'd1;

                // Little-endian packing: first byte ends up in bits [7:0].
                case (byte_idx)
                    2'd0: word_shift[7:0]   <= pix_data;
                    2'd1: word_shift[15:8]  <= pix_data;
                    2'd2: word_shift[23:16] <= pix_data;
                    default: ;   // fourth byte goes straight to the FIFO
                endcase

                if (word_ready) begin
                    if (fifo_full) begin
                        // The source cannot be stalled, so the only options
                        // are to drop the word or to corrupt the stream.
                        drop_cnt <= drop_cnt + 32'd1;
                    end else begin
                        fifo_wr_en <= 1'b1;
                        fifo_din   <= {is_last, pix_data, word_shift};
                    end

                    word_cnt <= word_cnt + {{(WORD_CNT_W-1){1'b0}}, 1'b1};

                    if (is_last) begin
                        capturing <= 1'b0;
                        done_pix  <= 1'b1;
                    end
                end
            end
        end
    end

    // ------------------------------------------------------------------
    // Asynchronous FIFO
    //
    // Width is 33 bits: the extra bit marks the last word of the frame and
    // travels with the data. Deriving tlast from a counter on the read side
    // would break as soon as a word is dropped.
    // ------------------------------------------------------------------
    wire [32:0] fifo_dout;
    wire        fifo_empty;
    wire        fifo_rd_en;

    xpm_fifo_async #(
        .CDC_SYNC_STAGES       (2),
        .DOUT_RESET_VALUE      ("0"),
        .ECC_MODE              ("no_ecc"),
        .FIFO_MEMORY_TYPE      ("auto"),
        .FIFO_READ_LATENCY     (0),          // required by fwft
        .FIFO_WRITE_DEPTH      (FIFO_DEPTH),
        .FULL_RESET_VALUE      (0),
        .PROG_EMPTY_THRESH     (10),
        .PROG_FULL_THRESH      (10),
        .RD_DATA_COUNT_WIDTH   (FIFO_CNT_W),
        .READ_DATA_WIDTH       (33),
        .READ_MODE             ("fwft"),
        .RELATED_CLOCKS        (0),
        .SIM_ASSERT_CHK        (0),
        .USE_ADV_FEATURES      ("0000"),
        .WAKEUP_TIME           (0),
        .WRITE_DATA_WIDTH      (33),
        .WR_DATA_COUNT_WIDTH   (FIFO_CNT_W)
    ) u_fifo (
        .almost_empty  (),
        .almost_full   (),
        .data_valid    (),
        .dbiterr       (),
        .dout          (fifo_dout),
        .empty         (fifo_empty),
        .full          (fifo_full),
        .overflow      (),
        .prog_empty    (),
        .prog_full     (),
        .rd_data_count (),
        .rd_rst_busy   (),
        .sbiterr       (),
        .underflow     (),
        .wr_ack        (),
        .wr_data_count (),
        .wr_rst_busy   (),
        .din           (fifo_din),
        .injectdbiterr (1'b0),
        .injectsbiterr (1'b0),
        .rd_clk        (aclk),
        .rd_en         (fifo_rd_en),
        .rst           (~aresetn),
        .sleep         (1'b0),
        .wr_clk        (pix_clk),
        .wr_en         (fifo_wr_en)
    );

    // ------------------------------------------------------------------
    // AXI4-Stream master
    //
    // In first-word-fall-through mode the data is already on dout while the
    // FIFO is not empty, so the handshake is a direct mapping.
    // ------------------------------------------------------------------
    assign m_axis_tvalid = ~fifo_empty;
    assign m_axis_tdata  = fifo_dout[31:0];
    assign m_axis_tlast  = fifo_dout[32];
    assign m_axis_tkeep  = 4'hF;
    assign fifo_rd_en    = m_axis_tvalid & m_axis_tready;

    // ------------------------------------------------------------------
    // Status back to the AXI domain
    // ------------------------------------------------------------------
    xpm_cdc_single #(
        .DEST_SYNC_FF   (4),
        .INIT_SYNC_FF   (0),
        .SIM_ASSERT_CHK (0),
        .SRC_INPUT_REG  (1)
    ) u_done_cdc (
        .dest_out (frame_done),
        .dest_clk (aclk),
        .src_clk  (pix_clk),
        .src_in   (done_pix)
    );

    // A plain binary counter crossing clock domains would glitch, so the
    // gray-coded crossing is used instead. It is valid because drop_cnt
    // only ever increments by one.
    xpm_cdc_gray #(
        .DEST_SYNC_FF          (4),
        .INIT_SYNC_FF          (0),
        .REG_OUTPUT            (1),
        .SIM_ASSERT_CHK        (0),
        .SIM_LOSSLESS_GRAY_CHK (0),
        .WIDTH                 (32)
    ) u_drop_cdc (
        .dest_out_bin (dropped_words),
        .dest_clk     (aclk),
        .src_clk      (pix_clk),
        .src_in_bin   (drop_cnt)
    );

endmodule
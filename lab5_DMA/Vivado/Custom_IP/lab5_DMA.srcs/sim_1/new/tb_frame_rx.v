`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 30.09.2026 18:18:37
// Design Name: 
// Module Name: tb_frame_rx
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
// tb_frame_rx.v
//
// Testbench для модуля frame_rx окремо -- без MicroBlaze, DMA і block
// design. Ізольована перевірка найскладнішої частини проєкту: пакування
// байтів, перетин тактових доменів, tlast і облік втрат.
//
// Кадр навмисно маленький (32x8 = 256 пікселів = 64 слова). Логіка та
// сама, що для 320x200, але симуляція триває мілісекунди, а не години.
//
// Тактові частоти різні й некратні -- щоб асинхронний FIFO реально
// працював на перетині доменів, а не випадково збігався по фазі.

`timescale 1ns / 1ps

module tb_frame_rx;

    // ---- Parameters -------------------------------------------------
    localparam integer FRAME_WIDTH  = 32;
    localparam integer FRAME_HEIGHT = 8;
    localparam integer FRAME_PIXELS = FRAME_WIDTH * FRAME_HEIGHT;
    localparam integer FRAME_WORDS  = FRAME_PIXELS / 4;
    localparam integer FIFO_DEPTH   = 16;    // small on purpose: overflow is testable

    localparam real    ACLK_HALF    = 5.0;   // 100 MHz
    localparam real    PIXCLK_HALF  = 17.0;  // ~29.4 MHz, deliberately unrelated

    // ---- Signals ----------------------------------------------------
    reg         aclk      = 1'b0;
    reg         aresetn   = 1'b0;
    reg         pix_clk   = 1'b0;
    reg  [7:0]  pix_data  = 8'd0;
    reg         pix_valid = 1'b0;
    reg         start     = 1'b0;
    reg         tready    = 1'b0;

    wire        frame_done;
    wire [31:0] dropped_words;
    wire [31:0] tdata;
    wire [3:0]  tkeep;
    wire        tvalid;
    wire        tlast;

    // ---- Bookkeeping ------------------------------------------------
    integer received;
    integer errors;
    integer last_seen;
    integer i;

    // Byte fields are declared 8 bits wide on purpose. Masking an integer
    // expression with 8'hFF narrows the value but NOT the width, so
    // concatenating those expressions directly would build a 128-bit
    // vector and the assignment would keep only its lowest word.
    reg [7:0]  b0, b1, b2, b3;
    reg [31:0] expected;

    // ---- DUT --------------------------------------------------------
    frame_rx #(
        .FRAME_WIDTH  (FRAME_WIDTH),
        .FRAME_HEIGHT (FRAME_HEIGHT),
        .FIFO_DEPTH   (FIFO_DEPTH)
    ) dut (
        .pix_clk       (pix_clk),
        .pix_data      (pix_data),
        .pix_valid     (pix_valid),
        .aclk          (aclk),
        .aresetn       (aresetn),
        .start         (start),
        .frame_done    (frame_done),
        .dropped_words (dropped_words),
        .m_axis_tdata  (tdata),
        .m_axis_tkeep  (tkeep),
        .m_axis_tvalid (tvalid),
        .m_axis_tready (tready),
        .m_axis_tlast  (tlast)
    );

    always #(ACLK_HALF)   aclk    = ~aclk;
    always #(PIXCLK_HALF) pix_clk = ~pix_clk;

    // ---- Stream consumer --------------------------------------------
    // Collects words and checks them against the expected pattern.
    // The last word of a frame must carry tlast.

    always @(posedge aclk) begin
        if (aresetn && tvalid && tready) begin
            b0 = (received * 4 + 0) & 8'hFF;
            b1 = (received * 4 + 1) & 8'hFF;
            b2 = (received * 4 + 2) & 8'hFF;
            b3 = (received * 4 + 3) & 8'hFF;
            expected = {b3, b2, b1, b0};

            if (tdata !== expected) begin
                $display("[%0t] FAIL word %0d: got %08h, expected %08h",
                         $time, received, tdata, expected);
                errors = errors + 1;
            end

            if (tlast) begin
                last_seen = received;
            end

            received = received + 1;
        end
    end

    // ---- Tasks ------------------------------------------------------

    // Feeds one byte on pix_clk. gap = idle cycles after the byte,
    // so the source can be made slower than the AXI side.
    task send_byte(input [7:0] value, input integer gap);
        integer g;
        begin
            @(posedge pix_clk);
            pix_data  <= value;
            pix_valid <= 1'b1;
            @(posedge pix_clk);
            pix_valid <= 1'b0;
            for (g = 0; g < gap; g = g + 1) begin
                @(posedge pix_clk);
            end
        end
    endtask

    task send_frame(input integer gap);
        integer p;
        begin
            for (p = 0; p < FRAME_PIXELS; p = p + 1) begin
                send_byte(p[7:0], gap);
            end
        end
    endtask

    // Asserts start and then waits until the capture side is actually
    // armed. start is generated in the aclk domain and crosses into
    // pix_clk through a four-stage synchroniser, so it arrives several
    // pixel clocks later. Feeding data before that loses the first bytes.
    task pulse_start;
        begin
            @(posedge aclk);
            start <= 1'b1;
            repeat (4) @(posedge aclk);
            start <= 1'b0;

            wait (dut.capturing === 1'b1);
            @(posedge pix_clk);
        end
    endtask

    task report(input [8*40-1:0] label, input integer condition);
        begin
            if (condition) begin
                $display("[%0t] PASS %0s", $time, label);
            end else begin
                $display("[%0t] FAIL %0s", $time, label);
                errors = errors + 1;
            end
        end
    endtask

    // ---- Scenario ---------------------------------------------------
    initial begin
        $display("=== frame_rx: %0dx%0d = %0d pixels = %0d words ===",
                 FRAME_WIDTH, FRAME_HEIGHT, FRAME_PIXELS, FRAME_WORDS);

        received  = 0;
        errors    = 0;
        last_seen = -1;

        // Reset
        aresetn = 1'b0;
        tready  = 1'b0;
        repeat (20) @(posedge aclk);
        aresetn = 1'b1;
        repeat (20) @(posedge aclk);

        // --- 1. Data before start must be ignored --------------------
        $display("--- data before start ---");
        tready = 1'b1;
        for (i = 0; i < 40; i = i + 1) begin
            send_byte(8'hA5, 0);
        end
        repeat (50) @(posedge aclk);
        report("input ignored before start", received == 0);

        // --- 2. Normal frame, consumer always ready ------------------
        $display("--- frame with a ready consumer ---");
        pulse_start;
        send_frame(0);
        repeat (200) @(posedge aclk);

        report("all words received",  received  == FRAME_WORDS);
        report("tlast on last word",  last_seen == FRAME_WORDS - 1);
        report("nothing dropped",     dropped_words == 0);
        report("frame_done asserted", frame_done === 1'b1);

        // --- 3. Frame with a stalling consumer -----------------------
        // tready is held low long enough for the small FIFO to fill, so
        // the drop path is exercised. Words still arrive in order, only
        // fewer of them, so the expected pattern no longer matches and
        // data checking is disabled for this phase.
        $display("--- frame with a stalling consumer ---");
        tready = 1'b0;

        pulse_start;
        send_frame(0);
        repeat (100) @(posedge aclk);

        report("words dropped while stalled", dropped_words > 0);

        received = FRAME_WORDS;   // stop the data comparison
        tready   = 1'b1;
        repeat (400) @(posedge aclk);

        $display("[%0t] after drain: dropped %0d of %0d words",
                 $time, dropped_words, FRAME_WORDS);

        // --- Summary -------------------------------------------------
        if (errors == 0) begin
            $display("=== ALL CHECKS PASSED ===");
        end else begin
            $display("=== %0d CHECK(S) FAILED ===", errors);
        end
        $finish;
    end

    // ---- Timeout guard ----------------------------------------------
    initial begin
        #2_000_000;
        $display("*** TIMEOUT ***");
        $finish;
    end

endmodule
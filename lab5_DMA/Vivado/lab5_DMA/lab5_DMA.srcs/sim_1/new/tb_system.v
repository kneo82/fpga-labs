`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01.10.2026 16:30:12
// Design Name: 
// Module Name: tb_system
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

module tb_system;
 
    // ---- Frame geometry (must match the frame_rx IP parameters) ------
    localparam integer FRAME_WIDTH  = 320;
    localparam integer FRAME_HEIGHT = 200;
    localparam integer FRAME_PIXELS = FRAME_WIDTH * FRAME_HEIGHT;
    localparam integer FRAME_WORDS  = FRAME_PIXELS / 4;
 
    localparam real    ACLK_HALF    = 10.0;  // 50 MHz system clock
    localparam real    PIXCLK_HALF  = 17.0;  // ~29.4 MHz, deliberately unrelated
 
    // Debounce margins, see the header note.
    localparam integer BOOT_NS      = 600_000;
    localparam integer DEBOUNCE_NS  = 600_000;
    localparam integer DRAIN_NS     = 1_000_000;
 
    // ---- Signals -----------------------------------------------------
    reg        clk_50m    = 1'b0;
    reg        reset_n    = 1'b0;
    reg        pix_clk    = 1'b0;
    reg  [7:0] pix_data   = 8'd0;
    reg        pix_valid  = 1'b0;
    reg  [0:0] btn        = 1'b1;    // active low, released
 
    // ---- DUT ---------------------------------------------------------
    // Port names come from Make External in the block design. Verify them
    // against the generated wrapper if elaboration complains.
    design_1_wrapper dut (
        .clk_50m    (clk_50m),
        .reset_n    (reset_n),
        .pix_clk_0  (pix_clk),
        .pix_data_0 (pix_data),
        .pix_valid_0(pix_valid),
        .btn_tri_i  (btn)
    );
 
    always #(ACLK_HALF)   clk_50m = ~clk_50m;
    always #(PIXCLK_HALF) pix_clk = ~pix_clk;
 
    // ---- Frame source ------------------------------------------------
    // One byte per pix_clk with pix_valid held high: the source free-runs
    // at full rate, which is the worst case for the FIFO. Pixel value is
    // the pixel index, so with little-endian packing word N is known in
    // advance and the firmware can verify it.
 
    task send_frame;
        integer p;
        begin
            $display("[%0t] sending %0d pixels", $time, FRAME_PIXELS);
            @(posedge pix_clk);
            pix_valid <= 1'b1;
            for (p = 0; p < FRAME_PIXELS; p = p + 1) begin
                pix_data <= p[7:0];
                @(posedge pix_clk);
            end
            pix_valid <= 1'b0;
            $display("[%0t] frame sent", $time);
        end
    endtask
 
    // ---- Scenario ----------------------------------------------------
    initial begin
        $display("=== system simulation: %0dx%0d = %0d pixels = %0d words ===",
                 FRAME_WIDTH, FRAME_HEIGHT, FRAME_PIXELS, FRAME_WORDS);
 
        reset_n = 1'b0;
        repeat (50) @(posedge clk_50m);
        reset_n = 1'b1;
        $display("[%0t] reset released", $time);
 
        // The firmware boots, initialises the DMA and the GPIOs, then enters
        // the polling loop. Its debounce first requires a stable RELEASED
        // level, so the button has to stay up well past that point --
        // pressing it too early hangs the first loop forever.
        #BOOT_NS;
 
        $display("[%0t] button pressed", $time);
        btn = 1'b0;
 
        // The pressed-level debounce needs another hundred reads, after
        // which the firmware arms the DMA and raises start.
        #DEBOUNCE_NS;
 
        send_frame;
 
        // Let the DMA drain the FIFO and write the final burst, then let the
        // firmware read the memory back and report.
        #DRAIN_NS;
 
        btn = 1'b1;
 
        $display("=== simulation finished ===");
        $finish;
    end
 
    // ---- Timeout guard -----------------------------------------------
    // The frame data alone takes about 2.2 ms, so the limit is generous.
    initial begin
        #20_000_000;
        $display("*** TIMEOUT: nothing completed within 20 ms ***");
        $finish;
    end
 
endmodule
// tb_alu.v
// Testbench for alu.v: task + self-checking (===) + $display format
// specifiers + a demonstration of the X and Z states.
//
// IMPORTANT: alu.v has REGISTERED inputs AND a registered output -> the
// result appears TWO clock cycles after the inputs change. check_alu
// accounts for this explicitly (two @(posedge clk) in a row).
//
// Console run (Vivado XSim), from the folder containing both files:
//     xvlog alu.v tb_alu.v
//     xelab tb_alu -s tb_sim
//     xsim tb_sim -R
// Local quick check (Icarus Verilog, no Vivado needed):
//     iverilog -o sim alu.v tb_alu.v
//     vvp sim

module tb_alu;

    reg        clk;
    reg        rst;
    reg  [3:0] a, b;
    reg  [1:0] op;
    reg        oe;
    wire [3:0] result;

    alu dut (
        .clk(clk), .rst(rst),
        .a(a), .b(b), .op(op),
        .oe(oe), .result(result)
    );

    // ---- Clock generator ----
    initial clk = 0;
    always #5 clk = ~clk;

    // ---- Self-checking task (accounts for the 2-cycle latency) ----
    // Classic Verilog task port style (no string type - we print the
    // actual a/b/op values instead of a text label for the operation).
    task automatic check_alu;
        input [3:0] a_val;
        input [3:0] b_val;
        input [3:0] expected;
        input [1:0] op_val;
        begin
            a = a_val;  b = b_val;  op = op_val;
            @(posedge clk); #1;     // cycle 1: inputs -> a_reg/b_reg/op_reg
            @(posedge clk); #1;     // cycle 2: result_reg <= alu_result
            if (result === expected)
                $display("[%0t ns] PASS: a=%0d b=%0d op=%b -> result=%0d (0x%h, %b)",
                          $time, a_val, b_val, op_val, result, result, result);
            else
                $display("[%0t ns] FAIL: a=%0d b=%0d op=%b -> expected %0d, got %0d (%b)",
                          $time, a_val, b_val, op_val, expected, result, result);
        end
    endtask

    initial begin
        // ---- 1. X-state demo: right at the start, before reset ----
        oe = 1;
        $display("[%0t ns] BEFORE reset: result = %b  <- X state, result_reg has no value yet",
                  $time, result);

        // ---- 2. Reset ----
        rst = 1;  a = 4'd0;  b = 4'd0;  op = 2'd0;
        @(posedge clk); #1;
        rst = 0;
        $display("[%0t ns] AFTER reset: result = %0d", $time, result);

        // ---- 3. Self-checking test of all 4 operations ----
        check_alu(4'd5, 4'd3, 4'd8, 2'b00);
        check_alu(4'd7, 4'd2, 4'd5, 2'b01);
        check_alu(4'd6, 4'd5, 4'd4, 2'b10);
        check_alu(4'd6, 4'd5, 4'd7, 2'b11);
$stop;
        // ---- 4. Z-state demo: disable the output via oe ----
        oe = 0;
        #1;
        $display("[%0t ns] oe=0: result = %b  <- Z state, output disabled", $time, result);
        oe = 1;
        #1;
        $display("[%0t ns] oe=1: result = %b  <- output back to normal", $time, result);

        $display("[%0t ns] Simulation finished", $time);
        $finish;
    end

endmodule

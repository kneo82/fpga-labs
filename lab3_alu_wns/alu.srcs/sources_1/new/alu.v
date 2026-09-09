// alu.v
// ALU with REGISTERED inputs AND a REGISTERED output (2-cycle latency).
// Written in classic Verilog (no logic/always_comb/always_ff/string) to
// avoid any file-type detection issues with command-line tools.

module alu (
    input  wire        clk,
    input  wire        rst,     // asynchronous reset, active high
    input  wire [3:0]  a,
    input  wire [3:0]  b,
    input  wire [1:0]  op,      // 00=+, 01=-, 10=AND, 11=OR
    input  wire        oe,      // output enable: 0 -> output goes to Z
    output wire [3:0]  result
);

    // ---- Stage 1: registered inputs ----
    reg [3:0] a_reg, b_reg;
    reg [1:0] op_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            a_reg  <= 4'd0;
            b_reg  <= 4'd0;
            op_reg <= 2'd0;
        end else begin
            a_reg  <= a;
            b_reg  <= b;
            op_reg <= op;
        end
    end

    // ---- Combinational ALU logic (operates on the registered inputs) ----
    reg [3:0] alu_result;

    always @(*) begin
        case (op_reg)
            2'b00:   alu_result = a_reg + b_reg;
            2'b01:   alu_result = a_reg - b_reg;
            2'b10:   alu_result = a_reg & b_reg;
            2'b11:   alu_result = a_reg | b_reg;
            default: alu_result = 4'd0;
        endcase
    end

    // ---- Stage 2: registered output ----
    reg [3:0] result_reg;

    always @(posedge clk or posedge rst) begin
        if (rst)
            result_reg <= 4'd0;
        else
            result_reg <= alu_result;
    end

    // ---- Tri-state output: oe=0 -> Z (demonstrates the Z state) ----
    assign result = oe ? result_reg : 4'bzzzz;

endmodule

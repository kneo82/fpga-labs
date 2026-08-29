`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 29.08.2026 10:52:14
// Design Name: 
// Module Name: mux2
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


module mux2(
    input   logic   sel,
    input   logic   d0,
    input   logic   d1,
    output  logic   out
    );
    
    always_comb begin
        case (sel)
            1'b0: out = d0;
            1'b1: out = d1;
            default: out = 1'b0;
        endcase
    end
    
endmodule

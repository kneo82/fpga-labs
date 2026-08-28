`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 28.08.2026 18:00:33
// Design Name: 
// Module Name: top
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


module top(
        input   logic       en,
        input   logic [1:0] sel4,
        input   logic [2:0] sel8,
        output  logic [3:0] out4,
        output  logic [7:0] out8
    );
    
    decoder dec4(
        .en(en), 
        .sel(sel4),
        .out(out4)
    );
    
    decoder #(.WIDTH(8)) dec8(
        .en(en), 
        .sel(sel8),
        .out(out8)
    );
    
endmodule

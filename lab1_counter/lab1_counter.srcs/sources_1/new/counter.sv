`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 29.08.2026 11:23:57
// Design Name: 
// Module Name: counter
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


module counter(
        input   logic clk,
        input   logic reset,
        output  logic [3:0] led
    );
    
    always_ff @(posedge clk, posedge reset) begin
        if (reset)  led <= '0;
        else        led <= led + 4'd1;
    end
    
endmodule

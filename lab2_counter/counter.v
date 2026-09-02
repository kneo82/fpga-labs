`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02.09.2026 17:03:54
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
        input   wire          clk,
        input   wire          rst,
        input   wire          load,
        input   wire [3:0]    data_in,
        input   wire          en,
        input   wire          up_down,
        output  reg  [3:0]    count
    );
    
    always @(posedge clk or posedge rst) begin
        if (rst) 
            count <= 4'd0;
        else if (load)
            count <= data_in;
        else if (en)
            count <= up_down ? count + 4'd1 : count - 4'd1;
    end
    
endmodule

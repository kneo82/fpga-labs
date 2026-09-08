`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08.09.2026 19:08:48
// Design Name: 
// Module Name: debounce
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


module debounce #(
    parameter integer COUNT_MAX = 200_000
)(
    input wire clk,
    input wire rst,
    input wire btn_raw,
    output reg btn_clean
    );
    
    localparam integer CNT_W = $clog2(COUNT_MAX + 1);
    
    reg [CNT_W-1:0] counter;
    
    reg btn_ff1;
    reg btn_ff2;
    
    always @(posedge clk or posedge rst) begin 
        if (rst) begin
            btn_ff1 = 1'b0;
            btn_ff2 = 1'b0;
        end
        else begin
            btn_ff1 = btn_raw;
            btn_ff2 = btn_ff1;
        end
    end
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            counter <= {CNT_W{1'b0}};
            btn_clean <= 1'b0; 
        end
        else if (btn_ff2 != btn_clean) begin
            if (counter == COUNT_MAX[CNT_W-1:0]) begin
                btn_clean <= btn_ff2;
                counter <= {CNT_W{1'b0}};
            end
            else begin
                counter <= counter + 1'b1;
            end
        end
        else begin
            counter <= {CNT_W{1'b0}};
        end
    end 
endmodule

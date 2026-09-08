`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08.09.2026 18:57:44
// Design Name: 
// Module Name: lock_top
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


module lock_top(
    input wire          clk,
    input wire          rst,
    input wire [3:0]    digit_raw,
    output wire         unlocked_led
    );
    
    wire [3:0] digit_clean;
    
    debounce d0(.clk(clk), .rst(rst), .btn_raw(digit_raw[0]), .btn_clean(digit_clean[0]));
    debounce d1(.clk(clk), .rst(rst), .btn_raw(digit_raw[1]), .btn_clean(digit_clean[1]));
    debounce d2(.clk(clk), .rst(rst), .btn_raw(digit_raw[2]), .btn_clean(digit_clean[2]));
    debounce d3(.clk(clk), .rst(rst), .btn_raw(digit_raw[3]), .btn_clean(digit_clean[3]));
    
    lock_controller fsm(.clk(clk), .rst(rst), .digit_in(digit_clean), .unlocked_led(unlocked_led));
    
endmodule

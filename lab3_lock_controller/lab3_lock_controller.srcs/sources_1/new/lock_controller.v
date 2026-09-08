`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08.09.2026 18:18:50
// Design Name: 
// Module Name: lock_controller
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


module lock_controller(
    input wire          clk,
    input wire          rst,
    input wire [3:0]    digit_in,
    output reg          unlocked_led
    );
    
    localparam [3:0]    DIGIT1 = 4'd7,
                        DIGIT2 = 4'd1,
                        DIGIT3 = 4'd2;
    
    localparam [1:0]    LOCKED   =  2'd0,
                        WAIT_D2  =  2'd1,
                        WAIT_D3  =  2'd2,
                        UNLOCKED =  2'd3;
    
    reg [1:0] state, next_state;
    
    always @(posedge clk or posedge rst) begin
        if (rst)
            state <= LOCKED;
        else 
            state <= next_state;
    end
    
    always @(*) begin
        next_state = state;
        case (state)
            LOCKED: begin
                if (digit_in == DIGIT1)
                    next_state = WAIT_D2;
                 else
                    next_state = LOCKED;
            end
            
            WAIT_D2: begin
                if (digit_in == DIGIT2)
                    next_state = WAIT_D3;
                 else
                    next_state = LOCKED;
            end
            
            WAIT_D3: begin
                if (digit_in == DIGIT3)
                    next_state = UNLOCKED;
                 else
                    next_state = LOCKED;
            end
            
            UNLOCKED:
                next_state = UNLOCKED;
                
            default:
                next_state = LOCKED;
        endcase
    end
    
    always @(*) begin
        unlocked_led = (state == UNLOCKED);
    end
    
endmodule

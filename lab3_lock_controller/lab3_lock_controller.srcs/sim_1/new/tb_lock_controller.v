
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08.09.2026 19:40:09
// Design Name: 
// Module Name: tb_locl_controller
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

`timescale 1ns / 1ps

module tb_lock_controller;
    reg          clk;
    reg          rst;
    reg [3:0]    digit_in;
    wire         unlocked_led;
    
    lock_controller dut(.clk(clk),
                        .rst(rst),
                        .digit_in(digit_in),
                        .unlocked_led(unlocked_led));
                        
    // ------- Clock generator
    initial clk = 0;
    always #5 clk = ~clk;
    
    // Check Task
    task automatic check_transition;
        input [3:0]      digit;
        input [1:0]      expected;
        input [8*64-1:0] name;
        begin
            digit_in = digit;
            @(posedge clk); #1;
            log_transition(expected, name);
        end
    endtask
    
    task automatic log_transition;
        input [1:0]      expected;
        input [8*64-1:0] name;
        begin
        if (dut.state === expected) 
            $display("PASS: %0s; state = %0d", name, dut.state);
        else 
            $display("FAIL: %0s; expected = %0d, got = %2d", name,  expected, dut.state);
        end
    endtask
    
    task automatic reset_lock_counter;
    begin
        rst             = 1'b1;
        digit_in        = 4'd0;
        
        @(posedge clk); #1;
        rst             = 1'b0;
    end
    endtask
    
     task automatic check_unlocked_led;
     input      expected;
     input [8*64-1:0] name;
        begin
            if (unlocked_led === expected) 
                $display("PASS: %0s; unlocked_led === %0b", name, unlocked_led);
            else
                $display("FAIL: %0s; unlocked_led expected %0b, got %0b", name, expected, unlocked_led);
         end
    endtask
    
    // 
    initial begin
        $display("====== Lock Counter Testbench ======");
        $display("== Reset ==");

        reset_lock_counter();
        
        log_transition(dut.LOCKED, "after reset");
        
        $display("== Check Success Case UNLOCK =="); 
        check_transition(dut.DIGIT1, dut.WAIT_D2, "digit1 correct");
        check_unlocked_led(1'b0, "led is off in WAIT_D2");
        
        check_transition(dut.DIGIT2, dut.WAIT_D3, "digit2 correct");
        check_transition(dut.DIGIT3, dut.UNLOCKED, "digit3 correct");
        
        check_unlocked_led(1'b1, "after correct enter code");

        $display("== Check UNLOCKED is sticky ==");
        check_transition(4'd8, dut.UNLOCKED, "wrong digit does not leave UNLOCKED");
        check_transition(dut.DIGIT1, dut.UNLOCKED, "correct digit1 does not leave UNLOCKED");
            
        $display("== Reset after UNLOCK ==");
        reset_lock_counter();
        log_transition(dut.LOCKED, "reset after UNLOCK");
        
        $display("== Check Case Wrong first Digit =="); 
        check_transition(4'd8, dut.LOCKED, "digit1 wrong");
        check_transition(dut.DIGIT2, dut.LOCKED, "digit2 correct but enter after wrong first");
        check_unlocked_led(1'b0, "after enter wrong code");
        
        $display("== Check Case Wrong second Digit ==");
        reset_lock_counter();
        check_transition(dut.DIGIT1, dut.WAIT_D2, "digit1 correct");
        check_transition(4'd9, dut.LOCKED, "digit2 wrong");
        
        $display("== Check Case Wrong third Digit ==");
        reset_lock_counter();
        check_transition(dut.DIGIT1, dut.WAIT_D2, "digit1 correct");
        check_transition(dut.DIGIT2, dut.WAIT_D3, "digit2 correct");
        check_transition(4'd5, dut.LOCKED, "digit3 wrong");
        
        $display("== Check Case Reset in middle enter ==");
        reset_lock_counter();
        check_transition(dut.DIGIT1, dut.WAIT_D2, "digit1 correct");
        reset_lock_counter();
        log_transition(dut.LOCKED, "reset in middle enter");
        
        $finish;
    end
    
endmodule

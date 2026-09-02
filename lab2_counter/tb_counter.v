`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02.09.2026 17:20:35
// Design Name: 
// Module Name: tb_counter
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

module tb_counter;
    reg          clk;
    reg          rst;
    reg          load;
    reg  [3:0]   data_in;
    reg          en;
    reg          up_down;
    wire [3:0]   count;
    
    counter dut(.clk(clk),
                .rst(rst),
                .load(load),
                .data_in(data_in),
                .en(en),
                .up_down(up_down),
                .count(count));
                
    // ------- Clock generator
    initial clk = 0;
    always #5 clk = ~clk;
    
    // Check Task
    task automatic check_count;
        input [3:0]      expected;
        input string     name;
        begin
        if (count === expected) 
            $display("PASS: %s; count = %2d", name, count);
        else 
            $display("FAIL: %s; count = %2d, expected = %2d", name, count, expected);
        end
    endtask
    
    // 
    initial begin
        $display("====== Counter Testbench ======");
        $display("== Init ==");
        rst     = 1'b0;
        load    = 1'b0;
        en      = 1'b0;
        up_down = 1'b0;
        data_in = 4'd0;
        
        #3;
        
        $display("== Task 3 ==");
        // Reset
        rst = 1'b1; 
        @(posedge clk); #1;
        rst = 1'b0;
        $display("[%0t ps] After reset: count = %0d", $time, count);
        
        // Task 
        load = 1'b1; data_in = 4'd10;
        @(posedge clk); #1;
        load = 1'b0;
        
        check_count(4'd10, "task 3 load 10");
        
        $display("== Task 4 ==");
        en = 1'b1; up_down = 1'b1; 
        
        repeat (3) begin @(posedge clk); #1; end
        
        check_count(4'd13, "task 4 count up 10 -> 13");
        
        repeat (3) begin @(posedge clk); #1; end
        
        check_count(4'd0, "task 4 count up 3 times, wrap up 15 -> 0");
        
        $display("== Task 5 ==");
        en = 1'b0;
        repeat (2) begin @(posedge clk); #1; end
        
        check_count(4'd0, "task 5 hold while en = 0");
        
        $display("== Task 6 ==");
        en = 1'b1; up_down = 1'b0; 
        @(posedge clk); #1;
        
        check_count(4'd15, "task 6 wrap down 0 -> 15");
        
        $display("== Task 7 ==");
        load = 1'b1; data_in = 4'd5; en = 1'b1; up_down = 1'b1;
        @(posedge clk); #1;
        
        check_count(4'd5, "task 7 load wins over en");
        
        $display("== Task Bonus");
        load = 1'b1; data_in = 4'd7;
        @(posedge clk); #1;
        load = 1'b0;
        
        en = 1'b1; up_down = 1'b0; 
        @(posedge clk); #1;
        
        check_count(4'd6, "task Bonus plain count down 7 -> 6");
        
        $finish;
    end
    
endmodule


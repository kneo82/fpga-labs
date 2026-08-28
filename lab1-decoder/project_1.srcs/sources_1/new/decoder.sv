`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 28.08.2026 17:32:52
// Design Name: 
// Module Name: decoder
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


module decoder #(parameter int WIDTH = 4)(
        input   logic                     en,
        input   logic[$clog2(WIDTH)-1:0]  sel,
        output  logic [WIDTH-1:0]         out
    );
    always_comb begin
        out = '0;
        if (en)
            out[sel] = 1'b1;
    end;
        
endmodule

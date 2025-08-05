`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 17.03.2025 11:35:27
// Design Name: 
// Module Name: uart_tx
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

module uart_tx(
    input clk,
    input rst,
    input en,
    input [7:0] data_in,
    output reg data_out
);
    reg [10:0] temp ;
    always @(posedge clk ) begin
            if(rst) begin
                temp =0;
                data_out=1;
            end else if (en) begin
                temp[0] <= 1'b0;              // Start bit
                temp[8:1] <= data_in;         // Data bits
                temp[9] <= ^data_in;          // Parity bit
                temp[10] <= 1'b1;             // Stop bit
            end else  begin
                data_out <= temp[0];
                temp <= {1'b1, temp[10:1]};   // Shift right
            end
    end
endmodule


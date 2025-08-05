`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 17.03.2025 20:08:11
// Design Name: 
// Module Name: uart
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


module uart(
    input clk,            // System clock (e.g., 50 MHz)
    input rst,            // Reset signal
    input en,             // Transmit enable (pulse for 1 clk)
    input [7:0] data_in,  // Byte to transmit
    output       data_out,     // Serial TX output
    output [7:0] data_out_rx,  // Parallel RX output
    output       data_valid    // RX data valid flag
);

     
    // UART transmitter
    uart_tx tx (
        .clk(clk),
        .rst(rst),
        .en(en),
        .data_in(data_in),
        .data_out(data_out)
    );

    // UART receiver
    uart_rx rx (
        .clk(clk),
        .rst(rst),
        .data_in(data_out),
        .data_out_rx(data_out_rx),
        .data_valid(data_valid)
    );

endmodule




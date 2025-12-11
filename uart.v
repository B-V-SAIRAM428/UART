module uart(
    input clk_tx,            // System clock (e.g., 50 MHz)
    input clk_rx,
    input rst,            // Reset signal
    input en,             // Transmit enable (pulse for 1 clk)
    input [7:0] data_in,  // Byte to transmit
    output [7:0] data_out_rx,  // Parallel RX output
    output      data_valid    // RX data valid flag
);
    wire data_out;     
    // UART transmitter
    uart_tx tx (
        .clk_tx(clk_tx),
        .rst(rst),
        .en(en),
        .data_in(data_in),
        .data_out(data_out)
    );

    // UART receiver
    uart_rx rx (
        .clk_rx(clk_rx),
        .rst(rst),
        .data_in(data_out),
        .data_out_rx(data_out_rx),
        .data_valid(data_valid)
    ); 
endmodule




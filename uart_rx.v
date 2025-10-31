`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 17.03.2025 14:09:41
// Design Name: 
// Module Name: uart_rx
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

module uart_rx (
    input clk,
    input rst,
    input data_in,
    output reg [7:0] data_out_rx,
    output reg data_valid
);

    reg [3:0] count = 0;
    reg [10:0] temp_data = 11'b0;
    reg receiving = 0;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            count <= 0;
            temp_data <= 0;
            receiving <= 0;
            data_out_rx <= 0;
            data_valid <= 0;
        end else begin
            if (!receiving && data_in == 0) begin
                // Start bit detected
                receiving <= 1;
                count <= 0;
                data_valid <= 0;
            end else if (receiving) begin
                if (count < 11) begin
                    temp_data <= {data_in,temp_data[10:1]};  // LSB first
                    count <= count + 1;
                end else begin
                    receiving <= 0;
                    count <= 0;
                    // Parity check: XOR of bits [8:1] should match bit 9
                    if ((^temp_data[7:0]) == temp_data[8]) begin
                        data_out_rx <= temp_data[7:0];  // valid 8-bit data
                        data_valid <= 1;
                    end else begin
                        data_out_rx <= 8'dx;  // parity error
                        data_valid <= 0;
                    end
                end
            end
        end
    end

endmodule

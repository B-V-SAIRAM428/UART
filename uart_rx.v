module uart_rx #(frequency = 50_000_000)(
    input clk_rx,
    input rst,
    input data_in,
    output reg [7:0] data_out_rx,
    output reg data_valid
);

    reg [3:0] bit_cnt = 0;
    reg [10:0] temp_data = 11'b0;
    reg receiving = 0;
    localparam integer baud_clk_rx = frequency/9600;
    reg [17:0] baud_cnt;
    always @(posedge clk_rx) begin
        if (rst) begin
            bit_cnt <= 0;
            baud_cnt <= 0;
            temp_data <= 0;
            receiving <= 0;
            data_out_rx <= 0;
            data_valid <= 0;
        end else begin
                if (!receiving && data_in == 0) begin
                    // Start bit detected
                    receiving <= 1;
                    bit_cnt <= 0;
                    data_valid <= 0;
                end else if (receiving) begin
                    if(bit_cnt <11) begin
                        if (baud_cnt == baud_clk_rx-1) begin
                           temp_data <= {data_in, temp_data[10:1]}; // shift right
                           baud_cnt <=0;
                           bit_cnt <= bit_cnt+1;
                        end else
                           baud_cnt <= baud_cnt+1;
                     end else begin
                            receiving <= 0;
                            bit_cnt <= 0;
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

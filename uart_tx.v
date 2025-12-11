module uart_tx#(parameter frequency = 100_000_000)(
    input clk_tx,
    input rst,
    input en,
    input [7:0] data_in,
    output reg data_out
);
    localparam integer baud_clk_tx = frequency/9600;
    reg [10:0] temp =11'b1111_1111_111;
    reg busy;
    reg [17:0] baud_count;
    reg [3:0] bit_cnt;
    always @(posedge clk_tx) begin
            if(rst) begin
                temp <=0;
                bit_cnt <=0;
                busy <= 0;
                data_out <= 1 ;
                baud_count <= 0;
            end else if (en && !busy) begin
                temp[0] <= 1'b0;              // Start bit
                temp[8:1] <= data_in;         // Data bits
                temp[9] <= ^data_in;          // Parity bit
                temp[10] <= 1'b1;             // Stop bit
                busy <= 1;
                baud_count <=0;
            end else if (busy) begin
                if(bit_cnt < 11) begin
                    if(baud_count == baud_clk_tx-1'b1) begin
                        data_out <= temp[0];
                        temp <= {1'b1, temp[10:1]};   // Shift right
                        baud_count <= 0;
                        bit_cnt <= bit_cnt+1;
                    end else 
                        baud_count <=  baud_count +1;
                end else begin
                    busy <= 0;
                    bit_cnt <=0;
                end
            end else 
		         data_out <= 1; 
    end
endmodule


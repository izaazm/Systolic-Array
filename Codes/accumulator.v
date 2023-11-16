`timescale 100ns / 1ns

module accumulator #(
    parameter integer   PE_OUT_WIDTH    = 32,
    parameter integer   INDEX_WIDTH     = 8,
    parameter integer   MODE_SIG_WIDTH  = 2
)(
	input wire clk,
    input wire reset,
    input wire [MODE_SIG_WIDTH      -1:0] acc_mode,
    input wire [INDEX_WIDTH         -1:0] acc_index,
    input wire [8*PE_OUT_WIDTH      -1:0] res_in,
  	output reg [8*8*PE_OUT_WIDTH    -1:0] res_out
);
    reg [PE_OUT_WIDTH   -1:0] data [15:0][7:0];
    
    integer i;
    integer j;
  	
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i=0; i<15; i=i+1) begin
            	for (j=0; j<8; j=j+1) begin
                    data[i][j] <= 0;
                end
            end
          
        end else begin
          	case (acc_mode)
				2'b00: begin // Idle
                end
              	2'b01: begin // Input Mode
                    for(i = 0; i < 8; i = i + 1) begin
                        data[acc_index][i] <= res_in[PE_OUT_WIDTH * i +: PE_OUT_WIDTH];
                    end
              	end
              	2'b10: begin
                    for(i = 0; i < 8; i = i + 1) begin
                        for(j = 0; j < 8; j = j + 1) begin
                            res_out[(j + 8*i)*PE_OUT_WIDTH +: PE_OUT_WIDTH] <= data[i + j][j];
                        end
                    end                	
                end
            endcase
        end
    end
endmodule
`timescale 100ns / 1ns


module activation_buffer #(
    parameter integer DATA_WIDTH = 8,
    parameter integer INDEX_WIDTH = 8,
    parameter integer OP_SIG_WIDTH = 3,
    parameter integer MODE_SIG_WIDTH = 2
)(
    input wire clk,
    input wire reset,
    
    input wire [INDEX_WIDTH     - 1:0] N,
    input wire [INDEX_WIDTH     - 1:0] K,
    input wire [INDEX_WIDTH     - 1:0] index_out,

    input wire [DATA_WIDTH      - 1:0] data_in,
  	output reg [8*DATA_WIDTH    - 1:0] data_out,
  	
    input wire [MODE_SIG_WIDTH  - 1:0] buffer_mode
);

    // Shift register for systolic array dataflow
  	reg [DATA_WIDTH - 1:0] shift_reg [7:0][15:0];
    
    integer i;
  	integer j;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
          for (i=0; i<8; i=i+1) begin
            for (j=0; j<16; j=j+1) begin
                    shift_reg[i][j] <= 0;
                end
            end
          i = 0;
          j = 0;
          
        end else begin
          	case (buffer_mode)
              2'b00: begin // idle, outputting zeros
                data_out[0 +: 8*DATA_WIDTH] <= 0;  
              end
              2'b01: begin // (Input Mode) WS
                $display("%d %d %d", i, j, data_in);
                if((i < K) && (j < N)) begin
                    shift_reg[i][i + j] <= data_in;
                end 

                i = i + 1;
                if(i >= K) begin
                  i = 0;
                  j = j + 1;
                end
              end
              2'b10: begin // (Input Mode) OS 
                if((i < N) && (j < K)) begin
                    shift_reg[i][i + j] <= data_in;
                end
                
                j = j + 1;
                if(j >= K) begin
                  j = 0;
                  i = i + 1;
                end
              end
              2'b11: begin // (Output Mode) Output data with
                // Output the last element in the register
                for (i=0; i<8; i=i+1) begin
                    data_out[DATA_WIDTH * i +: DATA_WIDTH] <= shift_reg[i][index_out];
                end        
              end
            endcase
        end
    end
endmodule

module weight_buffer #(
    parameter integer DATA_WIDTH = 8,
    parameter integer INDEX_WIDTH = 8,
    parameter integer OP_SIG_WIDTH = 3,
    parameter integer MODE_SIG_WIDTH = 2
)(
    input wire clk,
    input wire reset,
    
    input wire [INDEX_WIDTH     - 1:0] N,
    input wire [INDEX_WIDTH     - 1:0] K,
    input wire [INDEX_WIDTH     - 1:0] index_out,
    
    input wire [DATA_WIDTH   - 1:0] data_in,
  	output reg [8*DATA_WIDTH    - 1:0] data_out,
  	
    input wire [MODE_SIG_WIDTH  - 1:0] buffer_mode
);

    // Shift register for systolic array dataflow
  	reg [DATA_WIDTH - 1:0] data [7:0][7:0];
  	reg [DATA_WIDTH - 1:0] shift_reg [15:0][7:0];

    integer i;
  	integer j;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
          for (i=0; i<8; i=i+1) begin
            for (j=0; j<8; j=j+1) begin
                    data[i][j] <= 0;
                end
            end
          for (i=0; i<16; i=i+1) begin
            for (j=0; j<8; j=j+1) begin
                    shift_reg[i][j] <= 0;
                end
            end
          i = 0;
          j = 0;
          
        end else begin
          	case (buffer_mode)
              2'b00: begin // idle, outputting zeros
                data_out[0 +: 8*DATA_WIDTH] <= 0;  
              end
              2'b01: begin // (Input Mode) Process Data In
                if((i < N) && (j < K)) begin
                  data[i][j] <= data_in;
                  shift_reg[i + j][j] <= data_in;
                end
                
                j = j + 1;
                if(j >= K) begin
                  j = 0;
                  i = i + 1;
                end
              end
              2'b10: begin // (Output Mode Shift) Output data with shift 
                for (i=0; i<8; i=i+1) begin
                    data_out[DATA_WIDTH * i +: DATA_WIDTH] <= shift_reg[index_out][i];
                end
              end
              2'b11: begin // (Output Mode) Output data without lag
                for (i=0; i<8; i=i+1) begin
                    data_out[DATA_WIDTH * i +: DATA_WIDTH] <= data[index_out][i];
                end          
              end
            endcase
        end
    end
endmodule
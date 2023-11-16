`timescale 100ns/1ns


module systolic_array #(
    parameter integer   ACT_WIDTH       = 8,
    parameter integer   WGT_WIDTH       = 8, 
    parameter integer   MULT_OUT_WIDTH  = ACT_WIDTH + WGT_WIDTH,
    parameter integer   PE_OUT_WIDTH    = 32,
    parameter integer   OP_SIG_WIDTH    = 3
)(
    input wire clk, 
    input wire reset, 
    input wire  [OP_SIG_WIDTH     -1:0] operation_signal_in,
    input wire  [8*ACT_WIDTH      -1:0] a_in, 
    input wire  [8*WGT_WIDTH      -1:0] w_in, 
    output wire [8*8*PE_OUT_WIDTH -1:0] out
);
  
    wire [ACT_WIDTH       -1:0] a_out[7:0][7:0];
    wire [WGT_WIDTH       -1:0] w_out[7:0][7:0];
    wire [PE_OUT_WIDTH    -1:0] res[7:0][7:0];
    wire [PE_OUT_WIDTH    -1:0] zero;
    assign zero = 0;
    
      
    generate
        genvar i, j;
        for (i = 0; i < 8; i = i + 1) begin : rows
            for (j = 0; j < 8; j = j + 1) begin : cols
                pe #(
                    .ACT_WIDTH(ACT_WIDTH),
                    .WGT_WIDTH(WGT_WIDTH),
                    .MULT_OUT_WIDTH(MULT_OUT_WIDTH),
                    .PE_OUT_WIDTH(PE_OUT_WIDTH),
                    .OP_SIG_WIDTH(OP_SIG_WIDTH)
                ) pe (
                    .clk(clk), 
                    .reset(reset), 
                    .operation_signal_in(operation_signal_in),
                    .a_in((j==0) ? a_in[i*ACT_WIDTH +: ACT_WIDTH] : a_out[i][j-1]),
                    .w_in((i==0) ? w_in[j*WGT_WIDTH +: WGT_WIDTH] : w_out[i-1][j]),
                    .res_in((i==0) ? zero : res[i-1][j]),
                    .a_out(a_out[i][j]),
                    .w_out(w_out[i][j]),
                    .res_out(res[i][j])
                );
                assign out[(j + 8*i)*PE_OUT_WIDTH +: PE_OUT_WIDTH] = res[i][j];
            end
        end
    endgenerate
  
endmodule
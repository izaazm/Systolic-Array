`timescale 100ns/1ns
module mat_mul_system #(
    parameter integer DATA_WIDTH          = 8,
    parameter integer RAM_DATA_WIDTH      = 32,
    parameter integer ADDR_WIDTH          = 12,
    parameter integer INDEX_WIDTH         = 8,
    parameter integer OP_SIG_WIDTH        = 3,
    parameter integer MODE_SIG_WIDTH      = 2,
    parameter integer BRAM_ADDR_WIDTH     = 32,
    parameter integer ACT_WIDTH           = 8,
    parameter integer WGT_WIDTH           = 8, 
    parameter integer MULT_OUT_WIDTH      = ACT_WIDTH + WGT_WIDTH,
    parameter integer PE_OUT_WIDTH        = 32,
    parameter integer OUTPUT_REG          = 0
) (
    /* optional, you can use reset or not */
//    input wire reset,
    /* Below IO is fixed */
    input wire clk,
    
    /*Connection with SP_BRAM*/
    output wire [32-1:0]         addr_sp_bram,
    output wire                  enable_sp_bram,
    input wire [32-1:0]          data_out_sp_bram,  
    output wire [4-1 :0]         w_enable_sp_bram,
    output wire [32-1:0]         data_in_sp_bram,
    /* Connection with A_BRAM */
    output wire [32-1:0]        addr_a_bram,
    output wire                  enable_a_bram,
    input wire [32-1:0]         data_out_a_bram,
    /* Connection with W_BRAM */
    output wire [32-1:0]         addr_w_bram,
    output wire                  enable_w_bram,
    input wire [32-1:0]         data_out_w_bram,
    /* Connection with O_BRAM */
    output wire [32-1:0]         addr_o_bram,
    output wire                  enable_o_bram,
    output wire [4-1 :0]         w_enable_o_bram,
    output wire [32-1:0]         data_in_o_bram
);

    wire [INDEX_WIDTH-1:0] M;
    wire [INDEX_WIDTH-1:0] N;
    wire [INDEX_WIDTH-1:0] K;
    

    wire [MODE_SIG_WIDTH-1:0] a_buffer_mode;
    wire [MODE_SIG_WIDTH-1:0] w_buffer_mode;
    wire [MODE_SIG_WIDTH-1:0] acc_mode;
    wire [INDEX_WIDTH-1:0] acc_index;
    wire [OP_SIG_WIDTH-1:0] operation_signal_processed;

    // Activation Buffer signals
    wire  [ACT_WIDTH-1:0] a_data_in;
    wire  [8*ACT_WIDTH-1:0]  a_data_out;
    wire  [INDEX_WIDTH-1:0]  a_index_out;

    // Weight Buffer signals
    wire  [WGT_WIDTH-1:0] w_data_in;
    wire  [8*WGT_WIDTH-1:0]  w_data_out;
    wire  [INDEX_WIDTH-1:0]  w_index_out;

    // Systolic Array outputs
    wire [8*8*PE_OUT_WIDTH-1:0] sys_res_out;

    // Accumulator outputs
    wire [8*8*PE_OUT_WIDTH-1:0] acc_out;

    // FSM instantiation
    fsm #(
        .DATA_WIDTH(DATA_WIDTH),
        .PE_OUT_WIDTH(PE_OUT_WIDTH),
        .OP_SIG_WIDTH(OP_SIG_WIDTH),
        .MODE_SIG_WIDTH(MODE_SIG_WIDTH),
        .BRAM_ADDR_WIDTH(BRAM_ADDR_WIDTH)
    ) uut_fsm (
        .clk(clk),
//        .reset(reset),
        .addr_sp_bram(addr_sp_bram),
        .enable_sp_bram(enable_sp_bram),
        .data_out_sp_bram(data_out_sp_bram),
        .w_enable_sp_bram(w_enable_sp_bram),
        .data_in_sp_bram(data_in_sp_bram),
        .addr_a_bram(addr_a_bram),
        .enable_a_bram(enable_a_bram),
        .data_out_a_bram(data_out_a_bram),
        .addr_w_bram(addr_w_bram),
        .enable_w_bram(enable_w_bram),
        .data_out_w_bram(data_out_w_bram),
        .addr_o_bram(addr_o_bram),
        .enable_o_bram(enable_o_bram),
        .w_enable_o_bram(w_enable_o_bram),
        .data_in_o_bram(data_in_o_bram),
        .M(M),
        .N(N),
        .K(K),
        .a_data_in(a_data_in),
        .w_data_in(w_data_in),
        .a_buffer_mode(a_buffer_mode),
        .w_buffer_mode(w_buffer_mode),
        .a_index_out(a_index_out),
        .w_index_out(w_index_out),
        .acc_mode(acc_mode),
        .acc_index(acc_index),
        .operation_signal_processed(operation_signal_processed),
        .sys_res_out(sys_res_out),
        .acc_out(acc_out)
    );

    activation_buffer #(
        .DATA_WIDTH(ACT_WIDTH),
        .INDEX_WIDTH(INDEX_WIDTH),
        .OP_SIG_WIDTH(OP_SIG_WIDTH),
        .MODE_SIG_WIDTH(MODE_SIG_WIDTH)
    ) a_buf (
        .clk(clk),
//        .reset(reset),
        .N(N),
        .K(K),
        .index_out(a_index_out),
        .data_in(a_data_in),
        .data_out(a_data_out),
        .buffer_mode(a_buffer_mode)
    );
    
    weight_buffer #(
        .DATA_WIDTH(WGT_WIDTH),
        .INDEX_WIDTH(INDEX_WIDTH),
        .OP_SIG_WIDTH(OP_SIG_WIDTH),
        .MODE_SIG_WIDTH(MODE_SIG_WIDTH)
    ) w_buf (
        .clk(clk),
//        .reset(reset),
        .N(K),
        .K(M),
        .index_out(w_index_out),
        .data_in(w_data_in),
        .data_out(w_data_out),
        .buffer_mode(w_buffer_mode)
    );
  
    systolic_array #(
        .ACT_WIDTH(ACT_WIDTH),
        .WGT_WIDTH(WGT_WIDTH),
        .MULT_OUT_WIDTH(MULT_OUT_WIDTH),
        .PE_OUT_WIDTH(PE_OUT_WIDTH),
        .OP_SIG_WIDTH(OP_SIG_WIDTH)
    ) uut_sys (
        .clk(clk),
//        .reset(reset),
        .operation_signal_in(operation_signal_processed),
        .a_in(a_data_out),
        .w_in(w_data_out),
        .out(sys_res_out)
    );
      
  	accumulator #(
  	    .PE_OUT_WIDTH(PE_OUT_WIDTH),
  	    .INDEX_WIDTH(INDEX_WIDTH),
  	    .MODE_SIG_WIDTH(MODE_SIG_WIDTH)
  	)uut_acc (
  	    .clk(clk),
//        .reset(reset),
        .acc_mode(acc_mode),
        .acc_index(acc_index),
        .res_in(sys_res_out[7*8*PE_OUT_WIDTH +: 8*PE_OUT_WIDTH]),
        .res_out(acc_out)
    );

endmodule
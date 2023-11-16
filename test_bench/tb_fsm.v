`timescale 100ns / 1ns

module fsm_tb #(
    parameter integer DATA_WIDTH          = 8,
    parameter integer RAM_DATA_WIDTH      = 32,
    parameter integer ADDR_WIDTH          = 12,
    parameter integer INDEX_WIDTH         = 8,
    parameter integer OP_SIG_WIDTH        = 3,
    parameter integer MODE_SIG_WIDTH      = 2,
    parameter integer BRAM_SP_ADDR_WIDTH  = 4,
    parameter integer ACT_WIDTH           = 8,
    parameter integer WGT_WIDTH           = 8, 
    parameter integer MULT_OUT_WIDTH      = ACT_WIDTH + WGT_WIDTH,
    parameter integer PE_OUT_WIDTH        = 32,
    parameter integer OUTPUT_REG          = 0
);
  
    reg clk;
    reg reset;


    reg [31:0]sp_addr;
    reg [31:0]sp_data_in;
    reg [3:0]sp_web;
    reg data_loaded;

    wire read_req;
    wire [ADDR_WIDTH-1:0] read_addr;
    wire [RAM_DATA_WIDTH-1:0] read_data;

    wire write_req;
    wire [ADDR_WIDTH-1:0] write_addr;
    wire [RAM_DATA_WIDTH-1:0] write_data;

    wire [INDEX_WIDTH-1:0] M;
    wire [INDEX_WIDTH-1:0] N;
    wire [INDEX_WIDTH-1:0] K;
    

    wire [MODE_SIG_WIDTH-1:0] a_buffer_mode;
    wire [MODE_SIG_WIDTH-1:0] w_buffer_mode;
    wire [MODE_SIG_WIDTH-1:0] acc_mode;
    wire [INDEX_WIDTH-1:0] acc_index;
    wire [OP_SIG_WIDTH-1:0] operation_signal_processed;

    // Activation Buffer signals
    reg  [64*ACT_WIDTH-1:0] a_data_in;
    wire [8*ACT_WIDTH-1:0]  a_data_out;
    wire  [INDEX_WIDTH-1:0]  a_index_out;

    // Weight Buffer signals
    reg  [64*WGT_WIDTH-1:0] w_data_in;
    wire [8*WGT_WIDTH-1:0]  w_data_out;
    wire  [INDEX_WIDTH-1:0]  w_index_out;

    // Systolic Array outputs
    wire [8*8*PE_OUT_WIDTH-1:0] sys_res_out;

    // Accumulator outputs
    wire [8*8*PE_OUT_WIDTH-1:0] acc_out;

    // FSM instantiation
    fsm #(
        .DATA_WIDTH(DATA_WIDTH),
        .INDEX_WIDTH(INDEX_WIDTH),
        .OP_SIG_WIDTH(OP_SIG_WIDTH),
        .MODE_SIG_WIDTH(MODE_SIG_WIDTH),
        .BRAM_SP_ADDR_WIDTH(BRAM_SP_ADDR_WIDTH)
    ) uut_fsm (
        .clk(clk),
        .reset(reset),
        .sp_addr(sp_addr),    
        .sp_data_in(sp_data_in),
        .sp_web(sp_web),
        .data_loaded(data_loaded),
        .read_req(read_req),
        .read_addr(read_addr),
        .read_data(read_data),
        .write_req(write_req),
        .write_addr(write_addr),
        .write_data(write_data),
        .M(M),
        .N(N),
        .K(K),
        .a_buffer_mode(a_buffer_mode),
        .w_buffer_mode(w_buffer_mode),
        .a_index_out(a_index_out),
        .w_index_out(w_index_out),
        .acc_mode(acc_mode),
        .acc_index(acc_index),
        .operation_signal_processed(operation_signal_processed)
    );

    activation_buffer #(
        .DATA_WIDTH(ACT_WIDTH),
        .INDEX_WIDTH(INDEX_WIDTH),
        .OP_SIG_WIDTH(OP_SIG_WIDTH),
        .MODE_SIG_WIDTH(MODE_SIG_WIDTH)
    ) a_buf (
        .clk(clk),
        .reset(reset),
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
        .reset(reset),
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
        .reset(reset),
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
        .reset(reset),
        .acc_mode(acc_mode),
        .acc_index(acc_index),
        .res_in(sys_res_out[7*8*PE_OUT_WIDTH +: 8*PE_OUT_WIDTH]),
        .res_out(acc_out)
    );

    ram #(
        .DATA_WIDTH(RAM_DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .OUTPUT_REG(OUTPUT_REG)
    ) sp_ram (
        .clk(clk),
        .reset(reset),
        .read_req(read_req),
        .read_addr(read_addr),
        .read_data(read_data),
        .write_req(write_req),
        .write_addr(write_addr),
        .write_data(write_data)
    );

    // Clock generation
    always begin
        #0.5 clk = ~clk;
    end
    
    always @(posedge clk or posedge reset) begin
//        $display("a_buf_mode: %d", a_buffer_mode);
//        $display("w_buf_mode: %d", w_buffer_mode);
//        $display("op_signal: %d", operation_signal_processed);
//        $display("a_out: %d %d %d %d %d %d %d %d", a_data_out[0*ACT_WIDTH +: ACT_WIDTH], a_data_out[1*ACT_WIDTH +: ACT_WIDTH], a_data_out[2*ACT_WIDTH +: ACT_WIDTH], a_data_out[3*ACT_WIDTH +: ACT_WIDTH], a_data_out[4*ACT_WIDTH +: ACT_WIDTH], a_data_out[5*ACT_WIDTH +: ACT_WIDTH], a_data_out[6*ACT_WIDTH +: ACT_WIDTH], a_data_out[7*ACT_WIDTH +: ACT_WIDTH]);
//        $display("a_out: %d %d %d %d %d %d %d %d", w_data_out[0*ACT_WIDTH +: ACT_WIDTH], w_data_out[1*ACT_WIDTH +: ACT_WIDTH], w_data_out[2*ACT_WIDTH +: ACT_WIDTH], w_data_out[3*ACT_WIDTH +: ACT_WIDTH], w_data_out[4*ACT_WIDTH +: ACT_WIDTH], w_data_out[5*ACT_WIDTH +: ACT_WIDTH], w_data_out[6*ACT_WIDTH +: ACT_WIDTH], w_data_out[7*ACT_WIDTH +: ACT_WIDTH]);
    end
    
    integer i;

    // FSM Test sequence
    initial begin
        reset = 1;
        clk = 0;
        sp_addr = 0;
        sp_data_in = 0;
        sp_web = 0;
        #10;

        data_loaded = 0;
        
        // Testing OS mode
        $display("Testing OS mode");
        // sp_data_in[0*BRAM_SP_ADDR_WIDTH +: BRAM_SP_ADDR_WIDTH] = 1; // Start signal
        // sp_data_in[1*BRAM_SP_ADDR_WIDTH +: BRAM_SP_ADDR_WIDTH] = 0; // OS mode
        // sp_data_in[2*BRAM_SP_ADDR_WIDTH +: BRAM_SP_ADDR_WIDTH] = 8; // M
        // sp_data_in[3*BRAM_SP_ADDR_WIDTH +: BRAM_SP_ADDR_WIDTH] = 8; // K
        // sp_data_in[4*BRAM_SP_ADDR_WIDTH +: BRAM_SP_ADDR_WIDTH] = 8; // N
        // reset = 0;

        reset = 0;
        sp_web=4'b1111;
        #10 // need to handle #1
        sp_addr=4; 
        sp_data_in=0; //MODES
        #2
        sp_addr=8; 
        sp_data_in=8; //M
        #2
        sp_addr=12; 
        sp_data_in=8; //K
        #2
        sp_addr=16; 
        sp_data_in=8; //N
        #2
        sp_web=4'b0000;

        // Making test data
        for(i=0; i<64; i=i+1) begin
            a_data_in[i*ACT_WIDTH +: ACT_WIDTH] = i + 1;
        end
        for(i=0; i<64; i=i+1) begin
            w_data_in[i*WGT_WIDTH +: WGT_WIDTH] = i + 1;
        end
        data_loaded = 1;
        
        #300; // Some delay to observe FSM behavior

        // Display the result OS
//       for (i = 0; i < 8; i = i + 1) begin
//         $display("Data Out : %d %d %d %d %d %d %d %d", sys_res_out[(0 + 8*i)*PE_OUT_WIDTH +: PE_OUT_WIDTH], sys_res_out[(1 + 8*i)*PE_OUT_WIDTH +: PE_OUT_WIDTH], sys_res_out[(2 + 8*i)*PE_OUT_WIDTH +: PE_OUT_WIDTH], sys_res_out[(3 + 8*i)*PE_OUT_WIDTH +: PE_OUT_WIDTH], sys_res_out[(4 + 8*i)*PE_OUT_WIDTH +: PE_OUT_WIDTH], sys_res_out[(5 + 8*i)*PE_OUT_WIDTH +: PE_OUT_WIDTH], sys_res_out[(6 + 8*i)*PE_OUT_WIDTH +: PE_OUT_WIDTH], sys_res_out[(7 + 8*i)*PE_OUT_WIDTH +: PE_OUT_WIDTH]);
//       end
        
         // Display the result WS
         for (i = 0; i < 8; i = i + 1) begin
             $display("Data Out : %d %d %d %d %d %d %d %d", acc_out[(0 + 8*i)*PE_OUT_WIDTH +: PE_OUT_WIDTH], acc_out[(1 + 8*i)*PE_OUT_WIDTH +: PE_OUT_WIDTH], acc_out[(2 + 8*i)*PE_OUT_WIDTH +: PE_OUT_WIDTH], acc_out[(3 + 8*i)*PE_OUT_WIDTH +: PE_OUT_WIDTH], acc_out[(4 + 8*i)*PE_OUT_WIDTH +: PE_OUT_WIDTH], acc_out[(5 + 8*i)*PE_OUT_WIDTH +: PE_OUT_WIDTH], acc_out[(6 + 8*i)*PE_OUT_WIDTH +: PE_OUT_WIDTH], acc_out[(7 + 8*i)*PE_OUT_WIDTH +: PE_OUT_WIDTH]);
         end

         $finish;
     end
    

endmodule
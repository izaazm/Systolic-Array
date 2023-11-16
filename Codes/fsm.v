`timescale 100ns / 1ns

module fsm #(
    parameter integer DATA_WIDTH        = 8,
    parameter integer PE_OUT_WIDTH      = 32,
    parameter integer BRAM_ADDR_WIDTH   = 32,
    parameter integer INDEX_WIDTH       = 8,
    parameter integer OP_SIG_WIDTH      = 3,
    parameter integer MODE_SIG_WIDTH    = 2
)(
    input wire clk,
    input wire reset,

    output wire [32-1:0]         addr_sp_bram,
    output wire                  enable_sp_bram,
    input wire  [32-1:0]         data_out_sp_bram,  
    output wire [4-1 :0]         w_enable_sp_bram,
    output wire [32-1:0]         data_in_sp_bram,

    output wire [32-1:0]         addr_a_bram,
    output wire                  enable_a_bram,
    input  wire [32-1:0]         data_out_a_bram,

    output wire [32-1:0]         addr_w_bram,
    output wire                  enable_w_bram,
    input  wire [32-1:0]         data_out_w_bram,

    output wire [32-1:0]         addr_o_bram,
    output wire                  enable_o_bram,
    output wire [4-1 :0]         w_enable_o_bram,
    output wire [32-1:0]         data_in_o_bram,

    output wire [INDEX_WIDTH-1:0] M,
    output wire [INDEX_WIDTH-1:0] N,
    output wire [INDEX_WIDTH-1:0] K,

    output wire [DATA_WIDTH      - 1:0] a_data_in,
    output wire [DATA_WIDTH      - 1:0] w_data_in,
    output wire [MODE_SIG_WIDTH  - 1:0] a_buffer_mode,
    output wire [MODE_SIG_WIDTH  - 1:0] w_buffer_mode,
    output wire [INDEX_WIDTH     - 1:0] a_index_out,
    output wire [INDEX_WIDTH     - 1:0] w_index_out,

    output wire [MODE_SIG_WIDTH  - 1:0] acc_mode,
    output wire [INDEX_WIDTH  - 1:0] acc_index,

    output wire [OP_SIG_WIDTH  - 1:0] operation_signal_processed,
    
    input  wire [8*8*PE_OUT_WIDTH - 1:0] sys_res_out,
    input  wire [8*8*PE_OUT_WIDTH - 1:0] acc_out
);
    localparam IDLE = 0, 
    INIT = 1,
    READ_MODE = 2,
    READ_N = 3,
    READ_K = 4,
    READ_M = 5,
    WAIT_A_DATA = 6, 
    WRITE_A_SET = 7, 
    WAIT_W_DATA = 8,
    WRITE_W_SET = 9, 
    PREP_COMPUTE = 10,
    WAIT_W_PE = 11,
    LOAD_W_PE = 12,
    COMPUTE = 13, 
    WRITE_OUTPUT = 14,
    SEND_END_SIGNAL = 15,
    END_STEP = 16;

    reg [7:0] cur_state, next_state, mode;

    localparam COMPUTE_IDLE = 0,
    COMPUTE_WAIT = 1,
    COMPUTE_SYSTOLIC_OS = 2,
    COMPUTE_SYSTOLIC_WS = 3,
    FILL_ACC = 4,
    COMPUTE_EXTRA_OS = 5,
    COMPUTE_EXTRA_WS = 6,
    COMPUTE_DONE = 7;
    
    localparam COMPUTE_STEP_IDLE = 0,
    COMPUTE_STEP_INITIAL = 1,
    COMPUTE_STEP_EXTRA = 2,
    COMPUTE_STEP_FILL = 3,
    COMPUTE_STEP_DONE = 4;    

    reg [32-1:0] addr_sp_bram_reg;
    reg          enable_sp_bram_reg;
    reg [32-1:0] data_out_sp_bram_reg;  
    reg [4-1 :0] w_enable_sp_bram_reg;
    reg [32-1:0] data_in_sp_bram_reg;

    reg [32-1:0] addr_a_bram_reg;
    reg          enable_a_bram_reg;
    reg [32-1:0] data_out_a_bram_reg;

    reg [32-1:0] addr_w_bram_reg;
    reg          enable_w_bram_reg;
    reg [32-1:0] data_out_w_bram_reg;

    reg [32-1:0] addr_o_bram_reg;
    reg          enable_o_bram_reg;
    reg [4-1 :0] w_enable_o_bram_reg;
    reg [32-1:0] data_in_o_bram_reg;
    
    reg [7:0] next_compute_step; // 0 idle, 1 initial, 2 extra, 3 done
    reg [7:0] compute_substate; // FSM substate for computation
    reg [7:0] next_compute_substate;

    reg [7:0] a_buf_counter;
    reg [7:0] w_buf_counter;
    reg [7:0] out_counter;
    reg [7:0] compute_counter; // counter for the loops
    reg signed [7:0] acc_counter; // counter for PE load in WS
    reg signed [7:0] compute_w_pe_counter; // counter for PE load in WS

    localparam RAM_SP_IDLE = 0,
    RAM_SP_WAIT_WRITE = 1,
    RAM_SP_WAIT_READ = 2,
    RAM_SP_WRITE = 3,
    RAM_SP_READ = 4;

    localparam RAM_SP_READ_SIGNAL = 0,
    RAM_SP_READ_M = 1,
    RAM_SP_READ_K = 2,
    RAM_SP_READ_N = 3,
    RAM_SP_DONE = 4;

    reg [INDEX_WIDTH - 1:0] start_signal;
    reg start_signal_latched = 1'b0;
    
    reg [DATA_WIDTH  - 1:0] a_data_in_reg;
    reg [DATA_WIDTH  - 1:0] w_data_in_reg;
    
    reg [INDEX_WIDTH  - 1:0] a_index_out_reg;
    reg [INDEX_WIDTH  - 1:0] w_index_out_reg;
    reg [INDEX_WIDTH  - 1:0] acc_index_reg;

    reg [INDEX_WIDTH-1:0] M_reg;
    reg [INDEX_WIDTH-1:0] N_reg;
    reg [INDEX_WIDTH-1:0] K_reg;

    reg [MODE_SIG_WIDTH-1:0] a_buffer_mode_reg;
    reg [MODE_SIG_WIDTH-1:0] w_buffer_mode_reg;
    reg [MODE_SIG_WIDTH-1:0] acc_mode_reg;

    reg[OP_SIG_WIDTH-1:0] operation_signal_processed_reg;

    reg [1:0] delay_counter;

    integer i;
    integer j;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            enable_sp_bram_reg = 0;
            enable_a_bram_reg = 0;
            enable_w_bram_reg = 0;
            enable_o_bram_reg = 0;
            
            cur_state = IDLE;
            next_state = IDLE;
            compute_substate = COMPUTE_IDLE;
            compute_counter = 5'd0;
            delay_counter = 2'd0;
            next_compute_step = COMPUTE_STEP_IDLE;
            acc_counter = 0;
        end
    end

    always @(negedge clk) begin
        cur_state = next_state;

        case (cur_state)
            IDLE: begin
                enable_sp_bram_reg = 1;

                $display("IDLE %d", data_out_sp_bram);
                addr_sp_bram_reg = 0;
                if (data_out_sp_bram) begin
                    next_state = INIT;
                end
            end
            INIT: begin
                a_buffer_mode_reg = 2'b00;
                w_buffer_mode_reg = 2'b00;
                addr_sp_bram_reg = 4;
                next_state = READ_MODE;
                $display("pass INIT!");
            end
            READ_MODE: begin
                mode = data_out_sp_bram;
                addr_sp_bram_reg = 8;
                next_state = READ_N;
                $display("pass READ_MODE %d", mode);
            end
            READ_N: begin
                N_reg = data_out_sp_bram;
                addr_sp_bram_reg = 12;
                next_state = READ_K;
                $display("pass READ_N %d", N_reg);
            end
            READ_K: begin
                K_reg = data_out_sp_bram;
                addr_sp_bram_reg = 16;
                next_state = READ_M;
                $display("pass READ_K %d", K_reg);
            end
            READ_M: begin
                M_reg = data_out_sp_bram;
                next_state = WAIT_A_DATA;
                enable_sp_bram_reg = 0;
                a_buf_counter = 0;
                $display("pass READ_M %d", M_reg);
            end
            WAIT_A_DATA: begin
                enable_a_bram_reg = 1;
                addr_a_bram_reg = a_buf_counter * 4;
                
                a_buffer_mode_reg = 2'b00;
                next_state = WRITE_A_SET;
                $display("pass A_WAIT!");
            end
            WRITE_A_SET: begin
                if (mode) begin
                    a_buffer_mode_reg = 2'b10; // OS mode
                end else begin
                    a_buffer_mode_reg = 2'b01; // WS mode
                end
                a_data_in_reg = data_out_a_bram;
                
                a_buf_counter = a_buf_counter + 1;
                if (a_buf_counter >= N_reg * K_reg) begin
                    next_state = WAIT_W_DATA;
                    enable_a_bram_reg = 0;
                    w_buf_counter = 0;
                end else begin
                    next_state = WAIT_A_DATA;
                end
                $display("pass WRITE_A_SET! %d", a_data_in_reg);
            end
            WAIT_W_DATA: begin
                enable_w_bram_reg = 1;
                addr_w_bram_reg = w_buf_counter * 4;
                
                w_buffer_mode_reg = 2'b00;
                next_state = WRITE_W_SET;
                $display("pass W_WAIT!");
            end
            WRITE_W_SET: begin
                w_buffer_mode_reg = 2'b01;
                w_data_in_reg = data_out_w_bram;
                
                w_buf_counter = w_buf_counter + 1;
                if (w_buf_counter >= K_reg * M_reg) begin
                    next_state = PREP_COMPUTE;
                    enable_w_bram_reg = 0;
                end else begin
                    next_state = WAIT_W_DATA;
                end
                $display("pass WRITE_W_SET! %d", w_data_in_reg);
            end
            PREP_COMPUTE: begin
                if (mode) begin
                    next_compute_substate = COMPUTE_WAIT;
                    next_compute_step = COMPUTE_STEP_INITIAL;
                    compute_counter = 0;
                    next_state = COMPUTE;
                end else begin
                    compute_w_pe_counter = 7;
                    acc_counter = 0;
                    next_state = WAIT_W_PE;
                end
                $display("pass PREP_COMPUTE!");
            end
            WAIT_W_PE:  begin
                operation_signal_processed_reg = 3'b111;
                w_buffer_mode_reg = 2'b11;
                w_index_out_reg = compute_w_pe_counter;
                compute_w_pe_counter = compute_w_pe_counter - 1;
                next_state = LOAD_W_PE;
            end
            LOAD_W_PE: begin
                // load w to PE
                operation_signal_processed_reg = 3'b001;
                if(compute_w_pe_counter < 0)begin
                    next_compute_substate = COMPUTE_WAIT;
                    next_compute_step = COMPUTE_STEP_INITIAL;
                    compute_counter = 0;
                    next_state = COMPUTE;
                end else begin
                    next_state = WAIT_W_PE;
                end
                $display("pass LOAD_W_PE! %d", w_index_out_reg);
            end
            COMPUTE: begin
                compute_substate = next_compute_substate;
                case (compute_substate)
                
                    COMPUTE_IDLE: begin
                        // idle
                        // NOT_REACHED
                    end
                    
                    COMPUTE_WAIT: begin
                        case(next_compute_step)
                            COMPUTE_STEP_IDLE: begin
                                // idle
                                // NOT_REACHED
                            end
                            COMPUTE_STEP_INITIAL: begin // fetch data from buffer
                                if (mode) begin
                                    a_buffer_mode_reg = 2'b11;
                                    w_buffer_mode_reg = 2'b10;
                                    a_index_out_reg = compute_counter;
                                    w_index_out_reg = compute_counter;
                                    next_compute_substate = COMPUTE_SYSTOLIC_OS;
                                end else begin
                                    a_buffer_mode_reg = 2'b11;
                                    w_buffer_mode_reg = 2'b00;
                                    a_index_out_reg = compute_counter;
                                    next_compute_substate = COMPUTE_SYSTOLIC_WS;
                                end
                            end
                            COMPUTE_STEP_EXTRA: begin // doesn't need to fetch data
                                if (mode) begin
                                    a_buffer_mode_reg = 2'b00;
                                    w_buffer_mode_reg = 2'b00;
                                    next_compute_substate = COMPUTE_EXTRA_OS;
                                end else begin
                                    a_buffer_mode_reg = 2'b00;
                                    next_compute_substate = COMPUTE_EXTRA_WS;
                                end
                            end
                            COMPUTE_STEP_FILL: begin
                                next_compute_substate = FILL_ACC;
                            end
                            COMPUTE_STEP_DONE: begin // selesai cok
                                next_compute_substate = COMPUTE_DONE;
                            end
                        endcase

                        acc_mode_reg = 2'b00;
                        operation_signal_processed_reg = 3'b111;
                        $display("pass COMPUTE_WAIT!, compute_counter: %d", compute_counter);
                    end
                    
                    COMPUTE_SYSTOLIC_OS: begin
                        $display("pass COMPUTE_SYSTOLIC!, compute_counter: %d", compute_counter);
                        operation_signal_processed_reg = 3'b100;
                        compute_counter = compute_counter + 1;
                        if (compute_counter > 15) begin // set so it will continue to COMPUTE_EXTRA from COMPUTE_WAIT
                            next_compute_step = COMPUTE_STEP_EXTRA;
                            compute_counter = 0;
                        end
                        next_compute_substate = COMPUTE_WAIT;
                    end

                    COMPUTE_SYSTOLIC_WS: begin
                        $display("pass COMPUTE_SYSTOLIC!, compute_counter: %d", compute_counter);
                        operation_signal_processed_reg = 3'b000;
                        compute_counter = compute_counter + 1;
                        if (compute_counter > 7) begin
                            next_compute_step = COMPUTE_STEP_FILL;
                        end
                        if (compute_counter > 14) begin
                            compute_counter = 0;
                        end
                        next_compute_substate = COMPUTE_WAIT;
                    end

                    FILL_ACC: begin
                        $display("pass FILL_ACC!, compute_counter: %d", compute_counter);
                        acc_mode_reg = 2'b01;  // set to add mode
                        acc_index_reg = acc_counter;
                        acc_counter = acc_counter + 1;
                        $display("acc_index_reg: %d", acc_index_reg); 
                        if (acc_counter < 8) begin
                            next_compute_step = COMPUTE_STEP_INITIAL;
                        end else if (acc_counter < 15) begin
                            next_compute_step = COMPUTE_STEP_EXTRA;
                        end else begin
                            next_compute_step = COMPUTE_STEP_DONE;
                        end
                        next_compute_substate = COMPUTE_WAIT;
                    end
                    
                    COMPUTE_EXTRA_OS: begin
                        $display("pass COMPUTE_EXTRA!, compute_counter: %d", compute_counter);
                        operation_signal_processed_reg = 3'b100;
                        compute_counter = compute_counter + 1;
                        if (compute_counter > 7) begin
                            next_compute_step = COMPUTE_STEP_DONE;
                            compute_counter = 0;
                        end
                        next_compute_substate = COMPUTE_WAIT;
                    end

                    COMPUTE_EXTRA_WS: begin
                        operation_signal_processed_reg = 3'b000;
                        next_compute_step = COMPUTE_STEP_FILL;
                        next_compute_substate = COMPUTE_WAIT;
                    end
                    
                    COMPUTE_DONE: begin
                        if (mode) begin
                            operation_signal_processed_reg = 3'b110;
                        end else begin
                            acc_mode_reg = 2'b10;
                        end
                        next_compute_step = COMPUTE_STEP_IDLE;
                        next_compute_substate = COMPUTE_IDLE;
                        next_state = WRITE_OUTPUT;
                        i = 0;
                        j = 0;
                        out_counter = 0;
                        $display("pass COMPUTE_DONE");
                    end
                endcase
            end
            WRITE_OUTPUT: begin //TODO ganti kali ya biar ngurangin clock, kyk di piazza, 300 ga cukup soalnya
                enable_o_bram_reg = 1;
                w_enable_o_bram_reg = 4'b1111;
                
                addr_o_bram_reg = 4 * out_counter;
                if (mode) begin // get from sys_res_ut if OS
                    data_in_o_bram_reg = sys_res_out[(j + 8*i)*PE_OUT_WIDTH +: PE_OUT_WIDTH];
                end else begin // get from acc_out if WS
                    data_in_o_bram_reg = acc_out[(j + 8*i)*PE_OUT_WIDTH +: PE_OUT_WIDTH];
                end
                
                j = j + 1;
                if (j >= M_reg) begin
                    i = i + 1;
                    j = 0;
                end
                
                out_counter = out_counter + 1;
                if (out_counter >= N_reg * M_reg) begin //TODO rapihin dikit
                    next_state = SEND_END_SIGNAL;
                end else begin
                    next_state = WRITE_OUTPUT;
                end
                $display("pass WRITE_OUTPUT! %d %d", out_counter, data_in_o_bram_reg);
            end
            SEND_END_SIGNAL: begin //TODO rapihin dikit sm gw gatau ini diapain
                enable_o_bram_reg = 0;
                w_enable_o_bram_reg = 4'b0000;
                enable_sp_bram_reg = 1;
                w_enable_sp_bram_reg = 4'b1111;
                addr_sp_bram_reg = 100;
                data_in_sp_bram_reg = 1;
                
                i = 0;
                j = 0;
            
                next_state = END_STEP;
                $display("pass SEND_END_SIGNAL!");
            end
            END_STEP: begin
                next_state = END_STEP;
                // TODO gua gatau mau ngapain cok ini, harusnya balik kah ke awal?
                //next_state = IDLE;
            end
        endcase
    end

    // assigning the outputs
    assign addr_sp_bram = addr_sp_bram_reg;
    assign enable_sp_bram = enable_sp_bram_reg;
    assign w_enable_sp_bram = w_enable_sp_bram_reg;
    assign data_in_sp_bram = data_in_sp_bram_reg;

    assign addr_a_bram = addr_a_bram_reg;
    assign enable_a_bram = enable_a_bram_reg;

    assign addr_w_bram = addr_w_bram_reg;
    assign enable_w_bram = enable_w_bram_reg;

    assign addr_o_bram = addr_o_bram_reg;
    assign enable_o_bram = enable_o_bram_reg;
    assign w_enable_o_bram = w_enable_o_bram_reg;
    assign data_in_o_bram = data_in_o_bram_reg;

    assign M = M_reg;
    assign N = N_reg;
    assign K = K_reg;
    assign a_data_in = a_data_in_reg;
    assign w_data_in = w_data_in_reg;
    assign a_buffer_mode = a_buffer_mode_reg;
    assign w_buffer_mode = w_buffer_mode_reg;
    assign a_index_out = a_index_out_reg;
    assign acc_index = acc_index_reg;
    assign w_index_out = w_index_out_reg;
    assign acc_mode = acc_mode_reg;

    assign operation_signal_processed = operation_signal_processed_reg;


endmodule
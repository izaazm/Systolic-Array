`timescale 100ns/1ns

module pe #(
    parameter integer   ACT_WIDTH       = 8,
    parameter integer   WGT_WIDTH       = 8, 
    parameter integer   MULT_OUT_WIDTH  = ACT_WIDTH + WGT_WIDTH,
    parameter integer   PE_OUT_WIDTH    = 32,
    parameter integer   OP_SIG_WIDTH    = 3
)(
    input wire clk,
    input wire reset,
    input wire [OP_SIG_WIDTH    - 1:0] operation_signal_in,
  
    input wire [ACT_WIDTH       - 1:0] a_in,
    input wire [WGT_WIDTH       - 1:0] w_in,
    input wire [PE_OUT_WIDTH    - 1:0] res_in,

    output reg [ACT_WIDTH       - 1:0] a_out,
    output reg [WGT_WIDTH       - 1:0] w_out,
    output reg [PE_OUT_WIDTH    - 1:0] res_out
);
    reg  [PE_OUT_WIDTH - 1:0] stored_weight;    // for WS mode
    reg  [PE_OUT_WIDTH - 1:0] res;              // for OS mode
    wire [PE_OUT_WIDTH - 1:0] multi_ws;
    wire [PE_OUT_WIDTH - 1:0] multi_os;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            // reset logic
            a_out <= 0;
            w_out <= 0;
			stored_weight <= 0;
            res <= 0;

        end else begin
            case (operation_signal_in)
                3'b001: begin
                    // W_load Mode
                    stored_weight <= w_in;
                  	w_out <= w_in;
                end
                3'b000: begin
                    // W_flow Mode
                    res_out <= res_in + multi_ws;
                    a_out <= a_in;
                end
                3'b100: begin
                    // OS_flow Mode
                    res <= res + multi_os;
                    a_out <= a_in;
                    w_out <= w_in;
                end
                3'b110: begin
                    // OS_drain Mode
                    res_out <= res;
                end
            endcase
        end 
    end
  	assign multi_ws = a_in * stored_weight;
  	assign multi_os = a_in * w_in;
  
endmodule
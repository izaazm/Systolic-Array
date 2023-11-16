module systolic_array_tb;

  // Parameters
  parameter integer ACT_WIDTH       = 8;
  parameter integer WGT_WIDTH       = 8;
  parameter integer MULT_OUT_WIDTH  = ACT_WIDTH + WGT_WIDTH;
  parameter integer PE_OUT_WIDTH    = 32;
  parameter integer OP_SIG_WIDTH    = 3;
  parameter integer ARRAY_SIZE      = 2;  // Changed to 2x2 matrix

  // Signals
  reg clk;
  reg reset;
  reg [ACT_WIDTH * ARRAY_SIZE - 1:0] act_data_in;
  reg [WGT_WIDTH - 1:0] wgt_data_in[ARRAY_SIZE-1:0][ARRAY_SIZE-1:0];
  wire [PE_OUT_WIDTH - 1:0] result_data_out[ARRAY_SIZE-1:0];

  // Instantiate the systolic array
  systolic_array #(
    .ACT_WIDTH(ACT_WIDTH),
    .WGT_WIDTH(WGT_WIDTH),
    .MULT_OUT_WIDTH(MULT_OUT_WIDTH),
    .PE_OUT_WIDTH(PE_OUT_WIDTH),
    .OP_SIG_WIDTH(OP_SIG_WIDTH),
    .ARRAY_SIZE(ARRAY_SIZE)
  ) uut (
    .clk(clk),
    .reset(reset),
    .act_data_in(act_data_in),
    .wgt_data_in(wgt_data_in),
    .result_data_out(result_data_out)
  );

  initial begin
    // Test setup
    clk = 0;
    forever #5 clk = ~clk;

    reset = 1;
    #10 reset = 0;

    // Input data for 2x2 matrix
    act_data_in = {8'h04, 8'h03, 8'h02, 8'h01};
    wgt_data_in[0][0] = 8'h01;
    wgt_data_in[0][1] = 8'h02;
    wgt_data_in[1][0] = 8'h03;
    wgt_data_in[1][1] = 8'h04;

    #20;

    // Matrix multiplication result check
    if(result_data_out[0][0] == 8'h07 && 
       result_data_out[0][1] == 8'h0A && 
       result_data_out[1][0] == 8'h0F && 
       result_data_out[1][1] == 8'h16) 
    begin
      $display("Matrix multiplication is correct.");
    end else begin
      $display("Matrix multiplication result:");
      $display("[ %0d %0d ]", result_data_out[0][0], result_data_out[0][1]);
      $display("[ %0d %0d ]", result_data_out[1][0], result_data_out[1][1]);
    end

    $finish;
  end

endmodule

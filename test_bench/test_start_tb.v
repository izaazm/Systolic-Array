module test_start_tb;
  reg clk;
  reg reset;

  // Instantiate the systolic array
  test_start uut (
    .clk(clk),
    .reset(reset)
  );

  initial begin
    // Test setup
    clk = 0;
    forever #0.5 clk = ~clk;

    reset = 1;
    #10 reset = 0;

    #20;

    $finish;
  end

endmodule

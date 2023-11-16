`timescale 100ns/1ns

module tb_systolic_array_fsm();

    reg clk;
    reg reset;
    reg [2:0] operation_signal_in;
    wire [2:0] operation_signal_out;

    // Instantiate the FSM module
    systolic_array_fsm uut (
        .clk(clk),
        .reset(reset),
        .operation_signal_in(operation_signal_in),
        .operation_signal_out(operation_signal_out)
    );

    // Clock Generation
    always begin
        #5 clk = ~clk;
    end

    // Test sequence
    initial begin
        // Initialize signals
        clk = 0;
        reset = 1;
        operation_signal_in = 3'b000; // default mode
        #10;
        
        // Release reset
        reset = 0;
        #10;

        // Test WS Mode
        operation_signal_in = 3'b000; 
        #10;
        $display("WS Mode signal out: %b", operation_signal_out);
        
        #10;
        $display("WS Flow Mode signal out: %b", operation_signal_out);
      
      	#10;
      	$display("WS Flow Mode signal out 2: %b", operation_signal_out);
      
      	// Release reset
        reset = 1;
        #10;
      	reset = 0;
		#10;

        // Test OS Mode
        operation_signal_in = 3'b001;
        #10;
        $display("OS Mode signal out: %b", operation_signal_out);

        #10;
        $display("OS Drain Mode signal out: %b", operation_signal_out);

        // End the simulation
        $finish;
    end
endmodule
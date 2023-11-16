/*
OUTPUT_REG = 1
    register exist and read takes 1 cycle
OUTPUT_REG = 0
    feed read_addr and get data immediately
*/
/* You can use ram.v freely. */
`timescale 100ns/1ns
module ram
#(
  parameter integer DATA_WIDTH    = 8,      
  parameter integer ADDR_WIDTH    = 12,     /* determine size of ram */
  parameter integer OUTPUT_REG    = 0
)
(
  input  wire                         clk,
  input  wire                         reset,

  input  wire                         read_req,
  input  wire [ ADDR_WIDTH  -1 : 0 ]  read_addr,
  output wire [ DATA_WIDTH  -1 : 0 ]  read_data,

  input  wire                         write_req,
  input  wire [ ADDR_WIDTH  -1 : 0 ]  write_addr,
  input  wire [ DATA_WIDTH  -1 : 0 ]  write_data
);
  reg  [ DATA_WIDTH -1 : 0 ] mem [ 0 : 1<<ADDR_WIDTH ];

  /* Write */
  always @(posedge clk)
  begin: RAM_WRITE
    if (write_req)
      mem[write_addr] <= write_data;
  end
  /* Read */
  generate
    if (OUTPUT_REG == 0)
      assign read_data = mem[read_addr];
    else begin
      reg [DATA_WIDTH-1:0] _read_data;
      always @(posedge clk)
      begin
        if (reset)
          _read_data <= 0;
        else if (read_req)
          _read_data <= mem[read_addr];
      end
      assign read_data = _read_data;
    end
  endgenerate
endmodule
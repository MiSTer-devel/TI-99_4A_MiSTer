`ifndef _latch_8bit_vh_
`define _latch_8bit_vh_

// Simple 8 bit latch
module latch_8bit(
    // clock input
    input le,
    // input
    input [7:0]din,
    // output
    output [7:0]dout
);

reg [7:0] latch_q;

always @(negedge le) begin
  latch_q <= din;
end

assign dout = latch_q;

endmodule

`endif 

`ifndef _shift_sin_pout_vh_
`define _shift_sin_pout_vh_

// 8 bit serial in, parallel out shift register.
module shift_sin_pout(
    // clock input
    input clk,
	 // select line
	 input select,
    // latch data to expose internal shifter.
    input le,
    // input
    input din,
    // output
    output [7:0]dout,
	 // parity signal
	 output parity
);

reg [7:0] latch_q;
reg [7:0] shift_q;

always @(posedge clk) begin
  if (select) begin
    if (le) latch_q <= shift_q;
    else shift_q <= { shift_q[6:0], din };
  end
end

assign dout = latch_q;
assign parity = ^shift_q;

endmodule

`endif 

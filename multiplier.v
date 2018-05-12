/***************************************************************************************************
*  multiplier.v
*
***************************************************************************************************/

module multiplier (
  input clk,
  input [17:0] a,
  input [17:0] b,
  output [35:0] p
);

  reg [17:0] old_a;
  reg [17:0] old_b;
  reg [35:0] shift_a;
  reg [35:0] product;
  reg [18:0] bindex;
  assign p = product;
  

  always @(posedge clk) begin
    if ((old_a != a) || (old_b != b)) begin
	  bindex <= 1;
	  product <= 36'h000000000;
	  old_a <= a;
	  old_b <= b;
	  shift_a <= a;
    end else if (bindex < 19'h40000) begin
	  product <= product + ((bindex & old_b) ? shift_a : 0);
	  bindex <= bindex << 1;
	  shift_a <= shift_a << 1;
    end
  end

endmodule

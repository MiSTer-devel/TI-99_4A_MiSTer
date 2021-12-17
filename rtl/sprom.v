
module sprom #(parameter init_file = "", awidth = 0)
(
	input	             clock,
	input [awidth-1:0] address,
	output       [15:0] q
);

altsyncram	altsyncram_component
(
	.address_a (address),
	.clock0 (clock),
	.q_a (q),
	.aclr0 (1'b0),
	.aclr1 (1'b0),
	.address_b (1'b1),
	.addressstall_a (1'b0),
	.addressstall_b (1'b0),
	.byteena_a (2'b11),
	.byteena_b (1'b1),
	.clock1 (1'b1),
	.clocken0 (1'b1),
	.clocken1 (1'b1),
	.clocken2 (1'b1),
	.clocken3 (1'b1),
	.data_a ({16{1'b1}}),
	.data_b (1'b1),
	.eccstatus (),
	.q_b (),
	.rden_a (1'b1),
	.rden_b (1'b1),
	.wren_a (1'b0),
	.wren_b (1'b0)
);

defparam
	altsyncram_component.address_aclr_a = "NONE",
	altsyncram_component.clock_enable_input_a = "BYPASS",
	altsyncram_component.clock_enable_output_a = "BYPASS",
	altsyncram_component.init_file = init_file,
	altsyncram_component.intended_device_family = "Cyclone V",
	altsyncram_component.lpm_hint = "ENABLE_RUNTIME_MOD=NO",
	altsyncram_component.lpm_type = "altsyncram",
	altsyncram_component.numwords_a = (2**awidth),
	altsyncram_component.operation_mode = "ROM",
	altsyncram_component.outdata_aclr_a = "NONE",
	altsyncram_component.outdata_reg_a = "UNREGISTERED",
	altsyncram_component.widthad_a = awidth,
	altsyncram_component.width_a = 16,
	altsyncram_component.width_byteena_a = 2;

endmodule

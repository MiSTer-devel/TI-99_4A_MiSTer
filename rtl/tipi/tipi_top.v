`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    13:20:25 07/15/2017 
// Design Name: 
// Module Name:    tipi_top 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
//`include "crubits.v"
`include "latch_8bit.v"
`include "shift_pload_sout.v"
`include "shift_sin_pout.v"
//`include "tristate_8bit.v"
`include "mux2_8bit.v"

module tipi_top(
//		output db_dir, // Which direction the data is flowing
//		output db_en,	// OCTAL BUS' OE line, enable/disable data flow from eeprom
		
		input r_clk,
		// 0 = Data or 1 = Control byte selection
		input r_cd,
		input r_dout,
		input r_le,
		// R|T 0 = RPi or 1 = TI originating data 
		input r_rt,
		output r_din,
		output r_reset,

		input ti_dbin,		// TMS9900 CPU_RD   - request for data from bus
		input ti_memen,
		input ti_we,		// TMS9900 NOT CPU_WR
		
		input[3:0] cru_state,
		input[15:0] ti_a,
		input[7:0] tp_d_i,
		output[7:0] tp_d_o
		
    );


// Process CRU bits
wire cru_dev_en = cru_state[0];
assign r_reset = ~cru_state[1];
// For a 32k 27C256 chip, these control bank switching.
// For a 8k 27C64 chip, these need to stay constant
// assign dsr_b0 = 1'bz; // not connected on 27C64
// assign dsr_b1 = 1'b1; // Active LOW is PGM on 27C64

// Latches && Shift Registers for TI to RPi communication - TC & TD

// Register selection:
// r_rt and r_dc combine to select the rd rc td and tc registers. 
// we will assert that r_rt == 0 is RPi output register
//                     r_rt == 1 is TI output register
//                     r_dc == 0 is data register
//                     r_dc == 1 is control register
// The following aliases should help.
wire tipi_rc = ~r_rt && ~r_cd;
wire tipi_rd = ~r_rt && r_cd;
wire tipi_tc = r_rt && ~r_cd;
wire tipi_td = r_rt && r_cd; 

// address comparisons
wire rc_addr = ti_a == 16'h5ff9;
wire rd_addr = ti_a == 16'h5ffb;
wire tc_addr = ti_a == 16'h5ffd;
wire td_addr = ti_a == 16'h5fff;

// TD Latch
wire tipi_td_le = (cru_dev_en && ~ti_we && ~ti_memen && td_addr);
wire [7:0]rpi_td;
latch_8bit tdl(tipi_td_le, tp_d_i, rpi_td);

// TC Latch
wire tipi_tc_le = (cru_dev_en && ~ti_we && ~ti_memen && tc_addr);
wire [7:0]rpi_tc;
latch_8bit tcl(tipi_tc_le, tp_d_i, rpi_tc);

// TD Shift output
wire td_out;
shift_pload_sout shift_td(r_clk, tipi_td, r_le, rpi_td, td_out);

// TC Shift output
wire tc_out;
shift_pload_sout shift_tc(r_clk, tipi_tc, r_le, rpi_tc, tc_out);


// Data from the RPi, to be read by the TI.

// RD
wire [7:0]tipi_db_rd;
wire rd_parity;
shift_sin_pout shift_rd(r_clk, tipi_rd, r_le, r_dout, tipi_db_rd, rd_parity);

// RC
wire [7:0]tipi_db_rc;
wire rc_parity;
shift_sin_pout shift_rc(r_clk, tipi_rc, r_le, r_dout, tipi_db_rc, rc_parity);

// Select if output is from the data or control register
reg r_din_mux;
always @(posedge r_clk) begin
  if (r_rt & r_cd) r_din_mux <= td_out;
  else if (r_rt & ~r_cd) r_din_mux <= tc_out;
  else if (~r_rt & r_cd) r_din_mux <= rd_parity;
  else r_din_mux <= rc_parity;
end
assign r_din = r_din_mux;


//-- Databus control

// drive the 74hct245 oe and dir lines.
//assign db_en = ~(cru_dev_en && ti_a >= 16'h4000 && ti_a < 16'h6000);    //Enable/Disable Database  0= Enable EPROM READ 1=Disable EPROM READ
//assign db_dir = cru_dev_en && ~ti_memen && ti_dbin;							//0=In From CPU			1= Out To CPU.  CPU requested a READ MEMORY

// register to databus output selection
wire [7:0]rreg_mux_out; 
mux2_8bit rreg_mux(rc_addr, tipi_db_rc, rd_addr, tipi_db_rd, tc_addr, rpi_tc, td_addr, rpi_td, rreg_mux_out);

//wire [7:0]tp_d_buf;
//wire dbus_ts_en = cru_state[0] && ~ti_memen && ti_dbin && ( ti_a >= 16'h5ff8 && ti_a < 16'h6000 );
//tristate_8bit dbus_ts(dbus_ts_en, rreg_mux_out, tp_d_buf);

//assign tp_d_o = tp_d_buf;
assign tp_d_o = rreg_mux_out;


endmodule

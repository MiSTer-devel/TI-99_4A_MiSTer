//
// fdc1772.v
//
// Copyright (c) 2015 Till Harbaum <till@harbaum.org>
//
// This source file is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This source file is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

// TODO: 
// - 30ms settle time after step before data can be read
// - implement sector size 0

module fdc1772 (
	input            clkcpu, // system cpu clock.
	input            clk8m_en,
	input            fd1771, // 1771 compatibility
	input            dden,
	input            turbo,	 // Speed up reading/writing by ignoring sector under head
	input            fd80, // MyArc currently selected drive is an 80 Track Drive 

	// external set signals
	input      [3:0] floppy_drive,
	input            floppy_side, 
	input            floppy_reset,

	// interrupts
	output reg       irq,
	output reg       drq, // data request

	input      [1:0] cpu_addr,
	input            cpu_sel,
	input            cpu_rw,
	input      [7:0] cpu_din,
	output reg [7:0] cpu_dout,

	// place any signals that need to be passed up to the top after here.
	input      [2:0] img_mounted, // signaling that new image has been mounted
	input      [2:0] img_wp,      // write protect
	input            img_ds,      // double-sided image (for BBC Micro only)
	input     [31:0] img_size,    // size of image in bytes
	output reg[31:0] sd_lba_fd0,
	output reg[31:0] sd_lba_fd1,
	output reg[31:0] sd_lba_fd2,
	output reg [2:0] sd_rd,
	output reg [2:0] sd_wr,
	input      [2:0] sd_ack,
	input      [8:0] sd_buff_addr,
	input      [7:0] sd_dout,
	output     [7:0] sd_din_fd0,
	output     [7:0] sd_din_fd1,
	output     [7:0] sd_din_fd2,
	input            sd_dout_strobe,
	output reg       drive_led
);

parameter CLK = 32000000;
parameter CLK_EN = 16'd1000; // in kHz  - original value :2033
parameter SECTOR_SIZE_CODE = 2'd3; // sec size 0=128, 1=256, 2=512, 3=1024
parameter SECTOR_BASE = 1'b0; // number of first sector on track (archie 0, dos 1)

localparam SECTOR_SIZE = 11'd128 << SECTOR_SIZE_CODE;

always @(*) drive_led = motor_on;


// -------------------------------------------------------------------------
// --------------------- IO controller image handling ----------------------
// -------------------------------------------------------------------------

reg [31:0] sd_lba;
always @(*) begin
	case (SECTOR_SIZE_CODE)
	// archie
	3: sd_lba = {(16'd0 + (fd_spt*track[6:0]) << fd_doubleside) + (floppy_side ? 5'd0 : fd_spt) + sector[4:0], s_odd };
	// st
	2: sd_lba = ((fd_spt*track[6:0]) << fd_doubleside) + (floppy_side ? 5'd0 : fd_spt) + sector[4:0] - 1'd1;
	// bbc micro
	// TI994/A
	1: sd_lba = ((((fd_spt*(floppy_side?track[6:0]:(~(track[6:0]-(image_tps - 1)))+image_tps))) + (floppy_side ? 5'd0 : fd_spt) + sector[4:0]));

	default: sd_lba = 0;
	endcase
end

reg [2:0] floppy_ready = 0;

wire         floppy_present = (floppy_drive == 4'b1110)?floppy_ready[0]:
                              (floppy_drive == 4'b1101)?floppy_ready[1]:
                              (floppy_drive == 4'b1011)?floppy_ready[2]:1'b0;

wire floppy_write_protected = (floppy_drive == 4'b1110)?img_wp[0]:
                              (floppy_drive == 4'b1101)?img_wp[1]:
                              (floppy_drive == 4'b1011)?img_wp[2]:1'b1;
reg   [1:0] drive_sel;

reg  [10:0] sector_len[3];
reg   [4:0] spt[3];     // sectors/track
reg   [9:0] gap_len[3]; // gap len/sector
reg   [4:0] interleave_mode[3]; // Sector Interleave to use.  0- TI-controller (0,7,5,3,1,8,6,4,2),  1- Interleave 1 (1-spt)
reg   [2:0] doubleside;
reg   [2:0] hd;
reg         fm;

reg  [11:0] image_sectors;
reg  [11:0] image_sps; // sectors/side
reg   [4:0] image_spt; // sectors/track
reg   [7:0] image_tps /* synthesis keep */; // tracks/side
reg   [9:0] image_gap_len;
reg         image_doubleside;
reg   [4:0] image_interleave_mode; // Sector Interleave to use.  0- TI-controller (0,7,5,3,1,8,6,4,2),  1- Interleave 1 (linear)
wire        image_hd = img_size[20];
reg 			allow_formatting;  // Prevents disk from being Formatted by creating an error on Write Track commands.  This prevents damage to disk images when DSRs don't support formatting them.

always @(*) begin
	reg [11:0] calc_spt;
	drive_sel = floppy_drive == 4'b1110 ? 2'd0 : floppy_drive == 4'b1101 ? 2'd1 : 2'd2;

	case (SECTOR_SIZE_CODE)
	3: begin
		// archie, 1024 bytes/sector
		fm = 0;
		allow_formatting = 1;
		image_sectors = img_size[21:10];
		image_doubleside = 1'b1;
		image_spt = image_hd ? 5'd10 : 5'd5;
		image_gap_len = 10'd220;
		image_interleave_mode = 4'd1;
	end
	2: begin
		// this block is valid for the .st format (or similar arrangement), 512 bytes/sector
		fm = 0;
		allow_formatting = 1;
		image_sectors = img_size[20:9];
		image_doubleside = 1'b0;
		image_sps = image_sectors;
		image_interleave_mode = 4'd1;
		
		if (image_sectors > (85*12)) begin
			image_doubleside = 1'b1;
			image_sps = image_sectors >> 1'b1;
		end
		if (image_hd) image_sps = image_sps >> 1'b1;

		// spt : 9-12, tracks: 79-85
		case (image_sps)
			711,720,729,738,747,756,765   : image_spt = 5'd9;
			790,800,810,820,830,840,850   : image_spt = 5'd10;
			948,960,972,984,996,1008,1020 : image_spt = 5'd12;
			default : image_spt = 5'd11;
		endcase;

		if (image_hd) image_spt = image_spt << 1'b1;

		// SECTOR_GAP_LEN = BPT/SPT - (SECTOR_LEN + SECTOR_HDR_LEN) = 6250/SPT - (512+6)
		case (image_spt)
			5'd9, 5'd18: image_gap_len = 10'd176;
			5'd10,5'd20: image_gap_len = 10'd107;
			5'd11,5'd22: image_gap_len = 10'd50;
			default : image_gap_len = 10'd2;
		endcase;
	end
	1: begin
		// 256 bytes/sector single density (BBC SSD/DSD, TI99/4A)
		fm = 1;
		image_tps = 40;  //Default to 40
		allow_formatting = 0;  // By default, don't allow formatting until a support floppy size is detected.
		image_sectors = img_size[19:8];
		image_doubleside = img_ds;
		image_interleave_mode = 4'd0;
		if (image_doubleside)
			image_sps = image_sectors >> 1'b1;
		else
			image_sps = image_sectors;
		case (image_sps)
			360: begin
					image_spt = 9; // TI99/4A
					image_interleave_mode = 4'd0;
					fm = 1;
					allow_formatting = 1;
				end
			640: begin
					image_spt = 16; // TI99/4A Double Density
					image_interleave_mode = 4'd1;
					fm = 0;
					allow_formatting = 0;
				end
			720: begin
					image_spt = fd80 ? 5'd9 : 5'd18; // TI99/4A 40 Track Double Density or 80 Track Single Density
					image_interleave_mode = 4'd1;
					fm = 0;
					allow_formatting = 1;
					if(fd80) image_tps = 80;
				end
			760: begin
					image_spt = 19; // TI99/4A Double Density - Odd Disk size, may be a fluke and removed in the future.
					image_interleave_mode = 4'd1;
					fm = 0;
					allow_formatting = 0;
				end
			1440: begin
					image_spt = 18; // TI99/4A Double Density
					image_interleave_mode = 4'd1;
					fm = 0;
					allow_formatting = 1;
					image_tps = 80;
				end
			default: begin
					calc_spt = image_sps/image_tps;
					image_spt = calc_spt[4:0];
					image_interleave_mode = 4'd1;
				end
		endcase
		image_gap_len = 10'd50;
	end
	default: begin
		fm = 0;
		image_sectors = 0;
		image_doubleside = 0;
		image_spt = 0;
		image_gap_len = 0;
		image_interleave_mode = 4'd0;
	end

	endcase
end

always @(posedge clkcpu) begin
	reg [2:0] img_mountedD;

	img_mountedD <= img_mounted;
	if (~img_mountedD[0] && img_mounted[0]) begin
		floppy_ready[0] <= |img_size;
		sector_len[0] <= SECTOR_SIZE;
		spt[0] <= image_spt;
		gap_len[0] <= image_gap_len;
		doubleside[0] <= image_doubleside;
		hd[0] <= image_hd;
		interleave_mode[0] <= image_interleave_mode;
		
	end
	if (~img_mountedD[1] && img_mounted[1]) begin
		floppy_ready[1] <= |img_size;
		sector_len[1] <= SECTOR_SIZE;
		spt[1] <= image_spt;
		gap_len[1] <= image_gap_len;
		doubleside[1] <= image_doubleside;
		hd[1] <= image_hd;
		interleave_mode[1] <= image_interleave_mode;
	end
	if (~img_mountedD[2] && img_mounted[2]) begin
		floppy_ready[2] <= |img_size;
		sector_len[2] <= SECTOR_SIZE;
		spt[2] <= image_spt;
		gap_len[2] <= image_gap_len;
		doubleside[2] <= image_doubleside;
		hd[2] <= image_hd;
		interleave_mode[2] <= image_interleave_mode;
	end
end

// -------------------------------------------------------------------------
// ---------------------------- IRQ/DRQ handling ---------------------------
// -------------------------------------------------------------------------
reg cpu_selD;
reg cpu_rwD;
always @(posedge clkcpu) begin
	cpu_rwD <= cpu_sel & ~cpu_rw;
	cpu_selD <= cpu_sel;
end

wire cpu_we = cpu_sel & ~cpu_rw & ~cpu_rwD;

reg irq_set;

// floppy_reset and read of status register/write of command register clears irq
reg cpu_rw_cmdstatus;

always @(posedge clkcpu)
  cpu_rw_cmdstatus <= ~cpu_selD && cpu_sel && (cpu_addr == FDC_REG_CMDSTATUS /*|| track_operation_doneD*/);

wire irq_clr = !floppy_reset || cpu_rw_cmdstatus;

always @(posedge clkcpu) begin
	if(irq_clr) irq <= 1'b0;
	else if(irq_set) irq <= 1'b1;
end

reg drq_set;

reg cpu_rw_data;
always @(posedge clkcpu)
	cpu_rw_data <= ~cpu_selD && cpu_sel && cpu_addr == FDC_REG_DATA;

wire drq_clr = !floppy_reset || cpu_rw_data;

always @(posedge clkcpu) begin
	if(drq_clr) drq <= 1'b0;
	else if(drq_set) drq <= 1'b1;
end

// -------------------------------------------------------------------------
// -------------------- virtual floppy drive mechanics ---------------------
// -------------------------------------------------------------------------

// -------------------------------------------------------------------------
// ------------------------------- floppy 0 --------------------------------
// -------------------------------------------------------------------------
wire fd0_index;
wire fd0_ready;
wire [6:0] fd0_track;
wire [4:0] fd0_sector;
wire fd0_sector_hdr;
wire fd0_sector_data;
wire fd0_dclk;

floppy #(.SYS_CLK(CLK)) floppy0 (
	.clk         ( clkcpu          ),

	// control signals into floppy
	.select      (!floppy_drive[0] ),
	.motor_on    ( motor_on        ),
	.step_in     ( step_in         ),
	.step_out    ( step_out        ),

	// physical parameters
	.sector_len  ( sector_len[0]   ),
	.spt         ( spt[0]          ),
	.sector_gap_len ( gap_len[0]   ),
	.interleave_mode ( interleave_mode[0] ),
	.sector_base ( SECTOR_BASE     ),
	.hd          ( hd[0]           ),
	.fm          ( fm              ),

	// status signals generated by floppy
	.dclk_en     ( fd0_dclk        ),
	.track       ( fd0_track       ),
	.sector      ( fd0_sector      ),
	.sector_hdr  ( fd0_sector_hdr  ),
	.sector_data ( fd0_sector_data ),
	.ready       ( fd0_ready       ),
	.index       ( fd0_index       )
);

// -------------------------------------------------------------------------
// ------------------------------- floppy 1 --------------------------------
// -------------------------------------------------------------------------
wire fd1_index;
wire fd1_ready;
wire [6:0] fd1_track;
wire [4:0] fd1_sector;
wire fd1_sector_hdr;
wire fd1_sector_data;
wire fd1_dclk;

floppy #(.SYS_CLK(CLK)) floppy1 (
	.clk         ( clkcpu          ),

	// control signals into floppy
	.select      (!floppy_drive[1] ),
	.motor_on    ( motor_on        ),
	.step_in     ( step_in         ),
	.step_out    ( step_out        ),

	// physical parameters
	.sector_len  ( sector_len[1]   ),
	.spt         ( spt[1]          ),
	.sector_gap_len ( gap_len[1]   ),
	.interleave_mode ( interleave_mode[1] ),
	.sector_base ( SECTOR_BASE     ),
	.hd          ( hd[1]           ),
	.fm          ( fm              ),

	// status signals generated by floppy
	.dclk_en     ( fd1_dclk        ),
	.track       ( fd1_track       ),
	.sector      ( fd1_sector      ),
	.sector_hdr  ( fd1_sector_hdr  ),
	.sector_data ( fd1_sector_data ),
	.ready       ( fd1_ready       ),
	.index       ( fd1_index       )
);

// -------------------------------------------------------------------------
// ------------------------------- floppy 2 --------------------------------
// -------------------------------------------------------------------------
wire fd2_index;
wire fd2_ready;
wire [6:0] fd2_track;
wire [4:0] fd2_sector;
wire fd2_sector_hdr;
wire fd2_sector_data;
wire fd2_dclk;

floppy #(.SYS_CLK(CLK)) floppy2 (
	.clk         ( clkcpu          ),

	// control signals into floppy
	.select      (!floppy_drive[2] ),
	.motor_on    ( motor_on        ),
	.step_in     ( step_in         ),
	.step_out    ( step_out        ),

	// physical parameters
	.sector_len  ( sector_len[2]   ),
	.spt         ( spt[2]          ),
	.sector_gap_len ( gap_len[2]   ),
	.interleave_mode ( interleave_mode[2] ),
	.sector_base ( SECTOR_BASE     ),
	.hd          ( hd[2]           ),
	.fm          ( fm              ),

	// status signals generated by floppy
	.dclk_en     ( fd2_dclk        ),
	.track       ( fd2_track       ),
	.sector      ( fd2_sector      ),
	.sector_hdr  ( fd2_sector_hdr  ),
	.sector_data ( fd2_sector_data ),
	.ready       ( fd2_ready       ),
	.index       ( fd2_index       )
);

// -------------------------------------------------------------------------
// ------------------------------- floppy 3 --------------------------------
// -------------------------------------------------------------------------
wire fd3_index;
wire fd3_ready;
wire [6:0] fd3_track;
wire [4:0] fd3_sector;
wire fd3_sector_hdr;
wire fd3_sector_data;
wire fd3_dclk;

floppy #(.SYS_CLK(CLK)) floppy3 (
	.clk         ( clkcpu          ),

	// control signals into floppy
	.select      (!floppy_drive[3] ),
	.motor_on    ( motor_on        ),
	.step_in     ( step_in         ),
	.step_out    ( step_out        ),

	// physical parameters
	.sector_len  (                 ),
	.spt         (                 ),
	.sector_gap_len (              ),
	.sector_base ( SECTOR_BASE     ),
	.hd          (                 ),
	.fm          ( fm              ),

	// status signals generated by floppy
	.dclk_en     ( fd3_dclk        ),
	.track       ( fd3_track       ),
	.sector      ( fd3_sector      ),
	.sector_hdr  ( fd3_sector_hdr  ),
	.sector_data ( fd3_sector_data ),
	.ready       ( fd3_ready       ),
	.index       ( fd3_index       )
);

// -------------------------------------------------------------------------
// ----------------------------- floppy demux ------------------------------
// -------------------------------------------------------------------------

wire fd_index =        (!floppy_drive[0])?fd0_index:
                       (!floppy_drive[1])?fd1_index:
                       (!floppy_drive[2])?fd2_index:
                       (!floppy_drive[3])?fd3_index:
                       1'b0;

wire fd_ready =        (!floppy_drive[0])?fd0_ready:
                       (!floppy_drive[1])?fd1_ready:
                       (!floppy_drive[2])?fd2_ready:
                       (!floppy_drive[3])?fd3_ready:
                       1'b0;

wire [6:0] fd_track =  (!floppy_drive[0])?fd0_track:
                       (!floppy_drive[1])?fd1_track:
                       (!floppy_drive[2])?fd2_track:
                       (!floppy_drive[3])?fd3_track:
                       7'd0;

wire [4:0] fd_sector = (!floppy_drive[0])?fd0_sector:
                       (!floppy_drive[1])?fd1_sector:
                       (!floppy_drive[2])?fd2_sector:
                       (!floppy_drive[3])?fd3_sector:
                       4'd0;

wire fd_sector_hdr =   (!floppy_drive[0])?fd0_sector_hdr:
                       (!floppy_drive[1])?fd1_sector_hdr:
                       (!floppy_drive[2])?fd2_sector_hdr:
                       (!floppy_drive[3])?fd3_sector_hdr:
                       1'b0;

//wire fd_sector_data =  (!floppy_drive[0])?fd0_sector_data:
//                       (!floppy_drive[1])?fd1_sector_data:
//                       (!floppy_drive[2])?fd2_sector_data:
//                       (!floppy_drive[3])?fd3_sector_data:
//                       1'b0;

wire fd_dclk_en =      (!floppy_drive[0])?fd0_dclk:
                       (!floppy_drive[1])?fd1_dclk:
                       (!floppy_drive[2])?fd2_dclk:
//                       (!floppy_drive[3])?fd3_dclk:
                       1'b0;

wire fd_doubleside =   (!floppy_drive[0])?doubleside[0]:
                       (!floppy_drive[1])?doubleside[1]:
                       (!floppy_drive[2])?doubleside[2]:
//                       (!floppy_drive[3])?doubleside[3]:
                       1'b0;


//wire fd_doubleside =   (!floppy_drive[0])?doubleside[0]:doubleside[1];
wire [4:0]  fd_spt =   (!floppy_drive[0])?spt[0]:
                       (!floppy_drive[1])?spt[1]:
                       (!floppy_drive[2])?spt[2]:
//                       (!floppy_drive[3])?spt[3]:
                       5'd9;

//wire [4:0]  fd_spt =   (!floppy_drive[0])?spt[0]:spt[1];

wire fd_track0 = (fd_track == 0);

// -------------------------------------------------------------------------
// ----------------------- internal state machines -------------------------
// -------------------------------------------------------------------------

// --------------------------- Motor handling ------------------------------

// if motor is off and type 1 command with "spin up sequnce" bit 3 set
// is received then the command is executed after the motor has
// reached full speed for 5 rotations (800ms spin-up time + 5*200ms =
// 1.8sec) If the floppy is idle for 10 rotations (2 sec) then the
// motor is switched off again
localparam MOTOR_IDLE_COUNTER = 4'd10;
reg [3:0] motor_timeout_index /* verilator public */;
reg indexD;
reg busy /* verilator public */;
reg step_in, step_out;
reg [3:0] motor_spin_up_sequence /* verilator public */;

// consider spin up done either if the motor is not supposed to spin at all or
// if it's supposed to run and has left the spin up sequence
wire motor_spin_up_done = (!motor_on) || (motor_on && (motor_spin_up_sequence == 0));

// ---------------------------- step handling ------------------------------

localparam STEP_PULSE_LEN = 16'd1;
localparam STEP_PULSE_CLKS = STEP_PULSE_LEN * CLK_EN;
reg [15:0] step_pulse_cnt;

// the step rate is only valid for command type I
wire [15:0] step_rate_clk = 
           (cmd[1:0]==2'b00)?(16'd6*CLK_EN-1'd1):    //  6ms
           (cmd[1:0]==2'b01)?(16'd12*CLK_EN-1'd1):   // 12ms
           (cmd[1:0]==2'b10)?(16'd2*CLK_EN-1'd1):    //  2ms
           (16'd3*CLK_EN-1'd1);                      //  3ms

reg [15:0] step_rate_cnt;
reg [23:0] delay_cnt;

// flag indicating that a "step" is in progress
wire step_busy = (step_rate_cnt != 0);
wire delaying = (delay_cnt != 0);

reg [7:0] step_to;
reg RNF;
reg sector_inc_strobe;
reg track_inc_strobe;
reg track_dec_strobe;
reg track_clear_strobe;
reg track_to_sector;

reg sector_clear_strobe;	//Reset SECTOR register to sector 0 (used by Read/Write Track)

always @(posedge clkcpu) begin
	reg [1:0] seek_state;
	reg notready_wait;
	reg sector_not_found;
	reg irq_at_index;
	reg [1:0] data_transfer_state;

	sector_clear_strobe <= 1'b0;
	sector_inc_strobe <= 1'b0;
	track_inc_strobe <= 1'b0;
	track_dec_strobe <= 1'b0;
	track_clear_strobe <= 1'b0;
	track_to_sector <= 1'b0;
	irq_set <= 1'b0;

	if(!floppy_reset) begin
		motor_on <= 1'b0;
		busy <= 1'b0;
		step_in <= 1'b0;
		step_out <= 1'b0;
		sd_card_read <= 0;
		sd_card_write <= 0;
		data_transfer_start <= 1'b0;
		seek_state <= 0;
		notready_wait <= 1'b0;
		sector_not_found <= 1'b0;
		irq_at_index <= 1'b0;
		data_transfer_state <= 2'b00;
		RNF <= 1'b0;
//		WF <= 1'b0;
	end
	else if (clk8m_en) begin
		sd_card_read <= 0;
		sd_card_write <= 0;
		data_transfer_start <= 1'b0;

		// disable step signal after 1 msec
		if(step_pulse_cnt != 0) 
			step_pulse_cnt <= step_pulse_cnt - 16'd1;
		else begin
			step_in <= 1'b0;
			step_out <= 1'b0;
		end

		 // step rate timer
		if(step_rate_cnt != 0) 
			step_rate_cnt <= step_rate_cnt - 16'd1;

		// delay timer
		if(delay_cnt != 0) 
			delay_cnt <= delay_cnt - 1'd1;

		// just received a new command
		if(cmd_rx) begin
			busy <= 1'b1;
			notready_wait <= 1'b0;
			sector_not_found <= 1'b0;
			data_transfer_state <= 2'b00;
			if(cmd_type_1 || cmd_type_2 || cmd_type_3) begin
				RNF <= 1'b0;
				motor_on <= 1'b1;
				// 'h' flag '0' -> wait for spin up
				if (!motor_on && !cmd[3]) motor_spin_up_sequence <= 6;   // wait for 6 full rotations
			end

			// handle "forced interrupt"
			if(cmd_type_4) begin
				busy <= 1'b0;
				if(cmd[3]) irq_set <= 1'b1;
				if(cmd[3:2] == 2'b01) irq_at_index <= 1'b1;
				// From Hatari: Starting a Force Int command when idle should set the motor bit and clear the spinup bit (verified on STF)
				if (!busy && fd_index ) motor_on <= 1'b1;	//If this is on power-up, FD_INDEX will be low, so we don't want motor to start up and stay stuck till first disk operation
			end
		end

		// execute command if motor is not supposed to be running or
		// wait for motor spinup to finish
		if(busy && motor_spin_up_done && !step_busy && !delaying) begin

			// ------------------------ TYPE I -------------------------
			if(cmd_type_1) begin
				if(!floppy_present) begin
					// no image selected -> send irq after 6 ms
					if (!notready_wait) begin
						delay_cnt <= 16'd6*CLK_EN;
						notready_wait <= 1'b1;
					end else begin
						RNF <= 1'b1;
						busy <= 1'b0;
						irq_set <= 1'b1; // emit irq when command done
					end
				end else
				// evaluate command
				case (seek_state)
				0: begin
					// restore
					if(cmd[7:4] == 4'b0000) begin
						if (fd_track0) begin
							track_clear_strobe <= 1'b1;
							seek_state <= 2;
						end else begin
							step_dir <= 1'b1;
							seek_state <= 1;
						end
					end

					// seek
					if(cmd[7:4] == 4'b0001) begin
						if (track == step_to) seek_state <= 2;
						else begin
							step_dir <= (step_to < track);
							seek_state <= 1;
						end
					end

					// step
					if(cmd[7:5] == 3'b001) seek_state <= 1;

					// step-in
					if(cmd[7:5] == 3'b010) begin
						step_dir <= 1'b0;
						seek_state <= 1;
					end

					// step-out
					if(cmd[7:5] == 3'b011) begin
						step_dir <= 1'b1;
						seek_state <= 1;
					end
				   end

				// do the step
				1: begin
					if (step_dir)
						step_in <= 1'b1;
					else
						step_out <= 1'b1;

					// update the track register if seek/restore or the update flag set
					if( (!cmd[6] && !cmd[5]) || ((cmd[6] || cmd[5]) && cmd[4]))
						if (step_dir)
							track_dec_strobe <= 1'b1;
						else
							track_inc_strobe <= 1'b1;

					step_pulse_cnt <= STEP_PULSE_CLKS - 1'd1;
					step_rate_cnt <= step_rate_clk;

					seek_state <= (!cmd[6] && !cmd[5]) ? 0 : 2; // loop for seek/restore
				   end

				// verify
				2: begin
					if (cmd[2]) begin
						delay_cnt <= 16'd3*CLK_EN; // TODO: implement verify, now just delay one more step
					end
					seek_state <= 3;
				   end

				// finish
				3: begin
					busy <= 1'b0;
					irq_set <= 1'b1; // emit irq when command done
					seek_state <= 0;
				   end
				endcase
			end // if (cmd_type_1)

			// ------------------------ TYPE II -------------------------
			if(cmd_type_2) begin
				if(!floppy_present) begin
					// no image selected -> send irq after 6 ms
					if (!notready_wait) begin
						delay_cnt <= 16'd6*CLK_EN;
						notready_wait <= 1'b1;
					end else begin
						RNF <= 1'b1;
						busy <= 1'b0;
						irq_set <= 1'b1; // emit irq when command done
					end
				end else if (sector_not_found) begin
					busy <= 1'b0;
					irq_set <= 1'b1; // emit irq when command done
					RNF <= 1'b1;
				end else if (cmd[2] && !notready_wait) begin
					// e flag: 15 ms settling delay
					delay_cnt <= 16'd15*CLK_EN;
					notready_wait <= 1'b1;
					
				// read sector
				end else begin
					if(cmd[7:5] == 3'b100) begin
						// Myarc uses the DDEN line to check if floppy is MFM by switching to FM, reading sector and looking for error
						// therefore if the DDEN line doesn't match the FM/MFM determined for the floppy image, we error out.
						// Ultimately Write Track will be properly implemented with CRC generation for both FM and MFM
						if (((sector - SECTOR_BASE) >= fd_spt) || fm != dden) begin
							// wait 5 rotations (1 sec) before setting RNF
							sector_not_found <= 1'b1;
							delay_cnt <= 24'd1000 * CLK_EN;
						end else if (sd_state == SD_IDLE) begin
							case (data_transfer_state)

							2'b00: if (fifo_cpuptr == 0) begin
								// SD Card phase
								sd_card_read <= 1;
								data_transfer_state <= 2'b01;
							end

							2'b01: begin
								// CPU phase
								// we are busy until the right sector header passes under 
								// the head and the sd-card controller indicates the sector
								// is in the fifo
								if(fd_ready && (fd_sector_hdr  || turbo) && ((fd_sector == sector) || turbo)) data_transfer_start <= 1'b1;

								if(data_transfer_done) begin
									data_transfer_state <= 2'b00;
									if (cmd[4]) sector_inc_strobe <= 1'b1; // multiple sector transfer
									else begin
										busy <= 1'b0;
										irq_set <= 1'b1; // emit irq when command done
									end
								end
							end

							default :;
							endcase

						end
					end

					// write sector
					if(cmd[7:5] == 3'b101) begin
						if ((sector - SECTOR_BASE) >= fd_spt) begin
							// wait 5 rotations (1 sec) before setting RNF
							sector_not_found <= 1'b1;
							delay_cnt <= 24'd1000 * CLK_EN;
						end else if (sd_state == SD_IDLE) begin
							case (data_transfer_state)
							2'b00: begin
								// pre-read phase
									if (SECTOR_SIZE_CODE < 2) sd_card_read <= 1;
									data_transfer_state <= 2'b10;
								end
							2'b10: begin
								// CPU phase
//								if (fifo_cpuptr == 0 && fd_ready && (fd_sector_hdr  || turbo) && ((fd_sector == sector) || turbo)) data_transfer_start <= 1'b1;
								if (fifo_cpuptr == 0 && fd_ready && fd_sector_hdr && fd_sector == sector) data_transfer_start <= 1'b1;
								if (data_transfer_done) begin
									sd_card_write <= 1;
									data_transfer_state <= 2'b11;
								end
							end

							2'b11: begin
								// SD Card phase
								data_transfer_state <= 2'b00;
								if (cmd[4]) sector_inc_strobe <= 1'b1; // multiple sector transfer
								else begin
									busy <= 1'b0;
									irq_set <= 1'b1; // emit irq when command done
								end
							end

							default: ;
							endcase

						end
					end
				end
			end

			// ------------------------ TYPE III -------------------------
			if(cmd_type_3) begin
				if(!floppy_present) begin
					// no image selected -> send irq after 6 ms
					if (!notready_wait) begin
						delay_cnt <= 16'd6*CLK_EN;
						notready_wait <= 1'b1;
					end else begin
						RNF <= 1'b1;
						busy <= 1'b0;
						irq_set <= 1'b1; // emit irq when command done
					end
				end
				else if (cmd[2] && !notready_wait) begin
					// e flag: 15 ms settling delay
					delay_cnt <= 16'd15*CLK_EN;
					notready_wait <= 1'b1;
				end
				else begin
					// read track TODO: fake
					if(cmd[7:4] == 4'b1110) begin
						busy <= 1'b0;
					end
					// write track
					if(cmd[7:4] == 4'b1111) begin
						if ((sector - SECTOR_BASE) >= fd_spt || ~allow_formatting) begin
							// wait 5 rotations (1 sec) before setting RNF
							sector_not_found <= 1'b1;
							delay_cnt <= 24'd1000 * CLK_EN;
						end
						else if (sd_state == SD_IDLE) begin
							case (data_transfer_state)
							2'b00: begin
								// pre-read phase
									if (SECTOR_SIZE_CODE < 2) sd_card_read <= 1;
									data_transfer_state <= 2'b10;
								end
							2'b10: begin
								// CPU phase
								if (fifo_cpuptr == 0 && fd_ready && (fd_sector_hdr  || turbo) && ((fd_sector == sector) || turbo)) data_transfer_start <= 1'b1;
								if (data_transfer_done) begin
									sd_card_write <= 1;
									data_transfer_state <= 2'b11;
								end
							end

							2'b11: begin
								// SD Card phase
								data_transfer_state <= 2'b00;
								if (sector != (fd_spt - 1)) sector_inc_strobe <= 1'b1; // multiple sector transfer
								else begin
									busy <= 1'b0;
									sector_clear_strobe <= 0;
									// If not in FD1771 mode, throw an interrupt, otherwise don't or it will lock up the TIFDC
									if(~fd1771) irq_set <= 1'b1;
								end
							end

							default: ;
							endcase

						end
					end

					// read address
					if(cmd[7:4] == 4'b1100) begin
						// we are busy until the next setor header passes under the head
						if(fd_ready && fd_sector_hdr)
							data_transfer_start <= 1'b1;

						if(data_transfer_done) begin
							busy <= 1'b0;
							irq_set <= 1'b1; // emit irq when command done
							track_to_sector <= 1'b1;
						end
					end
				end
			end
		end

		// stop motor if there was no command for 10 index pulses
		indexD <= fd_index;
		if(indexD && !fd_index) begin
			irq_at_index <= 1'b0;
			if (irq_at_index) irq_set <= 1'b1;

			// let motor timeout run once fdc is not busy anymore
			if(!busy && motor_spin_up_done) begin
				if(motor_timeout_index != 0)
					motor_timeout_index <= motor_timeout_index - 4'd1;
				else if(motor_on)
					motor_timeout_index <= MOTOR_IDLE_COUNTER;

				if(motor_timeout_index == 1)
					motor_on <= 1'b0;
			end

			if(motor_spin_up_sequence != 0)
				motor_spin_up_sequence <= motor_spin_up_sequence - 4'd1;
		end
		if(busy) motor_timeout_index <= 0;
	end
end

// floppy delivers data at a floppy generated rate (usually 250kbit/s), so the start and stop
// signals need to be passed forth and back from cpu clock domain to floppy data clock domain
reg data_transfer_start;
reg data_transfer_done;

// ==================================== FIFO ==================================

// 0.5/1 kB buffer used to receive a sector as fast as possible from from the io
// controller. The internal transfer afterwards then runs at 250000 Bit/s
reg  [10:0] fifo_cpuptr;
reg  [9:0] fifo_cpuptr_adj;
wire [7:0] fifo_q;
reg        s_odd; //odd sector
reg  [9:0] fifo_sdptr;

always @(*) begin

	if (SECTOR_SIZE_CODE == 3)
		fifo_sdptr = { s_odd, sd_buff_addr };
	else
		fifo_sdptr = { 1'b0, sd_buff_addr };

	fifo_cpuptr_adj = fifo_cpuptr[9:0];
end

reg     [7:0] sd_din;

fdc1772_dpram #(8, 10) fifo
(
	.clock(clkcpu),

	.address_a(fifo_sdptr),
	.data_a(sd_dout),
	.wren_a(sd_dout_strobe & sd_ack[drive_sel]),
	.q_a(sd_din),

	.address_b(fifo_cpuptr_adj),
	.data_b(data_in),
	.wren_b(data_in_strobe),
	.q_b(fifo_q)
);

// ------------------ SD card control ------------------------
localparam SD_IDLE = 0;
localparam SD_READ = 1;
localparam SD_WRITE = 2;

reg [1:0] sd_state;
reg       sd_card_write;
reg       sd_card_read;

always @(posedge clkcpu) begin
	reg sd_ackD;
	reg sd_card_readD;
	reg sd_card_writeD;

	if(drive_sel == 0) sd_din_fd0 = sd_din;
	else if(drive_sel == 1) sd_din_fd1 = sd_din;
	else if(drive_sel == 2) sd_din_fd2 = sd_din;

	case (drive_sel)
		0: sd_lba_fd0 = sd_lba;
		1: sd_lba_fd1 = sd_lba;
		2: sd_lba_fd2 = sd_lba;
		default: begin
			sd_lba_fd0 = 0;
			sd_lba_fd1 = 0;
			sd_lba_fd2 = 0;
		end
		
	endcase

	sd_card_readD <= sd_card_read;
	sd_card_writeD <= sd_card_write;
	sd_ackD <= sd_ack[drive_sel];
	if (sd_ack[0]) {sd_rd[0], sd_wr[0]} <= 0;
	if (sd_ack[1]) {sd_rd[1], sd_wr[1]} <= 0;
	if (sd_ack[2]) {sd_rd[2], sd_wr[2]} <= 0;

	case (sd_state)
	SD_IDLE:
	begin
		s_odd <= 1'b0;
		if (~sd_card_readD & sd_card_read) begin
			sd_rd <= ~{ floppy_drive[2], floppy_drive[1], floppy_drive[0] };
			sd_state <= SD_READ;
		end
		else if (~sd_card_writeD & sd_card_write) begin
			sd_wr <= ~{ floppy_drive[2], floppy_drive[1], floppy_drive[0] };
			sd_state <= SD_WRITE;
		end
	end

	SD_READ:
	if (sd_ackD & ~sd_ack[drive_sel]) begin
		if (s_odd || SECTOR_SIZE_CODE != 3) begin
			sd_state <= SD_IDLE;
		end else begin
			s_odd <= 1;
			sd_rd <= ~{ floppy_drive[2], floppy_drive[1], floppy_drive[0] };
		end
	end

	SD_WRITE:
	if (sd_ackD & ~sd_ack[drive_sel]) begin
		if (s_odd || SECTOR_SIZE_CODE != 3) begin
			sd_state <= SD_IDLE;
		end else begin
			s_odd <= 1;
			sd_wr <= ~{ floppy_drive[2], floppy_drive[1], floppy_drive[0] };
		end
	end

	default: ;
	endcase
end

// -------------------- CPU data read/write -----------------------
reg data_in_strobe;
reg data_in_valid;
reg data_mark_found;
//reg [1:0] write_crc;
//reg [15:0] crc;
always @(posedge clkcpu) begin
	reg        data_transfer_startD;
	reg [10:0] data_transfer_cnt;

	if (cpu_we && cpu_addr == FDC_REG_DATA) begin
		data_out <= data_in;
		data_in_valid <= 1;
	end

	// reset fifo read pointer on reception of a new command or 
	// when multi-sector transfer increments the sector number
	// Flandango: or when a disk is swapped.
	if(cmd_rx || sector_inc_strobe || sector_clear_strobe) begin
		data_in_valid <= 0;
		data_transfer_cnt <= 0;
		fifo_cpuptr <= 0;
//		write_crc <= 2'b00;
	end

	drq_set <= 1'b0;
	if (clk8m_en) data_transfer_done <= 0;
	data_transfer_startD <= data_transfer_start;
	// received request to read data
	if(~data_transfer_startD & data_transfer_start) begin

		// read_address command has 6 data bytes
		if(cmd[7:4] == 4'b1100)
			data_transfer_cnt <= 11'd6+11'd1;

		// read/write sector has SECTOR_SIZE data bytes
		if(cmd[7:6] == 2'b10)
			data_transfer_cnt <= SECTOR_SIZE + 1'd1;

		if(cmd[7:4] == 4'b1111) begin
			if(sector == 0) data_transfer_cnt <= SECTOR_SIZE + (fm ? 11'd74 : 11'd114); // 11'd32 + 11'd81 + 11'd1;  // 12/32 Bytes Index Mark Filler and 61/81 Bytes of non-data sector information (fm/mfm), +1 for counter offset
			else if(sector != (fd_spt -1)) data_transfer_cnt <= SECTOR_SIZE + (fm ? 11'd62 : 11'd82); //11'd81 + 11'd1; // If not last Sector on track, just add the 61/81 Bytes of sector information, +1 for counter offset
			else if(sector == (fd_spt -1)) data_transfer_cnt <= SECTOR_SIZE + 11'd302; // 11'd81 + 11'd218 + 11'd1; // Last Sector includes 240/218 bytes of Track End Filler, +1 for counter offset
			data_mark_found <= 0;
		end
		// write sector asserts drq earlier to fill up the data register in time
		if(cmd[7:5] == 3'b101 || cmd[7:4] == 4'b1111) drq_set <= !data_in_valid;
	end

	// advance fifo pointer when the write sector data consumed
	data_in_strobe <= 1'b0;
	if((cmd[7:5] == 3'b101 || cmd[7:4] == 4'b1111) && data_in_strobe) fifo_cpuptr <= fifo_cpuptr + 1'd1;

	if(fd_dclk_en) begin
		if(data_transfer_cnt != 0) begin
			if(data_transfer_cnt != 1) begin
				data_lost <= 1'b0;
				if (drq) data_lost <= 1'b1;
				// raise drq, except when the last byte is already taken from the CPU for write
				if (cmd[7:5] != 3'b101 || cmd[7:4] != 4'b1111 || data_transfer_cnt != 2) drq_set <= 1'b1;

				// read_address
				if(cmd[7:4] == 4'b1100) begin
					case(data_transfer_cnt)
						7: data_out <= fd_track;
//						6: data_out <= { 7'b0000000, fd1771 ^ floppy_side };
						6: data_out <= { 7'b0000000, 1'b1 ^ floppy_side };  //Myarc FDC seems to also reverses the floppy_side bit
						5: data_out <= fd_sector;
						4: data_out <= SECTOR_SIZE_CODE[7:0]; // TODO: sec size 0=128, 1=256, 2=512, 3=1024
						3: data_out <= 8'ha5;
						2: data_out <= 8'h5a;
					endcase // case (data_read_cnt)
				end

				// read sector
				if(cmd[7:5] == 3'b100 && fifo_cpuptr != SECTOR_SIZE) begin
					data_out <= fifo_q;
					fifo_cpuptr <= fifo_cpuptr + 1'd1;
				end
				// write sector
				if(cmd[7:5] == 3'b101 && fifo_cpuptr != SECTOR_SIZE) begin
					data_in_strobe <= 1;
					data_in_valid <= 0;
				end
				
				// Write Track
				if(cmd[7:4] == 4'b1111) begin
					case(data_in)
//						'hf7: begin
//							if(write_crc == 2'b00) begin
//								data_out <= 'ha4;
//								data_in_valid <= 0;
//								write_crc <= 2'b01;
//								drq_set <= 1'b0;	//Don't ask for a new byte till next round.
//							end
//							else if(write_crc == 2'b01) begin
//								data_out <= 'h0c;
//								data_in_valid <= 0;
//							end
//							data_transfer_cnt <= data_transfer_cnt + 1;
//						end
//						'hf8: begin
//							crc <= 'hFFFF;
//							data_in_valid <= 0;
//							data_transfer_cnt <= data_transfer_cnt + 11'd1;
//						end
//						'hf9: begin
//							crc <= 'hFFFF;
//							data_in_valid <= 0;
//							data_transfer_cnt <= data_transfer_cnt + 11'd1;
//							
//						end
//						'hfa: begin
//							crc <= 'hFFFF;
//							data_in_valid <= 0;
//							data_transfer_cnt <= data_transfer_cnt + 11'd1;
//						end
//						'hfb: begin
//							crc <= 'hFFFF;
//							data_in_valid <= 0;
//							data_transfer_cnt <= data_transfer_cnt + 11'd1;
//						end
//						'hfc: begin
//							data_in_valid <= 0;
//							data_transfer_cnt <= data_transfer_cnt + 11'd1;
//						end
//						'hfe: begin
//							crc <= 'hFFFF;
//							data_in_valid <= 0;
//							data_transfer_cnt <= data_transfer_cnt + 11'd1;
//						end
//						'h4e: begin
//							data_in_valid <= 0;
//							if(fm) begin
//								if (fifo_cpuptr < SECTOR_SIZE) data_in_strobe <= 1;
//								data_transfer_cnt <= data_transfer_cnt - 11'd1;
//							end
//						end
						'hf5, 'hf6, 'hf7: begin  // Not to be written to SD Card
							data_in_valid <= 0;
							data_transfer_cnt <= data_transfer_cnt - 11'd1;
//							if(sector == (fd_spt -1) && fifo_cpuptr == SECTOR_SIZE) begin
//								data_transfer_cnt <= data_transfer_cnt - 11'd1;
//							end
						end
						'hfb: begin
							data_in_valid <= 0;
//							if(data_mark_found && fifo_cpuptr < SECTOR_SIZE) data_in_strobe <= 1;
//							else data_mark_found <= 1;
							data_mark_found <= 1;
							data_transfer_cnt <= data_transfer_cnt - 11'd1;
						end
						'hf8, 'hf9,	'hfa,
						'hfc, 'hfe, 'hff: begin	// Not to be written to SD Card if in FM mode
							data_in_valid <= 0;
//							if(~fm) begin
//								if(data_mark_found) data_in_strobe <= 1;
//								if (fifo_cpuptr == SECTOR_SIZE) data_transfer_cnt <= 1;
//							end
								
							data_transfer_cnt <= data_transfer_cnt - 11'd1;
//							if(sector == (fd_spt -1) && fifo_cpuptr == SECTOR_SIZE) begin
//								data_transfer_cnt <= data_transfer_cnt - 11'd1;
//							end
						end
//						'hd7, 'he5: begin
//							data_in_strobe <= 1;
//							data_in_valid <= 0;
//							data_transfer_cnt <= data_transfer_cnt - 11'd1;
//						end
						default: begin
							if(data_mark_found && fifo_cpuptr < SECTOR_SIZE) data_in_strobe <= 1;
							data_in_valid <= 0;
							data_transfer_cnt <= data_transfer_cnt - 11'd1;
							//if(sector < (fd_spt -1) && fifo_cpuptr == SECTOR_SIZE && data_transfer_cnt > 15) data_transfer_cnt <= 15;
//							if (fifo_cpuptr == SECTOR_SIZE) data_transfer_cnt <= 1;
						end
//						default: begin
////							crc <= 'hFFFF;
//							data_in_valid <= 0;
//							if(sector == (fd_spt -1) && fifo_cpuptr == SECTOR_SIZE) begin
//								data_transfer_cnt <= 1;
//							end
//						end
					endcase
				end
				
			end

			// count down and stop after last byte
			if(cmd[7:4] != 4'b1111) data_transfer_cnt <= data_transfer_cnt - 11'd1;
			if(data_transfer_cnt == 1) begin
				if(cmd[7:4] == 4'b1111) begin
					drq_set <= 1'b1;
					data_in_valid <= 0;
				end
				data_transfer_done <= 1'b1;
			end
		end
	end
end

// the status byte
wire [7:0] status = { fd1771 ? !floppy_present : motor_on,
		      floppy_write_protected,              // wrprot
		      cmd_type_1?motor_spin_up_done:1'b0,  // data mark
		      RNF,                                 // seek error/record not found
		      1'b0,                                // crc error
		      cmd_type_1?fd_track0:data_lost,      // track0/data lost
		      cmd_type_1?~fd_index:drq,            // index mark/drq
		      busy  /* synthesis keep */};

reg [7:0] track /* verilator public */;
reg [7:0] sector;
reg [7:0] data_in;
reg [7:0] data_out;

reg step_dir;
reg motor_on /* verilator public */ = 1'b0;
reg data_lost;

// ---------------------------- command register -----------------------   
reg [7:0] cmd /* verilator public */;
wire cmd_type_1 = (cmd[7] == 1'b0);
wire cmd_type_2 = (cmd[7:6] == 2'b10);
wire cmd_type_3 = (cmd[7:5] == 3'b111) || (cmd[7:4] == 4'b1100);
wire cmd_type_4 = (cmd[7:4] == 4'b1101);

localparam FDC_REG_CMDSTATUS    = 0;
localparam FDC_REG_TRACK        = 1;
localparam FDC_REG_SECTOR       = 2;
localparam FDC_REG_DATA         = 3;

// CPU register read
always @(*) begin
	cpu_dout = 8'h00;

	if(cpu_sel && cpu_rw) begin
		case(cpu_addr)
			FDC_REG_CMDSTATUS: cpu_dout = status;
			FDC_REG_TRACK:     cpu_dout = track;
			FDC_REG_SECTOR:    cpu_dout = sector;
			FDC_REG_DATA:      cpu_dout = data_out;
		endcase
	end
end

// cpu register write
reg cmd_rx /* verilator public */;
reg cmd_rx_i;

always @(posedge clkcpu) begin
	if(!floppy_reset) begin
		// clear internal registers
		cmd <= 8'h00;
		track <= 8'h00;
		sector <= 8'h00;
		
		// reset state machines and counters
		cmd_rx_i <= 1'b0;
		cmd_rx <= 1'b0;
	end else begin

		// cmd_rx is delayed to make sure all signals (the cmd!) are stable when
		// cmd_rx is evaluated
		cmd_rx <= cmd_rx_i;

		// command reception is ack'd by fdc going busy
		if((!cmd_type_4 && busy) || (clk8m_en && cmd_type_4 && !busy)) cmd_rx_i <= 1'b0;

		// only react if stb just raised
		if(cpu_we) begin
			if(cpu_addr == FDC_REG_CMDSTATUS) begin       // command register
				cmd <= cpu_din;
				cmd_rx_i <= 1'b1;
				// ------------- TYPE I commands -------------
				if(cpu_din[7:4] == 4'b0000) begin               // RESTORE
					if(track != 0 ) begin
						track <= 8'hFF;
					end
					step_to <= 8'd0;
					data_in <= 0;
				end

				if(cpu_din[7:4] == 4'b0001) begin               // SEEK
					step_to <= data_in;
				end

				if(cpu_din[7:5] == 3'b001) begin                // STEP
				end

				if(cpu_din[7:5] == 3'b010) begin                // STEP-IN
				end

				if(cpu_din[7:5] == 3'b011) begin                // STEP-OUT
				end

				// ------------- TYPE II commands -------------
				if(cpu_din[7:5] == 3'b100) begin                // read sector
				end

				if(cpu_din[7:5] == 3'b101) begin                // write sector
				end

				// ------------- TYPE III commands ------------
				if(cpu_din[7:4] == 4'b1100) begin               // read address
//					sector <= fd_track;
				end

				if(cpu_din[7:4] == 4'b1110) begin               // read track
				end

				if(cpu_din[7:4] == 4'b1111) begin               // write track
					sector <= 8'h00;	//Start at sector 0 of current track
				end

				// ------------- TYPE IV commands -------------
				if(cpu_din[7:4] == 4'b1101) begin               // force intrerupt
				end
			end

			if(cpu_addr == FDC_REG_TRACK)                    // track register
				track <= cpu_din;

			if(cpu_addr == FDC_REG_SECTOR)                   // sector register
				sector <= cpu_din;

			if(cpu_addr == FDC_REG_DATA) begin               // data register
				data_in <= cpu_din;
			end
		end

		if (sector_clear_strobe) sector <= 1'd0;
		if (sector_inc_strobe) sector <= sector + 1'd1;
		if (track_inc_strobe) track <= track + 1'd1;
		if (track_dec_strobe) track <= track - 1'd1;
		if (track_clear_strobe) track <= 8'd0;
		if (track_to_sector) sector <= track;
	end
end

endmodule

module fdc1772_dpram #(parameter DATAWIDTH=8, ADDRWIDTH=9)
(
	input                   clock,

	input   [ADDRWIDTH-1:0] address_a,
	input   [DATAWIDTH-1:0] data_a,
	input                   wren_a,
	output reg [DATAWIDTH-1:0] q_a,

	input   [ADDRWIDTH-1:0] address_b,
	input   [DATAWIDTH-1:0] data_b,
	input                   wren_b,
	output reg [DATAWIDTH-1:0] q_b
);

reg [DATAWIDTH-1:0] ram[0:(1<<ADDRWIDTH)-1];

always @(posedge clock) begin
	if(wren_a) begin
		ram[address_a] <= data_a;
		q_a <= data_a;
	end else begin
		q_a <= ram[address_a];
	end
end

always @(posedge clock) begin
	if(wren_b) begin
		ram[address_b] <= data_b;
		q_b <= data_b;
	end else begin
		q_b <= ram[address_b];
	end
end

endmodule

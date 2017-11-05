//============================================================================
//  ColecoVision
//
//  Port to MiSTer
//  Copyright (C) 2017 Sorgelig
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [43:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	output  [7:0] VIDEO_ARX,
	output  [7:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status ORed with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S, // 1 - signed audio samples, 0 - unsigned
	input         TAPE_IN,

	// SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE
);

assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = 0;
 
assign LED_USER  = ioctl_download;
assign LED_DISK  = 0;
assign LED_POWER = 0;

assign VIDEO_ARX = status[1] ? 8'd16 : 8'd4;
assign VIDEO_ARY = status[1] ? 8'd9  : 8'd3; 

`include "build_id.v" 
parameter CONF_STR = {
	"Coleco;;",
	"-;",
	"F,COLBIN;",
	"-;",
	"O1,Aspect ratio,4:3,16:9;",
	"-;",
	"T6,Reset;",
	"-;",
	"-;",
	"-;",
	"-;",
	"J,Fire 1,Fire 2,*,#,0,1,2,3,Purple Tr,Blue Tr;",
	"V,v1.00.",`BUILD_DATE
};

/////////////////  CLOCKS  ////////////////////////

wire clk_sys;
wire pll_locked;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_sys),
	.locked(pll_locked)
);

reg ce_10m7 = 0;
always @(posedge clk_sys) ce_10m7 <= ~ce_10m7;

/////////////////  HPS  ///////////////////////////

wire [31:0] status;
wire  [1:0] buttons;

wire [15:0] joya, joyb;
wire [65:0] ps2_key;

wire        ioctl_download;
wire  [7:0] ioctl_index;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;

hps_io #(.STRLEN($size(CONF_STR)>>3)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.conf_str(CONF_STR),

	.buttons(buttons),
	.status(status),
	
	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_index),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),

	.ps2_key(ps2_key),

	.joystick_0(joya),
	.joystick_1(joyb)
);

/////////////////  RESET  /////////////////////////

wire reset = RESET | status[0] | buttons[1] | status[6] | ioctl_download;

/////////////////  Memory  ////////////////////////

wire [12:0] bios_a;
wire  [7:0] bios_d;

sprom #("bios.hex", 13) rom
(
	.clock(clk_sys),
   .address(bios_a),
   .q(bios_d)
);

wire  [9:0] ram_a;
wire        ram_we_n, ram_ce_n;
wire  [7:0] ram_di;
wire  [7:0] ram_do;

spram #(10) ram
(
	.clock(clk_sys),
	.address(ram_a),
	.wren(ce_10m7 & ~(ram_we_n | ram_ce_n)),
	.data(ram_do),
	.q(ram_di)
);

wire [13:0] vram_a;
wire        vram_we;
wire  [7:0] vram_di;
wire  [7:0] vram_do;

spram #(14) vram
(
	.clock(clk_sys),
	.address(vram_a),
	.wren(vram_we),
	.data(vram_do),
	.q(vram_di)
);

wire [14:0] cart_a;
wire  [7:0] cart_d;

dpram #(15) cart
(
	.clk_a_i(clk_sys),
	.we_i(ioctl_wr && !ioctl_addr[24:15]),
	.addr_a_i(ioctl_addr[14:0]),
	.data_a_i(ioctl_dout),

	.clk_b_i(clk_sys),
	.addr_b_i(cart_a),
	.data_b_o(cart_d)
);

////////////////  Console  ////////////////////////

wire [7:0] audio;
assign AUDIO_L = {audio,8'd0};
assign AUDIO_R = {audio,8'd0};
assign AUDIO_S = 1;

assign CLK_VIDEO = clk_sys;
assign CE_PIXEL = ce_10m7;

wire [1:0] ctrl_p1;
wire [1:0] ctrl_p2;
wire [1:0] ctrl_p3;
wire [1:0] ctrl_p4;
wire [1:0] ctrl_p5;
wire [1:0] ctrl_p6;
wire [1:0] ctrl_p7 = 2'b11;
wire [1:0] ctrl_p8;
wire [1:0] ctrl_p9 = 2'b11;

cv_console console
(
	.clk_i(clk_sys),
	.clk_en_10m7_i(ce_10m7),
	.reset_n_i(~reset),
	.por_n_o(),

	.ctrl_p1_i(ctrl_p1),
	.ctrl_p2_i(ctrl_p2),
	.ctrl_p3_i(ctrl_p3),
	.ctrl_p4_i(ctrl_p4),
	.ctrl_p5_o(ctrl_p5),
	.ctrl_p6_i(ctrl_p6),
	.ctrl_p7_i(ctrl_p7),
	.ctrl_p8_o(ctrl_p8),
	.ctrl_p9_i(ctrl_p9),

	.bios_rom_a_o(bios_a),
	.bios_rom_d_i(bios_d),

	.cpu_ram_a_o(ram_a),
	.cpu_ram_we_n_o(ram_we_n),
	.cpu_ram_ce_n_o(ram_ce_n),
	.cpu_ram_d_i(ram_di),
	.cpu_ram_d_o(ram_do),

	.vram_a_o(vram_a),
	.vram_we_o(vram_we),
	.vram_d_o(vram_do),
	.vram_d_i(vram_di),

	.cart_a_o(cart_a),
	.cart_d_i(cart_d),

	.rgb_r_o(VGA_R),
	.rgb_g_o(VGA_G),
	.rgb_b_o(VGA_B),
	.hsync_n_o(VGA_HS),
	.vsync_n_o(VGA_VS),
	.blank_n_o(VGA_DE),

	.audio_o(audio)
);

////////////////  Control  ////////////////////////

wire pressed    = (ps2_key[15:8] != 8'hf0);
wire extended   = (~pressed ? (ps2_key[23:16] == 8'he0) : (ps2_key[15:8] == 8'he0));
wire [8:0] code = ps2_key[63:24] ? 9'd0 : {extended, ps2_key[7:0]}; // filter out PRNSCR and PAUSE
always @(posedge clk_sys) begin
	reg old_state;
	old_state <= ps2_key[64];
	
	if(old_state != ps2_key[64]) begin
		casex(code)
			'hX75: btn_up    <= pressed;
			'hX72: btn_down  <= pressed;
			'hX6B: btn_left  <= pressed;
			'hX74: btn_right <= pressed;
			'hX16: btn_1     <= pressed; // 1
			'hX1E: btn_2     <= pressed; // 2
			'hX26: btn_3     <= pressed; // 3
			'hX15: btn_4     <= pressed; // q
			'hX1D: btn_5     <= pressed; // w
			'hX24: btn_6     <= pressed; // e
			'hX1C: btn_7     <= pressed; // a
			'hX1B: btn_8     <= pressed; // s
			'hX23: btn_9     <= pressed; // d
			'hX1A: btn_s     <= pressed; // z
			'hX22: btn_0     <= pressed; // x
			'hX21: btn_p     <= pressed; // c
			'hX1F: btn_pt    <= pressed; // gui l
			'hX27: btn_pt    <= pressed; // gui r
			'hX11: btn_bt    <= pressed; // alt

			'hX25: btn_4     <= pressed; // 4
			'hX2E: btn_5     <= pressed; // 5
			'hX36: btn_6     <= pressed; // 6
			'hX3D: btn_7     <= pressed; // 7
			'hX3E: btn_8     <= pressed; // 8
			'hX46: btn_9     <= pressed; // 9
			'hX45: btn_0     <= pressed; // 0

			'h012: btn_arm   <= pressed; // shift l
			'h059: btn_arm   <= pressed; // shift r
			'hX14: btn_fire  <= pressed; // ctrl
		endcase
	end
end

reg btn_up    = 0;
reg btn_down  = 0;
reg btn_left  = 0;
reg btn_right = 0;
reg btn_1     = 0;
reg btn_2     = 0;
reg btn_3     = 0;
reg btn_4     = 0;
reg btn_5     = 0;
reg btn_6     = 0;
reg btn_7     = 0;
reg btn_8     = 0;
reg btn_9     = 0;
reg btn_s     = 0;
reg btn_0     = 0;
reg btn_p     = 0;
reg btn_pt    = 0;
reg btn_bt    = 0;
reg btn_arm   = 0;
reg btn_fire  = 0;

wire m_right  = btn_right | joya[0];
wire m_left   = btn_left  | joya[1];
wire m_down   = btn_down  | joya[2];
wire m_up     = btn_up    | joya[3];
wire m_fire   = btn_fire  | joya[4];
wire m_arm    = btn_arm   | joya[5];
wire m_1      = btn_1     | joya[9];
wire m_2      = btn_2     | joya[10];
wire m_3      = btn_3     | joya[11];
wire m_s      = btn_s     | joya[6];
wire m_0      = btn_0     | joya[8];
wire m_p      = btn_p     | joya[7];
wire m_pt     = btn_pt    | joya[12];
wire m_bt     = btn_bt    | joya[13];

wire [0:19] keypad0 = {m_0,m_1,m_2,m_3,btn_4,btn_5,btn_6,btn_7,btn_8,btn_9,m_s,m_p,m_pt,m_bt,m_up,m_down,m_left,m_right,m_fire,m_arm};
wire [0:19] keypad1 = {joyb[8],joyb[9],joyb[10],joyb[11],1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,joyb[6],joyb[7],joyb[12],joyb[13],joyb[3],joyb[2],joyb[1],joyb[0],joyb[4],joyb[5]};
wire [0:19] keypad[2] = '{keypad0,keypad1};

reg [3:0] ctrl1[2] = '{'0,'0};
assign {ctrl_p1[0],ctrl_p2[0],ctrl_p3[0],ctrl_p4[0]} = ctrl1[0];
assign {ctrl_p1[1],ctrl_p2[1],ctrl_p3[1],ctrl_p4[1]} = ctrl1[1];

localparam cv_key_0_c        = 4'b0011;
localparam cv_key_1_c        = 4'b1110;
localparam cv_key_2_c        = 4'b1101;
localparam cv_key_3_c        = 4'b0110;
localparam cv_key_4_c        = 4'b0001;
localparam cv_key_5_c        = 4'b1001;
localparam cv_key_6_c        = 4'b0111;
localparam cv_key_7_c        = 4'b1100;
localparam cv_key_8_c        = 4'b1000;
localparam cv_key_9_c        = 4'b1011;
localparam cv_key_asterisk_c = 4'b1010;
localparam cv_key_number_c   = 4'b0101;
localparam cv_key_pt_c       = 4'b0100;
localparam cv_key_bt_c       = 4'b0010;
localparam cv_key_none_c     = 4'b1111;

generate 
	genvar i;
	for (i = 0; i <= 1; i++) begin : ctl
		always_comb begin
			reg [3:0] ctl1, ctl2;
			reg p61,p62;
			
			ctl1 = 4'b1111;
			ctl2 = 4'b1111;
			p61 = 1;
			p62 = 1;

			if (~ctrl_p5[i]) begin
				casex(keypad[i][0:13]) 
					'b1xxxxxxxxxxxxx: ctl1 = cv_key_0_c;
					'b01xxxxxxxxxxxx: ctl1 = cv_key_1_c;
					'b001xxxxxxxxxxx: ctl1 = cv_key_2_c;
					'b0001xxxxxxxxxx: ctl1 = cv_key_3_c;
					'b00001xxxxxxxxx: ctl1 = cv_key_4_c;
					'b000001xxxxxxxx: ctl1 = cv_key_5_c;
					'b0000001xxxxxxx: ctl1 = cv_key_6_c;
					'b00000001xxxxxx: ctl1 = cv_key_7_c;
					'b000000001xxxxx: ctl1 = cv_key_8_c;
					'b0000000001xxxx: ctl1 = cv_key_9_c;
					'b00000000001xxx: ctl1 = cv_key_asterisk_c;
					'b000000000001xx: ctl1 = cv_key_number_c;
					'b0000000000001x: ctl1 = cv_key_pt_c;
					'b00000000000001: ctl1 = cv_key_bt_c;
					'b00000000000000: ctl1 = cv_key_none_c;
				endcase
				p61 = ~keypad[i][19]; // button 2
			end

			if (~ctrl_p8[i]) begin
				ctl2 = ~keypad[i][14:17];
				p62 = ~keypad[i][18];  // button 1
			end
			
			ctrl1[i] = ctl1 & ctl2;
			ctrl_p6[i] = p61 & p62;
		end
	end
endgenerate


endmodule

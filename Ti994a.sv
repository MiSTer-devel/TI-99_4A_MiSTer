//============================================================================
//  TI-99 4A
//
//  Port to MiSTer
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
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE,

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM (USE_FB=1 in qsf)
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

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
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

assign ADC_BUS = 'Z;
//assign USER_OUT = '1;
assign USER_OUT[1] = 1'b1;
assign USER_OUT[2] = 1'b1;
assign USER_OUT[3] = 1'b1;
assign USER_OUT[5] = 1'b1;
assign USER_OUT[6] = 1'b1;

assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = 0;
//assign {SDRAM_CLK, SDRAM_CKE, SDRAM_A, SDRAM_BA, SDRAM_DQML, SDRAM_DQMH, SDRAM_nCS, SDRAM_nCAS, SDRAM_nWE} = 'z;
assign VGA_SCALER = 0;
assign HDMI_FREEZE = 0;

// number of blocks-1, total size ((sd_blk_cnt+1)*(1<<(BLKSZ+7))) must be <= 16384!
// Not used at the moment so setting everything to 0.
assign sd_blk_cnt[0] = 6'd0;
assign sd_blk_cnt[1] = 6'd0;
assign sd_blk_cnt[2] = 6'd0;
assign sd_blk_cnt[3] = 6'd0;

assign VGA_DISABLE = 1'b0;


assign LED_USER  = ioctl_download | drive_led | loading_nv;
assign LED_DISK  = 0;
assign LED_POWER = 0;
assign BUTTONS   = osd_btn;
assign ps2_kbd_led_status[0] = btn_al;			// Synch Alpha Lock with Caps Lock LED
assign ps2_kbd_led_status[1] = 0;
assign ps2_kbd_led_status[2] = drive_led;    // Use the Scroll Lock LED for Floppy Activity


//assign VIDEO_ARX = status[1] ? 8'd16 : 8'd4;
//assign VIDEO_ARY = status[1] ? 8'd9  : status[13] ? 8'd4 : 8'd3; 

// Status Bit Map:
//              Upper                          Lower
// 0         1         2         3          4         5         6
// 01234567890123456789012345678901 23456789012345678901234567890123
// 0123456789ABCDEFGHIJKLMNOPQRSTUV 0123456789ABCDEFGHIJKLMNOPQRSTUV
// XX XXXXXXXXXXXXXXXXXXXXXXXXXXXXX                             XX

// IOCTL INDEX
// 0	- Boot.rom
// 1	- Full
// 2	- Cart (C/D)
// 3	- Grom (G)
// 4	- 
// 5	- System Grom
// 6	- System Rom
// 7	- Speech Rom
// 8	- TI-Disk DSR
// 9	- Tipi DSR
//
`include "build_id.v" 
parameter CONF_STR = {
	"TI-99_4A;;",
	"F1,M99BIN,Load Full Cart;",
	"F2,BIN,Load Rom Cart;",
	"F3,BIN,Load Grom Cart;",
	"d6S0,DSK,Drive 1;",
	"d6S1,DSK,Drive 2;",
	"d6S2,DSK,Drive 3;",
	"h2OS,TIFDC Disk Speed,Normal,Turbo;",
	"h3P4,MyArc FDC Dip Switches;",
	"P4OS,MyArc Disk Speed,Normal,Turbo;",
	"H4P4OT,Drive 1 Seek Speed,6ms,20/2ms;",
	"H4P4OU,Drive 2 Seek Speed,6ms,20/2ms;",
	"H4P4OV,Drive 3 Seek Speed,6ms,20/2ms;",
	"h4P4OT,Drive 1 Drive Type,5-1/4\",3-1/2\";",
	"h4P4OU,Drive 2 Drive Type,5-1/4\",3-1/2\";",
	"h4P4OV,Drive 3 Drive Type,5-1/4\",3-1/2\";",
	"-;",
	"OIK,Cart Type,Normal,MBX,Paged7,Paged378,Paged379,MiniMem;",	//Normal = 0, MBX = 1, Paged7 = 2, UberGrom = 3, Paged378 = 4, MiniMem = 5
	"H0P1,Mini Mem;",
	"P1S3,DAT,NVRAM File;",
	"D5P1rS,Load NVRAM;",
	"D5P1rT,Save NVRAM;",

	"P2,Video Settings;",
	"P2OD,Video Mode,NTSC, PAL;",
	"P2O79,Scandoubler Fx,None,HQ2x-320,CRT 25%,CRT 50%,CRT 75%;",
	"P2O56,Scale,Normal,V-Integer,Narrower HV-Integer,Wider HV-Integer;",
	"P2O1,Aspect Ratio,Original,Full Screen;",
	"D1P2OL,Vertical Crop,No,Yes;",
	
	"P3,Hardware;",
	"P3OA,Turbo,Off,On;",
	"P3OE,Scratchpad RAM,256B,1KB;",
	"P3OGH,Speech,Off,5220,5200;",
	"P3OF,Alpha Lock on Power Up, Off, On;",
	"P3OM,SAMS Memory,Disabled,Enabled;",
	"P3ON,TiPi,Disabled,Enabled;",
	"P3OOP,TiPi CRU Base,1000,1100,1200,1400;",
	"P3OQ,PCode,Disabled,Enabled;",
	"P3-;",
	"P3FC4,BIN,Select System Grom;",
	"P3FC5,BIN,Select System Rom ;",
	"P3FC6,BIN,Select Speech Rom ;",
	"P3FC7,BIN,Select Disk DSR   ;",
	"P3FC8,BIN,Select TIPI DSR   ;",		//File is 32k but only 4k is used.  So ignore anyting over x1000
	"P3FC9,BIN,Select P-Code Rom ;",		//Index 10 since it's the 11th menu item
	"-;",
	"OC,Arrow Keys,Cursor, Joystick;",
	"OB,Swap joysticks,NO,YES;",
	"o01,Mouse,Disabled,Mechatronics,Joy1,Joy2;",
//	"-;",
//	"oA,Pause When OSD is Open,No,Yes;",
	"RR,Reset & Detach Cart;",
	"R0,Reset;",
	"-;",
	"J,Fire 1,Fire 2,1,2,3,Enter,Back,Redo;",
	"V,v",`BUILD_DATE
};

wire reset_osd  = status[0];
wire turbo      = status[10];
wire joy_swap   = status[11];
wire virt_joy   = status[12];
wire is_pal     = status[13];
wire scratch_1k = status[14];
wire [1:0] speech_mod = ~status[17:16];
// Switches are: 63 CPU Wait States, 31 CPU Wait States (if turbo is on we have to use 31), 8 CPU Wait States
wire [2:0] optSWI= {1'b0, 1'b1 , 1'b0};	//Currently using 31 cpu wait states as required for SDRAM to work right
wire sams_en    = status[22];
// Tipi
wire tipi_en    = status[23];
// Tipi CRU Base options at the moment are 1000, 1100, 1200 and 1400.  Can be expanded or hard coded for 1000 - 1F00, just set tipi_crubase to 0 thru F
wire [3:0] tipi_crubase = (status[25:24] == 2'b11) ?  4'b0100 : status[25:24];

//wire myarc_en   = (disk_dsr_hash == 'h6C || disk_dsr_hash == 'h6B);
wire myarc_en   = (disk_dsr_hash == 'h6C);
wire myarc80    = (disk_dsr_hash == 'h6B);
wire [1:0] mecmouse_en = status[33:32];

//Bring up OSD when no system/boot rom is loaded - copied from Megadrive/Genesis core
reg osd_btn = 0;
wire first_boot;

always @(posedge clk_sys) begin
	integer timeout = 0;
	reg     has_bootrom = 0;
	reg     last_rst = 0;

	if (RESET) first_boot <= 1;
	if (btn_al & first_boot) first_boot <= 0;

	if (RESET) last_rst = 0;
	if (status[0]) last_rst = 1;

	if (ioctl_wr & status[0]) has_bootrom <= 1;

	if(last_rst & ~status[0]) begin
		osd_btn <= 0;
		if(timeout < 24000000) begin
			timeout <= timeout + 1;
			osd_btn <= ~has_bootrom;
		end
	end
end

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
reg ce_5m3 = 0;
always @(posedge clk_sys) begin
	reg [2:0] div;
	
	div <= div+1'd1;
	ce_10m7 <= !div[1:0];
	ce_5m3  <= !div[2:0];
end

/////////////////  HPS  ///////////////////////////

wire [63:0] status;
wire [63:0] status_o;		//So we can update OCD Settings on the fly
wire			status_update;	//Trigger the status update
wire [15:0] status_mask = {fdc_en, ~nv_file_valid, myarc80, (myarc_en || myarc80) && fdc_en, fdc_en && ~myarc_en && ~myarc80, scandoubler, cart_type !=5};
wire  [1:0] buttons;

wire [31:0] joy0, joy1;
wire [10:0] ps2_key;
wire  [2:0] ps2_kbd_led_use = { 1'b1, 1'b0, 1'b1};
wire  [2:0] ps2_kbd_led_status;
wire [24:0] ps2_mouse;


wire        ioctl_download;
wire  [7:0] ioctl_index;
wire        ioctl_wr;
wire [26:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire        forced_scandoubler;
wire [21:0] gamma_bus;

wire [31:0] sd_lba[4];
wire	[5:0] sd_blk_cnt[4];

wire  [3:0] sd_rd;
wire  [3:0] sd_wr;
wire  [3:0] sd_ack;
wire  [8:0] sd_buff_addr;
wire  [7:0] sd_buff_dout;
wire  [7:0] sd_buff_din[4];
wire        sd_buff_wr;	//sd_dout_strobe
wire  [3:0] img_mounted;
wire [31:0] img_size;
wire  [2:0]	cart_type = status[20:18];
wire [31:0] img_ext;
wire        fdc_en = ~(tipi_en == 1'b1 && tipi_crubase == 4'b0001) && disk_dsr_hash != 0;

hps_io #(.CONF_STR(CONF_STR), .VDNUM(4), .BLKSZ(1)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.buttons(buttons),
	.status(status),
	.status_in(status_o),
	.status_set(status_update),
	.status_menumask(status_mask),
	.forced_scandoubler(forced_scandoubler),
	.gamma_bus(gamma_bus),

	.sd_lba(sd_lba),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din(sd_buff_din),
	.sd_buff_wr(sd_buff_wr),
   .sd_blk_cnt(sd_blk_cnt), 		// number of blocks-1, total size ((sd_blk_cnt+1)*(1<<(BLKSZ+7))) must be <= 16384!

	.img_mounted(img_mounted),
	.img_size(img_size),

	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_index),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_file_ext(img_ext),
	
	.ps2_key(ps2_key),
	.ps2_kbd_led_use(ps2_kbd_led_use),
	.ps2_kbd_led_status(ps2_kbd_led_status),
	.ps2_mouse(ps2_mouse),

	.joystick_0(joy0),
	.joystick_1(joy1)
);

/////////////////  RESET  /////////////////////////

// reset after download
reg [7:0] download_reset_cnt;
wire download_reset = download_reset_cnt != 0;
always @(posedge CLK_50M) begin
	if(ioctl_download || reset_osd || buttons[1] || RESET || erasing) download_reset_cnt <= 8'd255;
	else if(download_reset_cnt != 0) download_reset_cnt <= download_reset_cnt - 8'd1;
end

// hold machine in reset until first download starts
reg init_reset;
always @(posedge CLK_50M) begin
	if(!pll_locked) init_reset <= 1'b1;
	else if(ioctl_download) init_reset <= 1'b0;
end

wire reset = (init_reset || buttons[1] || RESET || reset_osd | ioctl_download | erasing);


///////////////// Erase Cart Storage /////////////////
reg erasing;
wire [26:0] erase_addr;
wire        erase_wr;

always @(posedge clk_sys) begin
	reg old_clear = 0;
	old_clear <= status[27];
	if (~old_clear & status[27]) begin
		erasing <= 1;
		erase_addr <= 0;
	end
	if(erasing == 1) begin
		if(sdram_ready && ~erase_wr) begin
			if(erase_addr >= 27'h0 && erase_addr <= 27'hFDFFE) begin
				if(erase_addr == 27'h7FFFF) erase_addr <= 27'h86000;			//After clearing Cart Rom Area 0x00000..0x7FFFF, move over to Grom Area
				else if(erase_addr == 27'h9FFFF) erase_addr <= 27'hFD000;	//After clearing Grom Area, move over to Scratch Pad
				else erase_addr <= erase_addr + 8'd1;
				erase_wr <= 1;
			end
			else begin
				erasing <= 0;
				erase_wr <= 0;
			end
		end
		else erase_wr <= 0;
	end
end


/////////////////  OSD Status Update //////////////
always @(posedge clk_sys) begin
	reg downloading = 0;

	status_update = 0;
	downloading <= ioctl_download;
	//IF we loaded a M99 file then update the Cartridge Type
	if((ioctl_index == 0 || ioctl_index == 1) && valid_m99 == 1 && (downloading && ioctl_download == 0)) begin
		status_o = status;
		status_o[20:18] = m99CartType[2:0];
		status_update = 1;
	end
	//If a reset and detach cart signal is detected, reset the Cart Type to 0 "Normal/Standard"
	if(status[27]) begin
		status_o = status;
		status_o[27]= 'b0;		//Don't want to save the reset and detach cart signal and restore it.
		status_o[20:18] = 'd0;
		status_update = 1;
	end

end
/////////////////  Memory  ////////////////////////

wire [14:0] speech_a;
wire  [7:0] speech_d;
wire [14:0] speechrom_a;

assign speechrom_a = ioctl_download && (ioctl_index == 6 || legacy_speech) ? ioctl_addr[14:0] : speech_a;

spram #(15) speechrom
(
	.clock(clk_sys),
	.wren((ioctl_index == 6 || legacy_speech) ? ioctl_wr : 0),
	.data(ioctl_dout),
	.address(speechrom_a),
	.q(speech_d)
);


// 17x16 bit address = 256K
wire  [24:0] ram_a;
wire        ram_we_n, ram_ce_n;
wire  [15:0] ram_di;
wire  [15:0] sdram_din;
wire  [15:0] ram_do;
wire  [1:0] ram_be_n;

reg   [27:0] download_addr;
reg	[24:0] download_offset;
reg   [27:0] cart_size;
reg   [19:0] cart_8k_banks;

reg	legacy_rom = 1'b0;
reg	legacy_speech = 1'b0;
reg	valid_m99 = 1'b0;
reg	[15:0] autoloaded_roms = 16'h0000;
reg	[23:0] m99Sig =24'd0;
reg	[7:0]  m99Ver = 'd0;
reg	[7:0]  m99CartType = 'd0;
reg	[15:0]  m99RomBlks = 'd0;
reg	[15:0]  m99Groms = 'd0;
reg   [7:0] disk_dsr_hash = 8'd0;

//Determine where in ram to store the downloaded data based on IOCTL_INDEX
always @(posedge clk_sys) begin

	sdram_we = ioctl_wr;
	
	
	case(ioctl_index)
		0,1,'h41:											//boot.rom and M99
			begin
				sdram_we = 0;
				legacy_speech = 0;
				if(ioctl_addr == 0) begin
					if(ioctl_dout != 8'h4D) legacy_rom = 1;
					else legacy_rom = 0;
				end
				if(legacy_rom) begin
					if(ioctl_addr >= 28'h0 && ioctl_addr <= 28'hFFFF) begin
						download_addr = ioctl_addr;
						sdram_we = ioctl_wr;
					end
					else if(ioctl_addr >= 28'h10000 && ioctl_addr <=28'h15FFF && ~autoloaded_roms[0]) begin
						download_addr = ioctl_addr + 23'h80000;
						sdram_we = ioctl_wr;
					end
					else if(ioctl_addr >= 28'h16000 && ioctl_addr <= 28'h1FFFF) begin
						download_addr = ioctl_addr - 28'h16000 + 23'h86000;
						sdram_we = ioctl_wr;
					end
					else if(ioctl_addr >= 28'h20000 && ioctl_addr <=28'h29FFF && ~autoloaded_roms[3]) begin
						download_addr = ioctl_addr - 28'h20000 + 23'hB0000;
						sdram_we = ioctl_wr;
					end
					else if(ioctl_addr >= 28'h2A000 && ioctl_addr <=28'h2FFFF && ~autoloaded_roms[1]) begin
						download_addr = ioctl_addr - 28'h2A000 + 23'hFE000;
						sdram_we = ioctl_wr;
					end
					else if(ioctl_addr >= 28'h40000 && ioctl_addr <=28'h47FFF && ~autoloaded_roms[2]) begin
						legacy_speech=1;
					end
					
				end
				else if(ioctl_addr >= 28'h0 && ioctl_addr <= 28'h63) begin
				
					
					if(ioctl_addr >= 28'h0 && ioctl_addr <= 28'd2) begin
						if(ioctl_addr == 28'h0) m99Sig[23:16] = ioctl_dout;
						else if(ioctl_addr == 28'h1) m99Sig[15:8] = ioctl_dout;
						else if(ioctl_addr == 28'h2) m99Sig[7:0] = ioctl_dout;
						if(ioctl_addr == 28'd2) valid_m99 = m99Sig == 24'h4D3939 ? 1'b1 : 1'b0;
					end
					
					else if(valid_m99 == 1'b1) begin
						if(ioctl_addr == 28'h3) m99Ver = ioctl_dout;
						else if(ioctl_addr == 28'h4) m99CartType = ioctl_dout;
						else if(ioctl_addr == 28'h5) m99RomBlks[15:8] = ioctl_dout;
						else if(ioctl_addr == 28'h6) m99RomBlks[7:0] = ioctl_dout;
						else if(ioctl_addr == 28'h7) m99Groms[15:8] = ioctl_dout;
						else if(ioctl_addr == 28'h8) m99Groms[7:0] = ioctl_dout;
						// 7-27	:	RESERVED-Future Expansion
						// 28-67	:	Title (40 bytes)
						// 68-87	:	Manufacturer (20 bytes)
						//	88-97	:	Serial #	(10 bytes)
						else if(ioctl_addr == 28'h62) valid_m99 = ioctl_dout == 'hFF ? 1'b1 : 1'b0;
						else if(ioctl_addr == 28'h63) valid_m99 = ioctl_dout == 'hFF ? 1'b1 : 1'b0;
					end
				end
				else if(valid_m99 == 1'b1) begin
					if(m99RomBlks > 0) begin
						if(ioctl_addr <= (m99RomBlks * 28'h4000)) begin
							download_addr = ioctl_addr - 28'h64;
							if(download_addr >= 28'h80000) begin	//Anything over 512K goes to SDRAM above SAMS RAM (above x1FFFFF). Therefore offset is x180000
								download_addr = download_addr + 28'h180000;
							end
							sdram_we = ioctl_wr;
						end
					end
					if(m99Groms > 0) begin
						if((ioctl_addr - 28'h64) >= (m99RomBlks * 25'h2000) && (ioctl_addr - 25'h64) <= ((m99Groms * 24'h2000)+(m99RomBlks * 25'h2000))) begin
							download_addr = ioctl_addr - 28'h64 - (m99RomBlks * 25'h2000) + 25'h86000;
							sdram_we = ioctl_wr;
						end
					end
				end
			end
		2: 										//Rom only Cart
			begin
				download_addr = ioctl_addr;
				if(ioctl_addr >= 28'h80000) begin
					download_addr = ioctl_addr + 28'h180000;
				end
			end
		3:											//Grom only cart
			begin
				download_addr = ioctl_addr + 23'h86000;
				if(ioctl_addr >= 28'h2A000) sdram_we = 0;		//Stop loading anything over 172k
			end
		4:											//System Grom
			begin
				autoloaded_roms[0]=1;
				download_addr = ioctl_addr + 23'h80000;
				if(ioctl_addr >= 28'h6000) sdram_we = 0;		//Stop loading anything over 24k
			end
		5:											//System Rom
			begin
				autoloaded_roms[1]=1;
				download_addr = ioctl_addr + 23'hFE000;
				if(ioctl_addr >= 28'h2000) sdram_we = 0;		//Stop loading anything over 8k
			end
				
		6:	
			begin
				autoloaded_roms[2]=1;
				sdram_we = 0;												//Speech Rom not going to SDRAM so don't download into SDRAM
			end
		7:											//Disk DSR
			begin
				autoloaded_roms[3]=1;
				download_addr = ioctl_addr + 23'hB0000;
				if(ioctl_addr >= 28'h8000) sdram_we = 0;		//Stop loading anything over 32k.
			end
		8:											//Tipi DSR
			begin
				autoloaded_roms[4]=1;
				download_addr = ioctl_addr + 23'hB8000;
				if(ioctl_addr >= 28'h1000) sdram_we = 0;		//Stop loading anything over 4k.
			end
		9:											//PCode DSR/Grom 
			begin
				autoloaded_roms[5]=1;
				download_addr = ioctl_addr + 23'hB9000;
				if(ioctl_addr >= 28'h13000) sdram_we = 0;		//Stop loading anything over 76k.
			end

		default:	download_addr = ioctl_addr;
	endcase
	download_addr[0] = ~download_addr[0];
end

wire [25:0] sdram_addr;
wire  [6:1] rommask_s;
reg	sdram_we;


assign SDRAM_CLK = ~clk_sys;
sdram sdram
(
	.*,
	
	.init(~pll_locked),
	.clk(clk_sys),

   .wtbt((ioctl_download || nvram_en || erasing) ? 2'b0 : ~ram_be_n),
   .addr(loading_nv ? nvram_addr : saving_nv? nvram_save_addr : erasing ? erase_addr : sdram_addr),
   .rd(saving_nv? nvram_rd_strobe : ~ram_ce_n),
   .dout(sdram_din),
   .din(ioctl_download? {ioctl_dout,ioctl_dout} : nvram_en ? {nv_dout, nv_dout} : erasing ? 16'h0000 : ram_do),
   .we(ioctl_download ? sdram_we : nvram_en ? nv_buff_wr & nv_ack : erasing ? erase_wr : ~ram_we_n),
   .ready(sdram_ready)
);

//Generate a hash of the Disk DSR to determine which DSR is being used
always @(posedge clk_sys) begin
	reg [26:0] last_ioaddr;
	if(ioctl_download && ioctl_index == 7 && ioctl_addr == 28'h0) disk_dsr_hash = 0;
	last_ioaddr <= ioctl_addr;
	if(ioctl_download == 1 && ioctl_index == 7  && last_ioaddr != ioctl_addr ) begin
		disk_dsr_hash = disk_dsr_hash + ioctl_dout[0];
	end
end


//Mega Cart - bank count.  IOCTL_INDEX of 2
always @(posedge clk_sys) begin
	if(~nvram_en) ram_di <= sdram_din;
	if(ioctl_download == 1 && ioctl_index == 2) begin
		cart_size <= ioctl_addr;
		cart_8k_banks <= cart_size[27:13];
	end
end

reg  [12:0]	nv_dout_counter;
wire [24:0] nvram_save_addr;
wire        nvram_rd_strobe;


always @(posedge clk_sys) begin
	reg saving_nvD;
	nvram_rd_strobe <= 0;
	saving_nvD <= saving_nv;
	if(~saving_nvD && saving_nv) begin
		nv_dout_counter = 0;
		nvram_save_addr <= nv_dout_counter + 24'h1000;
		nvram_rd_strobe <= 1;
	end
	else if(nvram_rd_strobe == 0 && sd_ack[3]) begin
		if(saving_nv && sdram_ready) begin
			if(nv_dout_counter == nv_buff_addr+(sd_lba[3]*512)) begin
				sd_buff_din[3] <= sdram_din[7:0];
				if (nv_dout_counter < 4095 ) begin
					nv_dout_counter = nv_dout_counter + 1'b1;					//If counter is under 4095, increment by one
					nvram_save_addr <= nv_dout_counter + 24'h1000;
					nvram_rd_strobe <= 1;											//Hit the read enable wire on sdram
				end
			end
		end
	end
end
				
assign sdram_addr = ioctl_download ? download_addr[25:0] : { ram_a , 1'b0 };


wire [13:0] vram_a;
wire        vram_we;
wire  [7:0] vram_di;
wire  [7:0] vram_do;

spram #(14) vram
(
	.clock(clk_sys),
	.address(erasing? erase_addr[13:0]:vram_a),
	.wren(erasing? erase_wr: vram_we),
	.data(erasing? 8'd0 : vram_do),
	.q(vram_di)
);


////////////////  Console  ////////////////////////

wire [10:0] audio;
assign AUDIO_L = {audio,5'd0};
assign AUDIO_R = {audio,5'd0};
assign AUDIO_S = 0;
assign AUDIO_MIX = 0;

assign CLK_VIDEO = clk_sys;

wire [7:0] R,G,B;
wire hblank, vblank;
wire hsync, vsync;

wire [8:0] keyboardSignals_i;
wire [7:0] keyboardSignals_o;

wire drive_led;

ep994a console
(
	.clk_i(clk_sys),
	.clk_en_10m7_i(ce_10m7),
	.reset_n_i(~reset),
	.por_n_o(),

	.epGPIO_o(keyboardSignals_i),
	.epGPIO_i(keyboardSignals_o),

	.cpu_ram_a_o(ram_a),
	.cpu_ram_we_n_o(ram_we_n),
	.cpu_ram_ce_n_o(ram_ce_n),
	.cpu_ram_be_n_o(ram_be_n),
	.cpu_ram_d_i(ram_di),
	.cpu_ram_d_o(ram_do),

	.vram_a_o(vram_a),
	.vram_we_o(vram_we),
	.vram_d_o(vram_do),
	.vram_d_i(vram_di),

	.rgb_r_o(R),
	.rgb_g_o(G),
	.rgb_b_o(B),
	.hsync_n_o(hsync),
	.vsync_n_o(vsync),
	.hblank_o(hblank),
	.vblank_o(vblank),

	.myarcfdc_en(myarc_en || myarc80),
	.fdc_turbo(status[28]),
	.myarcSwitches(status[31:29]),
	.myarc80(myarc80),

	.img_mounted(img_mounted[2:0]),
	.img_wp("000"),							//Currently the floppy images are not write protected
	.img_size(img_size),

	.sd_lba_fd0(sd_lba[0]),
	.sd_lba_fd1(sd_lba[1]),
	.sd_lba_fd2(sd_lba[2]),
	.sd_rd(sd_rd[2:0]),
	.sd_wr(sd_wr[2:0]),
	.sd_ack(fd_ack[2:0]),
	.sd_buff_addr(fd_buff_addr),
	.sd_dout(fd_dout),
	.sd_din_fd0(sd_buff_din[0]),
	.sd_din_fd1(sd_buff_din[1]),
	.sd_din_fd2(sd_buff_din[2]),
	.sd_dout_strobe(fd_buff_wr),

	.audio_total_o(audio),

	.speech_model(speech_mod),
	.sr_re_o(),
	.sr_addr_o(speech_a),
	.sr_data_i(speech_d),
	
//Cassette Tape Data
	.cassette_bit_i(adc_cassette_bit),
	.cassette_bit_o(),
	
//TiPi Related
	.tipi_en(tipi_en),
	.tipi_crubase(tipi_crubase),
	.rpi_clk(rpi_clk),							// PI-31					D+			White
	.rpi_cd(rpi_cd),								// PI-40					D-			Brown
	.rpi_dout(rpi_dout),							// PI-36					RX+		Yellow
	.rpi_le(rpi_le),								// PI-35					RX-		Green
	.rpi_rt(rpi_rt),								// PI-33					TX-		Blue
	.rpi_din(rpi_din),							// PI-38	OUT			TX+		Red
	.rpi_reset(rpi_reset),						// PI-37 OUT			GND_D		Orange
														// GND								Purple and Grey
//PCode
	.pcode_en(status[26]),

	.scratch_1k_i(scratch_1k),
	.cart_type_i(cart_type),
	.optSWI(optSWI),
	.rommask_i((cart_type == 0 && m99RomBlks == 2) ? 6'b000001 : 6'b000111),
	.flashloading_i(download_reset),
	.turbo_i(turbo),
	.drive_led(drive_led),
	.pause_i(pause),
	.sams_en_i(sams_en),
	.cart_8k_banks(valid_m99 ? m99RomBlks - 1 : cart_size != 0 ? cart_8k_banks[11:0] : 8),
	.tape_audio_en(1),							// Tape Audio hardcoded on for now.  Should make this a toggle switch in OSD when all this stuff works.
	.is_pal_g(is_pal)
);


wire scandoubler = status[9:7] || forced_scandoubler;

/////////////////////// ADC Module  //////////////////////////////


wire [11:0] adc_data;
wire        adc_sync;
reg [11:0] adc_value;
reg adc_sync_d;

integer ii=0;
reg [11:0] adc_val[0:511];
reg [21:0] adc_total = 0;
reg [11:0] adc_avg;

reg adc_cassette_bit;

// interface to ADC via framework

ltc2308 #(1, 44100, 50000000) adc_input		// mono, ADC_RATE = 48000, CLK_RATE = 50000000
(
	.reset(reset),
	.clk(CLK_50M),

	.ADC_BUS(ADC_BUS),
	.dout(adc_data),
	.dout_sync(adc_sync)
);

always @(posedge CLK_50M) begin

	
	adc_sync_d<=adc_sync;
	if(adc_sync_d ^ adc_sync) begin
		adc_value <= adc_data;					// latch in current value, adc_Value
		
		adc_val[0] <= adc_value;				
		adc_total  <= adc_total - adc_val[511] + adc_value;

		for (ii=0; ii<511; ii=ii+1)
			adc_val[ii+1] <= adc_val[ii];
			
		adc_avg <= adc_total[20:9];			// update average value every fetch
		

		if (adc_value > (adc_avg + 40))
			adc_cassette_bit <= 1;
		else adc_cassette_bit <= 0;
			
	end
end


////////////////////////////////////////////////////Video////////////////////////////////////////////////////
//Playing around with video scaling and cropping


reg [9:0] vcrop;
//reg wide;
always @(posedge CLK_VIDEO) begin
	vcrop <= 0;
//	wide <= 0;
	if(HDMI_WIDTH >= (HDMI_HEIGHT + HDMI_HEIGHT[11:1]) && !scandoubler) begin
		if(HDMI_HEIGHT == 480)  vcrop <= 240;
//		if(HDMI_HEIGHT == 600)  begin vcrop <= 200; wide <= vcrop_en; end
		if(HDMI_HEIGHT == 720)  vcrop <= 240;
		if(HDMI_HEIGHT == 768)  vcrop <= 256; // NTSC mode has 250 visible lines only!
//		if(HDMI_HEIGHT == 800)  begin vcrop <= 200; wide <= vcrop_en; end
		if(HDMI_HEIGHT == 1080) vcrop <= 10'd216;
		if(HDMI_HEIGHT == 1200) vcrop <= 240;
	end
end


wire ar = status[1];
wire vcrop_en = status[21];
wire vga_de;
video_freak video_freak
(
	.*,
	.VGA_DE_IN(vga_de),
	.ARX((!ar) ? 12'd400 : ar ),
	.ARY((!ar) ? 12'd300 : 12'd0),
	.CROP_SIZE(vcrop_en ? vcrop : 10'd0),
	.CROP_OFF(0),
	.SCALE(status[6:5])
);

assign VGA_F1 = 0;
//assign VGA_SL = sl[1:0];

//wire [2:0] scale = status[9:7];
assign VGA_SL    = (status[9:7] > 1) ? status[8:7] - 2'd1 : 2'd0;
//wire [2:0] sl = scale ? scale - 1'd1 : 3'd0;

reg hs_o, vs_o;
always @(posedge CLK_VIDEO) begin
	hs_o <= ~hsync;
	if(~hs_o & ~hsync) vs_o <= ~vsync;
end

video_mixer #(.LINE_LENGTH(284), .GAMMA(1)) video_mixer
(

	.CLK_VIDEO(CLK_VIDEO),
	.ce_pix(ce_5m3),
	.CE_PIXEL(CE_PIXEL),

	.scandoubler(scandoubler),
	.hq2x(~status[9] & ~status[8] & status[7]),
	.gamma_bus(gamma_bus),


	.R(R),
	.G(G),
	.B(B),

	// Positive pulses.
	.HSync(hs_o),
	.VSync(vs_o),
	.HBlank(hblank),
	.VBlank(vblank),
	
//	.HDMI_FREEZE(HDMI_FREEZE),
//	.freeze_sync(freeze_sync),
	.VGA_R(VGA_R),
	.VGA_G(VGA_G),
	.VGA_B(VGA_B),
	.VGA_VS(VGA_VS),
	.VGA_HS(VGA_HS),
	.VGA_DE(vga_de)

);


///////////////////////////////////////////// NVRAM for MiniMem /////////////////////////////////////////////

wire pause;
wire  [7:0] fd_dout;
wire  [7:0] fd_din[2:0];
wire  [7:0] nv_dout;
wire  [8:0] fd_buff_addr;
wire  [8:0] nv_buff_addr;


wire	[2:0]	fd_ack;
wire			nv_ack;
wire        fd_buff_wr;
wire			nv_buff_wr;

wire  sd_data_path;

always @(posedge clk_sys) begin
	if(sd_rd[0] || sd_rd[1] || sd_rd[2] || sd_wr[0] || sd_wr[1] || sd_wr[2]) sd_data_path <= 0;
	else if(sd_rd[3] || sd_wr[3]) sd_data_path <= 1;
	
	if(sd_data_path) begin
		nv_dout <= sd_buff_dout;
//		sd_buff_din[3] <= nv_din;
//		sd_lba[3] <= nv_lba;
		nv_buff_wr <= sd_buff_wr;
		nv_buff_addr <= sd_buff_addr;
		nv_ack <= sd_ack[3];						//Should update from single bit to # of Devices when updating Framework
	end
   else begin
		fd_dout <= sd_buff_dout;

		fd_buff_wr <= sd_buff_wr;
		fd_buff_addr <= sd_buff_addr;
		fd_ack[2:0] <= sd_ack[2:0];						//Should update from single bit to # of Devices when updating Framework
	end
end



wire nv_file_valid;
wire [24:0] nvram_addr;

wire load_nv = status[60];
wire save_nv = status[61];

always @(posedge clk_sys) begin

	reg img_mountedD;
	
	img_mountedD <= img_mounted[3];
	if (~img_mountedD && img_mounted[3]) begin
		if(img_size == 4096) nv_file_valid <= 1;
		else nv_file_valid <= 0;
	end
end


reg nvram_en;				//Indicates we are either Reading or Writing NVRAM data to/from memory and file on sd card

assign nvram_addr[24:0] = { 13'h1, sd_lba[3][3:0], nv_buff_addr[7:0]};			// 7000-7FFF (ram location: 1000-1fff)
reg loading_nv;
reg saving_nv;


// //////////////////////////////////////////// SD card control /////////////////////////////////////////////
localparam SD_IDLE = 0;
localparam SD_READ = 1;
localparam SD_WRITE = 2;

reg [1:0] sd_state;
reg       sd_card_write;
reg       sd_card_read;
wire      sdram_ready;

always @(posedge clk_sys) begin
	reg nv_ackD;
	reg load_nvD, save_nvD;
	reg [8:0] old_nv_addr;
	
	load_nvD <= load_nv;
	save_nvD <= save_nv;

	if(~load_nvD && load_nv) begin
		loading_nv <= 1;
		nvram_en <= 1;
		sd_lba[3] <= 0;					//Start with first block of SD Buffer
		pause <= 1;
	end
	if(~save_nvD && save_nv) begin
		saving_nv <= 1;
		nvram_en <= 1;
		sd_lba[3] <= 0;					//Start with first block of SD Buffer
		pause <= 1;
	end

	nv_ackD <= nv_ack;
	if (nv_ack) {sd_rd[3], sd_wr[3]} <= 0;

	case (sd_state)
	SD_IDLE:
	begin
		if (~load_nvD & load_nv) begin
			sd_rd[3] <= 1;
			sd_state <= SD_READ;
		end
		else if (~save_nvD & save_nv) begin
			sd_wr[3] <= 1;
			sd_state <= SD_WRITE;
		end
	end

	SD_READ:
	if (nv_ackD & ~nv_ack) begin
		if(sd_lba[3] <15) begin
			sd_lba[3] <= sd_lba[3] + 1'd1;
			sd_rd[3] <= 1;
		end
		else begin
			sd_state <= SD_IDLE;
			loading_nv <= 0;
			nvram_en <= 0;
			pause <= 0;
		end
	end

	SD_WRITE:
	if (nv_ackD & ~nv_ack) begin
		if(sd_lba[3] <15) begin
			sd_lba[3] <= sd_lba[3] +1'd1;
			sd_wr[3] <= 1;
		end
		else begin
			sd_state <= SD_IDLE;
			saving_nv <= 0;
			nvram_en <= 0;
			pause <= 0;
		end
	end

	default: ;
	endcase
end


///////////////////////////////////////////////// TiPi //////////////////////////////////////////////////////

wire rpi_dout= USER_IN[1];				//D-
wire rpi_rt  = USER_IN[2];				//SSTX-
wire rpi_le  = USER_IN[3];				//GND_D
wire rpi_cd  = USER_IN[5];				//SSRX-
wire rpi_clk = USER_IN[6];				//SSTX+

wire rpi_din, rpi_reset;

assign USER_OUT[0] = rpi_reset;			//D+
assign USER_OUT[4] = rpi_din;				//SSRX+


/////////////////////////////////////////////////  Control  /////////////////////////////////////////////////
// Mouse
wire [4:0] mouseData;
mecmouse mouse(
	.clk(clk_sys),
	.reset(reset),
	.ps2_mouse(ps2_mouse),
	.j1_s(~keyboardSignals_i[1]),
	.j2_s(~keyboardSignals_i[0]),
	.mode(mecmouse_en[1]),
	.mecmouse_o(mouseData)
);
	
// Keyboard

wire       pressed = ps2_key[9];
wire [8:0] code    = ps2_key[8:0];
always @(posedge clk_sys) begin
	reg old_state;
	old_state <= ps2_key[10];
	
	if(first_boot & status[15]) btn_al <= 1;
	
	if(old_state != ps2_key[10]) begin
		casex(code)
//			'hX75: btn_up    <= pressed;
//			'hX72: btn_down  <= pressed;
//			'hX6B: btn_left  <= pressed;
//			'hX74: btn_right <= pressed;
			'hX0E: btn_fire  <= pressed; // ` => fire
			
			'hX16: btn_1     <= pressed; // 1
			'hX1E: btn_2     <= pressed; // 2
			'hX26: btn_3     <= pressed; // 3
			'hX25: btn_4     <= pressed; // 4
			'hX2E: btn_5     <= pressed; // 5
			'hX36: btn_6     <= pressed; // 6
			'hX3D: btn_7     <= pressed; // 7
			'hX3E: btn_8     <= pressed; // 8
			'hX46: btn_9     <= pressed; // 9
			'hX45: btn_0     <= pressed; // 0
			'hX4E: btn_eq    <= pressed; // - => =
			'hX55: btn_eq    <= pressed; // =
			'hX5D: btn_eq    <= pressed; // \ => =

			'hX15: btn_q     <= pressed; // q
			'hX1D: btn_w     <= pressed; // w
			'hX24: btn_e     <= pressed; // e
			'hX2D: btn_r     <= pressed; // r
			'hX2C: btn_t     <= pressed; // t
			'hX35: btn_y     <= pressed; // y
			'hX3C: btn_u     <= pressed; // u
			'hX43: btn_i     <= pressed; // i
			'hX44: btn_o     <= pressed; // o
			'hX4D: btn_p     <= pressed; // p
			'hX54: btn_fs    <= pressed; // [ => /
			
			'hX1C: btn_a     <= pressed; // a
			'hX1B: btn_s     <= pressed; // s
			'hX23: btn_d     <= pressed; // d
			'hX2B: btn_f     <= pressed; // f
			'hX34: btn_g     <= pressed; // g
			'hX33: btn_h     <= pressed; // h
			'hX3B: btn_j     <= pressed; // j
			'hX42: btn_k     <= pressed; // k
			'hX4B: btn_l     <= pressed; // l
			'hX4C: btn_se    <= pressed; // ;
			'hX5A: btn_en    <= pressed; // enter
			
			'hX12: btn_sh    <= pressed; // lshift
			'hX1A: btn_z     <= pressed; // z
			'hX22: btn_x     <= pressed; // x
			'hX21: btn_c     <= pressed; // c
			'hX2A: btn_v     <= pressed; // v
			'hX32: btn_b     <= pressed; // b
			'hX31: btn_n     <= pressed; // n
			'hX3A: btn_m     <= pressed; // m
			'hX41: btn_co    <= pressed; // ,
			'hX49: btn_pe    <= pressed; // .
			'hx4A: btn_fs    <= pressed; // /
			'hX59: btn_sh    <= pressed; // rshift

			'hX58: btn_al    <= (~btn_al & pressed) | (btn_al & ~pressed); // caps => alpha lock
			'hX14: btn_ct    <= pressed; // lctrl
			'hX29: btn_sp    <= pressed; // space
			'hX11: btn_fn    <= pressed; // lalt => fn
			'hx52:	//Quotes
				begin
					btn_fn	<= pressed;
					btn_p		<= pressed;
				end
			'hx66:	//BackSpace
				begin
					btn_fn	<= pressed;
					btn_s		<= pressed;
				end
			'hx6B:	//Left Arrow
				begin
					if(virt_joy) btn_left	<= pressed;
					else begin
						btn_fn	<= pressed;
						btn_s		<= pressed;
					end
				end
			'hx72:	//Down Arrow
				begin
					if(virt_joy) btn_down	<= pressed;
					else begin
						btn_fn	<= pressed;
						btn_x		<= pressed;
					end
				end
			'hx74:	//Right Arrow
				begin
					if(virt_joy) btn_right	<= pressed;
					else begin
						btn_fn	<= pressed;
						btn_d		<= pressed;
					end
				end
			'hx75:	//Up Arrow
				begin
					if(virt_joy) btn_up	<= pressed;
					else begin
						btn_fn	<= pressed;
						btn_e		<= pressed;
					end
				end
			'hX71: begin // del
					btn_fn   <= pressed;
					btn_1    <= pressed;
			end
			'hX70: begin // ins
					btn_fn   <= pressed;
					btn_2    <= pressed;
			end
			'hX76: begin // esc (back)
					btn_fn   <= pressed;
					btn_9    <= pressed;
			end
		endcase
	end
end

reg btn_1 = 0;
reg btn_2 = 0;
reg btn_3 = 0;
reg btn_4 = 0;
reg btn_5 = 0;
reg btn_6 = 0;
reg btn_7 = 0;
reg btn_8 = 0;
reg btn_9 = 0;
reg btn_0 = 0;
reg btn_eq = 0;

reg btn_q = 0;
reg btn_w = 0;
reg btn_e = 0;
reg btn_r = 0;
reg btn_t = 0;
reg btn_y = 0;
reg btn_u = 0;
reg btn_i = 0;
reg btn_o = 0;
reg btn_p = 0;
reg btn_fs = 0;
			
reg btn_a = 0;
reg btn_s = 0;
reg btn_d = 0;
reg btn_f = 0;
reg btn_g = 0;
reg btn_h = 0;
reg btn_j = 0;
reg btn_k = 0;
reg btn_l = 0;
reg btn_se = 0;
reg btn_en = 0;
			
reg btn_sh = 0;
reg btn_z = 0;
reg btn_x = 0;
reg btn_c = 0;
reg btn_v = 0;
reg btn_b = 0;
reg btn_n = 0;
reg btn_m = 0;
reg btn_co = 0;
reg btn_pe = 0;

reg btn_al = 0;
reg btn_ct = 0;
reg btn_sp = 0;
reg btn_fn = 0;

reg btn_up    = 0;
reg btn_down  = 0;
reg btn_left  = 0;
reg btn_right = 0;
reg btn_fire  = 0;
//|0|0|0|U|D|R|L|B|
//00 - off, 01, Mechatronics, 10 Joy1, 11 joy2
wire m_right2  = mecmouse_en && mecmouse_en[0] == 1 ? ~mouseData[2] : joy_swap ? joy0[0] : joy1[0];
wire m_left2   = mecmouse_en && mecmouse_en[0] == 1 ? ~mouseData[1] : joy_swap ? joy0[1] : joy1[1];
wire m_down2   = mecmouse_en && mecmouse_en[0] == 1 ? ~mouseData[3] : joy_swap ? joy0[2] : joy1[2];
wire m_up2     = mecmouse_en && mecmouse_en[0] == 1 ? ~mouseData[4] : joy_swap ? joy0[3] : joy1[3];
wire m_fire2   = mecmouse_en && mecmouse_en[0] == 1 ? ~mouseData[0] : joy_swap ? joy0[4] | joy1[5] : joy1[4] | joy0[5]; // Fire 2 = fire button on second controller joy[5]
wire m_right  = mecmouse_en && mecmouse_en < 3 ? ~mouseData[2] : btn_right | (joy_swap ? joy1[0] : joy0[0]);
wire m_left   = mecmouse_en && mecmouse_en < 3 ? ~mouseData[1] : btn_left  | (joy_swap ? joy1[1] : joy0[1]);
wire m_down   = mecmouse_en && mecmouse_en < 3 ? ~mouseData[3] : btn_down  | (joy_swap ? joy1[2] : joy0[2]);
wire m_up     = mecmouse_en && mecmouse_en < 3 ? ~mouseData[4] : btn_up    | (joy_swap ? joy1[3] : joy0[3]);
wire m_fire   = mecmouse_en && mecmouse_en < 3 ? ~mouseData[0] : btn_fire  | (joy_swap ? joy1[4] | joy0[5] : joy0[4] | joy1[5]);


//Parsec uses keys 1,2,3: Make these joystick buttons for convenience
//Also can be used to select menu on boot
wire m_1  = btn_1 | joy0[6] | joy1[6];
wire m_2  = btn_2 | joy0[7] | joy1[7];
wire m_3  = btn_3 | joy0[8] | joy1[8];
wire m_en = btn_en | joy0[9] | joy1[9];
wire m_8  = btn_8 | joy0[10] | joy1[10];
wire m_9  = btn_9 | joy0[11] | joy1[11];
wire m_fn = btn_fn | joy0[10] | joy1[10] | joy0[11] | joy1[11];

wire [7:0] keys0 = {btn_eq, btn_pe, btn_co, btn_m,  btn_n,  btn_fs, m_fire,  m_fire2};        // last=fire2
wire [7:0] keys1 = {btn_sp, btn_l,  btn_k,  btn_j,  btn_h,  btn_se, m_left,  m_left2};        // last=left2
wire [7:0] keys2 = {m_en,   btn_o,  btn_i,  btn_u,  btn_y,  btn_p,  m_right, m_right2};       // last=right2
wire [7:0] keys3 = {1'b0,   m_9,    m_8,    btn_7,  btn_6,  btn_0,  m_down,  m_down2};        // last=down2
wire [7:0] keys4 = {m_fn,   m_2,    m_3,    btn_4,  btn_5,  m_1,    m_up,    m_up2};          // last=up2/al
wire [7:0] keys5 = {btn_sh, btn_s,  btn_d,  btn_f,  btn_g,  btn_a,  1'b0,      1'b0};         // last=
wire [7:0] keys6 = {btn_ct, btn_w,  btn_e,  btn_r,  btn_t,  btn_q,  1'b0,      1'b0};         // last=
wire [7:0] keys7 = {1'b0,   btn_x,  btn_c,  btn_v,  btn_b,  btn_z,  1'b0,      1'b0};         // last=
wire [7:0] keyboardSelect = '{~keyboardSignals_i[4],
                              ~keyboardSignals_i[5],
                              ~keyboardSignals_i[6],
                              ~keyboardSignals_i[7],
                              ~keyboardSignals_i[3],
                              ~keyboardSignals_i[2],
                              ~keyboardSignals_i[1],
										~keyboardSignals_i[0]};
wire [7:0] keys = '{~|(keys7 & keyboardSelect[7:0]),
                    ~|(keys6 & keyboardSelect[7:0]),
                    ~|(keys5 & keyboardSelect[7:0]),
                    ~(|(keys4 & keyboardSelect[7:0]) | (btn_al & ~keyboardSignals_i[8])),
                    ~|(keys3 & keyboardSelect[7:0]),
                    ~|(keys2 & keyboardSelect[7:0]),
                    ~|(keys1 & keyboardSelect[7:0]),
                    ~|(keys0 & keyboardSelect[7:0])
						  };

assign keyboardSignals_o[7:0] = keys[7:0];

endmodule

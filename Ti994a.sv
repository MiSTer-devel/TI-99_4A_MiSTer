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
	inout  [45:0] HPS_BUS,

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

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
//	output        HDMI_FREEZE,

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
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = 0;
//assign {SDRAM_CLK, SDRAM_CKE, SDRAM_A, SDRAM_BA, SDRAM_DQML, SDRAM_DQMH, SDRAM_nCS, SDRAM_nCAS, SDRAM_nWE} = 'z;
assign VGA_SCALER = 0;


assign LED_USER  = ioctl_download | drive_led | loading_nv;
assign LED_DISK  = 0;
assign LED_POWER = 0;
assign BUTTONS   = osd_btn;
assign ps2_kbd_led_status[0] = btn_al;			// Synch Alpha Lock with Caps Lock LED
assign ps2_kbd_led_status[2] = drive_led;    // Use the Scroll Lock LED for Floppy Activity


//assign VIDEO_ARX = status[1] ? 8'd16 : 8'd4;
//assign VIDEO_ARY = status[1] ? 8'd9  : status[13] ? 8'd4 : 8'd3; 

// Status Bit Map:
//              Upper                          Lower
// 0         1         2         3          4         5         6
// 01234567890123456789012345678901 23456789012345678901234567890123
// 0123456789ABCDEFGHIJKLMNOPQRSTUV 0123456789ABCDEFGHIJKLMNOPQRSTUV
// XX XXXXXXXXXXXX XXXXX X                                 

`include "build_id.v" 
parameter CONF_STR = {
	"TI-99_4A;;",
	"F,BIN,Load Full or C.bin;",
	"F,BIN,Load D.bin;",
	"F,BIN,Load G.bin;",
	"F,BIN,Load Mega Cart;",
	"S0,DSK,Drive 1;",
	"S1,DSK,Drive 2;",
	"-;",
	"OIK,Cart Type,Normal,MBX,Paged7,UberGrom,Paged379,MiniMem;",	//Normal = 0, MBX = 1, Paged7 = 2, UberGrom = 3, Paged378 = 4, MiniMem = 5
	"-;",
	"D0P1,Mini Mem;",
	"P1S2,DAT,NVRAM File;",
	"P1rS,Load NVRAM;",
	"P1rT,Save NVRAM;",

	"P2,Video Settings;",
	"P2OD,Video Mode,NTSC, PAL;",
	"P2O79,Scandoubler Fx,None,HQ2x-320,CRT 25%,CRT 50%,CRT 75%;",
	"P2O56,Scale,Normal,V-Integer,Narrower HV-Integer,Wider HV-Integer;",
	"P2O1,Aspect Ratio,Original,Full Screen;",
	"D1P2o8,Vertical Crop,No,Yes;",
	"-;",
	"OM,SAMS Memory,Off,On;",
	"OE,Scratchpad RAM,256B,1KB;",
	
	"OA,Turbo,Off,On;",
	"OGH,Speech,Off,5220,5200;",
	"OC,Arrow Keys,Cursor, Joystick;",
	"OF,Alpha Lock on Power Up, Off, On;",
	"OB,Swap joysticks,NO,YES;",
	"-;",
//	"oA,Pause When OSD is Open,No,Yes;",
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

wire clk_sys; //, clk_ram;
wire pll_locked;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_sys),
//	.outclk_1(clk_ram),
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
wire [15:0] status_mask = {scandoubler, cart_type !=5};
wire  [1:0] buttons;

wire [31:0] joy0, joy1;
wire [10:0] ps2_key;
wire  [2:0] ps2_kbd_led_use = { 1'b1, 1'b0, 1'b1};
wire  [2:0] ps2_kbd_led_status;

wire        ioctl_download;
wire  [7:0] ioctl_index;
wire        ioctl_wr;
wire [26:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire        forced_scandoubler;
wire [21:0] gamma_bus;

wire [31:0] sd_lba;
wire  [3:0] sd_rd;
wire  [3:0] sd_wr;
//wire  [1:0] sd_ack;
wire        sd_ack;
wire  [8:0] sd_buff_addr;
wire  [7:0] sd_buff_dout;
wire  [7:0] sd_buff_din;
wire        sd_buff_wr;	//sd_dout_strobe
wire  [3:0] img_mounted;
wire [31:0] img_size;
wire  [2:0]	cart_type = status[20:18];

hps_io #(.STRLEN($size(CONF_STR)>>3), .VDNUM(3)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.conf_str(CONF_STR),

	.buttons(buttons),
	.status(status),
//	.status_menumask(|vcrop),
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

	.img_mounted(img_mounted),
	.img_size(img_size),

	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_index),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),

	.ps2_key(ps2_key),
	.ps2_kbd_led_use(ps2_kbd_led_use),
	.ps2_kbd_led_status(ps2_kbd_led_status),

	.joystick_0(joy0),
	.joystick_1(joy1)
);

/////////////////  RESET  /////////////////////////

// reset after download
reg [7:0] download_reset_cnt;
wire download_reset = download_reset_cnt != 0;
always @(posedge CLK_50M) begin
	if((ioctl_download && ioctl_index != 9) || reset_osd || buttons[1] || RESET) download_reset_cnt <= 8'd255;
	else if(download_reset_cnt != 0) download_reset_cnt <= download_reset_cnt - 8'd1;
end

// hold machine in reset until first download starts
reg init_reset;
always @(posedge CLK_50M) begin
	if(!pll_locked) init_reset <= 1'b1;
	else if(ioctl_download) init_reset <= 1'b0;
end

wire reset = (init_reset || buttons[1] || RESET || reset_osd | ioctl_download);

/////////////////  Memory  ////////////////////////

wire [14:0] speech_a;
wire  [7:0] speech_d;
wire [14:0] speechrom_a;

assign speechrom_a = ioctl_download ? ioctl_addr[14:0] : speech_a;

spram #(15) speechrom
(
	.clock(clk_sys),
	.wren(ioctl_index == 4 ? 0 : ioctl_wr && |ioctl_addr[26:18]),
	.data(ioctl_dout),
	.address(speechrom_a),
	.q(speech_d)
);


// 17x16 bit address = 256K
wire  [20:0] ram_a;
wire        ram_we_n, ram_ce_n;
wire  [15:0] ram_di;
wire  [15:0] sdram_din;
wire  [15:0] ram_do;
wire  [1:0] ram_be_n;

wire  [24:0] download_addr;
reg   [19:0] cart_size;
reg   [19:0] cart_8k_banks;

// ioctl_index={1=Full/C.bin=0,2=D.bin=h2000>>1=h1000,3=G.bin=h16000>>1=hB000}
assign download_addr[0] = ~ioctl_addr[0]; //endian fix
assign download_addr[24:1] = ioctl_addr[20:1] + ((ioctl_index == 1 || ioctl_index == 0) ? (ioctl_addr[18:16] == 3'b000 ? 21'h0000 : (ioctl_addr[17:16] == 2'b01 ? 21'h38000 : 21'h48000)) : 
                                                (ioctl_index == 2 ? 21'h1000 : (ioctl_index == 3 ? 21'h43000 : 21'h0000)));
// Add the following to the IOCTL_ADDRESS:
// If Index is 0 or 1 (boot.rom/Full/C.bin), First 64k, starts at x0000,   
// If Index is 2 (D.bin), add x1000 (x2000 right shifted)
// If Index is 3 (G.bin), add x43000 (x86000 right shifted)
// Any other index, don't add anything, start at x0000


wire [24:0] sdram_addr;
wire  [6:1] rommask_s;

assign SDRAM_CLK = ~clk_sys;
sdram sdram
(
	.*,
	
	.init(~pll_locked),
	.clk(clk_sys),

   .wtbt((ioctl_download || nvram_en) ? 2'b0 : ~ram_be_n),
   .addr(loading_nv ? nvram_addr : saving_nv? nvram_save_addr : sdram_addr),
   .rd(saving_nv? nvram_rd_strobe : ~ram_ce_n),
   .dout(sdram_din),
   .din(ioctl_download? {ioctl_dout,ioctl_dout} : nvram_en ? {nv_dout, nv_dout} : ram_do),
   .we(ioctl_download ? (ioctl_index == 4 ? ioctl_wr : (ioctl_wr && !ioctl_addr[24:18])) : nvram_en ? nv_buff_wr & nv_ack : ~ram_we_n),
   .ready(sdram_ready)
);

always @(posedge clk_sys) begin
	if(~nvram_en) ram_di <= sdram_din;
	if(ioctl_download == 1 && ioctl_index == 4) begin
		cart_size <= ioctl_addr[19:0];
		cart_8k_banks <= (cart_size >> 13);
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
	else if(nvram_rd_strobe == 0 && sd_ack) begin
		if(saving_nv && sdram_ready) begin
			if(nv_dout_counter == nv_buff_addr+(nv_lba*512)) begin
				nv_din <= sdram_din[7:0];
				if (nv_dout_counter < 4095 ) begin
					nv_dout_counter = nv_dout_counter + 1'b1;					//If counter is under 4095, increment by one
					nvram_save_addr <= nv_dout_counter + 24'h1000;
					nvram_rd_strobe <= 1;											//Hit the read enable wire on sdram
				end
			end
		end
	end
end
				
		

assign rommask_s = ioctl_index != 2 ? 6'b000111 :
                  (ioctl_addr[24:14] == 11'd0 ? 6'b000001 :
						(ioctl_addr[24:15] == 10'd0 ? 6'b000011 :
						(ioctl_addr[24:16] == 9'd0 ? 6'b000111 :
						(ioctl_addr[24:17] == 8'd0 ? 6'b001111 :
						(ioctl_addr[24:18] == 7'd0 ? 6'b011111 : 6'b111111
						)))));
						
assign sdram_addr = ioctl_download ? download_addr : { 3'b000 ,ram_a , 1'b0 };


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

	.img_mounted(img_mounted[1:0]),
	.img_wp("00"),							//Currently the floppy images are not write protected
	.img_size(img_size),

	.sd_lba(fd_lba),
	.sd_rd(sd_rd[1:0]),
	.sd_wr(sd_wr[1:0]),
	.sd_ack(fd_ack),
	.sd_buff_addr(fd_buff_addr),
	.sd_dout(fd_dout),
	.sd_din(fd_din),
	.sd_dout_strobe(fd_buff_wr),

	.audio_total_o(audio),

	.speech_model(speech_mod),
	.sr_re_o(),
	.sr_addr_o(speech_a),
	.sr_data_i(speech_d),
	
	.scratch_1k_i(scratch_1k),
	.cart_type_i(cart_type),
	.optSWI(optSWI),
	.rommask_i(rommask_s),
	.flashloading_i(download_reset),
	.turbo_i(turbo),
	.drive_led(drive_led),
	.pause_i(pause),
	.sams_en_i(sams_en),
	.cart_8k_banks(cart_size != 0 ? cart_8k_banks[7:0] : 8),
	.is_pal_g(is_pal)
);


wire scandoubler = status[9:7] || forced_scandoubler;


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
wire vcrop_en = status[40];
wire vga_de;
video_freak video_freak
(
	.*,
	.VGA_DE_IN(vga_de),
	.ARX((!ar) ? 12'd400 : ar ),
//	.ARX((!ar) ? (wide ? 12'd340 : 12'd400) : (ar - 1'd1)),
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
wire  [7:0] fd_din;
wire  [7:0] nv_dout;
wire  [7:0] nv_din;
wire [31:0] fd_lba;
wire [31:0] nv_lba;
wire  [8:0] fd_buff_addr;
wire  [8:0] nv_buff_addr;


wire			fd_ack;
wire			nv_ack;
wire        fd_buff_wr;
wire			nv_buff_wr;

wire  sd_data_path;

always @(posedge clk_sys) begin
	if(sd_rd[0] || sd_rd[1] || sd_wr[0] || sd_wr[1]) sd_data_path <= 0;
	else if(sd_rd[2] || sd_wr[2]) sd_data_path <= 1;
	
	if(sd_data_path) begin
		nv_dout <= sd_buff_dout;
		sd_buff_din <= nv_din[7:0];
		sd_lba <= nv_lba;
		nv_buff_wr <= sd_buff_wr;
		nv_buff_addr <= sd_buff_addr;
		nv_ack <= sd_ack;						//Should update from single big to # of Devices when updating Framework
	end
   else begin
		fd_dout <= sd_buff_dout;
		sd_buff_din <= fd_din;
		sd_lba <= fd_lba;
		fd_buff_wr <= sd_buff_wr;
		fd_buff_addr <= sd_buff_addr;
		fd_ack <= sd_ack;						//Should update from single big to # of Devices when updating Framework
	end
end



wire nv_file_valid;
wire [24:0] nvram_addr;

wire load_nv = status[60];
wire save_nv = status[61];

always @(posedge clk_sys) begin

	reg img_mountedD;
	
	img_mountedD <= img_mounted[2];
	if (~img_mountedD && img_mounted[2]) begin
		if(img_size == 4096) nv_file_valid <= 1;
		else nv_file_valid <= 0;
	end
end


reg nvram_en;				//Indicates we are either Reading or Writing NVRAM data to/from memory and file on sd card

assign nvram_addr[24:0] = { 13'h1, nv_lba[2:0], nv_buff_addr[8:0]};			// 7000-7FFF (ram location: 1000-1fff)
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
		nv_lba <= 0;					//Start with first block of SD Buffer
		pause <= 1;
	end
	if(~save_nvD && save_nv) begin
		saving_nv <= 1;
		nvram_en <= 1;
		nv_lba <= 0;					//Start with first block of SD Buffer
		pause <= 1;
	end

	nv_ackD <= nv_ack;
	if (nv_ack) {sd_rd[2], sd_wr[2]} <= 0;

	case (sd_state)
	SD_IDLE:
	begin
		if (~load_nvD & load_nv) begin
			sd_rd[2] <= 1;
			sd_state <= SD_READ;
		end
		else if (~save_nvD & save_nv) begin
			sd_wr[2] <= 1;
			sd_state <= SD_WRITE;
		end
	end

	SD_READ:
	if (nv_ackD & ~nv_ack) begin
		if(nv_lba <7) begin
			nv_lba <= nv_lba + 1'd1;
			sd_rd[2] <= 1;
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
		if(nv_lba <7) begin
			nv_lba <= nv_lba +1'd1;
			sd_wr[2] <= 1;
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



/////////////////////////////////////////////////  Control  /////////////////////////////////////////////////

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

wire m_right2  = joy_swap ? joy0[0] : joy1[0];
wire m_left2   = joy_swap ? joy0[1] : joy1[1];
wire m_down2   = joy_swap ? joy0[2] : joy1[2];
wire m_up2     = joy_swap ? joy0[3] : joy1[3];
wire m_fire2   = joy_swap ? joy0[4] | joy1[5] : joy1[4] | joy0[5]; // Fire 2 = fire button on second controller joy[5]
wire m_right  = btn_right | (joy_swap ? joy1[0] : joy0[0]);
wire m_left   = btn_left  | (joy_swap ? joy1[1] : joy0[1]);
wire m_down   = btn_down  | (joy_swap ? joy1[2] : joy0[2]);
wire m_up     = btn_up    | (joy_swap ? joy1[3] : joy0[3]);
wire m_fire   = btn_fire  | (joy_swap ? joy1[4] | joy0[5] : joy0[4] | joy1[5]);

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

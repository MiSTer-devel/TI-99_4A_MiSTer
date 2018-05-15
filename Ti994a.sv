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
	inout  [44:0] HPS_BUS,

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

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S, // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)
	input         TAPE_IN,

	// SD-SPI
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
	output        SDRAM_nWE
);

assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = 0;
 
assign LED_USER  = ioctl_download;// | (loader_fail);// & led_blink);
assign LED_DISK  = 0;
assign LED_POWER = 0;

assign VIDEO_ARX = status[1] ? 8'd16 : 8'd4;
assign VIDEO_ARY = status[1] ? 8'd9  : 8'd3; 

wire [1:0] scale = status[8:7];

`include "build_id.v" 
parameter CONF_STR = {
	"TI-99_4A;;",
	"F,BIN,Load Full or C.bin;",
	"F,BIN,Load D.bin;",
	"F,BIN,Load G.bin;",
	"O1,Aspect ratio,4:3,16:9;",
	"O78,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%;",
	"-;",
	"T6,Reset;",
	"-;",
	"-;",
	"-;",
	"J,Fire 1,Fire 2,*,#,0,1,2,3,Purple Tr,Blue Tr;",
	"V,v1.00.",`BUILD_DATE
};

wire reset_osd = status[6];

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

wire [31:0] status;
wire  [1:0] buttons;

wire [15:0] joya, joyb;
wire [10:0] ps2_key;

wire        ioctl_download;
wire  [7:0] ioctl_index;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire        forced_scandoubler;

hps_io #(.STRLEN($size(CONF_STR)>>3)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.conf_str(CONF_STR),

	.buttons(buttons),
	.status(status),
	.forced_scandoubler(forced_scandoubler),

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

// reset after download
reg [7:0] download_reset_cnt;
wire download_reset = download_reset_cnt != 0;
always @(posedge CLK_50M) begin
	if(ioctl_download || reset_osd) download_reset_cnt <= 8'd255;
	else if(download_reset_cnt != 0) download_reset_cnt <= download_reset_cnt - 8'd1;
end

// hold machine in reset until first download starts
reg init_reset;
always @(posedge CLK_50M) begin
	if(!pll_locked) init_reset <= 1'b1;
	else if(ioctl_download) init_reset <= 1'b0;
end

wire reset = (init_reset || buttons[1] || RESET || reset_osd);// || download_reset );

/////////////////  Memory  ////////////////////////
wire [24:0] memory_addr;       // 25 bit byte address
wire        memory_we;                // cpu/chipset requests write
wire [7:0]  memory_din;               // data input from chipset/cpu
wire        memory_oeA;               // cpu requests data
wire [7:0]  memory_doutA;             // data output to cpu
wire        memory_oeB;               // ppu requests data
wire [7:0]  memory_doutB;             // data output to ppu

assign memory_we = 1'b0;
assign SDRAM_CKE         = 1'b1;

sdram sdram
(
	// interface to the MT48LC16M16 chip
	.sd_data     	( SDRAM_DQ                 ),
	.sd_addr     	( SDRAM_A                  ),
	.sd_dqm      	( {SDRAM_DQMH, SDRAM_DQML} ),
	.sd_cs       	( SDRAM_nCS                ),
	.sd_ba       	( SDRAM_BA                 ),
	.sd_we       	( SDRAM_nWE                ),
	.sd_ras      	( SDRAM_nRAS               ),
	.sd_cas      	( SDRAM_nCAS               ),

	// system interface
	.clk      		( clk_sys         				),
	.clkref      	( ce_5m3         			),
	.init         	( !pll_locked     			),

	// cpu/chipset interface
	.addr     		( memory_addr ),
	
	.we       		( memory_we	),
	.din       		( memory_din ),
	
	.oeA         	( memory_oeA ),
	.doutA       	( memory_doutA	),
	
	.oeB         	( memory_oeB ),
	.doutB       	( memory_doutB	)
);

wire [12:0] bios_a;
wire  [7:0] bios_d;

//sprom #("bios.hex", 13) rom
//(
//	.clock(clk_sys),
//	.address(bios_a),
//	.q(bios_d)
//);

// 17x16 bit address = 256K
wire  [16:0] ram_a;
wire        ram_we_n, ram_ce_n;
wire  [15:0] ram_di;
wire  [15:0] ram_do;
wire  [1:0] ram_be_n;

wire  [17:0] download_addr;
assign download_addr[0] = ~ioctl_addr[0]; //endian fix
// ioctl_index={1=Full/C.bin=0,2=D.bin=h2000>>1=h1000,3=G.bin=h16000>>1=hB000}
assign download_addr[17:1] = ioctl_addr[17:1] + (ioctl_index[1] ? (ioctl_index[0] ? 'hB000 : 'h1000): 'h0000);

dpram16_8 #(17) ram
(
	.clock(clk_sys),
	.address_a(ram_a),
	.wren_a(~(ram_we_n | ram_ce_n)), //& ce_10m7),
	.data_a(ram_do),
	.q_a(ram_di),
	.byteena_a(~ram_be_n),

	.wren_b(ioctl_wr && !ioctl_addr[24:18]),
	.address_b(download_addr),
	.data_b(ioctl_dout),
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

//wire [14:0] cart_a;
//wire  [7:0] cart_d;

//dpram #(15) cart
//(
//	.clk_a_i(clk_sys),
//	.we_i(ioctl_wr && !ioctl_addr[24:15]),
//	.addr_a_i(ioctl_addr[14:0]),
//	.data_a_i(ioctl_dout),
//
//	.clk_b_i(clk_sys),
//	.addr_b_i(cart_a),
//	.data_b_o(cart_d)
//);

////////////////  Console  ////////////////////////

wire [7:0] audio;
assign AUDIO_L = {audio,8'd0};
assign AUDIO_R = {audio,8'd0};
assign AUDIO_S = 0;//1;
assign AUDIO_MIX = 0;

assign CLK_VIDEO = clk_sys;

//wire [1:0] ctrl_p1;
//wire [1:0] ctrl_p2;
//wire [1:0] ctrl_p3;
//wire [1:0] ctrl_p4;
//wire [1:0] ctrl_p5;
//wire [1:0] ctrl_p6;
//wire [1:0] ctrl_p7 = 2'b11;
//wire [1:0] ctrl_p8;
//wire [1:0] ctrl_p9 = 2'b11;

wire [7:0] R,G,B;
wire hblank, vblank;
wire hsync, vsync;

wire [8:0] keyboardSignals_i;
wire [7:0] keyboardSignals_o;

ep994a console
(
	.clk_i(clk_sys),
	.clk_en_10m7_i(ce_10m7),
	.reset_n_i(~reset),
	.por_n_o(),

	// GPIO port
	.epGPIO_o(keyboardSignals_i),
	.epGPIO_i(keyboardSignals_o),
	// GPIO 0..7  = IO1P..IO8P - these are the keyboard row strobes.
	// GPIO 8..15 = IO1N..IO8N - these are key input signals.

	//.bios_rom_a_o(bios_a),
	//.bios_rom_d_i(bios_d),

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

	//.cart_a_o(cart_a),
	//.cart_d_i(cart_d),

	.rgb_r_o(R),
	.rgb_g_o(G),
	.rgb_b_o(B),
	.hsync_n_o(hsync),
	.vsync_n_o(vsync),
	.hblank_o(hblank),
	.vblank_o(vblank),

	.audio_o(audio),
	
	.flashloading_i(download_reset)
);

video_mixer #(.LINE_LENGTH(290)) video_mixer
(
	.*,

	.ce_pix(ce_5m3),
	.ce_pix_out(CE_PIXEL),

	.scanlines({scale == 3, scale == 2}),
	.scandoubler(scale || forced_scandoubler),
	.hq2x(scale==1),

	.mono(0),

	.R(R),
	.G(G),
	.B(B),

	// Positive pulses.
	.HSync(~hsync),
	.VSync(~vsync),
	.HBlank(hblank),
	.VBlank(vblank)
);



////////////////  Control  ////////////////////////

wire       pressed = ps2_key[9];
wire [8:0] code    = ps2_key[8:0];
always @(posedge clk_sys) begin
	reg old_state;
	old_state <= ps2_key[10];
	
	if(old_state != ps2_key[10]) begin
		casex(code)
			'hX75: btn_up    <= pressed;
			'hX72: btn_down  <= pressed;
			'hX6B: btn_left  <= pressed;
			'hX74: btn_right <= pressed;
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
			'hX59: btn_sh    <= pressed; // rshift

			'hX58: btn_al    <= (~btn_al & pressed) | (btn_al & ~pressed); // caps => alpha lock
			'hX14: btn_ct    <= pressed; // lctrl
			'hX29: btn_sp    <= pressed; // space
			'hX11: btn_fn    <= pressed; // lalt => fn
			//'hX14: btn_fn    <= pressed; // rctrl => fn
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

wire m_right2  = joyb[0];
wire m_left2   = joyb[1];
wire m_down2   = joyb[2];
wire m_up2     = joyb[3];
wire m_fire2   = joyb[4];
wire m_right  = btn_right | joya[0];
wire m_left   = btn_left  | joya[1];
wire m_down   = btn_down  | joya[2];
wire m_up     = btn_up    | joya[3];
wire m_fire   = btn_fire  | joya[4];
//wire m_arm    = btn_arm   | joya[5];
//wire m_1      = btn_1     | joya[9];
//wire m_2      = btn_2     | joya[10];
//wire m_3      = btn_3     | joya[11];
//wire m_s      = btn_s     | joya[6];
//wire m_0      = btn_0     | joya[8];
//wire m_p      = btn_p     | joya[7];
//wire m_pt     = btn_pt    | joya[12];
//wire m_bt     = btn_bt    | joya[13];

wire [7:0] keys0 = {btn_eq, btn_pe, btn_co, btn_m,  btn_n,  btn_fs, m_fire,  m_fire2};        // last=fire2
wire [7:0] keys1 = {btn_sp, btn_l,  btn_k,  btn_j,  btn_h,  btn_se, m_left,  m_left2};        // last=left2
wire [7:0] keys2 = {btn_en, btn_o,  btn_i,  btn_u,  btn_y,  btn_p,  m_right, m_right2};       // last=right2
wire [7:0] keys3 = {1'b0,   btn_9,  btn_8,  btn_7,  btn_6,  btn_0,  m_down,  m_down2};        // last=down2
wire [7:0] keys4 = {btn_fn, btn_2,  btn_3,  btn_4,  btn_5,  btn_1,  m_up,    m_up2};          // last=up2/al
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

//assign keyboardSignals[15:8] = keys[7:0];
//assign keyboardSignals[7:0] = 'Z;
assign keyboardSignals_o[7:0] = keys[7:0];
//assign keyboardSignalsi[7:0] = 'Z;

endmodule

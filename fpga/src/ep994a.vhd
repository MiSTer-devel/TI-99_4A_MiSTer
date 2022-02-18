----------------------------------------------------------------------------------
-- ep994a.vhd
--
-- Toplevel module. The design is intended for the Saanlima electronics Pepino
-- FPGA board. The extension pins on that board are connected to an external
-- board (prototype board as of 2016-10-30) housing a TMS99105 microprocessor,
-- it's clock oscillator and a 74LVC245 buffer chip. See schematics for details.
--
-- This file is part of the ep994a design, a TI-99/4A clone 
-- designed by Erik Piehl in October 2016.
-- Erik Piehl, Kauniainen, Finland, speccery@gmail.com
--
-- This is copyrighted software.
-- Please see the file LICENSE for license terms. 
--
-- NO WARRANTY, THE SOURCE CODE IS PROVIDED "AS IS".
-- THE SOURCE IS PROVIDED WITHOUT ANY GUARANTEE THAT IT WILL WORK 
-- FOR ANY PARTICULAR USE. IN NO EVENT IS THE AUTHOR LIABLE FOR ANY 
-- DIRECT OR INDIRECT DAMAGE CAUSED BY THE USE OF THE SOFTWARE.
--
-- Synthesized with Xilinx ISE 14.7.
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use IEEE.STD_LOGIC_UNSIGNED.ALL;
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

--0000..1FFF     Console ROM
--2000..3FFF     (8K, part of 32K RAM expansion)
--4000..5FFF     (Peripheral cards ROM)
--6000..7FFF     Cartridge ROM (module port)
--8000..83FF     Scratchpad RAM (256 bytes, mirrored (partially decoded) across 8000..83FF)
--8400..87FF     Sound chip write
--8800..8BFF     VDP Read (8800 read, 8802 status)
--8C00..8FFF     VDP Write (8C00 write, 8C02 set address)
--9800..9BFF     GROM Read (9800 read, 9802 read addr+1)
--9C00..9FFF     GROM Write (9C00 write data, 9C02 write address)
--A000..FFFF     (24K, part of 32K RAM expansion)
----------------------------------------------------------------------------------
-- CRU map of the TI-99/4A
--0000..0FFE	  Internal use
--1000..10FE	  Unassigned
--1100..11FE	  Disk controller card
--1200..12FE	  Modems
--1300..13FE     RS232 (primary)
--1400..14FE     Unassigned
--1500..15FE     RS232 (secondary)
--1600..16FE     Unassigned
--...
----------------------------------------------------------------------------------
entity ep994a is
	generic (
		compat_rgb_g    : integer := 0
	);
	port (
		-- Global Interface -------------------------------------------------------
		clk_i           : in  std_logic;
		clk_en_10m7_i   : in  std_logic;
		reset_n_i       : in  std_logic;
		por_n_o         : out std_logic;
		-- Controller Interface ---------------------------------------------------
		-- GPIO port
		epGPIO_i		 : in std_logic_vector(7 downto 0);
		epGPIO_o		 : out std_logic_vector(8 downto 0);
		-- CPU RAM Interface ------------------------------------------------------
		cpu_ram_a_o     : out std_logic_vector(24 downto 0);
		cpu_ram_ce_n_o  : out std_logic;
		cpu_ram_we_n_o  : out std_logic;
		cpu_ram_be_n_o  : out std_logic_vector( 1 downto 0);
		cpu_ram_d_i     : in  std_logic_vector(15 downto 0);
		cpu_ram_d_o     : out std_logic_vector(15 downto 0);
		-- Video RAM Interface ----------------------------------------------------
		vram_a_o        : out std_logic_vector(13 downto 0);
		vram_we_o       : out std_logic;
		vram_d_o        : out std_logic_vector( 7 downto 0);
		vram_d_i        : in  std_logic_vector( 7 downto 0);
		-- RGB Video Interface ----------------------------------------------------
		col_o           : out std_logic_vector( 3 downto 0);
		rgb_r_o         : out std_logic_vector( 7 downto 0);
		rgb_g_o         : out std_logic_vector( 7 downto 0);
		rgb_b_o         : out std_logic_vector( 7 downto 0);
		hsync_n_o       : out std_logic;
		vsync_n_o       : out std_logic;
		blank_n_o       : out std_logic;
		hblank_o        : out std_logic;
		vblank_o        : out std_logic;
		comp_sync_n_o   : out std_logic;
		-- Disk interface ---------------------------------------------------------
		myarcfdc_en     : in std_logic;
		myarc80         : in std_logic;
		fdc_turbo       : in std_logic;
		myarcSwitches   : in std_logic_vector( 2 downto 0);

		img_mounted     : in  std_logic_vector( 2 downto 0);
		img_wp          : in  std_logic_vector( 2 downto 0);
		img_size        : in  std_logic_vector(31 downto 0); -- in bytes

		sd_lba_fd0      : out std_logic_vector(31 downto 0); -- Not doing Arrays in VDHL...they are pissing me off
		sd_lba_fd1      : out std_logic_vector(31 downto 0);
		sd_lba_fd2      : out std_logic_vector(31 downto 0);
		sd_rd           : out std_logic_vector( 2 downto 0);
		sd_wr           : out std_logic_vector( 2 downto 0);
      sd_ack          : in  std_logic_vector( 2 downto 0);	-- Saving for later when updating to newer framework
		sd_buff_addr    : in  std_logic_vector( 8 downto 0);
		sd_dout         : in  std_logic_vector( 7 downto 0);
		sd_din_fd0      : out std_logic_vector( 7 downto 0); -- Not doing Arrays in VDHL...they are pissing me off
		sd_din_fd1      : out std_logic_vector( 7 downto 0);
		sd_din_fd2      : out std_logic_vector( 7 downto 0);
		sd_dout_strobe  : in  std_logic;
		
		-- Tipi Interface ---------------------------------------------------------
		tipi_crubase	 : in  std_logic_vector( 3 downto 0) := "0000";
		tipi_en			 : in  std_logic := '0';
		rpi_clk		 	 : in  std_logic := '0';								-- PI-31
			-- 0 = Data or 1 = Control byte selection
		rpi_cd			 : in  std_logic := '0';								-- PI-40
		rpi_dout			 : in  std_logic := '0';								-- PI-36
		rpi_le			 : in  std_logic := '0';								-- PI-35
			-- R|T 0 = RPi or 1 = TI originating data 
		rpi_rt			 : in  std_logic := '0';								-- PI-33
		rpi_din			 : out std_logic := '0';								-- PI-38
		rpi_reset		 : out std_logic := '0';								-- PI-37
		-- PCODE Interface --------------------------------------------------------
		pcode_en			 : in std_logic := '0';
		
		-- Audio Interface --------------------------------------------------------
		audio_total_o   : out std_logic_vector(10 downto 0);

		speech_model     : in  std_logic_vector( 1 downto 0);
		sr_re_o          : out std_logic;
		sr_addr_o        : out std_logic_vector(14 downto 0);
		sr_data_i        : in  std_logic_vector( 7 downto 0);
		
		-- Cassette Data ----------------------------------------------------------
		
		cassette_bit_i   : in std_logic;
		cassette_bit_o   : out std_logic;
		tape_audio_en	  : in std_logic;
			  
		scratch_1k_i     : in std_logic;
		cart_type_i      : in std_logic_vector( 3 downto 0);
		optSWI           : in std_logic_vector( 2 downto 0);
		rommask_i        : in std_logic_vector(6 downto 1) := "000111";
		flashloading_i   : in std_logic;
		turbo_i          : in std_logic;
		drive_led		  : out std_logic;
		pause_i			  : in std_logic;
		sams_en_i		  : in std_logic;
		cart_8k_banks	  : in std_logic_vector(11 downto 0);
		is_pal_g         : in boolean
	);
end ep994a;

-- pragma translate_off
use std.textio.all;
-- pragma translate_on

use work.tispeechsyn;

architecture Behavioral of ep994a is
	component fdc1772 is
		generic (
			CLK              : integer := 42954540;  -- old values tried with different ram/success : 42666000 42800000 42680000 42856000
--			CLK_EN           : integer := 8500;
			SECTOR_SIZE_CODE : integer := 1  -- 256 bytes/sector
		);
		port (
			clkcpu           : in  std_logic;
			clk8m_en         : in  std_logic;
			fd1771           : in  std_logic;
			dden             : in  std_logic;
			turbo            : in  std_logic;
			fd80             : in  std_logic;

			floppy_drive     : in  std_logic_vector( 3 downto 0);
			floppy_side      : in  std_logic;
			floppy_reset     : in  std_logic;

			irq              : out std_logic;
			drq              : out std_logic;

			cpu_addr         : in  std_logic_vector( 1 downto 0);
			cpu_sel          : in  std_logic;
			cpu_rw           : in  std_logic;
			cpu_din          : in  std_logic_vector( 7 downto 0);
			cpu_dout         : out std_logic_vector( 7 downto 0);

			img_mounted      : in  std_logic_vector( 2 downto 0);
			img_wp           : in  std_logic_vector( 2 downto 0);
			img_ds           : in  std_logic;
			img_size         : in  std_logic_vector(31 downto 0); -- in bytes

			sd_lba_fd0       : out std_logic_vector(31 downto 0);
			sd_lba_fd1       : out std_logic_vector(31 downto 0);
			sd_lba_fd2       : out std_logic_vector(31 downto 0);
			sd_rd            : out std_logic_vector( 2 downto 0);
			sd_wr            : out std_logic_vector( 2 downto 0);
			sd_ack           : in  std_logic_vector( 2 downto 0);
			sd_buff_addr     : in  std_logic_vector( 8 downto 0);
			sd_dout          : in  std_logic_vector( 7 downto 0);
			sd_din_fd0       : out std_logic_vector( 7 downto 0);
			sd_din_fd1       : out std_logic_vector( 7 downto 0);
			sd_din_fd2       : out std_logic_vector( 7 downto 0);
			sd_dout_strobe   : in  std_logic;
			drive_led		  : out std_logic
		);
	end component ;

	component tipi_top is
		port
		(
		

	-- START USER PORT CONNECTION		
			r_clk					: in  std_logic;
			-- 0 = Data or 1 = Control byte selection
			r_cd					: in  std_logic;
			r_dout				: in  std_logic;
			r_le					: in  std_logic;
			-- R|T 0 = RPi or 1 = TI originating data 
			r_rt					: in  std_logic;
			r_din					: out std_logic;
			r_reset				: out std_logic;
	-- END USER PORT CONNECTION

			ti_dbin				: in  std_logic;		-- TMS9900 CPU_RD   - request for data from bus
			ti_memen				: in  std_logic;
			ti_we					: in  std_logic;		-- TMS9900 NOT CPU_WR
			cru_state			: in  std_logic_vector( 3 downto 0);

			ti_a					: in  std_logic_vector( 15 downto 0);
			tp_d_i				: in  std_logic_vector( 7 downto 0);
			tp_d_o				: out std_logic_vector( 7 downto 0)
			
		);
	end component;
	

	-- TIPI TEMPORARY SIGNALS
		
		signal tipi_data	: std_logic_vector(7 downto 0);
		signal tipi_dsr_data	: std_logic_vector(15 downto 0);
		signal tipi_dsr_en : std_logic := '0';

	
	component sprom is
		generic
		(
			init_file		: string := "";
			awidth			: integer := 14
		);
		port
		(
			clock				: in std_logic;
			address			: in std_logic_vector (awidth-1 downto 0);
			q					: out std_logic_vector (15 downto 0)
		);
	end component;
	
	
	
	
	
	signal funky_reset 		: std_logic_vector(15 downto 0) := (others => '0');
	signal real_reset			: std_logic;
	signal real_reset_n		: std_logic;
	signal mem_addr			: std_logic_vector(31 downto 0);
	signal mem_read_rq		: std_logic;
	signal mem_write_rq		: std_logic;
	-- SRAM memory controller state machine
	type mem_state_type is (
		idle, 
		wr0, wr1, wr2,
		rd0, rd1, rd2,
		grace,
		cpu_wr0, cpu_wr1, cpu_wr2,
		cpu_rd0, cpu_rd1, cpu_rd2
		);
	signal mem_state : mem_state_type := idle;
	
	type ctrl_state_type is (
		idle, control_write, control_read, ack_end
		);
	signal ctrl_state : ctrl_state_type := idle;
	
	signal debug_sram_ce0 : std_logic;
	signal debug_sram_we  : std_logic;
	signal sram_addr_bus  : std_logic_vector(24 downto 0); 
	signal sram_16bit_read_bus : std_logic_vector(15 downto 0);	-- choose between (31..16) and (15..0) during reads.

	signal por_n_s          : std_logic;
	signal reset_n_s        : std_logic;
	signal switch           : std_logic;

	signal clk 					: std_logic;				-- output primary clock
	signal clk_en_3m58_s    : std_logic;
	signal clk_en_cpu_s     : std_logic;

	-- TMS99105 control signals
	signal cpu_addr			: std_logic_vector(15 downto 0);
	signal data_to_cpu		: std_logic_vector(15 downto 0);	-- data to CPU
	signal data_from_cpu		: std_logic_vector(15 downto 0);	-- data from CPU
	signal wr_sampler			: std_logic_vector(3 downto 0);
	signal rd_sampler			: std_logic_vector(3 downto 0);
	signal cruclk_sampler   : std_logic_vector(3 downto 0);
	signal cpu_access			: std_logic;		-- when '1' CPU owns the SRAM memory bus	

	-- VDP read and write signals
	signal vdp_wr 				: std_logic;
	signal vdp_rd 				: std_logic;
	signal vdp_data_out		: std_logic_vector(15 downto 0);
	signal vdp_interrupt		: std_logic; --low true

	-- GROM signals
	signal grom_data_out		: std_logic_vector(7 downto 0);
	signal grom_rd_inc		: std_logic;
	signal grom_we				: std_logic;
	signal grom_ram_addr		: std_logic_vector(19 downto 0);
	signal grom_selected		: std_logic;
	signal grom_rd				: std_logic;

	-- Keyboard control
	signal cru9901			: std_logic_vector(31 downto 0) := x"00000000";	-- 32 write bits to 9901, when cru9901(0)='0'
	signal cru9901IntMask: std_logic_vector(15 downto 0) := x"0000";		-- 16 bit Interrupt Mask for 9901
	
	type keyboard_array is array (7 downto 0, 7 downto 0) of std_logic;
	
	signal cru_read_bit		: std_logic;

	-- Reset control
	signal cpu_reset_ctrl	: std_logic_vector(7 downto 0);	-- 8 control signals, bit 0 = reset, bit 1=rom bank reset, bit 2=mask interrupts when cleared
	signal cpu_single_step  : std_logic_vector(7 downto 0) := x"00";	-- single stepping. bit 0=1 single step mode, bit 1=1 advance one instruction	

	-- Module port banking
	signal basic_rom_bank : std_logic_vector(6 downto 1) := "000000";	-- latch ROM selection, 512K ROM support
	signal cartridge_cs	 : std_logic;	-- 0x6000..0x7FFF
	signal mbx_rom_bank : std_logic_vector(1 downto 0);
	signal uber_rom_bank : std_logic_vector(11 downto 0);

	-- audio subsystem
	signal dac_data		: std_logic_vector(7 downto 0);	-- data from TMS9919 to DAC input
	--signal dac_out_bit	: std_logic;		-- output to pin
	-- SN76489 signal
	signal psg_ready_s      : std_logic;
	signal tms9919_we		: std_logic;		-- write enable pulse for the audio "chip"
	signal audio_data_out: std_logic_vector(7 downto 0);
	signal audio_o      : std_logic_vector( 7 downto 0);

	-- cassette/tape system
	signal timer9901Read   : std_logic_vector(13 downto 0); -- TMS 9901 Timer READ Register paused for CRU reading.
	signal timer9901Load: std_logic_vector(13 downto 0);	-- TMS 9901 Clock Register
	signal timer9901  : std_logic_vector(13 downto 0); -- TMS 9901 Timer countdown
	signal tms9901Counter : integer; -- simple counter to track 64 clock cycles @ 3Mhz (916 @ 42.9)
	constant tms9901NumCycles : integer := 916; -- Calc: CORE_CLK_MHZ / 3MHZ * 64    -- (42954540/3000000) = 14.318 X 64 = 916.36352 (x394), subtract 1 for range 0-393
	signal tms9901IntReq_n : std_logic;
	signal tape_audio			: std_logic;
	
	-- disk subsystem
	signal tifdc_en		: std_logic := '0';				  -- EITHER tifdc_en OR myarcfdc_en can be enabled at a time.
	signal fdc_en			: std_logic := '1';
	signal cru1100_regs  : std_logic_vector(7 downto 0); -- disk controller CRU select
	signal m80_tracks    : std_logic;                    -- For 80 Track capable MyArc FDC, Force 80 Track mode for 360K images.
	alias disk_page_ena  : std_logic is cru1100_regs(0);
	alias disk_motor_clk : std_logic is cru1100_regs(1);
	alias disk_wait_en   : std_logic is cru1100_regs(2);
	alias disk_hlt       : std_logic is cru1100_regs(3);
	alias disk_sel       : std_logic_vector(2 downto 0) is cru1100_regs(6 downto 4);
--	alias disk_side      : std_logic is cru1100_regs(7);
   signal disk_side     : std_logic;
	signal disk_ds       : std_logic;
	signal disk_motor_clk_d : std_logic;
	signal disk_motor    : std_logic;
	signal disk_motor_cnt: integer := 0;
	signal disk_clk_en   : std_logic;
	signal disk_clk_cnt  : unsigned(4 downto 0);
	signal disk_cs       : std_logic;
	signal disk_rw       : std_logic;
	signal disk_rd       : std_logic;
	signal disk_wr       : std_logic;
	signal disk_rdy      : std_logic;
	signal disk_proceed  : std_logic;
	signal disk_irq      : std_logic;
	signal disk_drq      : std_logic;
	signal disk_atn      : std_logic;
	signal disk_din      : std_logic_vector(7 downto 0);
	signal disk_dout     : std_logic_vector(7 downto 0);
	signal floppy_reset  : std_logic;
	signal floppy_addr   : std_logic_vector(1 downto 0);
	signal rst_sampler	: std_logic_vector(3 downto 0) := "0000";
	signal dden				: std_logic;

	-- Speech signals
	signal speech_data_out	: std_logic_vector(7 downto 0);
	signal speech_o       : signed(7 downto 0);
	signal speech_conv    : unsigned(10 downto 0);
	signal speech_i       : std_logic;
	signal speech_ready   : std_logic;
	
	-- SAMS memory extension
	signal sams_regs			: std_logic_vector(7 downto 0) := x"00";
	signal pager_data_in		: std_logic_vector(15 downto 0);
	signal pager_data_out   : std_logic_vector(15 downto 0);
	signal translated_addr  : std_logic_vector(15 downto 0);
	signal paging_enable    : std_logic := '0';
	signal paging_registers : std_logic;
	signal paging_wr_enable : std_logic;
	signal page_reg_read		: std_logic;
	signal paging_enable_cs : std_logic;	-- access to some registers to enable paging etc.
	signal paging_regs_visible : std_logic;	-- when 1 page registers can be accessed
	
	-- TIPI
	signal tipi_regs			: std_logic_vector(3 downto 0) := "0000";

	-- PCODE
	signal pcode_regs			: std_logic_vector(1 downto 0) := "00";
--	signal pcode_dsr_data	: std_logic_vector(15 downto 0);
	signal pcode_dsr_bank	: std_logic := '0';
	
	-- PCODE-GROM signals
	signal pcode_grom_data_out		: std_logic_vector(7 downto 0);
	signal pcode_grom_rd_inc		: std_logic;
	signal pcode_grom_we				: std_logic;
	signal pcode_grom_ram_addr		: std_logic_vector(19 downto 0);
	signal pcode_grom_selected		: std_logic;
	signal pcode_grom_rd				: std_logic;
	
	-- TMS99105 Shield control latch signals (written to control latch during control cycle)
	signal conl_int   : std_logic;	-- IO2P - indata[1]
	-- TMS99105 Shield control signal buffer read signals (read during control control cycle)
	signal WE_n			: std_logic;	-- IO1N - indata[8]
	signal MEM_n		: std_logic;	-- IO2N - indata[9]
	signal BST1			: std_logic;	-- IO6N - indata[13]
	signal BST2			: std_logic;	-- IO7N - indata[14]
	signal BST3			: std_logic;	-- IO8N - indata[15]
	-- when to write to places
	signal go_write   : std_logic;
	signal cpu_mem_write_pending : std_logic;
	-- counter of alatch pulses to produce a sign of life of the CPU
	signal alatch_counter : std_logic_vector(19 downto 0);
	
	signal go_cruclk : std_logic;	-- CRUCLK write pulses from the soft TMS9900 core

-------------------------------------------------------------------------------	
-- SRAM debug signals with FPGA CPU
	signal sram_capture : boolean := False;

-------------------------------------------------------------------------------	
-- Signals from FPGA CPU
-------------------------------------------------------------------------------	
	signal RD_n   : std_logic;
	signal cpu_rd : std_logic;
	signal cpu_wr : std_logic;	
	signal cpu_ready : std_logic;
	signal cpu_iaq : std_logic;
	signal cpu_as : std_logic;
	
	signal cpu_cruin : std_logic;
	signal cpu_cruout : std_logic;
	signal cpu_cruclk : std_logic;
	signal cpu_stuck : std_logic;
	
	signal cpu_hold : std_logic;
	signal cpu_holda : std_logic;
	
	signal cpu_reset : std_logic;
	
	signal cpu_int_req : std_logic;
--	signal cpu_ic03    : std_logic_vector(3 downto 0) := "0001";
	signal cpu_int_ack : std_logic;
	
	signal waits : std_logic_vector(7 downto 0);
-------------------------------------------------------------------------------	
-- Signals for SPI Flash controller
-------------------------------------------------------------------------------	
	signal clk8 : std_logic := '0';	-- about 8 MHz clock, i.e. 100MHz divided by 12 which is 8.3MHz
	signal clk8_divider : integer range 0 to 15 := 0;
	signal romLoaded : std_logic;
	signal flashAddrOut : STD_LOGIC_VECTOR (19 downto 0);
	signal flashLoading : std_logic;
	signal lastFlashLoading : std_logic;	-- last state of flashLoading

-------------------------------------------------------------------------------
-- Signals for LPC1343 SPI controller receiver
-------------------------------------------------------------------------------
	signal lastLPC_CLK : std_logic;
	signal lastLPC_CS : std_logic_vector(7 downto 0) := x"00";
	signal spiLPC_rx : std_logic_vector(7 downto 0);
	signal spiLPC_tx : std_logic_vector(7 downto 0);
	signal spi_bitcount : integer range 0 to 7;
	signal spi_ready : boolean := false;
	signal spi_test_toggle : boolean := false;
	signal spi_test_count : integer range 0 to 255 := 0;
	signal spi_clk_sampler : std_logic_vector(2 downto 0) := "000";
	signal spi_rx_bit : std_logic;	
	signal wait_clock : boolean := false;
-------------------------------------------------------------------------------	
    COMPONENT tms9900
	 GENERIC (cycle_clks_g : integer);
    PORT(
         clk : IN  std_logic;
         reset : IN  std_logic;
         addr_out : OUT  std_logic_vector(15 downto 0);
         data_in  : IN  std_logic_vector(15 downto 0);
         data_out : OUT  std_logic_vector(15 downto 0);
         rd : OUT  std_logic;
         wr : OUT  std_logic;
         ready : IN  std_logic := '1';
         iaq : OUT  std_logic;
         as : OUT  std_logic;
			alu_debug_arg1 : OUT  std_logic_vector(15 downto 0);
			alu_debug_arg2 : OUT  std_logic_vector(15 downto 0);
			int_req	: in STD_LOGIC;		-- interrupt request, active high
			ic03     : in STD_LOGIC_VECTOR(3 downto 0);	-- interrupt priority for the request, 0001 is the highest (0000 is reset)
			int_ack	: out STD_LOGIC;		-- does not exist on the TMS9900, when high CPU vectors to interrupt
			cpu_debug_out : out STD_LOGIC_VECTOR (95 downto 0);	
			cruin		: in STD_LOGIC;
			cruout   : out STD_LOGIC;
			cruclk   : out STD_LOGIC;
			hold     : in STD_LOGIC;
			holda    : out STD_LOGIC;
			waits    : in STD_LOGIC_VECTOR(7 downto 0);
			scratch_en : in STD_LOGIC;		-- when 1 in-core scratchpad RAM is enabled
         stuck : OUT  std_logic;
         turbo    : in STD_LOGIC
        );
    END COMPONENT;
-------------------------------------------------------------------------------	
	component pager612
		port (  clk 			: in  STD_LOGIC;
				  abus_high		: in  STD_LOGIC_VECTOR (15 downto 12);
				  abus_low  	: in  STD_LOGIC_VECTOR (3 downto 0);
				  dbus_in 		: in  STD_LOGIC_VECTOR (15 downto 0);
				  dbus_out 		: out  STD_LOGIC_VECTOR (15 downto 0);
				  mapen 			: in  STD_LOGIC;	-- 1 = enable mapping
				  write_enable : in  STD_LOGIC;		-- 0 = write to register when sel_regs = 1
				  page_reg_read : in  STD_LOGIC;		-- 0 = read from register when sel_regs = 1
				  translated_addr : out  STD_LOGIC_VECTOR (15 downto 0);
				  access_regs  : in  STD_LOGIC -- 1 = read/write registers	
		);
	end component;
-------------------------------------------------------------------------------
	component gromext is
    Port ( din 	: in  STD_LOGIC_VECTOR (7 downto 0);	-- data in, write bus for addresses
	        dout 	: out  STD_LOGIC_VECTOR (7 downto 0);	-- data out, read bus
           clk 	: in  STD_LOGIC;
           we 		: in  STD_LOGIC;								-- write enable, 1 cycle long
           rd		: in  STD_LOGIC;								-- read signal, may be up for multiple cycles
			  selected : out STD_LOGIC;							-- high when this GROM is enabled during READ
																			-- when high, databus should be driven
           mode 	: in  STD_LOGIC_VECTOR(4 downto 0);		-- A5..A1 (4 bits for GROM base select, 1 bit for register select)
			  reset  : in  STD_LOGIC;
			  addr	: out STD_LOGIC_VECTOR(19 downto 0)		-- 1 megabyte GROM address out
			  );
	end component;

begin
  
  -----------------------------------------------------------------------------
  -- Reset generation
  -----------------------------------------------------------------------------
  por_b : work.cv_por
    port map (
      clk_i   => clk_i,
      por_n_o => por_n_s
    );
  por_n_o   <= por_n_s;
  reset_n_s <= reset_n_i;--por_n_s and reset_n_i;


  -----------------------------------------------------------------------------
  -- Clock generation
  -----------------------------------------------------------------------------
  clock_b : work.cv_clock
    port map (
      clk_i         => clk_i,
      clk_en_10m7_i => clk_en_10m7_i,
      reset_n_i     => reset_n_s,
      clk_en_3m58_p_o => clk_en_3m58_s
    );

  clk <= clk_i;

	-------------------------------------

	-- Use all 32 bits of RAM, we use CE0 and CE1 to control what chip is active.
	-- The byte enables are driven the same way for both chips.
	cpu_ram_be_n_o	<= "00" when cpu_access = '1' else -- or flashLoading = '1' else	-- TMS99105 is always 16-bit, use CE 
						--"10" when mem_addr(0) = '1' else	-- lowest byte
						"01";										-- second lowest byte
	cpu_ram_a_o <= sram_addr_bus;

	-- broadcast on 16-bit wide lanes when CPU is writing
--	cpu_ram_d_o		<= data_from_cpu when cpu_access='1' and MEM_n='0' and WE_n = '0' else (others => 'Z');
	cpu_ram_d_o		<= data_from_cpu when cpu_access='1' and MEM_n='0' and WE_n = '0';

	sram_16bit_read_bus <= cpu_ram_d_i; --SRAM_DAT(15 downto 0) when sram_addr_bus(0)='0' else SRAM_DAT(31 downto 16);

	process(clk, switch)
	begin
		if rising_edge(clk) then
			if cpu_access = '0' then
				cpu_ram_ce_n_o	<= debug_sram_ce0;
				cpu_ram_we_n_o <= debug_sram_we;
			else
				cpu_ram_ce_n_o	<= MEM_n;
				if MEM_n = '0' and WE_n = '0'
					and cpu_addr(15 downto 12) /= x"9"        -- 9XXX addresses don't go to RAM
					and cpu_addr(15 downto 11) /= x"8" & '1'  -- 8800-8FFF don't go to RAM
					and cpu_addr(15 downto 13) /= "000"       -- 0000-1FFF don't go to RAM
					and ((tifdc_en = '1' and cpu_addr(15 downto 13) /= "010") or			-- 4000-5FFF don't go to RAM (DISK DSR)
					     (myarcfdc_en = '1' and cpu_addr(15 downto 12) /= "0100") )			-- 4000-5FFF don't go to RAM (DISK DSR)
					and (cartridge_cs='0'                     -- writes to cartridge region do not go to RAM, unless:
						or (cart_type_i = 1 and cpu_addr(15 downto 10) = "011011")		-- MBX cart is loaded, we allow writes to 6C00+
						or (cart_type_i = 5 and cpu_addr(15 downto 12) = "0111") )		-- Mini Mem Cart is loaded, we allow writes to 7000-7FFF
				then
					cpu_ram_we_n_o <= '0';
				else
					cpu_ram_we_n_o <= '1';
				end if;
			end if;
		end if;
	end process;

	-------------------------------------size

	-- CPU reset out. If either cpu_reset_ctrl(0) or funky_reset(MSB) is zero, put CPU to reset.
	real_reset <= funky_reset(funky_reset'length-1);
	real_reset_n <= not real_reset;

	cpu_access <= not cpu_holda;	-- CPU owns the bus except when in hold
--	cpu_ready <= '1';

	-------------------------------------
	-- vdp interrupt & Timer Interrupt

	conl_int <= '0' when (tms9901IntReq_n = '0' and cru9901IntMask(3) = '1' and timer9901Load /= 0) or (vdp_interrupt = '0' and cru9901IntMask(2) = '1') else '1';

	-- cartridge memory select
	cartridge_cs 	<= '1' when MEM_n = '0' and cpu_addr(15 downto 13) = "011" else '0'; -- cartridge_cs >6000..>7FFF

	-------------------------------------

	-- For the column decoder, rely on pull-ups to bring the row selectors high
	epGPIO_o(8) <= cru9901(21); 	-- alpha-lock
	epGPIO_o(7) <= '0' when cru9901(20 downto 18) = "011" else '1'; 	-- col#3
	epGPIO_o(6) <= '0' when cru9901(20 downto 18) = "010" else '1'; 	-- col#2
	epGPIO_o(5) <= '0' when cru9901(20 downto 18) = "001" else '1'; 	-- col#1
	epGPIO_o(4) <= '0' when cru9901(20 downto 18) = "000" else '1'; 	-- col#0
	epGPIO_o(3) <= '0' when cru9901(20 downto 18) = "100" else '1'; 	-- col#4
	epGPIO_o(2) <= '0' when cru9901(20 downto 18) = "101" else '1'; 	-- col#5
	epGPIO_o(1) <= '0' when cru9901(20 downto 18) = "110" else '1'; 	-- col#6
	epGPIO_o(0) <= '0' when cru9901(20 downto 18) = "111" else '1'; 	-- col#7
	-------------------------------------
	speech_i <= '0' when speech_model = "11" else '1';

	switch <= not reset_n_s;
	mem_read_rq <= '0';
	mem_write_rq <= '0';
	mem_addr <= (others => '0');
	flashloading <= flashloading_i;--'0';
	
	process(clk, switch)
	variable ki : integer range 0 to 7;
	begin
		if rising_edge(clk) then 	-- our 100 MHz clock
			-- reset generation
			if switch = '1' then
				funky_reset <= (others => '0');	-- button on the FPGA board pressed
			else
				funky_reset <= funky_reset(funky_reset'length-2 downto 0) & '1';
			end if;

			-- reset processing
			if funky_reset(funky_reset'length-1) = '0' then
				-- reset activity here
				mem_state <= idle;
				ctrl_state <= idle;
				debug_sram_ce0 <= '1';
				debug_sram_WE <= '1';
				cru9901 <= x"00000000";
				cru9901IntMask <= x"0000";
				cru1100_regs <= (others => '0');
				sams_regs <= (others => '0');
				tipi_regs <= (others => '0');
				pcode_regs <= (others => '0');
				pcode_dsr_bank <= '0';
				alatch_counter <= (others => '0');
				cpu_mem_write_pending <= '0';
				sram_capture <= True;
				cpu_single_step <= x"00";
				waits <= (others => '0');
				timer9901Load <= (others => '0');
				timer9901 <= (others => '0');
				tms9901Counter <= 0;
				tms9901IntReq_n <= '1';
				timer9901Read <= (others => '0');

			else
				-- processing of normal clocks here. We run at 100MHz.

				-- First manage CPU wait states
				-- if switch 2 is set we run at 63 wait states
				-- if switch 1 is set we run at 31 wait states
				-- if switch 0 is set we run at 8 wait states
				-- else we run at zero wait states
				if optSWI(2)='1' then
					if cpu_as='1' then
						-- setup number of wait states depending on address accessed
						case cpu_addr(15 downto 12) is
							when x"0" => waits <= x"60"; -- ROM an scratchpad 640 ns
							when x"1" => waits <= x"60";
							when x"8" => waits <= x"60"; -- scratchpad and I/O
							when others =>
								waits <= x"F0";	-- 196, i.e. 200, i.e. 2000ns
						end case;
					end if;
				elsif optSWI(1)='1' then
					waits <= x"1F";
				elsif optSWI(0)='1' then
					waits <= x"08";
				else
					waits <= (others => '0');
				end if;

				-- If SWI(0) is set then automatically bring CPU out of reset once FPGA has moved
				-- data from flash memory to SRAM.
				cpu_reset <= not (cpu_reset_ctrl(0) and real_reset and not flashLoading);
				lastFlashLoading <= flashLoading;
				if flashLoading='1' then
					cpu_reset_ctrl <= x"FC";	-- during flash loading force reset on
					basic_rom_bank <= (others => '0');
					mbx_rom_bank <= (others => '0');
					uber_rom_bank <= (others => '0');
					sams_regs <= x"00";
					tipi_regs <= "0000";
					pcode_regs <= (others => '0');
					pcode_dsr_bank <= '0';
				end if;
				if flashLoading='0' and lastFlashLoading='1' then
					-- flash loading just stopped. Bring CPU out of reset.
					cpu_reset_ctrl <= x"FF";
				end if;
				
				-- Enable/Disable Floppy Drive Controller based on TIPI CRU Base
				if(tipi_en = '1' and tipi_crubase = "0001") then fdc_en <= '0';
				else fdc_en <= '1';
				end if;
				
				---------------------------------------------------------
				-- SRAM map (1 mega byte, 0..FFFFF, 20 bit address space)
				---------------------------------------------------------
				-- 00000..7FFFF - Cartridge module port, paged, 512K, to support the TI megademo :)
				-- 80000..9FFFF - GROM mapped to this area, 128K (was at 30000)
				-- A0000..AFFFF - Not used currently
				-- B0000..BCFFF - DSR area, 52K reserved	(was at 60000)
				--		B0000..B7FFF - 32k For Disk roms (TI-FDC = 8k, CC=16K)
				--		B8000..B8FFF - 4K For Tipi DSR (Currently File is 32K but only 4K DSR Padded with 0s)
				--		B9000..CBFFF - 76K For PCode DSR+Grom
				--			B9000..BBFFF - 12k PCode DSR 8K + 4K banked
				--			BC000..CBFFF - 64k PCode Private Grom
				-- FD000..FDFFF - Scratchpad 	(was at 68000)
				-- FE000..FFFFF - Boot ROM remapped (was at 0)   
				-- 100000..1FFFFF - SAMS SRAM 1M (i.e. the "normal" CPU RAM paged with the SAMS system)
				-- 200000 and above - Cartridge ROM Space for anything above 512K (Currently up to 32Megs)
				---------------------------------------------------------
				-- The SAMS control bits are set to zero on reset.
				-- sams_regs(0) CRU 1E00: when set, paging registers appear at DSR space >4000..
				-- sams_regs(1) CRU 1E02: when set, paging is enabled
				-- sams_regs(2) CRU 1E04: unused
				-- sams_regs(3) CRU 1E06: unused
				-- The memory paging CRU register control bits can be used
				-- to remove devices from the CPU's address space, revealing the
				-- underlying pageable RAM:
				-- sams_regs(4) CRU 1E08: when set, ROM is out and pageable RAM instead is available
				-- sams_regs(5) CRU 1E0A: when set, cartridge is out and pageable RAM instead is available
				--								  Also writes to cartridge area do not change the cartridge page during this time.
				-- sams_regs(6) CRU 1E0C: when set I/O devices are out and pageable RAM instead is available
				-- sams_regs(7) CRU 1E0E: unused
				-- Also, when disk DSR ROM are not mapped (CRU >1100=0) or SAMS page registers visible (>1E00=0)
				--	the pageable RAM "under" the DSR space is available.
				-- Thus the entire 64K is pageable.
				---------------------------------------------------------

				-- Drive SRAM addresses outputs synchronously 
				if cpu_access = '1' then
					if cpu_addr(15 downto 8) = x"98" and cpu_addr(1)='0' then
						sram_addr_bus <= "000000" & x"8" & grom_ram_addr(15 downto 1);	-- 0x80000 GROM
--						sram_addr_bus <= "0" & x"4" & grom_ram_addr(16 downto 1);	-- 0x80000 GROM
					elsif cpu_addr(15 downto 0) = x"5BFC" and pcode_en = '1' and pcode_grom_selected = '1' then
						sram_addr_bus <= "00000" & (x"5E000" + pcode_grom_ram_addr(15 downto 1));	-- 0xBC000..CBFFF PCode GROM
					elsif cartridge_cs = '1' and cart_type_i = 1 and cpu_addr(12 downto 10) = "011" then
						-- MBX 6c00-6FFF - RAM
						sram_addr_bus <= "0000000000010" & cpu_addr(12 downto 1);

					elsif cartridge_cs = '1' and (cart_type_i = 1 or cart_type_i = 2) and cpu_addr(12) = '1' then
						-- MBX 7000-7FFF - bank switched area
						sram_addr_bus <= "000000000000" & mbx_rom_bank & cpu_addr(11 downto 1);

					elsif cartridge_cs = '1' and sams_regs(5) = '0' and (cart_type_i = 3 or cart_type_i = 4) then
						-- UberGrom 6000-7FFF - bank switched area
						if uber_rom_bank(11 downto 6) = 0 then
							sram_addr_bus <= "0000000" & uber_rom_bank(5 downto 0) & cpu_addr(12 downto 1);
						else -- Any cart address over 512K is above the SAMS reserved area (100000..1FFFFF) so we add 0xC0000 to the right shifted address.
							sram_addr_bus <= std_logic_vector(to_unsigned(786432+to_integer(unsigned(uber_rom_bank(11 downto 0) & cpu_addr(12 downto 1))),25));
						end if;
					elsif cartridge_cs = '1' and sams_regs(5) = '0' then
						-- Handle paging of module port at 0x6000 unless sams_regs(5) is set (1E0A)
						sram_addr_bus <= "0000000" & (basic_rom_bank and rommask_i) & cpu_addr(12 downto 1);	-- mapped to 0x00000..0x7FFFF
					--Flandango: Handle the two different FDC.

					elsif disk_page_ena='1' and tifdc_en='1' and cpu_addr(15 downto 13) = "010" then
						-- DSR's for disk system (TI-FDC) 0x4000..0x5FFF
						sram_addr_bus <= "000000" & x"B" & "000" & cpu_addr(12 downto 1);	-- mapped to 0xB0000..0xB7FFF

					elsif disk_page_ena='1' and myarcfdc_en='1' and cpu_addr(15 downto 12) = "0100" then
						-- DSR's for disk system (MYARC-FDC) 0x4000..0x4FFF (2 pages of 4k)
						sram_addr_bus <= "000000" & x"B" & "000" & cru1100_regs(3) & cpu_addr(11 downto 1);	-- mapped to 0xB0000..0xB0FFF

					elsif disk_page_ena='1' and myarcfdc_en='1' and cpu_addr(15 downto 12) = "0101" then
						-- MYARC's FDC SDRAM 0x5000..0x5FFF shift it by 0x1000 since DSR is two banks of 4K
						sram_addr_bus <= "000000" & x"B" & "0010" & cpu_addr(11 downto 1);	-- mapped to 0xB2000..0xB2FFF


					elsif tipi_regs(0)='1' and cpu_addr(15 downto 13) = "010" then
						-- DSR's for Tipi system
						sram_addr_bus <= "000000" & x"B" & "100" & cpu_addr(12 downto 1);	-- mapped to 0xB8000..0xB8FFF
					elsif pcode_regs(0)='1' and cpu_addr(15 downto 13) = "010" then																-- PCode DSR mapped to 0XB9000..0xBBFFF
						if cpu_addr(12) = '1' then sram_addr_bus <= "00000" & (x"5D000" + (pcode_dsr_bank & cpu_addr(11 downto 1)));		-- 2 banks for 0x5000..0x5FFF @ 0xBA000..0xBBFFF
						else sram_addr_bus <= "00000" & (x"5C800" + cpu_addr(12 downto 1));															-- 0x4000..0x4FFF @ 0xB9000..0xB9FFF
						end if;
						-- DSR's for PCode system
--						sram_addr_bus <= "0" & (x"5C800" + (pcode_dsr_bank & cpu_addr(12 downto 1)));	-- mapped to 0xB9000..0xBBFFF
					elsif cpu_addr(15 downto 13) = "000" and sams_regs(4) = '0' then
						-- ROM at the bottom of address space not paged unless sams_regs(4) is set (1E08)
						sram_addr_bus <= "000000" & x"F" & "111" & cpu_addr(12 downto 1);	-- mapped to 0xFE000
					elsif cpu_addr(15 downto 10) = "100000" then
						-- now that paging is introduced we need to move scratchpad (1k here)
						-- out of harm's way. Scartchpad at FD000 to keep it safe from paging.
						if scratch_1k_i='1' then
							sram_addr_bus <= "000000" & x"FD" & "00" & cpu_addr(9 downto 1);
						else
							sram_addr_bus <= "000000" & x"FD" & X"3" & cpu_addr(7 downto 1);
						end if;
					else
						-- regular RAM access
						-- Top 256K is CPU SAMS RAM for now, so we have 18 bit memory addresses for RAM
							sram_addr_bus <= "000001" & translated_addr(7 downto 0) & cpu_addr(11 downto 1);
					end if;
				end if;

				if MEM_n = '0' and go_write = '1' 
					and cpu_addr(15 downto 12) /= x"9"			-- 9XXX addresses don't go to RAM
					and cpu_addr(15 downto 11) /= x"8" & '1'	-- 8800-8FFF don't go to RAM
					and cpu_addr(15 downto 13) /= "000"			-- 0000-1FFF don't go to RAM
					and ((tifdc_en = '1' and cpu_addr(15 downto 13) /= "010") or			-- 4000-5FFF don't go to RAM (DISK DSR)
					     (myarcfdc_en = '1' and cpu_addr(15 downto 12) /= "0100") )			-- 4000-fFFF don't go to RAM (DISK DSR)
					and (cartridge_cs='0' 							-- writes to cartridge region do not go to RAM
						or (cart_type_i = 1 and cpu_addr(15 downto 10) = "011011")	-- MBX Cart
						or (cart_type_i = 5 and cpu_addr(15 downto 12) = "0111"))	-- MiniMem Cart
				then
						cpu_mem_write_pending <= '1';
				end if;

				if cpu_single_step(1 downto 0)="11" and cpu_holda = '0' then
					-- CPU single step is desired, and CPU is out of hold despite cpu_singe_step(0) being '1'.
					-- This must mean that the CPU is started to execute an instruction, so zero out bit 1
					-- which controls the stepping.
					cpu_single_step(1) <= '0';	
				end if;

				-- memory controller state machine
				case mem_state is
					when idle =>
						debug_sram_ce0 <= '1';
						debug_sram_WE <= '1';
						if mem_write_rq = '1' and mem_addr(20)='0' and cpu_holda='1' then
							-- normal memory write
							sram_addr_bus <= "0000" & mem_addr(21 downto 1);	-- setup address
							mem_state <= wr0;
						elsif mem_read_rq = '1' and mem_addr(20)='0' and cpu_holda='1' then
							sram_addr_bus <= "0000" & mem_addr(21 downto 1);	-- setup address
							mem_state <= rd0;
						elsif MEM_n = '0' and rd_sampler(1 downto 0) = "10" then
							-- init CPU read cycle
							mem_state <= cpu_rd0;
							debug_sram_ce0 <= '0';	-- init read cycle
						elsif cpu_mem_write_pending = '1' then
							-- init CPU write cycle
							mem_state <= cpu_wr1;	-- EPEP jump directly to state 1!!!
							debug_sram_ce0 <= '0';	-- initiate write cycle
							debug_sram_WE <= '0';	
							cpu_mem_write_pending <= '0';
						end if;
					when wr0 => 
						debug_sram_ce0 <= '0';	-- issue write strobes
						debug_sram_WE <= '0';	
						mem_state <= wr1;	
					when wr1 => mem_state <= wr2;	-- waste time
					when wr2 =>							-- terminate memory write cycle
						debug_sram_WE <= '1';
						debug_sram_ce0 <= '1';
						mem_state <= grace;

					-- states to handle read cycles
					when rd0 => 
						debug_sram_ce0 <= '0';	-- init read cycle
						mem_state <= rd1;
					when rd1 => mem_state <= rd2;	-- waste some time
					when rd2 => 
						debug_sram_ce0 <= '1';
						mem_state <= grace;	
					when grace =>						-- one cycle grace period before going idle.
						mem_state <= idle;			-- thus one cycle when mem_write_rq is not sampled after write.

					-- CPU read cycle
					when cpu_rd0 => mem_state <= cpu_rd1;
					when cpu_rd1 => 
						mem_state <= cpu_rd2;
						if sram_capture then
							sram_capture <= False;
						end if;
					when cpu_rd2 =>
						debug_sram_ce0 <= '1';
						mem_state <= grace;

					-- CPU write cycle
					when cpu_wr0 => mem_state <= cpu_wr1;
					when cpu_wr1 => mem_state <= cpu_wr2;
					when cpu_wr2 =>
						mem_state <= grace;
						debug_sram_WE <= '1';
						debug_sram_ce0 <= '1';
						mem_state <= grace;
				end case;

				-- Handle control state transfer is a separate
				-- state machine in order not to disturb the TMS99105.
				case ctrl_state is 
					when idle =>
						if mem_read_rq = '1' and mem_addr(20)='1' then
							ctrl_state <= control_read;
						elsif mem_write_rq = '1' and mem_addr(20)='1' then 
							ctrl_state <= control_write;
						end if;
					when control_read =>
						ctrl_state <= ack_end;
					when ack_end =>
						ctrl_state <= idle;
					when control_write =>
						ctrl_state <= ack_end;
				end case;

				if cpu_reset_ctrl(1)='0' then
					basic_rom_bank <= "000000";	-- Reset ROM bank selection
					mbx_rom_bank <= "00";
					uber_rom_bank <= (others => '0');
				end if;

				-- CPU signal samplers
				if cpu_as='1' then
					alatch_counter <= std_logic_vector(to_unsigned(1+to_integer(unsigned(alatch_counter)), alatch_counter'length));
				end if;
				wr_sampler <= wr_sampler(wr_sampler'length-2 downto 0) & WE_n;
				rd_sampler <= rd_sampler(rd_sampler'length-2 downto 0) & RD_n;
				if myarcfdc_en = '1' and disk_page_ena = '1' then
					rst_sampler <= rst_sampler(rst_sampler'length-2 downto 0) & cru1100_regs(1);
				end if;
				cruclk_sampler <= cruclk_sampler(cruclk_sampler'length-2 downto 0) & cpu_cruclk;
				if (clk_en_10m7_i = '1') then
					vdp_wr <= '0';
					vdp_rd <= '0';
				end if;
				grom_we <= '0';
				pcode_grom_we	<= '0';
				if (psg_ready_s = '1') then
					tms9919_we <= '0';
				end if;				
				paging_wr_enable <= '0';
				if sams_regs(6)='0' then	-- if sams_regs(6) is set I/O is out and paged RAM is there instead
					if go_write = '1' and MEM_n='0' then
						if cpu_addr(15 downto 8) = x"80" then
--							outreg <= data_from_cpu;			-- write to >80XX is sampled in the output register
						elsif cpu_addr(15 downto 8) = x"8C" then
							vdp_wr <= '1';
						elsif cpu_addr(15 downto 8) = x"9C" then
							grom_we <= '1';			-- GROM writes
						elsif cpu_addr(15 downto 0) = x"5FFE" and pcode_en = '1' and pcode_regs(0) = '1' then
							pcode_grom_we <= '1';			-- PCode - GROM writes
						elsif cartridge_cs='1' and sams_regs(5)='0' and cart_type_i = 0 then
							basic_rom_bank <= cpu_addr(6 downto 1);	-- capture ROM bank select
						elsif cartridge_cs='1' and cpu_addr(12 downto 1)='0'&x"FF"&"111" and cart_type_i = 1 then -- mbx bank switch (>6FFE)
							mbx_rom_bank <= data_from_cpu(9 downto 8);
						elsif cartridge_cs='1' and cpu_addr(14 downto 3)=x"E00" and cart_type_i = 2 then -- Paged7 bank switch (>7000 - 7006) 
							mbx_rom_bank <= cpu_addr(2 downto 1);
						elsif cartridge_cs='1' and (cpu_addr(15 downto 12)=x"6" or cpu_addr(15 downto 12)=x"7") and cart_type_i = 3 then -- Paged378 bank switch (>6000 - 61FE) 
							uber_rom_bank <= (cpu_addr(12 downto 1) and cart_8k_banks(11 downto 0));
						elsif cartridge_cs='1' and cpu_addr(14 downto 7)=x"C0" and cart_type_i = 4 then -- Paged379 bank switch (>6000 - 607E) 
							uber_rom_bank <= (others => '0');
							-- Depending on how many banks the cartridge/rom has, we will need to figure out where the paging registers reside,
							--    since they are inverse (bottom up) than that of say Paged378
							if cart_8k_banks = 1 or cart_8k_banks = 2 then
								uber_rom_bank <= "00000000000" & (not cpu_addr(1) and '1');
							elsif cart_8k_banks = 3 or cart_8k_banks = 4 then
								uber_rom_bank <= "0000000000" & (not cpu_addr(2 downto 1) and "11");
							elsif cart_8k_banks > 4 and cart_8k_banks < 9 then
								uber_rom_bank <= "000000000" & (not cpu_addr(3 downto 1) and "111");
							elsif cart_8k_banks > 8 and cart_8k_banks < 17 then
								uber_rom_bank <= "00000000" & (not cpu_addr(4 downto 1) and "1111");
							elsif cart_8k_banks > 16 and cart_8k_banks < 33 then
								uber_rom_bank <= "0000000" & (not cpu_addr(5 downto 1) and "11111");
							elsif cart_8k_banks > 32 and cart_8k_banks < 65 then
								uber_rom_bank <= "000000" & not cpu_addr(6 downto 1) and "111111";
							end if;
						elsif cpu_addr(15 downto 8) = x"84" then	
							tms9919_we <= '1';		-- Audio chip write
							audio_data_out <= data_from_cpu(15 downto 8);
						elsif paging_registers = '1' and sams_en_i = '1' then 
							paging_wr_enable <= '1';
						end if;
					end if;	
					if MEM_n='0' and rd_sampler(1 downto 0)="00" and cpu_addr(15 downto 8)=x"88" then
						vdp_rd <= '1';
					end if;
					grom_rd <= '0';
					if MEM_n='0' and rd_sampler(1 downto 0)="00" and cpu_addr(15 downto 8) = x"98" then
						grom_rd <= '1';
					end if;
					pcode_grom_rd <= '0';
					if MEM_n='0' and rd_sampler(1 downto 0)="00" and (cpu_addr(15 downto 0) = x"5BFC" or cpu_addr(15 downto 0) = x"5BFE") then
						pcode_grom_rd <= '1';
					end if;
				end if;

				-- TMS9901
				-- Not Connected Pins - set to 1 (Inactive)
				cru9901(1)  <= '1';
--				-- Map the epGPIO pins to the proper CRU bit even though we don't currently use them
				cru9901(3)  <= epGPIO_i(0);
				cru9901(4)  <= epGPIO_i(1);
				cru9901(5)  <= epGPIO_i(2);
				cru9901(6)  <= epGPIO_i(3);
				cru9901(7)  <= epGPIO_i(4);
				cru9901(8)  <= epGPIO_i(5);
				cru9901(9)  <= epGPIO_i(6);
				cru9901(10) <= epGPIO_i(7);

				cru9901(11) <= cassette_bit_i;
				cru9901(12) <= '1';				-- Always 1 - Attached to Pull up Resistor (5v)
				cru9901(13) <= cru9901(25);	-- Bit 13 Mirrors Bit 25 (Cassette Out)
				cru9901(14) <= cru9901(24);	-- Bit 14 Mirrors Bit 24 (Audio Gate)
				cru9901(15) <= cru9901(23);	-- Bit 15 Mirrors Bit 23 (CS2 Motor)
				cru9901(16) <= '0';
				cru9901(17) <= '0';

				-- Other CRU mirroring
				cru9901(26) <= cru9901(18);	-- Bit 26 Mirrors Bit 18 (Select Keyboard Column or Joystick)
				cru9901(28) <= cru9901(10);	-- Bit 28 Mirrors Bit 10 (Keyboard)
				cru9901(27) <= cassette_bit_i;
				cru9901(29) <= cru9901(9);		-- Bit 29 Mirrors Bit 9  (Keyboard)
				cru9901(30) <= cru9901(8);		-- Bit 30 Mirrors Bit 8  (Keyboard)
				cru9901(31) <= cru9901(7);		-- Bit 31 Mirrors Bit 7  (Keyboard)

				cassette_bit_o <= cru9901(25);
				
				if tms9901Counter = 0 then											
					tms9901Counter <= tms9901NumCycles; --"11" & x"94";				-- Reset Ph4 counter to 916 (x394)
					if timer9901 = 0 and timer9901Load /= 0 then				-- If tms timer hits 0 and the clock register isn't 0, then reset timer and throw an interrupt -- was at 0, but from looks of how Mame process the cycles, it decrements first, then compares to 0 to throw interrupt.  We skip that step
						timer9901 <= timer9901Load;
						if cru9901IntMask(3) = '1' then 
							tms9901IntReq_n <= '0';
						end if;
					else
						timer9901 <= (timer9901 - 1); -- and ("11111111111111");
					end if;
				else
					tms9901Counter <= tms9901Counter - 1;
				end if;
				if cru9901(0) = '0' then
					timer9901Read <= timer9901;					-- TMS timer Read registered updated with current countdown
				end if;

-----------------------------------------------------------------------------------------------------------
--------------------------------------------------TMS9901--------------------------------------------------
-----------------------------------------------------------------------------------------------------------
------------------------------------------------CRU WRITES-------------------------------------------------
-----------------------------------------------------------------------------------------------------------
				-- CRU cycle to TMS9901
				if MEM_n='1' and cpu_addr(15 downto 8)=x"00" and go_cruclk = '1' then
					if cpu_addr(5 downto 1) = "00000" then -- 0
						cru9901(0) <= cpu_cruout;
						if cru9901(0) = '1' then
							timer9901Read <= timer9901;												-- 9901 just entered timer mode, update timer read register with current timer value
						end if;
					elsif cpu_addr(5 downto 1) >= "10000" then -- 16
						cru9901(to_integer(unsigned(cpu_addr(5 downto 1)))) <= cpu_cruout;
					elsif cpu_addr(5 downto 1) = "01111" then	-- 15
						if cru9901(0) = '1' then
							if cpu_cruout = '0' then													-- A 0 written to bit 15 while in timer mode does a soft reset
								cru9901(0) <= '0';
								cru9901IntMask <= x"0000";
								cru9901IntMask(1) <= '0';
								cru9901IntMask(2) <= '0';
								cru9901IntMask(3) <= '0';
								cru9901(25) <= '0';
								cru9901(27) <= '0';
								timer9901Load <= (others => '0');
								timer9901 <= (others => '0');
							end if;
						else
							cru9901IntMask(15) <= cpu_cruout;
						end if;
					else																						-- All other bits (1-14 should only be left)
						if cru9901(0) = '1' then
							timer9901Load(to_integer(unsigned(cpu_addr(5 downto 1)))-1) <= cpu_cruout;
							timer9901 <= timer9901Load;
							timer9901(to_integer(unsigned(cpu_addr(5 downto 1)))-1) <= cpu_cruout;			-- temporarly doing this because 
						else
							cru9901IntMask(to_integer(unsigned(cpu_addr(5 downto 1)))) <= cpu_cruout;
							if cpu_addr(5 downto 1) = "00011" then -- 3
								tms9901IntReq_n <= '1';
							end if;
						end if;
					end if;
				end if;

				
-- Flandango - CRU writes				
				-- CRU write cycle to disk control system
				if MEM_n='1' and cpu_addr(15 downto 4)= x"110" and fdc_en = '1' and go_cruclk = '1' then
					cru1100_regs(to_integer(unsigned(cpu_addr(3 downto 1)))) <= cpu_cruout;
				end if;
				-- SAMS register writes. 
				if MEM_n='1' and cpu_addr(15 downto 4) = x"1E0" and go_cruclk = '1' then
					sams_regs(to_integer(unsigned(cpu_addr(3 downto 1)))) <= cpu_cruout;
				end if;				
--				-- TIPI register writes. 
				if MEM_n='1' and cpu_addr(15 downto 4) = "0001" & tipi_crubase & "0000" and tipi_en = '1' and go_cruclk = '1' then
					tipi_regs(to_integer(unsigned(cpu_addr(3 downto 1)))) <= cpu_cruout;
				end if;				
				-- PCode register writes. 
				if MEM_n='1' and cpu_addr(15 downto 4) = x"1F0" and pcode_en = '1' and go_cruclk = '1' then
					pcode_regs(to_integer(unsigned(cpu_addr(3 downto 1)))) <= cpu_cruout;
				end if;				

				-- PCode DSR Bank Selection
				if MEM_n='1' and  cpu_addr(15 downto 0) = x"1F80" and pcode_en = '1' and go_cruclk = '1' then
					pcode_dsr_bank <= cpu_cruout;
				end if;

				-- Precompute cru_read_bit in case this cycle is a CRU read 
-----------------------------------------------------------------------------------------------------------
--------------------------------------------------TMS9901--------------------------------------------------
-----------------------------------------------------------------------------------------------------------
-------------------------------------------------CRU READS-------------------------------------------------
-----------------------------------------------------------------------------------------------------------

				cru_read_bit <= '1';
				-- Read Keyboard
				if cpu_addr(15 downto 1) & '0' >= 6 and cpu_addr(15 downto 1) & '0' < 22 and cru9901(0) = '0' then
					-- 6 = 0110
					--	8 = 1000
					-- A = 1010 
					ki := to_integer(unsigned(cpu_addr(3 downto 1))) - 3; -- row select on address
					case ki is
						when 0 => cru_read_bit <= epGPIO_i(0);
						when 1 => cru_read_bit <= epGPIO_i(1);
						when 2 => cru_read_bit <= epGPIO_i(2);
						when 3 => cru_read_bit <= epGPIO_i(3);
						when 4 => cru_read_bit <= epGPIO_i(4);
						when 5 => cru_read_bit <= epGPIO_i(5);
						when 6 => cru_read_bit <= epGPIO_i(6);
						when 7 => cru_read_bit <= epGPIO_i(7);
						when others => null;
					end case;
					if ki = 0 and cru9901IntMask(3) = '1' and timer9901Load /= 0 then 										-- If INT3 Mask is enabled and Timer is running, INT3 doesn't generate interrupts so we return a 1 (inactive)
						cru_read_bit <= '1';
					end if;
				elsif cpu_addr(15 downto 1) & '0' = x"0000" then
					cru_read_bit <= cru9901(0);
				elsif cpu_addr(15 downto 1) & '0' = x"0002" and cru9901(0) = '0' then
					cru_read_bit <= '1';									-- External Interrupt (not implement at the moment)
				elsif cpu_addr(15 downto 1) & '0' = x"0004" and cru9901(0) = '0' then
					cru_read_bit <= vdp_interrupt;					-- VDP interrupt status (read with TB 2 instruction)
					
					
					
				elsif cpu_addr(15 downto 1) & '0' = x"001E" and cru9901(0) = '1' then
					cru_read_bit <= conl_int;
				
				elsif cpu_addr(15 downto 1) & '0' >= 2 and cpu_addr(15 downto 1) & '0' <= x"1C" and cru9901(0) = '1' then							--Flanny read current 9901 timer read-back register
					cru_read_bit <= timer9901Read(to_integer(unsigned('0' & cpu_addr(4 downto 1)))-1);
				elsif cpu_addr(15 downto 1) & '0' >= x"16" and cpu_addr(15 downto 1) & '0' <= x"3E" then		-- 9901 CRU bits 11-31
					if cpu_addr(15 downto 1) & '0' = x"36" then																-- Tape in, reading directly from cassette_bit_i instead of cru9901(27) to avoid the 1+ cycles offset
						cru_read_bit <= cassette_bit_i;
					else
						cru_read_bit <= cru9901(to_integer(unsigned(cpu_addr(15 downto 1))));
					end if;
					if cpu_addr(15 downto 1) & '0' >= x"20" and cru9901(0) = '1' then									-- If 9901 is in timer mode and we do any reads on bits 16+, we get out of timer mode
						cru9901(0) <= '0';
						cru_read_bit <= cru9901(to_integer(unsigned(cpu_addr(5 downto 1))));
					end if;



-----------------------------------------------------------------------------------------------------------
------------------------------------------------NON-TMS9901------------------------------------------------
-----------------------------------------------------------------------------------------------------------

				elsif cpu_addr(15 downto 4) = x"110" and fdc_en = '1' then
					if tifdc_en = '1' then
						case to_integer(unsigned(cpu_addr(3 downto 1))) is
							when 0 => cru_read_bit <= disk_hlt; -- HLD
							when 1 => cru_read_bit <= cru1100_regs(4) and disk_motor; -- DS1
							when 2 => cru_read_bit <= cru1100_regs(5) and disk_motor; -- DS2
							when 3 => cru_read_bit <= cru1100_regs(6) and disk_motor; -- DS3
							when 4 => cru_read_bit <= not disk_motor;
							when 5 => cru_read_bit <= '0';
							when 6 => cru_read_bit <= '1';
							when 7 => cru_read_bit <= disk_side;
							when others => null;
						end case;
					elsif myarcfdc_en = '1' then
						case to_integer(unsigned(cpu_addr(3 downto 1))) is
							when 0 => cru_read_bit <= disk_irq; -- Disk INTRQ
							when 1 => cru_read_bit <= disk_drq; -- Disk DRQ
							when 2 => cru_read_bit <= '0'; --fdc_turbo;      -- Turbo mode (currently not implemented)
							when 3 => cru_read_bit <= null;     -- Not connected on real hardware
							when 4 => cru_read_bit <= '0'                 ; -- Drive 4 Head Seek Speed   0 = 6ms, 1= 20ms/2ms (FD1770/FD1772) (bit flipped when read by cru)
							when 5 => cru_read_bit <= not myarcSwitches(2); -- Drive 3 Head Seek Speed   0 = 6ms, 1= 20ms/2ms (FD1770/FD1772) (bit flipped when read by cru)
							when 6 => cru_read_bit <= not myarcSwitches(1); -- Drive 2 Head Seek Speed   0 = 6ms, 1= 20ms/2ms (FD1770/FD1772) (bit flipped when read by cru)
							when 7 => cru_read_bit <= not myarcSwitches(0); -- Drive 1 Head Seek Speed   0 = 6ms, 1= 20ms/2ms (FD1770/FD1772) (bit flipped when read by cru)
							when others => null;
						end case;
					end if;
				elsif cpu_addr(15 downto 4) = x"1E0" then
					cru_read_bit <= sams_regs(to_integer(unsigned(cpu_addr(3 downto 1))));
				elsif cpu_addr(15 downto 4) = "0001" & tipi_crubase & "0000" and tipi_en = '1' then
					cru_read_bit <= tipi_regs(to_integer(unsigned(cpu_addr(3 downto 1))));
				elsif cpu_addr(15 downto 4) = x"1F0" and pcode_en = '1' then
					cru_read_bit <= pcode_regs(to_integer(unsigned(cpu_addr(3 downto 1))));
				end if;

			end if;
		end if;	-- rising_edge
	end process;

	tifdc_en <= not myarcfdc_en;
	disk_side <= cru1100_regs(7) when tifdc_en = '1' else cru1100_regs(2) when myarcfdc_en = '1';
	
	cpu_hold <= '1' when mem_read_rq='1' or mem_write_rq='1' or (cpu_single_step(0)='1' and cpu_single_step(1)='0') 
							or flashLoading = '1' or pause_i = '1' else '0'; -- issue DMA request
	--DEBUG1 <= go_write;

	go_write <= '1' when wr_sampler = "1000" else '0'; -- wr_sampler = "1110" else '0';
	go_cruclk <= '1' when cruclk_sampler(1 downto 0) = "01" else '0';

	vdp_data_out(7 downto 0) <= x"00";
	data_to_cpu <= 
		tipi_data & tipi_data when tipi_en = '1' and tipi_regs(0) = '1' and MEM_n = '0' and WE_n = '1' and ( cpu_addr(15 downto 0) >= x"5FF9" and cpu_addr(15 downto 0) <= x"5FFF") else		-- Tipi control registers

		vdp_data_out         			when sams_regs(6)='0' and cpu_addr(15 downto 10) = "100010" else	-- 10001000..10001011 (8800..8BFF)
		speech_data_out & x"00"       when sams_regs(6)='0' and cpu_addr(15 downto 10) = "100100" and speech_i='1' else	-- speech address read (9000..93FF)
		x"6000"                       when sams_regs(6)='0' and cpu_addr(15 downto 10) = "100100" and speech_i='0' else	-- speech address read (9000..93FF)
		grom_data_out & x"00" 			when sams_regs(6)='0' and cpu_addr(15 downto 8) = x"98" and cpu_addr(1)='1' else	-- GROM address read
		pcode_grom_data_out & x"00" 	when sams_regs(6)='0' and cpu_addr(15 downto 0) = x"5BFE" and pcode_regs(0) = '1' and pcode_en = '1' else	-- GROM address read
		pager_data_out(7 downto 0) & pager_data_out(7 downto 0) when paging_registers = '1' else	-- replicate pager values on both hi and lo bytes
		sram_16bit_read_bus(15 downto 8) & x"00" when sams_regs(6)='0' and cpu_addr(15 downto 8) = x"98" and cpu_addr(1)='0' and grom_ram_addr(0)='0' and grom_selected='1' else
		sram_16bit_read_bus(7 downto 0)  & x"00" when sams_regs(6)='0' and cpu_addr(15 downto 8) = x"98" and cpu_addr(1)='0' and grom_ram_addr(0)='1' and grom_selected='1' else
		sram_16bit_read_bus(15 downto 8) & x"00" when sams_regs(6)='0' and cpu_addr(15 downto 0) = x"5BFC" and pcode_grom_ram_addr(0)='0' and pcode_grom_selected='1' and pcode_en = '1' else
		sram_16bit_read_bus(7 downto 0) & x"00" when sams_regs(6)='0' and cpu_addr(15 downto 0) = x"5BFC" and pcode_grom_ram_addr(0)='1' and pcode_grom_selected='1' and pcode_en = '1' else
	   x"FF00"                       when sams_regs(6)='0' and cpu_addr(15 downto 8) = x"98" and cpu_addr(1)='0' and grom_selected='0' else
	   x"FF00"                       when sams_regs(6)='0' and cpu_addr(15 downto 0) = x"5BFC" and pcode_grom_selected='0' and pcode_en = '1' else
		-- CRU space signal reads
		cru_read_bit & "000" & x"000"	when MEM_n='1' else
--		x"FFF0"								when MEM_n='1' else -- other CRU
		-- line below commented, paged memory repeated in the address range as opposed to returning zeros outside valid range
		--	x"0000"							when translated_addr(15 downto 6) /= "0000000000" else -- paged memory limited to 256K for now
		not disk_dout & not disk_dout when disk_cs = '1' and tifdc_en = '1' else
		disk_dout & disk_dout         when disk_cs = '1' and myarcfdc_en = '1' else
		sram_16bit_read_bus(15 downto 0);		-- data to CPU
	
  -----------------------------------------------------------------------------
  -- TMS9928A Video Display Processor
  -----------------------------------------------------------------------------
  vdp18_b : work.vdp18_core
    generic map (
--      is_pal_g      => is_pal_g,
      compat_rgb_g  => compat_rgb_g
    )
    port map (
      clk_i         => clk_i,
      clk_en_10m7_i => clk_en_10m7_i,
      reset_n_i     => real_reset,--
      csr_n_i       => not vdp_rd,--
      csw_n_i       => not vdp_wr,--
      mode_i        => cpu_addr(1),
      int_n_o       => vdp_interrupt,--
      cd_i          => data_from_cpu(15 downto 8),--
      cd_o          => vdp_data_out(15 downto 8),--
      vram_we_o     => vram_we_o,
      vram_a_o      => vram_a_o,
      vram_d_o      => vram_d_o,
      vram_d_i      => vram_d_i,
      col_o         => col_o,
      rgb_r_o       => rgb_r_o,
      rgb_g_o       => rgb_g_o,
      rgb_b_o       => rgb_b_o,
      hsync_n_o     => hsync_n_o,
      vsync_n_o     => vsync_n_o,
      blank_n_o     => blank_n_o,
      hblank_o      => hblank_o,
      vblank_o      => vblank_o,
      comp_sync_n_o => comp_sync_n_o,
		is_pal_g      => is_pal_g
    );
	
	-- GROM implementation - GROM's are mapped to external RAM
	extbasgrom : entity work.gromext port map (
			clk 		=> clk,
			din 		=> data_from_cpu(15 downto 8),
			dout		=> grom_data_out,
			we 		=> grom_we,
			rd 		=> grom_rd,
			selected => grom_selected,	-- output from GROM available, i.e. GROM address is ours
			mode 		=> cpu_addr(5 downto 1),
			reset 	=> real_reset_n,
			addr 		=> grom_ram_addr
		);

	-- GROM implementation for PCode- GROM's are mapped to external RAM
	pcodegrom : entity work.gromext port map (
			clk 		=> clk,
			din 		=> data_from_cpu(15 downto 8),
			dout		=> pcode_grom_data_out,
			we 		=> pcode_grom_we,
			rd 		=> pcode_grom_rd,
			selected => pcode_grom_selected,	-- output from GROM available, i.e. GROM address is ours
			mode 		=> cpu_addr(5 downto 1) and "00001",	-- This is a private grom so it only has one base
			reset 	=> real_reset_n,
			addr 		=> pcode_grom_ram_addr
		);

		
	-- sound chip implementation
--	TMS9919_CHIP: entity work.tms9919
--		generic map (
--			divider_g => 191
--		)
--		port map (
--			clk 		=> clk,
--			reset		=> real_reset_n,
--			data_in 	=> data_from_cpu(15 downto 8),
--			we			=> tms9919_we,
--			dac_out	=> dac_data
--		);		
--		dac_convert: process(dac_data)
--		begin
--			audio_o <= signed(dac_data);
--		end process dac_convert;
  -----------------------------------------------------------------------------
  -- SN76489 Programmable Sound Generator
  -----------------------------------------------------------------------------
  psg_b : work.sn76489_top
    generic map (
      clock_div_16_g => 1
    )
    port map (
      clock_i    => clk_i,
      clock_en_i => clk_en_3m58_s,
      res_n_i    => real_reset,--
      ce_n_i     => not tms9919_we,--
      we_n_i     => not tms9919_we,--
      ready_o    => psg_ready_s,--
      d_i        => audio_data_out,--
      aout_o     => audio_o
    );

	-- memory paging unit implementation
	paging_regs_visible 	<= sams_regs(0);			-- 1E00 in CRU space
	paging_enable 			<= sams_regs(1);			-- 1E02 in CRU space

	-- the pager registers can be accessed at >4000 to >5FFF when paging_regs_visible is set
	paging_registers <= '1' when paging_regs_visible = '1' and (cpu_rd='1' or cpu_wr='1') and cpu_addr(15 downto 13) = "010" else '0';
	page_reg_read <= '1' when paging_registers = '1' and cpu_rd ='1' else '0';	

	pager_data_in <= x"00" & data_from_cpu(15 downto 8);	-- my own extended mode not supported here

	pager : pager612 port map (
		clk		 => clk,
		abus_high => cpu_addr(15 downto 12),
		abus_low  => cpu_addr(4 downto 1),
		dbus_in   => pager_data_in,
		dbus_out  => pager_data_out,
		mapen 	 => paging_enable,				-- ok
		write_enable	 => paging_wr_enable,	-- ok
		page_reg_read   => page_reg_read,
		translated_addr => translated_addr,		-- ok
		access_regs     => paging_registers		-- ok
		);

	MEM_n <= not (cpu_rd or cpu_wr);
	WE_n <= not cpu_wr;
	RD_n <= not cpu_rd;
	cpu_cruin <= cru_read_bit;
	cpu_int_req <= not conl_int and cpu_reset_ctrl(2);	-- cpu_reset_ctrl(2), when cleared, allows us to mask interrupts

	cpu : tms9900
		generic map (
			cycle_clks_g => 16 -- orig=14
		)
	PORT MAP (
          clk => clk,
          reset => cpu_reset,
          addr_out => cpu_addr,
          data_in => data_to_cpu,
          data_out => data_from_cpu,
          rd => cpu_rd,
          wr => cpu_wr,
          ready => (speech_ready or not speech_i) and cpu_ready,
          iaq => cpu_iaq,
          as => cpu_as,
			 alu_debug_arg1 => open,
			 alu_debug_arg2 => open,
			 int_req => cpu_int_req,
			 ic03 => "0001",						--Ti994/A is fixed at this value
			 int_ack => cpu_int_ack,
		    cpu_debug_out => open,
			 cruin => cpu_cruin,
			 cruout => cpu_cruout,
			 cruclk => cpu_cruclk,
			 hold => cpu_hold,
			 holda => cpu_holda,
			 waits => waits,
--			 waits => waitStates,
			 scratch_en => '0',
          stuck => cpu_stuck,
			 turbo => turbo_i
        );

	speech : tispeechsyn
	PORT MAP (
          clk_i => clk,
          reset_n_i => not cpu_reset,
          addr_i => cpu_addr,
          data_o => speech_data_out,
          data_i => data_from_cpu(15 downto 8),
			 MEM_n_i => MEM_n,
			 dbin_i => cpu_rd,
			 ready_o => speech_ready,
			 aout_o => speech_o,
			 sr_re_o => sr_re_o,
			 sr_addr_o => sr_addr_o,
			 sr_data_i => sr_data_i,
			 model => speech_model
        );

	speech_conv <= unsigned(resize(speech_o,speech_conv'length)) + to_unsigned(128,11) when speech_i = '1' else to_unsigned(0,speech_conv'length);

	tape_audio <= cru9901(27) and cru9901IntMask(3) and not cru9901IntMask(2) and cru9901(22) and not cru9901(24) and tape_audio_en;
	audio_total_o <= std_logic_vector(unsigned("0" & (audio_o(7) xor cru9901(25)) & audio_o(6 downto 3) & (audio_o(2) xor tape_audio) & audio_o(1 downto 0) & "00") + speech_conv);

	-----------------------------------------------------------------------------
	-- TIPI
	-----------------------------------------------------------------------------

	tipi : tipi_top
	port map
	(
		
--		db_dir		=> tipi_db_dir,	-- Which direction the data is flowing
--		db_en			=> tipi_db_en,	-- OCTAL BUS' OE line, enable/disable data flow from eeprom

-- START USER PORT CONNECTION		
		r_clk			=> rpi_clk,
		-- 0 = Data or 1 = Control byte selection
		r_cd			=> rpi_cd,
		r_dout		=> rpi_dout,
		r_le			=> rpi_le,
		-- R|T 0 = RPi or 1 = TI originating data 
		r_rt			=> rpi_rt,
		r_din			=> rpi_din,
		r_reset		=> rpi_reset,
-- END USER PORT CONNECTION

		ti_dbin		=> cpu_rd,		-- TMS9900 CPU_RD   - request for data from bus
		ti_memen		=> MEM_n,
		ti_we			=> WE_n,		-- TMS9900 NOT CPU_WR
		cru_state	=> tipi_regs,

		ti_a	 		=> cpu_addr,
		tp_d_i		=> data_from_cpu(7 downto 0),
		tp_d_o		=> tipi_data
		
	);
	

	-----------------------------------------------------------------------------
	-- Disk subsystem (PHP1240)
	-----------------------------------------------------------------------------
	disk_ds <= '1' when unsigned(img_size(19 downto 8)) > 360 else '0';
	disk_cs <= '1' when disk_page_ena = '1' and ((tifdc_en = '1' and cpu_addr(15 downto 4) = x"5FF") or (myarcfdc_en = '1' and cpu_addr(15 downto 3) = x"5F0" & '0')) and (disk_rd = '1' or disk_wr = '1') else '0';
	disk_rd <= not cpu_addr(3) and cpu_rd when tifdc_en = '1' else cpu_rd when myarcfdc_en = '1' and disk_page_ena = '1' else '0';
	disk_wr <= cpu_addr(3) and cpu_wr when tifdc_en = '1' else cpu_wr when myarcfdc_en = '1' and disk_page_ena = '1' else '0';
	disk_rw <= not disk_wr;
	disk_din <= not data_from_cpu(15 downto 8) when tifdc_en = '1' else data_from_cpu(7 downto 0) when myarcfdc_en = '1';
	floppy_reset <= '0' when reset_n_s = '0' or rst_sampler = "0001" else '1';
	dden <= '1' when tifdc_en = '1' else cru1100_regs(3) when myarcfdc_en = '1' else '0';
	m80_tracks <= '1' when myarc80 = '1' and ((disk_sel = "001" and myarcSwitches(0) = '1') or (disk_sel = "010" and myarcSwitches(1) = '1') or (disk_sel = "100" and myarcSwitches(2) = '1')) else '0';

	fdc : fdc1772
	port map
	(
		clkcpu  => clk,
		clk8m_en => disk_clk_en,
		fd1771 => tifdc_en,
		dden => dden,
		turbo => fdc_turbo,
		fd80 => m80_tracks,

		floppy_drive => "1"&not disk_sel(2 downto 0),
		floppy_side => not disk_side,
		floppy_reset => floppy_reset,

		irq => disk_irq,
		drq => disk_drq,

		cpu_addr => cpu_addr(2 downto 1),
		cpu_sel => disk_cs,
		cpu_rw => disk_rw,
		cpu_din => disk_din,
		cpu_dout => disk_dout,

		-- The following signals are all passed in from the Top module
		img_mounted => img_mounted,
		img_wp => img_wp,
		img_size => img_size,
		img_ds => disk_ds,

		sd_lba_fd0 => sd_lba_fd0,
		sd_lba_fd1 => sd_lba_fd1,
		sd_lba_fd2 => sd_lba_fd2,
		sd_rd => sd_rd,
		sd_wr => sd_wr,
		sd_ack => sd_ack,
		sd_buff_addr => sd_buff_addr,
		sd_dout => sd_dout,
		sd_din_fd0 => sd_din_fd0,
		sd_din_fd1 => sd_din_fd1,
		sd_din_fd2 => sd_din_fd2,
		sd_dout_strobe => sd_dout_strobe,
		drive_led => drive_led
	);

	process(clk, reset_n_s)
	begin
		if reset_n_s = '0' then
			disk_clk_en <= '0';
		elsif rising_edge(clk) then
			disk_clk_cnt <= disk_clk_cnt + 1;
			disk_clk_en <= '0';
			if disk_clk_cnt = 1 then -- was 20
				disk_clk_en <= '1';
				disk_clk_cnt <= (others => '0');
			end if;
		end if;
	end process;

	-- LS123 monostable, 4.5 sec pulse
	process(clk, reset_n_s)
	begin
		if reset_n_s = '0' then
			disk_motor <= '0';
			disk_motor_cnt <= 0;
		elsif rising_edge(clk) then
			disk_motor_clk_d <= disk_motor_clk;
			if disk_motor_clk_d = '0' and disk_motor_clk = '1' then
				disk_motor <= '1';
				disk_motor_cnt <= 193295430;
			elsif disk_motor_cnt /= 0 then
				disk_motor_cnt <= disk_motor_cnt - 1;
			else
				disk_motor <= '0';
			end if;
		end if;
	end process;

	cpu_ready <= disk_rdy;
	disk_rdy <= '1' when (tifdc_en = '1' and disk_wait_en = '0') or disk_proceed = '1' or disk_cs = '0' or myarcfdc_en = '1' else '0';
	-- disk wait generation
	process(clk, reset_n_s)
	begin
		if reset_n_s = '0' then
			disk_proceed <= '0';
		elsif rising_edge(clk) then
			disk_atn <= disk_irq or disk_drq;
			if disk_cs = '0' then
				disk_proceed <= '0';
			elsif disk_atn = '0' and (disk_irq or disk_drq) = '1' then
				disk_proceed <= '1';
			end if;
		end if;
	end process;

end Behavioral;

LIBRARY ieee;
USE ieee.std_logic_1164.all;

LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all;

ENTITY dpram16_8 IS
	GENERIC
	(
		widthad				: natural;
		width				: natural := 16;
		outdata_reg_a			: string := "UNREGISTERED";
		outdata_reg_b			: string := "UNREGISTERED"
	);
	PORT
	(
		address_a	: IN STD_LOGIC_VECTOR (widthad-1 DOWNTO 0);
		address_b	: IN STD_LOGIC_VECTOR (widthad DOWNTO 0);
		clock		: IN STD_LOGIC ;
		data_a		: IN STD_LOGIC_VECTOR (width-1 DOWNTO 0);
		data_b		: IN STD_LOGIC_VECTOR (width/2-1 DOWNTO 0);
		wren_a		: IN STD_LOGIC ;
		wren_b		: IN STD_LOGIC ;
		byteena_a	: IN STD_LOGIC_VECTOR (1 DOWNTO 0) ;
		--byteena_b	: IN STD_LOGIC_VECTOR (1 DOWNTO 0) ;
		q_a		: OUT STD_LOGIC_VECTOR (width-1 DOWNTO 0);
		q_b		: OUT STD_LOGIC_VECTOR (width/2-1 DOWNTO 0)
	);
END dpram;


ARCHITECTURE SYN OF dpram16_8 IS

BEGIN

	altsyncram_component : altsyncram
	GENERIC MAP (
		clock_enable_input_a => "BYPASS",
		clock_enable_output_a => "BYPASS",
		clock_enable_input_b => "BYPASS",
		clock_enable_output_b => "BYPASS",
		intended_device_family => "Cyclone III",
		lpm_hint => "ENABLE_RUNTIME_MOD=NO",
		lpm_type => "altsyncram",
		numwords_a => 2**widthad,
		numwords_b => 2**(widthad+1),
		operation_mode => "BIDIR_DUAL_PORT",
		outdata_aclr_a => "NONE",
		outdata_reg_a => outdata_reg_a,
		outdata_aclr_b => "NONE",
		outdata_reg_b => outdata_reg_b,
		power_up_uninitialized => "FALSE",
		read_during_write_mode_port_a => "NEW_DATA_NO_NBE_READ",
		read_during_write_mode_port_b => "NEW_DATA_NO_NBE_READ",
		widthad_a => widthad,
		width_a => width,
		width_byteena_a => 2,
		widthad_b => widthad+1,
		width_b => width/2,
		width_byteena_b => 1
	)
	PORT MAP (
		wren_a => wren_a,
		wren_b => wren_b,
		clock0 => clock,
		clock1 => clock,
		address_a => address_a,
		address_b => address_b,
		data_a => data_a,
		data_b => data_b,
		q_a => q_a,
		q_b => q_b,
		byteena_a => byteena_a
	);
END SYN;

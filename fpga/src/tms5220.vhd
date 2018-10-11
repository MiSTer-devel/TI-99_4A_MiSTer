----------------------------------------------------------------------------------
-- tms5220.vhd
--
-- Implementation of the tms5220 speech chip.
-- The module is not 100% compatible with the orignal design.
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
-----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_MISC.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

entity tms5220 is
	port
	(
		reset     : in STD_LOGIC;
		clk_i     : in STD_LOGIC;
		ce_n_i    : in STD_LOGIC;
		rs_n_i    : in STD_LOGIC;
		ws_n_i    : in STD_LOGIC;
		add1_o    : out STD_LOGIC;
		add2_o    : out STD_LOGIC;
		add4_o    : out STD_LOGIC;
		add8_o    : out STD_LOGIC;
		add8_i    : in STD_LOGIC;
		m0_o      : out STD_LOGIC;
		m1_o      : out STD_LOGIC;
		data_i    : in STD_LOGIC_VECTOR (7 downto 0);
		data_o    : out STD_LOGIC_VECTOR (7 downto 0);
		ready_n_o : out STD_LOGIC;
		int_n_o   : out STD_LOGIC;
		aout_o    : out signed(7 downto 0)
	);
end tms5220;

architecture tms5220_Behavioral of tms5220 is

	constant cmd_reset    : std_logic_vector(2 downto 0) := b"111";
	constant cmd_load     : std_logic_vector(2 downto 0) := b"100";
	constant cmd_speak    : std_logic_vector(2 downto 0) := b"101";
	constant cmd_speakext : std_logic_vector(2 downto 0) := b"110";
	constant cmd_readbyte : std_logic_vector(2 downto 0) := b"001";
	constant cmd_readbr   : std_logic_vector(2 downto 0) := b"011";
	--constant cmd_loadfr   : std_logic_vector(2 downto 0) := b"0x0";

	type fifo_array is array (15 downto 0) of std_logic_vector(7 downto 0);
	signal fifo      : fifo_array;
	signal in_fifo   : std_logic_vector(3 downto 0);
	signal out_fifo  : std_logic_vector(6 downto 0);
	signal fifo_len  : unsigned(4 downto 0);

	signal loading   : integer;
	signal external  : std_logic;
	signal speaking  : std_logic;
	signal last_rs_n : std_logic;
	signal last_ws_n : std_logic;
	signal status    : std_logic_vector(2 downto 0);
	signal rdata     : std_logic_vector(7 downto 0);
	signal loadbit   : std_logic_vector(7 downto 0);
	signal readbyte  : std_logic;
	signal m0        : std_logic;
	signal m1        : std_logic;
	signal dummy     : std_logic_vector(1 downto 0);
	signal loadcnt   : std_logic_vector(4 downto 0);

begin
	--only used when m1_o is high
	add1_o <= data_i(0);
	add2_o <= data_i(1);
	add4_o <= data_i(2);
	add8_o <= data_i(3);
	m0_o <= m0;
	m1_o <= m1;
	status(2) <= speaking;
	status(1) <= '1' when fifo_len <= to_unsigned(8, fifo_len'length) else '0';
	status(0) <= '1' when fifo_len = to_unsigned(0, fifo_len'length) else '0';
	data_o <= rdata when readbyte='1' else (status & b"00000");

	process(clk_i, reset)
		variable inc1 : boolean;
		variable dec1 : boolean;
	begin
		if reset = '1' then
			aout_o <= to_signed(0, 8);
			m0 <= '0';
			m1 <= '0';
			ready_n_o <= '0'; --not implemented
			int_n_o <= '0';   --not implemented
			external <= '0';
			speaking <= '0';
			last_ws_n <= '0';
			readbyte <= '0';
			loadbit <= x"80";
			in_fifo <= x"0";
			out_fifo <= b"0000000";
			fifo_len <= to_unsigned(0, 5);
			dummy <= b"00";
			loadcnt <= b"00000";
		elsif rising_edge(clk_i) then
			dec1 := False;
			inc1 := False;
			last_ws_n <= ws_n_i;
			last_rs_n <= rs_n_i;
			m0 <= '0';
			m1 <= '0';
			if (loadcnt(4)='1') then
				--m0 <= '0';
				dummy <= b"11";
				loadcnt <= b"00000";
			elsif (or_reduce(dummy)='1') then
				m0 <= dummy(0);
				dummy <= '0' & dummy(1);
			elsif ((readbyte='1') and or_reduce(loadbit)='1') then
				if (m0='0') then
					rdata <= rdata(6 downto 0) & add8_i;
					m0 <= not loadbit(0); -- 1 except last loadbit
					loadbit <= '0' & loadbit(7 downto 1);
				end if;
			end if;
			if ((rs_n_i = '1') and (last_rs_n = '0')) then --rising edge?
				readbyte <= '0';
			elsif ((ws_n_i = '1') and (last_ws_n = '0')) then --rising edge?
				if (external='0') then
				case data_i(6 downto 4) is
						when cmd_reset =>
							speaking <= '0';
						when cmd_load =>
							m1 <= '1';
							loadcnt <= loadcnt(3 downto 0) & '1';
						when cmd_speak =>
							speaking <= '1';
						when cmd_speakext =>
							external <= '1';
						when cmd_readbyte =>
							loadbit <= x"80";
							readbyte <= '1';
							m0 <= '1';
						when cmd_readbr =>
							speaking <= '1';
						when others => --cmd_loadfr
							speaking <= '1';
					end case;
				else
					if (data_i=x"FF") then
						external <= '0';
					elsif (fifo_len < 16) then
						fifo(to_integer(unsigned(in_fifo))) <= data_i;
						in_fifo <= std_logic_vector(unsigned(in_fifo) + to_unsigned(1, in_fifo'length));
						inc1 := True;
					end if;
				end if;
			end if;
			if inc1 and not dec1 then
				fifo_len <= fifo_len + (1);
			elsif not inc1 and dec1 then
				fifo_len <= fifo_len - (1);
			end if;
		end if;
	end process;

end tms5220_Behavioral;


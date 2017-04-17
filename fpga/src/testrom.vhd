----------------------------------------------------------------------------------
-- Engineer:	Erik Piehl 
-- 
-- Create Date:    07:01:30 04/15/2017 
-- Design Name: 	 testrom.vhd
-- Module Name:    testrom - Behavioral 
-- Project Name: 	 TMS9900 Test ROM code
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity testrom is
    Port ( clk : in  STD_LOGIC;
           addr : in  STD_LOGIC_VECTOR (7 downto 0);
           data_out : out  STD_LOGIC_VECTOR (15 downto 0));
end testrom;

architecture Behavioral of testrom is
	constant romLast : integer := 255;
	type pgmRomArray is array(0 to romLast) of STD_LOGIC_VECTOR (15 downto 0);
	constant pgmRom : pgmRomArray := (  
            x"8300"
           ,x"0008"
           ,x"beef"
           ,x"beef"
           ,x"0203"
           ,x"8340"
           ,x"04d3"
           ,x"0204"
           ,x"8350"
           ,x"0202"
           ,x"0002"
           ,x"cd33"
           ,x"0644"
           ,x"ad02"
           ,x"6802"
           ,x"8350"
           ,x"0283"
           ,x"8342"
           ,x"1301"
           ,x"0380"
           ,x"0201"
           ,x"4444"
           ,x"c801"
           ,x"8360"
           ,x"c820"
           ,x"8360"
           ,x"8350"
           ,x"8060"
           ,x"8350"
           ,x"1301"
           ,x"0380"
           ,x"0200"
           ,x"1234"
           ,x"0380"
           ,x"06a0"
           ,x"00a0"
           ,x"04c1"
           ,x"04e3"
           ,x"0004"
           ,x"0723"
           ,x"0006"
           ,x"04e0"
           ,x"8348"
           ,x"0713"
           ,x"04f3"
           ,x"04f3"
           ,x"04f3"
           ,x"0502"
           ,x"ccc2"
           ,x"10f0"
           ,x"0502"
           ,x"0202"
           ,x"8002"
           ,x"0502"
           ,x"0502"
           ,x"05c3"
           ,x"c143"
           ,x"0585"
           ,x"0605"
           ,x"06c5"
           ,x"0545"
           ,x"0713"
           ,x"0745"
           ,x"0505"
           ,x"0200"
           ,x"1234"
           ,x"0201"
           ,x"0001"
           ,x"c4c0"
           ,x"c0b3"
           ,x"a081"
           ,x"c202"
           ,x"c4c1"
           ,x"a4c1"
           ,x"c820"
           ,x"0004"
           ,x"8344"
           ,x"06a0"
           ,x"00a0"
           ,x"10b4"
           ,x"0204"
           ,x"007b"
           ,x"045b"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
	);
begin

	process(clk)
	variable addr_int : integer range 0 to romLast := 0;
	begin
		if rising_edge(clk) then
			addr_int := to_integer( unsigned( addr ));	-- word address
			data_out <= pgmRom( addr_int );
		end if;
	end process;

end Behavioral;
  
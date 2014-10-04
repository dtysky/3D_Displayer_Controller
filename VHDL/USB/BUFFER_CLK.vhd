library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;

entity BUFFER_CLK is
port
	(
		inclk_usb_self,inclk_usb_out:in std_logic;
		inclk_ram_self:in std_logic;
		c0,c1,c2:out std_logic
	);
end entity;

architecture buffer_clkx of BUFFER_CLK is

begin

	c0<=inclk_usb_self;
	c1<=inclk_usb_out;
	c2<=inclk_ram_self;

end buffer_clkx;

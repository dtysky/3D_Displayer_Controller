--FPGA application for this system.
--copyright(c) 2014 dtysky

--This program is free software; you can redistribute it and/or modify
--it under the terms of the GNU General Public License as published by
--the Free Software Foundation; either version 2 of the License, or
--(at your option) any later version.

--This program is distributed in the hope that it will be useful,
--but WITHOUT ANY WARRANTY; without even the implied warranty of
--MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--GNU General Public License for more details.

--You should have received a copy of the GNU General Public License along
--with this program; if not, write to the Free Software Foundation, Inc.,
--51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_misc.all;
use ieee.std_logic_unsigned.all;


entity BLUETOOTH_CONTROL is

port
	(
		clk_self,pll_lock:in std_logic;
		bluetooth_rqu:in std_logic:='0';
		bluetooth_ack:out std_logic:='0';
		bluetooth_reset:out std_logic:='0';
		bluetooth_data:inout std_logic_vector(3 downto 0):=x"0";
		
		in_rqu:out std_logic:='0';
		in_end:in std_logic:='0';
		data_in:out std_logic_vector(7 downto 0)
		
		--error:std_logic
	);

end entity;


architecture bluetooth of BLUETOOTH_CONTROL is


type states is (free,recieve,ack,sync,reset);
signal state:states:=free;

signal data_buffer:std_logic_vector(7 downto 0):=x"00";

begin

MAIN:process(clk_self,pll_lock)

variable con_recieve:integer range 0 to 3:=0;

begin

	if clk_self'event and clk_self='1' and pll_lock='1' then
		
			
		------------IDLE------------
		if state=free then
			bluetooth_ack<='0';
			bluetooth_reset<='0';
			
			if bluetooth_rqu='1' then
				state<=recieve;
			else
				state<=state;
			end if;
		
		----------RECIEVE-----------
		elsif state=recieve then
			
			if con_recieve=0 then
				data_buffer(7 downto 4)<=bluetooth_data;
				con_recieve:=1;
				state<=ack;
			else
				data_buffer(7 downto 4)<=bluetooth_data;
				con_recieve:=0;
				state<=ack;
			end if;
		
		------------ACK------------
		elsif state=ack then
			bluetooth_ack<='1';
			
			if con_recieve=1 then
				in_rqu<='1';
				data_in<=data_buffer;
				state<=sync;
			elsif bluetooth_rqu='0' then
				state<=free;
			else
				state<=state;
			end if;
		
		-----------SYNC------------
		elsif state=sync then
			
			if in_end='1' then
				in_rqu<='0';
				state<=free;
			else
				state<=state;
			end if;
		
		----------RESET-----------
		elsif state=reset then
			con_recieve:=0;
			bluetooth_reset<='1';
			in_rqu<='0';
			state<=free;
		
		else
			
			state<=reset;
		
		end if;

	end if;
	
end process;


end bluetooth;
		
		













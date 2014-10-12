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

--数据传输结束确定后进入LOCK状态，usb_end置1

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity USB_RAM_BUFFER is
	port
		(
			inclk:in std_logic;
			
			usb_clk:out std_logic;
			usb_full,usb_empty:in std_logic;
			sloe:out std_logic:='0';
			slrd,pktend:out std_logic:='0';
			slwr:out std_logic:='0';
			fifoadr:out std_logic_vector(1 downto 0);
			usb_data:inout std_logic_vector(15 downto 0);
			pc_rqu:in std_logic;
			usb_in:in std_logic
		);
end entity;


architecture bufferx of usb_RAM_BUFFER is

component PLL is
port
	(
		inclk0:in std_logic;
		c0,c1,c2,c3:out std_logic;
		locked:out std_logic
	);
end component;


component FIFO_TO_OTHER is
	PORT
	(
		aclr		: IN STD_LOGIC  := '0';
		data		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
		rdclk		: IN STD_LOGIC ;
		rdreq		: IN STD_LOGIC ;
		wrclk		: IN STD_LOGIC ;
		wrreq		: IN STD_LOGIC ;
		q		: OUT STD_LOGIC_VECTOR (15 DOWNTO 0);
		rdusedw		: OUT STD_LOGIC_VECTOR (8 DOWNTO 0);
		wrusedw		: OUT STD_LOGIC_VECTOR (9 DOWNTO 0)
	);
end component;

component COUNTER_TIMEOUT IS
	PORT
	(
		aclr		: IN STD_LOGIC ;
		clk_en		: IN STD_LOGIC ;
		clock		: IN STD_LOGIC ;
		q		: OUT STD_LOGIC_VECTOR (11 DOWNTO 0)
	);
end component;


----------------Clock------------------
signal clk_usb_p,clk_usb_n,clk_usb_90,clk_usb_270,clk_usb_lock:std_logic;

----------------fifo例化----------------
signal data_to_ram:std_logic_vector(15 downto 0);
signal fifo_utr_write,fifo_utr_read:std_logic:='0';
signal fifo_utr_aclr:std_logic:='0';

signal data_from_usb:std_logic_vector(7 downto 0);
signal data_to_usb:std_logic_vector(15 downto 0);

--------------fifo已写/可读数据-----------
signal fifo_utr_num_w:std_logic_vector(9 downto 0);
signal fifo_utr_num_r:std_logic_vector(8 downto 0);
signal fifo_utr_num_w_buffer:std_logic_vector(9 downto 0);
signal fifo_utr_num_r_buffer:std_logic_vector(8 downto 0);

----------------pc cmd------------------
signal command:std_logic_vector(15 downto 0);

------------------usb-------------------
signal usb_in_rqu,usb_out_rqu:std_logic:='0';
signal usb_in_rqu_last:std_logic:='0';

signal usb_in_ready,usb_out_ready:std_logic:='0';
signal usb_in_ready_last,usb_out_ready_last:std_logic:='0';

signal usb_in_allow:std_logic:='0';
signal usb_out_allow:std_logic:='0';

signal usb_check:std_logic_vector(15 downto 0);

------------------timeout----------------
signal timeout_aclr:std_logic:='1';
signal timeout_clken:std_logic:='0';
signal timeout_q:std_logic_vector(11 downto 0);
signal timeout_buffer:std_logic_vector(11 downto 0);

-----------------flags-------------------
type ustates is (free,full,ack,rd,reset,lock);

signal usb_state,usb_state_buffer:ustates:=free;



begin

usb_clk<=clk_usb_270;

PLL_1:PLL
	port map
		(
			inclk0=>inclk,
			c0=>clk_usb_p,c1=>clk_usb_90,c2=>clk_usb_n,c3=>clk_usb_270,
			locked=>clk_usb_lock
		);
	


buffer_usb:FIFO_TO_OTHER 
	port map
		(
			aclr=>fifo_utr_aclr,
			data=>data_from_usb,q(7 downto 0)=>data_to_ram(15 downto 8),q(15 downto 8)=>data_to_ram(7 downto 0),
			wrclk=>clk_usb_270,rdclk=>clk_usb_270,
			wrreq=>fifo_utr_write,rdreq=>fifo_utr_read,
			wrusedw=>fifo_utr_num_w,rdusedw=>fifo_utr_num_r
		);

timeout:COUNTER_TIMEOUT
	port map
		(
			aclr=>timeout_aclr,
			clk_en=>timeout_clken,
			clock=>clk_usb_n,
			q=>timeout_q
		);

--------------USB------------
usb_control:process(clk_usb_p,clk_usb_lock)

variable con_full:integer range 0 to 7:=0;
variable con_ack:integer range 0 to 7:=0;

begin

	if clk_usb_p'event and clk_usb_p='1' and clk_usb_lock='1' then
		
		case usb_state is
		
	-----------IDLE------------
			when free =>
				usb_data<="ZZZZZZZZZZZZZZZZ";
				if usb_full='1' then
					usb_state<=full;
				else
					usb_state<=free;
				end if;
			
		-----------FULL------------			
			when full =>
				
				case con_full is
				
					when 0 =>
						fifo_utr_aclr<='0';
						fifo_utr_write<='0';
						sloe<='0';
						slrd<='0';
						fifoadr<="00";
						con_full:=con_full+1;
						
					when 1 =>
						sloe<='1';
						con_full:=con_full+1;
					
					when 2 =>
						con_full:=con_full+1;
						
					when 3 =>
						slrd<='1';
						fifo_utr_write<='1';
						con_full:=con_full+1;
						
					when others =>
						
						case fifo_utr_num_w_buffer is
							
							when "0111111101" =>
								usb_check(7 downto 0)<=usb_data(7 downto 0);
								
							when "0111111110" =>
								usb_check(15 downto 8)<=usb_data(7 downto 0);
								sloe<='0';
								slrd<='0';  
								fifo_utr_write<='0';
								
							when "1000000000" =>
								usb_state<=ack;
								con_full:=0;
							
							when others =>
								fifo_utr_write<=fifo_utr_write;
						end case;
						
				end case;
		
		-------------RD-------------
--			when rd =>
--				
--				if fifo_utr_num_r="100000000" then
--					fifo_utr_read<='1';
--				elsif fifo_utr_num_r="000000000" then
--					fifo_utr_read<='0';
--					usb_state<=ack;
--				end if;

		-------------ACK------------
			when ack =>	
				
				case con_ack is
				
					when 0 =>
						fifoadr<="10";
						slwr<='0';
						pktend<='0';
						con_ack:=con_ack+1;
					when 2 =>
						slwr<='1';
						usb_data(7 downto 0)<=usb_check(7 downto 0);
						con_ack:=con_ack+1;
					when 3=>
						usb_data(7 downto 0)<=usb_check(15 downto 8);
						con_ack:=con_ack+1;
					when 4 =>
						slwr<='0';
						pktend<='1';
						con_ack:=con_ack+1;
					when 5 =>
						pktend<='0';
						fifo_utr_aclr<='1';
						usb_state<=free;
						con_ack:=0;
					when others =>
						con_ack:=con_ack+1;
						
				end case;
			
		-----------RESET-----------
			when reset =>	
				con_full:=0;
				con_ack:=0;
				slwr<='0';
				fifo_utr_aclr<='1';
				usb_state<=free;
			
		-----------LOCK------------
			when lock =>
				fifo_utr_aclr<='1';
			
		-----------ERROR-----------	
			when others =>
				usb_state<=reset;
		
		end case;
		
		fifo_utr_num_w_buffer<=fifo_utr_num_w;
	
	end if;
	
end process;
data_from_usb<=usb_data(7 downto 0);
--data_from_usb(15 downto 8)<=usb_data_in(7 downto 0);

end bufferx;	
			
		
		
		
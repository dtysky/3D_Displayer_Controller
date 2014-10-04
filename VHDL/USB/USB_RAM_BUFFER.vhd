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
			clk_usb_lock,clk_ram_lock:in std_logic;
			
			clk_usb_p,clk_usb_n,clk_usb_90,clk_usb_270:in std_logic;
			clk_ram_p,clk_ram_n,clk_ram_90,clk_ram_270:in std_logic;
			usb_clk:out std_logic;
			usb_full,usb_empty:in std_logic;
			sloe:out std_logic:='0';
			slrd,pktend:out std_logic:='0';
			slwr:out std_logic:='0';
			fifoadr:out std_logic_vector(1 downto 0);
			usb_data_in:in std_logic_vector(15 downto 0);
			usb_data_out:out std_logic_vector(15 downto 0);
			usb_data_en:out std_logic:='0';
			pc_rqu:in std_logic;
			usb_in:in std_logic;
			
			w_rqu,r_rqu:out std_logic;
			w_ready,r_ready:in std_logic;
			w_end,r_end:in std_logic;
			ram_dm:out std_logic_vector(3 downto 0):="0011";
			w_num,r_num:out std_logic_vector(15 downto 0);
			ram_bank:out std_logic_vector(2 downto 0);
			ram_addr_row:out std_logic_vector(12 downto 0);
			ram_addr_col:out std_logic_vector(9 downto 0);
			ram_data_in:in std_logic_vector(15 downto 0);
			ram_data_out:out std_logic_vector(15 downto 0);
			
			ram_reset:out std_logic:='0';
			usb_end:out std_logic:='0'
		);
end entity;


architecture bufferx of usb_RAM_BUFFER is

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

component FIFO_TO_USB is
	PORT
	(
		aclr		: IN STD_LOGIC  := '0';
		data		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
		rdclk		: IN STD_LOGIC ;
		rdreq		: IN STD_LOGIC ;
		wrclk		: IN STD_LOGIC ;
		wrreq		: IN STD_LOGIC ;
		q		: OUT STD_LOGIC_VECTOR (15 DOWNTO 0);
		rdusedw		: OUT STD_LOGIC_VECTOR (10 DOWNTO 0);
		wrusedw		: OUT STD_LOGIC_VECTOR (10 DOWNTO 0)
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

----------------fifo例化----------------
signal data_from_ram,data_to_ram:std_logic_vector(15 downto 0);
signal fifo_utr_write,fifo_utr_read:std_logic:='0';
signal fifo_utr_aclr:std_logic:='0';

signal data_from_usb:std_logic_vector(7 downto 0);
signal data_to_usb:std_logic_vector(15 downto 0);
signal clk_from_ram,clk_to_usb:std_logic:='0';
signal fifo_rtu_write,fifo_rtu_read:std_logic:='0';
signal fifo_rtu_aclr:std_logic:='0';

--------------fifo已写/可读数据-----------
signal fifo_utr_num_w:std_logic_vector(9 downto 0);
signal fifo_utr_num_r:std_logic_vector(8 downto 0);
signal fifo_utr_num_w_buffer:std_logic_vector(9 downto 0);
signal fifo_utr_num_r_buffer:std_logic_vector(8 downto 0);

signal fifo_rtu_num_w:std_logic_vector(10 downto 0);
signal fifo_rtu_num_w_buffer:std_logic_vector(10 downto 0);
signal fifo_rtu_num_r:std_logic_vector(10 downto 0);
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

-------------------ram-------------------
signal w_num_s:std_logic_vector(15 downto 0):=x"0000";
signal ram_bank_s:std_logic_vector(2 downto 0):="000";
signal ram_addr_row_s:std_logic_vector(12 downto 0):="0000000000000";
signal ram_addr_col_s:std_logic_vector(9 downto 0):="0000000000";

signal r_num_s:std_logic_vector(15 downto 0):=x"0000";
signal trans_no:std_logic_vector(31 downto 0):=x"00000000";
signal r_ready_s:std_logic;

------------------timeout----------------
signal timeout_aclr:std_logic:='1';
signal timeout_clken:std_logic:='0';
signal timeout_q:std_logic_vector(11 downto 0);
signal timeout_buffer:std_logic_vector(11 downto 0);

-----------------flags-------------------
type ustates is (free,trans,collect,full,judge,ack,reset,lock);
type rstates is (free,trans,collect,judge,ack,reset,lock);

signal usb_state,usb_state_buffer:ustates:=free;
signal ram_state:rstates:=free;



begin

usb_clk<=clk_usb_n;

buffer_usb:FIFO_TO_OTHER 
	port map
		(
			aclr=>fifo_utr_aclr,
			data=>data_from_usb,q(7 downto 0)=>data_to_ram(15 downto 8),q(15 downto 8)=>data_to_ram(7 downto 0),
			wrclk=>clk_usb_270,rdclk=>clk_ram_p,
			wrreq=>fifo_utr_write,rdreq=>fifo_utr_read,
			wrusedw=>fifo_utr_num_w,rdusedw=>fifo_utr_num_r
		);

buffer_ram:FIFO_TO_USB 
	port map
		(
			aclr=>fifo_rtu_aclr,
			data=>data_from_ram,q=>data_to_usb,
			wrclk=>clk_ram_270,rdclk=>clk_usb_90,
			wrreq=>fifo_rtu_write,rdreq=>fifo_rtu_read,
			wrusedw=>fifo_rtu_num_w,rdusedw=>fifo_rtu_num_r
		);
		
timeout:COUNTER_TIMEOUT
	port map
		(
			aclr=>timeout_aclr,
			clk_en=>timeout_clken,
			clock=>clk_ram_n,
			q=>timeout_q
		);

--------------USB------------
usb_control:process(clk_usb_p,clk_usb_lock)

variable con_full:integer range 0 to 7:=0;
variable con_collect:integer range 0 to 3:=0;
variable con_ack:integer range 0 to 7:=0;

begin

	if clk_usb_p'event and clk_usb_p='1' and clk_usb_lock='1' then
		
		case usb_state is
		
	-----------IDLE------------
			when free =>
				fifo_rtu_aclr<='0';
				pktend<='0';
				
				if usb_full='1' then
					usb_state<=full;
				else
					usb_state<=free;
				end if;
			
		-----------FULL------------			
			when full =>
				
				case con_full is
				
					when 0 =>
						usb_data_en<='0';
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
								usb_check(7 downto 0)<=usb_data_in(7 downto 0);
								
							when "0111111110" =>
								usb_check(15 downto 8)<=usb_data_in(7 downto 0);
								sloe<='0';
								slrd<='0';  
								fifo_utr_write<='0';
								
							when "1000000000" =>
								usb_state<=judge;
								con_full:=0;
							
							when others =>
								fifo_utr_write<=fifo_utr_write;
						end case;
						
				end case;
					
		-------------JUDGE------------
			when judge =>	
			
				case ram_state is
					
					when collect =>
						
						if fifo_rtu_num_w_buffer="10000000000" then
							usb_state<=collect;
						else
							usb_state<=judge;
						end if;
					
					when trans =>
						usb_state<=trans;
					
					when judge =>
						usb_state<=judge;
					
					when others =>
						usb_state<=reset;
				
				end case;
		
		-----------TRANS------------
			when trans =>	
				
				case ram_state is
					
					when ack =>
						usb_state<=ack;
					
					when trans =>
						usb_state<=trans;
					
					when others =>
						usb_state<=reset;
				
				end case;

		-------------ACK------------
			when ack =>	
				
				case con_ack is
				
					when 0 =>
						usb_data_en<='1';
						fifoadr<="10";
						slwr<='0';
						pktend<='0';
						con_ack:=con_ack+1;
					when 2 =>
						slwr<='1';
						con_ack:=con_ack+1;
					when 3 =>
						slwr<='0';
						pktend<='1';
						con_ack:=con_ack+1;
					when 4 =>
						usb_data_en<='0';
						pktend<='0';
						usb_state<=free;
						con_ack:=0;
					when others =>
						con_ack:=con_ack+1;
						
				end case;

		-----------COLLECT----------
			when collect =>	

				if ram_state=reset or usb_full='1' then
					usb_state<=reset;
					
				else
					
					case con_collect is
						
						when 0 =>
							usb_data_en<='1';
							fifoadr<="10";
							con_collect:=con_collect+1;
						
						when 1 =>
							fifo_rtu_read<='1';
							con_collect:=con_collect+1;
							
						when 2 =>
							slwr<='1';
							con_collect:=con_collect+1;
							
						when others =>
						
							if usb_in='0' and fifo_rtu_num_r(7 downto 0)=x"01" then
								usb_data_en<='0';
								fifo_rtu_read<='0';
							
							elsif usb_in='0' and fifo_rtu_num_r(7 downto 0)=x"00" then
								slwr<='0';
							
							elsif usb_in='1' and fifo_rtu_num_r(10)='0' then
							
								case fifo_rtu_num_r(9 downto 8) is
									
									when "00" =>
										usb_state<=free;
									when others =>
										usb_data_en<='1';
										fifo_rtu_read<='1';
										slwr<='1';
									
								end case;
							
							else
								fifo_rtu_read<=fifo_rtu_read;
							
							end if;
						
						
--							if fifo_rtu_num_r="0000000000" then
--								usb_data_en<='0';
--								fifo_rtu_read<='0';
--								slwr<='0';
--								usb_state<=free;
--								con_collect:=0;
--							else
--								fifo_rtu_read<='1';
--							end if;
				
					end case;
				
				end if;
			
		-----------RESET-----------
			when reset =>	
				con_full:=0;
				con_ack:=0;
				con_collect:=0;
				fifo_rtu_aclr<='1';
				usb_data_en<='0';
				fifo_rtu_read<='0';
				slwr<='0';
				usb_state<=free;
			
		-----------LOCK------------
			when lock =>
				fifo_rtu_aclr<='1';
			
		-----------ERROR-----------	
			when others =>
				usb_state<=reset;
		
		end case;
		
		fifo_utr_num_w_buffer<=fifo_utr_num_w;
	
	end if;
	
end process;
data_from_usb<=usb_data_in(7 downto 0);
--data_from_usb(15 downto 8)<=usb_data_in(7 downto 0);

with usb_state select
	usb_data_out<=usb_check when ack,
					  data_to_usb when collect,
					  x"0000" when others;
			

--------------RAM------------
ram_control:process(clk_ram_p,clk_ram_lock)

variable con_judge:integer range 0 to 7:=0;
variable con_collect:integer range 0 to 3:=0;
variable con_trans:integer range 0 to 3:=0; 

begin


	if clk_ram_p'event and clk_ram_p='1' and clk_ram_lock='1' then
	
		case ram_state is
	
	-------------IDLE-------------
			when free =>
				fifo_utr_aclr<='0';
				ram_reset<='0';
				
				if usb_state_buffer=judge then
					ram_state<=judge;
				else
					ram_state<=free;
				end if;
		
	-------------JUDGE------------
			when judge =>
				
				case con_judge is
				
					when 0 =>
						fifo_utr_read<='1';
						con_judge:=con_judge+1;
						
					when 1 =>
						con_judge:=con_judge+1;
						
					when 2 =>
						command<=data_to_ram;
						con_judge:=con_judge+1;
					
					when 3 =>
						w_num_s<=data_to_ram;
						r_num_s<=data_to_ram;
						con_judge:=con_judge+1;
					
					when 4 =>
						trans_no(15 downto 8)<=data_to_ram(7 downto 0);
						trans_no(7 downto 0)<=data_to_ram(15 downto 8);
						con_judge:=con_judge+1;
						
					when 5 =>
						fifo_utr_read<='0';
						trans_no(31 downto 24)<=data_to_ram(7 downto 0);
						trans_no(23 downto 16)<=data_to_ram(15 downto 8);
						con_judge:=con_judge+1;
						
					when 6 =>
						con_judge:=0;
							
						case command is
						
							when "1000011110000110" => --UTF8-采集-8786
								ram_state<=collect;
								fifo_utr_aclr<='1';
							when "1010000010000001" => --UTF8-传送-A081
								ram_state<=trans;
							when "1001010101011101" => --UTF8-锁定-955B
								ram_state<=lock;
							when others =>
								ram_state<=reset;
						
						end case;
					
					when others =>
						ram_state<=reset;
					
				end case;
				
	-----------TRANS------------
			when trans =>
				
				if timeout_buffer=2500 then
					ram_reset<='1';
					fifo_utr_read<='0';
					w_rqu<='0';
					ram_state<=reset;
				
				else
				
					case con_trans is
					
						when 0 =>
						
							case trans_no(1 downto 0) is
								when "00" =>
									ram_addr_col_s<="0000000000";
								when "01" =>
									ram_addr_col_s<="0011111011"; --251
								when "10" =>
									ram_addr_col_s<="0111110110"; --502
								when "11" =>
									ram_addr_col_s<="1011110001"; --753
								when others =>
								  null;
							end case;
					
							ram_addr_row_s<=trans_no(14 downto 2);
							ram_bank_s<=trans_no(17 downto 15);
					
							if trans_no(18)='1' then
								ram_dm<="0011";
							else
								ram_dm<="1100";
							end if;
							con_trans:=con_trans+1;
				
						when 1 =>
							timeout_clken<='1';
							timeout_aclr<='0';
							w_rqu<='1';
							w_num<=w_num_s;
							ram_bank<=ram_bank_s;
							ram_addr_col<=ram_addr_col_s;
							ram_addr_row<=ram_addr_row_s;
							con_trans:=con_trans+1;
				
						when others =>
					
							if w_ready='1' then
								fifo_utr_read<='1';
							elsif fifo_utr_num_r_buffer<"000100000" then
								timeout_clken<='0';
								timeout_aclr<='1';
								fifo_utr_read<='0';
								w_rqu<='0';
								fifo_utr_aclr<='1';
								ram_state<=ack;
								con_trans:=0;
							else
								ram_state<=trans;
							end if;
				
					end case;
				
				end if;
				
	-------------ACK------------
			when ack =>
				
				case usb_state_buffer is
					
					when free =>
						ram_state<=free;
					
					when ack =>
						ram_state<=ack;
					
					when trans =>
						ram_state<=ack;
					
					when others =>
						ram_state<=reset;
					
				end case;
				
	-----------COLLECT----------
			when collect =>
				
				if timeout_buffer=4090 then
					ram_reset<='1';
					fifo_rtu_write<='0';
					r_rqu<='0';
					ram_state<=reset;
				
				else
					
					case con_collect is
					
						when 0 =>

							ram_addr_col_s<="0000000000";
							
							ram_addr_row_s<=trans_no(12 downto 0);
							ram_bank_s<=trans_no(15 downto 13);
					
							if trans_no(16)='1' then
								ram_dm<="0011";
							else
								ram_dm<="1100";
							end if;
							con_trans:=con_trans+1;
							con_collect:=con_collect+1;
					
						when 1 =>
							timeout_clken<='1';
							timeout_aclr<='0';
							r_rqu<='1';
							r_num<=r_num_s;
							ram_bank<=ram_bank_s;
							ram_addr_col<=ram_addr_col_s;
							ram_addr_row<=ram_addr_row_s;
							con_collect:=con_collect+1;
					
						when others =>
							
							case r_ready_s is
								
								when '1' =>
									fifo_rtu_write<='1';
								
								when others =>
									
									--if fifo_rtu_num_w_buffer(9 downto 2)=r_num_s(7 downto 0) then
									
									if usb_state_buffer=collect then
											timeout_clken<='0';
											timeout_aclr<='1';
											ram_state<=free;
											con_collect:=0;
									else
										con_collect:=con_collect;
									end if;
									
							end case;
								
							if fifo_rtu_num_w_buffer="10000000000" then
								fifo_rtu_write<='0';
								r_rqu<='0';
							else
								r_rqu<='1';
							end if;
					
					end case;
					
				end if;
				
	-----------RESET------------
			when reset =>
				fifo_utr_aclr<='1';
				ram_reset<='1';
				con_judge:=0;
				con_trans:=0;
				con_collect:=0;
				
				if usb_state_buffer=free then
					ram_state<=free;
				else
					null;
				end if;
			
	------------LOCK------------
			when lock =>
				fifo_utr_aclr<='1';
				usb_end<='1';
	
	------------ERROR-----------
			when others =>
				ram_state<=reset;
			
		end case;
		
		fifo_utr_num_r_buffer<=fifo_utr_num_r;
		fifo_rtu_num_w_buffer<=fifo_rtu_num_w;
		timeout_buffer<=timeout_q;
		usb_state_buffer<=usb_state;
		r_ready_s<=r_ready;
		
	end if;
	
end process;
ram_data_out<=data_to_ram;

data_from_ram<=ram_data_in;


			
end bufferx;	
			
		
		
		
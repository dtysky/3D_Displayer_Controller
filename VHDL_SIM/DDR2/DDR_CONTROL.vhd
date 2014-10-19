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


----The wr_num or rd_num must be less than x"0100"----  
----It means Only 1 line would be read/write per operation----  

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_misc.all;
use ieee.std_logic_unsigned.all;

entity DDR2_CONTROL is

generic
	(
		----------------------timing-------------------
		constant tRPA:integer:=4;	--PRC ALL Period
		constant tMRD:integer:=2;	--LM Cycle
		constant tRFC:integer:=25;	--RF to BA/RF
		constant tRP:integer:=3;	--PRC ONE Period
		constant tWR:integer:=3;	--Write Recovery
		constant tRCD:integer:=3;	--BA TO WR/RD
		constant tXSRD:integer:=200;	--EXT SRF TO OTHER
		
		constant AL:integer:=2;
		constant CL:integer:=3;
		constant BL:integer:=4;
		constant BLC:integer:=2;	---BL/2
		constant WL:integer:=4;		----AL+CL-1
		constant RL:integer:=5;		----AL+CL
		
		constant SETUP:integer:=35000;
		
		
		-----------------------CMD---------------------
		constant CMD_INIT:std_logic_vector(4 downto 0):="01000";
		constant CMD_LM:std_logic_vector(4 downto 0):="10000";
		constant CMD_RF:std_logic_vector(4 downto 0):="10001";
		constant CMD_SRF_IN:std_logic_vector(4 downto 0):="00001";
		constant CMD_SRF_OUT:std_logic_vector(4 downto 0):="10111";
		constant CMD_PRC:std_logic_vector(4 downto 0):="10010";
		constant CMD_BA:std_logic_vector(4 downto 0):="10011";
		constant CMD_WR:std_logic_vector(4 downto 0):="10100";
		constant CMD_RD:std_logic_vector(4 downto 0):="10101";
		constant CMD_NOP:std_logic_vector(4 downto 0):="10111";
		
		----------PD FAST,WR=2,CL=3,BT SE,BL=4------------
		----------------MR with DLL RESET-----------------
		constant MR1:std_logic_vector(12 downto 0):="0010100110010";
		---------------MR without DLL RESET---------------
		constant MR2:std_logic_vector(12 downto 0):="0010000110010";
		
		--RDQS/DQS# OFF,OCD/DLL ON,ODS FULL,RTT=50,AL=2---
		---------------EMR with OCD default---------------
		constant EMR_0:std_logic_vector(12 downto 0):="0011111010100";
		-----------------EMR with OCD exit----------------
		constant EMR_1:std_logic_vector(12 downto 0):="0010001010100";
		---------------------default----------------------
		constant EMR2:std_logic_vector(12 downto 0):="0000000000000";
		constant EMR3:std_logic_vector(12 downto 0):="0000000000000"
	);

port
	(
		pll_lock:in std_logic;
		
		clk_control_p,clk_out_p,clk_out_n:in std_logic;
		clk_data:in std_logic;
		clk,n_clk:out std_logic;
		cke,n_cs,n_ras,n_cas,n_we:out std_logic:='1';
		udm,ldm:out std_logic:='0';
		
		udqs_in,ldqs_in:in std_logic:='1';
		udqs_out,ldqs_out:out std_logic:='1';
		dqs_en:out std_logic:='0';
		
		odt:out std_logic:='0';
		bank:out std_logic_vector(2 downto 0):="000";
		addr:out std_logic_vector(12 downto 0):="0000000000000";
		
		ram_data_in:in std_logic_vector(15 downto 0):=x"0000";
		ram_data_out:out std_logic_vector(15 downto 0):=x"0000";
		ram_data_en:out std_logic:='0';
		
		ram_reset:in std_logic:='0';
		
		wr_rqu,rd_rqu:in std_logic:='0';
		wr_ready,rd_ready:out std_logic:='0';
		wr_end,rd_end:out std_logic:='0';
		udm_in,ldm_in:in std_logic:='0';
		write_num:in std_logic_vector(15 downto 0);
		read_num:in std_logic_vector(15 downto 0);
		data_other_in:in std_logic_vector(15 downto 0);
		data_other_out:out std_logic_vector(15 downto 0);
		bank_other:in std_logic_vector(2 downto 0);
		addr_other_row:in std_logic_vector(12 downto 0);
		addr_other_col:in std_logic_vector(9 downto 0)
	);
	
end entity;

architecture ddr2_con of DDR2_CONTROL is

---------------------clock-----------------------
signal clk_self,clk_out:std_logic;

----------cke,n_cs,n_ras,n_cas,n_we--------------
signal cmd:std_logic_vector(4 downto 0):=CMD_INIT;

--------------------flags------------------------
type states is (start,wr,rd,prc,srf,arf,reset);

--attribute states_encoding:string;
--attribute states_encoding of states:type is "000 001 010 011 100 101 110";

signal state:states:=start;

-------------------addr buffer-------------------
signal addr_row:std_logic_vector(12 downto 0):="1111111111111";
signal addr_other_row_s:std_logic_vector(12 downto 0);
signal addr_col:std_logic_vector(9 downto 0);
signal bank_s:std_logic_vector(2 downto 0);

--------------------others-----------------------
signal wr_start,rd_start:std_logic:='0';
signal wr_ready_s,rd_ready_s:std_logic:='0';
signal rd_ready_s_1,rd_ready_s_2:std_logic:='0';
signal wr_rqu_s,rd_rqu_s:std_logic;
signal udqs_last,udqs_last_last:std_logic:='0';
signal write_num_s,read_num_s:std_logic_vector(15 downto 0);
signal dqs_en_s:std_logic:='0';

begin
	
	clk<=clk_out_p;
	n_clk<=clk_out_n;
	
	cke<=cmd(4);
	n_cs<=cmd(3);
	n_ras<=cmd(2);
	n_cas<=cmd(1);
	n_we<=cmd(0);
	
	rd_ready_s<=rd_ready_s_1 or rd_ready_s_2;
	
	wr_ready<=wr_ready_s;
	rd_ready<=rd_ready_s;
	
	
CONTROL:process(clk_control_p,pll_lock)

variable con_init:integer range 0 to 65535:=0;
variable con_srf:integer range 0 to 255:=0;
variable con_arf:integer range 0 to 31:=0;
variable con_prc:integer range 0 to 7:=0;
variable con_write:integer range 0 to 15:=0;
variable con_write_trans:integer range 0 to 3:=0;
variable con_write_total:integer range 0 to 65536;
variable con_read:integer range 0 to 63:=0;
variable con_read_trans:integer range 0 to 3:=0;
variable con_read_total:integer range 0 to 65536:=0;
variable con_reset:integer range 0 to 31:=0;

begin
	
	if clk_control_p'event and clk_control_p='1' and pll_lock='1' then

		if ram_reset='1' then
			state<=reset;
		
		else
			
			case state is
---------------------INIT---------------------
				when start=>
					con_init:=con_init+1;
						
					case con_init is
						
						when 10 =>
							odt<='0';
						
						when SETUP=> 
							cmd<=CMD_NOP; 
						
						when SETUP+100=> 
							cmd<=CMD_PRC;
							addr(10)<='1';
						
						when SETUP+100+1=>
							cmd<=CMD_NOP;
						
						when SETUP+100+tRPA+1=>
							cmd<=CMD_LM;
							bank<="010";
							addr<=EMR2;
						
						when SETUP+100+tRPA+2=>
							cmd<=CMD_NOP;
							
						when SETUP+100+tRPA+tMRD+2=>
							cmd<=CMD_LM;
							bank<="011";
							addr<=EMR3;
							
						when SETUP+100+tRPA+tMRD+3=>
							cmd<=CMD_NOP;
							
						when SETUP+100+tRPA+tMRD+tMRD+3=>
							cmd<=CMD_LM;
							bank<="001";
							addr<=EMR_0;
						
						when SETUP+100+tRPA+tMRD+tMRD+4=>
							cmd<=CMD_NOP;
							
						when SETUP+100+tRPA+tMRD+tMRD+tMRD+4=>
							cmd<=CMD_LM;
							bank<="000";
							addr<=MR1;
						
						when SETUP+100+tRPA+tMRD+tMRD+tMRD+5=>
							cmd<=CMD_NOP;
						
						when SETUP+100+tRPA+tMRD+tMRD+tMRD+tMRD+5=>
							cmd<=CMD_PRC;
							addr(10)<='1';
						
						when SETUP+100+tRPA+tMRD+tMRD+tMRD+tMRD+6=>
							cmd<=CMD_NOP;
					
						when SETUP+100+tRPA+tMRD+tMRD+tMRD+tMRD+tRPA+6=>
							cmd<=CMD_RF;
						
						when SETUP+100+tRPA+tMRD+tMRD+tMRD+tMRD+tRPA+7=>
							cmd<=CMD_NOP;
							
						when SETUP+100+tRPA+tMRD+tMRD+tMRD+tMRD+tRPA+tRFC+7=>
							cmd<=CMD_RF;
							
						when SETUP+100+tRPA+tMRD+tMRD+tMRD+tMRD+tRPA+tRFC+8=>
							cmd<=CMD_NOP;
						
						when SETUP+100+tRPA+tMRD+tMRD+tMRD+tMRD+tRPA+tRFC+tRFC+8=>
							cmd<=CMD_LM;
							bank<="000";
							addr<=MR2;
						
						when SETUP+100+tRPA+tMRD+tMRD+tMRD+tMRD+tRPA+tRFC+tRFC+9=>
							cmd<=CMD_NOP;
						
						when SETUP+100+tRPA+tMRD+tMRD+tMRD+tMRD+tRPA+tRFC+tRFC+tMRD+9=>
							cmd<=CMD_LM;
							bank<="001";
							addr<=EMR_0;
					
						when SETUP+100+tRPA+tMRD+tMRD+tMRD+tMRD+tRPA+tRFC+tRFC+tMRD+10=>
							cmd<=CMD_NOP;
						
						when SETUP+100+tRPA+tMRD+tMRD+tMRD+tMRD+tRPA+tRFC+tRFC+tMRD+tMRD+10=>
							cmd<=CMD_LM;
							bank<="001";
							addr<=EMR_1;
							
						when SETUP+100+tRPA+tMRD+tMRD+tMRD+tMRD+tRPA+tRFC+tRFC+tMRD+tMRD+11=>
							cmd<=CMD_NOP;
						
						when SETUP+1000=>
							state<=srf;
							con_init:=0;
							
						when others=>
							con_init:=con_init;
							
					end case;
				
		------------------AUTO REFRESH----------------
				when arf=>
					
					if dqs_en_s='0' then
						wr_end<='0';
						rd_end<='0';
					
						case con_arf is
						
							when 0 =>
								con_arf:=con_arf+1;
								cmd<=CMD_RF;
							when 1=>
								cmd<=CMD_NOP;
								con_arf:=con_arf+1;
							when 1+tRFC=>
								con_arf:=0;
								if wr_rqu_s='1' then
									udm<=udm_in;
									ldm<=ldm_in;
									bank_s<=bank_other;
									addr_row<=addr_other_row;
									addr_col<=addr_other_col;
									write_num_s<=write_num;
									state<=wr;
								elsif rd_rqu_s='1' then
									udm<=udm_in;
									ldm<=ldm_in;
									bank_s<=bank_other;
									addr_row<=addr_other_row;
									addr_col<=addr_other_col;
									read_num_s<=read_num;
									state<=rd;
								else
									state<=arf;
								end if;
								
							when others=>
								con_arf:=con_arf+1;
						end case;
					
					elsif wr_ready_s='1' then
						
						case con_write is
							when WL =>---WL?未定
								wr_end<='1';
								wr_ready_s<='0';
								dqs_en_s<='0';
								dqs_en<='0';
								ram_data_en<='0';
								con_write:=0;
							when others=>
								con_write:=con_write+1;
						end case;
						
					elsif rd_ready_s='1' then
						
						case con_read is
							when RL =>---RL?未定
								rd_end<='1';
								rd_ready_s_1<='0';
								dqs_en_s<='0';
								dqs_en<='0';
								ram_data_en<='0';
								con_read:=0;
							when others=>
								con_read:=con_read+1;
						end case;
					
					else
						state<=reset;
					
					end if;

		------------------SELF REFRESH----------------
				when srf=>
					
					case con_srf is
						
						when 0 =>
							cmd<=CMD_SRF_IN;
							con_srf:=con_srf+1;
						
						when 1 =>
						
							if wr_rqu_s='1' then
								cmd<=CMD_SRF_OUT;
								con_srf:=con_srf+1;
							elsif rd_rqu_s='1' then
								cmd<=CMD_SRF_OUT;
								con_srf:=con_srf+1;
							else
								con_srf:=con_srf;
							end if; 
						
						when 1+tXSRD =>
								
							if wr_rqu_s='1' or rd_rqu_s='1' then
								udm<=udm_in;
								ldm<=ldm_in;
								wr_end<='0';
								rd_end<='0';
								bank_s<=bank_other;
								addr_row<=addr_other_row;
								addr_col<=addr_other_col;
								write_num_s<=write_num;
								state<=prc;
								con_srf:=0;
							else
								state<=reset;
							end if;
						
						when others =>
							con_srf:=con_srf+1;
						
					end case;
				
		-------------------PRECHARGE------------------
				when prc=>
					
					case con_prc is
					
						when 0 =>
							bank<=bank_s;
							addr<=addr_row;
							con_prc:=con_prc+1;
						when 1 =>
							cmd<=CMD_PRC;
							con_prc:=con_prc+1;
						when 2 =>
							cmd<=CMD_NOP;
							con_prc:=con_prc+1;
						when 1+tRP =>
							con_prc:=0;
							state<=arf;
						when others=>
							con_prc:=con_prc+1;
					
					end case;

		---------------------WRITE--------------------
				when wr=>
					
					if dqs_en_s='0' then
						
						case con_write is
						
							when 1 =>
								cmd<=CMD_BA;
								ram_data_en<='1';
								bank<=bank_s;
								addr<=addr_row;
								con_write_total:=1;
								con_write:=con_write+1;
							when 2 =>
								cmd<=CMD_NOP;
								con_write:=con_write+1;
							when 2+tRCD =>
								cmd<=CMD_WR;
								addr(9 downto 0)<=addr_col;
								addr(12 downto 10)<="000";
								con_write:=con_write+1;
							when 3+tRCD =>
								cmd<=CMD_NOP;
								wr_start<='1';
								addr_col<=addr_col+BL;
								con_write:=con_write+1;
							when 3+tRCD+WL-2 =>
								dqs_en<='1';
								--wr_ready_s<='1';
								con_write:=con_write+1;
							when 3+tRCD+WL-1 =>
								dqs_en_s<='1';
								wr_ready_s<='1';
								con_write:=0;
							when others =>
								con_write:=con_write+1;
							
						end case;
					
					else
						state<=state;
						
					end if;
					
					if wr_start='1' then
						
						case con_write_trans is
						
							when BLC-1 =>
								cmd<=CMD_NOP;
								addr_col<=addr_col+BL;
								con_write_trans:=0;
								con_write_total:=con_write_total+1;
								
								if con_write_total=conv_integer(write_num_s) then
--									dqs_en_s<='0';
--									ram_data_en<='0';
									wr_start<='0';
									state<=prc;
								else
									wr_start<=wr_start;
								end if;
							
							when 0 =>
								cmd<=CMD_WR;
								addr(9 downto 0)<=addr_col;
								addr(12 downto 10)<="000";
								con_write_trans:=con_write_trans+1;
							
							when others =>
								con_write_trans:=con_write_trans+1;
						
						end case;
					
					else
						state<=state;
					
					end if;

		---------------------READ---------------------
				when rd=>
					
					if rd_ready_s_2='1' then
						rd_ready_s_1<='1';
					else
						rd_ready_s_1<=rd_ready_s_1;
					end if;
					
					if dqs_en_s='0' then
					
						case con_read is
						
							when 1 =>
								cmd<=CMD_BA;
								ram_data_en<='0';
								bank<=bank_s;
								addr<=addr_row;
								con_read:=con_read+1;
							when 2 =>
								cmd<=CMD_NOP;
								con_read:=con_read+1;
							when 2+tRCD =>
								cmd<=CMD_RD;
								addr(9 downto 0)<=addr_col;
								addr(12 downto 10)<="000";
								con_read:=con_read+1;
							when 3+tRCD =>
								cmd<=CMD_NOP;
								rd_start<='1';
								addr_col<=addr_col+BL;
								con_read:=con_read+1;
							when 3+tRCD+RL-2 =>
								con_read:=con_read+1;
							when 3+tRCD+RL-1 =>
								dqs_en_s<='1';
								con_read:=0;
							when others =>
								con_read:=con_read+1;
						
						end case;
						
					else
						state<=state;

					end if;
					
					if rd_start='1' then
						
						case con_read_trans is
						
							when BLC-1 =>
								addr_col<=addr_col+BL;
								cmd<=CMD_NOP;
								
								if con_read_total=conv_integer(read_num_s) then
									rd_start<='0';
									con_read_total:=0;
									state<=prc;
								else
									rd_start<=rd_start;
								end if;
								con_read_trans:=0;
								
							when 0 =>
								cmd<=CMD_RD;
								addr(9 downto 0)<=addr_col;
								addr(12 downto 10)<="000";
								con_read_total:=con_read_total+1;
								con_read_trans:=con_read_trans+1;
								
							--when 1 =>
								--cmd<=CMD_NOP;
								--con_read_total:=con_read_total+1;
								
							when others =>
								state<=reset;
							
						end case;
						
					else
						state<=state;

					end if;
			
		---------------------RESET--------------------			
				when reset=>
					con_arf:=0;
					con_prc:=0;
					con_read:=0;
					con_read_total:=0;
					con_read_trans:=0;
					con_srf:=0;
					con_write:=0;
					con_write_total:=0;
					con_write_trans:=0;
					wr_ready_s<='0';
					rd_ready_s_1<='0';
					rd_start<='0';
					dqs_en_s<='0';
					dqs_en<='0';
					ram_data_en<='0';
					cmd<=CMD_NOP;
					
					case con_reset is
						
						when 20 =>
							state<=prc;
							con_reset:=0;
						when others =>
							con_reset:=con_reset+1;
				
					end case;

		--------------------OTHERS--------------------						
				when others=>
					state<=reset;
				
			end case;
		
		wr_rqu_s<=wr_rqu;
		rd_rqu_s<=rd_rqu;
		
		end if;

	end if;

end process;	

--------------------dqs/dq-write---------------------
with dqs_en_s select
	udqs_out<=
		clk_control_p when '1',
		'0' when others;
		
with dqs_en_s select
	ldqs_out<=
		clk_control_p when '1',
		'0' when others;
	
ram_data_out<=data_other_in;

 
--------------------dqs/dq-read----------------------
data_other_out<=ram_data_in;


DQS_FLAG:process(clk_data,pll_lock)

begin

	if clk_data'event and clk_data='1' and pll_lock='1' then
		
		if state=rd then
			
			if udqs_last='0' and udqs_last_last/='0' then
				rd_ready_s_2<='1';
			else
				rd_ready_s_2<=rd_ready_s_2;
			end if;
			
		elsif rd_ready_s_1='0' then
			rd_ready_s_2<='0';
		
		else
			rd_ready_s_2<=rd_ready_s_2;
			
		end if;
		
		udqs_last<=udqs_in;
		udqs_last_last<=udqs_last;
		
	end if;

end process;
	

end ddr2_con;
			
		
			
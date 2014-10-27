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


--RAM模块输入为USB模块和LED模块的或

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_misc.all;
use ieee.std_logic_unsigned.all;

----------------clk_ledm 待替换-----------

------------------命名规则-----------------
---- uwr: usb with ram
---- lwr: ram with led
---- lwb: bluetooth with led

entity TD_DISPLAYER is
port
	(
		clk_40m_p,clk_40m_p1:in std_logic;
		clk_160m_p,clk_160m_p1,clk_160m_n1:in std_logic;
		clk_320m_p,clk_320m_n,clk_stpii:in std_logic;
		pll1_lock,pll2_lock,pll3_lock:in std_logic:='0';
		 
		------------DDR2------------
		ddr2_clk,ddr2_n_clk:out std_logic;
		cke,n_cs,n_ras,n_cas,n_we:out std_logic:='0';
		udm,ldm:out std_logic:='0';
		udm_2,ldm_2:out std_logic:='0';
		udqs,ldqs:inout std_logic:='1';
		udqs_2,ldqs_2:inout std_logic:='1';
		odt:out std_logic:='1';
		ddr2_bank:out std_logic_vector(2 downto 0);
		ddr2_addr:out std_logic_vector(12 downto 0);
		ddr2_data:inout std_logic_vector(31 downto 0):=x"00000000";
		
		------------USB--------------
		usb_full,usb_empty:in std_logic;
		usb_clk:out std_logic;
		sloe,slrd,pktend:out std_logic:='0';
		slwr:out std_logic:='0';
		pc_rqu:in std_logic;
		usb_in:in std_logic;
		usb_fifoadr:out std_logic_vector(1 downto 0);
		usb_data:inout std_logic_vector(15 downto 0);
		
		-------------LED--------------
		sensor:in std_logic;
		data_buffer_a:out std_logic_vector(39 downto 0):=x"0000000000";
		data_buffer_b:out std_logic_vector(39 downto 0):=x"0000000000";
		data_buffer_c:out std_logic_vector(39 downto 0):=x"0000000000";
		en_row_a:out std_logic:='0';
		en_row_b:out std_logic:='0';
		en_row_c:out std_logic_vector(1 downto 0):="00";									--------分割为两个管脚，分配同一信号
		en_col_a_1,en_col_a_2,en_col_a_3:out std_logic:='0';
		en_col_b_1,en_col_b_2,en_col_b_3:out std_logic:='0';
		en_col_c_1,en_col_c_2,en_col_c_3:out std_logic:='0';
		
		-----------BLUETOOTH-----------
		bluetooth_rqu:in std_logic:='0';
		bluetooth_ack:out std_logic:='0';
		bluetooth_reset:out std_logic:='0';
		bluetooth_data:inout std_logic_vector(3 downto 0):=x"0";
		
		test:in std_logic
		
	);
end entity;


architecture displayer of TD_DISPLAYER is

component DDR2_CONTROL is
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
		
		odt:out std_logic:='1';
		bank:out std_logic_vector(2 downto 0);
		addr:out std_logic_vector(12 downto 0);
		
		ram_data_in:in std_logic_vector(15 downto 0):=x"0000";
		ram_data_out:out std_logic_vector(15 downto 0):=x"0000";
		ram_data_en:out std_logic:='0';
		
		ram_reset:in std_logic:='0';
		
		wr_rqu,rd_rqu:in std_logic:='0';
		wr_ready,rd_ready:out std_logic:='0';
		wr_end,rd_end:out std_logic:='1';
		udm_in,ldm_in:in std_logic:='0';
		write_num:in std_logic_vector(15 downto 0);
		read_num:in std_logic_vector(15 downto 0);
		data_other_in:in std_logic_vector(15 downto 0);
		data_other_out:out std_logic_vector(15 downto 0);
		bank_other:in std_logic_vector(2 downto 0);
		addr_other_row:in std_logic_vector(12 downto 0);
		addr_other_col:in std_logic_vector(9 downto 0)
	);
end component;

component USB_RAM_BUFFER is
	port
		(
			clk_usb_lock,clk_ram_lock:in std_logic;
			
			clk_usb_p,clk_usb_o_p:in std_logic;
			clk_ram_p:in std_logic;
			usb_clk:out std_logic;
			usb_full,usb_empty:in std_logic;
			sloe,slrd,pktend:out std_logic:='0';
			slwr:out std_logic:='0';
			fifoadr:out std_logic_vector(1 downto 0);
			pc_rqu:in std_logic;
			usb_in:in std_logic;
			usb_data_in:in std_logic_vector(15 downto 0);
			usb_data_out:out std_logic_vector(15 downto 0);
			usb_data_en:out std_logic:='0';
			
			ram_dm:out std_logic_vector(3 downto 0);
			w_rqu,r_rqu:out std_logic;
			w_ready,r_ready:in std_logic;
			w_end,r_end:in std_logic;
			w_num,r_num:out std_logic_vector(15 downto 0);
			ram_bank:out std_logic_vector(2 downto 0);
			ram_addr_row:out std_logic_vector(12 downto 0);
			ram_addr_col:out std_logic_vector(9 downto 0);
			ram_data_in:in std_logic_vector(15 downto 0);
			ram_data_out:out std_logic_vector(15 downto 0);
			
			ram_reset:out std_logic:='0';
			usb_end:out std_logic:='0'
		);
end component;

component LED is
	port
		(
			clk_control:in std_logic;
			clk_data_p:in std_logic;
			
			sensor:in std_logic;
			data_buffer_a:out std_logic_vector(39 downto 0):=x"0000000000";
			data_buffer_b:out std_logic_vector(39 downto 0):=x"0000000000";
			data_buffer_c:out std_logic_vector(39 downto 0):=x"0000000000";
			en_row_a:out std_logic:='0';
			en_row_b:out std_logic:='0';
			en_row_c:out std_logic_vector(1 downto 0):="00";									--------分割为两个管脚，分配同一信号
			en_col_a_1,en_col_a_2,en_col_a_3:out std_logic:='0';
			en_col_b_1,en_col_b_2,en_col_b_3:out std_logic:='0';
			en_col_c_1,en_col_c_2,en_col_c_3:out std_logic:='0';
			
			blue_rqu:in std_logic:='0';
			blue_end:out std_logic:='0';
			blue_data:in std_logic_vector(7 downto 0):=x"00";
			
			ram_data:in std_logic_vector(15 downto 0);
			r_rqu:out std_logic;
			r_ready:in std_logic;
			ram_reset:out std_logic;
			r_end:in std_logic;
			r_num:out std_logic_vector(7 downto 0);
			ram_dm:out std_logic_vector(3 downto 0);
			ram_bank:out std_logic_vector(2 downto 0);
			ram_addr_row:out std_logic_vector(12 downto 0);
			ram_addr_col:out std_logic_vector(9 downto 0)
		);
end component;

component BLUETOOTH_CONTROL is

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

end component;

------------------------ram----------------------------
signal data_from_ram_1,data_from_ram_2:std_logic_vector(15 downto 0);
signal dm_s:std_logic_vector(3 downto 0);
signal rd_rqu_s,rd_ready_s,rd_end_s:std_logic;
signal rd_num_s:std_logic_vector(15 downto 0);
signal ram_bank_s:std_logic_vector(2 downto 0);
signal ram_addr_row_s:std_logic_vector(12 downto 0);
signal ram_addr_col_s:std_logic_vector(9 downto 0);

signal ram_data_in,ram_data_out:std_logic_vector(31 downto 0);
signal ram_data_en:std_logic:='0';
signal udqs_in,ldqs_in:std_logic:='1';
signal udqs_out,ldqs_out:std_logic:='1';
signal dqs_en:std_logic:='0';
signal udqs_in_2,ldqs_in_2:std_logic:='1';
signal udqs_out_2,ldqs_out_2:std_logic:='1';
signal dqs_en_2:std_logic:='0';

------------------------usb----------------------------
signal usb_data_in,usb_data_out:std_logic_vector(15 downto 0);
signal usb_data_en:std_logic:='0';

---------------------usb with ram----------------------
signal uwr_wr_rqu,uwr_rd_rqu:std_logic;
signal uwr_wr_ready,uwr_rd_ready:std_logic;
signal uwr_wr_end,uwr_rd_end:std_logic;
signal uwr_dm:std_logic_vector(3 downto 0);
signal uwr_wr_num,uwr_rd_num:std_logic_vector(15 downto 0);
signal uwr_bank:std_logic_vector(2 downto 0);
signal uwr_addr_row:std_logic_vector(12 downto 0);
signal uwr_addr_col:std_logic_vector(9 downto 0);
signal uwr_data_toram,uwr_data_tousb:std_logic_vector(15 downto 0);

signal ram_reset_s1,ram_reset_s2,ram_reset_s:std_logic;
signal usb_end_s,usb_end_last:std_logic;

---------------------led with ram----------------------
signal lwr_rd_rqu:std_logic;
signal lwr_rd_ready:std_logic;
signal lwr_rd_end:std_logic;
signal lwr_dm:std_logic_vector(3 downto 0);
signal lwr_rd_num:std_logic_vector(7 downto 0);
signal lwr_bank:std_logic_vector(2 downto 0);
signal lwr_addr_row:std_logic_vector(12 downto 0);
signal lwr_addr_col:std_logic_vector(9 downto 0);
signal lwr_data_ram:std_logic_vector(15 downto 0);

-------------------led with bluetooth-------------------
signal lwb_in_rqu:std_logic;
signal lwb_in_end:std_logic;
signal lwb_in_data:std_logic_vector(7 downto 0);


begin

	DDR2_1:DDR2_CONTROL 
		port map
			(
				pll_lock=>pll2_lock,
				
				clk_control_p=>clk_160m_p,clk_out_p=>clk_160m_p1,clk_out_n=>clk_160m_n1,
				clk_data=>clk_320m_p,
				clk=>ddr2_clk,n_clk=>ddr2_n_clk,
				cke=>cke,n_cs=>n_cs,n_ras=>n_ras,n_cas=>n_cas,n_we=>n_we,
				udm=>udm,ldm=>ldm,
				
				udqs_in=>udqs_in,ldqs_in=>ldqs_in,
				udqs_out=>udqs_out,ldqs_out=>ldqs_out,
				dqs_en=>dqs_en,
				odt=>odt,
				bank=>ddr2_bank,addr=>ddr2_addr,
				
				ram_data_in=>ram_data_in(15 downto 0),
				ram_data_out=>ram_data_out(15 downto 0),
				ram_data_en=>ram_data_en,
				
				ram_reset=>ram_reset_s,
				
				wr_rqu=>uwr_wr_rqu,rd_rqu=>rd_rqu_s,
				wr_ready=>uwr_wr_ready,rd_ready=>rd_ready_s,
				wr_end=>uwr_wr_end,rd_end=>rd_end_s,
				udm_in=>dm_s(1),ldm_in=>dm_s(0),
				write_num=>uwr_wr_num,read_num=>rd_num_s,
				bank_other=>ram_bank_s,
				addr_other_row=>ram_addr_row_s,
				addr_other_col=>ram_addr_col_s,
				data_other_in=>uwr_data_toram,
				data_other_out=>data_from_ram_1
			);
		
	DDR2_2:DDR2_CONTROL
		port map
			(
				pll_lock=>pll2_lock,
			
				clk_control_p=>clk_160m_p,clk_out_p=>clk_160m_p1,clk_out_n=>clk_160m_n1,
				clk_data=>clk_320m_p,
--				clk=>ddr2_clk,n_clk=>ddr2_n_clk,
--				cke=>cke,n_cs=>n_cs,n_ras=>n_ras,n_cas=>n_cas,n_we=>n_we,
				udm=>udm_2,ldm=>ldm_2,
				
				udqs_in=>udqs_in_2,ldqs_in=>ldqs_in_2,
				udqs_out=>udqs_out_2,ldqs_out=>ldqs_out_2,
				dqs_en=>dqs_en_2,
				
--				odt=>odt,
--				bank=>ddr2_bank,addr=>ddr2_addr,
				
				ram_data_in=>ram_data_in(31 downto 16),
				ram_data_out=>ram_data_out(31 downto 16),
				
				ram_reset=>ram_reset_s,
				
				wr_rqu=>uwr_wr_rqu,rd_rqu=>rd_rqu_s,
--				wr_ready=>uwr_wr_ready,rd_ready=>uwr_rd_ready,
--				wr_end=>uwr_wr_end,rd_end=>uwr_rd_end,
				write_num=>uwr_wr_num,read_num=>rd_num_s,
				udm_in=>dm_s(3),ldm_in=>dm_s(2),
				bank_other=>ram_bank_s,
				addr_other_row=>ram_addr_row_s,
				addr_other_col=>ram_addr_col_s,
				data_other_in=>uwr_data_toram,
				data_other_out=>data_from_ram_2
			);
		
	USB:USB_RAM_BUFFER
		port map
			(
				clk_usb_lock=>pll1_lock,clk_ram_lock=>pll2_lock,
			
				clk_usb_p=>clk_40m_p,clk_usb_o_p=>clk_40m_p1,
				clk_ram_p=>clk_320m_p,
				usb_clk=>usb_clk,
				usb_full=>usb_full,usb_empty=>usb_empty,
				sloe=>sloe,slrd=>slrd,slwr=>slwr,pktend=>pktend,
				fifoadr=>usb_fifoadr,
				usb_data_in=>usb_data_in,
				usb_data_out=>usb_data_out,
				usb_data_en=>usb_data_en,
				pc_rqu=>pc_rqu,
				usb_in=>usb_in,
				
				w_rqu=>uwr_wr_rqu,r_rqu=>uwr_rd_rqu,
				w_ready=>uwr_wr_ready,r_ready=>uwr_rd_ready,
				w_end=>uwr_wr_end,r_end=>uwr_rd_end,
				ram_dm=>uwr_dm,
				w_num=>uwr_wr_num,r_num=>uwr_rd_num,
				ram_bank=>uwr_bank,
				ram_addr_row=>uwr_addr_row,
				ram_addr_col=>uwr_addr_col,
				ram_data_in=>uwr_data_tousb,
				ram_data_out=>uwr_data_toram,
				
				ram_reset=>ram_reset_s1,
				usb_end=>usb_end_s
			);	
		
	LED_CONTROL:LED
		port map
			(
				clk_control=>clk_40m_p,
				clk_data_p=>clk_320m_p,
				
				sensor=>sensor,
				data_buffer_a=>data_buffer_a,
				data_buffer_b=>data_buffer_b,
				data_buffer_c=>data_buffer_c,
				en_row_a=>en_row_a,
				en_row_b=>en_row_b,
				en_row_c=>en_row_c,
				en_col_a_1=>en_col_a_1,en_col_a_2=>en_col_a_2,en_col_a_3=>en_col_a_3,
				en_col_b_1=>en_col_b_1,en_col_b_2=>en_col_b_2,en_col_b_3=>en_col_b_3,
				en_col_c_1=>en_col_c_1,en_col_c_2=>en_col_c_2,en_col_c_3=>en_col_c_3,
				
				blue_rqu=>lwb_in_rqu,
				blue_end=>lwb_in_end,
				blue_data=>lwb_in_data,
				
				r_rqu=>lwr_rd_rqu,
				r_ready=>lwr_rd_ready,
				r_end=>lwr_rd_end,
				r_num=>lwr_rd_num,
				ram_reset=>ram_reset_s2,
				ram_dm=>lwr_dm,
				ram_bank=>lwr_bank,
				ram_addr_row=>lwr_addr_row,
				ram_addr_col=>lwr_addr_col,
				ram_data=>lwr_data_ram
			);
			
	BLUETOOTH:BLUETOOTH_CONTROL
		port map
			(
				clk_self=>clk_40m_p,pll_lock=>pll1_lock,
				
				bluetooth_rqu=>bluetooth_rqu,
				bluetooth_ack=>bluetooth_ack,
				bluetooth_reset=>bluetooth_reset,
				bluetooth_data=>bluetooth_data,
				
				in_rqu=>lwb_in_rqu,
				in_end=>lwb_in_end,
				data_in=>lwb_in_data
			);
	
			
RAM:process(clk_320m_p,pll2_lock)

begin
	
	if clk_320m_p'event and clk_320m_p='1' and pll2_lock='1' then
	
--		case usb_data_en is
--			
--			when '0' =>
--				usb_data<="ZZZZZZZZZZZZZZZZ";
--				usb_data_in<=usb_data;
--			
--			when others =>
--				usb_data<=usb_data_out;
--		
--		end case;

--		case dm_s is
--			
--			when "0011" =>
--				uwr_data_tousb<=data_from_ram_2;
--				lwr_data_ram<=data_from_ram_2;
--			when "1100" =>
--				uwr_data_tousb<=data_from_ram_1;
--				lwr_data_ram<=data_from_ram_1;
--			when others =>
--				null;
--		
--		end case;
	
		case usb_end_last is
		
			when '0' =>
				dm_s<=uwr_dm;
				ram_bank_s<=uwr_bank;
				ram_addr_row_s<=uwr_addr_row;
				ram_addr_col_s<=uwr_addr_col;
				rd_rqu_s<=uwr_rd_rqu;
				rd_num_s<=uwr_rd_num;
				ram_reset_s<=ram_reset_s1;
				
			when others =>
				dm_s<=lwr_dm;
				ram_bank_s<=lwr_bank;
				ram_addr_row_s<=lwr_addr_row;
				ram_addr_col_s<=lwr_addr_col;
				rd_rqu_s<=lwr_rd_rqu;
				rd_num_s(15 downto 8)<=x"00";
				rd_num_s(7 downto 0)<=lwr_rd_num;
				ram_reset_s<=ram_reset_s2;
		
		end case;
		
		usb_end_last<=usb_end_s;
		
--		if ram_data_out(15 downto 0)=x"0010" then
--			ram_data_out(15 downto 0)<=x"0000";
--		else
--			ram_data_out(15 downto 0)<=ram_data_out(15 downto 0)+1;
--		end if;
--		ram_data_out(31 downto 16)<=ram_data_out(15 downto 0);
	
	end if;

end process;

with dm_s select
	uwr_data_tousb<=data_from_ram_2 when "0011",
						 data_from_ram_1 when others;
				
with dm_s select			
	lwr_data_ram<=data_from_ram_2 when "0011",
						 data_from_ram_1 when others;

with usb_data_en select
	usb_data <= usb_data_out when '1',
					"ZZZZZZZZZZZZZZZZ" when others;
usb_data_in<=usb_data;

with dqs_en select
	udqs <= udqs_out when '1',
			  'Z' when others;
udqs_in<=udqs;
with dqs_en select
	ldqs <= ldqs_out when '1',
			  'Z' when others;
ldqs_in<=ldqs;

with dqs_en_2 select
	udqs_2 <= udqs_out_2 when '1',
			  'Z' when others;
udqs_in_2<=udqs_2;
with dqs_en_2 select
	ldqs_2 <= ldqs_out_2 when '1',
			  'Z' when others;
ldqs_in_2<=ldqs_2;

with ram_data_en select
	ddr2_data <= ram_data_out when '1',
					"ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ" when others;
ram_data_in<=ddr2_data;

uwr_rd_ready<=rd_ready_s;
uwr_rd_end<=rd_end_s;
lwr_rd_ready<=rd_ready_s;
lwr_rd_end<=rd_end_s;

end displayer;
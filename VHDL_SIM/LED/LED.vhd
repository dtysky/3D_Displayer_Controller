--A program for testing.
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


--实现方案：
--由于FIFO输入和输出只能为偶数倍关系，输入又必为32或16bits，所以最后将其调整：
--设立三类FIFO，其中后两类为普通的图片双缓存，第一类为转换

--写入时就按16bits写入！（为了满足要求，由于每一个模块总数据为120*38=4560=285*16），充分利用DM（数据掩码），将RAM作为先后两个RAM对待！
--写入时，一次写入856个16bits数据，丢掉最后一个

--读出时，按照16bits读出！顺序写入一个第一类FIFO
--读出时，每张图片总突发次数为214（最后一个16bits扔掉）

--第一类FIFO为16bits输入，16bits输出；二三类FIFO为80bits输入，40bis输出
--第一类FIFO和二三类之间插入一个80bits信号做缓存（80=16*5=80*1）
--经计算，每10us需更新一次图片，用此方法，保证FIFO数据流跑到240M（DDR2数据流速度），一次更新只需不到2us，满足要求

--所有输出到RAM的信号初值为0

--再锁定尚待加入

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity LED is
	generic
		(
			constant r20_con:integer:=2047;	------------20r/s时每一度间隔计数（clk_control下）
			constant opic_con:integer:=1023;	------------刷一张图片一遍计数
			constant unlock_con:integer:=4095		------------解锁计数
		);
	
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
			r_end:in std_logic;
			r_num:out std_logic_vector(7 downto 0);
			ram_reset:out std_logic:='0';
			ram_dm:out std_logic_vector(3 downto 0);
			ram_bank:out std_logic_vector(2 downto 0);
			ram_addr_row:out std_logic_vector(12 downto 0);
			ram_addr_col:out std_logic_vector(9 downto 0)
		);
end entity;


architecture ledx of LED is

component FIFO_LED_TRANS is
	port
		(
			aclr:in std_logic;
			data:in std_logic_vector(15 downto 0);
			rdclk:in std_logic;
			rdreq:in std_logic;
			wrclk:in std_logic;
			wrreq:in std_logic;
			q:out std_logic_vector(15 downto 0);
			wrusedw:out std_logic_vector(10 downto 0);
			rdusedw:out std_logic_vector(10 downto 0)
		);
end component;

component FIFO_LED_PIC is
	port
		(
			aclr:in std_logic;
			data:in std_logic_vector(79 downto 0);
			rdclk:in std_logic;
			rdreq:in std_logic;
			wrclk:in std_logic;
			wrreq:in std_logic;
			q:out std_logic_vector(39 downto 0);
			rdusedw:out std_logic_vector(7 downto 0);
			wrusedw:out std_logic_vector(6 downto 0)
		);
end component;


----------------转换缓存----------------
signal fifo_buffer:std_logic_vector(79 downto 0);

----------------fifo例化----------------
--signal data_trans_in:std_logic_vector(15 downto 0);
signal data_trans_out:std_logic_vector(15 downto 0);
signal fifo_trans_write,fifo_trans_read:std_logic:='0';
signal fifo_trans_aclr:std_logic:='0';

signal data_pic_in_a_1:std_logic_vector(79 downto 0);
signal data_pic_out_a_1:std_logic_vector(39 downto 0);
signal clk_pic_out_a_1:std_logic:='0';
signal fifo_pic_write_a_1,fifo_pic_read_a_1:std_logic:='0';
signal fifo_pic_aclr_a_1:std_logic:='0';

signal data_pic_in_a_2:std_logic_vector(79 downto 0);
signal data_pic_out_a_2:std_logic_vector(39 downto 0);
signal clk_pic_out_a_2:std_logic:='0';
signal fifo_pic_write_a_2,fifo_pic_read_a_2:std_logic:='0';
signal fifo_pic_aclr_a_2:std_logic:='0';

signal data_pic_in_a_3:std_logic_vector(79 downto 0);
signal data_pic_out_a_3:std_logic_vector(39 downto 0);
signal clk_pic_out_a_3:std_logic:='0';
signal fifo_pic_write_a_3,fifo_pic_read_a_3:std_logic:='0';
signal fifo_pic_aclr_a_3:std_logic:='0';

signal data_pic_in_b_1:std_logic_vector(79 downto 0);
signal data_pic_out_b_1:std_logic_vector(39 downto 0);
signal clk_pic_out_b_1:std_logic:='0';
signal fifo_pic_write_b_1,fifo_pic_read_b_1:std_logic:='0';
signal fifo_pic_aclr_b_1:std_logic:='0';

signal data_pic_in_b_2:std_logic_vector(79 downto 0);
signal data_pic_out_b_2:std_logic_vector(39 downto 0);
signal clk_pic_out_b_2:std_logic:='0';
signal fifo_pic_write_b_2,fifo_pic_read_b_2:std_logic:='0';
signal fifo_pic_aclr_b_2:std_logic:='0';

signal data_pic_in_b_3:std_logic_vector(79 downto 0);
signal data_pic_out_b_3:std_logic_vector(39 downto 0);
signal clk_pic_out_b_3:std_logic:='0';
signal fifo_pic_write_b_3,fifo_pic_read_b_3:std_logic:='0';
signal fifo_pic_aclr_b_3:std_logic:='0';

--------------fifo已写/可读数据-----------
signal fifo_trans_num:std_logic_vector(10 downto 0);
signal fifo_trans_num_buffer:std_logic_vector(10 downto 0);

signal fifo_pic_num_w_a_1:std_logic_vector(6 downto 0);
signal fifo_pic_num_r_a_1:std_logic_vector(7 downto 0);
signal fifo_pic_num_w_a_2:std_logic_vector(6 downto 0);
signal fifo_pic_num_w_a_3:std_logic_vector(6 downto 0);

signal fifo_pic_num_w_a_1_buffer:std_logic_vector(6 downto 0);
signal fifo_pic_num_w_a_2_buffer:std_logic_vector(6 downto 0);
signal fifo_pic_num_w_a_3_buffer:std_logic_vector(6 downto 0);

signal fifo_pic_num_w_b_1:std_logic_vector(6 downto 0);
signal fifo_pic_num_w_b_2:std_logic_vector(6 downto 0);
signal fifo_pic_num_w_b_3:std_logic_vector(6 downto 0);

signal fifo_pic_num_w_b_1_buffer:std_logic_vector(6 downto 0);
signal fifo_pic_num_w_b_2_buffer:std_logic_vector(6 downto 0);
signal fifo_pic_num_w_b_3_buffer:std_logic_vector(6 downto 0);

-------------------ram-------------------
signal ram_bank_s:std_logic_vector(2 downto 0):="000";
signal ram_addr_row_s:std_logic_vector(12 downto 0):="0000000000000";
signal ram_addr_col_s:std_logic_vector(9 downto 0):="0000000000";
signal r_rqu_s,r_ready_s:std_logic:='0';

------------------状态标志----------------
type states_t is (trans_in,trans_a,trans_b);
signal trans_state:states_t:=trans_in;

type states_c is (free,control_work);
signal control_state:states_c:=free;

type states_l is (lock,unlock);
signal lock_state:states_l:=lock;

signal control_begin:std_logic:='0';
signal fifo_choice:std_logic:='0';

signal sensor_last:std_logic:='0';

------------------图片第几张--------------
signal pic_num:std_logic_vector(12 downto 0):="0000000000001";	----从1开始
signal pic_num_last:std_logic_vector(12 downto 0):="0000000000001";
signal pic_dm:std_logic_vector(3 downto 0):="0011";
signal pic_bank:std_logic_vector(2 downto 0):="000";
signal pic_addr_row:std_logic_vector(12 downto 0):="0000000000000";

-------------------图片行-----------------
signal pic_row_ab:bit_vector(37 downto 0):="01111111111111111111111111111111111111";
signal pic_row_c_h:bit_vector(37 downto 0):="01111111111111111111111111111111111111";
signal pic_row_c_l:bit_vector(37 downto 0):="11111111111111111101111111111111111111";
signal pic_no:std_logic_vector(7 downto 0):=x"00";

-------------------蓝牙------------------
signal blue_rqu_s:std_logic;


begin

	r_rqu<=r_rqu_s;
	
	--pic_row_abc_n<=pic_row_abc;


	FIFO_TRANS:FIFO_LED_TRANS
		port map
			(
				aclr=>fifo_trans_aclr,
				data=>ram_data,q=>data_trans_out,
				wrclk=>clk_data_p,rdclk=>clk_data_p,
				wrreq=>fifo_trans_write,rdreq=>fifo_trans_read,
				wrusedw=>fifo_trans_num
			);

			
	FIFO_PIC_A_1:FIFO_LED_PIC
		port map
			(
				aclr=>fifo_pic_aclr_a_1,
				data=>data_pic_in_a_1,q=>data_pic_out_a_1,
				wrclk=>clk_data_p,rdclk=>clk_pic_out_a_1,
				wrreq=>fifo_pic_write_a_1,rdreq=>fifo_pic_read_a_1,
				wrusedw=>fifo_pic_num_w_a_1,rdusedw=>fifo_pic_num_r_a_1
			);
	
	FIFO_PIC_A_2:FIFO_LED_PIC
		port map
			(
				aclr=>fifo_pic_aclr_a_2,
				data=>data_pic_in_a_2,q=>data_pic_out_a_2,
				wrclk=>clk_data_p,rdclk=>clk_pic_out_a_2,
				wrreq=>fifo_pic_write_a_2,rdreq=>fifo_pic_read_a_2,
				wrusedw=>fifo_pic_num_w_a_2
			);
			
	FIFO_PIC_A_3:FIFO_LED_PIC
		port map
			(
				aclr=>fifo_pic_aclr_a_3,
				data=>data_pic_in_a_3,q=>data_pic_out_a_3,
				wrclk=>clk_data_p,rdclk=>clk_pic_out_a_3,
				wrreq=>fifo_pic_write_a_3,rdreq=>fifo_pic_read_a_3,
				wrusedw=>fifo_pic_num_w_a_3
			);
			
	
	FIFO_PIC_B_1:FIFO_LED_PIC
		port map
			(
				aclr=>fifo_pic_aclr_b_1,
				data=>data_pic_in_b_1,q=>data_pic_out_b_1,
				wrclk=>clk_data_p,rdclk=>clk_pic_out_b_1,
				wrreq=>fifo_pic_write_b_1,rdreq=>fifo_pic_read_b_1,
				wrusedw=>fifo_pic_num_w_b_1
			);

	FIFO_PIC_B_2:FIFO_LED_PIC
		port map
			(
				aclr=>fifo_pic_aclr_b_2,
				data=>data_pic_in_b_2,q=>data_pic_out_b_2,
				wrclk=>clk_data_p,rdclk=>clk_pic_out_b_2,
				wrreq=>fifo_pic_write_b_2,rdreq=>fifo_pic_read_b_2,
				wrusedw=>fifo_pic_num_w_b_2
			);

	FIFO_PIC_B_3:FIFO_LED_PIC
		port map
			(
				aclr=>fifo_pic_aclr_b_3,
				data=>data_pic_in_b_3,q=>data_pic_out_b_3,
				wrclk=>clk_data_p,rdclk=>clk_pic_out_b_3,
				wrreq=>fifo_pic_write_b_3,rdreq=>fifo_pic_read_b_3,
				wrusedw=>fifo_pic_num_w_b_3
			);
			
	

TRANS:process(clk_data_p)

variable con_unlock:integer range 0 to unlock_con+1:=0;
variable con_trans_in:integer range 0 to 3:=0;
variable con_trans_a:integer range 0 to 15:=0;
variable con_trans_b:integer range 0 to 15:=0;
variable con_timeout:integer range 0 to 127:=0;


begin

	if clk_data_p'event and clk_data_p='1' then
		
		case lock_state is
		---------------LOCK------------------
			when lock =>
			
				if sensor_last='0' and sensor='1' then
					
					if con_unlock>unlock_con then
						lock_state<=unlock;
						con_unlock:=0;
					else
						lock_state<=lock;
					end if;
				
				else
				
					if con_unlock>unlock_con then
						con_unlock:=con_unlock;
					else
						con_unlock:=con_unlock+1;
					end if;
				
				end if;
			
			----------------RELOAD---------------
			when others =>
			
				pic_num_last<=pic_num;
				if pic_num_last=pic_num then
					control_begin<=control_begin;
				else
					control_begin<='0';
				end if;
				
				if sensor_last='0' and sensor='1' then
					fifo_trans_aclr<='1';
					con_trans_in:=0;
					con_trans_a:=0;
					con_trans_b:=0;
					con_unlock:=0;
					
					pic_addr_row(12 downto 9)<=pic_no(3 downto 0);
					pic_bank<=pic_no(6 downto 4);
					
					if pic_no(7)='1' then
						pic_dm<="0011";
					else
						pic_dm<="1100";
					end if;
					
					trans_state<=trans_in;
					
				else

					case trans_state is
					----------------TRANS_IN-----------------
						when trans_in =>
							
							case con_trans_in is
								
								when 0 =>
									r_num<=x"D6";	----214次突发
									ram_dm<=pic_dm;		----一张三维图的所有切片必在一个bank内，由于是静态三维图，故不用切换bank，更不用切换RAM
									ram_bank_s<=pic_bank;
									ram_addr_row_s<=pic_addr_row+pic_num-1;
									ram_addr_col_s<="0000000000";
									con_timeout:=0;
									ram_reset<='0';
									con_trans_in:=1;
							
								when 1 =>
								
									ram_bank<=ram_bank_s;
									ram_addr_row<=ram_addr_row_s;
									ram_addr_col<=ram_addr_col_s;
								
									if fifo_trans_num_buffer="0000000000" then
										fifo_trans_aclr<='0';
										r_rqu_s<='1';
										con_trans_in:=2;
									else
										fifo_trans_aclr<='1';
										r_rqu_s<='0';
										con_trans_in:=1;
									end if;
								
								when 2  =>
									
									case r_ready_s is
									
										when '1' =>
											fifo_trans_write<='1';
											con_timeout:=0;
											
										when others =>
											
											if con_timeout=80 then
												r_rqu_s<='0';
												ram_reset<='1';
												con_timeout:=0;
											else
												con_timeout:=con_timeout+1;
											end if;
											
											if fifo_trans_num_buffer="01101011000" then		----是否提前一个周期待定
												con_trans_in:=3;
											else
												con_trans_in:=2;
											end if;
											
									end case;
									
									if fifo_trans_num_buffer="01101011000" then		
										fifo_trans_write<='0';
										r_rqu_s<='0';
									else
										r_rqu_s<='1';
									end if;
									
								when others =>
											
									if fifo_pic_num_w_a_1_buffer="0000000" and fifo_pic_num_w_b_1_buffer="0000000" then
										trans_state<=trans_a;
										con_trans_in:=0;
									elsif fifo_pic_num_w_a_1_buffer="0000000" then
										trans_state<=trans_a;
										con_trans_in:=0;
									elsif fifo_pic_num_w_b_1_buffer="0000000" then
										trans_state<=trans_b;
										con_trans_in:=0;
									else
										trans_state<=trans_in;
										con_trans_in:=2;
									end if;
								
							end case;
							
						----------------TRANS_A-----------------
						when trans_a =>		----------从FIFO_TRANS读五个，然后塞入第一个FIFO，满后第二个，满后第三个
							
							case con_trans_a is
							
								when 0 =>
									fifo_trans_read<='1';
									con_trans_a:=con_trans_a+1;
								
								when 1 =>
									fifo_buffer(79 downto 64)<=data_trans_out;
									con_trans_a:=con_trans_a+1;
								
								when 2 =>
									fifo_buffer(63 downto 48)<=data_trans_out;
									con_trans_a:=con_trans_a+1;
								
								when 3 =>
									fifo_buffer(47 downto 32)<=data_trans_out;
									con_trans_a:=con_trans_a+1;
								
								when 4 =>
									fifo_buffer(31 downto 16)<=data_trans_out;
									con_trans_a:=con_trans_a+1;
								
								when 5 =>
									fifo_buffer(15 downto 0)<=data_trans_out;
									fifo_trans_read<='0';
									con_trans_a:=con_trans_a+1;
								
								when 6 =>
									
									if fifo_pic_num_w_a_1_buffer<"0111001" then
										data_pic_in_a_1<=fifo_buffer;
										fifo_pic_write_a_1<='1';
									elsif fifo_pic_num_w_a_2_buffer<"0111001" then
										data_pic_in_a_2<=fifo_buffer;
										fifo_pic_write_a_2<='1';
									elsif fifo_pic_num_w_a_3_buffer<"0111001" then
										data_pic_in_a_3<=fifo_buffer;
										fifo_pic_write_a_3<='1';
									else
										con_trans_a:=con_trans_a;
									end if;
									con_trans_a:=con_trans_a+1;
									
								when others =>
									fifo_pic_write_a_1<='0';
									fifo_pic_write_a_2<='0';
									fifo_pic_write_a_3<='0';
									con_trans_a:=0;
									
									if fifo_trans_num_buffer="00000000001" then
										
										if fifo_pic_num_w_b_1_buffer="0000000" then
											control_begin<='1';
										else
											control_begin<='0';
										end if;
										
										fifo_trans_aclr<='1';
										trans_state<=trans_in;
									
									else
										trans_state<=trans_a;
									
									end if;
								
							end case;
								
						----------------TRANS_B-----------------
						when trans_b =>		----------从FIFO_TRANS读五个，然后塞入第一个FIFO，满后第二个，满后第三个
							
							case con_trans_b is
							
								when 0 =>
									fifo_trans_read<='1';
									con_trans_b:=con_trans_b+1;
								
								when 1 =>
									fifo_buffer(79 downto 64)<=data_trans_out;
									con_trans_b:=con_trans_b+1;
								
								when 2 =>
									fifo_buffer(63 downto 48)<=data_trans_out;
									con_trans_b:=con_trans_b+1;
								
								when 3 =>
									fifo_buffer(47 downto 32)<=data_trans_out;
									con_trans_b:=con_trans_b+1;
								
								when 4 =>
									fifo_buffer(31 downto 16)<=data_trans_out;
									con_trans_b:=con_trans_b+1;
								
								when 5 =>
									fifo_buffer(15 downto 0)<=data_trans_out;
									fifo_trans_read<='0';
									con_trans_b:=con_trans_b+1;
								
								when 6 =>
									
									if fifo_pic_num_w_b_1_buffer<"0111001" then
										data_pic_in_b_1<=fifo_buffer;
										fifo_pic_write_b_1<='1';
									elsif fifo_pic_num_w_b_2_buffer<"0111001" then
										data_pic_in_b_2<=fifo_buffer;
										fifo_pic_write_b_2<='1';
									elsif fifo_pic_num_w_b_3_buffer<"0111001" then
										data_pic_in_b_3<=fifo_buffer;
										fifo_pic_write_b_3<='1';
									else
										con_trans_b:=con_trans_b;
									end if;
									con_trans_b:=con_trans_b+1;
									
								when others =>
									fifo_pic_write_b_1<='0';
									fifo_pic_write_b_2<='0';
									fifo_pic_write_b_3<='0';
									con_trans_b:=0;
									
									if fifo_trans_num_buffer="00000000001" then
										fifo_trans_aclr<='1';
										trans_state<=trans_in;
									else
										trans_state<=trans_b;
									end if;
							
							end case;
							

					end case;
				
				end if;
		
		end case;
		
		r_ready_s<=r_ready;
		sensor_last<=sensor;
		fifo_trans_num_buffer<=fifo_trans_num;
		fifo_pic_num_w_a_1_buffer<=fifo_pic_num_w_a_1;
		fifo_pic_num_w_a_2_buffer<=fifo_pic_num_w_a_2;
		fifo_pic_num_w_a_3_buffer<=fifo_pic_num_w_a_3;
		fifo_pic_num_w_b_1_buffer<=fifo_pic_num_w_b_1;
		fifo_pic_num_w_b_2_buffer<=fifo_pic_num_w_b_2;
		fifo_pic_num_w_b_3_buffer<=fifo_pic_num_w_b_3;
		
	
	end if;
	
end process;



CONTROL:process(clk_control)

variable con_step:integer range 0 to r20_con:=0;
variable con_control_work:integer range 0 to 15:=0;
		
begin

	if clk_control'event and clk_control='1' then
	
		blue_rqu_s<=blue_rqu;
		case blue_rqu_s is
	
			when '1' =>
				pic_no<=blue_data;
				blue_end<='1';
			when others =>
				blue_end<='0';
				
		end case;
		
		case lock_state is
		---------------LOCK------------------
			when lock =>
				
				control_state<=control_state;
					
			--------------CHIOCE-----------------
			when others =>
				
				if sensor_last='0' and sensor='1' then
					con_step:=0;
					con_control_work:=0;
					fifo_pic_aclr_a_1<='1';
					fifo_pic_aclr_a_2<='1';
					fifo_pic_aclr_a_3<='1';
					fifo_pic_aclr_b_1<='1';
					fifo_pic_aclr_b_2<='1';
					fifo_pic_aclr_b_3<='1';
					control_state<=free;
				
				else
					
					case con_step is
					
						when opic_con =>
							con_step:=0;
							con_control_work:=0;
							fifo_pic_aclr_a_1<='1';
							fifo_pic_aclr_a_2<='1';
							fifo_pic_aclr_a_3<='1';
							fifo_pic_aclr_b_1<='1';
							fifo_pic_aclr_b_2<='1';
							fifo_pic_aclr_b_3<='1';
							
							if pic_num="0001000000000" then
								pic_num<="0000000000001";
								control_state<=free;
							else
								pic_num<=pic_num+1;
							end if;
						
						when others =>
							con_step:=con_step+1;
							
							case control_state is
							---------------IDLE------------------		
								when free =>
									
									fifo_pic_aclr_a_1<='0';
									fifo_pic_aclr_a_2<='0';
									fifo_pic_aclr_a_3<='0';
									fifo_pic_aclr_b_1<='0';
									fifo_pic_aclr_b_2<='0';
									fifo_pic_aclr_b_3<='0';
									
									if control_begin='1' then
										control_state<=control_work;
									else
										control_state<=control_state;
									end if;
								
							---------------WORK------------------		
								when control_work =>
									
									case con_control_work is
									
										when 0 =>
											
											if fifo_pic_num_r_a_1>0 then
												fifo_choice<='0';
												fifo_pic_read_a_1<='1';
												fifo_pic_read_a_2<='1';
												fifo_pic_read_a_3<='1';
											else
												fifo_choice<='1';
												fifo_pic_read_b_1<='1';
												fifo_pic_read_b_2<='1';
												fifo_pic_read_b_3<='1';
											end if;
											
											data_buffer_a<=x"0000000000";
											data_buffer_b<=x"0000000000";
											data_buffer_c<=x"0000000000";
											
										when 1 =>
										
											en_row_a<='1';
											con_control_work:=con_control_work+1;
										
										when 2 =>
											
											if fifo_choice='0' then
												clk_pic_out_a_1<='1';
												clk_pic_out_a_2<='1';
												clk_pic_out_a_3<='1';
											else
												clk_pic_out_b_1<='1';
												clk_pic_out_b_2<='1';
												clk_pic_out_b_3<='1';
											end if;
											
											en_row_b<='1';
											en_row_c<="11";
											con_control_work:=con_control_work+1;
										
										when 3 =>
											en_row_a<='0';
											en_row_b<='0';
											en_row_c<="00";
											
											if fifo_choice='0' then
												clk_pic_out_a_1<='0';
												clk_pic_out_a_2<='0';
												clk_pic_out_a_3<='0';
											else
												clk_pic_out_b_1<='0';
												clk_pic_out_b_2<='0';
												clk_pic_out_b_3<='0';
											end if;
											con_control_work:=con_control_work+1;
										
										when 4 =>
										
											if fifo_choice='0' then
												data_buffer_a<=data_pic_out_a_1;
												data_buffer_b<=data_pic_out_a_2;
												data_buffer_c<=data_pic_out_a_3;
											else
												data_buffer_a<=data_pic_out_b_1;
												data_buffer_b<=data_pic_out_b_2;
												data_buffer_c<=data_pic_out_b_3;
											end if;
											con_control_work:=con_control_work+1;
										
										when 5 =>
										
											if fifo_choice='0' then
												clk_pic_out_a_1<='1';
												clk_pic_out_a_2<='1';
												clk_pic_out_a_3<='1';
											else
												clk_pic_out_b_1<='1';
												clk_pic_out_b_2<='1';
												clk_pic_out_b_3<='1';
											end if;
										
											en_col_a_1<='1';
											en_col_b_1<='1';
											en_col_c_1<='1';
											con_control_work:=con_control_work+1;
										
										when 6 =>
										
											if fifo_choice='0' then
												clk_pic_out_a_1<='0';
												clk_pic_out_a_2<='0';
												clk_pic_out_a_3<='0';
											else
												clk_pic_out_b_1<='0';
												clk_pic_out_b_2<='0';
												clk_pic_out_b_3<='0';
											end if;
										
											if fifo_choice='0' then
												data_buffer_a<=data_pic_out_a_1;
												data_buffer_b<=data_pic_out_a_2;
												data_buffer_c<=data_pic_out_a_3;
											else
												data_buffer_a<=data_pic_out_b_1;
												data_buffer_b<=data_pic_out_b_2;
												data_buffer_c<=data_pic_out_b_3;
											end if;
											con_control_work:=con_control_work+1;
											
										when 7 =>
											
											if fifo_choice='0' then
												clk_pic_out_a_1<='1';
												clk_pic_out_a_2<='1';
												clk_pic_out_a_3<='1';
											else
												clk_pic_out_b_1<='1';
												clk_pic_out_b_2<='1';
												clk_pic_out_b_3<='1';
											end if;
										
											en_col_a_2<='1';
											en_col_b_2<='1';
											en_col_c_2<='1';
											con_control_work:=con_control_work+1;
										
										when 8 =>
										
											if fifo_choice='0' then
												clk_pic_out_a_1<='0';
												clk_pic_out_a_2<='0';
												clk_pic_out_a_3<='0';
											else
												clk_pic_out_b_1<='0';
												clk_pic_out_b_2<='0';
												clk_pic_out_b_3<='0';
											end if;
										
											if fifo_choice='0' then
												data_buffer_a<=data_pic_out_a_1;
												data_buffer_b<=data_pic_out_a_2;
												data_buffer_c<=data_pic_out_a_3;
											else
												data_buffer_a<=data_pic_out_b_1;
												data_buffer_b<=data_pic_out_b_2;
												data_buffer_c<=data_pic_out_b_3;
											end if;
											con_control_work:=con_control_work+1;
											
										when 9 =>
											en_col_a_3<='1';
											en_col_b_3<='1';
											en_col_c_3<='1';
											con_control_work:=con_control_work+1;
										
										when 10 =>
											en_col_a_1<='0';
											en_col_b_1<='0';
											en_col_c_1<='0';
											en_col_a_2<='0';
											en_col_b_2<='0';
											en_col_c_2<='0';
											en_col_a_3<='0';
											en_col_b_3<='0';
											en_col_c_3<='0';
											con_control_work:=con_control_work+1;
										
										when 11 =>
											
											data_buffer_b(39 downto 2)<=to_stdlogicvector(pic_row_ab);
											
											if pic_row_c_h(37)='0' then
												data_buffer_c(19 downto 1)<="0111111111111111111";
											elsif pic_row_c_h(18)='0' then
												data_buffer_c(19 downto 1)<="1111111111111111111";
											else
												data_buffer_c(19 downto 1)<=to_stdlogicvector(pic_row_c_h(18 downto 0));
											end if;
											
											if pic_row_c_l(0)='0' then
												data_buffer_c(38 downto 20)<="1111111111111111110";
											else
												data_buffer_c(38 downto 20)<=to_stdlogicvector(pic_row_c_l(37 downto 19));
											end if;
											con_control_work:=con_control_work+1;
										
										when 12 =>
											en_row_a<='1';
											con_control_work:=con_control_work+1;
											
										when 13 =>
											en_row_b<='1';
											en_row_c<="11";
											con_control_work:=con_control_work+1;
										
										when 14 =>
											en_col_a_1<='0';
											en_col_b_1<='0';
											en_col_c_1<='0';
											en_col_a_2<='0';
											en_col_b_2<='0';
											en_col_c_2<='0';
											en_col_a_3<='0';
											en_col_b_3<='0';
											en_col_c_3<='0';

											en_row_a<='0';
											en_row_b<='0';
											en_row_c<="00";
											con_control_work:=con_control_work+1;
											
										when 15 =>
											pic_row_ab<=pic_row_ab rol 1;
											pic_row_c_h<=pic_row_c_h rol 1;
											pic_row_c_l<=pic_row_c_l ror 1;
											con_control_work:=0;
											
										when others =>
											con_control_work:=con_control_work+1;
											
									end case;
									
								when others =>
									control_state<=control_work;
								
							end case;
						
					end case;
						
				end if;					
	
		end case;
	
	end if;

end process;
			
		
end ledx;
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity LED is
	generic
		(
			constant cpd:integer:=2047	------------count per one degree（inclk下）
		);
	
	port
		(
			inclk:in std_logic;
			rst:in std_logic;
			
			data_buffer_a:out std_logic_vector(39 downto 0):=x"0000000000";
			data_buffer_b:out std_logic_vector(39 downto 0):=x"0000000000";
			data_buffer_c:out std_logic_vector(39 downto 0):=x"0000000000";
			en_row_a:out std_logic:='0';
			en_row_b:out std_logic:='0';
			en_row_c:out std_logic_vector(1 downto 0):="00";									--------分割为两个管脚，分配同一信号
			en_col_a_1,en_col_a_2,en_col_a_3:out std_logic:='0';
			en_col_b_1,en_col_b_2,en_col_b_3:out std_logic:='0';
			en_col_c_1,en_col_c_2,en_col_c_3:out std_logic:='0';
			
			control_begin:in std_logic:='0';
			fifo_change:out std_logic:='0';
			fifo_en_r:out std_logic;
			fifo_data_1:in std_logic_vector(127 downto 0);
			fifo_data_2:in std_logic_vector(127 downto 0);
			fifo_data_3:in std_logic_vector(127 downto 0)
		);
end entity;


architecture RTL of LED is


------------------State----------------
type states_c is (free,control_work);
signal control_state:states_c:=free;
signal fifo_change_s:std_logic:='0';

--------------Row of frame-------------
signal frame_row_ab:bit_vector(37 downto 0):="01111111111111111111111111111111111111";
signal frame_row_c_h:bit_vector(37 downto 0):="01111111111111111111111111111111111111";
signal frame_row_c_l:bit_vector(37 downto 0):="11111111111111111101111111111111111111";

procedure frame_change(
	variable con_step:inout integer;
	signal fifo_change:inout std_logic;
	signal control_state:inout states_c
	) is
begin
	if con_step=cpd then
		fifo_change<=not fifo_change;
		control_state<=free;
		con_step:=0;
	else
		con_step:=con_step+1;
	end if;
end frame_change;

begin

fifo_change<=fifo_change_s;

MAIN:process(inclk,rst)

variable con_step:integer range 0 to cpd:=0;
variable con_control_work:integer range 0 to 63:=0;
variable con_total:integer range 0 to 63:=0;
		
begin
	if rst='1' then
		control_state<=free;
		con_control_work:=0;
		con_step:=0;
		con_total:=0;
	
	elsif rising_edge(inclk) then
		case control_state is
		---------------IDLE------------------		
			when free =>
				con_control_work:=0;
				con_step:=0;
				con_total:=0;
				if control_begin='1' then
					control_state<=control_work;
				else
					control_state<=control_state;
				end if;
			
		---------------WORK------------------		
			when control_work =>
				----------change a frame---------- 
				frame_change(con_step,fifo_change_s,control_state);
				
				if con_control_work=50 then
					if con_total=37 then
						null;
					else
						con_control_work:=0;
						con_total:=con_total+1;
					end if;
				else
					con_control_work:=con_control_work+1;
				end if;
				
				case con_control_work is
				
					when 0 =>
						data_buffer_a<=x"0000000000";
						data_buffer_b<=x"0000000000";
						data_buffer_c<=x"0000000000";
					when 1 =>
						en_col_a_1<='0';
						en_col_b_1<='0';
						en_col_c_1<='0';
						en_col_a_2<='0';
						en_col_b_2<='0';
						en_col_c_2<='0';
						en_col_a_3<='0';
						en_col_b_3<='0';
						en_col_c_3<='0';
					when 2=>
						en_col_a_1<='1';
						en_col_b_1<='1';
						en_col_c_1<='1';
					when 3 =>
						en_col_a_2<='1';
						en_col_b_2<='1';
						en_col_c_2<='1';
					when 4 =>
						en_col_a_3<='1';
						en_col_b_3<='1';
						en_col_c_3<='1';
					
					when 5 =>
						data_buffer_a<=x"FFFFFFFFFF";
					when 6 =>
						en_row_a<='0';
						en_row_b<='0';
					when 7 =>
						en_row_a<='1';
						en_row_b<='1';
					
					when 8 =>
						data_buffer_c<=x"FFFFFFFFFF";
					when 9 =>
						en_row_c<="00";
					when 10 =>
						en_row_c<="11";
					
					when 11 =>
						data_buffer_a<=x"0000000000";
						data_buffer_c<=x"0000000000";
						
					when 12 =>
						fifo_en_r<='1';
					
					when 13=>
						fifo_en_r<='0';
					
					when 14 =>
						data_buffer_a(39 downto 2)<=to_stdlogicvector(frame_row_ab);
					when 15 =>
						en_row_a<='0';
						en_row_b<='0';
					when 16=>
						en_row_a<='1';
						en_row_b<='1';
						
					when 17 =>
						
						if frame_row_c_h(37)='0' then
							data_buffer_c(19 downto 1)<="0111111111111111111";
						elsif frame_row_c_h(18)='0' then
							data_buffer_c(19 downto 1)<="1111111111111111111";
						else
							data_buffer_c(19 downto 1)<=to_stdlogicvector(frame_row_c_h(18 downto 0));
						end if;
						
						if frame_row_c_l(0)='0' then
							data_buffer_c(38 downto 20)<="1111111111111111110";
						else
							data_buffer_c(38 downto 20)<=to_stdlogicvector(frame_row_c_l(37 downto 19));
						end if;
					when 18 =>
						en_row_c<="00";
					when 19 =>
						en_row_c<="11";
					
					when 20 =>
						data_buffer_a<=fifo_data_1(119 downto 80);
						
					when 21=>
						data_buffer_b<=fifo_data_2(119 downto 80);
					
					when 22 =>
						data_buffer_c<=fifo_data_3(119 downto 80);
					
					when 23=>
						en_col_a_1<='0';
						en_col_b_1<='0';
						en_col_c_1<='0';
					when 24 =>
						en_col_a_1<='1';
						en_col_b_1<='1';
						en_col_c_1<='1';
					
					when 25 =>
						data_buffer_a<=fifo_data_1(79 downto 40);
					
					when 26 =>
						data_buffer_b<=fifo_data_2(79 downto 40);
					
					when 27 =>
						data_buffer_c<=fifo_data_3(79 downto 40);
					
					when 28 =>
						en_col_a_2<='0';
						en_col_b_2<='0';
						en_col_c_2<='0';
					when 29 =>
						en_col_a_2<='1';
						en_col_b_2<='1';
						en_col_c_2<='1';
					
					when 30 =>
						data_buffer_a<=fifo_data_1(39 downto 0);
					
					when 31 =>
						data_buffer_b<=fifo_data_2(39 downto 0);
					
					when 32 =>
						data_buffer_c<=fifo_data_3(39 downto 0);
					
					when 33 =>
						en_col_a_3<='0';
						en_col_b_3<='0';
						en_col_c_3<='0';
					when 34 =>
						en_col_a_3<='1';
						en_col_b_3<='1';
						en_col_c_3<='1';
						
					when 35 =>
						frame_row_ab<=frame_row_ab rol 1;
						frame_row_c_h<=frame_row_c_h rol 1;
						frame_row_c_l<=frame_row_c_l ror 1;
						
					when others =>
						null;
						
				end case;
				
			when others =>
				control_state<=control_work;
			
		end case;
	
	end if;					

end process;
			
		
end RTL;
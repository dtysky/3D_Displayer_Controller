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
			fifo_clk_r:out std_logic;
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
variable con_control_work:integer range 0 to 15:=0;
		
begin

	if inclk'event and inclk='1' then

		if rst='1' then
			control_state<=free;
			con_control_work:=0;
			con_step:=0;
		
		else		
			case control_state is
			---------------IDLE------------------		
				when free =>
					con_control_work:=0;
					con_step:=0;
					if control_begin='1' then
						control_state<=control_work;
					else
						control_state<=control_state;
					end if;
				
			---------------WORK------------------		
				when control_work =>
					----------change a frame---------- 
					frame_change(con_step,fifo_change_s,control_state);

					case con_control_work is
					
						when 0 =>
							fifo_en_r<='1';
							data_buffer_a<=x"0000000000";
							data_buffer_b<=x"0000000000";
							data_buffer_c<=x"0000000000";
							
						when 1 =>
							fifo_clk_r<='1';
							en_row_a<='1';
							con_control_work:=con_control_work+1;
						
						when 2 =>
							fifo_clk_r<='0';
							fifo_en_r<='0';
							en_row_b<='1';
							en_row_c<="11";
							con_control_work:=con_control_work+1;
						
						when 3 =>
							en_row_a<='0';
							en_row_b<='0';
							en_row_c<="00";
							con_control_work:=con_control_work+1;
						
						when 4 =>
							data_buffer_a<=fifo_data_1(119 downto 80);
							data_buffer_b<=fifo_data_2(119 downto 80);
							data_buffer_c<=fifo_data_3(119 downto 80);
							con_control_work:=con_control_work+1;
						
						when 5 =>
							en_col_a_1<='1';
							en_col_b_1<='1';
							en_col_c_1<='1';
							con_control_work:=con_control_work+1;
						
						when 6 =>
							data_buffer_a<=fifo_data_1(79 downto 40);
							data_buffer_b<=fifo_data_2(79 downto 40);
							data_buffer_c<=fifo_data_3(79 downto 40);
							con_control_work:=con_control_work+1;
							
						when 7 =>
							en_col_a_2<='1';
							en_col_b_2<='1';
							en_col_c_2<='1';
							con_control_work:=con_control_work+1;
						
						when 8 =>
							data_buffer_a<=fifo_data_1(39 downto 0);
							data_buffer_b<=fifo_data_2(39 downto 0);
							data_buffer_c<=fifo_data_3(39 downto 0);
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
							
							data_buffer_b(39 downto 2)<=to_stdlogicvector(frame_row_ab);
							
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
							frame_row_ab<=frame_row_ab rol 1;
							frame_row_c_h<=frame_row_c_h rol 1;
							frame_row_c_l<=frame_row_c_l ror 1;
							
						when others =>
							con_control_work:=con_control_work+1;
							
					end case;
					
				when others =>
					control_state<=control_work;
				
			end case;
		
		end if;					
	
	end if;

end process;
			
		
end RTL;
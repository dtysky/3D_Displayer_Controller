library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity DECODER is
generic
	(
		constant fpr:integer:=360;
		constant cmd_end:std_logic_vector(1 downto 0):="00"
	);
port
	(
		inclk,rst:in std_logic;
		
		control_begin:out std_logic:='0';
		load_next:in std_logic;
		fifo_en_w:out std_logic:='0';
		fifo_aclr:out std_logic:='0';
		fifo_clk_w_1:out std_logic:='0';
		fifo_clk_w_2:out std_logic:='0';
		fifo_clk_w_3:out std_logic:='0';
		fifo_data_1:out std_logic_vector(127 downto 0);
		fifo_data_2:out std_logic_vector(127 downto 0);
		fifo_data_3:out std_logic_vector(127 downto 0)
	);
end entity;

architecture RTL of DECODER is

type state is (init,idle,load);
signal st:state:=init;
type load_state is (read_next,judge,set,clear,do_write);
signal load_st:load_state:=judge;

signal data_cmd:std_logic_vector(1 downto 0):="00";
signal data_x,data_y:std_logic_vector(6 downto 0):="0000000";
signal x_now,y_now,y_last,y_sub:integer range 0 to 127:=0;

signal fifo_tmp:std_logic_vector(127 downto 0);
signal row_tmp:std_logic_vector(119 downto 0);

signal rom_addr:std_logic_vector(5 downto 0):="000000";
signal write_fin:std_logic:='0';

procedure row_clear(
	signal row:inout std_logic_vector(119 downto 0)
	) is
begin
	row<=x"000000000000000000000000000000";
end row_clear;
procedure fifo_write(
	signal row_num:in integer;
	signal write_fin:inout std_logic;
	variable con_wr:inout integer
	) is
begin
	if con_wr=1 then
		fifo_en_w<='0';
		fifo_clk_w_1<='0';
		fifo_clk_w_2<='0';
		fifo_clk_w_3<='0';
		write_fin<='1';
	else
		fifo_en_w<='1';
		if row_num<40 then
			fifo_clk_w_1<='1';
		elsif row_num<80 then
			fifo_clk_w_2<='1';
		else
			fifo_clk_w_3<='1';
		end if;
		write_fin<='0';
		con_wr:=con_wr+1;
	end if;
end fifo_write;

begin

fifo_tmp(127 downto 120)<=x"00";
fifo_tmp(119 downto 0)<=row_tmp;

x_now<=conv_integer(data_x);
y_now<=conv_integer(data_y);

fifo_data_1<=fifo_tmp;
fifo_data_2<=fifo_tmp;
fifo_data_3<=fifo_tmp;

MAIN:process(inclk,rst)

variable con_frame:integer range 0 to fpr:=0;
variable con_wr:integer range 0 to 3:=0;

begin

	if rst='1' then
		st<=init;
	elsif rising_edge(inclk) then
		case st is
			when init =>
				rom_addr<="000000";
				control_begin<='0';
				fifo_aclr<='1';
				load_st<=judge;
				st<=load;
			when idle =>
				if load_next='1' then
					if con_frame=fpr-1 then
						rom_addr<="000000";
					else
						con_frame:=con_frame+1;
						rom_addr<=rom_addr+1;
					end if;
					row_clear(row_tmp);
					fifo_aclr<='1';
					st<=load;
				else
					st<=st;
				end if;
			when load =>
				fifo_aclr<='0';
				case load_st is
					when read_next =>
						y_last<=y_now;
						rom_addr<=rom_addr+1;
						load_st<=judge;
					when judge =>
						if data_cmd=cmd_end then
							st<=idle;
						elsif y_now=y_last then
							load_st<=set;
						else
							load_st<=do_write;
						end if;
					when set =>
						row_tmp(x_now)<='1';
						load_st<=read_next;
					when clear =>
						row_clear(row_tmp);
						if y_sub=0 then
							load_st<=set;
						else
							y_last<=y_last+1;
							load_st<=do_write;
						end if;
					when do_write =>
						fifo_write(y_last,write_fin,con_wr);
						if write_fin='1' then
							y_sub<=y_now-y_last-1;
							write_fin<='0';
							load_st<=clear;
						else
							load_st<=load_st;
						end if;
				end case;
		end case;
	end if;
end process;

end RTL;
		
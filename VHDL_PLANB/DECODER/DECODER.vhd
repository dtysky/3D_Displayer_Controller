library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity DECODER is
generic
	(
		constant fpr:integer:=360;
		constant cmd_end:std_logic_vector(1 downto 0):="11"
	);
port
	(
		inclk,rst:in std_logic;
		
		control_begin:out std_logic:='0';
		load_next:in std_logic;
		fifo_en_w_1:out std_logic:='0';
		fifo_en_w_2:out std_logic:='0';
		fifo_en_w_3:out std_logic:='0';
		fifo_aclr:out std_logic:='0';
		fifo_data_1:out std_logic_vector(127 downto 0);
		fifo_data_2:out std_logic_vector(127 downto 0);
		fifo_data_3:out std_logic_vector(127 downto 0)
	);
end entity;

architecture RTL of DECODER is

component ROM is
port
	(
		clock:in std_logic;
		address:in std_logic_vector(12 downto 0);
		q:out std_logic_vector(15 downto 0)
	);
end component;

type state is (init,idle,load);
signal st:state:=init;
type load_state is (read_next,judge,set,clear,do_write);
signal load_st:load_state:=judge;

signal data_cmd:std_logic_vector(1 downto 0):="00";
signal data_x,data_y:std_logic_vector(6 downto 0):="0000000";
signal x_now,y_now,y_last,y_sub:integer range 0 to 127:=0;

signal fifo_tmp:std_logic_vector(127 downto 0);
signal row_tmp:std_logic_vector(119 downto 0);

signal rom_addr:std_logic_vector(12 downto 0):="0000000000000";
signal rom_data:std_logic_vector(15 downto 0):=x"0000";
signal write_fin:std_logic:='0';

procedure row_clear(
	signal row:inout std_logic_vector(119 downto 0)
	) is
begin
	row<=x"000000000000000000000000000000";
end row_clear;

procedure fifo_write(
	signal row_num:in integer range 0 to 127;
	signal write_fin:inout std_logic;
	signal fifo_en_w_1:out std_logic;
	signal fifo_en_w_2:out std_logic;
	signal fifo_en_w_3:out std_logic;
	variable con_wr:inout integer
	) is
begin
	if con_wr=1 then
		fifo_en_w_1<='0';
		fifo_en_w_2<='0';
		fifo_en_w_3<='0';
		write_fin<='1';
	else
		if row_num<40 then
			fifo_en_w_1<='1';
		elsif row_num<80 then
			fifo_en_w_2<='1';
		else
			fifo_en_w_3<='1';
		end if;
		write_fin<='0';
		con_wr:=con_wr+1;
	end if;
end fifo_write;

begin

fifo_tmp(127 downto 120)<=x"00";
fifo_tmp(119 downto 0)<=row_tmp;

data_cmd<=rom_data(15 downto 14);
data_x<=rom_data(13 downto 7);
data_y<=rom_data(6 downto 0);

x_now<=conv_integer(data_x);
y_now<=conv_integer(data_y);

fifo_data_1<=fifo_tmp;
fifo_data_2<=fifo_tmp;
fifo_data_3<=fifo_tmp;

ROM1:ROM
	port map
		(
			clock=>inclk,
			address=>rom_addr,
			q=>rom_data
		);

MAIN:process(inclk,rst)

variable con_frame:integer range 0 to fpr:=0;
variable con_wr:integer range 0 to 3:=0;
variable con_init:integer range 0 to 15:=0;
variable con_read_rom:integer range 0 to 3:=0;

begin

	if rst='1' then
		con_init:=0;
		st<=init;
	elsif rising_edge(inclk) then
		case st is
			when init =>
				if con_init=15 then
					rom_addr<="0000000000000";
					control_begin<='0';
					row_clear(row_tmp);
					fifo_aclr<='1';
					y_last<=0;
					con_read_rom:=1;
					load_st<=read_next;
					st<=load;
				else
					con_init:=con_init+1;
				end if;
			when idle =>
				if load_next='1' then
					if con_frame=fpr-1 then
						rom_addr<="0000000000000";
						con_frame:=0;
					else
						con_frame:=con_frame+1;
						rom_addr<=rom_addr+1;
					end if;
					row_clear(row_tmp);
					fifo_aclr<='1';
					y_last<=0;
					con_read_rom:=1;
					load_st<=read_next;
					st<=load;
				else
					st<=st;
				end if;
			when load =>
				fifo_aclr<='0';
				case load_st is
					when read_next =>
						if con_read_rom=3 then
							load_st<=judge;
							con_read_rom:=0;
						elsif con_read_rom=0 then
							rom_addr<=rom_addr+1;
							con_read_rom:=con_read_rom+1;
						else
							con_read_rom:=con_read_rom+1;
						end if;
					when judge =>
						if data_cmd=cmd_end then
							con_wr:=0;
							load_st<=do_write;
						elsif y_now=y_last then
							load_st<=set;
						else
							con_wr:=0;
							load_st<=do_write;
						end if;
					when set =>
						row_tmp(x_now)<='1';
						load_st<=read_next;
					when clear =>
						row_clear(row_tmp);
						if y_sub=0 then
							if data_cmd=cmd_end then
								control_begin<='1';
								st<=idle;
							else
								y_last<=y_now;
								load_st<=set;
							end if;
						else
							y_last<=y_last+1;
							con_wr:=0;
							load_st<=do_write;
						end if;
					when do_write =>
						fifo_write(y_last,write_fin,fifo_en_w_1,fifo_en_w_2,fifo_en_w_3,con_wr);
						if write_fin='1' then
							if data_cmd=cmd_end then
								y_sub<=113-y_last-1;
							else
								y_sub<=y_now-y_last-1;
							end if;
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
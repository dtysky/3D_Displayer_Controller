library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity VHDL_PLANB is 
port
	(
		inclk:in std_logic:='0';
		data_buffer_a:out std_logic_vector(39 downto 0):=x"0000000000";
		data_buffer_b:out std_logic_vector(39 downto 0):=x"0000000000";
		data_buffer_c:out std_logic_vector(39 downto 0):=x"0000000000";
		en_row_a:out std_logic:='0';
		en_row_b:out std_logic:='0';
		en_row_c:out std_logic_vector(1 downto 0):="00";									--------分割为两个管脚，分配同一信号
		en_col_a_1,en_col_a_2,en_col_a_3:out std_logic:='0';
		en_col_b_1,en_col_b_2,en_col_b_3:out std_logic:='0';
		en_col_c_1,en_col_c_2,en_col_c_3:out std_logic:='0'
	);
end entity;

architecture RTL of VHDL_PLANB is
	
	component PLL is
	port
		(
			inclk0:in std_logic;
			c0,c1,c2:out std_logic
		);
	end component;

	component DECODER is
	generic
		(
			constant fpr:integer:=360
		);
	port
		(
			inclk,rst:in std_logic;
			
			control_begin:out std_logic:='0';
			load_next:in std_logic;
			fifo_aclr:out std_logic:='0';
			fifo_en_w_1:out std_logic:='0';
			fifo_en_w_2:out std_logic:='0';
			fifo_en_w_3:out std_logic:='0';
			fifo_data_1:out std_logic_vector(127 downto 0);
			fifo_data_2:out std_logic_vector(127 downto 0);
			fifo_data_3:out std_logic_vector(127 downto 0)
		);
	end component;

	component LED is
		generic
			(
				constant cpd:integer:=4000	------------count per one degree（inclk下）
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
				
				control_begin:in std_logic;
				fifo_change:out std_logic;
				fifo_en_r:out std_logic;
				fifo_data_1:in std_logic_vector(127 downto 0);
				fifo_data_2:in std_logic_vector(127 downto 0);
				fifo_data_3:in std_logic_vector(127 downto 0)
			);
	end component;
	
	component FIFO is
	port
	(
		aclr:in std_logic:= '0';
		data:in std_logic_vector(127 downto 0);
		rdclk:in std_logic;
		rdreq:in std_logic;
		wrclk:in std_logic;
		wrreq:in std_logic;
		q:out std_logic_vector(127 downto 0)
	);
	end component;
	
	signal rst:std_logic:='0';
	
	signal clk_decoder,clk_led,clk_main:std_logic;
	signal control_begin:std_logic;
	signal load_next:std_logic:='0';
	signal fifo_change,fifo_change_last:std_logic;
	signal fifo_aclr:std_logic:='0';
	signal fifo_clk_w:std_logic:='0';
	signal fifo_en_w_1:std_logic:='0';
	signal fifo_en_w_2:std_logic:='0';
	signal fifo_en_w_3:std_logic:='0';
	signal fifo_data_dec_1:std_logic_vector(127 downto 0);
	signal fifo_data_dec_2:std_logic_vector(127 downto 0);
	signal fifo_data_dec_3:std_logic_vector(127 downto 0);
	signal fifo_en_r:std_logic:='0';
	signal fifo_clk_r:std_logic:='0';
	signal fifo_data_led_1:std_logic_vector(127 downto 0);
	signal fifo_data_led_2:std_logic_vector(127 downto 0);
	signal fifo_data_led_3:std_logic_vector(127 downto 0);
	signal fifo_aclr_a:std_logic:='0';
	signal fifo_en_w_1_a:std_logic:='0';
	signal fifo_en_w_2_a:std_logic:='0';
	signal fifo_en_w_3_a:std_logic:='0';
	signal fifo_data_dec_1_a:std_logic_vector(127 downto 0);
	signal fifo_data_dec_2_a:std_logic_vector(127 downto 0);
	signal fifo_data_dec_3_a:std_logic_vector(127 downto 0);
	signal fifo_en_r_a:std_logic:='0';
	signal fifo_data_led_1_a:std_logic_vector(127 downto 0);
	signal fifo_data_led_2_a:std_logic_vector(127 downto 0);
	signal fifo_data_led_3_a:std_logic_vector(127 downto 0);
	signal fifo_aclr_b:std_logic:='0';
	signal fifo_en_w_1_b:std_logic:='0';
	signal fifo_en_w_2_b:std_logic:='0';
	signal fifo_en_w_3_b:std_logic:='0';
	signal fifo_data_dec_1_b:std_logic_vector(127 downto 0);
	signal fifo_data_dec_2_b:std_logic_vector(127 downto 0);
	signal fifo_data_dec_3_b:std_logic_vector(127 downto 0);
	signal fifo_en_r_b:std_logic:='0';
	signal fifo_data_led_1_b:std_logic_vector(127 downto 0);
	signal fifo_data_led_2_b:std_logic_vector(127 downto 0);
	signal fifo_data_led_3_b:std_logic_vector(127 downto 0);
	
begin

	CLOCK:PLL
		port map
			(
				inclk0=>inclk,
				c0=>clk_led,
				c1=>clk_decoder,
				c2=>clk_main
			);

	DECODER1:DECODER
		port map
			(
				inclk=>clk_decoder,
				rst=>rst,
			
				control_begin=>control_begin,
				load_next=>load_next,
				fifo_aclr=>fifo_aclr,
				fifo_en_w_1=>fifo_en_w_1,
				fifo_en_w_2=>fifo_en_w_2,
				fifo_en_w_3=>fifo_en_w_3,
				fifo_data_1=>fifo_data_dec_1,
				fifo_data_2=>fifo_data_dec_2,
				fifo_data_3=>fifo_data_dec_3
			);

	LED1:LED
		port map
			(
				inclk=>clk_led,
				rst=>rst,
				
				data_buffer_a=>data_buffer_a,
				data_buffer_b=>data_buffer_b,
				data_buffer_c=>data_buffer_c,
				en_row_a=>en_row_a,
				en_row_b=>en_row_b,
				en_row_c=>en_row_c,
				en_col_a_1=>en_col_a_1,en_col_a_2=>en_col_a_2,en_col_a_3=>en_col_a_3,
				en_col_b_1=>en_col_b_1,en_col_b_2=>en_col_b_2,en_col_b_3=>en_col_b_3,
				en_col_c_1=>en_col_c_1,en_col_c_2=>en_col_c_2,en_col_c_3=>en_col_c_3,
				
				control_begin=>control_begin,
				fifo_change=>fifo_change,
				fifo_en_r=>fifo_en_r,
				fifo_data_1=>fifo_data_led_1,
				fifo_data_2=>fifo_data_led_2,
				fifo_data_3=>fifo_data_led_3
			);
	
	FIFO1A:FIFO
		port map
			(
				aclr=>fifo_aclr_a,
				data=>fifo_data_dec_1_a,
				rdclk=>fifo_clk_r,
				rdreq=>fifo_en_r_a,
				wrclk=>fifo_clk_w,
				wrreq=>fifo_en_w_1_a,
				q=>fifo_data_led_1_a
			);

	FIFO2A:FIFO
		port map
			(
				aclr=>fifo_aclr_a,
				data=>fifo_data_dec_2_a,
				rdclk=>fifo_clk_r,
				rdreq=>fifo_en_r_a,
				wrclk=>fifo_clk_w,
				wrreq=>fifo_en_w_2_a,
				q=>fifo_data_led_2_a
			);

	FIFO3A:FIFO
		port map
			(
				aclr=>fifo_aclr_a,
				data=>fifo_data_dec_3_a,
				rdclk=>fifo_clk_r,
				rdreq=>fifo_en_r_a,
				wrclk=>fifo_clk_w,
				wrreq=>fifo_en_w_3_a,
				q=>fifo_data_led_3_a
			);

	FIFO1B:FIFO
		port map
			(
				aclr=>fifo_aclr_b,
				data=>fifo_data_dec_1_b,
				rdclk=>fifo_clk_r,
				rdreq=>fifo_en_r_b,
				wrclk=>fifo_clk_w,
				wrreq=>fifo_en_w_1_b,
				q=>fifo_data_led_1_b
			);

	FIFO2B:FIFO
		port map
			(
				aclr=>fifo_aclr_b,
				data=>fifo_data_dec_2_b,
				rdclk=>fifo_clk_r,
				rdreq=>fifo_en_r_b,
				wrclk=>fifo_clk_w,
				wrreq=>fifo_en_w_2_b,
				q=>fifo_data_led_2_b
			);

	FIFO3B:FIFO
		port map
			(
				aclr=>fifo_aclr_b,
				data=>fifo_data_dec_3_b,
				rdclk=>fifo_clk_r,
				rdreq=>fifo_en_r_b,
				wrclk=>fifo_clk_w,
				wrreq=>fifo_en_w_3_b,
				q=>fifo_data_led_3_b
			);			

			
fifo_data_dec_1_a<=fifo_data_dec_1;
fifo_data_dec_2_a<=fifo_data_dec_2;
fifo_data_dec_3_a<=fifo_data_dec_3;
fifo_data_dec_1_b<=fifo_data_dec_1;
fifo_data_dec_2_b<=fifo_data_dec_2;
fifo_data_dec_3_b<=fifo_data_dec_3;

fifo_clk_w<=clk_decoder;
fifo_clk_r<=clk_led;
			
MAIN:process(clk_main,rst)

begin
	if rst='1' then
		fifo_aclr_a<=fifo_aclr;
		fifo_en_r_a<=fifo_en_r;
		fifo_en_w_1_a<=fifo_en_w_1;
		fifo_en_w_2_a<=fifo_en_w_2;
		fifo_en_w_3_a<=fifo_en_w_3;
		fifo_data_led_1<=fifo_data_led_1_a;
		fifo_data_led_2<=fifo_data_led_2_a;
		fifo_data_led_3<=fifo_data_led_3_a;
	elsif rising_edge(clk_main) then
		fifo_change_last<=fifo_change;
		if control_begin='0' then
			fifo_aclr_a<=fifo_aclr;
			fifo_en_r_a<=fifo_en_r;
			fifo_en_w_1_a<=fifo_en_w_1;
			fifo_en_w_2_a<=fifo_en_w_2;
			fifo_en_w_3_a<=fifo_en_w_3;
			fifo_data_led_1<=fifo_data_led_1_a;
			fifo_data_led_2<=fifo_data_led_2_a;
			fifo_data_led_3<=fifo_data_led_3_a;
		elsif fifo_change='1' then
			fifo_en_r_b<=fifo_en_r;
			fifo_data_led_1<=fifo_data_led_1_b;
			fifo_data_led_2<=fifo_data_led_2_b;
			fifo_data_led_3<=fifo_data_led_3_b;
			fifo_aclr_b<='0';
			fifo_en_w_1_b<='0';
			fifo_en_w_2_b<='0';
			fifo_en_w_3_b<='0';
			fifo_aclr_a<=fifo_aclr;
			fifo_en_w_1_a<=fifo_en_w_1;
			fifo_en_w_2_a<=fifo_en_w_2;
			fifo_en_w_3_a<=fifo_en_w_3;
			fifo_en_r_a<='0';
		elsif fifo_change='0' then
			fifo_en_r_a<=fifo_en_r;
			fifo_data_led_1<=fifo_data_led_1_a;
			fifo_data_led_2<=fifo_data_led_2_a;
			fifo_data_led_3<=fifo_data_led_3_a;
			fifo_aclr_a<='0';
			fifo_en_w_1_a<='0';
			fifo_en_w_2_a<='0';
			fifo_en_w_3_a<='0';
			fifo_aclr_b<=fifo_aclr;
			fifo_en_w_1_b<=fifo_en_w_1;
			fifo_en_w_2_b<=fifo_en_w_2;
			fifo_en_w_3_b<=fifo_en_w_3;
			fifo_en_r_b<='0';
		end if;
		if fifo_change_last/=fifo_change then
			load_next<='1';
		else
			load_next<='0';
		end if;
	end if;

end process;
		

end RTL;
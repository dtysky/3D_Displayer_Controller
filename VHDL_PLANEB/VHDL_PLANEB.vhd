library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity VHDL_PLANEB is 
port
	(
		inclk:in std_logic;
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

architecture RTL of VHDL_PLANEB is

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
			fifo_en_w:out std_logic:='0';
			fifo_aclr:out std_logic:='0';
			fifo_clk_w_1:out std_logic:='0';
			fifo_clk_w_2:out std_logic:='0';
			fifo_clk_w_3:out std_logic:='0';
			fifo_data_1:out std_logic_vector(127 downto 0);
			fifo_data_2:out std_logic_vector(127 downto 0);
			fifo_data_3:out std_logic_vector(127 downto 0)
		);
	end component;

	component LED is
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
				
				control_begin:in std_logic;
				fifo_change:out std_logic;
				fifo_clk_r:out std_logic;
				fifo_en_r:out std_logic;
				fifo_data_1:in std_logic_vector(127 downto 0);
				fifo_data_2:in std_logic_vector(127 downto 0);
				fifo_data_3:in std_logic_vector(127 downto 0)
			);
	end component;
	
	signal clk_decoder,clk_led:std_logic;
	signal rst:std_logic:='0';
	signal control_begin:std_logic;
	signal load_next:std_logic;
	signal fifo_en_w:std_logic;
	signal fifo_aclr:std_logic;
	signal fifo_clk_w_1:std_logic;
	signal fifo_clk_w_2:std_logic;
	signal fifo_clk_w_3:std_logic;
	signal fifo_data_dec_1:std_logic_vector(127 downto 0);
	signal fifo_data_dec_2:std_logic_vector(127 downto 0);
	signal fifo_data_dec_3:std_logic_vector(127 downto 0);
	signal fifo_change:std_logic;
	signal fifo_en_r:std_logic;
	signal fifo_clk_r:std_logic;
	signal fifo_data_led_1:std_logic_vector(127 downto 0);
	signal fifo_data_led_2:std_logic_vector(127 downto 0);
	signal fifo_data_led_3:std_logic_vector(127 downto 0);
	
begin

	DECODER1:DECODER
		port map
			(
				inclk=>clk_decoder,
				rst=>rst,
			
				control_begin=>control_begin,
				load_next=>load_next,
				fifo_en_w=>fifo_en_w,
				fifo_aclr=>fifo_aclr,
				fifo_clk_w_1=>fifo_clk_w_1,
				fifo_clk_w_2=>fifo_clk_w_2,
				fifo_clk_w_3=>fifo_clk_w_3,
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
				fifo_clk_r=>fifo_clk_r,
				fifo_data_1=>fifo_data_led_1,
				fifo_data_2=>fifo_data_led_2,
				fifo_data_3=>fifo_data_led_3
			);
	
end RTL;
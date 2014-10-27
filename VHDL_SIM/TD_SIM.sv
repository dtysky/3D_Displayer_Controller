module TD_SIM;
	timeunit 1ps;
	timeprecision 1ps;

	//DDR2
	bit clk_c_0,clk_c_180,clk_o_0,clk_o_180,clk_d_0,clk_d_180,pll_lock;
	bit ddr2_clk,ddr2_clk_n;
	bit cke,n_cs,n_ras,n_cas,n_we;
	wire[1:0] dm,dm_2;
	wire[1:0] dqs,dqs_2;
	bit odt;
	bit[2:0] ddr2_bank;
	bit[12:0] ddr2_addr;
	wire[31:0] ddr2_data;
	//USB
	bit usb_full,usb_empty;
	bit usb_clk;
	bit sloe,slrd,pktend;
	bit slwr;
	bit pc_rqu;
	bit usb_in;
	bit[1:0] usb_fifoadr;
	wire[15:0] usb_data;
	//LED
	bit sensor;
	bit[39:0] data_buffer_a,data_buffer_b,data_buffer_c;
	bit en_row_a,en_row_b,en_row_c;
	bit en_col_a_1,en_col_a_2,en_col_a_3;
	bit en_col_b_1,en_col_b_2,en_col_b_3;
	bit en_col_c_1,en_col_c_2,en_col_c_3;
	//BULETOOTH
	bit bluetooth_rqu;
	bit bluetooth_ack;
	bit bluetooth_reset;
	wire[3:0] bluetooth_data;

	class usb_class;
	
	endclass :usb_class

	//Class
	usb_class usb;

	//Instantiation
	CLOCK CLK(
		clk_c_0,clk_c_180,
		clk_o_0,clk_o_180,
		clk_d_0,clk_d_180,
		pll_lock
		);

	TD_DISPLATER TD_DIS(
		ddr2_clk,ddr2_clk_n,
		cke,n_cs,n_ras,n_cas,n_we,
		dm[1],dm[0],dm_2[1],dm_2[0],
		dqs[1],dqs[0],dqs_2[1],dqs_2[0],
		odt,
		ddr2_bank,
		ddr2_addr,
		ddr2_data,
		//USB
		usb_full,usb_empty,
		usb_clk,
		sloe,slrd,pktend,
		slwr,
		pc_rqu,
		usb_in,
		usb_fifoadr,
		usb_data,
		//LED
		sensor,
		data_buffer_a,data_buffer_b,data_buffer_c,
		en_row_a,en_row_b,en_row_c,
		en_col_a_1,en_col_a_2,en_col_a_3,
		en_col_b_1,en_col_b_2,en_col_b_3,
		en_col_c_1,en_col_c_2,en_col_c_3,
		//BULETOOTH
		bluetooth_rqu,
		bluetooth_ack,
		bluetooth_reset,
		bluetooth_data
		);

		ddr2 DDR2M_1(
		ddr2_clk,ddr2_clk_n,
		cke,n_cs,n_ras,n_cas,n_we,
		dm,
		ddr2_bank,ddr2_addr,
		ddr2_data[31:16],
		dqs,dqs_n,rdqs_n,
		odt
		);

		ddr2 DDR2M_2(
		ddr2_clk,ddr2_clk_n,
		cke,n_cs,n_ras,n_cas,n_we,
		dm_2,
		ddr2_bank,ddr2_addr,
		ddr2_data[15:0],
		dqs_2,dqs_n,rdqs_n,
		odt
		);

		initial begin

		end



endmodule
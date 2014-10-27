module TD_SIM;
	timeunit 1ps;
	timeprecision 1ps;

	typedef enum {true,false} bool;

	//Clock
	bit clk_40m_p,clk_40m_p1,clk_160m_p,clk_160m_p1,clk_160m_n1;
	bit clk_320m_p,clk_320m_n,clk_stpii,pll1_lock,pll2_lock,pll3_lock;
	//DDR2
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

	//Class
	class usb_class;
		bit[1:0][7:0] cmd;
		bit[1:0][7:0] length;
		bit[3:0][7:0] no;
		bit[7:0] data_p[$];
		rand bit[1:0][7:0] ack;
		bit[7:0] data[$],data_r[$];
		rand int len_true;

		constraint c{
			len_true>=510;
			len_true<=512;
		}

		function new();
		
		endfunction : new

		function void up();
			no+=1;
		endfunction : up

		function void clear();
			no=0;
		endfunction : clear

		function void write_creat();
			data_p.delete();
			this.randomize();
			cmd=16'hA081;
			length=16'h0041;
			no+=1;
			repeat(502)
				data_p.push_back($urandom_range(0,8'hff));
			data={>>{cmd,length,no,data_p,ack}};
		endfunction : write_creat

		function bit[7:0] data_write(int i);
			return data[i];
		endfunction : data_write

		function void read_creat();
			data.delete();
			repeat(502)
				data_p.push_back(0);
			cmd=16'hA081;
			length=16'h0041;
			no+=1;
			data={>>{cmd,length,no,data_p,ack}};
		endfunction : read_creat

		function void data_read(bit[7:0] d);
			data_r.push_back(d);
		endfunction : data_read

		function bool ack_check(bit[1:0][7:0] ack_in);
			if (ack==ack_in)
				return true;
			else
				return false;
		endfunction : ack_check
		
	endclass :usb_class

	//Class
	usb_class usb;

	//Instantiation
	CLOCK CLK(
			clk_40m_p,clk_40m_p1,clk_160m_p,clk_160m_p1,clk_160m_n1,
			clk_320m_p,clk_320m_n,clk_stpii,pll1_lock,pll2_lock,pll3_lock
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

	logic[15:0] usb_data_reg;
	assign usb_data=usb_data_reg;

	//Task
	task usb_write();
		int i;
		bit[1:0][7:0] ack;
		usb.write_creat();
		@(posedge usb_clk);
		usb_full=1;
		while(!sloe) @(posedge usb_clk);
		usb_data_reg[15:8]=8'h00;
		usb_data_reg[7:0]=usb.data_write(0);
		usb_full=0;
		i=1;
		while(i<512) @(posedge usb_clk) begin
			if(slrd) begin
				usb_data_reg[15:8]=8'h00;
				usb_data_reg[7:0]=usb.data_write(i);
				i++;
			end
		end
		usb_empty=1;
		i=0;
		usb_data_reg=16'hzzzz;
		while(1) @(posedge usb_clk) begin
			if (i>1)
				$fatal("Error!");
			else if  (pktend)
				break;
			else if (slwr)
				ack[i]=usb_data[7:0];
				i++;
		end
		usb.ack_check(ack);
	endtask : usb_write

	task usb_read();
		int i;
		bit[1:0][7:0] ack;
		usb.write_creat();
		@(posedge usb_clk);
		usb_full=1;
		while(!sloe) @(posedge usb_clk);
		usb_data_reg[15:8]=8'h00;
		usb_data_reg[7:0]=usb.data_write(0);
		usb_full=0;
		i=1;
		while(i<512) @(posedge usb_clk) begin
			if(slrd) begin
				usb_data_reg[15:8]=8'h00;
				usb_data_reg[7:0]=usb.data_write(i);
				i++;
			end
		end
		usb_empty=1;
		i=0;
		usb_data_reg=16'hzzzz;
		usb_in=1;
		while(!slwr) @(posedge usb_clk);
		usb.data_read(usb_data[7:0]);
		while(slwr) @(posedge usb_clk)
			usb.data_read(usb_data[7:0]);
		usb_in=0;
		
	endtask : usb_read


	initial begin
		usb=new();
		repeat(100)
			usb_write();
		repeat(100)
			usb_read();

	end



endmodule
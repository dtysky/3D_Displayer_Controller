
module CLOCK (output bit clk_40m_p,clk_40m_p1,clk_160m_p,clk_160m_p1,clk_160m_n1,
	clk_320m_p,clk_320m_n,clk_stpii,pll1_lock,pll2_lock,pll3_lock);

	timeunit 1ps;
	timeprecision 1ps;
	parameter Cycle40 = 1500;
	parameter Cycle160 = 6000;
	parameter Cycle320 = 3000;

	initial begin
		clk_40m_p=0;
		clk_40m_p1=0;
		clk_160m_p=0;
		clk_160m_p1=0;
		clk_160m_n1=1;
		clk_320m_p=0;
		clk_320m_n=1;
		pll1_lock=1;
		pll2_lock=1;
		pll3_lock=1;
	end

	always #(Cycle40/2) begin
		clk_40m_p=~clk_40m_p;
		clk_40m_p1=~clk_40m_p1;
	end 

	always #(Cycle160/2) begin
		clk_160m_p=~clk_160m_p;
		clk_160m_p1=~clk_160m_p1;
		clk_160m_n1=~clk_160m_n1;
	end

	always #(Cycle320/2) begin
		clk_320m_p=~clk_320m_p;
		clk_320m_n=~clk_320m_n;
	end

endmodule
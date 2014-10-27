
module CLOCK (output bit clk_c_0,clk_c_180,clk_o_0,clk_o_180,clk_d_0,clk_d_180,pll_lock);

	timeunit 1ps;
	timeprecision 1ps;
	parameter CycleC = 6000;
	parameter CycleD = 3000;

	initial begin
		pll_lock=1;
		clk_c_0=0;
		clk_c_180 = 1;
		clk_o_0=0;
		clk_o_180 = 1;
		clk_d_0=0;
		clk_d_180 = 1;
		pll_lock = 1;
	end

	always #(CycleC/2) begin
		clk_c_0=~clk_c_0;
		clk_c_180=~clk_c_180;
		clk_o_0=~clk_o_0;
		clk_o_180=~clk_o_180;
	end

	always #(CycleD/2) begin
			clk_d_0=~clk_d_0;
			clk_d_180=~clk_d_180;
	end

endmodule
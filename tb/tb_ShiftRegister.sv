module tb_ShiftRegister();

	reg clk;
	reg rst_n;
	
	reg [7:0] shift_i;

	class seed;
		rand reg [7:0] shift;
	endclass
	seed test_seed;

    covergroup shiftData;
        coverpoint shift_i;
    endgroup
	shiftData shiftData_a;
	
	reg [7:0] c;
	reg [4:0] counter;
	initial begin
		test_seed = new();
		shiftData_a = new();
		test_seed.randomize();
		shift_i = test_seed.shift;
        rst_n = 0;
		@(posedge clk);
		rst_n = 1;
		repeat (500) begin
			@(posedge clk);
			test_seed.randomize();
			shift_i = test_seed.shift;
			shiftData_a.sample();
		end
	end
	
	initial clk = 0;
	always #10 clk = ~clk;
		
	initial begin
		#100000
		$display("XXXXXXXXXXXXXXX, %f", shiftData_a.get_coverage());
		#100
		$finish;
	end

	initial begin
		$fsdbDumpfile("xxx.fsdb");
		$fsdbDumpvars();
		$fsdbDumpMDA();
	end

	ShiftRegister u_dut (
		.clk(clk),
		.rst_n(rst_n),
		.shiftData_i(shift_i)
	);
	
	

endmodule

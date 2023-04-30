module tb_BLC();

	reg clk;
	reg rst_n;
	reg [7:0] rMean_i;
	reg [7:0] grMean_i;
	reg [7:0] gbMean_i;
	reg [7:0] bMean_i;
	
	reg href_i;
	reg vsync_i;
	reg [7:0] pixel_i;
	
	
	class seed;
		rand reg [7:0] rM;
		rand reg [7:0] grM;
		rand reg [7:0] gbM;
		rand reg [7:0] bM;
		rand reg [7:0] pixel;
	endclass
	seed test_seed;
	
	reg [7:0] c;
	reg [4:0] counter;
	initial begin
		test_seed = new();
		test_seed.randomize();
		rMean_i = test_seed.rM;
		grMean_i = test_seed.grM;
		gbMean_i = test_seed.gbM;
		bMean_i = test_seed.bM;
		pixel_i = test_seed.pixel;
		repeat (64) begin
			@(posedge clk);
			test_seed.randomize();
			pixel_i = test_seed.pixel;
		end
	end
	
	
	initial clk = 0;
	always #10 clk = ~clk;
	
	initial begin 
		href_i = 0;
		vsync_i = 1;
	end
		
	always begin
		repeat (2) begin
			@(posedge clk);
		end
		href_i = 1'b1;
		repeat (64) begin
			@(posedge clk);
		end
		href_i = 1'b0;
	end
	
	always begin
		@(posedge clk);
		vsync_i = 0;
		repeat (4) begin
			@(posedge href_i);
		end
		vsync_i = 1;
		@(posedge clk);
		vsync_i = 0;
	end
	
	initial begin
		rst_n = 0;
		@(posedge clk);
		rst_n = 1;
		#10000
		$finish;
	end

	
	initial begin
		$fsdbDumpfile("xxx.fsdb");
		$fsdbDumpvars();
		$fsdbDumpMDA();
	end
	

	BLC #(.width(64), .height(4))
	u_dut (
		.clk(clk),
		.rst_n(rst_n),
		.rMean_i(rMean_i),
		.grMean_i(grMean_i),
		.gbMean_i(gbMean_i),
		.bMean_i(bMean_i),
		.href_i(href_i),
		.vsync_i(vsync_i),
		.pixel_i(pixel_i),
		.href_o(),
		.vsync_o(),
		.pixel_o()
	);
	
	

endmodule

module tb_DPC();

	reg clk;
	reg rst_n;
	
	reg href_i;
	reg vsync_i;
	reg [7:0] pixel_i;

	reg href_i_reg;
	reg vsync_i_reg;
	reg [7:0] pixel_i_reg;
	
	
	class seed;	
		rand reg [7:0] pixel;
	endclass
	seed test_seed;
	
	reg [7:0] c;
	reg [4:0] counter;
	initial begin
		test_seed = new();
		test_seed.randomize();
		pixel_i = test_seed.pixel;
		repeat (64*100) begin
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
		#100000
		$finish;
	end

	
	initial begin
		$fsdbDumpfile("xxx.fsdb");
		$fsdbDumpvars();
		$fsdbDumpMDA();
	end


	always @(posedge clk or negedge rst_n) begin
		if(~rst_n) begin
			href_i_reg <= 1'b0;
			vsync_i_reg <= 1'b0;
			pixel_i_reg <= 8'h0;
		end else begin
			href_i_reg <= href_i;
			vsync_i_reg <= vsync_i;
			pixel_i_reg <= pixel_i;
		end
	end


	DPC #(.width(64), .height(4))
	u_dut (
		.clk(clk),
		.rst_n(rst_n),
		.href_i(href_i_reg),
		.vsync_i(vsync_i_reg),
		.pixel_i(pixel_i_reg),
		.threshold_i(200),
		.href_o(),
		.vsync_o(),
		.pixel_o()
	);
	
	

endmodule

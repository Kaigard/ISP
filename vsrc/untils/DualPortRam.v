module DualPortRam
#(
	parameter dataWidth = 8,
	parameter arrayWidth = 4,
	parameter size = 2**arrayWidth
)
(
	input clk,
	input writeEnable,
	input [arrayWidth-1 : 0] writeAddr,
	input [dataWidth-1 : 0] writeData,
	input readEnable,
	input [arrayWidth-1 : 0] readAddr,
	output [dataWidth-1 : 0] readData
);

    reg [dataWidth-1 : 0] memory [size-1 : 0];
    reg [dataWidth-1 : 0] readData_reg;

    always @(posedge clk) begin
        if(writeEnable) 
            memory[writeAddr] <= writeData;
    end

    always @(posedge clk) begin
        if(readEnable) 
            readData_reg <= memory[readAddr];
    end
    assign readData = readData_reg;

endmodule
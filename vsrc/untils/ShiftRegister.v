module ShiftRegister
#(
	parameter bits = 8,
	parameter width = 480,
	parameter lines = 4
)
(
	input                clk,
	input                rst_n,
	input  [bits-1:0]    shiftData_i,
	output [bits-1:0]    shiftData_o,
	output [bits*lines-1:0] tapData_o
);

    reg [$clog2(width)-1 : 0] point;
    wire [bits-1 : 0] lines_wires [lines-1 : 0];

    // 读、写指针 
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            point <= 0;
        end else begin
            if(point < width-1) 
                point <= point + 1;
            else
                point <= {$clog2(width){1'b0}};
        end
    end

    // 多bit位宽移位寄存器，由双端口RAM特性，读要在下一个指针循环才能读到数据，以此循环，进行4列数据的寄存
    // DualPortRam #(8, $clog2(width), width) U_DP_Ram_0 (clk, rst_n, point, shiftData_i, rst_n, point, lines_wires[0]);
    // DualPortRam #(8, $clog2(width), width) U_DP_Ram_1 (clk, rst_n, point, lines_wires[0], rst_n, point, lines_wires[1]);
    // DualPortRam #(8, $clog2(width), width) U_DP_Ram_2 (clk, rst_n, point, lines_wires[1], rst_n, point, lines_wires[2]);
    // DualPortRam #(8, $clog2(width), width) U_DP_Ram_3 (clk, rst_n, point, lines_wires[2], rst_n, point, lines_wires[3]);
    generate
        genvar i;
        for (i = 0; i < lines; i = i + 1) begin
            DualPortRam #(8, $clog2(width), width) U_DP_Ram_0 (clk, rst_n, point, (i > 0 ? lines_wires[i-1] : shiftData_i), rst_n, point, lines_wires[i]);
        end
    endgenerate
    
    // 获取每个line的最前端数据，而每进入一个数据就相当于所有line都进行了平移，tap数据就是每个line的头一个数据。（这个移位寄存器应该会贯穿ISP始终，精妙绝伦的结构！！！）
    generate
        genvar j;
        for (j = 0; j < lines; j = j + 1) begin
            assign tapData_o[bits*j +: bits] = lines_wires[j]; 
        end
    endgenerate

    assign shiftData_o = lines_wires[lines-1];

endmodule
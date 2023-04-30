module BLC
#(
    parameter bits = 8,
    parameter width = 2048,
    parameter height = 2048,
    parameter bayerFormat = 0       // 0:RGGB, 1:GRBG, 2:GBRG, 3:BGGR
)
(
    input clk,
    input rst_n,
    // 采用全局均值需要进行均值计算会耗费大量时间，因此使用较简单的自定义固定均值
    input [bits-1 : 0] rMean_i,      
    input [bits-1 : 0] grMean_i,
    input [bits-1 : 0] gbMean_i,
    input [bits-1 : 0] bMean_i,

    /*
                       _______    _______    _______    _______    
    href :  __________|       |__|       |__|       |__|       |________________________   ...
              _______                                                  _______ 
    vsync : _|       |______________ ... _____________________________|       |__________   ...
    */
    input href_i,                   // camer输出时序为DVP，h为行同步，v为帧同步
    input vsync_i,
    input [bits-1 : 0] pixel_i,
    
    output href_o,
    output vsync_o,
    output [bits-1 : 0] pixel_o
);
    
    /*
       R | G | R | G 
      ___|___|___|___
       G | B | G | B
         |   |   |
    RGGB format
    因此需要判断是奇数行还是偶数行，是奇数列还是偶数列，从而推出该像素是那种类型
    */

    reg odd_line;
    reg href_reg;
    wire href_jump;
    reg odd_row;
    reg [bits-1 : 0] pixel_new;
    reg href_new;
    reg vsync_new;

    // 奇偶列判断
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            odd_line <= 1'b0;
        end else begin
            // if(~href_i) 
            //     odd_line <= 1'b0;                      // 行同步，说明一行传输结束
            // else 
            //     odd_line <= ~odd_line;                 // 固定流水，每时钟周期进入一个pixel
            odd_line <= href_i ? ~odd_line : 1'b0;
        end        
    end

    // href打一拍做电平跳变（上升沿）判断(做电平跳变的条件：低电平维持超过一个clock，而href超过一个clock因此不能直接用低电平判断，可以用电平跳变判断)
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) 
            href_reg <= 1'b0;
        else 
            href_reg <= href_i;
    end
    assign href_jump = href_reg & ~href_i; 

    // 奇偶行判断
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            odd_row <= 1'b0;
        end else begin
            if(vsync_i) 
                odd_row <= 1'b0;
            else if(href_jump) 
                odd_row <= ~odd_row;
        end
    end

    wire [1:0] pixelFormat = bayerFormat[1:0] ^ {odd_row, odd_line}; // 可以推一下Format

    // 判断类型，然后减去mean。PS：function可综合,输出即函数名
    function [bits-1 : 0] pixel_sub_mean(input [bits-1 : 0] pixel, input [1:0] format);
        case (format)
            // r 
            2'b00 : pixel_sub_mean = pixel - rMean_i;
            // gr
            2'b01 : pixel_sub_mean = pixel - grMean_i;
            // gb
            2'b10 : pixel_sub_mean = pixel - gbMean_i;
            // b
            2'b11 : pixel_sub_mean = pixel - bMean_i;
            default : pixel_sub_mean = {bits{1'b0}};            // 不定位数赋默认值，为什么不用'b0，可以综合一下，'b0会自动往4的倍数上靠，会有多余的资源浪费（网上看的，反正我没试过）
        endcase
    endfunction

    // 输出pixel
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) 
            pixel_new <= {bits{1'b0}};
        else 
            pixel_new <= pixel_sub_mean(pixel_i, pixelFormat);
    end
    assign pixel_o = pixel_new;

    // 因为BLC仅用一个clock，所以行、帧同步一起打一拍丢出去。PS：寄存器一般不做复位
    always @(posedge clk) href_new <= href_i;
    always @(posedge clk) vsync_new <= vsync_i;
    assign href_o = href_new;
    assign vsync_o = vsync_new;

endmodule
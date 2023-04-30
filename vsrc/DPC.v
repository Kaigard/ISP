// 动态DPC
module DPC
#(
    parameter bits = 8,
    parameter width = 2048,
    parameter height = 2048,
    parameter bayerFormat = 0
)
(
    input clk,
    input rst_n,

    input href_i,
    input vsync_i,
    input [bits-1 : 0] pixel_i,

    input [bits-1 : 0] threshold_i,                        // 坏点阈值

    output href_o,
    output vsync_o,
    output [bits-1 : 0] pixel_o
);

    wire [bits-1 : 0] tapData [3 : 0];
    // 五乘五，因此仅需4行缓存行
    ShiftRegister #(8, width, 4) U_LineBuffer (clk, rst_n, pixel_i, , {tapData[3], tapData[2], tapData[1], tapData[0]});

    reg [bits-1 : 0] pixel_i_reg [6:0];                                                   // LineBuffer读取需要一个clock，所以打一拍对齐
    reg [bits-1 : 0] RF00, RF01, RF02, RF03, RF04;                                        // Receptive Field感受野
    reg [bits-1 : 0] RF10, RF11, RF12, RF13, RF14;
    reg [bits-1 : 0] RF20, RF21, RF22, RF23, RF24;
    reg [bits-1 : 0] RF30, RF31, RF32, RF33, RF34;
    reg [bits-1 : 0] RF40, RF41, RF42, RF43, RF44;
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            pixel_i_reg[0] <= {bits{1'b0}};
            RF00 <= {bits{1'b0}}; RF01 <= {bits{1'b0}}; RF02 <= {bits{1'b0}}; RF03 <= {bits{1'b0}}; RF04 <= {bits{1'b0}};
            RF10 <= {bits{1'b0}}; RF11 <= {bits{1'b0}}; RF12 <= {bits{1'b0}}; RF13 <= {bits{1'b0}}; RF14 <= {bits{1'b0}};
            RF20 <= {bits{1'b0}}; RF21 <= {bits{1'b0}}; RF22 <= {bits{1'b0}}; RF23 <= {bits{1'b0}}; RF24 <= {bits{1'b0}};
            RF30 <= {bits{1'b0}}; RF31 <= {bits{1'b0}}; RF32 <= {bits{1'b0}}; RF33 <= {bits{1'b0}}; RF34 <= {bits{1'b0}};
            RF40 <= {bits{1'b0}}; RF41 <= {bits{1'b0}}; RF42 <= {bits{1'b0}}; RF43 <= {bits{1'b0}}; RF44 <= {bits{1'b0}};
        end else begin
            pixel_i_reg[0] <= pixel_i;
            RF00 <= RF01; RF01 <= RF02; RF02 <= RF03; RF03 <= RF04; RF04 <= tapData[3];
            RF10 <= RF11; RF11 <= RF12; RF12 <= RF13; RF13 <= RF14; RF14 <= tapData[2];
            RF20 <= RF21; RF21 <= RF22; RF22 <= RF23; RF23 <= RF24; RF24 <= tapData[1];
            RF30 <= RF31; RF31 <= RF32; RF32 <= RF33; RF33 <= RF34; RF34 <= tapData[0];
            RF40 <= RF41; RF41 <= RF41; RF42 <= RF43; RF43 <= RF44; RF44 <= pixel_i_reg[0];
        end
    end

    // 奇偶行判断
    reg odd_pixel;
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n)
            odd_pixel <= 1'b0;
        else
            odd_pixel <= href_i ? ~odd_pixel : 1'b0;
    end

    reg href_new;
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) 
            href_new <= 1'b0;
        else
            href_new <= href_i;
    end  

    reg odd_line;
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) 
            odd_line <= 1'b0;
        else if(vsync_i)
            odd_line <= 1'b0;
        else if(href_i & ~(href_new))
            odd_line <= ~odd_line;
    end

    // bayer format judgment判断当前pixel为何种类型
    wire [1:0] pixelFormat = bayerFormat[1:0] ^ {odd_line, odd_pixel};

    // 提取感受野中与当前format一致的pixel（5*5感受野中为8个）,！！！GR与GB会在该步骤进行混合，当提取GR时会提取感受野中4个GR与4个GB
    reg [bits-1 : 0] SFP00, SFP01, SFP02;                                                              // same format piexl
    reg [bits-1 : 0] SFP10, SFP11, SFP12;
    reg [bits-1 : 0] SFP20, SFP21, SFP22;
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            SFP00 <= {bits{1'b0}}; SFP01 <= {bits{1'b0}}; SFP02 <= {bits{1'b0}};
            SFP10 <= {bits{1'b0}}; SFP11 <= {bits{1'b0}}; SFP12 <= {bits{1'b0}};
            SFP20 <= {bits{1'b0}}; SFP21 <= {bits{1'b0}}; SFP22 <= {bits{1'b0}};
        end else begin
            case (pixelFormat)
                2'b00, 2'b11 : begin                                                                   // Bug！！！
                    SFP00 <= RF00; SFP01 <= RF02; SFP02 <= RF04;
                    SFP10 <= RF20; SFP11 <= RF22; SFP12 <= RF24;
                    SFP20 <= RF40; SFP21 <= RF42; SFP22 <= RF44;
                end
                2'b01, 2'b10 : begin
                    SFP00 <= RF11; SFP01 <= RF02; SFP02 <= RF13;
                    SFP10 <= RF20; SFP11 <= RF22; SFP12 <= RF24;
                    SFP20 <= RF31; SFP21 <= RF42; SFP22 <= RF33;
                end
                default : begin
                    SFP00 <= {bits{1'b0}}; SFP01 <= {bits{1'b0}}; SFP02 <= {bits{1'b0}};
                    SFP10 <= {bits{1'b0}}; SFP11 <= {bits{1'b0}}; SFP12 <= {bits{1'b0}};
                    SFP20 <= {bits{1'b0}}; SFP21 <= {bits{1'b0}}; SFP22 <= {bits{1'b0}};
                end
            endcase
        end
    end

    // 滤波阶段，可选择：1、均值滤波 2、中值滤波 3、梯度矫正法 为快速搭建此处仅使用均值滤波
    wire [bits*2-1 : 0] pixelSum = (SFP00 + SFP01 + SFP02 + SFP10 + SFP12 + SFP20 + SFP21 + SFP22) >> 3;

    reg [bits-1 : 0] pixelMean;
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            pixelMean <= {bits{1'b0}};
        end else begin
            pixelMean <= pixelSum;
        end
    end 

    // 滤波与坏点检测是并行的，因此需要将滤波数据同步到坏点检测时序中
    reg [bits-1 : 0] pixelMean_reg [2:0];
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            pixelMean_reg[0] <= {bits{1'b0}};
            pixelMean_reg[1] <= {bits{1'b0}};
            pixelMean_reg[2] <= {bits{1'b0}};
        end else begin
            pixelMean_reg[0] <= pixelMean;
            pixelMean_reg[1] <= pixelMean_reg[0];
            pixelMean_reg[2] <= pixelMean_reg[1];
        end
    end

    // 坏点检测
    /* 步骤：
     * 1、将感受野中pixel转为有符号数
     * 2、分别计算中心像素与周围八个像素值的差
     * 3、判断差值是否都为相同符号，并计算差值绝对值
     * 4、判断差值绝对值是否超出阈值
     * 5、判断坏点是否成立，对坏点进行像素值取代
     * 将其做成五级pipeline
    */
    // 数据类型转换 
    // verilog-2001提出了可综合的有符号reg与wire
    reg signed [bits : 0] SSFP00, SSFP01, SSFP02;                                                 // singed same format pixel
    reg signed [bits : 0] SSFP10, SSFP11, SSFP12;
    reg signed [bits : 0] SSFP20, SSFP21, SSFP22;
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            SSFP00 <= {bits+1{1'b0}}; SSFP01 <= {bits+1{1'b0}}; SSFP02 <= {bits+1{1'b0}};
            SSFP10 <= {bits+1{1'b0}}; SSFP11 <= {bits+1{1'b0}}; SSFP12 <= {bits+1{1'b0}};
            SSFP20 <= {bits+1{1'b0}}; SSFP21 <= {bits+1{1'b0}}; SSFP22 <= {bits+1{1'b0}};
        end else begin
            SSFP00 <= {1'b0, SFP00}; SSFP01 <= {1'b0, SFP01}; SSFP02 <= {1'b0, SFP02};
            SSFP10 <= {1'b0, SFP10}; SSFP11 <= {1'b0, SFP11}; SSFP12 <= {1'b0, SFP12};
            SSFP20 <= {1'b0, SFP20}; SSFP21 <= {1'b0, SFP21}; SSFP22 <= {1'b0, SFP22};
        end
    end

    // 差值计算
    reg signed [bits : 0] DIFF [7 : 0];
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            DIFF[0] <= {bits+1{1'b0}};
            DIFF[1] <= {bits+1{1'b0}};
            DIFF[2] <= {bits+1{1'b0}};
            DIFF[3] <= {bits+1{1'b0}};
            DIFF[4] <= {bits+1{1'b0}};
            DIFF[5] <= {bits+1{1'b0}};
            DIFF[6] <= {bits+1{1'b0}};
            DIFF[7] <= {bits+1{1'b0}};
        end else begin
            DIFF[0] <= SSFP11 - SSFP00;
            DIFF[1] <= SSFP11 - SSFP01;
            DIFF[2] <= SSFP11 - SSFP02;
            DIFF[3] <= SSFP11 - SSFP10;
            DIFF[4] <= SSFP11 - SSFP12;
            DIFF[5] <= SSFP11 - SSFP20;
            DIFF[6] <= SSFP11 - SSFP21;
            DIFF[7] <= SSFP11 - SSFP22; 
        end
    end

    // 绝对值计算
    reg [bits-1 : 0] DIFF_abs [7 : 0];
    reg DIFF_sameSymbol;

    wire [7:0] DIFF_symbol = {DIFF[0][bits], DIFF[1][bits], DIFF[2][bits], DIFF[3][bits], DIFF[4][bits], DIFF[5][bits], DIFF[6][bits], DIFF[7][bits]};     // 多维索引在verilog中已经支持，可不可综合未知
    
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            DIFF_sameSymbol <= 1'b0;
            DIFF_abs[0] <= {bits{1'b0}};
            DIFF_abs[1] <= {bits{1'b0}};
            DIFF_abs[2] <= {bits{1'b0}};
            DIFF_abs[3] <= {bits{1'b0}};
            DIFF_abs[4] <= {bits{1'b0}};
            DIFF_abs[5] <= {bits{1'b0}};
            DIFF_abs[6] <= {bits{1'b0}};
            DIFF_abs[7] <= {bits{1'b0}};
        end else begin
            DIFF_sameSymbol <= &DIFF_symbol || &(~DIFF_symbol);
            DIFF_abs[0] <= DIFF[0][bits] ? (1'sb0 - DIFF[0]) : DIFF[0];                                     // 自动截位
            DIFF_abs[1] <= DIFF[1][bits] ? (1'sb0 - DIFF[1]) : DIFF[1];
            DIFF_abs[2] <= DIFF[2][bits] ? (1'sb0 - DIFF[2]) : DIFF[2];
            DIFF_abs[3] <= DIFF[3][bits] ? (1'sb0 - DIFF[3]) : DIFF[3];
            DIFF_abs[4] <= DIFF[4][bits] ? (1'sb0 - DIFF[4]) : DIFF[4];
            DIFF_abs[5] <= DIFF[5][bits] ? (1'sb0 - DIFF[5]) : DIFF[5];
            DIFF_abs[6] <= DIFF[6][bits] ? (1'sb0 - DIFF[6]) : DIFF[6];
            DIFF_abs[7] <= DIFF[7][bits] ? (1'sb0 - DIFF[7]) : DIFF[7];
        end
    end

    // 判断是否超出阈值
    reg isBad;
    reg [bits-1 : 0] overflow;

    generate
        genvar i;
        for (i = 0; i < bits; i = i + 1) begin
            assign overflow[i] = DIFF_abs[i] > threshold_i;
        end
    endgenerate 

    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            isBad <= 1'b0;
        end else begin
            isBad <= |overflow;
        end
    end

    //
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            pixel_i_reg[1] <= {bits{1'b0}};
            pixel_i_reg[2] <= {bits{1'b0}};
            pixel_i_reg[3] <= {bits{1'b0}};
            pixel_i_reg[4] <= {bits{1'b0}};
            pixel_i_reg[5] <= {bits{1'b0}};
            pixel_i_reg[6] <= {bits{1'b0}};
        end else begin
            pixel_i_reg[1] <= pixel_i_reg[0];
            pixel_i_reg[2] <= pixel_i_reg[1];
            pixel_i_reg[3] <= pixel_i_reg[2];
            pixel_i_reg[4] <= pixel_i_reg[3];
            pixel_i_reg[5] <= pixel_i_reg[4];
            pixel_i_reg[6] <= pixel_i_reg[5];
        end
    end

    // 像素替换
    reg [bits-1 : 0] pixelNew;
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            pixelNew <= {bits{1'b0}};
        end else begin
            pixelNew <= isBad ? pixelMean_reg[2] : pixel_i_reg[6];
        end
    end

endmodule
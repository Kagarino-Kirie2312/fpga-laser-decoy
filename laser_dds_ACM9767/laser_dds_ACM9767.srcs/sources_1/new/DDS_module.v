`timescale 1ns / 1ps
module DDS_module(
clk,
reset_n,
mode_sel,
fword,
pword,
data
    );
input clk;
input reset_n;
input mode_sel; //模式选择。2位信号，用于选择输出波形类型：0-正弦波，1-方波，2-三角波，3-直流电平（固定值8192）
input [31:0] fword; //频率控制字。32位宽，用于控制输出信号的频率。其值与系统时钟和相位累加器位数共同决定输出频率。
input [16:0] pword; //相位控制字。12位宽，用于调整输出信号的初始相位，与累加器的高位相加后作为ROM的地址。
output data;

reg [13:0] data;

//频率控制字同步寄存器 将输入的频率控制字fword同步到时钟域中。
reg [31:0] fword_r; 
always@(posedge clk) 
fword_r <= fword; 

//相位控制字同步寄存器 将输入的相位控制字pword同步到时钟域
reg [16:0] pword_r; 
always@(posedge clk) 
    pword_r <= pword; 

//相位累加器     将频率控制字fword_r与当前的累加值freq_acc相加
//新相位 = 老相位 + 频率控制字
reg [31:0]freq_acc; 

always@(posedge clk or negedge reset_n) 
if(!reset_n) 
    freq_acc <= 0; 
else 
    freq_acc <= fword_r + freq_acc; 

//波形数据表地址 
//取出高12位（位31到20），并与相位控制字pword_r相加，生成12位的ROM地址rom_addr。这12位地址对应一个完整周期内4096个采样点中的一个
//只保留了相位信息中最重要的部分，舍弃了低20位的细节
//freq_acc决定了相位变化，pword_r决定了初相或者说相位偏移
reg [16:0]rom_addr;   
wire [16:0]rom_addr_tmp;    

assign rom_addr_tmp = freq_acc[31:15] + pword_r; 

always @(posedge clk) begin
    if (rom_addr_tmp < 92480)
        rom_addr <= rom_addr_tmp;      // 有效区域：0 ~ 92479
    else
        rom_addr <= rom_addr_tmp - 92480;  // 回绕到开头
end

wire [13:0] data_dac;      // 正弦波数据

blk_mem_gen_0 blk_mem_gen_0 (
    .clka(clk),              // input clka
    .addra(rom_addr),        // input [11:0] addra
    .douta(data_dac)        // output [13:0] douta
);

//TTL TTL (
//    .clka(clk),              // input clka
//    .addra(rom_addr),        // input [11:0] addra
//    .douta(data_dac)        // output [13:0] douta
//);

always@(*) begin
    case(mode_sel) 
        0: data = data_dac;     // 正弦波
        1: data = 8192;         // 直流中点（方波/其他模式暂时固定为0V）
        default: data = data_dac;
    endcase 
end 

endmodule

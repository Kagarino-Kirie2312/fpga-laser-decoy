`timescale 1ns / 1ps
module ACM9767_DDS(
clk,
reset_n,
dataa,
clka,
wrta
    );
input clk;
input reset_n;
output [13:0] dataa;
output clka;
output wrta;

    wire clk125M;
    assign clka = clk125M;
    assign wrta = clka;
    
    reg [1:0] mode_sela;
    
    wire cha_fword_flag; //调节ACM9767通道1的输出频率，可依次在1Hz，10Hz，100Hz，1kHz，10kHz，100kHz，1MHz，10MHz频率中切换 
    wire cha_pword_flag; //调节通道1输出信号相位，可依次在0°，30°，60°，90°，150°，180°，270°，320°中切换
    wire mode_sela_flag; //控制通道1输出的波形，依次在正弦波、方波、三角波、直线中切换
 
vio_0 vio_0 (
      .clk(clk125M),                // input wire clk
      .probe_out0(cha_fword_flag),  // output wire [0 : 0] probe_out0
      .probe_out1(cha_pword_flag),  // output wire [0 : 0] probe_out1
      .probe_out2(mode_sela_flag)  // output wire [0 : 0] probe_out2
    );
 
    //对flag信号打两拍，用于上升沿检测 
    reg cha_fword_flag_reg0,cha_fword_flag_reg1; 
    reg cha_pword_flag_reg0,cha_pword_flag_reg1; 
    reg mode_sela_flag_reg0,mode_sela_flag_reg1; 
 
    always@(posedge clk125M or negedge reset_n)     
    if(!reset_n)begin 
        cha_fword_flag_reg0 <= 0; 
        cha_fword_flag_reg1 <= 0; 
    end 
    else begin 
        cha_fword_flag_reg0 <= cha_fword_flag; 
        cha_fword_flag_reg1 <= cha_fword_flag_reg0; 
    end 
 
    always@(posedge clk125M or negedge reset_n)     
    if(!reset_n)begin 
        cha_pword_flag_reg0 <= 0; 
        cha_pword_flag_reg1 <= 0; 
    end 
    else begin 
        cha_pword_flag_reg0 <= cha_pword_flag; 
        cha_pword_flag_reg1 <= cha_pword_flag_reg0; 
    end    
 
    always@(posedge clk125M or negedge reset_n)     
    if(!reset_n)begin 
        mode_sela_flag_reg0 <= 0; 
        mode_sela_flag_reg1 <= 0; 
    end 
    else begin     
        mode_sela_flag_reg0 <= mode_sela_flag; 
        mode_sela_flag_reg1 <= mode_sela_flag_reg0; 
    end        
 
 
    wire cha_fword_posedge; 
    wire cha_pword_posedge; 
    wire mode_sela_posedge; 
    //上升沿检测    
    assign cha_fword_posedge = (!cha_fword_flag_reg1) & cha_fword_flag_reg0; 
    assign cha_pword_posedge = (!cha_pword_flag_reg1) & cha_pword_flag_reg0; 
    assign mode_sela_posedge = (!mode_sela_flag_reg1) & mode_sela_flag_reg0; 
    
    reg [2:0] cha_fword_sel;
    reg [2:0] cha_pword_sel;
    
    //`define sim
    
    always@(posedge clk125M or negedge reset_n)     
    if(!reset_n) 
        `ifdef sim
            cha_fword_sel <= 4; //仿真时用
        `else
            cha_fword_sel <= 0; //板级验证时启用 
        `endif
    else if(cha_fword_posedge) 
        cha_fword_sel <= cha_fword_sel + 1'd1; 
    else 
        cha_fword_sel <= cha_fword_sel; 
         
 
    always@(posedge clk125M or negedge reset_n)     
    if(!reset_n) 
        cha_pword_sel <= 0;//板级验证时使用 
    else if(cha_pword_posedge) 
        cha_pword_sel <= cha_pword_sel + 1'd1; 
    else 
        cha_pword_sel <= cha_pword_sel; 
         
         
    always@(posedge clk125M or negedge reset_n)     
    if(!reset_n) 
        mode_sela <= 0; 
    else if(mode_sela_posedge) 
        mode_sela <= mode_sela + 1'd1; 
    else 
        mode_sela <= mode_sela; 
         
    
    reg [31:0] fworda;
    reg [16:0] pworda;
    /*如果把周期完整的一个波形等分成2的32次方份，那么如果希望1秒钟输出一个完成的周期，每一拍递进多少份？*/ 
    //这些数值是根据公式 2^32 ×(目标频率 / 时钟频率) 计算得出的
    always@(*) 
        case(cha_fword_sel) 
            0:fworda = 4;//2**32 / 125000000; 1Hz
            1:fworda = 344;//2**32 / 12500000; 10Hz
            2:fworda = 3436;//2**32 / 1250000; 
            3:fworda = 34360;//2**32 / 125000; 
            4:fworda = 343597;//2**32 / 12500; 
            5:fworda = 3435974;//2**32 / 1250; 
            6:fworda = 34359738;//2**32 / 125; 
            7:fworda = 343597384;//2**32 / 12.5; 
        endcase 
         
//相位角度?360*4096
    always@(*) 
        case(cha_pword_sel) 
            0:pworda = 0;   //0 
            1:pworda = 7707; //30 
            2:pworda = 15413; //60 
            3:pworda = 23120; //90 
            4:pworda = 38533; //150 
            5:pworda = 46240; //180 
            6:pworda = 69360; //270 
            7:pworda = 82204; //320 
        endcase  

//ila_0 ila_0 (
//    .clk(clk), // input wire clk
//    .probe0(dataa), // input wire [13:0] probe0
//    .probe1(datab) // input wire [13:0]  probe1
//);

MMCM MMCM(
    .clk_out1(clk125M),     // output clk_out1
    .resetn(reset_n), // input resetn
    .locked(),       // output locked
    .clk_in1(clk)
    );      // input clk_in1

DDS_module DDS_module(
    .clk(clk125M),
    .reset_n(reset_n),
    .mode_sel(mode_sela),
    .fword(fworda),
    .pword(pworda),
    .data(dataa)
    );

endmodule

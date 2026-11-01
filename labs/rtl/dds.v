// ============================================================================
//  Lab 10  DDS（直接数字频率合成）—— 发射端波形发生
//  学到：① 相位累加器：每个时钟加一次频率控制字 fword，相当于相位以
//           fword/2^PHASE_W 圈/拍增长
//        ② 取相位累加器的高位做 ROM 地址（截断低位 = 相位截断，省 ROM）
//        ③ 输出频率公式： f_out = fword × f_clk / 2^PHASE_W
//           频率分辨率   = f_clk / 2^PHASE_W（32 位时可达毫赫兹级）
//  对应项目：deck p15/p16（32 位累加器 + 12 位 ROM 地址 + 4096 点）
//
//  注意：这里的正弦表用 case 直接写成 16 项（可综合）。
//        真实工程用 ROM IP 核 + .coe 初始化文件（4096 点），
//        因为 case 表写 4096 项不现实。原理完全一样。
// ============================================================================
`timescale 1ns/1ps

module dds #(
  parameter integer PHASE_W = 16,   // 相位累加器位宽
  parameter integer ADDR_W  = 4,    // ROM 地址位宽（=2^4=16 个点）
  parameter integer DATA_W  = 8     // 输出数据位宽
)(
  input  wire                    clk,
  input  wire                    rst_n,
  input  wire [PHASE_W-1:0]      fword,   // 频率控制字
  output reg  [DATA_W-1:0]       dout
);

  reg [PHASE_W-1:0] acc;

  // 取累加器的高 ADDR_W 位作为 ROM 地址（高位代表相位，低位是精度）
  wire [ADDR_W-1:0] addr = acc[PHASE_W-1 -: ADDR_W];

  // 16 点正弦表：0~255 对应 sin 的 -1~+1（中点 128）
  function [DATA_W-1:0] sine_lut;
    input [ADDR_W-1:0] a;
    begin
      case (a)
        4'd0:  sine_lut = 8'd128;
        4'd1:  sine_lut = 8'd177;
        4'd2:  sine_lut = 8'd218;
        4'd3:  sine_lut = 8'd245;
        4'd4:  sine_lut = 8'd255;
        4'd5:  sine_lut = 8'd245;
        4'd6:  sine_lut = 8'd218;
        4'd7:  sine_lut = 8'd177;
        4'd8:  sine_lut = 8'd128;
        4'd9:  sine_lut = 8'd79;
        4'd10: sine_lut = 8'd38;
        4'd11: sine_lut = 8'd11;
        4'd12: sine_lut = 8'd0;
        4'd13: sine_lut = 8'd11;
        4'd14: sine_lut = 8'd38;
        4'd15: sine_lut = 8'd79;
        default: sine_lut = 8'd128;
      endcase
    end
  endfunction

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      acc  <= 0;
      dout <= 8'd128;
    end
    else begin
      acc  <= acc + fword;          // 相位累加 —— DDS 的核心就这一行
      dout <= sine_lut(addr);
    end
  end

endmodule

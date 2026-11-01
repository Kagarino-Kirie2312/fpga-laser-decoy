// ============================================================================
//  Lab 2  边沿检测（打两拍同步 + 上升/下降沿）
//  学到：异步输入必须先同步（消亚稳态），再检测边沿；
//        "打三拍" = 2 级同步 + 1 级延迟用于比较。
//  对应项目：deck p18 的 VIO 按键、deck p26 的 uart_rx 打 3 拍（同一套路）
// ============================================================================
`timescale 1ns/1ps

module edge_detect (
  input  wire clk,
  input  wire rst_n,
  input  wire async_in,     // 相对 clk 异步，例如按键、外部串口线
  output wire level_sync,   // 同步后的电平
  output wire rise,         // 上升沿，宽度 = 1 个 clk
  output wire fall          // 下降沿，宽度 = 1 个 clk
);

  // 3 级移位：前 2 级负责同步，第 3 级用于和上一拍比较
  reg [2:0] sync;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) sync <= 3'b000;
    else        sync <= {sync[1:0], async_in};
  end

  assign level_sync = sync[2];
  assign rise = (sync[2:1] == 2'b01);   // 上一拍 0、这一拍 1
  assign fall = (sync[2:1] == 2'b10);   // 上一拍 1、这一拍 0

endmodule

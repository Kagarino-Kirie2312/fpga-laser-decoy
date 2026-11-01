// ============================================================================
//  Lab 3  按键消抖
//  学到：机械按键会抖动几十毫秒，必须"连续 N 个时钟稳定"才认可；
//        注意这里仍然先把按键打两拍同步，再做计数确认。
//  对应项目：deck 里没有专门的消抖模块（VIO 是虚拟按键，不抖），
//            但真实板子上按键进 FPGA 一定要消抖。
// ============================================================================
`timescale 1ns/1ps

module debounce #(
  parameter integer N = 20        // 连续多少个时钟稳定才认可
)(
  input  wire clk,
  input  wire rst_n,
  input  wire key_in,             // 按键原始输入（低有效）
  output reg  key_out             // 消抖后的电平
);

  reg [1:0]  sync;                // 2 级同步
  reg [15:0] cnt;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sync    <= 2'b11;           // 按键低有效，空闲给高
      cnt     <= 16'd0;
      key_out <= 1'b1;
    end
    else begin
      sync <= {sync[0], key_in};  // 打两拍

      if (sync[1] == key_out) begin
        cnt <= 16'd0;             // 和当前输出一致 -> 不需要改变
      end
      else if (cnt == N - 1) begin
        cnt     <= 16'd0;
        key_out <= sync[1];       // 稳定够久了 -> 认可新电平
      end
      else begin
        cnt <= cnt + 1'b1;
      end
    end
  end

endmodule

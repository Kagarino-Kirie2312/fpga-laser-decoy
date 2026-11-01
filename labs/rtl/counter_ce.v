// ============================================================================
//  Lab 1  计数器 / 时钟使能
//  学到：FPGA 里没有"延时函数"，只有"数够多少个时钟"；
//        降速要用「时钟使能」而不是分频出一个新时钟（见自查手册 坑 9）。
//  对应项目：激光诱偏 deck p15 的 50MHz -> 10MHz（那里用了 MMCM，这里是最简版）
// ============================================================================
`timescale 1ns/1ps

module counter_ce #(
  parameter integer CLK_HZ = 50_000_000,   // 输入时钟频率
  parameter integer OUT_HZ = 1             // 期望的使能频率
)(
  input  wire clk,
  input  wire rst_n,
  output reg  ce          // 每个 OUT_HZ 周期内，只有 1 个 clk 周期为高
);

  // 先算除法，再定位宽：DIV 最大 5e7，需要 26 位以上，这里给 32 位保险
  localparam integer DIV = CLK_HZ / OUT_HZ;   // 多少个时钟来一次使能

  reg [31:0] cnt;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cnt <= 32'd0;
      ce  <= 1'b0;
    end
    else if (cnt == DIV - 1) begin
      cnt <= 32'd0;
      ce  <= 1'b1;          // 只拉高一个周期
    end
    else begin
      cnt <= cnt + 1'b1;
      ce  <= 1'b0;
    end
  end

endmodule

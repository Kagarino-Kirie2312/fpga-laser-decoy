// ============================================================================
//  Lab 9  m 序列 / Gold 码生成
//  学到：① LFSR 的输出位 = 移位前的最低位；反馈 = 抽头位异或，补到最高位
//        ② ★抽头位号约定极易写错★：本模块用 0-indexed，且反馈补到最高位。
//           这个约定下 x^5+x^2+1 -> 5'b00101(0,2)；x^5+x^3+1 -> 5'b01001(0,3)
//           如果误按"1-indexed 取高位"写，周期会从 31 塌缩到 2，根本得不到 m 序列！
//        ③ Gold 码 = 两个 m 序列逐位异或
//  对应项目：deck p8（两个多项式、抽头位、Gold 码生成）
//
//  本模块把两条 m 序列和它们的异或都输出成 31 位并行值，方便测试台做相关运算。
// ============================================================================
`timescale 1ns/1ps

module gold_code #(
  parameter [4:0] TAPS_A = 5'b00101,   // x^5+x^2+1  (抽头 0,2)  = octal 45
  parameter [4:0] TAPS_B = 5'b01001,   // x^5+x^3+1  (抽头 0,3)  = octal 51
  parameter [4:0] SEED   = 5'b00001
)(
  input  wire clk,
  input  wire rst_n,
  input  wire en,          // 置 1 开始产生序列
  output reg  [30:0] seq_a,
  output reg  [30:0] seq_b,
  output reg  [30:0] gold,
  output reg         valid  // 31 位都出齐后拉高
);

  // ---- 两条 LFSR ----
  reg [4:0] sr_a, sr_b;
  wire fb_a = ^(sr_a & TAPS_A);     // 抽头位异或
  wire fb_b = ^(sr_b & TAPS_B);

  reg [4:0] idx;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sr_a  <= SEED;
      sr_b  <= SEED;
      idx   <= 5'd0;
      seq_a <= 31'd0;
      seq_b <= 31'd0;
      gold  <= 31'd0;
      valid <= 1'b0;
    end
    else if (en) begin
      if (idx < 5'd31) begin
        // 先记录当前最低位（这就是序列的第 idx 个码片）
        seq_a[idx] <= sr_a[0];
        seq_b[idx] <= sr_b[0];
        gold[idx]  <= sr_a[0] ^ sr_b[0];
        // 再移位：反馈补进最高位
        sr_a <= {fb_a, sr_a[4:1]};
        sr_b <= {fb_b, sr_b[4:1]};
        idx  <= idx + 1'b1;
        if (idx == 5'd30) valid <= 1'b1;
      end
    end
  end

endmodule

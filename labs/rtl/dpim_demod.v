// ============================================================================
//  Lab 11b  DPIM 解调器（两种判决方式，用来对比）
//  学到：① 解调 = 数两个脉冲之间有多少个 0，再换算成符号
//        ② ★判决门限必须居中★ 这是本实验的核心：
//           MODE=0 复刻 deck p32 的写法： slots = gap/10; sym = slots/2 - 1
//           MODE=1 改良版：把门限放到相邻标称间隔的中点（30/50/70）
//        ③ 顺带体现"FPGA 里除法很贵"：MODE=0 需要一个除法器，
//           MODE=1 只要三个比较器，而且更鲁棒
//  对应项目：deck p32（那里用 gap/10 与 (gap/10)/2-1）
//
//  判决区间对照（SLOT=10，标称间隔 20/40/60/80）：
//    gap      19  20  29 | 30  39 | 40  49 | 50  59 | 60  69 | 70  79 | 80
//    MODE=0   非法  0   0 |  0   0 |  1   1 |  1   1 |  2   2 |  2   2 |  3
//    MODE=1     0   0   0 |  1   1 |  1   1 |  2   2 |  2   2 |  3   3 |  3
//  → MODE=0 的每个符号判决下界正好压在标称间隔上，负向裕量为 0
// ============================================================================
`timescale 1ns/1ps

module dpim_demod #(
  parameter integer SLOT = 10,
  parameter integer MODE = 0        // 0 = deck 原版（整除）  1 = 门限居中
)(
  input  wire       clk,
  input  wire       rst_n,
  input  wire       din,            // 0/1 采样流
  output reg  [1:0] sym,            // 解出的符号
  output reg        sym_valid,      // 单周期脉冲：sym 有效
  output reg        out_of_range    // 间隔落到了非法区间
);

  reg        started;
  reg [15:0] cnt;
  integer    slots, s;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      started      <= 1'b0;
      cnt          <= 16'd0;
      sym          <= 2'd0;
      sym_valid    <= 1'b0;
      out_of_range <= 1'b0;
    end
    else begin
      sym_valid <= 1'b0;            // 默认拉低

      if (din) begin
        if (started) begin
          // 数到了两个 1 之间的 0 个数 = 一个 DPIM 间隔
          if (MODE == 0) begin
            // ---- deck 原版：整除判决 ----
            // 注意这一句在综合时会生成一个除法器（除数 10 不是 2 的幂）
            slots = cnt / SLOT;
            s     = slots / 2 - 1;          // 可能是 -1（非法）
            if (s >= 0 && s <= 3) begin
              sym          <= s;            // 截断到 2 位，s 在 0~3 内安全
              out_of_range <= 1'b0;
            end
            else begin
              sym          <= 2'd0;
              out_of_range <= 1'b1;         // gap=19 -> slots=1 -> s=-1
            end
          end
          else begin
            // ---- 改良版：门限居中（三个比较器）----
            if (cnt < 15) begin
              sym <= 2'd0; out_of_range <= 1'b1;      // 明显损坏
            end
            else if (cnt < 30) begin
              sym <= 2'd0; out_of_range <= 1'b0;
            end
            else if (cnt < 50) begin
              sym <= 2'd1; out_of_range <= 1'b0;
            end
            else if (cnt < 70) begin
              sym <= 2'd2; out_of_range <= 1'b0;
            end
            else begin
              sym <= 2'd3; out_of_range <= 1'b0;
            end
          end
          sym_valid <= 1'b1;
        end
        started <= 1'b1;
        cnt     <= 16'd0;
      end
      else begin
        cnt <= cnt + 1'b1;
      end
    end
  end

endmodule

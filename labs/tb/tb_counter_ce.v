// ============================================================================
//  tb: counter_ce  —— 自检测试台
//  检查：① ce 每 DIV 个时钟出现一次（间隔准确）
//        ② ce 的高电平只持续 1 个时钟（宽度准确）
//  技巧：把 CLK_HZ 传成很小的值，仿真才能秒出结果（真实 50MHz 要跑很久）
// ============================================================================
`timescale 1ns/1ps

module tb_counter_ce;

  localparam integer DIV = 10;      // 仿真里用 10 个时钟一次，而不是 5000 万个

  reg  clk = 0;
  reg  rst_n = 0;
  wire ce;

  counter_ce #(.CLK_HZ(DIV), .OUT_HZ(1)) dut (.clk(clk), .rst_n(rst_n), .ce(ce));

  always #5 clk = ~clk;             // 10 ns 周期

  integer cyc = 0, seen = 0, prev = -1, gap_err = 0, width_err = 0, run = 0;

  always @(posedge clk) begin
    cyc = cyc + 1;
    if (ce) begin
      if (run > 0) width_err = 1;                   // 上个时钟也是高 -> 宽度 > 1
      run  = 1;
      seen = seen + 1;
      if (prev >= 0 && (cyc - prev) != DIV) gap_err = 1;
      prev = cyc;
    end
    else begin
      run = 0;
    end
  end

  initial begin
    $dumpfile("tb_counter_ce.vcd");
    $dumpvars(0, tb_counter_ce);

    #20 rst_n = 1;                                  // 释放复位
    repeat (DIV * 20) @(posedge clk);               // 观察 20 个输出周期

    $display("  ce 出现次数 = %0d（期望 19~20）", seen);
    $display("  间隔错误 = %0d，宽度错误 = %0d（都应为 0）", gap_err, width_err);

    if (seen >= 19 && gap_err == 0 && width_err == 0)
      $display("PASS tb_counter_ce");
    else
      $display("FAIL tb_counter_ce");

    $finish;
  end

endmodule

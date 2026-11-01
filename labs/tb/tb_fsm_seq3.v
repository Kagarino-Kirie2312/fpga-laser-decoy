// ============================================================================
//  tb: fsm_seq3  —— 自检测试台
//  检查：每按 3 次 led 翻转一次（按 2 次不能翻）
//
//  ★ 重要技巧：激励在 **negedge** 驱动，不在 posedge 驱动。
//    如果写 `@(posedge clk); press = 1;`，这条赋值和 DUT 里
//    `always @(posedge clk)` 的采样发生在同一个时间步，谁先谁后是**不确定**的
//    （仿真器之间、甚至两次运行之间都可能不同）。结果 press 有时被采到 1 拍、
//    有时被采到 2 拍 —— 我第一版就是这么挂的：FSM 本身没问题，
//    但第 2 次按键就被算成第 3 次，测试台报"按 2 次就翻转了"。
//    正确做法：在 negedge 改变激励，离 posedge 半个周期，彻底避开竞争。
// ============================================================================
`timescale 1ns/1ps

module tb_fsm_seq3;

  reg  clk = 0;
  reg  rst_n = 0;
  reg  press = 0;
  wire led;
  wire [1:0] state_dbg;

  fsm_seq3 dut (.clk(clk), .rst_n(rst_n), .press(press),
                .led(led), .state_dbg(state_dbg));

  always #5 clk = ~clk;

  // 一次按键：一个干净的单周期脉冲（在 negedge 驱动，避开 posedge 竞争）
  task do_press;
    begin
      @(negedge clk); press = 1;
      @(negedge clk); press = 0;
      repeat (2) @(negedge clk);
    end
  endtask

  integer errs = 0;

  initial begin
    $dumpfile("tb_fsm_seq3.vcd");
    $dumpvars(0, tb_fsm_seq3);

    #20 rst_n = 1;
    repeat (2) @(negedge clk);

    // ---- 第 1 次：不应翻转 ----
    do_press;
    if (led !== 1'b0) begin errs = errs + 1; $display("  x 按 1 次就翻转了"); end

    // ---- 第 2 次：仍不应翻转（最容易写错的边界）----
    do_press;
    if (led !== 1'b0) begin errs = errs + 1; $display("  x 按 2 次就翻转了（边界写错）"); end

    // ---- 第 3 次：应该翻转成 1 ----
    do_press;
    repeat (2) @(negedge clk);
    if (led !== 1'b1) begin errs = errs + 1; $display("  x 按 3 次没有翻转"); end

    // ---- 再按 3 次：应该翻转回 0 ----
    do_press; do_press; do_press;
    repeat (2) @(negedge clk);
    if (led !== 1'b0) begin errs = errs + 1; $display("  x 第 6 次后没有翻回来"); end

    $display("  错误数 = %0d", errs);
    if (errs == 0) $display("PASS tb_fsm_seq3");
    else           $display("FAIL tb_fsm_seq3");

    $finish;
  end

endmodule

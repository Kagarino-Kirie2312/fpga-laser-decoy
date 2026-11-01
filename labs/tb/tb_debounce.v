// ============================================================================
//  tb: debounce  —— 自检测试台
//  检查：① 按键抖动期间，消抖输出不能被误触发（这是消抖的意义）
//        ② 稳定按住之后，输出必须跟随
// ============================================================================
`timescale 1ns/1ps

module tb_debounce;

  localparam integer N = 4;         // 仿真里用 4 个时钟，真实板子要几百个

  reg  clk = 0;
  reg  rst_n = 0;
  reg  key_in = 1;                  // 按键低有效，空闲为高
  wire key_out;

  debounce #(.N(N)) dut (.clk(clk), .rst_n(rst_n), .key_in(key_in), .key_out(key_out));

  always #5 clk = ~clk;

  integer false_trig = 0;
  reg watch = 0;

  always @(posedge clk)
    if (watch && (key_out !== 1'b1)) false_trig = false_trig + 1;

  initial begin
    $dumpfile("tb_debounce.vcd");
    $dumpvars(0, tb_debounce);

    #20 rst_n = 1;
    repeat (4) @(posedge clk);

    // ---- 抖动窗口：0/1 快速交替（每次只持续 1 个时钟）----
    // 注意 watch 必须在"抖动窗口结束时"立刻关掉，
    // 否则后面"真正按住"期间 key_out 合法地变成 0，也会被算成误触发。
    watch = 1;
    #2 key_in = 0;  #10 key_in = 1;  #10 key_in = 0;
    #10 key_in = 1; #10 key_in = 0;
    watch = 0;                      // 抖动窗口到此结束，之后是稳定按住

    // ---- 然后真正按住不放 ----
    repeat (16) @(posedge clk);

    $display("  抖动期间误触发次数 = %0d（应为 0）", false_trig);
    $display("  稳定按住后 key_out = %0b（应为 0）", key_out);

    if (false_trig == 0 && key_out === 1'b0)
      $display("PASS tb_debounce");
    else
      $display("FAIL tb_debounce");

    $finish;
  end

endmodule

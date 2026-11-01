// ============================================================================
//  tb: edge_detect  —— 自检测试台
//  检查：① 每次输入跳变只产生 1 个 rise / 1 个 fall 脉冲
//        ② 同步后的电平最终与输入一致（有 2~3 拍延迟，属正常）
//        ③ rise 和 fall 不会同时为高
//  注意：激励故意在时钟沿之后才变化，模拟真实的异步输入
// ============================================================================
`timescale 1ns/1ps

module tb_edge_detect;

  reg  clk = 0;
  reg  rst_n = 0;
  reg  async_in = 0;
  wire level_sync, rise, fall;

  edge_detect dut (.clk(clk), .rst_n(rst_n), .async_in(async_in),
                   .level_sync(level_sync), .rise(rise), .fall(fall));

  always #5 clk = ~clk;

  integer n_rise = 0, n_fall = 0, both = 0;

  always @(posedge clk) begin
    if (rise) n_rise = n_rise + 1;
    if (fall) n_fall = n_fall + 1;
    if (rise && fall) both = both + 1;
  end

  initial begin
    $dumpfile("tb_edge_detect.vcd");
    $dumpvars(0, tb_edge_detect);

    #20 rst_n = 1;
    @(posedge clk);

    // 3 次跳变：0->1, 1->0, 0->1
    #2 async_in = 1;  repeat (6) @(posedge clk);
    #2 async_in = 0;  repeat (6) @(posedge clk);
    #2 async_in = 1;  repeat (6) @(posedge clk);

    $display("  rise 次数 = %0d（期望 2），fall 次数 = %0d（期望 1）", n_rise, n_fall);
    $display("  同步后电平 = %0b（输入当前为 %0b）", level_sync, async_in);
    $display("  rise/fall 同时为高 = %0d（应为 0）", both);

    if (n_rise == 2 && n_fall == 1 && both == 0 && level_sync == async_in)
      $display("PASS tb_edge_detect");
    else
      $display("FAIL tb_edge_detect");

    $finish;
  end

endmodule

// ============================================================================
//  tb: dds  —— 自检测试台
//  做法：不去逐个核对正弦表的值，而是**测输出周期**，反推输出频率。
//        这是验证 DDS 最实用的思路：相位累加器算出来的频率对不对，
//        看波形周期就知道。
//
//  公式： f_out = fword × f_clk / 2^PHASE_W
//  本测试台：f_clk = 100 MHz（周期 10 ns），PHASE_W = 16
//    fword = 655  -> f_out ≈ 999.45 kHz -> 周期 ≈ 100.05 个时钟
//    fword = 1310 -> f_out ≈ 1.999 MHz  -> 周期 ≈ 50.03 个时钟
//    fword = 32   -> f_out ≈ 48.83 kHz  -> 周期 ≈ 2048 个时钟
// ============================================================================
`timescale 1ns/1ps

module tb_dds;

  localparam integer PHASE_W = 16;
  localparam integer ADDR_W  = 4;
  localparam integer DATA_W  = 8;
  localparam integer HALF    = 1 << (DATA_W - 1);   // 128，正弦中点

  reg  clk = 0, rst_n = 0;
  reg  [PHASE_W-1:0] fword = 0;
  wire [DATA_W-1:0] dout;

  dds #(.PHASE_W(PHASE_W), .ADDR_W(ADDR_W), .DATA_W(DATA_W)) dut (
    .clk(clk), .rst_n(rst_n), .fword(fword), .dout(dout));

  always #5 clk = ~clk;                 // 100 MHz

  // ---- 测周期：数两次"上穿中点"之间的时钟数 ----
  reg  [DATA_W-1:0] dout_d = 0;
  integer cyc = 0, last_cross = 0, period = 0;
  reg     seen = 0;

  always @(posedge clk) begin
    cyc = cyc + 1;
    dout_d <= dout;
    // dout 上升穿过中点 -> 一个周期开始
    if ((dout_d < HALF) && (dout >= HALF)) begin
      if (seen) period = cyc - last_cross;
      last_cross = cyc;
      seen = 1;
    end
  end

  integer errs = 0;

  task measure;
    input [PHASE_W-1:0] fw;
    input integer expect_period;
    input integer tol;
    begin
      fword = fw;
      seen  = 0; period = 0;
      repeat (expect_period * 3 + 50) @(posedge clk);   // 跑够 2~3 个周期
      $display("    fword=%0d -> 约 %0d kHz，实测周期 %0d 个时钟（期望 %0d）",
               fw, (fw * 100000 / 65536), period, expect_period);
      if (period < expect_period - tol || period > expect_period + tol) begin
        errs = errs + 1;
        $display("    x 周期超出容差 ±%0d", tol);
      end
    end
  endtask

  initial begin
    $dumpfile("tb_dds.vcd");
    $dumpvars(0, tb_dds);

    #20 rst_n = 1;
    repeat (4) @(negedge clk);

    $display("");
    $display("  f_clk = 100 MHz, PHASE_W = %0d, 频率分辨率 = %0d Hz",
             PHASE_W, 100000000 / (1 << PHASE_W));
    $display("  f_out = fword × f_clk / 2^PHASE_W");
    $display("");

    measure(16'd655,  100, 3);      // ~1 MHz
    measure(16'd1310,  50, 3);      // ~2 MHz
    measure(16'd32,  2048, 20);     // ~48.8 kHz

    $display("");
    $display("  错误数 = %0d", errs);
    if (errs == 0) $display("PASS tb_dds");
    else           $display("FAIL tb_dds");

    $finish;
  end

endmodule

`timescale 1ns/1ps

module tb_laser_measure;

  reg clk   = 1'b0;
  reg rst_n = 1'b0;
  reg sig   = 1'b0;

  wire [23:0] gap_lat;
  wire [23:0] wid_lat;
  wire [1:0]  sym;
  wire [11:0] cmd;
  wire [3:0]  win_cnt;
  wire        gap_stb;

  integer i;
  integer errs = 0;

  laser_measure #(
    .RELAX_DIV (50_000_000)
  ) dut (
    .clk     (clk),
    .rst_n   (rst_n),
    .sig     (sig),
    .gap_lat (gap_lat),
    .wid_lat (wid_lat),
    .sym     (sym),
    .cmd     (cmd),
    .win_cnt (win_cnt),
    .gap_stb (gap_stb)
  );

  always #10 clk = ~clk;

  task pulse(input integer g, input integer w);
    begin
      sig <= 1'b1;
      repeat (w) @(posedge clk);
      sig <= 1'b0;
      repeat (g - w) @(posedge clk);
    end
  endtask

  task check_sym(input integer g, input integer w, input [1:0] want);
    begin
      pulse(g, w);
      pulse(g, w);
      repeat (12) @(posedge clk);
      if (sym !== want) begin
        $display("  FAIL: gap=%0d 收 symbol=%0d 期望 %0d  (min_gap=%0d)",
                 gap_lat, sym, want, dut.min_gap);
        errs = errs + 1;
      end
      else begin
        $display("  OK  : gap=%0d (min_gap=%0d) -> symbol=%0d",
                 gap_lat, dut.min_gap, sym);
      end
    end
  endtask

  initial begin
    repeat (5) @(posedge clk);
    rst_n = 1'b1;

    repeat (3000) @(posedge clk);

    $display("");
    $display("===== 符号判决（自适应基准，间隔 100/200/300/400）=====");

    check_sym(100, 20, 2'd0);
    check_sym(200, 20, 2'd1);
    check_sym(300, 20, 2'd2);
    check_sym(400, 20, 2'd3);

    $display("");
    $display("===== 再跑一轮确认稳定 =====");
    check_sym(100, 20, 2'd0);
    check_sym(200, 20, 2'd1);
    check_sym(300, 20, 2'd2);
    check_sym(400, 20, 2'd3);

    $display("");
    if (errs == 0)
      $display("PASS: 自适应基准 + 符号判决全部正确（窗口计数 win_cnt=%0d）", win_cnt);
    else
      $display("FAIL: %0d 处不符", errs);

    $finish;
  end

endmodule

// ============================================================================
//  tb: gold_code  —— 自检测试台
//  这是整套实验里最有价值的一个：它把「deck 用的那两个多项式不是优选对」
//  这个缺陷，用硬件描述语言**跑出来**给你看。
//
//  判定标准（n=5 为奇数，t(n)=2^((n+1)/2)+1=9）：
//    两个 m 序列若是「优选对」，周期互相关只能取三个值 {-1, -9, 7}，最大绝对值 9。
//    若不是优选对，就会出现理论外的值，最大绝对值超过 9。
//
//  A 组：deck 用的 (0,2) 与 (0,3)      —— 预期 max|corr| = 11（不是优选对！）
//  B 组：换成优选对 (0,2) 与 (0,1,3,4) —— 预期 max|corr| = 9 （正确）
// ============================================================================
`timescale 1ns/1ps

module tb_gold_code;

  reg clk = 0, rst_n = 0, en = 0;
  always #5 clk = ~clk;

  // A 组：deck 原始参数  x^5+x^2+1 (0,2) 与 x^5+x^3+1 (0,3)
  wire [30:0] a_seq_a, a_seq_b, a_gold;
  wire a_valid;
  gold_code #(.TAPS_A(5'b00101), .TAPS_B(5'b01001)) dut_a (
    .clk(clk), .rst_n(rst_n), .en(en),
    .seq_a(a_seq_a), .seq_b(a_seq_b), .gold(a_gold), .valid(a_valid));

  // B 组：把第二个换成优选对 x^5+x^4+x^3+x+1 -> 抽头 (0,1,3,4) = 5'b11011 = octal 75
  wire [30:0] b_seq_a, b_seq_b, b_gold;
  wire b_valid;
  gold_code #(.TAPS_A(5'b00101), .TAPS_B(5'b11011)) dut_b (
    .clk(clk), .rst_n(rst_n), .en(en),
    .seq_a(b_seq_a), .seq_b(b_seq_b), .gold(b_gold), .valid(b_valid));

  // ---- 周期互相关：0/1 映射到 +1/-1，逐位移位相乘求和 ----
  function integer corr;
    input [30:0] x;
    input [30:0] y;
    input integer shift;
    integer i, s;
    reg xb, yb;
    begin
      s = 0;
      for (i = 0; i < 31; i = i + 1) begin
        xb = x[i];
        yb = y[(i + shift) % 31];
        s = s + ((xb ? 1 : -1) * (yb ? 1 : -1));
      end
      corr = s;
    end
  endfunction

  integer maxabs_a, extra_a, maxabs_b, extra_b, errs = 0;
  integer k, v;

  // 通用检查：算 31 个移位的互相关，输出最大绝对值 + "理论外取值个数"
  // 注意：用 task 而不是 function —— Verilog-2001 的 function 只能有一个返回值，
  //       不能带 output 端口（那是 SystemVerilog 才有的）。这是个常见的编译报错点。
  task scan_pair;
    input  [30:0] x;
    input  [30:0] y;
    output integer max_out;
    output integer n_extra;
    integer kk, vv, mx;
    begin
      mx = 0; n_extra = 0;
      for (kk = 0; kk < 31; kk = kk + 1) begin
        vv = corr(x, y, kk);
        if (vv < 0) vv = -vv;
        if (vv > mx) mx = vv;
      end
      for (kk = 0; kk < 31; kk = kk + 1) begin
        vv = corr(x, y, kk);
        if (vv !== 1 && vv !== -1 && vv !== -9 && vv !== 7) n_extra = n_extra + 1;
      end
      max_out = mx;
    end
  endtask

  task dump_pair;
    input [30:0] x;
    input [30:0] y;
    input integer is_deck;
    integer kk, vv;
    begin
      $write("    ");
      for (kk = 0; kk < 31; kk = kk + 1) begin
        vv = corr(x, y, kk);
        $write("%0d ", vv);
      end
      $write("\n");
      if (is_deck == 1) begin
        if (maxabs_a == 11 && extra_a > 0)
          $display("    -> A 组符合预期：**不是优选对**（最大 11 > t(5)=9，出现理论外取值）");
        else begin
          $display("    -> A 组结果与预期不符！（max=%0d extra=%0d）", maxabs_a, extra_a);
          errs = errs + 1;
        end
      end
      else begin
        if (maxabs_b == 9 && extra_b == 0)
          $display("    -> B 组符合预期：**是优选对**（最大 9，无理论外取值）");
        else begin
          $display("    -> B 组结果与预期不符！（max=%0d extra=%0d）", maxabs_b, extra_b);
          errs = errs + 1;
        end
      end
    end
  endtask

  initial begin
    $dumpfile("tb_gold_code.vcd");
    $dumpvars(0, tb_gold_code);

    #20 rst_n = 1;
    @(negedge clk); en = 1;
    wait (a_valid && b_valid);
    repeat (2) @(negedge clk);
    en = 0;

    scan_pair(a_seq_a, a_seq_b, maxabs_a, extra_a);
    scan_pair(b_seq_a, b_seq_b, maxabs_b, extra_b);

    $display("");
    $display("  === m 序列周期互相关（判定是否优选对）===");
    $display("  A 组 (deck 原参数): x^5+x^2+1 与 x^5+x^3+1");
    dump_pair(a_seq_a, a_seq_b, 1);
    $display("");
    $display("  B 组 (换成优选对): x^5+x^2+1 与 x^5+x^4+x^3+x+1");
    dump_pair(b_seq_a, b_seq_b, 0);

    $display("");
    $display("  === Gold 码 = 两条 m 序列异或 ===");
    $display("    A 组 gold = %b", a_gold);
    $display("    B 组 gold = %b", b_gold);

    if (a_gold !== (a_seq_a ^ a_seq_b)) begin
      errs = errs + 1; $display("  x A 组 gold 不等于两条 m 序列的异或");
    end
    if (b_gold !== (b_seq_a ^ b_seq_b)) begin
      errs = errs + 1; $display("  x B 组 gold 不等于两条 m 序列的异或");
    end

    $display("");
    if (errs == 0) $display("PASS tb_gold_code");
    else           $display("FAIL tb_gold_code");

    $finish;
  end

endmodule

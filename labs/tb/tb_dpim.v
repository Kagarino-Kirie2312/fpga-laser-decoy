// ============================================================================
//  tb: DPIM 调制解调  —— 自检测试台（本套实验里第二个"复现真实缺陷"的实验）
//
//  做法：三个调制器用同一个符号序列，但时隙长度分别是 9 / 10 / 11 个采样点，
//        模拟"发送端时钟比接收端慢 / 一致 / 快"三种情况；
//        每个调制器配两个解调器：MODE=0（deck 原版整除判决）
//        和 MODE=1（门限居中版），两者都按"1 时隙 = 10 采样点"理解。
//
//  预期结论（和 Python 仿真一致，也解释了 deck p32 的隐患）：
//    SLOT=10（无漂移）  : 两种判决都 0 错误
//    SLOT= 9（-10% 漂移）: 整除判决大量出错且出现非法符号；居中判决 0 错误
//    SLOT=11（+10% 漂移）: 两种判决都 0 错误
//  → 这就是「判决下界压在标称间隔上、负向裕量为 0」的直接后果。
//    正向漂移让间隔变长，落进宽达 +19 的容限里，所以没事；
//    负向漂移让间隔变短，符号 0 的间隔 20 掉到 18 就直接非法。
// ============================================================================
`timescale 1ns/1ps

module tb_dpim;

  localparam integer N = 16;         // 符号个数
  localparam integer SLOT_RX = 10;   // 接收端认为 1 时隙 = 10 个采样点

  reg clk = 0, rst_n = 0;
  always #5 clk = ~clk;

  // ---- 符号序列：覆盖 0/1/2/3 ----
  reg [1:0] pattern [0:N-1];
  integer   pi;
  initial begin
    pattern[0]=2'd0;  pattern[1]=2'd1;  pattern[2]=2'd2;  pattern[3]=2'd3;
    pattern[4]=2'd3;  pattern[5]=2'd2;  pattern[6]=2'd1;  pattern[7]=2'd0;
    pattern[8]=2'd0;  pattern[9]=2'd2;  pattern[10]=2'd1; pattern[11]=2'd3;
    pattern[12]=2'd3; pattern[13]=2'd0; pattern[14]=2'd1; pattern[15]=2'd2;
  end

  // ---- 三个调制器（SLOT = 9 / 10 / 11）----
  wire dout9, dout10, dout11;
  wire ready9, ready10, ready11;
  reg  start = 0;

  reg  [1:0] feed_sym  = 2'd0;
  reg  feed_valid = 0;          // 由下面的自动喂数据逻辑组合驱动
  reg  feeding = 0;             // start 之后才开始喂

  // 三个调制器共用同一组 sym/sym_valid，但各自 ready 的时刻不同，
  // 所以这里用"组合驱动 + 各自索引"的方式喂数据，保证零额外空闲周期。
  // 注意：Verilog 要求**先声明后使用**，下面的 wire 用到了 idx*，
  //       所以 integer 必须写在 wire 前面（我第一版写反了，编译直接报
  //       "Unable to bind wire/reg/memory `idx9'"）。
  integer idx9 = 0, idx10 = 0, idx11 = 0;

  reg [1:0] sym9, sym10, sym11;
  wire sv9  = feeding & ready9  & (idx9  < N);
  wire sv10 = feeding & ready10 & (idx10 < N);
  wire sv11 = feeding & ready11 & (idx11 < N);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin idx9 <= 0; idx10 <= 0; idx11 <= 0; end
    else begin
      if (sv9)  idx9  <= idx9  + 1;
      if (sv10) idx10 <= idx10 + 1;
      if (sv11) idx11 <= idx11 + 1;
    end
  end

  // 组合给出待发符号
  always @(*) begin
    sym9  = (idx9  < N) ? pattern[idx9]  : 2'd0;
    sym10 = (idx10 < N) ? pattern[idx10] : 2'd0;
    sym11 = (idx11 < N) ? pattern[idx11] : 2'd0;
  end

  dpim_mod #(.SLOT(9))  m9  (.clk(clk), .rst_n(rst_n), .start(start),
                             .sym_valid(sv9),  .sym(sym9),  .dout(dout9),  .ready(ready9));
  dpim_mod #(.SLOT(10)) m10 (.clk(clk), .rst_n(rst_n), .start(start),
                             .sym_valid(sv10), .sym(sym10), .dout(dout10), .ready(ready10));
  dpim_mod #(.SLOT(11)) m11 (.clk(clk), .rst_n(rst_n), .start(start),
                             .sym_valid(sv11), .sym(sym11), .dout(dout11), .ready(ready11));

  // ---- 六个解调器：三路 ×（整除判决 / 居中判决）----
  wire [1:0] s_f9, s_c9, s_f10, s_c10, s_f11, s_c11;
  wire v_f9, v_c9, v_f10, v_c10, v_f11, v_c11;
  wire o_f9, o_c9, o_f10, o_c10, o_f11, o_c11;

  dpim_demod #(.SLOT(SLOT_RX), .MODE(0)) d_f9  (.clk(clk),.rst_n(rst_n),.din(dout9), .sym(s_f9), .sym_valid(v_f9), .out_of_range(o_f9));
  dpim_demod #(.SLOT(SLOT_RX), .MODE(1)) d_c9  (.clk(clk),.rst_n(rst_n),.din(dout9), .sym(s_c9), .sym_valid(v_c9), .out_of_range(o_c9));
  dpim_demod #(.SLOT(SLOT_RX), .MODE(0)) d_f10 (.clk(clk),.rst_n(rst_n),.din(dout10),.sym(s_f10),.sym_valid(v_f10),.out_of_range(o_f10));
  dpim_demod #(.SLOT(SLOT_RX), .MODE(1)) d_c10 (.clk(clk),.rst_n(rst_n),.din(dout10),.sym(s_c10),.sym_valid(v_c10),.out_of_range(o_c10));
  dpim_demod #(.SLOT(SLOT_RX), .MODE(0)) d_f11 (.clk(clk),.rst_n(rst_n),.din(dout11),.sym(s_f11),.sym_valid(v_f11),.out_of_range(o_f11));
  dpim_demod #(.SLOT(SLOT_RX), .MODE(1)) d_c11 (.clk(clk),.rst_n(rst_n),.din(dout11),.sym(s_c11),.sym_valid(v_c11),.out_of_range(o_c11));

  // ---- 每个解调器各自的统计 ----
  integer idx_f9=0,  idx_c9=0,  idx_f10=0, idx_c10=0, idx_f11=0, idx_c11=0;
  integer err_f9=0,  err_c9=0,  err_f10=0, err_c10=0, err_f11=0, err_c11=0;
  integer oob_f9=0,  oob_c9=0,  oob_f10=0, oob_c10=0, oob_f11=0, oob_c11=0;

  always @(posedge clk) begin
    if (v_f9)  begin if (s_f9  !== pattern[idx_f9])  err_f9  = err_f9  + 1; if (o_f9)  oob_f9  = oob_f9  + 1; idx_f9  = idx_f9  + 1; end
    if (v_c9)  begin if (s_c9  !== pattern[idx_c9])  err_c9  = err_c9  + 1; if (o_c9)  oob_c9  = oob_c9  + 1; idx_c9  = idx_c9  + 1; end
    if (v_f10) begin if (s_f10 !== pattern[idx_f10]) err_f10 = err_f10 + 1; if (o_f10) oob_f10 = oob_f10 + 1; idx_f10 = idx_f10 + 1; end
    if (v_c10) begin if (s_c10 !== pattern[idx_c10]) err_c10 = err_c10 + 1; if (o_c10) oob_c10 = oob_c10 + 1; idx_c10 = idx_c10 + 1; end
    if (v_f11) begin if (s_f11 !== pattern[idx_f11]) err_f11 = err_f11 + 1; if (o_f11) oob_f11 = oob_f11 + 1; idx_f11 = idx_f11 + 1; end
    if (v_c11) begin if (s_c11 !== pattern[idx_c11]) err_c11 = err_c11 + 1; if (o_c11) oob_c11 = oob_c11 + 1; idx_c11 = idx_c11 + 1; end
  end

  integer errs = 0;

  initial begin
    $dumpfile("tb_dpim.vcd");
    $dumpvars(0, tb_dpim);

    #20 rst_n = 1;
    repeat (2) @(negedge clk);

    @(negedge clk); start = 1;          // 发出同步脉冲
    @(negedge clk); start = 0; feeding = 1;

    // 等全部发完（最慢的一路：16 个符号 × 最大 88 采样点 + 余量）
    repeat (16 * 100 + 200) @(negedge clk);

    $display("");
    $display("  符号序列（%0d 个）: 0 1 2 3 3 2 1 0 0 2 1 3 3 0 1 2", N);
    $display("  接收端一致按「1 时隙 = %0d 采样点」解调", SLOT_RX);
    $display("");
    $display("  发送端时隙  判决方式      解出个数  符号错误  非法间隔");
    $display("  ----------  ------------  --------  --------  --------");
    $display("     10       整除(MODE=0)   %0d        %0d         %0d", idx_f10, err_f10, oob_f10);
    $display("     10       居中(MODE=1)   %0d        %0d         %0d", idx_c10, err_c10, oob_c10);
    $display("      9       整除(MODE=0)   %0d        %0d         %0d", idx_f9,  err_f9,  oob_f9);
    $display("      9       居中(MODE=1)   %0d        %0d         %0d", idx_c9,  err_c9,  oob_c9);
    $display("     11       整除(MODE=0)   %0d        %0d         %0d", idx_f11, err_f11, oob_f11);
    $display("     11       居中(MODE=1)   %0d        %0d         %0d", idx_c11, err_c11, oob_c11);
    $display("");

    // ---- 判定 ----
    // 1) 无漂移时两种判决都必须完全正确
    if (idx_f10 != N || err_f10 != 0) begin errs=errs+1; $display("  x 无漂移时整除判决未能全部还原"); end
    if (idx_c10 != N || err_c10 != 0) begin errs=errs+1; $display("  x 无漂移时居中判决未能全部还原"); end
    // 2) 负向漂移：整除判决必须出错（这正是我们要复现的缺陷）
    if (err_f9 == 0) begin errs=errs+1; $display("  x 负向漂移下整除判决居然没错？结论不成立"); end
    else $display("  -> 负向漂移 -10%%：整除判决错了 %0d 个（其中非法间隔 %0d 个）== 缺陷复现成功", err_f9, oob_f9);
    // 3) 负向漂移：居中判决必须全部正确（这就是修法）
    if (idx_c9 != N || err_c9 != 0) begin errs=errs+1; $display("  x 居中判决在负向漂移下也错了（修法无效）"); end
    else $display("  -> 负向漂移 -10%%：居中判决 0 错误 == 修法有效");
    // 4) 正向漂移：整除判决应当没事（体现不对称性）
    if (err_f11 == 0) $display("  -> 正向漂移 +10%%：整除判决也没错 == 门限不对称，缺陷只在负方向");
    else $display("  -> 正向漂移 +10%%：整除判决错了 %0d 个", err_f11);

    $display("");
    if (errs == 0) $display("PASS tb_dpim");
    else           $display("FAIL tb_dpim");

    $finish;
  end

endmodule

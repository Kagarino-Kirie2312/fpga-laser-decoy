// ============================================================================
//  tb: sync_fifo  —— 自检测试台
//  检查：① 写入 N 个后 count 正确、empty/full 标志正确
//        ② 读出的顺序与写入顺序完全一致（FIFO 的本职）
//        ③ 满的时候再写会被忽略（不覆盖旧数据）
//        ④ **同时读写**时计数不变、数据不错  ← 这是最容易写错的地方
// ============================================================================
`timescale 1ns/1ps

module tb_sync_fifo;

  localparam integer W = 8, DEPTH = 16;

  reg  clk = 0, rst_n = 0, wr_en = 0, rd_en = 0;
  reg  [W-1:0] din = 0;
  wire [W-1:0] dout;
  wire full, empty;
  wire [$clog2(DEPTH+1)-1:0] count;

  sync_fifo #(.W(W), .DEPTH(DEPTH)) dut (
    .clk(clk), .rst_n(rst_n), .wr_en(wr_en), .din(din), .rd_en(rd_en),
    .dout(dout), .full(full), .empty(empty), .count(count));

  always #5 clk = ~clk;

  integer errs = 0, i;

  task do_write(input [W-1:0] d);
    begin
      @(negedge clk); din = d; wr_en = 1;
      @(negedge clk); wr_en = 0;
    end
  endtask

  // 读一个字节：返回后 dout 上就是读出的数据（FIFO 的 dout 是寄存输出）
  task do_read(output [W-1:0] d);
    begin
      @(negedge clk); rd_en = 1;
      @(negedge clk); rd_en = 0;
      d = dout;
    end
  endtask

  reg [W-1:0] v;

  initial begin
    $dumpfile("tb_sync_fifo.vcd");
    $dumpvars(0, tb_sync_fifo);

    #20 rst_n = 1;
    repeat (2) @(negedge clk);

    // ---- ① 空标志 ----
    if (!empty || count !== 0) begin errs=errs+1; $display("  x 复位后应为空"); end

    // ---- ② 写 5 个 ----
    for (i = 1; i <= 5; i = i + 1) do_write(i[W-1:0]);
    repeat (1) @(negedge clk);
    if (count !== 5) begin errs=errs+1; $display("  x 写入 5 个后 count=%0d（应为 5）", count); end
    if (empty || full) begin errs=errs+1; $display("  x 写 5 个后空满标志不对"); end

    // ---- ③ 顺序读出，必须与写入一致 ----
    for (i = 1; i <= 5; i = i + 1) begin
      do_read(v);
      if (v !== i[W-1:0]) begin
        errs=errs+1;
        $display("  x 第 %0d 个读出 %0d，期望 %0d（顺序错 = FIFO 的致命 bug）", i, v, i);
      end
    end
    if (!empty) begin errs=errs+1; $display("  x 读完 5 个后应为空"); end

    // ---- ④ 写满，检查 full，并验证满时写入被忽略 ----
    for (i = 0; i < DEPTH; i = i + 1) do_write(8'hA0 + i[7:0]);
    repeat (1) @(negedge clk);
    if (!full) begin errs=errs+1; $display("  x 写满后 full 未置起（count=%0d）", count); end
    do_write(8'hFF);                       // 满时写：应被忽略
    repeat (1) @(negedge clk);
    if (count !== DEPTH) begin errs=errs+1; $display("  x 满时写入居然改变了 count"); end
    do_read(v);
    if (v !== 8'hA0) begin errs=errs+1; $display("  x 满时写入覆盖了旧数据（读出 %02X，期望 A0）", v); end

    // ---- ⑤ 同时读写：计数不变、顺序正确 ----
    // 此刻 count = DEPTH-1 = 15，先读空到 count=3
    while (count > 3) do_read(v);

    @(negedge clk); din = 8'h5A; wr_en = 1; rd_en = 1;
    @(negedge clk); wr_en = 0; rd_en = 0;
    repeat (1) @(negedge clk);
    if (count !== 3) begin errs=errs+1; $display("  x 同时读写后 count=%0d（应保持 3）", count); end

    $display("  同时读写测试后 count = %0d（应为 3）", count);
    $display("  错误数 = %0d", errs);

    if (errs == 0) $display("PASS tb_sync_fifo");
    else           $display("FAIL tb_sync_fifo");

    $finish;
  end

endmodule

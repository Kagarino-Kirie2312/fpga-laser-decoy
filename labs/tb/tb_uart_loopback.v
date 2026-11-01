// ============================================================================
//  tb: UART 收发回环  —— 自检测试台
//  做法：把 uart_tx 的输出直接接到 uart_rx 的输入（回环），
//        发一串字节，检查收到的和发出的完全一致。
//        一个测试台同时验证收发两端，这是最省事的验证思路。
//
//  还做了一件重要的事：故意让收发两端的波特率有 **+3% 偏差**
//  （发送端 DIV=100，接收端 DIV=103），验证「中点采样」确实能容忍频差。
//  这是理解 UART 为什么必须中点采样的最好实验：
//  偏差会在 10 个 bit 上累积，采样点从"位正中间"向边缘漂移；
//  中点采样的容限约 ±5%（累积半个 bit），所以 +3% 还能过。
// ============================================================================
`timescale 1ns/1ps

module tb_uart_loopback;

  localparam integer BAUD   = 100;
  localparam integer TX_CLK = 10000;    // DIV = 100
  localparam integer RX_CLK = 10300;    // DIV = 103  -> 故意 +3% 频差

  reg  clk = 0;
  reg  rst_n = 0;
  reg  send = 0;
  reg  [7:0] tx_data = 0;
  wire tx_line;
  wire tx_busy;
  wire [7:0] rx_data;
  wire rx_done;

  uart_tx #(.CLK_HZ(TX_CLK), .BAUD(BAUD)) u_tx (
    .clk(clk), .rst_n(rst_n), .send(send), .data(tx_data), .tx(tx_line), .busy(tx_busy));

  uart_rx #(.CLK_HZ(RX_CLK), .BAUD(BAUD)) u_rx (
    .clk(clk), .rst_n(rst_n), .rx(tx_line), .data(rx_data), .done(rx_done));

  always #5 clk = ~clk;                 // 共用一个时钟，只是两端分频参数不同

  // ---- 收集收到的字节 ----
  reg [7:0] got [0:7];
  integer   n_got = 0;
  always @(posedge clk)
    if (rx_done) begin
      got[n_got] = rx_data;
      n_got = n_got + 1;
      $display("    收到 0x%02X", rx_data);
    end

  // ---- 发送一个字节 ----
  // 关键：send 拉高后必须**先等 busy 上升**（说明 FSM 已经采样到 send），
  //       再拉低 send。如果顺序错了，会去等一个已经发生过的边沿 -> 仿真永久阻塞。
  //       （我第一版就是这么挂的：200 ms 都没跑完。所以运行器一定要带超时。）
  task send_byte(input [7:0] b);
    begin
      @(negedge clk); tx_data = b; send = 1;
      @(posedge tx_busy);            // FSM 已锁存 -> 现在可以撤 send
      @(negedge clk); send = 0;
      @(negedge tx_busy);            // 等这一字节发完
      repeat (4) @(negedge clk);
    end
  endtask

  reg [7:0] pattern [0:3];
  integer i, errs = 0;

  initial begin
    $dumpfile("tb_uart_loopback.vcd");
    $dumpvars(0, tb_uart_loopback);

    pattern[0] = 8'h55;   // 0101_0101：位序错一眼看出来
    pattern[1] = 8'hA3;
    pattern[2] = 8'h00;
    pattern[3] = 8'hFF;

    #20 rst_n = 1;
    repeat (4) @(negedge clk);

    for (i = 0; i < 4; i = i + 1) begin
      $display("  发送 0x%02X", pattern[i]);
      send_byte(pattern[i]);
    end

    repeat (20) @(negedge clk);

    $display("  发出 4 个，收到 %0d 个（收发频差 +3%%）", n_got);
    if (n_got != 4) errs = errs + 1;
    else
      for (i = 0; i < 4; i = i + 1)
        if (got[i] !== pattern[i]) begin
          errs = errs + 1;
          $display("  x 第 %0d 个不符：期望 0x%02X，收到 0x%02X", i, pattern[i], got[i]);
        end

    if (errs == 0) $display("PASS tb_uart_loopback");
    else           $display("FAIL tb_uart_loopback");

    $finish;
  end

endmodule

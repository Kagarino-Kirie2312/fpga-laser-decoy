

`timescale 1ns/1ps

module tb_acm9238_probe;

  reg clk = 1'b0;
  reg rst_n = 1'b0;
  reg signed [11:0] ch1_d = 12'sd0;
  reg ch1_otr = 1'b0;

  wire adc_clk;
  wire [3:0] led;
  wire led4;
  wire uart_tx;

  integer errors = 0;
  integer i;

  acm9238_led_probe #(
    .THRESH   (12'sd16),
    .CONFIRM  (8'd8),
    .HOLD_CLK (32'd2000),
    .HEART_CLK(32'd1000),
    .LED_ACTIVE_LOW (0)
  ) dut (
    .clk     (clk),
    .rst_n   (rst_n),
    .ch1_d   (ch1_d),
    .ch1_otr (ch1_otr),
    .adc_clk (adc_clk),
    .led     (led),
    .led4    (led4),
    .uart_tx (uart_tx)
  );

  always #10 clk = ~clk;

  task pulse_ci(input integer width, input integer amp);
    begin
      for (i = 0; i < width; i = i + 1) begin
        @(posedge clk);
        ch1_d <= amp;
      end
      @(posedge clk);
      ch1_d <= 12'sd0;
    end
  endtask

  initial begin

    repeat (10) @(posedge clk);
    rst_n = 1'b1;
    repeat (20) @(posedge clk);

    $display("--- 1) 加噪声（±3 LSB），期望 led[1] 保持 0 ---");
    for (i = 0; i < 200; i = i + 1) begin
      @(posedge clk);
      ch1_d <= (i % 3 == 0) ? 12'sd3 : ((i % 3 == 1) ? -12'sd3 : 12'sd0);
    end
    if (led[1] !== 1'b0) begin
      $display("  FAIL: 噪声把灯点亮了");
      errors = errors + 1;
    end
    else $display("  OK  : 噪声没误触发");

    $display("--- 2) 灌一个脉冲（MSB=1，88 点 = 1.76us）---");
    pulse_ci(88, -100);
    repeat (30) @(posedge clk);
    if (led[1] !== 1'b1) begin
      $display("  FAIL: 脉冲没有点亮 led[1]");
      errors = errors + 1;
    end
    else $display("  OK  : 脉冲点亮 led[1]");

    $display("--- 3) 展宽计数到 0 后应熄灭 ---");
    repeat (2100) @(posedge clk);
    if (led[1] !== 1'b0) begin
      $display("  FAIL: 展宽没有结束");
      errors = errors + 1;
    end
    else $display("  OK  : 展宽正常结束");

    $display("--- 4) OTR 拉高，led[2] 应变亮 ---");
    ch1_otr <= 1'b1;
    repeat (3) @(posedge clk);
    if (led[2] !== 1'b1) begin
      $display("  FAIL: OTR 没反应");
      errors = errors + 1;
    end
    else $display("  OK  : OTR 指示正常");
    ch1_otr <= 1'b0;

    $display("--- 5) 2 个点的毛刺，不应误触发 ---");
    pulse_ci(2, -500);
    repeat (30) @(posedge clk);
    if (led[1] !== 1'b0) begin
      $display("  FAIL: 毛刺被当成脉冲");
      errors = errors + 1;
    end
    else $display("  OK  : 毛刺被过滤");

    if (errors == 0) $display("PASS: 5/5 项检查全部通过");
    else             $display("FAIL: %0d 项未通过", errors);

    $finish;
  end

endmodule

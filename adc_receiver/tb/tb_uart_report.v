`timescale 1ns/1ps

module tb_uart_report;

  reg clk   = 1'b0;
  reg rst_n = 1'b0;

  reg  [23:0] wid;
  reg  [23:0] gap;
  reg  [1:0]  sym;
  reg  [11:0] cmd;

  wire [7:0] tx_byte;
  wire       tx_start;
  wire       uart_tx;

  integer i;
  integer k;
  integer errs = 0;

  localparam integer BITNS = 1000;

  uart_report #(
    .CLK_FREQ (50_000_000),
    .BAUD     (1_000_000),
    .REP_DIV  (100000)
  ) dut (
    .clk      (clk),
    .rst_n    (rst_n),
    .wid      (wid),
    .gap      (gap),
    .sym      (sym),
    .cmd      (cmd),
    .tx_byte  (tx_byte),
    .tx_start (tx_start),
    .uart_tx  (uart_tx)
  );

  always #10 clk = ~clk;

  reg [7:0] rxbuf [0:63];
  integer   nch = 0;

  task wait_idle;
    integer c;
    begin
      c = 0;
      while (c < 3 * BITNS) begin
        @(posedge clk);
        if (uart_tx == 1'b1) c = c + 20;
        else                 c = 0;
      end
    end
  endtask

  task get_byte;
    begin
      @(negedge uart_tx);
      #(BITNS + BITNS/2);
      for (k = 0; k < 8; k = k + 1) begin
        rxbuf[nch][k] = uart_tx;
        #BITNS;
      end
      nch = nch + 1;
    end
  endtask

  reg [7:0] expect [0:28];

  initial begin
    wid = 24'h000096;
    gap = 24'h0003E9;
    sym = 2'd2;
    cmd = 12'hB77;

    expect[0]  = 8'h57;
    expect[1]  = 8'h3D;
    expect[2]  = 8'h30;
    expect[3]  = 8'h30;
    expect[4]  = 8'h30;
    expect[5]  = 8'h30;
    expect[6]  = 8'h39;
    expect[7]  = 8'h36;
    expect[8]  = 8'h20;
    expect[9]  = 8'h47;
    expect[10] = 8'h3D;
    expect[11] = 8'h30;
    expect[12] = 8'h30;
    expect[13] = 8'h30;
    expect[14] = 8'h33;
    expect[15] = 8'h45;
    expect[16] = 8'h39;
    expect[17] = 8'h20;
    expect[18] = 8'h53;
    expect[19] = 8'h3D;
    expect[20] = 8'h32;
    expect[21] = 8'h20;
    expect[22] = 8'h43;
    expect[23] = 8'h3D;
    expect[24] = 8'h42;
    expect[25] = 8'h37;
    expect[26] = 8'h37;
    expect[27] = 8'h0D;
    expect[28] = 8'h0A;

    repeat (5) @(posedge clk);
    rst_n = 1'b1;

    wait_idle;

    for (i = 0; i < 29; i = i + 1) get_byte;

    $display("");
    $display("===== 收到的串口内容 =====");
    for (i = 0; i < nch; i = i + 1) begin
      if (rxbuf[i] >= 8'h20 && rxbuf[i] < 8'h7F) $write("%c", rxbuf[i]);
      else if (rxbuf[i] == 8'h0D)                $write("<CR>");
      else if (rxbuf[i] == 8'h0A)                $write("<LF>");
      else                                       $write("[%02X]", rxbuf[i]);
    end
    $display("");

    for (i = 0; i < 29; i = i + 1) begin
      if (rxbuf[i] !== expect[i]) begin
        $display("  FAIL: 第 %0d 字符 收到 %02X 期望 %02X", i, rxbuf[i], expect[i]);
        errs = errs + 1;
      end
    end

    if (errs == 0 && nch == 29)
      $display("PASS: 帧格式正确（W=000096 G=0003E9 S=2 C=B77）");
    else
      $display("FAIL: %0d 处不符，收到 %0d 字符", errs, nch);

    $finish;
  end

endmodule

// ============================================================================
//  Lab 5  UART 发送
//  学到：① 单片机里一行 HAL_UART_Transmit，FPGA 里要自己搭波特率计数器 + 移位 + 状态机
//        ② 一帧 = 起始位0 + 8 数据位(LSB first) + 停止位1
//        ③ 波特率分频 DIV = CLK_HZ / BAUD
//  对应项目：deck p26/p34 的 9600bps（div_cnt == 5207，即 DIV-1 = 5208-1）
// ============================================================================
`timescale 1ns/1ps

module uart_tx #(
  parameter integer CLK_HZ = 50_000_000,
  parameter integer BAUD   = 9600
)(
  input  wire       clk,
  input  wire       rst_n,
  input  wire       send,      // 单周期脉冲：请求发送
  input  wire [7:0] data,      // 待发字节
  output reg        tx,        // 串行输出线（空闲为高）
  output reg        busy       // 发送中
);

  localparam integer DIV = CLK_HZ / BAUD;   // 每个 bit 占多少个时钟

  localparam [1:0] S_IDLE  = 2'd0,
                   S_START = 2'd1,
                   S_DATA  = 2'd2,
                   S_STOP  = 2'd3;

  reg [1:0]  state;
  reg [15:0] cnt;            // DIV 最大 5208，16 位足够
  reg [2:0]  bit_idx;
  reg [7:0]  shifter;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state   <= S_IDLE;
      tx      <= 1'b1;
      busy    <= 1'b0;
      cnt     <= 16'd0;
      bit_idx <= 3'd0;
      shifter <= 8'd0;
    end
    else begin
      case (state)
        S_IDLE: begin
          tx   <= 1'b1;                 // 空闲高
          cnt  <= 16'd0;
          bit_idx <= 3'd0;
          if (send) begin
            shifter <= data;            // 锁存待发数据
            busy    <= 1'b1;
            state   <= S_START;
          end
          else busy <= 1'b0;
        end

        S_START: begin
          tx <= 1'b0;                   // 起始位
          if (cnt == DIV - 1) begin cnt <= 16'd0; state <= S_DATA; end
          else                     cnt <= cnt + 1'b1;
        end

        S_DATA: begin
          tx <= shifter[0];             // LSB first
          if (cnt == DIV - 1) begin
            cnt     <= 16'd0;
            shifter <= {1'b0, shifter[7:1]};   // 右移，下一位到 bit0
            if (bit_idx == 3'd7) state <= S_STOP;
            else                 bit_idx <= bit_idx + 1'b1;
          end
          else cnt <= cnt + 1'b1;
        end

        S_STOP: begin
          tx <= 1'b1;                   // 停止位
          if (cnt == DIV - 1) begin
            cnt   <= 16'd0;
            busy  <= 1'b0;
            state <= S_IDLE;
          end
          else cnt <= cnt + 1'b1;
        end

        default: state <= S_IDLE;
      endcase
    end
  end

endmodule

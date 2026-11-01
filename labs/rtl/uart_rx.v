// ============================================================================
//  Lab 6  UART 接收（中点采样）
//  学到：① 异步串行线必须先用 2 级触发器同步，再做边沿检测（对应 Lab 2）
//        ② 「中点采样」：检测到起始位下降沿后，等半个 bit 再采，
//           之后每个 bit 都在正中间采 —— 这样能容忍双方波特率误差与抖动
//        ③ 采样时刻的推算：起始沿 + 0.5bit 校验起始位，再 +1bit = bit0 中点
//  对应项目：deck p26「打 3 拍 + 中点采样 + bit_cnt 0~9 + 停止位校验」
// ============================================================================
`timescale 1ns/1ps

module uart_rx #(
  parameter integer CLK_HZ = 50_000_000,
  parameter integer BAUD   = 9600
)(
  input  wire       clk,
  input  wire       rst_n,
  input  wire       rx,        // 串行输入线
  output reg  [7:0] data,      // 收到的字节
  output reg        done       // 收完一字节，给一个单周期脉冲
);

  localparam integer DIV  = CLK_HZ / BAUD;
  localparam integer HALF = DIV / 2;

  localparam [1:0] S_IDLE  = 2'd0,
                   S_START = 2'd1,
                   S_DATA  = 2'd2,
                   S_STOP  = 2'd3;

  // ---- 第一级：同步 + 边沿检测 ----
  reg [1:0] sync;
  reg       rx_d;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sync <= 2'b11;
      rx_d <= 1'b1;
    end
    else begin
      sync <= {sync[0], rx};    // 打两拍消亚稳态
      rx_d <= sync[1];
    end
  end

  wire rx_s      = sync[1];
  wire start_edge = rx_d & ~rx_s;   // 下降沿 = 起始位到来

  // ---- 第二级：接收状态机 ----
  reg [1:0]  state;
  reg [15:0] cnt;
  reg [2:0]  bit_idx;
  reg [7:0]  shifter;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state   <= S_IDLE;
      cnt     <= 16'd0;
      bit_idx <= 3'd0;
      shifter <= 8'd0;
      data    <= 8'd0;
      done    <= 1'b0;
    end
    else begin
      done <= 1'b0;                       // 默认拉低，只在收完那一拍为高

      case (state)
        S_IDLE: begin
          cnt <= 16'd0;
          if (start_edge) state <= S_START;   // 见到起始沿才开始
        end

        S_START: begin
          if (cnt == HALF - 1) begin          // 走到起始位正中
            cnt <= 16'd0;
            if (rx_s == 1'b0) begin           // 确认确实是起始位（不是毛刺）
              state   <= S_DATA;
              bit_idx <= 3'd0;
            end
            else state <= S_IDLE;             // 假起始，丢弃
          end
          else cnt <= cnt + 1'b1;
        end

        S_DATA: begin
          if (cnt == DIV - 1) begin           // 每个 bit 的中点采样
            cnt <= 16'd0;
            shifter[bit_idx] <= rx_s;         // LSB first
            if (bit_idx == 3'd7) state <= S_STOP;
            else                 bit_idx <= bit_idx + 1'b1;
          end
          else cnt <= cnt + 1'b1;
        end

        S_STOP: begin
          if (cnt == DIV - 1) begin           // 停止位中点
            cnt   <= 16'd0;
            data  <= shifter;
            done  <= 1'b1;                    // 收完，通知上层
            state <= S_IDLE;
          end
          else cnt <= cnt + 1'b1;
        end

        default: state <= S_IDLE;
      endcase
    end
  end

endmodule

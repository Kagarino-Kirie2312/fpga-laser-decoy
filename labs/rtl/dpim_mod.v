// ============================================================================
//  Lab 11a  DPIM 调制器
//  学到：① 用「脉冲之间的间隔长度」承载 2 个信息比特
//        ② 符号 0/1/2/3 -> 2/4/6/8 个时隙，1 时隙 = SLOT 个采样点
//        ③ 帧首固定发一个脉冲做同步基准（deck p11 的约定）
//  对应项目：deck p11 / p13
//
//  注意 SLOT 是参数：测试台故意把它设成 9 / 10 / 11，
//  来模拟"发送端时钟比接收端快/慢"的情况（见 tb_dpim.v）。
// ============================================================================
`timescale 1ns/1ps

module dpim_mod #(
  parameter integer SLOT = 10        // 1 个时隙 = 多少个采样点
)(
  input  wire       clk,
  input  wire       rst_n,
  input  wire       start,           // 单周期脉冲：先发一个同步脉冲
  input  wire       sym_valid,       // 单周期脉冲：本拍 sym 有效
  input  wire [1:0] sym,             // 待发符号 0~3
  output reg        dout,            // 0/1 采样流（每时钟一个采样点）
  output reg        ready            // 空闲、等待下一个符号
);

  localparam [1:0] S_SYNC  = 2'd0,
                   S_WAIT  = 2'd1,
                   S_GAP   = 2'd2,
                   S_PULSE = 2'd3;

  reg [1:0]  state;
  reg [15:0] cnt;
  reg [15:0] gap_target;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= S_WAIT;
      dout       <= 1'b0;        // 复位后输出 0：第一个 1 必须是 start 发出的同步脉冲
      cnt        <= 16'd0;
      gap_target <= 16'd0;
      ready      <= 1'b1;
    end
    else begin
      case (state)
        // 帧首同步脉冲：固定发一个 1（宽度 1 个采样点）
        S_SYNC: begin
          dout  <= 1'b1;
          state <= S_WAIT;
          ready <= 1'b1;
        end

        // 等下一个符号
        S_WAIT: begin
          dout  <= 1'b0;
          ready <= 1'b1;
          cnt   <= 16'd0;
          if (start) begin
            state <= S_SYNC;
            ready <= 1'b0;
          end
          else if (sym_valid) begin
            // 间隔 = 时隙数 × 每时隙采样点；时隙数 = 2*sym + 2
            // 减 1 的原因：脉冲之后必然先经过本状态 1 个时钟（输出 0），
            // 那个 0 也算在"脉冲到脉冲的间隔"里，所以 S_GAP 少发一个。
            // 这类 off-by-one 是 DPIM/串口这类"数间隔"逻辑最常见的错误来源。
            gap_target <= (sym * 2 + 2) * SLOT - 1;
            ready      <= 1'b0;
            state      <= S_GAP;
          end
        end

        // 发间隔（连续 0）
        S_GAP: begin
          dout <= 1'b0;
          if (cnt == gap_target - 1) begin
            cnt   <= 16'd0;
            state <= S_PULSE;
          end
          else cnt <= cnt + 1'b1;
        end

        // 发脉冲（宽度 1 个采样点）
        S_PULSE: begin
          dout  <= 1'b1;
          state <= S_WAIT;
        end

        default: state <= S_WAIT;
      endcase
    end
  end

endmodule

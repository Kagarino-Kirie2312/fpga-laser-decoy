// ============================================================================
//  Lab 4  三段式状态机
//  学到：工业界标准写法 = 状态寄存器（时序）+ 次态组合 + 输出（时序）；
//        组合块里必须给默认值，否则会综合出 latch（自查手册 坑 2）。
//  对应项目：deck p24 的 IDLE -> CALC_SYMBOL -> CALC_GOLD -> DONE
//            那个状态机是"计数器到了才转移"，这里是"按键次数到了才转移"。
//
//  功能：每按 3 次，led 翻转一次。
// ============================================================================
`timescale 1ns/1ps

module fsm_seq3 (
  input  wire clk,
  input  wire rst_n,
  input  wire press,        // 每次按下给一个单周期脉冲
  output reg  led,
  output reg  [1:0] state_dbg
);

  localparam [1:0] S_IDLE  = 2'd0,   // 等第 1 次
                   S_COUNT = 2'd1,   // 等第 2、3 次
                   S_TOG   = 2'd2;   // 执行翻转

  reg [1:0] state, next_state;
  reg [1:0] cnt;            // 已经认可的次数：0 -> 1 -> 2

  // ---- 第一段：状态寄存器 ----
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= S_IDLE;
    else        state <= next_state;
  end

  // ---- 第二段：次态组合逻辑 ----
  always @(*) begin
    next_state = state;                     // 默认保持，避免 latch
    case (state)
      S_IDLE:  if (press) next_state = S_COUNT;
      S_COUNT: if (press && (cnt == 2'd2)) next_state = S_TOG;
      S_TOG:   next_state = S_IDLE;         // 翻转完就回去
      default: next_state = S_IDLE;
    endcase
  end

  // ---- 第三段：输出与计数（时序输出，无毛刺）----
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cnt       <= 2'd0;
      led       <= 1'b0;
      state_dbg <= S_IDLE;
    end
    else begin
      state_dbg <= state;
      case (state)
        S_IDLE:  if (press) cnt <= 2'd1;                     // 第 1 次
        S_COUNT: if (press && (cnt != 2'd2)) cnt <= cnt + 1'b1;  // 第 2 次
        S_TOG:   begin
          led <= ~led;                                      // 第 3 次 -> 翻转
          cnt <= 2'd0;
        end
        default: cnt <= 2'd0;
      endcase
    end
  end

endmodule

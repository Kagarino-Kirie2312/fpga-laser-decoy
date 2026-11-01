// ============================================================================
//  Lab 8  同步 FIFO（先进先出缓冲）
//  学到：① 读写指针 + 计数器 + 空满标志
//        ② ★同时读写的陷阱★：如果写成两个独立的 if（先 +1 再 -1），
//           非阻塞赋值会让"后一条"覆盖"前一条"，计数就错了。
//           本模块用 case ({写使能, 读使能}) 明确处理四种组合。
//        ③ 为什么用 FIFO 而不是直接连线：缓冲速率不匹配的两侧
//  对应项目：deck p40 的 fifo_rx、p49 的 fifo_tx
//            （那两处是**异步** FIFO，因为两侧时钟不同；本实验先做同步版打基础）
// ============================================================================
`timescale 1ns/1ps

module sync_fifo #(
  parameter integer W     = 8,      // 数据位宽
  parameter integer DEPTH = 16      // 深度（本实现要求是 2 的幂，方便取模）
)(
  input  wire           clk,
  input  wire           rst_n,
  input  wire           wr_en,
  input  wire [W-1:0]   din,
  input  wire           rd_en,
  output reg  [W-1:0]   dout,
  output wire           full,
  output wire           empty,
  output reg  [$clog2(DEPTH+1)-1:0] count
);

  reg [W-1:0] mem [0:DEPTH-1];
  reg [$clog2(DEPTH)-1:0] wptr, rptr;

  assign full  = (count == DEPTH);
  assign empty = (count == 0);

  wire do_wr = wr_en & ~full;
  wire do_rd = rd_en & ~empty;

  wire [$clog2(DEPTH)-1:0] wptr_n = wptr + 1'b1;
  wire [$clog2(DEPTH)-1:0] rptr_n = rptr + 1'b1;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wptr  <= 0;
      rptr  <= 0;
      count <= 0;
      dout  <= 0;
    end
    else begin
      // ★ 必须把"同时读写"当成一个独立情况处理，否则 count 会被算错
      case ({do_wr, do_rd})
        2'b10: begin                      // 只写
          mem[wptr] <= din;
          wptr      <= wptr_n;
          count     <= count + 1'b1;
        end
        2'b01: begin                      // 只读
          dout <= mem[rptr];
          rptr <= rptr_n;
          count <= count - 1'b1;
        end
        2'b11: begin                      // 同时读写：数量不变
          mem[wptr] <= din;
          wptr      <= wptr_n;
          dout      <= mem[rptr];
          rptr      <= rptr_n;
        end
        default: ;                        // 什么都不做
      endcase
    end
  end

endmodule

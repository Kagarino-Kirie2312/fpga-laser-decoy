`timescale 1ns/1ps

module uart_tx #(
  parameter integer CLK_FREQ = 50_000_000,
  parameter integer BAUD     = 115200
)(
  input  wire       clk,
  input  wire       rst_n,
  input  wire [7:0] din,
  input  wire       start,
  output reg        tx,
  output reg        busy,
  output reg        done
);

  localparam integer DIV = CLK_FREQ / BAUD;

  reg [15:0] cnt;
  reg [3:0]  bit_i;
  reg [9:0]  shifter;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      tx      <= 1'b1;
      busy    <= 1'b0;
      done    <= 1'b0;
      cnt     <= 16'd0;
      bit_i   <= 4'd0;
      shifter <= 10'h3FF;
    end
    else begin
      done <= 1'b0;

      if (!busy) begin
        if (start) begin
          shifter <= {1'b1, din, 1'b0};
          busy    <= 1'b1;
          cnt     <= 16'd0;
          bit_i   <= 4'd0;
          tx      <= 1'b0;
        end
      end
      else if (cnt == DIV - 1) begin
        cnt <= 16'd0;
        if (bit_i == 4'd9) begin
          busy <= 1'b0;
          done <= 1'b1;
          tx   <= 1'b1;
        end
        else begin
          bit_i <= bit_i + 4'd1;
          tx    <= shifter[bit_i + 4'd1];
        end
      end
      else begin
        cnt <= cnt + 16'd1;
      end
    end
  end

endmodule

module laser_measure #(
  parameter integer RELAX_DIV = 50_000_000
)(
  input  wire       clk,
  input  wire       rst_n,
  input  wire       sig,
  output reg [23:0] gap_lat,
  output reg [23:0] wid_lat,
  output reg [1:0]  sym,
  output reg [11:0] cmd,
  output reg [3:0]  win_cnt,
  output reg        gap_stb
);

  localparam [30:0] GOLD = 31'b001_0111_1001_0110_1001_1110_1000_0000;

  reg        sig_q;
  reg [23:0] gap_cnt;
  reg [23:0] wid_cnt;

  wire sig_rise = sig  & ~sig_q;
  wire sig_fall = ~sig &  sig_q;

  reg stb1;
  reg stb2;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sig_q   <= 1'b0;
      gap_cnt <= 24'd0;
      gap_lat <= 24'd0;
      wid_cnt <= 24'd0;
      wid_lat <= 24'd0;
      gap_stb <= 1'b0;
      stb1    <= 1'b0;
      stb2    <= 1'b0;
    end
    else begin
      sig_q   <= sig;
      gap_stb <= sig_rise;
      stb1    <= gap_stb;
      stb2    <= stb1;

      if (sig_rise) begin
        gap_lat <= gap_cnt;
        gap_cnt <= 24'd0;
        wid_cnt <= 24'd0;
      end
      else if (gap_cnt != 24'hFFFFFF) begin
        gap_cnt <= gap_cnt + 24'd1;
      end

      if (sig_fall) begin
        wid_lat <= wid_cnt;
      end
      else if (sig && wid_cnt != 24'hFFFFFF) begin
        wid_cnt <= wid_cnt + 24'd1;
      end
    end
  end

  reg [23:0] min_gap;
  reg [25:0] relax;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      min_gap <= 24'hFFFFFF;
      relax   <= 26'd0;
    end
    else if (sig_rise && gap_cnt != 24'd0 && gap_cnt < min_gap) begin
      min_gap <= gap_cnt;
      relax   <= 26'd0;
    end
    else if (relax >= RELAX_DIV[25:0] - 26'd1) begin
      relax <= 26'd0;
      if (min_gap != 24'hFFFFFF) min_gap <= min_gap + 24'd1;
    end
    else begin
      relax <= relax + 26'd1;
    end
  end

  wire [25:0] mn = {2'b00, min_gap};
  wire [25:0] hf = {2'b00, min_gap[23:1]};
  wire [25:0] gx = {2'b00, gap_lat};

  wire [25:0] th1 = mn + hf;
  wire [25:0] th2 = {mn[24:0], 1'b0} + hf;
  wire [25:0] th3 = {mn[24:0], 1'b0} + mn + hf;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sym <= 2'd0;
    end
    else if (stb1) begin
      if (min_gap == 24'hFFFFFF) sym <= 2'd0;
      else if (gx < th1)         sym <= 2'd0;
      else if (gx < th2)         sym <= 2'd1;
      else if (gx < th3)         sym <= 2'd2;
      else                       sym <= 2'd3;
    end
  end

  reg        push_en;
  reg        pnd;
  reg [1:0]  pdata;
  reg [30:0] win;
  reg [4:0]  bitcnt;

  wire        pbit    = pdata[1];
  wire [30:0] win_nxt = {pbit, win[30:1]};
  wire        win_end = (bitcnt == 5'd30);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      push_en <= 1'b0;
      pnd     <= 1'b0;
      pdata   <= 2'd0;
      win     <= 31'd0;
      bitcnt  <= 5'd0;
      cmd     <= 12'd0;
      win_cnt <= 4'd0;
    end
    else if (stb2 && !push_en) begin
      push_en <= 1'b1;
      pnd     <= 1'b0;
      pdata   <= sym;
    end
    else if (push_en) begin
      if (win_end) begin
        cmd[win_cnt] <= (win_nxt == GOLD) ? 1'b1 : 1'b0;
        win     <= 31'd0;
        bitcnt  <= 5'd0;
        win_cnt <= (win_cnt == 4'd11) ? 4'd0 : win_cnt + 4'd1;
      end
      else begin
        win    <= win_nxt;
        bitcnt <= bitcnt + 5'd1;
      end

      if (pnd == 1'b0) begin
        pnd   <= 1'b1;
        pdata <= {1'b0, pdata[0]};
      end
      else begin
        push_en <= 1'b0;
      end
    end
  end

endmodule

module uart_report #(
  parameter integer CLK_FREQ = 50_000_000,
  parameter integer BAUD     = 115200,
  parameter integer REP_DIV  = 10_000_000
)(
  input  wire       clk,
  input  wire       rst_n,
  input  wire [23:0] wid,
  input  wire [23:0] gap,
  input  wire [1:0]  sym,
  input  wire [11:0] cmd,
  output reg  [7:0]  tx_byte,
  output reg         tx_start,
  output wire        uart_tx
);

  reg [4:0]  ci;
  reg [1:0]  st;
  reg [23:0] rep_tick;
  reg [23:0] w_snd;
  reg [23:0] g_snd;
  reg [1:0]  s_snd;
  reg [11:0] c_snd;

  wire tx_busy;
  wire tx_done;

  function [7:0] hexc(input [3:0] v);
    hexc = (v < 4'd10) ? (8'h30 + {4'd0, v}) : (8'h37 + {4'd0, v});
  endfunction

  always @(*) begin
    case (ci)
      5'd0:  tx_byte = 8'h57;
      5'd1:  tx_byte = 8'h3D;
      5'd2:  tx_byte = hexc(w_snd[23:20]);
      5'd3:  tx_byte = hexc(w_snd[19:16]);
      5'd4:  tx_byte = hexc(w_snd[15:12]);
      5'd5:  tx_byte = hexc(w_snd[11:8]);
      5'd6:  tx_byte = hexc(w_snd[7:4]);
      5'd7:  tx_byte = hexc(w_snd[3:0]);
      5'd8:  tx_byte = 8'h20;
      5'd9:  tx_byte = 8'h47;
      5'd10: tx_byte = 8'h3D;
      5'd11: tx_byte = hexc(g_snd[23:20]);
      5'd12: tx_byte = hexc(g_snd[19:16]);
      5'd13: tx_byte = hexc(g_snd[15:12]);
      5'd14: tx_byte = hexc(g_snd[11:8]);
      5'd15: tx_byte = hexc(g_snd[7:4]);
      5'd16: tx_byte = hexc(g_snd[3:0]);
      5'd17: tx_byte = 8'h20;
      5'd18: tx_byte = 8'h53;
      5'd19: tx_byte = 8'h3D;
      5'd20: tx_byte = 8'h30 + {6'd0, s_snd};
      5'd21: tx_byte = 8'h20;
      5'd22: tx_byte = 8'h43;
      5'd23: tx_byte = 8'h3D;
      5'd24: tx_byte = hexc(c_snd[11:8]);
      5'd25: tx_byte = hexc(c_snd[7:4]);
      5'd26: tx_byte = hexc(c_snd[3:0]);
      5'd27: tx_byte = 8'h0D;
      5'd28: tx_byte = 8'h0A;
      default: tx_byte = 8'h20;
    endcase
  end

  uart_tx #(
    .CLK_FREQ (CLK_FREQ),
    .BAUD     (BAUD)
  ) u_tx (
    .clk   (clk),
    .rst_n (rst_n),
    .din   (tx_byte),
    .start (tx_start),
    .tx    (uart_tx),
    .busy  (tx_busy),
    .done  (tx_done)
  );

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ci       <= 5'd0;
      st       <= 2'd0;
      rep_tick <= 24'd0;
      w_snd    <= 24'd0;
      g_snd    <= 24'd0;
      s_snd    <= 2'd0;
      c_snd    <= 12'd0;
      tx_start <= 1'b0;
    end
    else begin
      tx_start <= 1'b0;

      case (st)
        2'd0: begin
          if (rep_tick >= REP_DIV[23:0] - 24'd1) begin
            rep_tick <= 24'd0;
            w_snd    <= wid;
            g_snd    <= gap;
            s_snd    <= sym;
            c_snd    <= cmd;
            ci       <= 5'd0;
            st       <= 2'd1;
          end
          else begin
            rep_tick <= rep_tick + 24'd1;
          end
        end

        2'd1: begin
          if (!tx_busy) begin
            tx_start <= 1'b1;
            st       <= 2'd2;
          end
        end

        2'd2: begin
          if (tx_done) begin
            if (ci == 5'd28) begin
              st <= 2'd0;
            end
            else begin
              ci <= ci + 5'd1;
              st <= 2'd1;
            end
          end
        end

        default: st <= 2'd0;
      endcase
    end
  end

endmodule

module acm9238_led_probe #(
  parameter signed  [11:0] THRESH         = 12'sd16,
  parameter integer        CONFIRM        = 8'd40,
  parameter integer        HOLD_CLK       = 20_000_000,
  parameter integer        HEART_CLK      = 25_000_000,
  parameter integer        CLK_INVERT     = 1,
  parameter integer        LED_ACTIVE_LOW = 0,
  parameter integer        BAUD           = 115200,
  parameter integer        REP_DIV        = 10_000_000
)(
  input  wire               clk,
  input  wire               rst_n,
  input  wire signed [11:0] ch1_d,
  input  wire               ch1_otr,
  output wire               adc_clk,
  output wire [3:0]         led,
  output wire               led4,
  output wire               uart_tx
);

  assign adc_clk = CLK_INVERT ? ~clk : clk;

  localparam integer USE_MSB = 1;

  wire raw_hi = USE_MSB ? (ch1_d[11] & (|ch1_d)) : (ch1_d > THRESH);

  reg [7:0] hi_cnt;
  reg       sig;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      hi_cnt <= 8'd0;
      sig    <= 1'b0;
    end
    else if (raw_hi) begin
      if (hi_cnt != 8'hFF) hi_cnt <= hi_cnt + 8'd1;
      if (hi_cnt >= CONFIRM[7:0] - 8'd1) sig <= 1'b1;
    end
    else begin
      hi_cnt <= 8'd0;
      sig    <= 1'b0;
    end
  end

  reg sig_d;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) sig_d <= 1'b0;
    else        sig_d <= sig;
  end

  wire rise = sig & ~sig_d;

  reg [31:0] hold_cnt;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)                 hold_cnt <= 32'd0;
    else if (rise)              hold_cnt <= HOLD_CLK[31:0];
    else if (hold_cnt != 32'd0) hold_cnt <= hold_cnt - 32'd1;
  end

  reg [31:0] heart_cnt;
  reg        heart;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      heart_cnt <= 32'd0;
      heart     <= 1'b0;
    end
    else if (heart_cnt >= HEART_CLK[31:0]) begin
      heart_cnt <= 32'd0;
      heart     <= ~heart;
    end
    else heart_cnt <= heart_cnt + 32'd1;
  end

  reg [3:0] led_i;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      led_i <= 4'b0000;
    end
    else begin
      led_i[0] <= 1'b0;
      led_i[1] <= (hold_cnt != 32'd0);
      led_i[2] <= ch1_otr;
      led_i[3] <= heart;
    end
  end

  assign led  = LED_ACTIVE_LOW ? ~led_i : led_i;
  assign led4 = LED_ACTIVE_LOW ? ~sig   : sig;

  wire [23:0] m_gap;
  wire [23:0] m_wid;
  wire [1:0]  m_sym;
  wire [11:0] m_cmd;
  wire [3:0]  m_win;
  wire        m_stb;
  wire [7:0]  r_byte;
  wire        r_start;

  laser_measure #(
    .RELAX_DIV (50_000_000)
  ) u_meas (
    .clk     (clk),
    .rst_n   (rst_n),
    .sig     (sig),
    .gap_lat (m_gap),
    .wid_lat (m_wid),
    .sym     (m_sym),
    .cmd     (m_cmd),
    .win_cnt (m_win),
    .gap_stb (m_stb)
  );

  uart_report #(
    .CLK_FREQ (50_000_000),
    .BAUD     (BAUD),
    .REP_DIV  (REP_DIV)
  ) u_rep (
    .clk      (clk),
    .rst_n    (rst_n),
    .wid      (m_wid),
    .gap      (m_gap),
    .sym      (m_sym),
    .cmd      (m_cmd),
    .tx_byte  (r_byte),
    .tx_start (r_start),
    .uart_tx  (uart_tx)
  );

endmodule

# FPGA 实验包 —— 全部在真实仿真器上跑通

工具链：**Icarus Verilog 14.0**（已装在本机 `C:\iverilog\bin`，用户级 PATH 已加好）。
不需要 Vivado、不需要开发板，**9 个测试台全部 PASS**（每个测试台自己判对错）。

## 怎么跑

```powershell
# 跑全部
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\run_all.ps1

# 只跑某个实验（名字支持模糊匹配）
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\run_all.ps1 -Lab dpim

# 保留波形文件（work\*.vcd），再用 vcd2txt.py 看文本波形
.\run_all.ps1 -KeepVcd
python vcd2txt.py work\tb_uart_loopback.vcd --signals clk,tx_line,rx_done
```

也可以直接双击 `run_all.cmd`。

## 实验清单

| # | RTL 模块 | 测试台 | 学到什么 | 对应你项目里的 |
| --- | --- | --- | --- | --- |
| 1 | `counter_ce.v` | `tb_counter_ce` | 计数器 / **时钟使能**（不是分频出时钟） | p15 的 50M→10M |
| 2 | `edge_detect.v` | `tb_edge_detect` | 打两拍同步 + 上升/下降沿检测 | p18 VIO 按键、p26 uart_rx 打 3 拍 |
| 3 | `debounce.v` | `tb_debounce` | 按键消抖（连续 N 拍稳定才认可） | 真实板子上的按键 |
| 4 | `fsm_seq3.v` | `tb_fsm_seq3` | **三段式状态机**（按 3 次翻转） | p24 的 IDLE→CALC_SYMBOL→CALC_GOLD→DONE |
| 5 | `uart_tx.v` | `tb_uart_loopback` | UART 发送：波特率计数 + 移位 + 帧结构 | p26/p34 的 9600bps（div=5208） |
| 6 | `uart_rx.v` | 同上（回环） | UART 接收：**中点采样**、抗频差 | p26 的中点采样与停止位校验 |
| 7 | `sync_fifo.v` | `tb_sync_fifo` | FIFO 指针/空满标志/**同时读写** | p40/p49（那两处是异步版） |
| 8 | `gold_code.v` | `tb_gold_code` | LFSR、m 序列、**优选对判定** | p8 的两个多项式 |
| 9 | `dpim_mod.v` | `tb_dpim` | DPIM 调制：时隙与间隔 | p11/p13 |
| 10 | `dpim_demod.v` | `tb_dpim` | DPIM 解调：**判决门限** | p32 的 gap/10 |
| 11 | `dds.v` | `tb_dds` | **相位累加器** + ROM 查表、输出频率公式 | p15/p16 的 DDS |


## 目录

```
labs\
├─ rtl\            11 个可综合模块（每个都有中文注释，标注对应 deck 页码）
├─ tb\             9 个自检测试台（每个最后打印 PASS / FAIL）
├─ run_all.ps1     编译 + 运行 + 汇总（带超时保护）
├─ run_all.cmd     双击运行
├─ vcd2txt.py      文本波形查看器（没装 GTKWave 也能看时序）
└─ work\           编译产物与波形（可随时删）
```

# adc_receiver — 激光信号采集、解码与串口上报

PDAPC3 光电探测器 → ACM9238 12 位 ADC → FPGA（检测 + 解码）→ 串口 → 电脑

整条通路只做一件事：**把照到探测器的激光脉冲，解成 12 位命令并通过串口发给电脑**。

## 目录

```
adc_receiver/
├── rtl/acm9238_led_probe.v      顶层 + uart_tx + laser_measure + uart_report
├── tb/tb_acm9238_probe.v        有光检测 / 去抖 / 展宽 / OTR
├── tb/tb_laser_measure.v        自适应基准与符号判决
├── tb/tb_uart_report.v          串口帧格式逐字符校验
├── constr/acm9238_led.xdc       引脚约束
├── tools/laser_decode.py        电脑端接收与显示
└── run_all.ps1                  一键跑全部仿真
```

## 数据流

```
ADC 12 位 ──► 有光判定（D11 + 去抖）
                 │
                 ├──► led4          激光指示，有光即亮
                 │
                 └──► 测脉宽 / 测间隔
                          │
                          ├──► 自适应基准（跟踪最小间隔 = 1 个时隙）
                          │         │
                          │         └──► 三比较器居中判决 ──► 符号 0~3
                          │                    │
                          │                    └──► 每符号 2 比特
                          │                              │
                          │                              └──► 31 位窗口与 GOLD 比对
                          │                                        │
                          │                                        └──► 12 位命令
                          │
                          └──► 串口上报（115200 8N1）
```

## 串口帧格式

```
W=000096 G=0003E9 S=2 C=B77<CR><LF>
```

| 字段 | 宽度 | 含义 |
| --- | --- | --- |
| `W=` | 6 位十六进制 | 脉冲宽度，单位 **20 ns**（50 MHz 一拍） |
| `G=` | 6 位十六进制 | 相邻脉冲间隔，单位同上 |
| `S=` | 1 位十进制 | 当前符号 0~3 |
| `C=` | 3 位十六进制 | 12 位解码命令 |

上报周期默认 **200 ms**（参数 `REP_DIV`），与脉冲速率解耦，所以低速率和高速率都不会冲掉串口。

## 引脚

| 信号 | 引脚 | 说明 |
| --- | --- | --- |
| clk | Y9 | 板载 50 MHz |
| rst_n | H18 | KEY0 |
| adc_clk | U11 | → ACM9238 CH1_CLK，P7 第 2 脚 |
| ch1_d[0..11] | U12/U9/U10/Y10/Y11/W7/V7/Y5/Y6/V4/V5/U4 | P7 第 1~16 脚 |
| ch1_otr | T4 | P7 第 15 脚 |
| led[0..3] | P20/P21/R20/R21 | 板载 LED0~3 |
| led4 | R19 | 板载 LED4，**激光指示** |
| uart_tx | **AA7** | **P7 第 29 脚**（ACM9238 该脚 NC），接 USB-TTL 的 RX |

> 板载 USB-UART 占用了 U11/U12，与本设计的 ADC 时钟和数据线冲突，因此串口另行引出。

## LED 含义

| LED | 含义 |
| --- | --- |
| led[0] | 恒灭（保留端口） |
| led[1] | 收到光脉冲，亮 0.4 秒 |
| led[2] | OTR 超量程 |
| led[3] | 心跳 1 Hz |
| **led4** | **激光指示，有光即亮** |

本板 LED 为**高电平点亮**。

## 仿真

依赖 [Icarus Verilog](https://steveicarus.github.io/iverilog/)。

```powershell
cd adc_receiver
powershell -ExecutionPolicy Bypass -File .\run_all.ps1
```

三组测试台当前均为 PASS：

| 测试台 | 验证内容 | 结果 |
| --- | --- | --- |
| tb_acm9238_probe | 噪声不误触、脉冲点亮、展宽结束、OTR、毛刺过滤 | 5/5 |
| tb_laser_measure | 间隔 100/200/300/400 → 符号 0/1/2/3 | PASS |
| tb_uart_report | 帧内容逐字符比对 | PASS |

## 电脑端

```powershell
pip install pyserial
python tools/laser_decode.py            # 列出串口
python tools/laser_decode.py COM5       # 开始接收
```

## 关键参数

| 参数 | 默认 | 说明 |
| --- | --- | --- |
| THRESH | 16 | 阈值判决门限（USE_MSB=0 时生效） |
| CONFIRM | 40 | 连续 N 点才算有光，800 ns @50 MHz |
| HOLD_CLK | 20e6 | led[1] 展宽 0.4 s |
| CLK_INVERT | 1 | ADC 时钟取反 |
| LED_ACTIVE_LOW | 0 | 本板高电平点亮 |
| BAUD | 115200 | 串口波特率 |
| REP_DIV | 10e6 | 上报周期 200 ms |

## 已知局限

1. **命令没有帧同步**。Gold 码按 31 位一组比对，但真实光信号没有起始标志，复位后第一批窗口的起点是任意的。结果错位时按一次复位重试即可；要彻底解决需要加滑动相关做帧同步搜索。
2. **OTR 可能常亮**。模拟前端直流偏置未标定，OTR 指示仅供参考，不影响有光检测与解码。
3. **ch1_d[0..10] 逻辑上未使用**。为了不让综合裁掉这些输入端口（否则 xdc 会报端口不存在），`raw_hi` 里保留了 `& (|ch1_d)` 的写法，逻辑等价但会引用全部 12 位，请勿删除。

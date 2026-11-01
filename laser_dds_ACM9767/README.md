# laser_dds_ACM9767 — 发射端 DDS 波形回放工程

把预先编码好的 DPIM 脉冲串按设定速率还原成 14 位数字量，经 ACM9767 转换成 0~5 V 模拟电压，驱动激光发射。

## 结构

```
laser_dds_ACM9767.xpr                        Vivado 2020.2 工程
laser_dds_ACM9767.srcs/
  sources_1/new/laser_ACM9767.v              顶层
  sources_1/new/DDS_module.v                 DDS 回放引擎
  sources_1/ip/MMCM/                         时钟：50 MHz → 125 MHz
  sources_1/ip/blk_mem_gen_0/                波形表块 RAM
  sources_1/ip/TTL/                          输出整形
  sources_1/ip/vio_0/                        VIO 调试核（3 个 probe）
  constrs_1/new/laser_ACM9767.xdc            引脚约束
dac_signal.coe                               诱骗波形表（92480 点）
dac_ttl.coe                                  TTL 波形表
```

## 工作原理

相位累加器每个时钟把频率控制字累加上去，取高位当表地址。改频率控制字只改变**回放速率**，波形数据一个字节都不用动。

波形表按 8192 点（2¹³）一段切成 16 段，段基址 = 编号 << 13，段内偏移取相位累加器低 13 位 —— 段长是 2 的幂，取低位即等于对段长取模，回绕不需要比较器和减法器，整条地址通路只剩一级加法。

## VIO 三个控制位

| 信号 | 作用 |
| --- | --- |
| `cha_fword_flag` | 回放速率，8 档（每次上升沿 +1，循环） |
| `cha_pword_flag` | 起始相位，8 档 |
| `mode_sela_flag` | 输出开关 |

> 这三个都是**电平**型 probe，必须在 Hardware Manager 里「先置 1 再置 0」才算一次完整操作 —— 只有上升沿才产生单周期脉冲。

## 已知边界

| 项 | 说明 |
| --- | --- |
| `wrta` 与 `clka` 同源 | 写使能与写时钟取自同一时钟，功能正常但对 DAC 建立时间无额外裕量 |
| `fword` 档 0 的预设值 | 与理论 34 档不同，实测以第 3 档为准 |
| `mode_sel` 位宽 | 2 bit 定义截断为 1 bit，实际只有两态 |
| 波形表长度 | 128072 与 92480 的 wrap 差异，需按实际 COE 长度核对 |

以上不影响演示功能，报告中按「已知边界」口径表述。

## 构建

Vivado 2020.2 打开 `.xpr` → Generate Bitstream（约 5~10 分钟）。

仓库不含 `runs/`、`cache/`、`ip_user_files/` 等构建产物，首次打开 Vivado 会自动重建。

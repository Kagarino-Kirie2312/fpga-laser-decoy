#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
文本波形查看器：把 VCD 波形渲染成终端里的 ASCII 时序图。

为什么要它：GTKWave 的 Windows 二进制在 SourceForge 上对本机返回 403 拿不到，
而"看波形"是学 FPGA 最核心的技能之一。这个脚本让波形不依赖任何 GUI。

用法：
    python vcd2txt.py work\\tb_uart_loopback.vcd
    python vcd2txt.py xx.vcd --signals clk,tx_line,rx_done --cols 100
    python vcd2txt.py xx.vcd --from 0 --to 5000        # 只看一段时间窗
    python vcd2txt.py xx.vcd --list                    # 列出信号

纯标准库实现。

★ 一个真实的 VCD 坑（本脚本专门处理）：
  Icarus Verilog 会把**电气相连的线网别名成同一个标识符**。
  例如 tb 里的 `tx_line` 和它连到的 `u_tx.tx` 会共用同一个 VCD code，
  于是文件里出现两行 `$var ... ! tx_line` 和 `$var ... ! tx`。
  如果按 code 建字典，后一条会覆盖前一条，导致**按名字查不到信号**。
  所以这里给每个 code 保存"别名列表"，任一别名匹配就算命中。
"""

import argparse
import sys

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass


def parse_vcd(path):
    """返回 (signals, changes, times)

    signals: {code: {"names": [别名...], "width": int}}
    changes: {code: [(time, value_str), ...]}
    """
    signals, changes = {}, {}
    cur_time = 0
    in_defs = True

    with open(path, "r", encoding="utf-8", errors="replace") as f:
        for raw in f:
            line = raw.strip()
            if not line:
                continue

            if in_defs:
                if line.startswith("$var"):
                    parts = line.split()
                    if len(parts) >= 5:
                        code = parts[3]
                        name = parts[4]
                        width = int(parts[2]) if parts[2].isdigit() else 1
                        ent = signals.setdefault(code, {"names": [], "width": width})
                        if name not in ent["names"]:
                            ent["names"].append(name)
                    continue
                if line.startswith("$enddefinitions"):
                    in_defs = False
                continue

            if line[0] == "#":
                cur_time = int(line[1:])
                continue
            if line[0] in "01xzXZ":
                code = line[1:]
                if code in signals:
                    changes.setdefault(code, []).append((cur_time, line[0]))
                continue
            if line[0] in "bB":
                parts = line.split()
                if len(parts) == 2 and parts[1] in signals:
                    changes.setdefault(parts[1], []).append((cur_time, parts[0][1:]))
                continue

    times = sorted({t for seq in changes.values() for t, _ in seq})
    return signals, changes, times


def value_at(seq, t, width, default="x"):
    """取某信号在时间 t 的值（用最后一次变化的值）。"""
    val = default
    for ct, cv in seq:
        if ct <= t:
            val = cv
        else:
            break
    if len(val) < width:
        val = val.rjust(width, val[0] if val else "x")
    return val


def best_name(ent):
    """别名里挑一个最好看的显示名（最长的那个通常是模块内的完整名）。"""
    return max(ent["names"], key=len)


def render(signals, changes, times, want, cols, t_from, t_to):
    if not times:
        print("（波形里没有任何值变化）")
        return
    t0 = times[0] if t_from is None else t_from
    t1 = times[-1] if t_to is None else t_to
    span = max(t1 - t0, 1)

    if want:
        sel = []
        for code, ent in signals.items():
            if any(n in want for n in ent["names"]):
                sel.append((code, ent))
    else:
        sel = [(c, e) for c, e in signals.items() if e["width"] == 1][:12]

    if not sel:
        print("没有匹配的信号。用 --list 看看有哪些名字。")
        return

    namew = max(len(best_name(e)) for _, e in sel) + 2
    print(f"\nVCD: {t0} .. {t1}（{len(times)} 个变化点），每列 = {span/cols:.4g} 时间单位")
    if want:
        missing = [w for w in want if not any(w in e["names"] for _, e in sel)]
        if missing:
            print(f"  注意：这些名字没找到 -> {missing}")
    print()

    for code, ent in sel:
        seq = changes.get(code, [])
        row = []
        for k in range(cols):
            t = t0 + int(span * k / cols)
            v = value_at(seq, t, ent["width"])
            row.append(v[-1] if ent["width"] == 1 else ("1" if v.lstrip("0") else "0"))
        label = best_name(ent)
        if len(ent["names"]) > 1:
            label += "*"                      # * 表示这个名字有别名（相连线网）
        print(f"  {label:<{namew}} |{''.join(row)}|")

    print(f"  {'':<{namew}} +{'-' * cols}+")
    left, right = str(t0), str(t1)
    print(f"  {'':<{namew}}  {left}{' ' * max(cols - len(left) - len(right), 1)}{right}")


def main():
    ap = argparse.ArgumentParser(description="把 VCD 波形渲染成文本时序图")
    ap.add_argument("vcd", help="VCD 文件路径")
    ap.add_argument("--signals", help="要显示的信号名，逗号分隔")
    ap.add_argument("--cols", type=int, default=80, help="横向列数，默认 80")
    ap.add_argument("--from", dest="t_from", type=int, help="起始时间")
    ap.add_argument("--to", dest="t_to", type=int, help="结束时间")
    ap.add_argument("--list", action="store_true", help="只列出信号，不画图")
    args = ap.parse_args()

    signals, changes, times = parse_vcd(args.vcd)

    if args.list:
        print(f"{len(signals)} 个标识符（* 表示有别名）：")
        for code, ent in sorted(signals.items(), key=lambda kv: best_name(kv[1])):
            alias = "  <- " + ", ".join(ent["names"]) if len(ent["names"]) > 1 else ""
            n = len(changes.get(code, []))
            print(f"  {best_name(ent):<26} 位宽 {ent['width']:<3} 变化 {n:>6} 次{alias}")
        return 0

    want = [s.strip() for s in args.signals.split(",")] if args.signals else None
    render(signals, changes, times, want, args.cols, args.t_from, args.t_to)
    return 0


if __name__ == "__main__":
    sys.exit(main())

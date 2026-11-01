import re
import sys
import time

try:
    import serial
    from serial.tools import list_ports
except ImportError:
    print("缺少 pyserial，请先运行：pip install pyserial")
    sys.exit(1)

CLK_HZ = 50_000_000
TICK_US = 1e6 / CLK_HZ

FRAME = re.compile(
    r"W=([0-9A-Fa-f]{6})\s+G=([0-9A-Fa-f]{6})\s+S=([0-3])\s+C=([0-9A-Fa-f]{3})"
)

SYM_NAME = {0: "00", 1: "01", 2: "10", 3: "11"}
GOLD = 0b0010111100101101001111010000000


def list_serial_ports():
    ports = list(list_ports.comports())
    if not ports:
        print("没有找到任何串口。")
        return
    print("可用串口：")
    for p in ports:
        print("  {:12s} {}".format(p.device, p.description))
    print("\n用法：python laser_decode.py COM5 [波特率]")
    print("      默认波特率 115200，需与 FPGA 端 BAUD 参数一致")


def sym_sequence(cmd):
    bits = [(cmd >> i) & 1 for i in range(12)]
    return "".join(str(b) for b in bits)


def main():
    if len(sys.argv) < 2:
        list_serial_ports()
        return

    port = sys.argv[1]
    baud = int(sys.argv[2]) if len(sys.argv) > 2 else 115200

    ser = serial.Serial(port, baud, timeout=1)
    time.sleep(0.2)

    frames = 0
    last_cmd = None
    hist = []

    print("串口 {} 已打开 @ {}".format(port, baud))
    print("等待 FPGA 上报（Ctrl+C 退出）\n")
    print("{:>9s} {:>9s} {:>5s} {:>7s}   {}".format(
        "脉宽(us)", "间隔(us)", "符号", "命令", "备注"))

    try:
        while True:
            raw = ser.readline()
            if not raw:
                continue
            text = raw.decode("ascii", errors="ignore").strip()
            m = FRAME.search(text)
            if not m:
                continue

            w = int(m.group(1), 16)
            g = int(m.group(2), 16)
            s = int(m.group(3))
            cmd = int(m.group(4), 16)

            w_us = w * TICK_US
            g_us = g * TICK_US

            hist.append(g)
            if len(hist) > 128:
                hist.pop(0)

            note = ""
            if last_cmd is not None and cmd != last_cmd:
                note = "命令变化"
            if last_cmd is not None and cmd != 0 and cmd != last_cmd:
                note = "命令变化 0x%03X -> 0x%03X" % (last_cmd, cmd)
            last_cmd = cmd
            frames += 1

            print("{:9.2f} {:9.2f} {:>5s} 0x{:03X}   {}".format(
                w_us, g_us, SYM_NAME[s], cmd, note))

            if frames % 20 == 0 and hist:
                ordered = sorted(hist)
                lo = ordered[len(ordered) // 8]
                hi = ordered[-len(ordered) // 8]
                print("    [统计] 第 {} 帧，最近 {} 个间隔范围 {:.2f} ~ {:.2f} us".format(
                    frames, len(hist), lo * TICK_US, hi * TICK_US))

    except KeyboardInterrupt:
        print("\n已停止，共收到 {} 帧。".format(frames))
    finally:
        ser.close()


if __name__ == "__main__":
    main()

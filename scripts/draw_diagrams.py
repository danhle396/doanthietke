#!/usr/bin/env python3
"""Block diagrams and FSMs for the report (matplotlib, because mmdc /
wavedrom-cli are not installed). The Mermaid sources of the same diagrams are
written next to the PNGs in docs/report/hinh/*.mmd.

Usage: draw_diagrams.py
"""
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.patches import FancyBboxPatch, Circle  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs/report/hinh"
INK, INK2, SURF, LINE = "#0b0b0b", "#52514e", "#fcfcfb", "#52514e"
FILL = ["#d5e5f7", "#fbe1d6", "#d2f0e4", "#fbecc8", "#f8dce6", "#e4e3df"]


def canvas(w, h, title):
    fig, ax = plt.subplots(figsize=(w, h))
    fig.patch.set_facecolor(SURF)
    ax.set_facecolor(SURF)
    ax.set_xlim(0, w * 10)
    ax.set_ylim(0, h * 10)
    ax.axis("off")
    ax.set_title(title, loc="left", fontsize=11, color=INK)
    return fig, ax


def box(ax, x, y, w, h, text, fill=0, fs=8.5):
    ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.3,rounding_size=1.2",
                                facecolor=FILL[fill], edgecolor=LINE, linewidth=1))
    ax.text(x + w / 2, y + h / 2, text, ha="center", va="center", fontsize=fs, color=INK)
    return (x, y, w, h)


def arrow(ax, x0, y0, x1, y1, text="", style="-|>", color=LINE, fs=7.5, rad=0.0, tx=None, ty=None):
    ax.annotate("", xy=(x1, y1), xytext=(x0, y0),
                arrowprops=dict(arrowstyle=style, color=color, linewidth=1.1,
                                connectionstyle=f"arc3,rad={rad}"))
    if text:
        ax.text(tx if tx is not None else (x0 + x1) / 2, ty if ty is not None else (y0 + y1) / 2 + 1.2,
                text, ha="center", va="bottom", fontsize=fs, color=INK2)


def save(fig, name, mermaid):
    OUT.mkdir(parents=True, exist_ok=True)
    fig.tight_layout()
    fig.savefig(OUT / f"{name}.png", dpi=150)
    plt.close(fig)
    (OUT / f"{name}.mmd").write_text(mermaid.strip() + "\n")


def pipeline():
    fig, ax = canvas(13, 6, "Hình 2.1. Pipeline 5 tầng của rv_core")
    xs = [3, 27, 51, 75, 99]
    names = ["IF\npc_q, BTB+BHT\n(BP_MODE 2)\nchọn PC kế", "ID\ngiải nén C\ndecoder, imm\nregfile 2R1W",
             "EX\nforward mux\nALU, branch_unit\nmuldiv", "MEM\nLSU (dbus)\nCSR, trap\nMRET/FENCE.I",
             "WB\nghi regfile\nminstret, hpm\ncommit log"]
    for i, (x, n) in enumerate(zip(xs, names)):
        box(ax, x, 22, 18, 18, n, fill=i % 5)
    regs = ["if_id", "id_ex", "ex_mem", "mem_wb"]
    for i, r in enumerate(regs):
        x = xs[i] + 19.5
        ax.add_patch(FancyBboxPatch((x, 20), 2.5, 22, boxstyle="square,pad=0", facecolor="#c3c2b7",
                                    edgecolor=LINE))
        ax.text(x + 1.25, 44, r, ha="center", fontsize=7.5, color=INK2)
    # forward paths
    arrow(ax, 77 + 5, 21, 55, 21, "", rad=-0.3)
    arrow(ax, 101 + 5, 21, 57, 20, "", rad=-0.35)
    ax.text(48, 14.5, "forward: ex_mem → EX (ALU/MulDiv/link), mem_wb → EX (mọi kết quả)", fontsize=7.5,
            color=INK2, ha="center")
    # redirects
    arrow(ax, 60, 41, 12, 41, "", rad=0.35)
    ax.text(36, 52, "sai dự đoán (EX): flush if_id, id_ex", fontsize=7.5, color="#b8452a", ha="center")
    arrow(ax, 84, 41, 10, 41, "", rad=0.42, color="#b8452a")
    ax.text(60, 57, "trap / MRET / FENCE.I (MEM): flush if_id, id_ex, ex_mem", fontsize=7.5,
            color="#b8452a", ha="center")
    arrow(ax, 36, 40, 14, 40, "", rad=0.25)
    ax.text(24, 47, "redirect ID", fontsize=7.5, color=INK2, ha="center")
    box(ax, 3, 2, 18, 8, "RAM cổng I\n(đọc tổ hợp)", fill=5)
    arrow(ax, 12, 10, 12, 22, "ibus", style="<|-|>")
    box(ax, 75, 2, 18, 8, "dbus → xbar\nRAM / APB", fill=5)
    arrow(ax, 84, 10, 84, 22, "dbus", style="<|-|>")
    save(fig, "pipeline", """
flowchart LR
  IF[IF: pc_q, BTB+BHT, chọn PC] -->|if_id| ID[ID: giải nén C, decode, regfile]
  ID -->|id_ex| EX[EX: forward, ALU, branch, muldiv]
  EX -->|ex_mem| MEM[MEM: LSU, CSR, trap]
  MEM -->|mem_wb| WB[WB: regfile, counters]
  MEM -. forward .-> EX
  WB -. forward .-> EX
  EX -. sai dự đoán .-> IF
  MEM -. trap/mret/fence.i .-> IF
  ID -. redirect .-> IF
""")


def soc():
    fig, ax = canvas(12, 7, "Hình 3.1. Sơ đồ khối SoC")
    box(ax, 4, 45, 26, 18, "rv_core\nIF ID EX MEM WB\nBHT/BTB  MulDiv  CSR", fill=0, fs=9)
    box(ax, 45, 52, 22, 10, "ram_dp 128 KB\ncổng I | cổng D", fill=5)
    box(ax, 45, 34, 22, 9, "dbus_xbar\n(Wishbone)", fill=5)
    box(ax, 80, 34, 22, 9, "apb_bridge\nWishbone → APB4", fill=3)
    arrow(ax, 30, 58, 45, 58, "ibus (Wishbone)")
    arrow(ax, 30, 48, 45, 40, "dbus (Wishbone)")
    arrow(ax, 56, 43, 56, 52, "")
    arrow(ax, 67, 38.5, 80, 38.5, "")
    names = ["UART\nslot 0", "SPI\nslot 1", "TIMER64\nslot 2", "GPIO\nslot 3", "INTC\nslot 4", "SIM_CTRL\nslot 15"]
    for i, n in enumerate(names):
        x = 4 + i * 19
        box(ax, x, 10, 15, 10, n, fill=1 if i < 2 else 2)
        arrow(ax, 91, 34, x + 7.5, 20, "", rad=0.0)
    ax.text(60, 2.5, "uart_tx/rx      sclk/mosi/miso/cs_n[3:0]      mtip/msip/mtime → lõi      gpio[15:0]      "
            "meip = |(PENDING & ENABLE)", fontsize=7.5, color=INK2, ha="center")
    box(ax, 4, 30, 18, 7, "rst_sync", fill=5)
    save(fig, "soc", """
flowchart LR
  CORE[rv_core] -- ibus Wishbone --> RAM[(ram_dp 128 KB)]
  CORE -- dbus Wishbone --> XBAR[dbus_xbar]
  XBAR -- Wishbone --> RAM
  XBAR -- Wishbone --> BR[apb_bridge]
  BR --> UART & SPI & TIMER[TIMER64] & GPIO & INTC & SIM[SIM_CTRL]
  TIMER -- mtip/msip/mtime --> CORE
  UART & SPI & GPIO --> INTC -- meip --> CORE
""")


def fsm(name, title, states, edges, mermaid, size=(9, 4.2)):
    fig, ax = canvas(size[0], size[1], title)
    pos = {}
    for i, (s, (x, y)) in enumerate(states.items()):
        ax.add_patch(Circle((x, y), 6.5, facecolor=FILL[i % 5], edgecolor=LINE, linewidth=1))
        ax.text(x, y, s, ha="center", va="center", fontsize=8, color=INK)
        pos[s] = (x, y)
    for a, b, lab, rad in edges:
        (x0, y0), (x1, y1) = pos[a], pos[b]
        if a == b:
            ax.annotate("", xy=(x0 + 3, y0 + 6), xytext=(x0 - 3, y0 + 6),
                        arrowprops=dict(arrowstyle="-|>", color=LINE, connectionstyle="arc3,rad=-1.6"))
            ax.text(x0, y0 + 12.5, lab, ha="center", fontsize=7, color=INK2)
            continue
        dx, dy = x1 - x0, y1 - y0
        d = (dx * dx + dy * dy) ** 0.5
        sx, sy = x0 + dx / d * 6.8, y0 + dy / d * 6.8
        ex, ey = x1 - dx / d * 6.8, y1 - dy / d * 6.8
        ax.annotate("", xy=(ex, ey), xytext=(sx, sy),
                    arrowprops=dict(arrowstyle="-|>", color=LINE, linewidth=1.1,
                                    connectionstyle=f"arc3,rad={rad}"))
        # midpoint of matplotlib's arc3 Bezier: M + rad * (dy, -dx) / 2
        mx = (sx + ex) / 2 + rad * (ey - sy) / 2
        my = (sy + ey) / 2 - rad * (ex - sx) / 2
        below = (-rad * (ex - sx)) < 0 or (rad == 0 and False)
        ax.text(mx, my + (-3.2 if below else 2.6), lab, ha="center", fontsize=7, color=INK2)
    save(fig, name, mermaid)


def main():
    pipeline()
    soc()
    fsm("apb_fsm", "Hình 3.2. FSM của apb_bridge",
        {"IDLE": (12, 22), "SETUP": (45, 22), "ACCESS": (78, 22)},
        [("IDLE", "SETUP", "CYC & STB: chốt PADDR/PWRITE/PWDATA/PSTRB", 0.25),
         ("SETUP", "ACCESS", "PSEL=1, PENABLE=0", 0.25),
         ("ACCESS", "ACCESS", "PREADY=0 (wait)", 0),
         ("ACCESS", "IDLE", "PREADY=1: ACK, hoặc ERR nếu PSLVERR", 0.45)],
        """
stateDiagram-v2
  [*] --> IDLE
  IDLE --> SETUP: CYC & STB
  SETUP --> ACCESS
  ACCESS --> ACCESS: !PREADY
  ACCESS --> IDLE: PREADY / ACK or ERR
""")
    fsm("uart_rx_fsm", "Hình 3.3. FSM bộ thu UART (lấy mẫu ×16)",
        {"IDLE": (10, 22), "START": (32, 22), "DATA": (54, 22), "PARITY": (76, 30), "STOP": (76, 10)},
        [("IDLE", "START", "rx=0", 0.3), ("START", "IDLE", "8 tick, rx=1 (giả)", 0.3),
         ("START", "DATA", "8 tick, rx=0", 0.2), ("DATA", "DATA", "16 tick: 1 bit", 0),
         ("DATA", "PARITY", "8 bit, có parity", 0.15), ("DATA", "STOP", "8 bit", -0.15),
         ("PARITY", "STOP", "16 tick", 0.3), ("STOP", "IDLE", "16 tick: lấy stop, đẩy byte", -0.35)],
        """
stateDiagram-v2
  [*] --> IDLE
  IDLE --> START: rx = 0
  START --> IDLE: 8 tick, rx = 1
  START --> DATA: 8 tick, rx = 0
  DATA --> DATA: 16 tick / bit
  DATA --> PARITY: 8 bit, parity
  DATA --> STOP: 8 bit
  PARITY --> STOP: 16 tick
  STOP --> IDLE: 16 tick, push byte
""", size=(9, 4.6))
    fsm("spi_fsm", "Hình 3.4. FSM của SPI master",
        {"IDLE": (12, 22), "XFER": (45, 22), "GAP": (78, 22)},
        [("IDLE", "XFER", "EN && TX có byte: pop", 0.25), ("XFER", "XFER", "nửa chu kỳ: đảo SCLK", 0),
         ("XFER", "GAP", "cạnh thứ 16", 0.25), ("GAP", "XFER", "còn byte", 0.35),
         ("GAP", "IDLE", "hết byte: DONE", 0.45)],
        """
stateDiagram-v2
  [*] --> IDLE
  IDLE --> XFER: EN && TX not empty
  XFER --> XFER: half period, toggle SCLK
  XFER --> GAP: 16th edge
  GAP --> XFER: more bytes
  GAP --> IDLE: TX empty (DONE)
""")
    fsm("divider_fsm", "Hình 2.2. FSM bộ chia lặp",
        {"IDLE": (12, 22), "BUSY": (45, 22), "DONE": (78, 22)},
        [("IDLE", "BUSY", "DIV hợp lệ, không đặc biệt", 0.25), ("BUSY", "BUSY", "32 vòng", 0),
         ("BUSY", "DONE", "vòng cuối", 0.25), ("DONE", "IDLE", "lệnh rời EX", 0.45),
         ("BUSY", "IDLE", "kill", -0.35)],
        """
stateDiagram-v2
  [*] --> IDLE
  IDLE --> BUSY: start
  BUSY --> BUSY: 32 iterations
  BUSY --> DONE
  DONE --> IDLE: advance
  BUSY --> IDLE: kill
""")
    print("[diagrams] " + ", ".join(sorted(p.name for p in OUT.glob("*.png"))))


if __name__ == "__main__":
    main()

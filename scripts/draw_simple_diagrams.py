"""Sơ đồ khối đơn giản cho báo cáo.

Mỗi sơ đồ được mô tả một lần (hộp, mũi tên, nhãn) rồi xuất ra hai dạng:
  docs/diagrams/so_do_khoi.drawio   (mở và sửa bằng draw.io, mỗi sơ đồ một trang)
  docs/diagrams/png/so_do_khoi_*.png      (ảnh dùng trong báo cáo)

Chạy: python scripts/draw_simple_diagrams.py
"""
import os
from xml.sax.saxutils import escape

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, Rectangle

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "docs", "diagrams")
PNG_DIR = os.path.join(OUT_DIR, "png")

plt.rcParams["font.family"] = ["Arial", "DejaVu Sans"]

# fill, stroke
C = {
    "cpu": ("#DAE8FC", "#6C8EBF"),
    "mem": ("#D5E8D4", "#82B366"),
    "bus": ("#FFE6CC", "#D79B00"),
    "per": ("#F8CECC", "#B85450"),
    "tim": ("#E1D5E7", "#9673A6"),
    "ctl": ("#FFF2CC", "#D6B656"),
    "gry": ("#F5F5F5", "#666666"),
    "wht": ("#FFFFFF", "#333333"),
    "box": ("#FAFAFA", "#999999"),
}
LINE = {"data": "#333333", "irq": "#B85450", "fwd": "#2E7D32", "ctl": "#B85450", "upd": "#7B4FA0"}


FS = 1.35  # phóng chữ để khi thu sơ đồ vào khổ 16 cm chữ vẫn khoảng 7–8 pt


class Diagram:
    def __init__(self, name, w, h):
        self.name, self.w, self.h = name, w, h
        self.items = []

    def box(self, x, y, w, h, title, sub="", color="wht", fs=13, rot=False, group=False, align="center"):
        self.items.append(("box", dict(x=x, y=y, w=w, h=h, title=title, sub=sub, color=color, fs=round(fs * FS),
                                       rot=rot, group=group, align=align)))

    def line(self, pts, kind="data", label="", lpos=None, arrow=True, both=False, dashed=False, fs=11):
        self.items.append(("line", dict(pts=pts, kind=kind, label=label, lpos=lpos, arrow=arrow, both=both,
                                        dashed=dashed, fs=round(fs * FS))))

    def text(self, x, y, s, fs=11, color="#333333", bold=False):
        self.items.append(("text", dict(x=x, y=y, s=s, fs=round(fs * FS), color=color, bold=bold)))

    # ------------------------------------------------------------------ PNG
    def png(self, path, dpi=220):
        k = 0.72  # 1 đơn vị = 0,01 inch = 0,72 pt
        fig = plt.figure(figsize=(self.w / 100, self.h / 100), dpi=dpi)
        ax = fig.add_axes([0, 0, 1, 1])
        ax.set_xlim(0, self.w); ax.set_ylim(self.h, 0); ax.axis("off")
        for kind, d in self.items:
            if kind == "box":
                fill, stroke = C[d["color"]]
                if d["group"]:
                    ax.add_patch(Rectangle((d["x"], d["y"]), d["w"], d["h"], fc=fill, ec=stroke, lw=1.0, ls="--"))
                    ax.text(d["x"] + 10, d["y"] + 8, d["title"], fontsize=d["fs"] * k, fontweight="bold",
                            va="top", ha="left", color="#333333")
                    continue
                ax.add_patch(FancyBboxPatch((d["x"], d["y"]), d["w"], d["h"],
                                            boxstyle="round,pad=0,rounding_size=6", fc=fill, ec=stroke, lw=1.2))
                cx, cy = d["x"] + d["w"] / 2, d["y"] + d["h"] / 2
                if d["rot"]:
                    ax.text(cx, cy, d["title"], rotation=90, fontsize=d["fs"] * k, fontweight="bold",
                            ha="center", va="center")
                    continue
                sub_lines = d["sub"].split("\n") if d["sub"] else []
                lh_t, lh_s = d["fs"] * 1.25, (d["fs"] - 2) * 1.3
                total = lh_t * len(d["title"].split("\n")) + lh_s * len(sub_lines)
                y0 = cy - total / 2
                for t in d["title"].split("\n"):
                    ax.text(cx, y0 + lh_t / 2, t, fontsize=d["fs"] * k, fontweight="bold", ha="center", va="center")
                    y0 += lh_t
                for s in sub_lines:
                    ax.text(cx, y0 + lh_s / 2, s, fontsize=(d["fs"] - 2) * k, ha="center", va="center",
                            color="#222222")
                    y0 += lh_s
            elif kind == "line":
                col = LINE[d["kind"]]
                ls = (0, (5, 3)) if d["dashed"] else "-"
                pts = d["pts"]
                xs, ys = [p[0] for p in pts], [p[1] for p in pts]
                ax.plot(xs[:-1] + [xs[-1]], ys[:-1] + [ys[-1]], color=col, lw=1.4, ls=ls, solid_capstyle="butt")
                st = dict(arrowstyle="-|>", color=col, lw=1.4, mutation_scale=12, shrinkA=0, shrinkB=0)
                if d["arrow"]:
                    ax.annotate("", xy=pts[-1], xytext=pts[-2], arrowprops=st)
                if d["both"]:
                    ax.annotate("", xy=pts[0], xytext=pts[1], arrowprops=st)
                if d["label"]:
                    lx, ly = d["lpos"] or ((pts[0][0] + pts[1][0]) / 2, (pts[0][1] + pts[1][1]) / 2)
                    ax.text(lx, ly, d["label"], fontsize=d["fs"] * k, ha="center", va="center", color=col,
                            bbox=dict(fc="white", ec="none", pad=1.2))
            elif kind == "text":
                ax.text(d["x"], d["y"], d["s"], fontsize=d["fs"] * k, ha="center", va="center", color=d["color"],
                        fontweight="bold" if d["bold"] else "normal")
        fig.savefig(path, dpi=dpi, facecolor="white")
        plt.close(fig)

    # ------------------------------------------------------------------ draw.io
    def drawio(self, page_id):
        cells, n = [], [2]

        def nid():
            n[0] += 1
            return f"{page_id}_{n[0]}"

        for kind, d in self.items:
            if kind == "box":
                fill, stroke = C[d["color"]]
                if d["group"]:
                    style = (f"rounded=0;whiteSpace=wrap;html=1;dashed=1;fillColor={fill};strokeColor={stroke};"
                             f"verticalAlign=top;align=left;spacingLeft=8;fontStyle=1;fontSize={d['fs']};")
                    val = escape(d["title"])
                else:
                    style = (f"rounded=1;arcSize=8;whiteSpace=wrap;html=1;fillColor={fill};strokeColor={stroke};"
                             f"fontSize={d['fs']};" + ("horizontal=0;fontStyle=1;" if d["rot"] else ""))
                    val = "<b>" + escape(d["title"]).replace("\n", "<br>") + "</b>"
                    if d["rot"]:
                        val = escape(d["title"])
                    if d["sub"]:
                        val += f'<br><font style="font-size:{d["fs"] - 2}px">' + \
                               escape(d["sub"]).replace("\n", "<br>") + "</font>"
                cells.append(f'<mxCell id="{nid()}" value="{escape(val, {chr(34): "&quot;"})}" style="{style}" '
                             f'vertex="1" parent="1"><mxGeometry x="{d["x"]}" y="{d["y"]}" width="{d["w"]}" '
                             f'height="{d["h"]}" as="geometry"/></mxCell>')
            elif kind == "line":
                col = LINE[d["kind"]]
                style = (f"html=1;rounded=0;strokeColor={col};strokeWidth=1.5;fontColor={col};fontSize={d['fs']};"
                         f"labelBackgroundColor=#FFFFFF;endArrow={'block' if d['arrow'] else 'none'};endFill=1;"
                         f"startArrow={'block' if d['both'] else 'none'};startFill=1;"
                         + ("dashed=1;" if d["dashed"] else ""))
                pts = d["pts"]
                mid = "".join(f'<mxPoint x="{p[0]}" y="{p[1]}"/>' for p in pts[1:-1])
                eid = nid()
                cells.append(f'<mxCell id="{eid}" value="" style="{style}" edge="1" parent="1">'
                             f'<mxGeometry relative="1" as="geometry">'
                             f'<mxPoint x="{pts[0][0]}" y="{pts[0][1]}" as="sourcePoint"/>'
                             f'<mxPoint x="{pts[-1][0]}" y="{pts[-1][1]}" as="targetPoint"/>'
                             + (f'<Array as="points">{mid}</Array>' if mid else "") +
                             '</mxGeometry></mxCell>')
                if d["label"]:
                    lx, ly = d["lpos"] or ((pts[0][0] + pts[1][0]) / 2, (pts[0][1] + pts[1][1]) / 2)
                    w = 9 * len(d["label"]) * d["fs"] / 13 + 10
                    cells.append(f'<mxCell id="{nid()}" value="{escape(d["label"])}" style="text;html=1;align=center;'
                                 f'verticalAlign=middle;fontSize={d["fs"]};fontColor={col};labelBackgroundColor=#FFFFFF;"'
                                 f' vertex="1" parent="1"><mxGeometry x="{lx - w / 2}" y="{ly - 10}" width="{w}" '
                                 f'height="20" as="geometry"/></mxCell>')
            elif kind == "text":
                w = 9 * len(d["s"]) + 10
                cells.append(f'<mxCell id="{nid()}" value="{escape(d["s"])}" style="text;html=1;align=center;'
                             f'verticalAlign=middle;fontSize={d["fs"]};fontColor={d["color"]};'
                             f'{"fontStyle=1;" if d["bold"] else ""}" vertex="1" parent="1"><mxGeometry '
                             f'x="{d["x"] - w / 2}" y="{d["y"] - 10}" width="{w}" height="20" as="geometry"/></mxCell>')
        return (f'<diagram id="{page_id}" name="{escape(self.name)}"><mxGraphModel dx="1200" dy="800" grid="1" '
                f'gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" '
                f'pageWidth="{self.w}" pageHeight="{self.h}" math="0" shadow="0"><root><mxCell id="0"/>'
                f'<mxCell id="1" parent="0"/>' + "".join(cells) + "</root></mxGraphModel></diagram>")


# ====================================================================== sơ đồ
def soc():
    d = Diagram("1. Kiến trúc SoC", 990, 590)
    d.box(80, 30, 250, 180, "Lõi RISC-V RV32IMC",
          "Pipeline 5 tầng\nDự đoán rẽ nhánh BHT + BTB\nNhân/chia, lệnh nén 16 bit\nCSR, ngắt, ngoại lệ", "cpu", fs=14)
    d.box(440, 30, 230, 70, "RAM 128 KB", "chứa lệnh và dữ liệu", "mem")
    d.box(440, 140, 230, 70, "Bộ giải mã địa chỉ", "chọn RAM hoặc ngoại vi", "bus")
    d.box(440, 245, 230, 65, "Cầu nối sang APB", "Wishbone → APB", "bus")
    d.box(80, 345, 860, 30, "Bus APB", "", "bus", fs=12)
    per = [("TIMER64", "bộ định thời 64 bit", "tim"),
           ("UART", "thu/phát nối tiếp\nchân TX, RX", "per"),
           ("SPI master", "SCLK, MOSI, MISO\nCS[3:0]", "per"),
           ("GPIO", "16 chân vào/ra", "tim"),
           ("INTC", "gom ngắt UART,\nSPI, GPIO", "ctl")]
    xs = [80, 255, 430, 605, 780]
    for (t, s, c), x in zip(per, xs):
        d.box(x, 405, 160, 80, t, s, c)
        d.line([(x + 80, 375), (x + 80, 405)])
    d.line([(330, 65), (440, 65)], label="bus lệnh", lpos=(385, 52))
    d.line([(330, 175), (440, 175)], label="bus dữ liệu", lpos=(385, 162))
    d.line([(555, 140), (555, 100)], both=True)
    d.line([(555, 210), (555, 245)])
    d.line([(555, 310), (555, 345)])
    # ngắt
    d.line([(335, 485), (335, 510), (860, 510), (860, 485)], kind="irq", dashed=True, label="yêu cầu ngắt",
           lpos=(770, 510))
    d.line([(510, 485), (510, 510)], kind="irq", dashed=True, arrow=False)
    d.line([(685, 485), (685, 510)], kind="irq", dashed=True, arrow=False)
    d.line([(160, 485), (160, 540), (55, 540), (55, 180), (80, 180)], kind="irq", dashed=True,
           label="ngắt timer", lpos=(110, 540))
    d.line([(940, 445), (965, 445), (965, 570), (35, 570), (35, 120), (80, 120)], kind="irq", dashed=True,
           label="ngắt ngoài", lpos=(500, 570))
    return d


def pipeline():
    d = Diagram("2. Lõi pipeline 5 tầng", 1000, 515)
    stages = [("IF – Nạp lệnh", [("Bộ đếm PC", ""), ("Dự đoán rẽ nhánh", "BHT + BTB"), ("Đọc lệnh", "từ RAM")]),
              ("ID – Giải mã", [("Giải nén lệnh C", "16 → 32 bit"), ("Giải mã lệnh", "tạo hằng số"),
                                ("Tệp thanh ghi", "32 × 32 bit")]),
              ("EX – Thực thi", [("ALU", ""), ("Nhân / chia", ""), ("Kiểm tra nhánh", "đúng / sai dự đoán")]),
              ("MEM – Bộ nhớ", [("Load / store", "RAM, ngoại vi"), ("CSR", "ngắt, ngoại lệ")]),
              ("WB – Ghi kết quả", [("Ghi thanh ghi", ""), ("Bộ đếm", "hiệu năng")])]
    regs = ["IF/ID", "ID/EX", "EX/MEM", "MEM/WB"]
    x = 14
    sw, rw, gap = 172, 16, 6
    xs = []
    for i, (title, blocks) in enumerate(stages):
        xs.append(x)
        d.box(x, 90, sw, 250, title, "", "box", group=True, fs=13)
        n = len(blocks)
        bh = 52
        space = (250 - 35 - n * bh) / (n + 1)
        for j, (t, s) in enumerate(blocks):
            col = "tim" if t == "Dự đoán rẽ nhánh" else ("mem" if t == "Tệp thanh ghi" else
                                                         ("ctl" if t == "CSR" else "wht"))
            d.box(x + 8, 90 + 35 + space + j * (bh + space), sw - 16, bh, t, s, col, fs=12)
        x += sw
        if i < 4:
            d.line([(x, 318), (x + gap, 318)])
            d.box(x + gap, 90, rw, 250, regs[i], "", "ctl", rot=True, fs=11)
            d.line([(x + gap + rw, 318), (x + 2 * gap + rw, 318)])
            x += 2 * gap + rw
    ex, mem, wb, idx, ifx = xs[2], xs[3], xs[4], xs[1], xs[0]
    # đổi hướng PC (trên)
    d.line([(mem + 60, 90), (mem + 60, 22), (ifx + 40, 22), (ifx + 40, 90)], kind="ctl",
           label="trap, ngắt: nhảy tới trình xử lý", lpos=(470, 22))
    d.line([(ex + 110, 90), (ex + 110, 44), (ifx + 80, 44), (ifx + 80, 90)], kind="ctl",
           label="sai dự đoán: nạp lại PC, hủy lệnh sai", lpos=(300, 44))
    d.line([(ex + 50, 90), (ex + 50, 66), (ifx + 120, 66), (ifx + 120, 90)], kind="upd", dashed=True,
           label="cập nhật BHT, BTB", lpos=(300, 66))
    # forwarding và ghi ngược (dưới)
    d.line([(mem + 60, 340), (mem + 60, 365), (ex + 110, 365), (ex + 110, 340)], kind="fwd", dashed=True,
           label="forwarding", lpos=(mem - 10, 365))
    d.line([(wb + 60, 340), (wb + 60, 390), (ex + 60, 390), (ex + 60, 340)], kind="fwd", dashed=True,
           label="forwarding", lpos=(wb - 10, 390))
    d.line([(wb + 120, 340), (wb + 120, 415), (idx + 80, 415), (idx + 80, 340)], kind="fwd",
           label="ghi kết quả vào tệp thanh ghi", lpos=(560, 415))
    d.box(14, 445, 972, 60, "Khối xử lý xung đột (hazard unit)",
          "dừng (stall) khi load-use, nhân/chia chưa xong, chờ bus; hủy (flush) lệnh khi sai dự đoán hoặc trap",
          "gry", fs=13)
    return d


def predictor():
    d = Diagram("3. Dự đoán rẽ nhánh", 980, 380)
    o = 40
    d.box(15, 120 + o, 120, 60, "PC hiện tại", "", "cpu")
    d.box(180, 5 + o, 280, 285, "Bộ dự đoán (tra ở tầng IF)", "", "box", group=True, fs=12)
    d.box(200, 50 + o, 240, 75, "BTB (32 mục)", "lệnh là nhánh/nhảy?\nđịa chỉ đích", "tim")
    d.box(200, 195 + o, 240, 75, "BHT", "256 bộ đếm 2 bit\nnhảy hay không nhảy?", "tim")
    d.box(510, 110 + o, 210, 80, "Chọn PC kế tiếp", "đích (nếu đoán nhảy)\nhoặc PC + 2 / PC + 4", "ctl")
    d.box(780, 110 + o, 190, 80, "Tầng EX kiểm tra", "PC đúng ≠ PC đoán?", "wht")
    d.line([(135, 150 + o), (165, 150 + o), (165, 87 + o), (200, 87 + o)])
    d.line([(165, 150 + o), (165, 232 + o), (200, 232 + o)])
    d.line([(440, 87 + o), (475, 87 + o), (475, 135 + o), (510, 135 + o)])
    d.line([(440, 232 + o), (475, 232 + o), (475, 165 + o), (510, 165 + o)])
    d.line([(720, 150 + o), (780, 150 + o)])
    d.line([(875, 190 + o), (875, 320 + o), (75, 320 + o), (75, 180 + o)], kind="ctl",
           label="sai: hủy 2 lệnh phía sau, nạp lại PC đúng", lpos=(470, 320 + o))
    d.line([(875, 110 + o), (875, 15), (320, 15), (320, 5 + o)], kind="upd", dashed=True,
           label="cập nhật BTB và BHT khi biết kết quả", lpos=(600, 15))
    return d


def uart_spi():
    d = Diagram("4. Ngoại vi UART và SPI", 1000, 600)
    for row, (name, eng1, eng2, gen, pins_out, pin_in) in enumerate([
        ("UART – địa chỉ 0x1000_0000", ("Bộ phát", "start, 8 bit, parity, stop"),
         ("Bộ thu", "lấy mẫu giữa bit (×16)"), ("Tạo tốc độ baud", "BAUD_DIV"), "TX", "RX"),
        ("SPI master – địa chỉ 0x1000_1000", ("Bộ dịch SPI", "mode 0 – 3\nMSB hoặc LSB trước"),
         None, ("Tạo SCLK", "CLK_DIV"), "SCLK, MOSI, CS", "MISO")]):
        y0 = 15 + row * 300
        d.box(10, y0, 980, 280, name, "", "box", group=True, fs=13)
        d.box(25, y0 + 45, 195, 190, "Thanh ghi", "DATA, STATUS, CTRL\nhệ số chia\nbật ngắt, cờ ngắt", "bus", fs=13)
        d.box(270, y0 + 50, 160, 55, "TX FIFO", "16 byte", "ctl")
        d.box(270, y0 + 175, 160, 55, "RX FIFO", "16 byte", "ctl")
        d.line([(220, y0 + 77), (270, y0 + 77)], label="ghi", lpos=(245, y0 + 62))
        d.line([(270, y0 + 202), (220, y0 + 202)], label="đọc", lpos=(245, y0 + 187))
        if eng2:
            d.box(480, y0 + 50, 250, 55, *eng1, "per")
            d.box(480, y0 + 175, 250, 55, *eng2, "per")
            d.box(530, y0 + 115, 150, 50, *gen, "gry", fs=12)
            d.line([(605, y0 + 115), (605, y0 + 105)])
            d.line([(605, y0 + 165), (605, y0 + 175)])
        else:
            d.box(480, y0 + 50, 250, 180, eng1[0], eng1[1] + "\nvừa phát vừa thu\n8 bit mỗi lần", "per")
            d.box(790, y0 + 115, 150, 50, *gen, "gry", fs=12)
            d.line([(790, y0 + 140), (730, y0 + 140)])
        d.line([(430, y0 + 77), (480, y0 + 77)])
        d.line([(480, y0 + 202), (430, y0 + 202)])
        d.line([(730, y0 + 77), (970, y0 + 77)], label=pins_out, lpos=(865, y0 + 62))
        d.line([(970, y0 + 202), (730, y0 + 202)], label=pin_in, lpos=(865, y0 + 187))
        d.line([(120, y0 + 235), (120, y0 + 258), (970, y0 + 258)], kind="irq", dashed=True,
               label="ngắt tới INTC: FIFO đạt ngưỡng, truyền xong, lỗi", lpos=(560, y0 + 258))
    return d


def board():
    d = Diagram("5. Hệ thống trên board DE2", 960, 430)
    d.box(160, 15, 655, 300, "Board DE2 – FPGA Cyclone II EP2C35", "", "box", group=True, fs=13)
    d.box(20, 60, 120, 50, "Thạch anh", "50 MHz", "wht")
    d.box(190, 60, 150, 50, "PLL", "tạo clock 24 MHz", "tim")
    d.box(190, 170, 150, 50, "Nút KEY0", "reset", "wht")
    d.box(400, 50, 220, 245, "SoC RISC-V", "lõi RV32IMC\nRAM 32 KB (khối M4K)\nUART, SPI, TIMER\nGPIO, INTC\n\n"
                                            "chương trình nạp sẵn\ntrong RAM", "cpu", fs=14)
    rows = [("Công tắc SW", 50, "in"), ("LED, LED 7 đoạn", 115, "out"), ("Header JP1", 180, "both"),
            ("Cổng RS-232", 245, "both")]
    for t, y, dirn in rows:
        d.box(650, y, 145, 45, t, "", "wht", fs=12)
        if dirn == "in":
            d.line([(650, y + 22), (620, y + 22)])
        else:
            d.line([(620, y + 22), (650, y + 22)], both=(dirn == "both"))
    d.box(830, 172, 125, 60, "Flash SPI", "W25Qxx", "gry")
    d.box(830, 240, 125, 55, "Máy tính", "terminal UART", "gry")
    d.line([(795, 202), (830, 202)], both=True)
    d.line([(795, 267), (830, 267)], both=True)
    d.box(400, 350, 220, 60, "Máy tính – Quartus II", "biên dịch, nạp qua JTAG", "gry")
    d.line([(140, 85), (190, 85)])
    d.line([(340, 85), (400, 85)], label="24 MHz", lpos=(370, 72))
    d.line([(340, 195), (400, 195)])
    d.line([(510, 350), (510, 295)], label="cấu hình FPGA", lpos=(570, 330))
    return d


def flow():
    d = Diagram("6. Quy trình thiết kế", 760, 665)
    steps = [("Đặc tả", "chức năng, bản đồ bộ nhớ, thanh ghi", "gry"),
             ("Thiết kế kiến trúc", "sơ đồ khối SoC, pipeline, bus", "cpu"),
             ("Viết RTL bằng SystemVerilog", "tăng dần: single-cycle → pipeline → M, C\n→ dự đoán rẽ nhánh → ngoại vi",
              "mem"),
             ("Xác minh", "testbench từng khối, riscv-tests, so với Spike,\nchương trình C trên SoC", "ctl"),
             ("Đánh giá hiệu năng", "CPI, độ chính xác dự đoán, kích thước mã", "tim"),
             ("Tổng hợp logic", "diện tích, tần số tối đa, đường găng", "tim"),
             ("Hiện thực", "FPGA DE2 (Quartus II), layout ASIC (OpenLane)", "per")]
    y = 15
    ys = []
    for t, s, c in steps:
        h = 75 if "\n" in s else 62
        d.box(150, y, 420, h, t, s, c, fs=14)
        ys.append((y, h))
        y += h + 28
    for (y1, h1), (y2, h2) in zip(ys, ys[1:]):
        d.line([(360, y1 + h1), (360, y2)])
    (yx, hx), (yr, hr) = ys[3], ys[2]
    d.line([(570, yx + hx / 2), (640, yx + hx / 2), (640, yr + hr / 2), (570, yr + hr / 2)], kind="ctl",
           label="có lỗi: sửa RTL", lpos=(660, yx - 5))
    (yp, hp) = ys[5]
    d.line([(150, yp + hp / 2), (90, yp + hp / 2), (90, ys[1][0] + ys[1][1] / 2), (150, ys[1][0] + ys[1][1] / 2)],
           kind="ctl", label="chưa đạt", lpos=(90, (yp + ys[1][0]) / 2 + 40))
    return d


def verify():
    d = Diagram("7. Luồng xác minh", 1000, 400)
    d.box(10, 25, 220, 75, "Chương trình", "riscv-tests, C, benchmark", "gry")
    d.box(10, 160, 220, 65, "RISC-V GCC", "biên dịch ra file nhị phân", "gry")
    d.box(300, 125, 260, 130, "Mô phỏng RTL", "Verilator\nSoC + mô hình UART,\nflash SPI (BFM)", "mem", fs=14)
    d.box(300, 15, 260, 75, "Spike", "mô hình chuẩn RISC-V", "tim")
    d.box(300, 295, 260, 70, "Testbench từng khối", "14 testbench tự kiểm tra", "mem")
    d.box(615, 55, 220, 75, "So sánh từng lệnh", "PC, mã lệnh, kết quả", "ctl")
    d.box(615, 185, 220, 75, "Kiểm tra đầu ra", "UART, mã thoát, bus", "ctl")
    d.box(875, 150, 115, 75, "ĐẠT /\nKHÔNG ĐẠT", "", "per", fs=12)
    d.line([(120, 100), (120, 160)])
    d.line([(230, 192), (300, 192)])
    d.line([(265, 192), (265, 52), (300, 52)])
    d.line([(560, 52), (588, 52), (588, 80), (615, 80)])
    d.line([(560, 160), (588, 160), (588, 105), (615, 105)])
    d.line([(560, 222), (615, 222)])
    d.line([(560, 330), (932, 330), (932, 225)])
    d.line([(835, 92), (932, 92), (932, 150)])
    d.line([(835, 222), (875, 222)])
    return d


def main():
    os.makedirs(PNG_DIR, exist_ok=True)
    ds = [("soc", soc()), ("pipeline", pipeline()), ("du_doan_re_nhanh", predictor()), ("uart_spi", uart_spi()),
          ("board_de2", board()), ("quy_trinh", flow()), ("xac_minh", verify())]
    pages = []
    for i, (key, d) in enumerate(ds, 1):
        d.png(os.path.join(PNG_DIR, f"so_do_khoi_{i}_{key}.png"))
        pages.append(d.drawio(f"s{i}"))
    with open(os.path.join(OUT_DIR, "so_do_khoi.drawio"), "w", encoding="utf-8") as f:
        f.write('<mxfile host="drawio" version="24.7.17">' + "".join(pages) + "</mxfile>\n")
    print("ok:", ", ".join(k for k, _ in ds))


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Throughput table: execution time and MIPS of every benchmark, Dhrystone and
CoreMark scores, bus and peripheral transfer rates.

Inputs (no new simulation):
  results/perf/exp1_predictor.csv  cycles / instret of the measured region
                                   (rv_core m1c1, BP_MODE 2, imc)
  results/synth/summary.json       median Fmax of soc_top_1k (ECP5 estimate)
  build/logs/systest/m1c1_bp2/hello.log
                                   Wishbone counters (measured APB access time)
Clock frequencies: 24 MHz (DE2 board, fpga/board/pll_cpu.v) and the ECP5 Fmax.
Peripheral rates follow from the RTL timing: UART bit = 16 x (BAUD_DIV + 1)
clocks (10-bit 8N1 frame), SPI byte in a burst = 17 x (CLK_DIV + 1) clocks
(16 SCLK half periods + 1 gap, half period checked by tb_spi).

Writes results/perf/throughput.md and throughput.csv.
"""
import csv
import json
import math
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import BUILD, RESULTS  # noqa: E402
from md_table import write_md  # noqa: E402

CFG = "m1c1_bp2_bht256_btb32"
F_BOARD = 24.0                     # MHz, DE2 PLL
DHRY_RUNS = 500                    # NUMBER_OF_RUNS (riscv-tests dhrystone.h)
COREMARK_ITER = 2                  # sw/benchmarks/coremark/flags.txt
VAX_DHRY = 1757                    # Dhrystones/s of the VAX 11/780 (1 DMIPS)


def main():
    rows = [r for r in csv.DictReader(open(RESULTS / "perf/exp1_predictor.csv"))
            if r["config"] == CFG and r["variant"] == "imc"]
    fmax = json.loads((RESULTS / "synth/summary.json").read_text())["fmax_mhz"].get("soc_top_1k")
    freqs = [("DE2", F_BOARD)] + ([("ECP5 Fmax", fmax)] if fmax else [])

    out_csv = []
    L = ["# Thông lượng (throughput)", "",
         f"Lõi `rv_core` RV32IMC, BP_MODE 2 (BHT 256, BTB 32), ELF `imc`; số chu kỳ/lệnh của vùng đo trong mỗi "
         f"benchmark (nguồn: `results/perf/exp1_predictor.csv`). Tần số: **{F_BOARD:g} MHz** (clock CPU trên board "
         "DE2) và " + (f"**{fmax} MHz** (Fmax trung vị 5 seed của `soc_top_1k`, ước lượng ECP5)" if fmax else "–")
         + ". Thời gian = chu kỳ ÷ f; MIPS = f ÷ CPI. Sinh bởi `scripts/throughput.py`.", "",
         "## Bảng T1 – Thời gian chạy và MIPS", "",
         "| Benchmark | Lệnh | Chu kỳ | CPI | " + " | ".join(f"Thời gian @{f:g} MHz (µs) | MIPS @{f:g} MHz"
                                                         for _, f in freqs) + " |",
         "|---|---|---|---|" + "---|---|" * len(freqs)]
    mips_all = {n: [] for n, _ in freqs}
    for r in rows:
        cyc, ins = int(r["cycles"]), int(r["instret"])
        cpi = cyc / ins
        cells = []
        rec = dict(bench=r["bench"], instret=ins, cycles=cyc, cpi=round(cpi, 3))
        for n, f in freqs:
            t_us = cyc / f
            mips = f / cpi
            mips_all[n].append(mips)
            cells += [f"{t_us:.1f}", f"{mips:.1f}"]
            rec[f"time_us_{f:g}MHz"] = round(t_us, 2)
            rec[f"mips_{f:g}MHz"] = round(mips, 2)
        out_csv.append(rec)
        L.append(f"| {r['bench']} | {ins} | {cyc} | {cpi:.3f} | " + " | ".join(cells) + " |")
    geo = {n: math.exp(sum(math.log(m) for m in v) / len(v)) for n, v in mips_all.items() if v}
    L.append("| **geomean MIPS** | | | | " + " | ".join(f" | **{geo[n]:.1f}**" for n, _ in freqs) + " |")
    L.append("")

    d = next(r for r in rows if r["bench"] == "dhrystone")
    c = next(r for r in rows if r["bench"] == "coremark")
    dmips_mhz = DHRY_RUNS * 1e6 / (int(d["cycles"]) * VAX_DHRY)
    cm_mhz = COREMARK_ITER * 1e6 / int(c["cycles"])
    L += ["## Bảng T2 – Điểm chuẩn", "",
          "| Chỉ số | /MHz | " + " | ".join(f"@{f:g} MHz" for _, f in freqs) + " |",
          "|---|---|" + "---|" * len(freqs),
          f"| Dhrystone (DMIPS; {DHRY_RUNS} vòng, 1 DMIPS = {VAX_DHRY} vòng/s) | {dmips_mhz:.3f} | "
          + " | ".join(f"{dmips_mhz * f:.1f}" for _, f in freqs) + " |",
          f"| CoreMark ({COREMARK_ITER} vòng, không phải lần chạy hợp lệ theo luật EEMBC) | {cm_mhz:.2f} | "
          + " | ".join(f"{cm_mhz * f:.1f}" for _, f in freqs) + " |", ""]

    # measured APB access time from the Wishbone checker
    apb_cyc = None
    log = BUILD / "logs/systest/m1c1_bp2/hello.log"
    if log.exists():
        m = re.search(r"apb_bridge ack=(\d+) err=(\d+) wait=(\d+)", log.read_text())
        if m and int(m.group(1)):
            acc = int(m.group(1)) + int(m.group(2))
            apb_cyc = (acc + int(m.group(3))) / acc
    L += ["## Bảng T3 – Bus và ngoại vi", "",
          "| Đường truyền | Chu kỳ / đơn vị | Nguồn | " + " | ".join(f"@{f:g} MHz" for _, f in freqs) + " |",
          "|---|---|---|" + "---|" * len(freqs)]

    def row(name, cyc, unit_bytes, src, unit="MB/s", per_s=False):
        vals = []
        for _, f in freqs:
            rate = f * 1e6 / cyc
            vals.append(f"{rate / 1e6:.2f} M truy cập/s" if per_s else
                        (f"{rate * unit_bytes / 1e6:.2f} MB/s" if unit == "MB/s" else
                         f"{rate * unit_bytes / 1e3:.1f} kB/s"))
        L.append(f"| {name} | {cyc:g} | {src} | " + " | ".join(vals) + " |")

    row("RAM qua Wishbone (load/store 32 bit, ACK cùng chu kỳ)", 1, 4,
        "RTL; số chu kỳ benchmark trùng khớp với RAM tổ hợp")
    if apb_cyc:
        row("Thanh ghi ngoại vi qua Wishbone → APB4", apb_cyc, 4,
            f"đo bằng `wb_checker` (system test `hello`: {apb_cyc:.2f} chu kỳ/truy cập)", per_s=True)
    row("UART 115200 baud (BAUD_DIV 12 @24 MHz, khung 8N1 = 10 bit)", 16 * 13 * 10, 1,
        "16 × (12 + 1) chu kỳ/bit", unit="kB/s")
    row("UART tối đa (BAUD_DIV 0, khung 8N1)", 16 * 10, 1, "16 chu kỳ/bit", unit="kB/s")
    row("SPI tối đa (CLK_DIV 0, SCLK = f/2, burst)", 17, 1, "17 × (CLK_DIV + 1) chu kỳ/byte")
    row("SPI flash trong firmware (CLK_DIV 1, SCLK = f/4)", 34, 1, "17 × 2 chu kỳ/byte")
    L += ["", "Ghi chú: tốc độ UART ở dòng 115200 baud đúng cho clock 24 MHz của board; ở tần số khác BAUD_DIV phải "
          "tính lại. CoreMark chạy 2 vòng để vừa thời gian mô phỏng nên chỉ dùng để so sánh tương đối.", ""]
    write_md(RESULTS / "perf/throughput.md", "\n".join(L))
    with open(RESULTS / "perf/throughput.csv", "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(out_csv[0].keys()))
        w.writeheader()
        w.writerows(out_csv)
    print("\n".join(L))


if __name__ == "__main__":
    main()

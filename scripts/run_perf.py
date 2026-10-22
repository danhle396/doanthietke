#!/usr/bin/env python3
"""Performance experiments (spec 12.1). Outputs results/perf/*.csv, *.png and
summary.md.

  exp1  predictor: BP_MODE 0/1/2 x every benchmark (rv32imc ELF)
  exp2  BHT_ENTRIES {16,64,256,1024} x BTB_ENTRIES {8,16,32,64} at BP_MODE 2
  exp3  C extension: .text size and CPI of rv32im vs rv32imc ELFs
  exp4  CPI breakdown (load-use, MulDiv, bus, misprediction, other)
  exp5  single-cycle vs pipeline: CPI and Fmax -> relative performance

All numbers come from the benchmark's measured region ([bench] lines printed
by the firmware from mcycle/minstret/mhpmcounter3..10) and from the test
bench's whole-run counters ([perf] lines). Area/Fmax are read from
results/synth/summary.json when `make synth` has been run.

Usage: run_perf.py [--exp 1 --exp 3 ...] [--quick]
"""
import argparse
import csv
import json
import re
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import (BUILD, JOBS, RESULTS, RISCV_PREFIX, build_soc, cfg_name, make_cfg,  # noqa: E402
                    parse_perf, run, run_sim)
from build_sw import build_program, program_dirs  # noqa: E402

OUT = RESULTS / "perf"
BENCH_RE = re.compile(r"^\[bench\] (.*)$", re.M)
BENCHES = ["dhrystone", "coremark", "median", "multiply", "qsort", "rsort", "towers",
           "vvadd", "memcpy"]

# reference categorical palette (slots 1-5, adjacent-pair validated) and text inks
C = ["#2a78d6", "#eb6834", "#1baf7a", "#eda100", "#e87ba4"]
INK, INK2, GRID, SURF = "#0b0b0b", "#52514e", "#e4e3df", "#fcfcfb"


def parse_bench(text):
    d = {}
    for m in BENCH_RE.finditer(text):
        for kv in m.group(1).split():
            k, v = kv.split("=")
            d[k] = v if k == "name" else int(v)
    return d


def run_bench(cfg, variant, bench):
    pdir = next(d for d in program_dirs("bench") if d.name == bench)
    elf = build_program("bench", pdir, variant, "sim")
    exe = build_soc(cfg)
    log = BUILD / "logs/perf" / cfg_name(cfg) / f"{variant}_{bench}.log"
    ok, out = run_sim(exe, elf.with_suffix(".hex"), ["+max_cycles=50000000"], log=log)
    b = parse_bench(out)
    p = parse_perf(out)
    if not ok or "cycles" not in b:
        raise RuntimeError(f"benchmark {bench} failed on {cfg_name(cfg)} ({log})")
    if bench == "coremark" and re.search(r"ERROR! (list|matrix|state) crc", out):
        raise RuntimeError("coremark CRC error")
    row = dict(config=cfg_name(cfg), variant=variant, bench=bench)
    row.update({k: v for k, v in b.items() if k != "name"})
    row["cpi"] = round(b["cycles"] / b["instret"], 4)
    ctl = b["branch"] + b["jump"]
    row["accuracy"] = round(1 - (b["branch_miss"] + b["jump_miss"]) / ctl, 4) if ctl else 1.0
    row["br_accuracy"] = round(1 - b["branch_miss"] / b["branch"], 4) if b["branch"] else 1.0
    row["run_id_redirects"] = p.get("id_redirects", 0)
    row["run_ex_redirects"] = p.get("ex_redirects", 0)
    row["run_cycles"] = p.get("cycles", 0)
    return row


def run_many(jobs):
    with ThreadPoolExecutor(max_workers=JOBS) as ex:
        return list(ex.map(lambda j: run_bench(*j), jobs))


def write_csv(name, rows):
    OUT.mkdir(parents=True, exist_ok=True)
    keys = list(rows[0].keys())
    with open(OUT / name, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=keys)
        w.writeheader()
        w.writerows(rows)


def geomean(xs):
    p = 1.0
    for x in xs:
        p *= x
    return p ** (1 / len(xs))


# --------------------------------------------------------------------------
# plotting helpers (matplotlib, static figures for the report)
# --------------------------------------------------------------------------
def plt_setup():
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    plt.rcParams.update({
        "figure.facecolor": SURF, "axes.facecolor": SURF, "savefig.facecolor": SURF,
        "axes.edgecolor": GRID, "axes.labelcolor": INK2, "xtick.color": INK2,
        "ytick.color": INK2, "text.color": INK, "axes.grid": True, "grid.color": GRID,
        "grid.linewidth": 0.6, "axes.axisbelow": True, "axes.spines.top": False,
        "axes.spines.right": False, "font.size": 9, "legend.frameon": False,
    })
    return plt


def grouped_bars(plt, cats, series, labels, ylabel, title, fname, ylim=None, fmt="{:.2f}"):
    import numpy as np
    fig, ax = plt.subplots(figsize=(8, 3.6))
    n = len(series)
    w = 0.8 / n
    x = np.arange(len(cats))
    for i, (vals, lab) in enumerate(zip(series, labels)):
        ax.bar(x + (i - (n - 1) / 2) * w, vals, w * 0.92, color=C[i], label=lab,
               edgecolor=SURF, linewidth=1)
    ax.set_xticks(x)
    ax.set_xticklabels(cats, rotation=0)
    ax.set_ylabel(ylabel)
    ax.set_title(title, loc="left", color=INK)
    if ylim:
        ax.set_ylim(*ylim)
    ax.legend(ncol=n, loc="upper left", bbox_to_anchor=(0, -0.12))
    fig.tight_layout()
    fig.savefig(OUT / fname, dpi=150)
    plt.close(fig)


# --------------------------------------------------------------------------
def exp1():
    jobs = [(make_cfg(BP_MODE=bp), "imc", b) for bp in (0, 1, 2) for b in BENCHES]
    rows = run_many(jobs)
    for r in rows:
        r["bp_mode"] = int(re.search(r"_bp(\d)", r["config"]).group(1))
        r["penalty_cycles"] = 2 * r["run_ex_redirects"] + r["run_id_redirects"]
    write_csv("exp1_predictor.csv", rows)
    return rows


def exp2(quick=False):
    bhts = (16, 64, 256, 1024)
    btbs = (8, 16, 32, 64)
    jobs = [(make_cfg(BP_MODE=2, BHT_ENTRIES=h, BTB_ENTRIES=t), "imc", b)
            for h in bhts for t in btbs for b in BENCHES]
    rows = run_many(jobs)
    for r in rows:
        m = re.search(r"_bht(\d+)_btb(\d+)", r["config"])
        r["bht"], r["btb"] = int(m.group(1)), int(m.group(2))
    write_csv("exp2_sweep.csv", rows)
    return rows


def text_size(elf):
    out = run([RISCV_PREFIX + "size", "-A", str(elf)]).stdout
    m = re.search(r"^\.text\s+(\d+)", out, re.M)
    return int(m.group(1))


def exp3():
    cfg = make_cfg(BP_MODE=2)
    rows = []
    for b in BENCHES:
        r_im = run_bench(cfg, "im", b)
        r_imc = run_bench(cfg, "imc", b)
        d = next(d for d in program_dirs("bench") if d.name == b)
        s_im = text_size(build_program("bench", d, "im", "sim"))
        s_imc = text_size(build_program("bench", d, "imc", "sim"))
        rows.append(dict(bench=b, text_im=s_im, text_imc=s_imc,
                         text_reduction=round(1 - s_imc / s_im, 4),
                         cycles_im=r_im["cycles"], cycles_imc=r_imc["cycles"],
                         instret_im=r_im["instret"], instret_imc=r_imc["instret"],
                         cpi_im=r_im["cpi"], cpi_imc=r_imc["cpi"],
                         compressed_frac=round(r_imc["compressed"] / r_imc["instret"], 4)))
    write_csv("exp3_rvc.csv", rows)
    return rows


def exp4(exp1_rows):
    rows = []
    for r in exp1_rows:
        if r["bp_mode"] != 2:
            continue
        mis = 2 * (r["branch_miss"] + r["jump_miss"])
        other = r["cycles"] - r["instret"] - r["stall_load_use"] - r["stall_muldiv"] - \
            r["stall_bus"] - mis
        n = r["instret"]
        rows.append(dict(bench=r["bench"], cpi=r["cpi"], base=1.0,
                         load_use=round(r["stall_load_use"] / n, 4),
                         muldiv=round(r["stall_muldiv"] / n, 4),
                         bus=round(r["stall_bus"] / n, 4),
                         mispredict=round(mis / n, 4),
                         other=round(other / n, 4)))
    write_csv("exp4_cpi_breakdown.csv", rows)
    return rows


def exp5():
    rows = []
    synth = {}
    sj = RESULTS / "synth/summary.json"
    if sj.exists():
        synth = json.loads(sj.read_text())
    cores = [("rv_core_sc (single-cycle, RV32I)", make_cfg(CORE_SC=1), "i", "sc"),
             ("rv_core pipeline RV32I", make_cfg(ENABLE_M=0, ENABLE_C=0, BP_MODE=2), "i",
              "m0c0_bp2"),
             ("rv_core pipeline RV32IMC", make_cfg(), "imc", "m1c1_bp2")]
    benches = [b for b in BENCHES if b != "coremark"] + ["coremark"]
    for label, cfg, variant, key in cores:
        rs = run_many([(cfg, variant, b) for b in benches])
        fmax = synth.get("fmax_mhz", {}).get(key)
        for r in rs:
            rows.append(dict(core=label, key=key, variant=variant, bench=r["bench"],
                             cycles=r["cycles"], instret=r["instret"], cpi=r["cpi"],
                             fmax_mhz=fmax if fmax else "",
                             time_us=round(r["cycles"] / fmax, 2) if fmax else ""))
    write_csv("exp5_sc_vs_pipeline.csv", rows)
    return rows


# --------------------------------------------------------------------------
def report(e1, e2, e3, e4, e5):
    plt = plt_setup()
    lines = ["# Đánh giá hiệu năng", "",
             "Số liệu đo trong vùng đo của từng benchmark (giữa hai lần `setStats`/`start_time`) bằng "
             "`mcycle`, `minstret`, `mhpmcounter3..10`. Tái tạo: `make perf` "
             "(= `.venv/bin/python scripts/run_perf.py`).", ""]
    checks = []
    if e1:
        lines += ["## Thí nghiệm 1 – Bộ dự đoán rẽ nhánh (rv32imc, BHT 256, BTB 32)", "",
                  "Bảng P1. CPI, độ chính xác dự đoán (branch + jump) và chu kỳ penalty "
                  "(toàn chương trình = 2×redirect ở EX + 1×redirect ở ID). "
                  "Nguồn: `results/perf/exp1_predictor.csv`.", "",
                  "| Benchmark | CPI BP0 | CPI BP1 | CPI BP2 | Acc BP0 | Acc BP1 | Acc BP2 | Penalty BP0 | Penalty BP1 | Penalty BP2 |",
                  "|---|---|---|---|---|---|---|---|---|---|"]
        by = {(r["bench"], r["bp_mode"]): r for r in e1}
        for b in BENCHES:
            rr = [by[(b, m)] for m in (0, 1, 2)]
            lines.append(f"| {b} | " + " | ".join(f"{r['cpi']:.3f}" for r in rr) + " | " +
                         " | ".join(f"{100*r['accuracy']:.1f}%" for r in rr) + " | " +
                         " | ".join(str(r["penalty_cycles"]) for r in rr) + " |")
        gm = [geomean([by[(b, m)]["cpi"] for b in BENCHES]) for m in (0, 1, 2)]
        lines += [f"| **geomean CPI** | {gm[0]:.3f} | {gm[1]:.3f} | {gm[2]:.3f} | | | | | | |", ""]
        grouped_bars(plt, BENCHES, [[by[(b, m)]["cpi"] for b in BENCHES] for m in (0, 1, 2)],
                     ["BP_MODE 0 (tĩnh)", "BP_MODE 1 (BHT@ID)", "BP_MODE 2 (BHT+BTB@IF)"],
                     "CPI (chu kỳ / lệnh)", "Hình P1. CPI theo chế độ dự đoán", "exp1_cpi.png")
        grouped_bars(plt, BENCHES, [[100 * by[(b, m)]["accuracy"] for b in BENCHES] for m in (0, 1, 2)],
                     ["BP_MODE 0", "BP_MODE 1", "BP_MODE 2"], "Độ chính xác dự đoán (%)",
                     "Hình P2. Độ chính xác dự đoán (branch + JAL/JALR)", "exp1_accuracy.png",
                     ylim=(0, 100))
        lines += ["![Hình P1](exp1_cpi.png)", "", "![Hình P2](exp1_accuracy.png)", ""]
        d = by[("dhrystone", 2)]["cpi"]
        checks.append(("CPI Dhrystone (BP2) trong [1.0, 2.0]", 1.0 <= d <= 2.0, f"{d:.3f}"))
        worse = [b for b in BENCHES if by[(b, 2)]["cycles"] > by[(b, 0)]["cycles"]]
        checks.append(("BP_MODE=2 không tệ hơn BP_MODE=0 (mọi benchmark)", not worse,
                       "tệ hơn: " + ", ".join(worse) if worse else "đạt"))
    if e2:
        import numpy as np
        bhts, btbs = (16, 64, 256, 1024), (8, 16, 32, 64)
        acc = np.zeros((4, 4))
        cpi = np.zeros((4, 4))
        for i, h in enumerate(bhts):
            for j, t in enumerate(btbs):
                rs = [r for r in e2 if r["bht"] == h and r["btb"] == t]
                acc[i, j] = 100 * sum(r["accuracy"] for r in rs) / len(rs)
                cpi[i, j] = geomean([r["cpi"] for r in rs])
        synth = {}
        sj = RESULTS / "synth/summary.json"
        if sj.exists():
            synth = json.loads(sj.read_text()).get("sweep_cells", {})
        lines += ["## Thí nghiệm 2 – Quét kích thước BHT × BTB (BP_MODE 2)", "",
                  "Bảng P2. Độ chính xác trung bình (%) / geomean CPI trên 9 benchmark; "
                  "diện tích = số cell Yosys của `rv_core` (generic, không tính RAM). "
                  "Nguồn: `results/perf/exp2_sweep.csv`, `results/synth/summary.json`.", "",
                  "| BHT \\ BTB | " + " | ".join(str(t) for t in btbs) + " |",
                  "|---|" + "---|" * 4]
        for i, h in enumerate(bhts):
            cells = []
            for j, t in enumerate(btbs):
                area = synth.get(f"bht{h}_btb{t}")
                cells.append(f"{acc[i,j]:.1f}% / {cpi[i,j]:.3f}" + (f" / {area} cell" if area else ""))
            lines.append(f"| {h} | " + " | ".join(cells) + " |")
        lines.append("")
        fig, ax = plt.subplots(figsize=(5.2, 3.8))
        im = ax.imshow(acc, cmap="Blues", origin="lower", vmin=acc.min() - 2, vmax=100)
        for i in range(4):
            for j in range(4):
                ax.text(j, i, f"{acc[i,j]:.1f}", ha="center", va="center",
                        color=SURF if acc[i, j] > (acc.min() + 100) / 2 + 1 else INK, fontsize=9)
        ax.set_xticks(range(4)); ax.set_xticklabels(btbs)
        ax.set_yticks(range(4)); ax.set_yticklabels(bhts)
        ax.set_xlabel("BTB_ENTRIES"); ax.set_ylabel("BHT_ENTRIES"); ax.grid(False)
        ax.set_title("Hình P3. Độ chính xác dự đoán trung bình (%)", loc="left", color=INK)
        fig.colorbar(im, ax=ax, shrink=0.8)
        fig.tight_layout(); fig.savefig(OUT / "exp2_accuracy_heatmap.png", dpi=150); plt.close(fig)
        lines += ["![Hình P3](exp2_accuracy_heatmap.png)", ""]
        if synth:
            fig, ax = plt.subplots(figsize=(6, 3.8))
            for j, t in enumerate(btbs):
                xs = [synth.get(f"bht{h}_btb{t}", 0) for h in bhts]
                ax.plot(xs, cpi[:, j], marker="o", color=C[j], linewidth=2, markersize=6,
                        label=f"BTB {t}")
            ax.set_xlabel("Diện tích rv_core (số cell Yosys)")
            ax.set_ylabel("geomean CPI")
            ax.set_title("Hình P4. CPI theo diện tích (mỗi đường: BHT 16→1024)", loc="left", color=INK)
            ax.legend(ncol=4, loc="upper left", bbox_to_anchor=(0, -0.15))
            fig.tight_layout(); fig.savefig(OUT / "exp2_cpi_vs_area.png", dpi=150); plt.close(fig)
            lines += ["![Hình P4](exp2_cpi_vs_area.png)", ""]
    if e3:
        lines += ["## Thí nghiệm 3 – Extension C", "",
                  "Bảng P3. Kích thước `.text` (byte) và CPI của ELF rv32im so với rv32imc, cùng lõi "
                  "`m1c1_bp2`. Nguồn: `results/perf/exp3_rvc.csv`.", "",
                  "| Benchmark | .text im | .text imc | Giảm | Lệnh nén (%) | Chu kỳ im | Chu kỳ imc | CPI im | CPI imc |",
                  "|---|---|---|---|---|---|---|---|---|"]
        for r in e3:
            lines.append(f"| {r['bench']} | {r['text_im']} | {r['text_imc']} | "
                         f"{100*r['text_reduction']:.1f}% | {100*r['compressed_frac']:.1f}% | "
                         f"{r['cycles_im']} | {r['cycles_imc']} | {r['cpi_im']:.3f} | {r['cpi_imc']:.3f} |")
        tot_im = sum(r["text_im"] for r in e3)
        tot_imc = sum(r["text_imc"] for r in e3)
        lines += [f"| **tổng** | {tot_im} | {tot_imc} | {100*(1-tot_imc/tot_im):.1f}% | | | | | |", ""]
        grouped_bars(plt, [r["bench"] for r in e3], [[r["text_im"] / 1024 for r in e3],
                                                      [r["text_imc"] / 1024 for r in e3]],
                     ["rv32im", "rv32imc"], "Kích thước .text (KiB)",
                     "Hình P5. Kích thước mã với và không có extension C", "exp3_text_size.png")
        lines += ["![Hình P5](exp3_text_size.png)", ""]
    if e4:
        import numpy as np
        lines += ["## Thí nghiệm 4 – Phân rã CPI (m1c1_bp2, rv32imc)", "",
                  "Bảng P4. CPI = 1 (lệnh) + các thành phần stall/lệnh. `mispredict` = 2 chu kỳ × số lần sai "
                  "dự đoán ở EX; `other` = phần còn lại (chủ yếu redirect 1 chu kỳ ở ID cho JAL). "
                  "Nguồn: `results/perf/exp4_cpi_breakdown.csv`.", "",
                  "| Benchmark | CPI | load-use | MulDiv | bus | mispredict | other |",
                  "|---|---|---|---|---|---|---|"]
        for r in e4:
            lines.append(f"| {r['bench']} | {r['cpi']:.3f} | {r['load_use']:.3f} | {r['muldiv']:.3f} | "
                         f"{r['bus']:.3f} | {r['mispredict']:.3f} | {r['other']:.3f} |")
        lines.append("")
        fig, ax = plt.subplots(figsize=(8, 3.8))
        x = np.arange(len(e4))
        bottom = np.ones(len(e4))
        ax.bar(x, bottom, 0.6, color=GRID, label="lệnh (CPI = 1)", edgecolor=SURF, linewidth=1)
        for k, (key, lab) in enumerate([("load_use", "load-use"), ("muldiv", "MulDiv"),
                                        ("bus", "chờ bus"), ("mispredict", "sai dự đoán"),
                                        ("other", "khác")]):
            v = np.array([max(r[key], 0) for r in e4])
            ax.bar(x, v, 0.6, bottom=bottom, color=C[k], label=lab, edgecolor=SURF, linewidth=1)
            bottom += v
        ax.set_xticks(x); ax.set_xticklabels([r["bench"] for r in e4])
        ax.set_ylabel("CPI"); ax.set_ylim(0.9, max(bottom) * 1.05)
        ax.set_title("Hình P6. Phân rã CPI (BP_MODE 2)", loc="left", color=INK)
        ax.legend(ncol=6, loc="upper left", bbox_to_anchor=(0, -0.12))
        fig.tight_layout(); fig.savefig(OUT / "exp4_cpi_breakdown.png", dpi=150); plt.close(fig)
        lines += ["![Hình P6](exp4_cpi_breakdown.png)", ""]
    if e5:
        cores = []
        for r in e5:
            if r["core"] not in cores:
                cores.append(r["core"])
        lines += ["## Thí nghiệm 5 – Single-cycle so với pipeline", "",
                  "Bảng P5. CPI (geomean), Fmax ước lượng (nextpnr ECP5, xem `results/synth/summary.md`) "
                  "và hiệu năng tương đối ∝ Fmax / CPI (chuẩn hóa theo lõi single-cycle). "
                  "Nguồn: `results/perf/exp5_sc_vs_pipeline.csv`.", "",
                  "| Lõi | geomean CPI | Dhrystone CPI | Fmax (MHz) | Fmax/CPI | Hiệu năng tương đối |",
                  "|---|---|---|---|---|---|"]
        base = None
        for c in cores:
            rs = [r for r in e5 if r["core"] == c]
            g = geomean([r["cpi"] for r in rs])
            dh = next(r["cpi"] for r in rs if r["bench"] == "dhrystone")
            f = rs[0]["fmax_mhz"]
            perf = (f / g) if f else None
            if base is None and perf:
                base = perf
            rel = f"{perf/base:.2f}×" if perf and base else "(chưa có Fmax)"
            lines.append(f"| {c} | {g:.3f} | {dh:.3f} | {f if f else '–'} | "
                         f"{perf:.1f} | {rel} |" if perf else
                         f"| {c} | {g:.3f} | {dh:.3f} | – | – | {rel} |")
        lines.append("")
    if checks:
        lines += ["## Kiểm tra hợp lý (spec 12.1)", "", "| Kiểm tra | Kết quả | Giá trị |", "|---|---|---|"]
        lines += [f"| {n} | {'ĐẠT' if ok else 'KHÔNG ĐẠT'} | {v} |" for n, ok, v in checks]
        lines.append("")
    (OUT / "summary.md").write_text("\n".join(lines))
    return checks


def load_csv(name):
    p = OUT / name
    if not p.exists():
        return None
    rows = list(csv.DictReader(open(p)))
    for r in rows:
        for k, v in r.items():
            try:
                r[k] = int(v)
            except ValueError:
                try:
                    r[k] = float(v)
                except ValueError:
                    pass
    return rows


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--exp", type=int, action="append")
    ap.add_argument("--report-only", action="store_true")
    args = ap.parse_args()
    exps = args.exp or [1, 2, 3, 4, 5]
    OUT.mkdir(parents=True, exist_ok=True)
    e1 = exp1() if 1 in exps and not args.report_only else load_csv("exp1_predictor.csv")
    e2 = exp2() if 2 in exps and not args.report_only else load_csv("exp2_sweep.csv")
    e3 = exp3() if 3 in exps and not args.report_only else load_csv("exp3_rvc.csv")
    e4 = exp4(e1) if (4 in exps and e1 and not args.report_only) else load_csv("exp4_cpi_breakdown.csv")
    e5 = exp5() if 5 in exps and not args.report_only else load_csv("exp5_sc_vs_pipeline.csv")
    checks = report(e1, e2, e3, e4, e5)
    for n, ok, v in checks:
        print(f"[perf] {'OK  ' if ok else 'FAIL'} {n}: {v}")
    sys.exit(0 if all(ok for _, ok, _ in checks) else 1)


if __name__ == "__main__":
    main()

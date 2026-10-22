#!/usr/bin/env python3
"""Synthesis report (spec 12.2).

  * Area: Yosys generic `synth -flatten` + `stat` (cell count, flip-flops) for
    rv_core in every configuration of 12.1 (BP_MODE 0/1/2, ENABLE_M/C, the
    BHT x BTB sweep), rv_core_sc, every peripheral and soc_top with ram_dp as
    a black box (RAM not counted).
  * Fmax: Yosys synth_ecp5 + nextpnr-ecp5 (LFE5U-85F, CABGA756) - an FPGA
    estimate only, no ASIC place & route. soc_top is placed with a 1 KB RAM
    (RAM_DEPTH = 256, LUT RAM) so that the instruction-fetch path is timed
    (a 4 KB combinational-read RAM needs > 5 GB in Yosys on this machine).
    Results of earlier runs are reused when no RTL/script file is newer.

Writes results/synth/summary.md, summary.json, area.csv and the critical path
excerpts results/synth/critical_path_<name>.txt.

Usage: synth_report.py [--no-fmax] [--no-sweep]
"""
import argparse
import csv
import json
import re
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import BUILD, JOBS, RESULTS, ROOT, YOSYS, rtl_files, run  # noqa: E402

OUT = RESULTS / "synth"
WORK = BUILD / "synth"
FILES = " ".join(rtl_files())

CORE_CFGS = {  # name -> rv_core parameters
    "m1c1_bp0": dict(ENABLE_M=1, ENABLE_C=1, BP_MODE=0),
    "m1c1_bp1": dict(ENABLE_M=1, ENABLE_C=1, BP_MODE=1),
    "m1c1_bp2": dict(ENABLE_M=1, ENABLE_C=1, BP_MODE=2),
    "m1c0_bp2": dict(ENABLE_M=1, ENABLE_C=0, BP_MODE=2),
    "m0c0_bp2": dict(ENABLE_M=0, ENABLE_C=0, BP_MODE=2),
}
PERIPHS = ["uart_apb", "spi_apb", "timer64_apb", "gpio_apb", "intc_apb", "apb_bridge",
           "dbus_xbar", "sim_ctrl", "rst_sync"]
FMAX_JOBS = {  # name -> (top, params)
    "m1c1_bp2": ("rv_core", CORE_CFGS["m1c1_bp2"]),
    "m1c1_bp0": ("rv_core", CORE_CFGS["m1c1_bp0"]),
    "m0c0_bp2": ("rv_core", CORE_CFGS["m0c0_bp2"]),
    "sc": ("rv_core_sc", {}),
    "soc_top_1k": ("soc_top", dict(RAM_DEPTH=256)),
    "soc_top_m0c0_1k": ("soc_top", dict(ENABLE_M=0, ENABLE_C=0, RAM_DEPTH=256)),
    "soc_top_sc_1k": ("soc_top", dict(CORE_SC=1, RAM_DEPTH=256)),
}


def _fresh(log):
    """True if `log` exists and is newer than every RTL file and syn template."""
    if not log.exists():
        return False
    newest = max([Path(f).stat().st_mtime for f in rtl_files()] +
                 [p.stat().st_mtime for p in (ROOT / "syn").glob("*.ys")])
    return log.stat().st_mtime > newest


def chparam(top, params):
    return "\n".join(f"chparam -set {k} {v} {top}" for k, v in params.items())


def generic_area(name, top, params, blackbox=""):
    d = WORK / "generic"
    d.mkdir(parents=True, exist_ok=True)
    tmpl = (ROOT / "syn/synth_generic.ys").read_text()
    ys = d / f"{name}.ys"
    ys.write_text(tmpl.format(files=FILES, top=top, chparam=chparam(top, params),
                              blackbox=blackbox))
    log = d / f"{name}.log"
    if not _fresh(log):
        run([YOSYS, "-q", "-l", str(log), "-s", str(ys)], timeout=3600)
    text = log.read_text()
    stat = text[text.rfind("Printing statistics"):]
    cells = int(re.search(r"^\s+(\d+)\s+cells\s*$", stat, re.M).group(1))
    ffs = sum(int(m.group(1)) for m in re.finditer(r"^\s+(\d+)\s+\$_[A-Z]*DFF[A-Z0-9_]*\s*$", stat, re.M))
    return dict(name=name, top=top, params=params, cells=cells, ffs=ffs)


def fmax(name, top, params):
    d = WORK / "ecp5"
    d.mkdir(parents=True, exist_ok=True)
    js = d / f"{name}.json"
    tmpl = (ROOT / "syn/synth_ecp5.ys").read_text()
    ys = d / f"{name}.ys"
    ys.write_text(tmpl.format(files=FILES, top=top, chparam=chparam(top, params), json=js))
    log = d / f"{name}.yosys.log"
    pnr_log = d / f"{name}.pnr.log"
    if not (_fresh(pnr_log) and "Max frequency" in pnr_log.read_text()):
        try:
            run([YOSYS, "-q", "-l", str(log), "-s", str(ys)], timeout=7200)
        except Exception as e:
            return dict(name=name, top=top, fmax_mhz=None, lut4=0, ff=0, critical_path="", error=str(e)[:200])
        run(["nextpnr-ecp5", "--85k", "--package", "CABGA756", "--json", str(js),
             "--freq", "50", "--timing-allow-fail", "--seed", "1"], check=False, timeout=7200,
            log=pnr_log)
    text = log.read_text()
    stat = text[text.rfind("Printing statistics"):]
    luts = sum(int(m.group(1)) for m in re.finditer(r"^\s+(\d+)\s+LUT4\s*$", stat, re.M))
    ffs = sum(int(m.group(1)) for m in re.finditer(r"^\s+(\d+)\s+TRELLIS_FF\s*$", stat, re.M))
    out = pnr_log.read_text()
    m = re.findall(r"Max frequency for clock '[^']*': ([\d.]+) MHz", out)
    f = float(m[-1]) if m else None
    # critical path excerpt (clock-to-clock report)
    cp = ""
    mm = re.search(r"Info: Critical path report for clock.*?(?=\nInfo: Critical path report|\nWarning: Max frequency|\nInfo: Max frequency)",
                   out, re.S)
    if mm:
        lines = [l.replace("Info: ", "") for l in mm.group(0).splitlines()
                 if re.search(r"Source|Sink|clk-to-q|setup|Net ", l)]
        cp = "\n".join(lines)
        (OUT / f"critical_path_{name}.txt").write_text(cp + "\n")
    js.unlink(missing_ok=True)
    return dict(name=name, top=top, fmax_mhz=f, lut4=luts, ff=ffs, critical_path=cp)


def summarize_cp(cp):
    """Short description: source register -> sink register of the critical path."""
    srcs = re.findall(r"Source (\S+)", cp)
    sinks = re.findall(r"Sink (\S+)", cp)
    if not srcs:
        return ""
    def short(s):
        s = s.rsplit(".", 1)[0] if s.count(".") else s      # drop the cell pin
        for cut in ("_TRELLIS", "_LUT4", "_CCU2C", "_PFUMX", "_L6MUX", "_DPR16X4"):
            s = s.split(cut)[0]
        return s
    return f"`{short(srcs[0])}` → `{short(sinks[-1])}` ({len(srcs)} chặng logic/định tuyến)"


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--no-fmax", action="store_true")
    ap.add_argument("--no-sweep", action="store_true")
    args = ap.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)

    jobs = [(f"rv_core_{n}", "rv_core", p) for n, p in CORE_CFGS.items()]
    jobs.append(("rv_core_sc", "rv_core_sc", {}))
    jobs += [(p, p, {}) for p in PERIPHS]
    if not args.no_sweep:
        for h in (16, 64, 256, 1024):
            for t in (8, 16, 32, 64):
                jobs.append((f"sweep_bht{h}_btb{t}", "rv_core",
                             dict(BP_MODE=2, BHT_ENTRIES=h, BTB_ENTRIES=t)))
    with ThreadPoolExecutor(max_workers=JOBS) as ex:
        area = list(ex.map(lambda j: generic_area(*j), jobs))
        soc = generic_area("soc_top", "soc_top", {}, blackbox="blackbox ram_dp")
        area.append(soc)
        fm = list(ex.map(lambda k: fmax(k, *FMAX_JOBS[k]), FMAX_JOBS)) if not args.no_fmax else []

    with open(OUT / "area.csv", "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["name", "top", "params", "cells", "flip_flops"])
        for a in area:
            w.writerow([a["name"], a["top"], json.dumps(a["params"]), a["cells"], a["ffs"]])
    summary = dict(
        area={a["name"]: dict(cells=a["cells"], ffs=a["ffs"]) for a in area},
        sweep_cells={a["name"].replace("sweep_", ""): a["cells"] for a in area
                     if a["name"].startswith("sweep_")},
        fmax_mhz={r["name"]: r["fmax_mhz"] for r in fm},
        ecp5={r["name"]: dict(lut4=r["lut4"], ff=r["ff"], fmax_mhz=r["fmax_mhz"]) for r in fm},
    )
    old = OUT / "summary.json"
    if args.no_fmax and old.exists():  # keep previous Fmax results
        prev = json.loads(old.read_text())
        summary["fmax_mhz"] = prev.get("fmax_mhz", {})
        summary["ecp5"] = prev.get("ecp5", {})
    old.write_text(json.dumps(summary, indent=2))

    A = summary["area"]
    lines = ["# Tổng hợp – diện tích và Fmax", "",
             "Diện tích: Yosys `synth -flatten` (thư viện generic, đơn vị = số cell logic sau tối ưu); "
             "`ram_dp` là black box nên **RAM 128 KB không được tính**. Fmax: Yosys `synth_ecp5` + "
             "`nextpnr-ecp5` (LFE5U-85F, CABGA756, seed 1) – chỉ là **ước lượng trên FPGA**; không làm "
             "place & route ASIC (ngoài phạm vi). Tái tạo: `make synth`.", "",
             "## Bảng S1 – Diện tích lõi và ngoại vi (generic)", "",
             "| Khối | Tham số | Cell | Flip-flop |", "|---|---|---|---|"]
    for a in area:
        if a["name"].startswith("sweep_"):
            continue
        lines.append(f"| `{a['name']}` | {a['params'] or '–'} | {a['cells']} | {a['ffs']} |")
    lines += ["", "Nguồn: `results/synth/area.csv`.", ""]
    if summary["sweep_cells"]:
        lines += ["## Bảng S2 – Diện tích `rv_core` theo BHT × BTB (BP_MODE 2, số cell)", "",
                  "| BHT \\ BTB | 8 | 16 | 32 | 64 |", "|---|---|---|---|---|"]
        for h in (16, 64, 256, 1024):
            lines.append(f"| {h} | " + " | ".join(str(summary['sweep_cells'].get(f'bht{h}_btb{t}', '–'))
                                                  for t in (8, 16, 32, 64)) + " |")
        lines.append("")
    if summary["ecp5"]:
        lines += ["## Bảng S3 – ECP5: tài nguyên và Fmax ước lượng", "",
                  "| Thiết kế | LUT4 | FF | Fmax (MHz) | Đường găng (tóm tắt) |", "|---|---|---|---|---|"]
        for r in fm or []:
            lines.append(f"| `{r['name']}` | {r['lut4']} | {r['ff']} | {r['fmax_mhz']} | "
                         f"{summarize_cp(r['critical_path'])} |")
        if not fm:
            for k, v in summary["ecp5"].items():
                lines.append(f"| `{k}` | {v['lut4']} | {v['ff']} | {v['fmax_mhz']} | |")
        lines += ["", "Chi tiết từng chặng: `results/synth/critical_path_<tên>.txt`. "
                  "`soc_top_*_1k` dùng RAM 1 KB (LUT RAM) thay cho 128 KB để đặt được trên FPGA "
                  "và tính cả đường đọc RAM tổ hợp; Fmax của lõi đứng riêng (`m1c1_bp2`, `sc`…) **không** "
                  "gồm đường qua RAM (cổng vào/ra lõi không được ràng buộc), nên so sánh single-cycle với "
                  "pipeline phải dùng các dòng `soc_top_*`.", ""]
    (OUT / "summary.md").write_text("\n".join(lines))
    print("\n".join(lines))


if __name__ == "__main__":
    main()

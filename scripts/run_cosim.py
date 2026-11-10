#!/usr/bin/env python3
"""C++ co-simulation with Spike in lock-step (cosim/cosim_main.cpp).

For every configuration the harness is built with Verilator (--cc --exe,
top soc_top, -DCOSIM so wb_stage calls the DPI function cosim_commit at each
retired instruction). Each riscv-test and benchmark (CONSOLE=sim) is run with
Spike as a child process; every retired instruction is compared at once with
Spike's next commit and the run stops at the first difference.

Also:
  * mutant check: the RTL is rebuilt with -DCOSIM_MUTANT (deliberate SLTU bug
    in alu.sv) and every program of m1c1_bp2 is run; the report lists which
    programs detect the bug and where;
  * lock-step figure: commits of one benchmark window written by the harness
    (+trace_csv) drawn as waveforms (RTL retire vs Spike commit).

Results: results/cosim/<config>.md, mutant.md, summary.md, lockstep.png.

Usage:
  run_cosim.py                       # default configurations + mutant + figure
  run_cosim.py --config m1c1_bp2 --tests add,sltu
"""
import argparse
import csv
import re
import shutil
import subprocess
import sys
import threading
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import (BUILD, JOBS, MARCH, RESULTS, ROOT, SPIKE, VERILATOR, _newest_mtime,  # noqa: E402
                    cfg_name, cfg_variant, rtl_files, run)
from compare_spike import bench_jobs, isa_jobs  # noqa: E402
from run_isa import CONFIGS  # noqa: E402

OUT = RESULTS / "cosim"
DEFAULT = ["m1c1_bp2", "m1c0_bp2", "m0c0_bp2", "sc"]
LINE_RE = re.compile(r"^COSIM (\w+) (.*?) \| commits=(\d+) masked=(\d+) cycles=(\d+) wall=([\d.]+)s"
                     r"(?: \| known: (.*))?$", re.M)
MISMATCH_RE = re.compile(r"RTL (pc 0x[0-9a-f]+ \(0x[0-9a-f]+\)[^|]*)\| Spike (pc [^|]*)")

_locks, _guard = {}, threading.Lock()


def build_cosim(cfg, mutant=False):
    name = cfg_name(cfg) + ("_mutant" if mutant else "")
    with _guard:
        lock = _locks.setdefault(name, threading.Lock())
    with lock:
        out = BUILD / "cosim" / name
        exe = out / "Vcosim"
        deps = [ROOT / "rtl", ROOT / "cosim", Path(__file__)]
        if exe.exists() and exe.stat().st_mtime > _newest_mtime(deps):
            return exe
        obj = out / "obj"
        if obj.exists():
            shutil.rmtree(obj)
        obj.mkdir(parents=True)
        cmd = [VERILATOR, "--cc", "--exe", "--build", "-j", str(JOBS), "--top-module", "soc_top",
               "-Mdir", str(obj), "-o", "Vcosim", "-O3", "--x-assign", "fast", "--x-initial", "fast",
               "-Wno-fatal", "-Wno-lint", "-Wno-style", "-CFLAGS", "-O2", "-DCOSIM"]
        if mutant:
            cmd.append("-DCOSIM_MUTANT")
        cmd += [f"-G{k}={v}" for k, v in cfg.items()]
        cmd += rtl_files() + [str(ROOT / "cosim/cosim_main.cpp")]
        run(cmd, log=out / "build.log")
        shutil.move(str(obj / "Vcosim"), str(exe))
        shutil.rmtree(obj)
        return exe


def run_one(exe, cfg, name, elf, hexf, tohost, extra=()):
    isa = MARCH[cfg_variant(cfg)] + "_zicntr"
    cmd = [str(exe), f"+elf={elf}", f"+hex={hexf}", f"+tohost={tohost}", f"+isa={isa}",
           f"+spike={shutil.which(SPIKE) or SPIKE}", "+max_cycles=50000000"] + list(extra)
    try:
        res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                             timeout=1800, errors="replace")
        text = res.stdout
    except subprocess.TimeoutExpired:
        text = "COSIM DIFF wall-clock timeout | commits=0 masked=0 cycles=0 wall=1800s"
    m = LINE_RE.search(text)
    if not m:
        return dict(test=name, result="ERROR", detail=text.strip().splitlines()[-1][:200] if text.strip() else "",
                    commits=0, masked=0, cycles=0, wall=0.0, known="")
    return dict(test=name, result=m.group(1), detail=m.group(2), commits=int(m.group(3)),
                masked=int(m.group(4)), cycles=int(m.group(5)), wall=float(m.group(6)),
                known=m.group(7) or "")


def jobs_for(cname, tf=None, bench=True):
    jobs = list(isa_jobs(cname, tf))
    if bench and not tf:
        jobs += list(bench_jobs(cname))
    return jobs


def report(cname, rows):
    ok = sum(r["result"] in ("MATCH", "KNOWN") for r in rows)
    commits = sum(r["commits"] for r in rows)
    wall = sum(r["wall"] for r in rows)
    L = [f"# Co-simulation C++ lock-step với Spike – cấu hình `{cname}`", "",
         "Harness `cosim/cosim_main.cpp` (Verilator C++): mỗi lệnh RTL retire được so **ngay khi chạy** với lệnh "
         "kế tiếp Spike commit (pc, mã lệnh, thanh ghi đích + giá trị, địa chỉ load, địa chỉ + dữ liệu store); "
         "lệch là dừng. Giá trị đọc từ counter được theo dõi (taint) như `compare_spike.py`.", "",
         f"MATCH (kể cả KNOWN) {ok} / {len(rows)}; {commits} lệnh được so khớp; tổng thời gian chạy {wall:.1f} s.", "",
         "| Chương trình | Kết quả | Lệnh so khớp | Giá trị counter bị che | Chu kỳ | Chi tiết |",
         "|---|---|---|---|---|---|"]
    for r in rows:
        det = r["detail"] + (f"; known: {r['known']}" if r["known"] else "")
        L.append(f"| {r['test']} | {r['result']} | {r['commits']} | {r['masked']} | {r['cycles']} | {det} |")
    L += ["", f"Tái tạo: `.venv/bin/python scripts/run_cosim.py --config {cname}`", ""]
    (OUT / f"{cname}.md").write_text("\n".join(L))
    return ok, commits, wall


def mutant_check():
    """Run every program of m1c1_bp2 on the SLTU mutant."""
    cname = "m1c1_bp2"
    cfg = CONFIGS[cname]
    exe = build_cosim(cfg, mutant=True)
    jobs = jobs_for(cname)
    with ThreadPoolExecutor(max_workers=JOBS) as ex:
        rows = list(ex.map(lambda j: run_one(exe, cfg, *j), jobs))
    det = [r for r in rows if r["result"] == "DIFF"]
    L = ["# Co-simulation với RTL có lỗi cài sẵn (mutant)", "",
         "Lỗi cài sẵn (`alu.sv`, chỉ khi `-DCOSIM_MUTANT`): SLTU/SLTIU lấy bit 31 của hiệu thay cho bit mượn – "
         "sai khi hai toán hạng khác nhau ở bit 31 (ví dụ `0 < 0xffff8000`).", "",
         f"Chương trình phát hiện lỗi: **{len(det)} / {len(rows)}** (cấu hình `{cname}`). Mỗi lần phát hiện, "
         "harness dừng ngay ở lệnh sai đầu tiên và in 6 lệnh khớp trước đó.", "",
         "| Chương trình | Phát hiện ở lệnh # | RTL | Spike |", "|---|---|---|---|"]
    for r in det:
        m = MISMATCH_RE.search(r["detail"])
        n = r["detail"].split(" ")[0]
        L.append(f"| {r['test']} | {n} | {m.group(1).strip() if m else ''} | {m.group(2).strip() if m else ''} |")
    miss = [r["test"] for r in rows if r["result"] != "DIFF"]
    L += ["", f"Không phát hiện ({len(miss)} chương trình, không thực thi SLTU/SLTIU với toán hạng gây sai): "
          + ", ".join(f"`{t}`" for t in miss) + ".", ""]
    (OUT / "mutant.md").write_text("\n".join(L))
    return len(det), len(rows)


class _Trace:
    """Minimal stand-in for vcd2png.Vcd built from the harness CSV."""

    def __init__(self):
        self.data, self.width = {}, {}

    def add(self, name, width, pts):
        self.width[name] = width
        self.data[name] = ([t for t, _ in pts], [v for _, v in pts])

    def value(self, name, t):
        ts, vs = self.data[name]
        v = None
        for tt, vv in zip(ts, vs):
            if tt <= t:
                v = vv
        return v


def lockstep_figure(cname="m1c1_bp2", bench="qsort", start=0, scan=50000, n=10, max_span=16):
    """Trace `scan` commits from `start`, draw the window of `n` commits with the most
    cycles without a retirement (stall / flush bubbles), at most `max_span` cycles long."""
    from vcd2png import plot
    cfg = CONFIGS[cname]
    exe = build_cosim(cfg)
    job = next(j for j in bench_jobs(cname) if j[0] == "bench-" + bench)
    csvf = OUT / f"lockstep_{bench}.csv"
    r = run_one(exe, cfg, *job, extra=[f"+trace_csv={csvf}", f"+trace_from={start}", f"+trace_n={scan}"])
    allrows = list(csv.DictReader(open(csvf)))
    best, best_gap = 0, -1
    for i in range(len(allrows) - n):
        span = int(allrows[i + n - 1]["cycle"]) - int(allrows[i]["cycle"]) + 1
        if span <= max_span and span - n > best_gap:
            best, best_gap = i, span - n
    rows = allrows[best:best + n]
    start = int(rows[0]["idx"])
    csvf.write_text("".join([open(csvf).readline()] + [",".join(x.values()) + "\n" for x in rows]))
    P = 20
    c0, c1 = int(rows[0]["cycle"]) - 1, int(rows[-1]["cycle"]) + 2
    by_cycle = {int(x["cycle"]): x for x in rows}
    tr = _Trace()
    ret, rpc, spc, rval, sval, ok = [], [], [], [], [], []
    last = {"rpc": None, "spc": None, "rval": None, "sval": None}

    def put(lst, t, v):              # a bus point only when the value changes
        if not lst or lst[-1][1] != v:
            lst.append((t, v))

    for c in range(c0, c1):
        t = c * P
        x = by_cycle.get(c)
        ret.append((t, 1 if x else 0))
        ok.append((t, 1 if x and x["status"] in ("MATCH", "MASKED") else 0))
        if x:
            last["rpc"] = int(x["rtl_pc"], 16) - 0x80000000
            last["spc"] = int(x["spike_pc"], 16) - 0x80000000
            if int(x["rtl_rd"]) >= 0:
                last["rval"] = int(x["rtl_val"], 16) & 0xFFFF
            if int(x["spike_rd"]) >= 0:
                last["sval"] = int(x["spike_val"], 16) & 0xFFFF
        put(rpc, t, last["rpc"])
        put(spc, t, last["spc"])
        put(rval, t, last["rval"])
        put(sval, t, last["sval"])
    clk = []
    for c in range(c0, c1):
        clk += [(c * P - P // 2, 0), (c * P, 1)]
    tr.add("clk", 1, clk)
    names = ["RTL retire (WB)", "RTL pc − 0x8000_0000", "Spike pc − 0x8000_0000",
             "RTL rd ← (16 bit thấp)", "Spike rd ← (16 bit thấp)", "khớp (mỗi lệnh retire)"]
    for name, pts, w in zip(names, (ret, rpc, spc, rval, sval, ok), (1, 32, 32, 32, 32, 1)):
        tr.add(name, w, pts)
    sigs = ["clk"] + names
    out = OUT / "lockstep.png"
    plot(tr, sigs, c0 * P, (c1 - 1) * P, out,
         f"Hình W10. Co-simulation lock-step ({bench}, lệnh #{start}–#{start + n - 1}): mỗi lệnh RTL retire "
         "được so ngay với lệnh Spike commit", period=P)
    return out, r


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--config", action="append", choices=list(CONFIGS))
    ap.add_argument("--tests")
    ap.add_argument("--no-bench", action="store_true")
    ap.add_argument("--no-mutant", action="store_true")
    args = ap.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    cnames = args.config or DEFAULT
    tf = set(args.tests.split(",")) if args.tests else None
    summary, bad = [], 0
    for cname in cnames:
        cfg = CONFIGS[cname]
        exe = build_cosim(cfg)
        jobs = jobs_for(cname, tf, bench=not args.no_bench)
        with ThreadPoolExecutor(max_workers=JOBS) as ex:
            rows = list(ex.map(lambda j: run_one(exe, cfg, *j), jobs))
        ok, commits, wall = report(cname, rows)
        summary.append((cname, ok, len(rows), commits, wall))
        bad += len(rows) - ok
        print(f"[cosim] {cname:10s} MATCH {ok}/{len(rows)}  ({commits} lệnh so khớp, {wall:.1f} s)")
        for r in rows:
            if r["result"] not in ("MATCH", "KNOWN"):
                print(f"        {r['result']}: {r['test']}: {r['detail'][:160]}")
    if tf:
        sys.exit(1 if bad else 0)
    mut = None if args.no_mutant else mutant_check()
    fig, _ = lockstep_figure()
    L = ["# Co-simulation C++ lock-step với Spike – tổng hợp", "",
         "| Cấu hình | MATCH | Tổng | Lệnh so khớp | Thời gian (s) |", "|---|---|---|---|---|"]
    L += [f"| `{c}` | {o} | {t} | {n} | {w:.1f} |" for c, o, t, n, w in summary]
    if mut:
        L += ["", f"Mutant (lỗi SLTU cài sẵn): phát hiện ở {mut[0]} / {mut[1]} chương trình – xem `mutant.md`."]
    L += ["", f"Hình lock-step: `{fig.relative_to(ROOT)}`.", "", "Tái tạo: `make cosim`", ""]
    (OUT / "summary.md").write_text("\n".join(L))
    print(f"[cosim] mutant: {mut[0]}/{mut[1]} chương trình phát hiện lỗi" if mut else "")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()

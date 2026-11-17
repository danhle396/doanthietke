#!/usr/bin/env python3
"""Code + functional coverage (spec 10.5).

1. Unit testbenches built with --coverage (run_unit.py --coverage).
2. tb_soc coverage builds (--coverage-line --coverage-toggle --coverage-user,
   functional points from tb/cov via `bind`) for every configuration of the
   riscv-tests matrix; runs: riscv-tests of each configuration, all system
   tests (m1c1_bp2; exceptions also on m1c0_bp2) and the benchmarks.
3. verilator_coverage merges everything -> build/cov/merged.dat, line coverage
   is exported as lcov info and summarized per file / directory in
   results/coverage/summary.md (+ uncovered lines in uncovered.md);
   functional points are reported by scripts/cov_report.py.

Usage: run_cov.py [--skip-runs]
"""
import argparse
import re
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import (BUILD, JOBS, RESULTS, ROOT, build_isa_test, build_soc, cfg_variant,  # noqa: E402
                    isa_tests, run, run_sim)
from build_sw import build_program, program_dirs  # noqa: E402
from run_isa import CONFIGS, EXCLUDED, suites_for  # noqa: E402
from run_systest import TESTS_DIR, ORDER, read_cfg  # noqa: E402
from md_table import write_md  # noqa: E402

COV = BUILD / "cov"
OUT = RESULTS / "coverage"


def sim_jobs():
    jobs = []
    for cname, cfg in CONFIGS.items():
        v = cfg_variant(cfg)
        for suite in suites_for(cname):
            for t in isa_tests(suite):
                name = f"{suite}-p-{t}"
                if name in EXCLUDED:
                    continue
                elf, hexf, tohost = build_isa_test(suite, t, v)
                jobs.append((cname, f"isa_{cname}_{name}", hexf,
                             [f"+tohost={tohost}", "+commitlog=/dev/null"]))
    for t in ORDER:
        tdir = TESTS_DIR / t
        tc = read_cfg(tdir)
        for cname in [c.strip() for c in tc.get("configs", "m1c1_bp2").split(",")]:
            elf = build_program("tests", tdir, cfg_variant(CONFIGS[cname]), "uart")
            args = [f"+max_cycles={tc.get('max_cycles', 2000000)}"]
            if "rx_file" in tc:
                args += [f"+uart_rx_file={tdir / tc['rx_file']}",
                         f"+uart_rx_mode={tc.get('rx_mode', 'line')}"]
            jobs.append((cname, f"sys_{cname}_{t}", elf.with_suffix(".hex"), args))
    for d in program_dirs("bench"):
        for cname in ("m1c1_bp2", "m1c1_bp1", "sc"):
            elf = build_program("bench", d, cfg_variant(CONFIGS[cname]), "sim")
            jobs.append((cname, f"bench_{cname}_{d.name}", elf.with_suffix(".hex"),
                         ["+max_cycles=50000000"]))
    return jobs


def run_job(job):
    cname, name, hexf, args = job
    exe = build_soc(CONFIGS[cname], coverage=True, trace=False)
    dat = COV / f"{name}.dat"
    ok, _ = run_sim(exe, hexf, args + [f"+verilator+coverage+file+{dat}"],
                    log=BUILD / "logs/cov" / f"{name}.log")
    return name, ok


# Explanations for lines that are not covered (file -> [(source substring, reason)])
EXPLAIN = {
    "rtl/core/alu.sv": [("default:", "nhánh `default` của `case (op)`: decoder chỉ sinh 10 mã ALU hợp lệ nên "
                         "nhánh này không thể xảy ra; giữ lại để tránh latch / X khi tổng hợp")],
    "rtl/periph/sim/sim_ctrl.sv": [("", "đường tự kết thúc dự phòng của SIM_CTRL (sau EXIT_DELAY = 1000 chu kỳ); "
                                    "trong mọi lần chạy `tb_soc` xử lý EXIT trước (D9) nên đường này không chạy – "
                                    "chỉ dùng khi SIM_CTRL được dùng mà không có testbench đó")],
    "rtl/core/wb_stage.sv": [("", "lệnh in commit log chỉ chạy khi có `+commitlog=`")],
}


def explain(rel, text):
    for sub, reason in EXPLAIN.get(rel, []):
        if sub in text:
            return reason
    return "CHƯA GIẢI THÍCH"


def fold():
    """Merge every per-run .dat into merged.dat and delete the per-run files."""
    merged = COV / "merged.dat"
    dats = sorted(str(p) for p in COV.glob("*.dat") if p.name != "merged.dat")
    if not dats:
        return
    tmp = COV / "merged.tmp.dat"
    run(["verilator_coverage", "--write", str(tmp)] + ([str(merged)] if merged.exists() else []) + dats)
    tmp.replace(merged)
    for d in dats:
        Path(d).unlink()


def line_summary(info):
    files = {}
    cur = None
    for line in info.read_text().splitlines():
        if line.startswith("SF:"):
            cur = line[3:]
            files.setdefault(cur, {})
        elif line.startswith("DA:") and cur:
            ln, cnt = line[3:].split(",")[:2]
            files[cur][int(ln)] = max(files[cur].get(int(ln), 0), int(cnt))
    return files


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--skip-runs", action="store_true")
    args = ap.parse_args()
    COV.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    if not args.skip_runs:
        for f in COV.glob("*.dat"):
            f.unlink()  # includes the previous merged.dat
        run([sys.executable, str(ROOT / "scripts/run_unit.py"), "--coverage"], check=False)
        for cname in CONFIGS:
            build_soc(CONFIGS[cname], coverage=True, trace=False)
        jobs = sim_jobs()
        merged = COV / "merged.dat"
        res = []
        # run in batches and fold each batch into merged.dat (keeps disk usage low)
        for i in range(0, len(jobs), 40):
            with ThreadPoolExecutor(max_workers=JOBS) as ex:
                res += list(ex.map(run_job, jobs[i:i + 40]))
            fold()
        bad = [n for n, ok in res if not ok]
        print(f"[cov] {len(res)} coverage runs, {len(bad)} failed {bad[:5]}")
    fold()
    merged = COV / "merged.dat"
    info = COV / "line.info"
    run(["verilator_coverage", "--filter-type", "line", "--write-info", str(info), str(merged)])
    tinfo = COV / "toggle.info"
    run(["verilator_coverage", "--filter-type", "toggle", "--write-info", str(tinfo), str(merged)])

    files = line_summary(info)
    tfiles = line_summary(tinfo)
    rows = []
    for f, lines in sorted(files.items()):
        rel = str(Path(f).resolve().relative_to(ROOT)) if f.startswith(str(ROOT)) else f
        if not rel.startswith("rtl/"):
            continue
        hit = sum(1 for c in lines.values() if c > 0)
        tl = tfiles.get(f, {})
        thit = sum(1 for c in tl.values() if c > 0)
        rows.append((rel, hit, len(lines), thit, len(tl), lines))
    def pct(a, b):
        return 100.0 * a / b if b else 100.0
    groups = {}
    for rel, h, n, th, tn, _ in rows:
        g = "rtl/core" if rel.startswith("rtl/core/") else \
            "rtl/periph" if rel.startswith("rtl/periph/") else "rtl (khác)"
        a = groups.setdefault(g, [0, 0, 0, 0])
        a[0] += h; a[1] += n; a[2] += th; a[3] += tn
    md = ["# Coverage", "",
          "Gộp mọi lần chạy: unit testbench, riscv-tests (cả ma trận cấu hình), system test, "
          "benchmark (m1c1_bp2, m1c1_bp1, sc). Công cụ: Verilator `--coverage-line "
          "--coverage-toggle --coverage-user`, gộp bằng `verilator_coverage`. Tái tạo: `make cov`. "
          "(Không có `genhtml` trên máy nên không xuất HTML; file lcov: `build/cov/line.info`.)", "",
          "## Bảng C1 – Theo thư mục (mục tiêu line ≥ 90% cho rtl/core và rtl/periph)", "",
          "| Thư mục | Line | Toggle |", "|---|---|---|"]
    for g, (h, n, th, tn) in sorted(groups.items()):
        md.append(f"| {g} | {pct(h, n):.1f}% ({h}/{n}) | {pct(th, tn):.1f}% ({th}/{tn}) |")
    md += ["", "## Bảng C2 – Theo file", "", "| File | Line | Toggle |", "|---|---|---|"]
    for rel, h, n, th, tn, _ in rows:
        md.append(f"| `{rel}` | {pct(h, n):.1f}% ({h}/{n}) | {pct(th, tn):.1f}% ({th}/{tn}) |")
    md += ["", "Các dòng chưa phủ và giải thích: `results/coverage/uncovered.md`. "
           "Functional coverage: `results/coverage/functional.md`.", ""]
    write_md(OUT / "summary.md", "\n".join(md))
    un = ["# Dòng RTL chưa được phủ (line coverage)", ""]
    for rel, h, n, th, tn, lines in rows:
        miss = sorted(l for l, c in lines.items() if c == 0)
        if not miss:
            continue
        src = (ROOT / rel).read_text().splitlines()
        un.append(f"## `{rel}` – {len(miss)} dòng")
        un.append("")
        un.append("| Dòng | Mã | Giải thích |")
        un.append("|---|---|---|")
        for l in miss:
            code = src[l - 1].strip() if l <= len(src) else ""
            un.append(f"| {l} | `{code.replace('|', '¦')}` | {explain(rel, code)} |")
        un.append("")
    write_md(OUT / "uncovered.md", "\n".join(un))
    run([sys.executable, str(ROOT / "scripts/cov_report.py"), str(merged)])
    print("\n".join(md[:12 + len(groups)]))


if __name__ == "__main__":
    main()

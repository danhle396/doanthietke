#!/usr/bin/env python3
"""Build + run riscv-tests on one or more RTL configurations.

Outputs results/isa/<config>.csv, results/isa/<config>.md and (with --matrix)
results/isa/summary.md. Exit code != 0 if any non-excluded test fails.

Examples:
  run_isa.py --matrix                     # full configuration matrix (spec 10.2)
  run_isa.py --config sc                  # single-cycle core, rv32ui only
  run_isa.py --config m1c1_bp2 --tests add,jal
"""
import argparse
import csv
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import (BUILD, JOBS, RESULTS, ISA_SUITES, build_isa_test, build_soc,  # noqa: E402
                    cfg_name, cfg_variant, isa_tests, make_cfg, parse_perf, run_sim)

# Tests that are allowed to be excluded (spec 10.2), with the justification.
EXCLUDED = {
    "rv32ui-p-ma_data": "core traps on misaligned load/store (allowed by the spec); "
                        "the trap behaviour is checked by rv32mi-p-ma_addr",
}
EXCLUDED_FILE = Path(__file__).resolve().parent / "isa_exclusions.txt"
if EXCLUDED_FILE.exists():
    for line in EXCLUDED_FILE.read_text().splitlines():
        if line.strip() and not line.startswith("#"):
            name, reason = line.split(":", 1)
            EXCLUDED[name.strip()] = reason.strip()

# Named configurations of the verification matrix.
CONFIGS = {
    "m1c1_bp0": make_cfg(ENABLE_M=1, ENABLE_C=1, BP_MODE=0),
    "m1c1_bp1": make_cfg(ENABLE_M=1, ENABLE_C=1, BP_MODE=1),
    "m1c1_bp2": make_cfg(ENABLE_M=1, ENABLE_C=1, BP_MODE=2),
    "m1c0_bp2": make_cfg(ENABLE_M=1, ENABLE_C=0, BP_MODE=2),
    "m0c0_bp2": make_cfg(ENABLE_M=0, ENABLE_C=0, BP_MODE=2),
    "sc": make_cfg(CORE_SC=1),
    # FPGA (DE2) build: falling-edge banked RAM, 32 KB
    "m1c1_bp2_sync": make_cfg(ENABLE_M=1, ENABLE_C=1, BP_MODE=2, RAM_SYNC=1, RAM_DEPTH=8192),
}
MATRIX = list(CONFIGS)


def suites_for(cname):
    cfg = CONFIGS[cname]
    if cfg["CORE_SC"]:
        return ["rv32ui"]
    return ISA_SUITES[cfg_variant(cfg)]


def run_config(cname, test_filter=None, max_cycles=2000000):
    cfg = CONFIGS[cname]
    variant = cfg_variant(cfg)
    exe = build_soc(cfg)
    jobs = []
    for suite in suites_for(cname):
        for t in isa_tests(suite):
            if test_filter and t not in test_filter:
                continue
            jobs.append((suite, t))

    def one(job):
        suite, t = job
        name = f"{suite}-p-{t}"
        if name in EXCLUDED:
            return dict(test=name, suite=suite, variant=variant, result="EXCLUDED",
                        cycles="", instret="", note=EXCLUDED[name])
        try:
            elf, hexf, tohost = build_isa_test(suite, t, variant)
        except Exception as e:  # build failure is a test failure
            return dict(test=name, suite=suite, variant=variant, result="BUILD_FAIL",
                        cycles="", instret="", note=str(e)[:200])
        log = BUILD / "logs/isa" / cname / f"{name}.log"
        ok, out = run_sim(exe, hexf, [f"+tohost={tohost}", f"+max_cycles={max_cycles}"], log=log)
        perf = parse_perf(out)
        note = ""
        if not ok:
            fails = [l for l in out.splitlines() if l.startswith("FAIL")]
            note = fails[0] if fails else "no PASS"
        return dict(test=name, suite=suite, variant=variant, result="PASS" if ok else "FAIL",
                    cycles=perf.get("cycles", ""), instret=perf.get("minstret", ""), note=note)

    with ThreadPoolExecutor(max_workers=JOBS) as ex:
        rows = list(ex.map(one, jobs))
    return cfg, rows


def write_results(cname, cfg, rows):
    out = RESULTS / "isa"
    out.mkdir(parents=True, exist_ok=True)
    with open(out / f"{cname}.csv", "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=["test", "suite", "variant", "result", "cycles",
                                          "instret", "note"])
        w.writeheader()
        w.writerows(rows)
    npass = sum(r["result"] == "PASS" for r in rows)
    nexc = sum(r["result"] == "EXCLUDED" for r in rows)
    nfail = len(rows) - npass - nexc
    lines = [f"# riscv-tests – cấu hình `{cname}`", "",
             f"Tham số RTL: `{cfg}` – biến thể ELF: `{cfg_variant(cfg)}`", "",
             f"PASS {npass} / FAIL {nfail} / EXCLUDED {nexc} (tổng {len(rows)})", "",
             "| Test | Kết quả | Chu kỳ | minstret | Ghi chú |", "|---|---|---|---|---|"]
    for r in rows:
        lines.append(f"| {r['test']} | {r['result']} | {r['cycles']} | {r['instret']} | {r['note']} |")
    lines += ["", f"Tái tạo: `.venv/bin/python scripts/run_isa.py --config {cname}`", ""]
    (out / f"{cname}.md").write_text("\n".join(lines))
    return npass, nfail, nexc


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--config", action="append", choices=list(CONFIGS))
    ap.add_argument("--matrix", action="store_true")
    ap.add_argument("--tests", help="comma-separated test names (without suite prefix)")
    ap.add_argument("--max-cycles", type=int, default=2000000)
    args = ap.parse_args()
    cnames = MATRIX if args.matrix or not args.config else args.config
    tf = set(args.tests.split(",")) if args.tests else None

    summary = []
    total_fail = 0
    for cname in cnames:
        cfg, rows = run_config(cname, tf, args.max_cycles)
        npass, nfail, nexc = write_results(cname, cfg, rows)
        total_fail += nfail
        summary.append((cname, cfg_variant(cfg), ",".join(suites_for(cname)), npass, nfail, nexc))
        print(f"[isa] {cname:10s} PASS {npass:3d}  FAIL {nfail:3d}  EXCLUDED {nexc}")
        for r in rows:
            if r["result"] not in ("PASS", "EXCLUDED"):
                print(f"      {r['result']}: {r['test']} {r['note']}")

    if args.matrix and not tf:
        lines = ["# riscv-tests – ma trận cấu hình", "",
                 "| Cấu hình RTL | ELF | Bộ test | PASS | FAIL | EXCLUDED |",
                 "|---|---|---|---|---|---|"]
        for c, v, s, p, f, e in summary:
            lines.append(f"| `{c}` | `{v}` | {s} | {p} | {f} | {e} |")
        lines += ["", "Test bị loại trừ và lý do:", ""]
        for k, v in sorted(EXCLUDED.items()):
            lines.append(f"- `{k}`: {v}")
        lines += ["", "Tái tạo: `make isa` (= `.venv/bin/python scripts/run_isa.py --matrix`)", ""]
        (RESULTS / "isa/summary.md").write_text("\n".join(lines))
    sys.exit(1 if total_fail else 0)


if __name__ == "__main__":
    main()

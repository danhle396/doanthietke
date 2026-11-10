#!/usr/bin/env python3
"""Build and run every unit testbench in tb/unit (Verilator --binary --timing).

A test passes only if the exit code is 0 AND the log contains a line `PASS`.
Writes results/unit/summary.md and prints a summary table.

Usage:
  run_unit.py                    # all testbenches, seed 1
  run_unit.py --tb tb_alu --seed 7
  run_unit.py --coverage         # coverage build, writes build/cov/unit_*.dat
"""
import argparse
import re
import shutil
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import BUILD, JOBS, RESULTS, ROOT, VERILATOR, _newest_mtime, run, run_sim  # noqa: E402

PKG = "rtl/pkg/rv_pkg.sv"
FIFO = "rtl/periph/sync_fifo.sv"

# testbench -> sources (RTL + BFM), testbench file itself is added automatically
UNIT = {
    "tb_alu": [PKG, "rtl/core/alu.sv"],
    "tb_regfile": ["rtl/core/regfile.sv"],
    "tb_muldiv": [PKG, "rtl/core/muldiv.sv"],
    "tb_compressed_decoder": [PKG, "rtl/core/compressed_decoder.sv"],
    "tb_bp": [PKG, "rtl/core/bp/bht.sv", "rtl/core/bp/btb.sv", "rtl/core/bp/branch_predictor.sv"],
    "tb_csr": [PKG, "rtl/core/csr_file.sv"],
    "tb_fifo": [FIFO],
    "tb_apb_bridge": ["rtl/bus/apb_bridge.sv", "tb/bfm/apb_slave_model.sv", "tb/bfm/wb_checker.sv"],
    "tb_dbus_xbar": ["rtl/bus/dbus_xbar.sv", "tb/bfm/wb_checker.sv"],
    "tb_uart": [FIFO, "rtl/periph/uart/uart_tx.sv", "rtl/periph/uart/uart_rx.sv",
                "rtl/periph/uart/uart_apb.sv", "tb/bfm/apb_master_bfm.sv", "tb/bfm/uart_bfm.sv"],
    "tb_spi": [FIFO, "rtl/periph/spi/spi_master.sv", "rtl/periph/spi/spi_apb.sv",
               "tb/bfm/apb_master_bfm.sv", "tb/bfm/spi_slave_bfm.sv", "tb/bfm/spi_flash_bfm.sv"],
    "tb_timer": ["rtl/periph/timer/timer64_apb.sv", "tb/bfm/apb_master_bfm.sv"],
    "tb_gpio": ["rtl/periph/gpio/gpio_apb.sv", "tb/bfm/apb_master_bfm.sv"],
    "tb_intc": ["rtl/periph/intc/intc_apb.sv", "tb/bfm/apb_master_bfm.sv"],
}

# Functional-coverage bind files added to coverage builds of unit testbenches
COV_FILES = {
    "tb_uart": ["tb/cov/uart_cov.sv", "tb/cov/fifo_cov.sv"],
    "tb_spi": ["tb/cov/spi_cov.sv", "tb/cov/fifo_cov.sv"],
    "tb_fifo": ["tb/cov/fifo_cov.sv"],
    "tb_bp": ["tb/cov/btb_cov.sv"],
}

# Optional pre-build step (generated vectors)
PREP = {
    "tb_compressed_decoder": ["scripts/gen_rvc_vectors.py"],
}


def available():
    out = []
    for tb, srcs in UNIT.items():
        if (ROOT / "tb/unit" / f"{tb}.sv").exists() and all((ROOT / s).exists() for s in srcs):
            out.append(tb)
    return out


def build_tb(tb, coverage=False):
    out = BUILD / ("unit_cov" if coverage else "unit") / tb
    exe = out / f"V{tb}"
    srcs = [ROOT / s for s in UNIT[tb]] + [ROOT / "tb/unit" / f"{tb}.sv"]
    deps = srcs + [ROOT / "tb/unit/tb_common.svh", ROOT / "tb/bfm", ROOT / "tb/cov", Path(__file__)]
    for p in PREP.get(tb, []):
        run([sys.executable, str(ROOT / p)])
        deps.append(ROOT / p)
    if exe.exists() and exe.stat().st_mtime > _newest_mtime(deps):
        return exe
    obj = out / "obj"
    if obj.exists():
        shutil.rmtree(obj)
    obj.mkdir(parents=True)
    cmd = [VERILATOR, "--binary", "--timing", "-j", str(JOBS), "--top-module", tb,
           "-Mdir", str(obj), "-o", f"V{tb}", "-Wno-fatal", "-Wno-lint", "-Wno-style",
           f"-I{ROOT / 'tb/unit'}", f"-I{ROOT / 'tb/bfm'}", f"-I{BUILD / 'gen'}", "-CFLAGS", "-O1"]
    if coverage:
        cmd += ["--coverage-line", "--coverage-toggle", "--coverage-user"]
        srcs += [ROOT / f for f in COV_FILES.get(tb, [])]
    cmd += [str(s) for s in srcs]
    run(cmd, log=out / "build.log")
    shutil.move(str(obj / f"V{tb}"), str(exe))
    shutil.rmtree(obj)
    return exe


def run_tb(tb, seed, coverage=False):
    t0 = time.time()
    try:
        exe = build_tb(tb, coverage)
    except Exception as e:
        return dict(tb=tb, result="BUILD_FAIL", seed=seed, time=0, info=str(e)[:200])
    log = BUILD / "logs/unit" / f"{tb}.log"
    args = [str(exe), f"+seed={seed}"]
    if coverage:
        (BUILD / "cov").mkdir(parents=True, exist_ok=True)
        args.append(f"+verilator+coverage+file+{BUILD / 'cov' / f'unit_{tb}.dat'}")
    res = run(args, check=False, log=log, timeout=1800, cwd=str(BUILD))
    ok = res.returncode == 0 and re.search(r"^PASS\s*$", res.stdout, re.M) is not None
    m = re.search(r"(\d+) checks passed", res.stdout)
    info = f"{m.group(1)} checks" if m else ""
    if not ok:
        fl = [l for l in res.stdout.splitlines() if l.startswith(("FAIL", "ERROR"))]
        info = fl[0] if fl else f"exit {res.returncode}"
    return dict(tb=tb, result="PASS" if ok else "FAIL", seed=seed,
                time=round(time.time() - t0, 1), info=info)


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--tb", action="append")
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--coverage", action="store_true")
    args = ap.parse_args()
    tbs = args.tb or available()
    missing = [t for t in UNIT if t not in available()]
    with ThreadPoolExecutor(max_workers=max(1, JOBS // 2)) as ex:
        rows = list(ex.map(lambda t: run_tb(t, args.seed, args.coverage), tbs))
    print(f"{'Testbench':26s} {'Result':10s} {'Seed':>5s} {'Time(s)':>8s}  Info")
    for r in rows:
        print(f"{r['tb']:26s} {r['result']:10s} {r['seed']:5d} {r['time']:8.1f}  {r['info']}")
    if not args.tb and not args.coverage:
        lines = ["# Unit testbench – tổng kết", "",
                 "| Testbench | Kết quả | Seed | Thời gian (s) | Ghi chú |", "|---|---|---|---|---|"]
        lines += [f"| {r['tb']} | {r['result']} | {r['seed']} | {r['time']} | {r['info']} |"
                  for r in rows]
        if missing:
            lines += ["", "Chưa có (chưa tới Phase tương ứng): " + ", ".join(missing)]
        lines += ["", "Tái tạo: `make unit` (= `.venv/bin/python scripts/run_unit.py`)", ""]
        (RESULTS / "unit").mkdir(parents=True, exist_ok=True)
        (RESULTS / "unit/summary.md").write_text("\n".join(lines))
    sys.exit(0 if all(r["result"] == "PASS" for r in rows) else 1)


if __name__ == "__main__":
    main()

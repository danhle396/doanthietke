#!/usr/bin/env python3
"""Run the C system tests (sw/tests/*) on tb_soc.

Each test directory may contain `test.cfg` (key = value):
  expect      : expected UART output file ('*' wildcards per line)
  rx_file     : bytes the UART BFM sends to the DUT (+uart_rx_file)
  rx_mode     : line (default) | all
  max_cycles  : timeout (default 2,000,000)
  configs     : comma-separated RTL configurations (default m1c1_bp2)
  plusargs    : extra plusargs
  require     : comma-separated conditions on [perf] counters, e.g. md_aborts>0
PASS = exit code 0 and "PASS" in the log (tb_soc checks SIM_CTRL exit code,
UART expectation and BFM error counters). Writes results/systest/summary.md.

Usage: run_systest.py [--test NAME ...] [--config CFG] [--trace]
"""
import argparse
import re
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import BUILD, JOBS, RESULTS, ROOT, build_soc, cfg_variant, parse_perf, run_sim  # noqa: E402
from build_sw import build_program  # noqa: E402
from run_isa import CONFIGS  # noqa: E402

TESTS_DIR = ROOT / "sw/tests"
ORDER = ["hello", "uart_irq_echo", "spi_flash", "spi_modes", "timer_irq", "gpio_irq",
         "irq_priority", "exceptions", "irq_during_div", "demo"]


def read_cfg(tdir):
    cfg = {}
    f = tdir / "test.cfg"
    if f.exists():
        for line in f.read_text().splitlines():
            line = line.split("#", 1)[0].strip()
            if "=" in line:
                k, v = line.split("=", 1)
                cfg[k.strip()] = v.strip()
    return cfg


def run_test(name, cname, trace=False):
    tdir = TESTS_DIR / name
    cfg = read_cfg(tdir)
    rtl = CONFIGS[cname]
    variant = cfg_variant(rtl)
    try:
        elf = build_program("tests", tdir, variant, "uart")
    except Exception as e:
        return dict(test=name, config=cname, result="BUILD_FAIL", cycles="", info=str(e)[:200])
    exe = build_soc(rtl)
    logdir = BUILD / "logs/systest" / cname
    logdir.mkdir(parents=True, exist_ok=True)
    args = [f"+max_cycles={cfg.get('max_cycles', 2000000)}",
            f"+uart_log={logdir / (name + '.uart.txt')}"]
    if "expect" in cfg:
        args.append(f"+uart_expect={tdir / cfg['expect']}")
    if "rx_file" in cfg:
        args.append(f"+uart_rx_file={tdir / cfg['rx_file']}")
        args.append(f"+uart_rx_mode={cfg.get('rx_mode', 'line')}")
    if trace:
        args += ["+trace", f"+trace_file={logdir / (name + '.fst')}"]
    args += cfg.get("plusargs", "").split()
    ok, out = run_sim(exe, elf.with_suffix(".hex"), args, log=logdir / f"{name}.log",
                      timeout=3600)
    perf = parse_perf(out)
    for cond in [c.strip() for c in cfg.get("require", "").split(",") if c.strip()]:
        m = re.match(r"(\w+)\s*(>=|>|==)\s*(\d+)", cond)
        v = perf.get(m.group(1), -1)
        good = {">": v > int(m.group(3)), ">=": v >= int(m.group(3)),
                "==": v == int(m.group(3))}[m.group(2)]
        if not good and ok:
            ok = False
            out += f"\nFAIL: requirement {cond} not met ({m.group(1)}={v})\n"
    info = ""
    if not ok:
        fails = [l for l in out.splitlines() if l.startswith("FAIL")]
        info = fails[0] if fails else "no PASS"
    else:
        m = re.findall(r"^\[uart\] (RESULT.*)$", out, re.M)
        info = m[-1] if m else ""
    return dict(test=name, config=cname, result="PASS" if ok else "FAIL",
                cycles=perf.get("cycles", ""), info=info)


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--test", action="append")
    ap.add_argument("--config", choices=list(CONFIGS))
    ap.add_argument("--trace", action="store_true")
    args = ap.parse_args()
    names = args.test or [n for n in ORDER if (TESTS_DIR / n).is_dir()]
    jobs = []
    for n in names:
        cfg = read_cfg(TESTS_DIR / n)
        for c in ([args.config] if args.config else cfg.get("configs", "m1c1_bp2").split(",")):
            jobs.append((n, c.strip()))
    for c in {c for _, c in jobs}:
        build_soc(CONFIGS[c])
    with ThreadPoolExecutor(max_workers=JOBS) as ex:
        rows = list(ex.map(lambda j: run_test(*j, trace=args.trace), jobs))
    print(f"{'Test':16s} {'Config':10s} {'Result':6s} {'Cycles':>10s}  Info")
    for r in rows:
        print(f"{r['test']:16s} {r['config']:10s} {r['result']:6s} {str(r['cycles']):>10s}  {r['info']}")
    missing = [n for n in ORDER if not (TESTS_DIR / n).is_dir()]
    if not args.test and not args.config:
        lines = ["# System test – tổng kết", "",
                 "| Test | Cấu hình RTL | Kết quả | Chu kỳ | Ghi chú |", "|---|---|---|---|---|"]
        lines += [f"| {r['test']} | `{r['config']}` | {r['result']} | {r['cycles']} | {r['info']} |"
                  for r in rows]
        if missing:
            lines += ["", "Chưa có: " + ", ".join(missing)]
        lines += ["", "Tiêu chí PASS: mã thoát 0 từ SIM_CTRL, output UART khớp file kỳ vọng "
                  "(nếu có), không có lỗi frame/parity ở BFM UART, không có lỗi giao thức ở BFM flash.",
                  "", "Tái tạo: `make systest` (= `.venv/bin/python scripts/run_systest.py`)", ""]
        (RESULTS / "systest").mkdir(parents=True, exist_ok=True)
        (RESULTS / "systest/summary.md").write_text("\n".join(lines))
    sys.exit(0 if all(r["result"] == "PASS" for r in rows) else 1)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Full regression (make regress): lint + unit + software build + riscv-tests
(whole configuration matrix) + Spike comparison + system tests.
Prints a PASS/FAIL table, writes results/regress.md and exits non-zero if any
step failed.
"""
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PY = str(ROOT / ".venv/bin/python")

STEPS = [
    ("lint", ["bash", "scripts/lint.sh"]),
    ("unit", [PY, "scripts/run_unit.py"]),
    ("sw", [PY, "scripts/build_sw.py"]),
    ("isa", [PY, "scripts/run_isa.py", "--matrix"]),
    ("spike", [PY, "scripts/compare_spike.py", "--all"]),
    ("systest", [PY, "scripts/run_systest.py"]),
]


def main():
    rows = []
    for name, cmd in STEPS:
        t0 = time.time()
        print(f"[regress] === {name}: {' '.join(cmd)}", flush=True)
        res = subprocess.run(cmd, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                             text=True, errors="replace")
        tail = [l for l in res.stdout.splitlines() if l.strip()][-12:]
        print("\n".join(tail), flush=True)
        rows.append((name, "PASS" if res.returncode == 0 else "FAIL", round(time.time() - t0)))
    print("\n[regress] Kết quả:")
    print(f"  {'Bước':10s} {'Kết quả':8s} {'Thời gian (s)':>13s}")
    for n, r, t in rows:
        print(f"  {n:10s} {r:8s} {t:13d}")
    ok = all(r == "PASS" for _, r, _ in rows)
    md = ["# Regression", "", "| Bước | Kết quả | Thời gian (s) |", "|---|---|---|"]
    md += [f"| {n} | {r} | {t} |" for n, r, t in rows]
    md += ["", f"Tổng: {'PASS' if ok else 'FAIL'}. Tái tạo: `make regress`.", ""]
    (ROOT / "results/regress.md").write_text("\n".join(md))
    print(f"[regress] {'PASS' if ok else 'FAIL'}")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()

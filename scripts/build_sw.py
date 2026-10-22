#!/usr/bin/env python3
"""Build firmware: system tests (sw/tests) and benchmarks (sw/benchmarks).

Each program is a directory with *.c / *.S files and an optional `flags.txt`
(extra compiler flags, one line). Output goes to
  build/sw/<kind>/<variant>_<console>/<name>.{elf,hex,dump}
where kind = tests | bench, variant = i | im | imc, console = uart | sim.

Usage:
  build_sw.py                       # all tests (imc/uart) + all benchmarks (i, im, imc / sim)
  build_sw.py --kind tests --name hello --console sim
"""
import argparse
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import BUILD, JOBS, MARCH, RISCV_PREFIX, ROOT, elf2hex, objdump, run  # noqa: E402

SW = ROOT / "sw"
COMMON_FLAGS = ["-mabi=ilp32", "-O2", "-g", "-ffreestanding", "-nostdlib", "-nostartfiles",
                "-fno-tree-loop-distribute-patterns", "-fno-builtin", "-Wall",
                "-ffunction-sections", "-fdata-sections"]
KIND_DIR = {"tests": SW / "tests", "bench": SW / "benchmarks"}


def program_dirs(kind):
    return sorted(d for d in KIND_DIR[kind].iterdir() if d.is_dir() and
                  (list(d.glob("*.c")) or list(d.glob("*.S"))))


def build_program(kind, pdir, variant, console):
    pdir = Path(pdir)
    out = BUILD / "sw" / kind / f"{variant}_{console}"
    out.mkdir(parents=True, exist_ok=True)
    elf = out / f"{pdir.name}.elf"
    srcs = sorted(pdir.glob("*.c")) + sorted(pdir.glob("*.S"))
    srcs += sorted((SW / "common").glob("*.c")) + sorted((SW / "common").glob("*.S"))
    srcs += sorted((SW / "drivers").glob("*.c"))
    extra = []
    fl = pdir / "flags.txt"
    if fl.exists():
        extra = fl.read_text().split()
    deps = srcs + list((SW / "common").glob("*.h")) + list((SW / "drivers").glob("*.h")) + \
        list(pdir.glob("*.h")) + [SW / "common/link.ld"] + ([fl] if fl.exists() else [])
    newest = max(p.stat().st_mtime for p in deps)
    hexf = elf.with_suffix(".hex")
    if hexf.exists() and hexf.stat().st_mtime > newest:
        return elf
    cmd = [RISCV_PREFIX + "gcc", f"-march={MARCH[variant]}"] + COMMON_FLAGS + extra + [
        f"-DCONSOLE_{console.upper()}", f"-I{SW / 'common'}", f"-I{SW / 'drivers'}", f"-I{pdir}",
        f"-T{SW / 'common/link.ld'}", "-Wl,--gc-sections", "-Wl,-Map," + str(out / f"{pdir.name}.map"),
        "-o", str(elf)] + [str(s) for s in srcs] + ["-lgcc"]
    run(cmd, log=out / f"{pdir.name}.build.log")
    elf2hex(elf, hexf)
    objdump(elf, out / f"{pdir.name}.dump")
    return elf


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--kind", choices=["tests", "bench"], action="append")
    ap.add_argument("--name", action="append")
    ap.add_argument("--variant", action="append", choices=list(MARCH))
    ap.add_argument("--console", action="append", choices=["uart", "sim"])
    args = ap.parse_args()

    jobs = []
    for kind in args.kind or ["tests", "bench"]:
        variants = args.variant or (["imc"] if kind == "tests" else ["i", "im", "imc"])
        consoles = args.console or (["uart"] if kind == "tests" else ["sim"])
        for pdir in program_dirs(kind):
            if args.name and pdir.name not in args.name:
                continue
            for v in variants:
                for c in consoles:
                    jobs.append((kind, pdir, v, c))
    with ThreadPoolExecutor(max_workers=JOBS) as ex:
        for elf in ex.map(lambda j: build_program(*j), jobs):
            print(f"[sw] {elf.relative_to(ROOT)}")


if __name__ == "__main__":
    main()

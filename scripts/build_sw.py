#!/usr/bin/env python3
"""Build firmware: system tests (sw/tests) and benchmarks (sw/benchmarks).

Each program is a directory with *.c / *.S files and an optional `flags.txt`
(extra compiler flags, one line). Output goes to
  build/sw/<kind>/<variant>_<console>/<name>.{elf,hex,dump}
where kind = tests | bench | fpga, variant = i | im | imc, console = uart | sim | de2.
console = de2 is the DE2 FPGA board build: UART console at 115200 baud with a
24 MHz CPU clock (BAUD_DIV 12), CPU_HZ defined, linked for 32 KB of RAM.

Usage:
  build_sw.py                       # all tests (imc/uart) + all benchmarks (i, im, imc / sim)
  build_sw.py --kind tests --name hello --console sim
"""
import argparse
import sys
import threading
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import BUILD, JOBS, MARCH, RISCV_PREFIX, ROOT, elf2hex, objdump, run  # noqa: E402

SW = ROOT / "sw"
COMMON_FLAGS = ["-mabi=ilp32", "-O2", "-g", "-ffreestanding", "-nostdlib", "-nostartfiles",
                "-fno-tree-loop-distribute-patterns", "-fno-builtin", "-Wall",
                "-ffunction-sections", "-fdata-sections"]
KIND_DIR = {"tests": SW / "tests", "bench": SW / "benchmarks", "examples": SW / "examples",
            "fpga": SW / "fpga"}
# DE2 board build (see fpga/README.md): 24 MHz CPU clock, 32 KB RAM
DE2_CPU_HZ = 24_000_000
DE2_BAUD_DIV = 12          # 24 MHz / (16 x 13) = 115384 baud (+0.16 %)
DE2_RAM_KB = 32


def link_script(console):
    """Linker script for a console: the board build gets a 32 KB RAM copy."""
    ld = SW / "common/link.ld"
    if console != "de2":
        return ld
    out = BUILD / "sw" / "link_de2.ld"
    text = ld.read_text().replace("LENGTH = 128K", f"LENGTH = {DE2_RAM_KB}K")
    out.parent.mkdir(parents=True, exist_ok=True)
    if not out.exists() or out.read_text() != text:
        out.write_text(text)
    return out


def console_defs(console):
    if console != "de2":
        return [f"-DCONSOLE_{console.upper()}"]
    return ["-DCONSOLE_UART", "-DBOARD_DE2", f"-DCPU_HZ={DE2_CPU_HZ}u",
            "-UCONSOLE_BAUD_DIV", f"-DCONSOLE_BAUD_DIV={DE2_BAUD_DIV}"]


def program_dirs(kind):
    return sorted(d for d in KIND_DIR[kind].iterdir() if d.is_dir() and
                  not d.name.startswith("_") and
                  (list(d.glob("*.c")) or list(d.glob("*.S")) or (d / "sources.txt").exists()))


def _expand(text):
    return text.replace("${TP}", str(ROOT / "third_party")).replace("${SW}", str(SW))


_locks = {}
_locks_guard = threading.Lock()


def build_program(kind, pdir, variant, console):
    """Thread-safe wrapper: one build per (kind, program, variant, console)."""
    key = (kind, Path(pdir).name, variant, console)
    with _locks_guard:
        lock = _locks.setdefault(key, threading.Lock())
    with lock:
        return _build_program(kind, pdir, variant, console)


def _build_program(kind, pdir, variant, console):
    pdir = Path(pdir)
    out = BUILD / "sw" / kind / f"{variant}_{console}"
    out.mkdir(parents=True, exist_ok=True)
    elf = out / f"{pdir.name}.elf"
    srcs = sorted(pdir.glob("*.c")) + sorted(pdir.glob("*.S"))
    incs = []
    if (pdir / "sources.txt").exists():  # sources taken from third_party
        for l in _expand((pdir / "sources.txt").read_text()).split():
            srcs.append(Path(l))
            incs.append(f"-I{Path(l).parent}")
    if kind == "bench":
        srcs += sorted((SW / "benchmarks/_common").glob("*.c"))
        incs = [f"-I{SW / 'benchmarks/_common'}"] + incs
    srcs += sorted((SW / "common").glob("*.c")) + sorted((SW / "common").glob("*.S"))
    srcs += sorted((SW / "drivers").glob("*.c"))
    extra = []
    fl = pdir / "flags.txt"
    if fl.exists():
        extra = _expand(fl.read_text()).split()
    deps = srcs + list((SW / "common").glob("*.h")) + list((SW / "drivers").glob("*.h")) + \
        list(pdir.glob("*.h")) + [SW / "common/link.ld"] + ([fl] if fl.exists() else []) + \
        list((SW / "benchmarks/_common").glob("*")) + [Path(__file__)]
    newest = max(p.stat().st_mtime for p in deps)
    hexf = elf.with_suffix(".hex")
    if hexf.exists() and hexf.stat().st_mtime > newest:
        return elf
    ld = link_script(console)
    cmd = [RISCV_PREFIX + "gcc", f"-march={MARCH[variant]}"] + COMMON_FLAGS + extra + \
        console_defs(console) + [f"-DBENCH_NAME=\"{pdir.name}\""] + incs + [
        f"-I{SW / 'common'}", f"-I{SW / 'drivers'}", f"-I{pdir}",
        f"-T{ld}", "-Wl,--gc-sections", "-Wl,-Map," + str(out / f"{pdir.name}.map"),
        "-o", str(elf)] + [str(s) for s in srcs] + ["-lgcc"]
    run(cmd, log=out / f"{pdir.name}.build.log")
    elf2hex(elf, hexf)
    objdump(elf, out / f"{pdir.name}.dump")
    return elf


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--kind", choices=["tests", "bench", "fpga"], action="append")
    ap.add_argument("--name", action="append")
    ap.add_argument("--variant", action="append", choices=list(MARCH))
    ap.add_argument("--console", action="append", choices=["uart", "sim", "de2"])
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

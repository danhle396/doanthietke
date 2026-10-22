"""Shared helpers for the build/run scripts (toolchain discovery, Verilator
builds, software builds, simulation runs)."""
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / "build"
RESULTS = ROOT / "results"
TP = ROOT / "third_party"

HOME = Path.home()
_extra = [HOME / "tools/oss-cad-suite/bin", HOME / "tools/spike/bin", HOME / "tools/dtc/bin"]
_extra += sorted((HOME / "tools").glob("xpack-riscv-none-elf-gcc*/bin"))
os.environ["PATH"] = os.pathsep.join([str(p) for p in _extra if p.is_dir()] +
                                     [os.environ.get("PATH", "")])
os.environ["LD_LIBRARY_PATH"] = os.pathsep.join(
    [str(HOME / "tools/dtc/lib"), os.environ.get("LD_LIBRARY_PATH", "")])

JOBS = int(os.environ.get("JOBS", os.cpu_count() or 4))


def find_riscv_prefix():
    env = os.environ.get("RISCV_PREFIX")
    if env:
        return env
    for p in ("riscv64-unknown-elf-", "riscv32-unknown-elf-", "riscv-none-elf-"):
        if shutil.which(p + "gcc"):
            return p
    sys.exit("No RISC-V GCC found (set RISCV_PREFIX)")


RISCV_PREFIX = find_riscv_prefix()
VERILATOR = os.environ.get("VERILATOR", "verilator")
SPIKE = os.environ.get("SPIKE", "spike")
YOSYS = os.environ.get("YOSYS", "yosys")

MARCH = {
    "i": "rv32i_zicsr_zifencei",
    "im": "rv32im_zicsr_zifencei",
    "imc": "rv32imc_zicsr_zifencei",
}


def run(cmd, cwd=None, log=None, check=True, timeout=None, env=None):
    """Run a command (list), optionally tee output into a log file."""
    res = subprocess.run(cmd, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                         text=True, timeout=timeout, env=env, errors="replace")
    if log:
        Path(log).parent.mkdir(parents=True, exist_ok=True)
        Path(log).write_text(res.stdout)
    if check and res.returncode != 0:
        sys.stderr.write(res.stdout[-4000:])
        raise RuntimeError(f"command failed ({res.returncode}): {' '.join(map(str, cmd))}")
    return res


def rtl_files():
    return [str(ROOT / l.strip()) for l in (ROOT / "rtl/rtl_files.f").read_text().splitlines()
            if l.strip() and not l.startswith("#")]


# --------------------------------------------------------------------------
# RTL configurations
# --------------------------------------------------------------------------
DEFAULT_CFG = dict(ENABLE_M=1, ENABLE_C=1, BP_MODE=2, BHT_ENTRIES=256, BTB_ENTRIES=32, CORE_SC=0)


def make_cfg(**kw):
    c = dict(DEFAULT_CFG)
    c.update(kw)
    if c["CORE_SC"]:
        c.update(ENABLE_M=0, ENABLE_C=0, BP_MODE=0)
    return c


def cfg_name(cfg):
    if cfg["CORE_SC"]:
        return "sc"
    return (f"m{cfg['ENABLE_M']}c{cfg['ENABLE_C']}_bp{cfg['BP_MODE']}"
            f"_bht{cfg['BHT_ENTRIES']}_btb{cfg['BTB_ENTRIES']}")


def cfg_variant(cfg):
    """Software variant that matches an RTL configuration."""
    if cfg["CORE_SC"] or not cfg["ENABLE_M"]:
        return "i"
    return "imc" if cfg["ENABLE_C"] else "im"


TB_SOC_SOURCES = ["tb/soc/tb_soc.sv"]
TB_INCDIRS = ["tb/soc", "tb/bfm"]


def _newest_mtime(paths):
    m = 0.0
    for p in paths:
        p = Path(p)
        if p.is_dir():
            for f in p.rglob("*"):
                if f.is_file():
                    m = max(m, f.stat().st_mtime)
        elif p.exists():
            m = max(m, p.stat().st_mtime)
    return m


def build_soc(cfg, coverage=False, trace=True, quiet=True):
    """Build tb_soc for one configuration; return the executable path.
    Rebuilds only if an RTL/TB source is newer than the executable."""
    name = cfg_name(cfg) + ("_cov" if coverage else "")
    out = BUILD / "verilator" / name
    exe = out / "Vtb_soc"
    deps = [ROOT / "rtl", ROOT / "tb/soc", ROOT / "tb/bfm", ROOT / "tb/cov", Path(__file__)]
    if exe.exists() and exe.stat().st_mtime > _newest_mtime(deps):
        return exe
    obj = out / "obj"
    if obj.exists():
        shutil.rmtree(obj)
    obj.mkdir(parents=True, exist_ok=True)
    cmd = [VERILATOR, "--binary", "--timing", "-j", str(JOBS), "--top-module", "tb_soc",
           "-Mdir", str(obj), "-o", "Vtb_soc", "-O3", "--x-assign", "fast",
           "--x-initial", "fast", "-Wno-fatal", "-Wno-lint", "-Wno-style",
           "-CFLAGS", "-O2", "--output-split", "20000"]
    for d in TB_INCDIRS:
        cmd.append(f"-I{ROOT / d}")
    for k, v in cfg.items():
        cmd.append(f"-G{k}={v}")
    if trace:
        cmd.append("--trace-fst")
    if coverage:
        cmd += ["--coverage-line", "--coverage-toggle", "--coverage-user"]
        cov_files = sorted((ROOT / "tb/cov").glob("*.sv"))
    else:
        cov_files = []
    cmd += rtl_files() + [str(ROOT / s) for s in TB_SOC_SOURCES] + [str(f) for f in cov_files]
    run(cmd, log=out / "build.log")
    shutil.move(str(obj / "Vtb_soc"), str(exe))
    shutil.rmtree(obj)  # keep only the executable (disk space)
    return exe


def run_sim(exe, hexfile, plusargs=(), log=None, timeout=1800, cwd=None):
    """Run a tb_soc executable. Returns (passed, output)."""
    cmd = [str(exe), f"+hex={hexfile}"] + list(plusargs)
    try:
        res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                             timeout=timeout, cwd=cwd, errors="replace")
        out, rc = res.stdout, res.returncode
    except subprocess.TimeoutExpired as e:
        out, rc = (e.stdout or "") + "\nFAIL: wall-clock timeout\n", -1
        if isinstance(out, bytes):
            out = out.decode(errors="replace")
    if log:
        Path(log).parent.mkdir(parents=True, exist_ok=True)
        Path(log).write_text(out)
    passed = rc == 0 and re.search(r"^PASS\s*$", out, re.M) is not None
    return passed, out


PERF_RE = re.compile(r"\[perf\] (.*)")


def parse_perf(text):
    d = {}
    for m in PERF_RE.finditer(text):
        for kv in m.group(1).split():
            k, v = kv.split("=")
            d[k] = int(v)
    return d


# --------------------------------------------------------------------------
# Software helpers
# --------------------------------------------------------------------------
def elf2hex(elf, hexfile):
    run([sys.executable, str(ROOT / "scripts/elf2hex.py"), str(elf), str(hexfile)])


def symbol_addr(elf, name):
    res = run([RISCV_PREFIX + "nm", str(elf)])
    for line in res.stdout.splitlines():
        parts = line.split()
        if len(parts) == 3 and parts[2] == name:
            return parts[0]
    return None


def objdump(elf, dump):
    res = run([RISCV_PREFIX + "objdump", "-d", "-M", "no-aliases", str(elf)], check=False)
    Path(dump).write_text(res.stdout)


def parse_makefrag(path, var):
    """Return the list assigned to `var` in a riscv-tests Makefrag."""
    text = Path(path).read_text().replace("\\\n", " ")
    m = re.search(rf"^{var}\s*=(.*)$", text, re.M)
    return m.group(1).split() if m else []


ISA_SUITES = {
    "i": ["rv32ui", "rv32mi"],
    "im": ["rv32ui", "rv32um", "rv32mi"],
    "imc": ["rv32ui", "rv32um", "rv32uc", "rv32mi"],
}


def isa_tests(suite):
    frag = TP / "riscv-tests/isa" / suite / "Makefrag"
    return parse_makefrag(frag, f"{suite}_sc_tests")


def build_isa_test(suite, test, variant):
    """Compile one riscv-tests program. Returns (elf, hex, tohost_hex)."""
    out = BUILD / "sw/isa" / variant
    out.mkdir(parents=True, exist_ok=True)
    stem = f"{suite}-p-{test}"
    elf, hexf = out / f"{stem}.elf", out / f"{stem}.hex"
    src = TP / "riscv-tests/isa" / suite / f"{test}.S"
    env = ROOT / "sw/riscv-tests-env/p"
    deps = [src, env, TP / "riscv-tests/isa/macros"]
    if not (hexf.exists() and hexf.stat().st_mtime > _newest_mtime(deps)):
        run([RISCV_PREFIX + "gcc", f"-march={MARCH[variant]}", "-mabi=ilp32", "-static",
             "-mcmodel=medany", "-fvisibility=hidden", "-nostdlib", "-nostartfiles",
             f"-I{env}", f"-I{TP / 'riscv-tests/env'}",
             f"-I{TP / 'riscv-tests/isa/macros/scalar'}",
             f"-T{env / 'link.ld'}", str(src), "-o", str(elf)])
        elf2hex(elf, hexf)
        objdump(elf, out / f"{stem}.dump")
    return elf, hexf, symbol_addr(elf, "tohost")

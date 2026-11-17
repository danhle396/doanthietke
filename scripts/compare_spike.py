#!/usr/bin/env python3
"""Lock-step comparison of the RTL commit log with `spike --log-commits`.

Each retired instruction is parsed with a regex into
(pc, insn, rd write, store address/data) - not compared as raw text.
Values read from cycle/mcycle/instret/minstret/time/mhpmcounter* are masked
(timing dependent). Reads of misa/marchid/mimpid are reported as KNOWN
implementation differences (never hidden). Spike bootrom instructions
(pc < 0x8000_0000) are skipped. Comparison stops at the first store to
`tohost` (end of test); the extra idle-loop lines either side are ignored.

Usage:
  compare_spike.py --all                      # every riscv-test + benchmarks (CONSOLE=sim)
  compare_spike.py --config m1c1_bp2 --tests add,lw
  compare_spike.py --elf x.elf --config m1c1_bp2   # ad-hoc program
"""
import argparse
import re
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import (BUILD, JOBS, MARCH, RESULTS, SPIKE, build_isa_test, build_soc,  # noqa: E402
                    cfg_variant, elf2hex, isa_tests, run_sim, symbol_addr)
from run_isa import CONFIGS, EXCLUDED, suites_for  # noqa: E402
from md_table import write_md  # noqa: E402

LINE_RE = re.compile(r"^core\s+0: \d 0x([0-9a-f]+) \(0x([0-9a-f]+)\)(.*)$")
REG_RE = re.compile(r"\bx(\d+)\s+0x([0-9a-f]+)")
MEM_RE = re.compile(r"\bmem 0x([0-9a-f]+)(?: 0x([0-9a-f]+))?")

# CSRs whose read value depends on timing -> rd value masked
MASKED_CSRS = {0xC00, 0xC01, 0xC02, 0xC80, 0xC81, 0xC82, 0xB00, 0xB02, 0xB80, 0xB82}
MASKED_CSRS |= set(range(0xB03, 0xB20)) | set(range(0xB83, 0xBA0))
MASKED_CSRS |= set(range(0xC03, 0xC20)) | set(range(0xC83, 0xCA0))
# CSRs whose value is implementation defined -> KNOWN difference
KNOWN_CSRS = {0x301: "misa", 0xF12: "marchid", 0xF13: "mimpid"}


def parse_log(path, skip_low=True):
    """List of (pc, insn, rd, store, load_addr) records."""
    recs = []
    with open(path, errors="replace") as f:
        for line in f:
            m = LINE_RE.match(line)
            if not m:
                continue
            pc = int(m.group(1), 16)
            if skip_low and pc < 0x80000000:
                continue
            rest = m.group(3)
            rd = None
            for r in REG_RE.finditer(rest):
                if int(r.group(1)) != 0:
                    rd = (int(r.group(1)), int(r.group(2), 16))
            store = load = None
            for mm in MEM_RE.finditer(rest):
                if mm.group(2) is not None:
                    store = (int(mm.group(1), 16), int(mm.group(2), 16))
                else:
                    load = int(mm.group(1), 16)
            recs.append((pc, int(m.group(2), 16), rd, store, load))
    return recs


def csr_of(insn):
    """CSR address if insn is a 32-bit Zicsr instruction, else None."""
    if (insn & 0x7F) == 0x73 and ((insn >> 12) & 7) not in (0, 4) and (insn & 3) == 3:
        return (insn >> 20) & 0xFFF
    return None


def src_regs(insn):
    """Source registers read by an RV32IMC instruction (for taint tracking)."""
    if insn & 3 != 3:  # compressed
        q, f3 = insn & 3, (insn >> 13) & 7
        rd = (insn >> 7) & 31
        r1p, r2p = 8 + ((insn >> 7) & 7), 8 + ((insn >> 2) & 7)
        rs2 = (insn >> 2) & 31
        if q == 0:
            return {0: [2], 2: [r1p], 6: [r1p, r2p]}.get(f3, [])
        if q == 1:
            if f3 == 0:
                return [rd]
            if f3 == 3:
                return [2] if rd == 2 else []
            if f3 == 4:
                return [r1p, r2p] if (insn >> 10) & 3 == 3 else [r1p]
            if f3 in (6, 7):
                return [r1p]
            return []
        if f3 == 0:
            return [rd]
        if f3 == 2:
            return [2]
        if f3 == 6:
            return [2, rs2]
        if f3 == 4:
            if rs2 == 0:
                return [rd]
            return [rs2] if not (insn >> 12) & 1 else [rd, rs2]
        return []
    opc = insn & 0x7F
    rs1, rs2 = (insn >> 15) & 31, (insn >> 20) & 31
    if opc in (0x63, 0x23, 0x33):
        return [rs1, rs2]
    if opc in (0x67, 0x03, 0x13):
        return [rs1]
    if opc == 0x73 and ((insn >> 12) & 7) in (1, 2, 3):
        return [rs1]
    return []


def truncate_at_tohost(recs, tohost):
    for i, r in enumerate(recs):
        if r[3] is not None and r[3][0] == tohost:
            return recs[:i + 1], True
    return recs, False


def compare(rtl, spk, tohost):
    """Lock-step comparison with taint tracking of timing-dependent values.

    Values read from cycle/instret/time/mhpmcounter CSRs differ legitimately.
    They are tracked ("tainted") through registers and memory; differences in
    tainted data are counted as masked. If the control flow diverges right
    after a branch/jump on tainted data (e.g. printing a cycle count), the
    lock-step ends there and only the final tohost value (exit code) is
    compared; the report states how many instructions were compared."""
    rtl, rtl_end = truncate_at_tohost(rtl, tohost)
    spk, spk_end = truncate_at_tohost(spk, tohost)
    known, masked = [], 0
    treg, tmem = set(), set()
    n = min(len(rtl), len(spk))
    prev_tainted_cti = False
    for i in range(n):
        a, b = rtl[i], spk[i]
        if a[0] != b[0] or a[1] != b[1]:
            if prev_tainted_cti:
                if rtl_end and spk_end and rtl[-1][3] == spk[-1][3]:
                    return True, (f"{i} lệnh khớp lock-step; luồng lệnh rẽ khác sau nhánh phụ thuộc "
                                  f"giá trị counter tại pc 0x{rtl[i-1][0]:08x}; mã thoát tohost khớp "
                                  f"(RTL còn {len(rtl)-i}, Spike còn {len(spk)-i} lệnh không so)"), known, masked + 1
                return False, f"#{i}: control diverged after counter-dependent branch and exit codes differ", known, masked
            if known:
                return None, (f"#{i}: diverges after known difference ({known[-1]})"), known, masked
            return False, f"#{i}: pc/insn RTL 0x{a[0]:08x}(0x{a[1]:x}) vs Spike 0x{b[0]:08x}(0x{b[1]:x})", known, masked
        insn = a[1]
        srcs = src_regs(insn)
        tainted = any(r in treg for r in srcs if r != 0)
        if a[4] is not None and (a[4] & ~3) in tmem:
            tainted = True
        csr = csr_of(insn)
        if csr in MASKED_CSRS:
            tainted = True
        opc = insn & 0x7F if insn & 3 == 3 else None
        is_cti = (opc in (0x63, 0x67)) or (insn & 3 == 1 and ((insn >> 13) & 7) in (6, 7)) or \
                 (insn & 3 == 2 and ((insn >> 13) & 7) == 4 and ((insn >> 2) & 31) == 0)
        prev_tainted_cti = tainted and is_cti
        # stores
        if a[3] != b[3]:
            if a[3] and b[3] and a[3][0] == b[3][0] and tainted:
                masked += 1
            else:
                return False, f"#{i} pc 0x{a[0]:08x}: store RTL {a[3]} vs Spike {b[3]}", known, masked
        if a[3]:
            if tainted:
                tmem.add(a[3][0] & ~3)
            else:
                tmem.discard(a[3][0] & ~3)
        # register results
        if a[2] != b[2]:
            if a[2] and b[2] and a[2][0] == b[2][0] and tainted:
                masked += 1
            elif csr in KNOWN_CSRS and a[2] and b[2] and a[2][0] == b[2][0]:
                known.append(f"pc 0x{a[0]:08x} read {KNOWN_CSRS[csr]}: RTL 0x{a[2][1]:08x} "
                             f"Spike 0x{b[2][1]:08x}")
            elif known:
                return None, (f"#{i} pc 0x{a[0]:08x}: diverges after known difference "
                              f"({known[-1]})"), known, masked
            else:
                return False, f"#{i} pc 0x{a[0]:08x} (0x{a[1]:x}): rd RTL {a[2]} vs Spike {b[2]}", known, masked
        if a[2]:
            if tainted:
                treg.add(a[2][0])
            else:
                treg.discard(a[2][0])
    if len(rtl) != len(spk):
        return False, f"length differs: RTL {len(rtl)} vs Spike {len(spk)} (tohost seen RTL={rtl_end} Spike={spk_end})", known, masked
    if not rtl_end:
        return False, "tohost store not reached", known, masked
    return True, f"{n} lệnh khớp", known, masked


def spike_run(elf, variant, log, max_insns=50_000_000):
    # The core implements Zicntr (cycle/time/instret); Spike needs it named.
    cmd = [SPIKE, f"--isa={MARCH[variant]}_zicntr", "--priv=m",
           "-m0x80000000:0x20000,0x1000F000:0x1000", "--log-commits",
           f"--instructions={max_insns}", str(elf)]
    with open(log, "w") as f:
        subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=f, timeout=1800)


def compare_program(cname, name, elf, hexf, tohost):
    cfg = CONFIGS[cname]
    variant = cfg_variant(cfg)
    exe = build_soc(cfg)
    d = BUILD / "logs/spike" / cname
    d.mkdir(parents=True, exist_ok=True)
    rtl_log, spk_log = d / f"{name}.rtl.log", d / f"{name}.spike.log"
    ok, _ = run_sim(exe, hexf, [f"+tohost={tohost}", f"+commitlog={rtl_log}"],
                    log=d / f"{name}.sim.log")
    spike_run(elf, variant, spk_log)
    if not ok:
        return dict(test=name, result="RTL_FAIL", detail="RTL simulation failed", known=[], masked=0)
    same, detail, known, masked = compare(parse_log(rtl_log, False), parse_log(spk_log),
                                          int(tohost, 16))
    # keep disk usage small: drop logs of matching runs
    if same is not False:
        rtl_log.unlink()
        spk_log.unlink()
    result = {True: "MATCH", False: "DIFF", None: "KNOWN"}[same]
    return dict(test=name, result=result, detail=detail, known=known, masked=masked)


def isa_jobs(cname, tf=None):
    variant = cfg_variant(CONFIGS[cname])
    for suite in suites_for(cname):
        for t in isa_tests(suite):
            name = f"{suite}-p-{t}"
            if (tf and t not in tf) or name in EXCLUDED:
                continue
            elf, hexf, tohost = build_isa_test(suite, t, variant)
            yield name, elf, hexf, tohost


def bench_jobs(cname):
    """Benchmarks built with CONSOLE=sim for this configuration (if present)."""
    variant = cfg_variant(CONFIGS[cname])
    bdir = BUILD / "sw/bench" / f"{variant}_sim"
    for elf in sorted(bdir.glob("*.elf")):
        hexf = elf.with_suffix(".hex")
        tohost = symbol_addr(elf, "tohost")
        if hexf.exists() and tohost:
            yield "bench-" + elf.stem, elf, hexf, tohost


def write_report(cname, rows):
    out = RESULTS / "spike"
    out.mkdir(parents=True, exist_ok=True)
    nm = sum(r["result"] in ("MATCH", "KNOWN") for r in rows)
    lines = [f"# So sánh commit log RTL với Spike – cấu hình `{cname}`", "",
             f"Mức so sánh: `--log-commits` (pc, mã lệnh, thanh ghi đích + giá trị, "
             f"địa chỉ + dữ liệu store), so khớp từng lệnh bằng regex.", "",
             f"MATCH (kể cả KNOWN) {nm} / {len(rows)}", "",
             "KNOWN = khớp tới lệnh đọc một CSR có giá trị tùy hiện thực (misa/marchid/mimpid), "
             "sau đó luồng chương trình rẽ khác một cách hợp lệ.", "",
             "| Chương trình | Kết quả | Chi tiết | Giá trị bị che (counter) | Khác biệt đã biết |",
             "|---|---|---|---|---|"]
    for r in rows:
        kn = "; ".join(sorted(set(r["known"]))) if r["known"] else ""
        lines.append(f"| {r['test']} | {r['result']} | {r['detail']} | {r['masked']} | {kn} |")
    lines += ["", f"Tái tạo: `.venv/bin/python scripts/compare_spike.py --config {cname}`", ""]
    write_md(out / f"{cname}.md", "\n".join(lines))
    return nm


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--config", action="append", choices=list(CONFIGS))
    ap.add_argument("--tests")
    ap.add_argument("--elf")
    ap.add_argument("--no-bench", action="store_true")
    args = ap.parse_args()

    if args.elf:
        cname = (args.config or ["m1c1_bp2"])[0]
        elf = Path(args.elf)
        hexf = BUILD / "tmp" / (elf.stem + ".hex")
        hexf.parent.mkdir(parents=True, exist_ok=True)
        elf2hex(elf, hexf)
        r = compare_program(cname, elf.stem, elf, hexf, symbol_addr(elf, "tohost"))
        print(r)
        sys.exit(0 if r["result"] == "MATCH" else 1)

    cnames = args.config or ["m1c1_bp2", "m1c0_bp2", "m0c0_bp2", "sc"]
    tf = set(args.tests.split(",")) if args.tests else None
    bad = 0
    summary = []
    for cname in cnames:
        jobs = list(isa_jobs(cname, tf))
        if not args.no_bench and not tf:
            jobs += list(bench_jobs(cname))
        build_soc(CONFIGS[cname])
        with ThreadPoolExecutor(max_workers=JOBS) as ex:
            rows = list(ex.map(lambda j: compare_program(cname, *j), jobs))
        nm = write_report(cname, rows)
        summary.append((cname, nm, len(rows)))
        bad += len(rows) - nm
        print(f"[spike] {cname:10s} MATCH {nm}/{len(rows)}")
        for r in rows:
            if r["result"] not in ("MATCH", "KNOWN"):
                print(f"        {r['result']}: {r['test']}: {r['detail']}")
            elif r["known"]:
                print(f"        KNOWN: {r['test']}: {r['known'][0]} | {r['detail']}")
    if not tf:
        lines = ["# So sánh với Spike – tổng hợp", "",
                 "| Cấu hình | MATCH | Tổng |", "|---|---|---|"]
        lines += [f"| `{c}` | {m} | {t} |" for c, m, t in summary]
        lines += ["", "Tái tạo: `make spike`", ""]
        write_md(RESULTS / "spike/summary.md", "\n".join(lines))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()

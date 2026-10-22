#!/usr/bin/env python3
"""Generate test vectors for tb_compressed_decoder.

Every RV32C instruction (directed boundary operands + seeded random operands)
is assembled twice with GNU as: the compressed form with `.option rvc` and the
architecturally equivalent 32-bit form with `.option norvc`. The encodings
are read back from `objdump -d` and paired, so the expected expansion comes
from the assembler, not from a hand-written model.

Outputs (build/gen/):
  rvc_vectors.hex  : one line per vector, 48 bits = {cinsn[15:0], insn[31:0]}
  rvc_illegal.hex  : 16-bit encodings that must be flagged illegal
  rvc_vectors.svh  : N_VEC / N_ILL localparams
"""
import argparse
import random
import re
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import BUILD, RISCV_PREFIX  # noqa: E402

REGS = [f"x{i}" for i in range(32)]
PRIME = [f"x{i}" for i in range(8, 16)]


def gen_pairs(rng, n_rand):
    """List of (compressed asm, expanded 32-bit asm)."""
    P = []

    def rnd(lo, hi, step=1, nz=False):
        while True:
            v = rng.randrange(lo, hi + 1, step)
            if not (nz and v == 0):
                return v

    def add(c, e):
        P.append((c, e))

    for _ in range(n_rand):
        rd = rng.choice(PRIME); imm = rnd(4, 1020, 4)
        add(f"c.addi4spn {rd}, x2, {imm}", f"addi {rd}, x2, {imm}")
    for rd, imm in [("x8", 4), ("x15", 1020)]:
        add(f"c.addi4spn {rd}, x2, {imm}", f"addi {rd}, x2, {imm}")
    for rd, rs1, imm in [("x8", "x9", 0), ("x15", "x8", 124)] + \
            [(rng.choice(PRIME), rng.choice(PRIME), rnd(0, 124, 4)) for _ in range(n_rand)]:
        add(f"c.lw {rd}, {imm}({rs1})", f"lw {rd}, {imm}({rs1})")
        add(f"c.sw {rd}, {imm}({rs1})", f"sw {rd}, {imm}({rs1})")
    # Quadrant 1
    add("c.nop", "addi x0, x0, 0")
    for rd, imm in [("x1", 1), ("x31", -32), ("x5", 31)] + \
            [(rng.choice(REGS[1:]), rnd(-32, 31, nz=True)) for _ in range(n_rand)]:
        add(f"c.addi {rd}, {imm}", f"addi {rd}, {rd}, {imm}")
    for off in [2, -2048, 2046] + [rnd(-2048, 2046, 2, nz=True) for _ in range(n_rand)]:
        add(f"c.jal .{off:+d}", f"jal x1, .{off:+d}")
        add(f"c.j .{off:+d}", f"jal x0, .{off:+d}")
    for rd, imm in [("x1", 0), ("x31", -32), ("x7", 31)] + \
            [(rng.choice(REGS[1:]), rnd(-32, 31)) for _ in range(n_rand)]:
        add(f"c.li {rd}, {imm}", f"addi {rd}, x0, {imm}")
    for imm in [16, -512, 496] + [rnd(-512, 496, 16, nz=True) for _ in range(n_rand)]:
        add(f"c.addi16sp x2, {imm}", f"addi x2, x2, {imm}")
    lui_vals = list(range(1, 32)) + list(range(0xFFFE0, 0x100000))
    for rd, imm in [("x1", 1), ("x31", 0xFFFE0), ("x3", 31)] + \
            [(rng.choice([r for r in REGS[1:] if r != "x2"]), rng.choice(lui_vals))
             for _ in range(n_rand)]:
        add(f"c.lui {rd}, {imm}", f"lui {rd}, {imm}")
    for rd, sh in [("x8", 1), ("x15", 31)] + [(rng.choice(PRIME), rnd(1, 31)) for _ in range(n_rand)]:
        add(f"c.srli {rd}, {sh}", f"srli {rd}, {rd}, {sh}")
        add(f"c.srai {rd}, {sh}", f"srai {rd}, {rd}, {sh}")
    for rd, imm in [("x8", 0), ("x15", -32), ("x9", 31)] + \
            [(rng.choice(PRIME), rnd(-32, 31)) for _ in range(n_rand)]:
        add(f"c.andi {rd}, {imm}", f"andi {rd}, {rd}, {imm}")
    for rd, rs2 in [("x8", "x15"), ("x15", "x8")] + \
            [(rng.choice(PRIME), rng.choice(PRIME)) for _ in range(n_rand)]:
        add(f"c.sub {rd}, {rs2}", f"sub {rd}, {rd}, {rs2}")
        add(f"c.xor {rd}, {rs2}", f"xor {rd}, {rd}, {rs2}")
        add(f"c.or {rd}, {rs2}", f"or {rd}, {rd}, {rs2}")
        add(f"c.and {rd}, {rs2}", f"and {rd}, {rd}, {rs2}")
    for rs1, off in [("x8", 2), ("x15", -256), ("x9", 254)] + \
            [(rng.choice(PRIME), rnd(-256, 254, 2, nz=True)) for _ in range(n_rand)]:
        add(f"c.beqz {rs1}, .{off:+d}", f"beq {rs1}, x0, .{off:+d}")
        add(f"c.bnez {rs1}, .{off:+d}", f"bne {rs1}, x0, .{off:+d}")
    # Quadrant 2
    for rd, sh in [("x1", 1), ("x31", 31)] + [(rng.choice(REGS[1:]), rnd(1, 31)) for _ in range(n_rand)]:
        add(f"c.slli {rd}, {sh}", f"slli {rd}, {rd}, {sh}")
    for rd, imm in [("x1", 0), ("x31", 252)] + \
            [(rng.choice(REGS[1:]), rnd(0, 252, 4)) for _ in range(n_rand)]:
        add(f"c.lwsp {rd}, {imm}(x2)", f"lw {rd}, {imm}(x2)")
    for rs2, imm in [("x0", 0), ("x31", 252)] + \
            [(rng.choice(REGS), rnd(0, 252, 4)) for _ in range(n_rand)]:
        add(f"c.swsp {rs2}, {imm}(x2)", f"sw {rs2}, {imm}(x2)")
    for rs1 in ["x1", "x31"] + [rng.choice(REGS[1:]) for _ in range(n_rand)]:
        add(f"c.jr {rs1}", f"jalr x0, 0({rs1})")
        add(f"c.jalr {rs1}", f"jalr x1, 0({rs1})")
    for rd, rs2 in [("x1", "x31"), ("x31", "x1")] + \
            [(rng.choice(REGS[1:]), rng.choice(REGS[1:])) for _ in range(n_rand)]:
        add(f"c.mv {rd}, {rs2}", f"add {rd}, x0, {rs2}")
        add(f"c.add {rd}, {rs2}", f"add {rd}, {rd}, {rs2}")
    add("c.ebreak", "ebreak")
    return P


ILLEGAL = [
    0x0000,                                  # all-zero
    0x0004, 0x0010, 0x001C,                  # C.ADDI4SPN nzuimm = 0
    0x2000, 0x2404, 0x6000, 0x6404,          # C.FLD / C.FLW
    0x8000, 0x8404, 0x9FFC,                  # quadrant 0 reserved (funct3 = 100)
    0xA000, 0xA404, 0xE000, 0xE404,          # C.FSD / C.FSW
    0x6101,                                  # C.ADDI16SP imm = 0
    0x6501, 0x6081, 0x6F81,                  # C.LUI imm = 0
    0x4002,                                  # C.LWSP rd = 0
    0x5002, 0x407E,                          # C.LWSP rd = 0 (other imm)
    0x8002,                                  # C.JR rs1 = 0
    0x1506, 0x1086, 0x1FFE,                  # C.SLLI shamt[5] = 1
    0x9005, 0x9381,                          # C.SRLI shamt[5] = 1
    0x9405, 0x9781,                          # C.SRAI shamt[5] = 1
    0x9C01, 0x9C21, 0x9C41, 0x9C61, 0x9FFD,  # C.SUBW/C.ADDW/reserved (RV64 only)
    0x2002, 0x3FFE, 0x6002, 0x7FFE,          # C.FLDSP / C.FLWSP
    0xA002, 0xBFFE, 0xE002, 0xFFFE,          # C.FSDSP / C.FSWSP
]


def assemble(lines, rvc):
    with tempfile.TemporaryDirectory() as td:
        src = Path(td) / "a.S"
        obj = Path(td) / "a.o"
        body = [".text", ".option rvc" if rvc else ".option norvc"] + lines
        src.write_text("\n".join(body) + "\n")
        march = "rv32imc_zicsr" if rvc else "rv32im_zicsr"
        subprocess.run([RISCV_PREFIX + "as", f"-march={march}", "-mabi=ilp32", "-mno-relax",
                        str(src), "-o", str(obj)], check=True)
        dump = subprocess.run([RISCV_PREFIX + "objdump", "-d", "-M", "no-aliases", str(obj)],
                              check=True, stdout=subprocess.PIPE, text=True).stdout
    words = []
    for line in dump.splitlines():
        m = re.match(r"^\s*[0-9a-f]+:\s+([0-9a-f]{4}|[0-9a-f]{8})\s", line)
        if m:
            words.append(int(m.group(1), 16))
    return words


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--nrand", type=int, default=40)
    args = ap.parse_args()
    rng = random.Random(args.seed)
    pairs = gen_pairs(rng, args.nrand)
    c = assemble([p[0] for p in pairs], True)
    e = assemble([p[1] for p in pairs], False)
    if len(c) != len(pairs) or len(e) != len(pairs):
        sys.exit(f"gen_rvc_vectors: count mismatch {len(pairs)} {len(c)} {len(e)}")
    for (ca, _), cw in zip(pairs, c):
        if cw & 3 == 3:
            sys.exit(f"gen_rvc_vectors: '{ca}' was not compressed")
    out = BUILD / "gen"
    out.mkdir(parents=True, exist_ok=True)
    (out / "rvc_vectors.hex").write_text("".join(f"{cw:04x}{ew:08x}\n" for cw, ew in zip(c, e)))
    (out / "rvc_illegal.hex").write_text("".join(f"{x:04x}\n" for x in ILLEGAL))
    (out / "rvc_vectors.svh").write_text(
        f"localparam int N_VEC = {len(c)};\nlocalparam int N_ILL = {len(ILLEGAL)};\n")
    print(f"[gen_rvc] {len(c)} vectors, {len(ILLEGAL)} illegal encodings (seed {args.seed})")


if __name__ == "__main__":
    main()

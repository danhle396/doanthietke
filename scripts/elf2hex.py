#!/usr/bin/env python3
"""ELF -> $readmemh hex (one 32-bit little-endian word per line).

Line 0 corresponds to BASE (default 0x8000_0000). Gaps are filled with 0.
Also reports the address of the 'tohost' symbol (if present).

Usage:
  elf2hex.py <in.elf> <out.hex> [--base 0x80000000] [--size 0x20000]
  elf2hex.py <in.elf> --sym tohost        # print symbol address only
"""
import argparse
import sys

from elftools.elf.elffile import ELFFile


def load_image(elf_path, base, size):
    """Return a bytearray holding all PT_LOAD segments of the ELF."""
    img = bytearray()
    with open(elf_path, "rb") as f:
        elf = ELFFile(f)
        for seg in elf.iter_segments():
            if seg["p_type"] != "PT_LOAD" or seg["p_filesz"] == 0:
                continue
            addr = seg["p_paddr"]
            data = seg.data()
            off = addr - base
            if off < 0 or off + len(data) > size:
                raise SystemExit(
                    f"elf2hex: segment 0x{addr:08x}+{len(data)} outside RAM "
                    f"[0x{base:08x}, 0x{base + size:08x})")
            if len(img) < off + len(data):
                img.extend(b"\0" * (off + len(data) - len(img)))
            img[off:off + len(data)] = data
    while len(img) % 4:
        img.append(0)
    return img


def find_symbol(elf_path, name):
    with open(elf_path, "rb") as f:
        elf = ELFFile(f)
        symtab = elf.get_section_by_name(".symtab")
        if symtab is None:
            return None
        syms = symtab.get_symbol_by_name(name)
        if not syms:
            return None
        return syms[0]["st_value"]


def write_hex(img, out_path):
    with open(out_path, "w") as f:
        for i in range(0, len(img), 4):
            word = int.from_bytes(img[i:i + 4], "little")
            f.write(f"{word:08x}\n")


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("elf")
    ap.add_argument("hex", nargs="?")
    ap.add_argument("--base", type=lambda s: int(s, 0), default=0x80000000)
    ap.add_argument("--size", type=lambda s: int(s, 0), default=0x20000)
    ap.add_argument("--sym", help="print address of this symbol and exit")
    args = ap.parse_args()

    if args.sym:
        addr = find_symbol(args.elf, args.sym)
        if addr is None:
            sys.exit(f"elf2hex: symbol '{args.sym}' not found")
        print(f"{addr:08x}")
        return
    if not args.hex:
        ap.error("output hex path required")
    write_hex(load_image(args.elf, args.base, args.size), args.hex)


if __name__ == "__main__":
    main()

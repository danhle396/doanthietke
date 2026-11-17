#!/usr/bin/env python3
"""Align markdown pipe tables so the columns line up in the source text.

Only whitespace inside table rows and the length of the dashes in the
separator row change; alignment markers (`:---`, `---:`, `:---:`) are kept,
so the rendered table is the same. Code fences are left untouched. Column
width is measured in terminal/editor cells: combining marks count 0, wide
(CJK, emoji) characters count 2, everything else (including precomposed
Vietnamese letters) counts 1.

Usage:
  md_table.py FILE...        align tables in place
  md_table.py --check FILE.. exit 1 if a file would change
Library:
  from md_table import align_tables, write_md
"""
import re
import sys
import unicodedata
from pathlib import Path

_SPLIT = re.compile(r"(?<!\\)\|")
_SEP_CELL = re.compile(r"^\s*:?-+:?\s*$")
_FENCE = re.compile(r"^\s*(```|~~~)")
_NUM = re.compile(r"^(\*\*)?[-+−]?[\d.,  ]*\d[\d.,  ]*\s*(%|x|×)?(\*\*)?$")


def width(s):
    w = 0
    for ch in s:
        if unicodedata.combining(ch) or ch in "​‍️":
            continue
        w += 2 if unicodedata.east_asian_width(ch) in "WF" else 1
    return w


def _cells(line):
    body = line.strip()
    if body.startswith("|"):
        body = body[1:]
    if body.endswith("|") and not body.endswith("\\|"):
        body = body[:-1]
    return [c.strip() for c in _SPLIT.split(body)]


def _is_sep(line):
    cells = _cells(line)
    return bool(cells) and all(_SEP_CELL.match(c) for c in cells)


def _format(block):
    indent = re.match(r"^\s*", block[0]).group(0)
    rows = [_cells(l) for l in block]
    ncol = max(len(r) for r in rows)
    rows = [r + [""] * (ncol - len(r)) for r in rows]
    aligns = []
    for c in rows[1]:
        c = c.strip()
        aligns.append("c" if c.startswith(":") and c.endswith(":") and len(c) > 1
                      else "r" if c.endswith(":") else "l")
    # numeric columns: right-justified in the source only (rendering unchanged)
    pad_right = []
    for j in range(ncol):
        body = [r[j] for r in rows[2:] if r[j]]
        pad_right.append(aligns[j] == "r" or (aligns[j] == "l" and bool(body)
                                              and all(_NUM.match(c) for c in body)))
    widths = [3] * ncol
    for i, r in enumerate(rows):
        if i == 1:
            continue
        for j, c in enumerate(r):
            widths[j] = max(widths[j], width(c))
    out = []
    for i, r in enumerate(rows):
        parts = []
        for j, c in enumerate(r):
            w = widths[j]
            if i == 1:
                a = aligns[j]
                d = "-" * w
                if a == "c":
                    d = ":" + "-" * (w - 2) + ":"
                elif a == "r":
                    d = "-" * (w - 1) + ":"
                elif c.strip().startswith(":"):
                    d = ":" + "-" * (w - 1)
                parts.append(d)
                continue
            pad = w - width(c)
            if pad_right[j] and i > 1:
                parts.append(" " * pad + c)
            elif aligns[j] == "c":
                parts.append(" " * (pad // 2) + c + " " * (pad - pad // 2))
            else:
                parts.append(c + " " * pad)
        out.append(indent + "| " + " | ".join(parts) + " |")
    return out


def align_tables(text):
    """Return `text` with every pipe table aligned (line endings kept)."""
    nl = "\r\n" if "\r\n" in text else "\n"
    lines = text.split(nl)
    out, i, fence = [], 0, None
    while i < len(lines):
        line = lines[i]
        m = _FENCE.match(line)
        if fence:
            out.append(line)
            if m and m.group(1) == fence:
                fence = None
            i += 1
            continue
        if m:
            fence = m.group(1)
            out.append(line)
            i += 1
            continue
        if (line.lstrip().startswith("|") and i + 1 < len(lines)
                and lines[i + 1].lstrip().startswith("|") and _is_sep(lines[i + 1])):
            j = i + 2
            while j < len(lines) and lines[j].lstrip().startswith("|"):
                j += 1
            out += _format(lines[i:j])
            i = j
            continue
        out.append(line)
        i += 1
    return nl.join(out)


def write_md(path, text):
    """Write a markdown file with its tables aligned."""
    Path(path).write_text(align_tables(text), encoding="utf-8")


def main(argv):
    check = "--check" in argv
    files = [a for a in argv if a != "--check"]
    changed = []
    for f in files:
        p = Path(f)
        old = p.read_bytes().decode("utf-8")
        new = align_tables(old)
        if new != old:
            changed.append(f)
            if not check:
                p.write_bytes(new.encode("utf-8"))
    for f in changed:
        print(("would align " if check else "aligned ") + f)
    return 1 if (check and changed) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

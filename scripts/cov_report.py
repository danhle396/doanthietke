#!/usr/bin/env python3
"""Functional coverage report: every `cover property` point (Verilator user
coverage) in a merged coverage.dat, aggregated by point name over all
instances. Prints the table and writes results/coverage/functional.md.

Usage: cov_report.py [build/cov/merged.dat]
"""
import re
import sys
from pathlib import Path
from md_table import write_md  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent


def parse(dat):
    pts = {}
    for line in Path(dat).read_text(errors="replace").splitlines():
        if not line.startswith("C '"):
            continue
        m = re.match(r"C '(.*)' (\d+)$", line)
        if not m:
            continue
        fields = dict(kv.split("\x02", 1) for kv in m.group(1).split("\x01") if "\x02" in kv)
        page = fields.get("page", "")
        if not page.startswith("v_user"):
            continue
        name = fields.get("o", "?")
        hier = fields.get("h", "?")
        cnt = int(m.group(2))
        p = pts.setdefault(name, {"count": 0, "inst": set(), "hit_inst": set()})
        p["count"] += cnt
        p["inst"].add(hier)
        if cnt:
            p["hit_inst"].add(hier)
    return pts


def main():
    dat = sys.argv[1] if len(sys.argv) > 1 else str(ROOT / "build/cov/merged.dat")
    pts = parse(dat)
    hit = sum(1 for p in pts.values() if p["count"] > 0)
    lines = ["# Functional coverage", "",
             f"{hit}/{len(pts)} điểm cover đạt (gộp theo tên, mọi instance). Điểm định nghĩa trong "
             "`tb/cov/*.sv`, gắn bằng `bind`. Tái tạo: `make cov`.", "",
             "| Điểm cover | Số lần | Instance đạt / tổng | Kết quả |", "|---|---|---|---|"]
    for name in sorted(pts):
        p = pts[name]
        lines.append(f"| `{name}` | {p['count']} | {len(p['hit_inst'])}/{len(p['inst'])} | "
                     f"{'ĐẠT' if p['count'] else 'CHƯA ĐẠT'} |")
    out = ROOT / "results/coverage/functional.md"
    out.parent.mkdir(parents=True, exist_ok=True)
    write_md(out, "\n".join(lines) + "\n")
    print(f"[cov] functional: {hit}/{len(pts)} cover points hit")
    for name in sorted(pts):
        if not pts[name]["count"]:
            print(f"[cov]   not hit: {name}")


if __name__ == "__main__":
    main()

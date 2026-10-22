#!/usr/bin/env python3
"""make docs: diagrams (matplotlib), waveform figures + walkthrough table, and
the report docs/report/baocao.docx (pandoc, if available).

Usage: build_docs.py [--no-waves]
"""
import argparse
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))
import common  # noqa: E402,F401  (sets PATH for the tools)

REPORT = ROOT / "docs/report"
CHAPTERS = ["00_bia.md", "chuong1_tong_quan.md", "chuong2_loi.md", "chuong3_soc.md",
            "chuong4_xac_minh.md", "chuong5_ket_luan.md", "tai_lieu_tham_khao.md"]


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--no-waves", action="store_true")
    args = ap.parse_args()
    py = sys.executable
    subprocess.run([py, str(ROOT / "scripts/draw_diagrams.py")], check=True)
    if not args.no_waves:
        subprocess.run([py, str(ROOT / "scripts/make_waves.py")], check=True)
    pandoc = shutil.which("pandoc")
    if not pandoc:
        print("[docs] pandoc not found: report kept as Markdown only")
        return
    files = [str(REPORT / c) for c in CHAPTERS if (REPORT / c).exists()]
    out = REPORT / "baocao.docx"
    subprocess.run([pandoc, "--toc", "--toc-depth=2",
                    f"--resource-path={REPORT}", "-o", str(out)] + files, check=True, cwd=REPORT)
    print(f"[docs] {out.relative_to(ROOT)} ({out.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()

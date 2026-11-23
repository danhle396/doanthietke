#!/usr/bin/env python3
"""Screenshots of the real GTKWave window (no drawing of our own).

A virtual X display (Xvfb) runs GTKWave on a dump written by the simulator;
a .gtkw save file selects the signals (with short aliases and comment rows),
a Tcl script sets the time window and the marker, and ImageMagick `import`
grabs the screen once GTKWave has drawn it.

Library:
  with Screen() as scr:
      scr.shot(dump, rows, t0_ns, t1_ns, out_png, marker_ns=None)
  rows: list of ("sig", "dut.u_core.pc_q", width, "alias") or ("comment", "text")
        hierarchical names are relative to the testbench top (TOP.<tb>.)
Needs: Xvfb, ImageMagick (import), xdpyinfo / xwininfo (x11-utils), gtkwave.
"""
import os
import re
import shutil
import subprocess
import tempfile
import time
from pathlib import Path

GTKWAVE = shutil.which("gtkwave") or str(Path.home() / "tools/oss-cad-suite/bin/gtkwave")
UNITS = {"s": 1e9, "ms": 1e6, "us": 1e3, "ns": 1.0, "ps": 1e-3, "fs": 1e-6}


def dump_ns_per_unit(dump):
    """Nanoseconds per time unit of a VCD file (its $timescale)."""
    head = ""
    with open(dump, errors="replace") as f:
        for _ in range(200):
            line = f.readline()
            if not line:
                break
            head += line
            if "$enddefinitions" in line:
                break
    m = re.search(r"\$timescale\s*(\d+)\s*([munpf]?s)\s*\$end", head, re.S)
    if not m:
        return 1.0
    return int(m.group(1)) * UNITS[m.group(2)]


class Screen:
    def __init__(self, display=":77", width=2560, height=1200, top="tb_soc"):
        self.display, self.w, self.h, self.top = display, width, height, top
        self.env = dict(os.environ, DISPLAY=display, GDK_BACKEND="x11")  # never WSLg/Wayland
        self.env.pop("WAYLAND_DISPLAY", None)
        self.tmp = Path(tempfile.mkdtemp(prefix="gtkshot_"))

    def __enter__(self):
        self.xvfb = subprocess.Popen(["Xvfb", self.display, "-screen", "0", f"{self.w}x{self.h}x24",
                                      "-nolisten", "tcp"], stdout=subprocess.DEVNULL,
                                     stderr=subprocess.DEVNULL)
        for _ in range(50):
            if subprocess.run(["xdpyinfo"], env=self.env, stdout=subprocess.DEVNULL,
                              stderr=subprocess.DEVNULL).returncode == 0:
                return self
            time.sleep(0.1)
        raise RuntimeError("Xvfb did not start")

    def __exit__(self, *exc):
        self.xvfb.terminate()
        self.xvfb.wait(10)
        shutil.rmtree(self.tmp, ignore_errors=True)

    def _gtkw(self, dump, rows, width):
        # window just tall enough for the rows (title, toolbar, time axis, scroll bar; 21 px a row)
        h = min(self.h, 150 + 21 * len(rows))
        lines = [f'[dumpfile] "{dump}"', f"[size] {width} {h}", "[pos] 0 0",
                 "[signals_width] 300", "[sst_expanded] 0", "[sst_width] 1"]
        for r in rows:
            if r[0] == "comment":
                lines += ["@200", f"-{r[1]}"]
                continue
            _, name, width, alias = r
            full = f"{self.top}.{name}" + (f"[{width - 1}:0]" if width > 1 else "")
            lines += ["@28" if width == 1 else "@22", f"+{{{alias}}} {full}"]
        return "\n".join(lines) + "\n"

    def shot(self, dump, rows, t0_ns, t1_ns, out_png, marker_ns=None, width=1600):
        dump = str(Path(dump).resolve())
        k = dump_ns_per_unit(dump)
        t0, t1 = int(round(t0_ns / k)), int(round(t1_ns / k))
        gtkw = self.tmp / "view.gtkw"
        gtkw.write_text(self._gtkw(dump, rows, min(width, self.w)))
        tcl = self.tmp / "view.tcl"
        cmds = [f"gtkwave::setZoomRangeTimes {t0} {t1}"]
        if marker_ns is not None:
            cmds.append(f"gtkwave::setMarker {int(round(marker_ns / k))}")
        tcl.write_text("\n".join(cmds) + "\n")
        p = subprocess.Popen([GTKWAVE, "-a", str(gtkw), "-S", str(tcl), dump], env=self.env,
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                             start_new_session=True)
        try:
            # wait for the main window, then give it time to load and draw
            win = None
            for _ in range(300):
                tree = subprocess.run(["xwininfo", "-root", "-tree"], env=self.env,
                                      capture_output=True, text=True).stdout
                m = re.search(r"^\s*(0x[0-9a-f]+) \"GTKWave - ", tree, re.M)
                if m:
                    win = m.group(1)
                    break
                time.sleep(0.1)
            else:
                raise RuntimeError("GTKWave window did not appear")
            time.sleep(3.0)
            Path(out_png).parent.mkdir(parents=True, exist_ok=True)
            subprocess.run(["import", "-window", win, str(out_png)], env=self.env, check=True)
        finally:
            os.killpg(p.pid, 15)
            p.wait(10)
        return out_png

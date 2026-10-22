#!/usr/bin/env python3
"""Minimal VCD reader + waveform plotter (matplotlib).

Library:
  vcd = Vcd(path, wanted)       # wanted: list of signal names (suffix match on the
                                # dotted hierarchy, e.g. "u_core.u_if.pc_q")
  vcd.value(name, t)            # value (int, or None for x/z) at time t
  vcd.changes(name)             # [(time, value), ...]
  plot(vcd, signals, t0, t1, out_png, title, period=20, labels=None, radix=None)

CLI:
  vcd2png.py wave.vcd out.png --signals a.b.clk,a.b.pc --start 1000 --end 2000 --title "..."
Times are converted to ns using the VCD $timescale (one clock = 20 ns).
"""
import argparse
import bisect
import re
import sys


class Vcd:
    def __init__(self, path, wanted):
        self.wanted = list(wanted)
        self.ids = {}       # id -> list of wanted names
        self.width = {}     # name -> bits
        self.data = {}      # name -> ([times], [values])
        self.names = []     # every full name in the file (for debugging)
        self._parse(path)

    def _match(self, full):
        return [w for w in self.wanted if full == w or full.endswith("." + w)]

    def _parse(self, path):
        scope = []
        div = 1  # VCD time units per ns
        with open(path, "r", errors="replace") as f:
            for line in f:
                tok = line.split()
                if not tok:
                    continue
                if tok[0] == "$timescale":
                    ts = " ".join(tok[1:])
                    if "$end" not in ts:
                        ts += " " + next(f).strip()
                    m = re.match(r"(\d+)\s*(fs|ps|ns|us)", ts)
                    if m:
                        mult = int(m.group(1)) * {"fs": 1e-6, "ps": 1e-3, "ns": 1, "us": 1e3}[m.group(2)]
                        div = 1 / mult if mult < 1 else 1
                elif tok[0] == "$scope":
                    scope.append(tok[2])
                elif tok[0] == "$upscope":
                    scope.pop()
                elif tok[0] == "$var":
                    width, ident, name = int(tok[2]), tok[3], tok[4]
                    full = ".".join([s for s in scope if s != "TOP"] + [name])
                    self.names.append(full)
                    for w in self._match(full):
                        if w in self.width:
                            continue
                        self.ids.setdefault(ident, []).append(w)
                        self.width[w] = width
                        self.data[w] = ([], [])
                elif tok[0] == "$enddefinitions":
                    break
            t = 0
            ids = self.ids
            for line in f:
                c = line[0]
                if c == "#":
                    t = int(int(line[1:]) // div)
                elif c in "01xzXZ":
                    ident = line[1:].strip()
                    if ident in ids:
                        v = None if c in "xzXZ" else int(c)
                        for w in ids[ident]:
                            self._add(w, t, v)
                elif c in "bB":
                    val, ident = line[1:].split()
                    if ident in ids:
                        v = None if re.search(r"[xzXZ]", val) else int(val, 2)
                        for w in ids[ident]:
                            self._add(w, t, v)
        missing = [w for w in self.wanted if w not in self.width]
        if missing:
            raise KeyError(f"signals not found in VCD: {missing}")

    def _add(self, w, t, v):
        ts, vs = self.data[w]
        if ts and ts[-1] == t:
            vs[-1] = v
        else:
            ts.append(t)
            vs.append(v)

    def value(self, name, t):
        ts, vs = self.data[name]
        i = bisect.bisect_right(ts, t) - 1
        return vs[i] if i >= 0 else None

    def changes(self, name):
        ts, vs = self.data[name]
        return list(zip(ts, vs))


def plot(vcd, signals, t0, t1, out_png, title, period=20, labels=None, radix=None,
         sample_offset=None):
    """Draw signals between t0 and t1. Buses are drawn as value boxes."""
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    INK, INK2, GRID, SURF, C1 = "#0b0b0b", "#52514e", "#e4e3df", "#fcfcfb", "#2a78d6"
    labels = labels or signals
    radix = radix or {}
    n = len(signals)
    fig_h = 0.42 * n + 1.0
    fig, ax = plt.subplots(figsize=(11, fig_h))
    fig.patch.set_facecolor(SURF)
    ax.set_facecolor(SURF)
    for i, s in enumerate(signals):
        y0 = (n - 1 - i) * 1.0
        ts, vs = vcd.data[s]
        # segments inside the window
        pts = [(t0, vcd.value(s, t0))]
        for t, v in zip(ts, vs):
            if t0 < t < t1:
                pts.append((t, v))
        pts.append((t1, None))
        w = vcd.width[s]
        for (ta, va), (tb, _) in zip(pts[:-1], pts[1:]):
            if w == 1:
                y = y0 + (0.7 if va == 1 else 0.1)
                col = "#e34948" if va is None else C1
                ax.plot([ta, tb], [y, y], color=col, linewidth=1.6)
            else:
                ax.fill_between([ta, tb], y0 + 0.1, y0 + 0.7, color="#d5e5f7" if va else SURF,
                                edgecolor=C1, linewidth=0.8)
                if (tb - ta) > (t1 - t0) * 0.035:
                    fmt = radix.get(s, "hex")
                    txt = "x" if va is None else (str(va) if fmt == "dec" else f"{va:x}")
                    ax.text((ta + tb) / 2, y0 + 0.4, txt, ha="center", va="center",
                            fontsize=7, color=INK)
        # vertical edges for single bits
        if w == 1:
            prev = pts[0][1]
            for t, v in pts[1:-1]:
                if v != prev:
                    ax.plot([t, t], [y0 + 0.1, y0 + 0.7], color=C1, linewidth=1.6)
                prev = v
    ax.set_yticks([(n - 1 - i) + 0.4 for i in range(n)])
    ax.set_yticklabels(labels, fontsize=8, color=INK)
    ax.set_xlim(t0, t1)
    ax.set_ylim(-0.1, n)
    # clock grid: one line per rising edge (period/2 offset in this testbench)
    first = ((t0 // period) + 1) * period
    for t in range(int(first), int(t1), period):
        ax.axvline(t, color=GRID, linewidth=0.6, zorder=0)
    ticks = list(range(int(first), int(t1), period * max(1, int((t1 - t0) / period / 20))))
    ax.set_xticks(ticks)
    ax.set_xticklabels([str((t - first) // period) for t in ticks], fontsize=7, color=INK2)
    ax.set_xlabel("chu kỳ clock (từ đầu cửa sổ)", color=INK2, fontsize=8)
    for sp in ("top", "right", "left"):
        ax.spines[sp].set_visible(False)
    ax.set_title(title, loc="left", fontsize=10, color=INK)
    fig.tight_layout()
    fig.savefig(out_png, dpi=150)
    plt.close(fig)


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("vcd")
    ap.add_argument("png")
    ap.add_argument("--signals", required=True)
    ap.add_argument("--start", type=int, required=True)
    ap.add_argument("--end", type=int, required=True)
    ap.add_argument("--title", default="")
    args = ap.parse_args()
    sigs = args.signals.split(",")
    v = Vcd(args.vcd, sigs)
    plot(v, sigs, args.start, args.end, args.png, args.title)


if __name__ == "__main__":
    main()

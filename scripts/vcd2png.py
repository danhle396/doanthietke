#!/usr/bin/env python3
"""Minimal VCD reader (used by scripts/make_waves.py to find the time window of
each waveform scene). The pictures themselves are screenshots of GTKWave
(scripts/gtkwave_shot.py); this module no longer draws anything.

Library:
  vcd = Vcd(path, wanted)       # wanted: list of signal names (suffix match on the
                                # dotted hierarchy, e.g. "u_core.u_if.pc_q")
  vcd.value(name, t)            # value (int, or None for x/z) at time t
  vcd.changes(name)             # [(time, value), ...]
Times are converted to ns using the VCD $timescale.
"""
import bisect
import re


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

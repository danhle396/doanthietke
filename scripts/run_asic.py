#!/usr/bin/env python3
"""ASIC layout with OpenLane 2 (sky130A, sky130_fd_sc_hd) - decision D30.

  * Flow: OpenLane 2.3.10 'Classic' flow in its Docker image
    (ghcr.io/efabless/openlane2:2.3.10), PDK sky130A from Volare
    (~/.volare, open_pdks 0fe599b). Designs: asic/<top>/config.json for the
    pipelined core rv_core (default parameters: M, C, BP_MODE 2) and the
    single-cycle core rv_core_sc. The core is hardened alone: soc_top holds a
    128 KB RAM that would have to be built from flip-flops (no SRAM macro in
    the flow). SystemVerilog is read by Synlig (USE_SYNLIG): the Yosys 0.46
    frontend of the image rejects file-scope package imports.
  * Gate-level check: the final (post-route) netlist is simulated with Icarus
    Verilog and the sky130_fd_sc_hd functional models; the same testbench
    (tb/asic/tb_core_gl.v) runs the RTL with Verilator. Every riscv-tests
    program that passes in results/isa/<cfg>.csv must PASS on both with the
    same cycle count and the same store signature.
  * Report: results/asic/summary.md, summary.json, gl_<top>.csv,
    layout_<top>.png (KLayout render of the final GDS) and the signoff timing
    excerpts timing_<top>.txt.

Usage: run_asic.py [--flow] [--gl] [--report] [--force] [--top rv_core ...]
       (no step option = all three)
"""
import argparse
import csv
import json
import os
import re
import shutil
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import BUILD, HOME, JOBS, RESULTS, RISCV_PREFIX, ROOT, VERILATOR, run  # noqa: E402

IMAGE = "ghcr.io/efabless/openlane2:2.3.10"
PDK_ROOT = Path(os.environ.get("PDK_ROOT", HOME / ".volare"))
PDK = PDK_ROOT / "volare/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A"
CELLS = PDK / "libs.ref/sky130_fd_sc_hd/verilog"
IVERILOG = os.environ.get("IVERILOG", "iverilog")
VVP = os.environ.get("VVP", "vvp")
OUT = RESULTS / "asic"
WORK = BUILD / "asic"
TAG = "base"
NOM = "nom_tt_025C_1v80"  # typical corner used for the headline numbers
CORNERS = ["nom_tt_025C_1v80", "nom_ss_100C_1v60", "nom_ff_n40C_1v95"]

# top -> (ISA results file, ELF variant directory)
DESIGNS = {
    "rv_core": ("m1c1_bp2", "imc"),
    "rv_core_sc": ("sc", "i"),
}


def run_dir(top):
    return ROOT / "asic" / top / "runs" / TAG


def core_files():
    """RTL files of the two cores (rtl_files.f up to rv_core_sc.sv)."""
    lines = [l.strip() for l in (ROOT / "rtl/rtl_files.f").read_text().splitlines()
             if l.strip() and not l.startswith("#")]
    return lines[:lines.index("rtl/core_sc/rv_core_sc.sv") + 1]


def docker(args, workdir, log=None, timeout=None):
    """Run a command in the OpenLane image as the current user."""
    cmd = ["docker", "run", "--rm", "-u", f"{os.getuid()}:{os.getgid()}", "-e", "HOME=/tmp", "-e", "QT_QPA_PLATFORM=offscreen",
           "-v", f"{ROOT}:{ROOT}", "-v", f"{PDK_ROOT}:{PDK_ROOT}", "-w", str(workdir), IMAGE] + args
    return run(cmd, log=log, timeout=timeout)


# --------------------------------------------------------------------------
# OpenLane flow
# --------------------------------------------------------------------------
def fresh(top):
    """True if the final metrics exist and are newer than the RTL and config."""
    m = run_dir(top) / "final/metrics.json"
    if not m.exists():
        return False
    srcs = [ROOT / f for f in core_files()] + [ROOT / "asic" / top / "config.json"]
    return m.stat().st_mtime > max(p.stat().st_mtime for p in srcs)


def flow(top, force):
    if fresh(top) and not force:
        print(f"[asic] {top}: up to date ({run_dir(top)})")
        return
    print(f"[asic] {top}: OpenLane flow (30-60 min) ...", flush=True)
    log = WORK / f"openlane_{top}.log"
    docker(["openlane", "--pdk-root", str(PDK_ROOT), "--run-tag", TAG, "--overwrite",
            "--hide-progress-bar", "-j", str(JOBS), "config.json"],
           ROOT / "asic" / top, log=log)
    print(f"[asic] {top}: done, log {log.relative_to(ROOT)}")


# --------------------------------------------------------------------------
# Gate-level simulation vs RTL
# --------------------------------------------------------------------------
RESULT_RE = re.compile(r"RESULT (\w+) code=(-?\d+) cycles=(\d+) writes=(\d+) wsig=([0-9a-fx]+)")


def build_sims(top):
    d = WORK / f"gl_{top}"
    d.mkdir(parents=True, exist_ok=True)
    tb = str(ROOT / "tb/asic/tb_core_gl.v")
    rtl_exe = d / "rtl/sim"
    run([VERILATOR, "--binary", "-j", str(JOBS), "-Wno-fatal", "-Wno-lint", "-Wno-style",
         "--top-module", "tb_core_gl", f"-DDUT={top}", "-Mdir", str(d / "rtl"), "-o", "sim"]
        + [str(ROOT / f) for f in core_files()] + [tb], log=d / "rtl_build.log")
    gl_vvp = d / "gl.vvp"
    netlist = run_dir(top) / "final/nl" / f"{top}.nl.v"
    run([IVERILOG, "-g2005", "-DFUNCTIONAL", "-DUNIT_DELAY=#1", f"-DDUT={top}", "-o", str(gl_vvp),
         str(CELLS / "primitives.v"), str(CELLS / "sky130_fd_sc_hd.v"), str(netlist), tb],
        log=d / "gl_build.log")
    return rtl_exe, gl_vvp


def tohost_addr(elf):
    for line in run([RISCV_PREFIX + "nm", str(elf)]).stdout.splitlines():
        p = line.split()
        if len(p) == 3 and p[2] == "tohost":
            return p[0]
    raise RuntimeError(f"no tohost in {elf}")


def parse_result(text):
    m = RESULT_RE.search(text)
    if not m:
        return dict(result="NO_RESULT", cycles="", writes="", wsig="")
    return dict(result=m.group(1), cycles=int(m.group(3)), writes=int(m.group(4)), wsig=m.group(5))


def gate_level(top):
    cfg, variant = DESIGNS[top]
    tests = [r["test"] for r in csv.DictReader(open(RESULTS / "isa" / f"{cfg}.csv"))
             if r["result"] == "PASS"]
    print(f"[asic] {top}: gate-level check, {len(tests)} riscv-tests ...", flush=True)
    rtl_exe, gl_vvp = build_sims(top)
    logs = WORK / f"gl_{top}/logs"
    logs.mkdir(parents=True, exist_ok=True)

    def one(t):
        elf = BUILD / "sw/isa" / variant / f"{t}.elf"
        hexf = elf.with_suffix(".hex")
        args = [f"+hex={hexf}", f"+tohost={tohost_addr(elf)}", "+max_cycles=200000"]
        r = parse_result(run([str(rtl_exe)] + args, log=logs / f"{t}.rtl.log", check=False).stdout)
        g = parse_result(run([VVP, "-n", str(gl_vvp)] + args, log=logs / f"{t}.gl.log",
                             check=False).stdout)
        same = all(r[k] == g[k] for k in ("result", "cycles", "writes", "wsig"))
        ok = same and r["result"] == "PASS"
        return dict(test=t, rtl=r["result"], gl=g["result"], rtl_cycles=r["cycles"],
                    gl_cycles=g["cycles"], writes=g["writes"], wsig=g["wsig"],
                    match="YES" if ok else "NO")

    with ThreadPoolExecutor(max_workers=JOBS) as ex:
        rows = list(ex.map(one, tests))
    OUT.mkdir(parents=True, exist_ok=True)
    with open(OUT / f"gl_{top}.csv", "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)
    bad = [r["test"] for r in rows if r["match"] != "YES"]
    print(f"[asic] {top}: gate-level {len(rows) - len(bad)}/{len(rows)} identical to RTL"
          + (f" - MISMATCH {bad}" if bad else ""))
    return not bad


# --------------------------------------------------------------------------
# Report
# --------------------------------------------------------------------------
RENDER = r"""
import pya
# Only the routing layers (li1, met1..met5) and the die boundary: the full
# layer set hides everything under well/implant/fill shapes.
SHOW = {(67, 20), (68, 20), (69, 20), (70, 20), (71, 20), (72, 20), (235, 4)}
lv = pya.LayoutView()
lv.set_config("background-color", "#ffffff")
lv.set_config("grid-visible", "false")
lv.set_config("text-visible", "false")
lv.load_layout(gds, 0)
lv.load_layer_props(lyp)
it = lv.begin_layers()
while not it.at_end():
    lp = it.current()
    lp.visible = (lp.source_layer, lp.source_datatype) in SHOW
    lv.set_layer_properties(it, lp)
    it.next()
lv.max_hier()
lv.zoom_fit()
lv.save_image(out, int(size), int(size))
"""


def render(top):
    gds = run_dir(top) / "final/gds" / f"{top}.gds"
    script = WORK / "render_gds.py"
    script.write_text(RENDER)
    png = OUT / f"layout_{top}.png"
    docker(["klayout", "-z", "-nc", "-rx", "-r", str(script), "-rd", f"gds={gds}",
            "-rd", f"lyp={PDK / 'libs.tech/klayout/tech/sky130A.lyp'}", "-rd", f"out={png}",
            "-rd", "size=1400"], ROOT, log=WORK / f"render_{top}.log", timeout=900)
    return png


def metric(m, key, corner=None):
    if corner:
        key = f"{key}__corner:{corner}"
    return m.get(key)


def timing_excerpt(top):
    """Worst setup path of the typical corner from the signoff STA report."""
    sta = sorted(run_dir(top).glob("*-openroad-stapostpnr"))
    if not sta:
        return None
    rpt = sta[-1] / NOM / "max.rpt"
    if not rpt.exists():
        return None
    text = rpt.read_text()
    end = text.find("slack")
    excerpt = text[:text.find("\n", end) + 1] if end > 0 else text[:6000]
    dst = OUT / f"timing_{top}.txt"
    dst.write_text(f"# {top}: worst setup path, corner {NOM} (OpenROAD STA after routing)\n"
                   f"# source: {rpt.relative_to(ROOT)}\n\n" + excerpt)
    return dst


def report():
    OUT.mkdir(parents=True, exist_ok=True)
    data = {}
    for top in DESIGNS:
        mfile = run_dir(top) / "final/metrics.json"
        if not mfile.exists():
            print(f"[asic] {top}: no final metrics, run --flow first")
            continue
        m = json.loads(mfile.read_text())
        cfg = json.loads((ROOT / "asic" / top / "config.json").read_text())
        period = float(cfg["CLOCK_PERIOD"])
        bbox = [float(x) for x in str(m["design__die__bbox"]).split()]
        ws = {c: metric(m, "timing__setup__ws", c) for c in CORNERS}
        d = dict(
            period_ns=period,
            die_um=[round(bbox[2] - bbox[0], 1), round(bbox[3] - bbox[1], 1)],
            die_mm2=round((bbox[2] - bbox[0]) * (bbox[3] - bbox[1]) / 1e6, 4),
            core_area_um2=m.get("design__core__area"),
            std_cells=m.get("design__instance__count__stdcell"),
            instances=m.get("design__instance__count"),
            cell_area_um2=m.get("design__instance__area__stdcell"),
            utilization=m.get("design__instance__utilization"),
            wirelength_um=m.get("route__wirelength"),
            setup_ws_ns=ws,
            hold_ws_ns={c: metric(m, "timing__hold__ws", c) for c in CORNERS},
            fmax_mhz={c: round(1000.0 / (period - w), 2) for c, w in ws.items() if w is not None},
            power_w=dict(total=m.get("power__total"), internal=m.get("power__internal__total"),
                         switching=m.get("power__switching__total"),
                         leakage=m.get("power__leakage__total")),
            drc_magic=m.get("magic__drc_error__count"),
            drc_klayout=m.get("klayout__drc_error__count"),
            drc_route=m.get("route__drc_errors"),
            lvs_errors=m.get("design__lvs_error__count"),
            antenna_nets=m.get("antenna__violating__nets"),
            xor_diff=m.get("design__xor_difference__count"),
            max_slew_viol=m.get("design__max_slew_violation__count"),  # worst of all corners
            max_cap_viol=m.get("design__max_cap_violation__count"),
            max_slew_viol_tt=metric(m, "design__max_slew_violation__count", NOM),
            max_cap_viol_tt=metric(m, "design__max_cap_violation__count", NOM),
        )
        gl = OUT / f"gl_{top}.csv"
        if gl.exists():
            rows = list(csv.DictReader(open(gl)))
            d["gl_match"] = [sum(r["match"] == "YES" for r in rows), len(rows)]
        if not (OUT / f"layout_{top}.png").exists() or \
                (OUT / f"layout_{top}.png").stat().st_mtime < mfile.stat().st_mtime:
            render(top)
        timing_excerpt(top)
        data[top] = d
    (OUT / "summary.json").write_text(json.dumps(data, indent=2) + "\n")
    write_md(data)


def fmt(v, nd=2):
    return "–" if v is None else (f"{v:,.{nd}f}" if isinstance(v, float) else f"{v:,}")


def write_md(data):
    tops = list(data)
    L = ["# Layout ASIC – OpenLane 2 / sky130A", "",
         "OpenLane 2.3.10 (flow `Classic`, image Docker `ghcr.io/efabless/openlane2:2.3.10`), PDK sky130A "
         "(open_pdks `0fe599b`), thư viện cell `sky130_fd_sc_hd`. Chỉ làm layout cho **lõi** (cổng Wishbone là "
         "chân I/O của khối); RAM 128 KB của SoC không đưa vào vì flow không có macro SRAM (quyết định D30). "
         "Sinh bởi `scripts/run_asic.py` (`make asic`).", "",
         "## Bảng A1 – Kết quả place & route", "",
         "| Chỉ số | " + " | ".join(f"`{t}`" for t in tops) + " |",
         "|---|" + "---|" * len(tops)]

    def row(name, f):
        L.append(f"| {name} | " + " | ".join(f(data[t]) for t in tops) + " |")

    row("Chu kỳ ràng buộc (SDC)", lambda d: f"{d['period_ns']:g} ns ({1000 / d['period_ns']:g} MHz)")
    row("Kích thước die", lambda d: f"{d['die_um'][0]:g} × {d['die_um'][1]:g} µm ({d['die_mm2']:.3f} mm²)")
    row("Số cell chuẩn (gồm tap, fill, diode, buffer)", lambda d: fmt(d["std_cells"]))
    row("Diện tích cell chuẩn", lambda d: f"{fmt(d['cell_area_um2'], 0)} µm²")
    row("Mật độ (utilization)", lambda d: "–" if d["utilization"] is None
        else f"{d['utilization'] * 100:.1f} %")
    row("Tổng chiều dài dây", lambda d: f"{fmt(d['wirelength_um'], 0)} µm")
    for c, label in ((NOM, "TT 25 °C 1,80 V"), ("nom_ss_100C_1v60", "SS 100 °C 1,60 V"),
                     ("nom_ff_n40C_1v95", "FF −40 °C 1,95 V")):
        row(f"Setup slack / Fmax – {label}",
            lambda d, c=c: "–" if d["setup_ws_ns"].get(c) is None else
            f"{d['setup_ws_ns'][c]:+.2f} ns / **{d['fmax_mhz'][c]:.1f} MHz**")
    row("Hold slack (TT)", lambda d: "–" if d["hold_ws_ns"].get(NOM) is None
        else f"{d['hold_ws_ns'][NOM]:+.3f} ns")
    row("Công suất tổng (TT, ước lượng)", lambda d: "–" if d["power_w"]["total"] is None
        else f"{d['power_w']['total'] * 1e3:.2f} mW")
    row("– trong đó: internal / switching / leakage", lambda d: "–" if d["power_w"]["total"] is None
        else f"{d['power_w']['internal'] * 1e3:.2f} mW / {d['power_w']['switching'] * 1e3:.2f} mW / "
        f"{d['power_w']['leakage'] * 1e6:.2f} µW")
    row("DRC (Magic / KLayout / router)",
        lambda d: f"{fmt(d['drc_magic'])} / {fmt(d['drc_klayout'])} / {fmt(d['drc_route'])}")
    row("LVS (Netgen) – số lỗi", lambda d: fmt(d["lvs_errors"]))
    row("Antenna – số net vi phạm", lambda d: fmt(d["antenna_nets"]))
    row("XOR GDS Magic ↔ KLayout", lambda d: fmt(d["xor_diff"]))
    row("Vi phạm max slew / max cap – TT", lambda d: f"{fmt(d['max_slew_viol_tt'])} / {fmt(d['max_cap_viol_tt'])}")
    row("Vi phạm max slew / max cap – góc xấu nhất", lambda d: f"{fmt(d['max_slew_viol'])} / {fmt(d['max_cap_viol'])}")
    row("Gate-level (netlist sau đi dây) ≡ RTL", lambda d: "–" if "gl_match" not in d
        else f"{d['gl_match'][0]}/{d['gl_match'][1]} riscv-tests")
    L += ["",
          "Fmax = 1 / (chu kỳ ràng buộc − setup slack) tại từng góc PVT, theo STA của OpenROAD sau đi dây "
          "(có ký sinh SPEF). Công suất do OpenSTA ước lượng với hoạt động chuyển mạch mặc định, không lấy từ "
          "mô phỏng – chỉ dùng để so sánh tương đối. Gate-level: netlist cuối cùng chạy bằng Icarus Verilog với "
          "mô hình chức năng `sky130_fd_sc_hd`, cùng testbench `tb/asic/tb_core_gl.v` với RTL (Verilator); "
          "một test khớp khi cả hai PASS với cùng số chu kỳ, số lần ghi và chữ ký ghi bộ nhớ "
          "(`results/asic/gl_<top>.csv`).", ""]
    L += ["## Hình", ""]
    for t in tops:
        L += [f"![Layout {t}](layout_{t}.png)", "", f"*Layout `{t}` (GDS cuối, KLayout).* "
              f"Đường găng: `results/asic/timing_{t}.txt`.", ""]
    L += [f"Tái tạo: `make asic` (lần đầu khoảng 1 giờ; kết quả cũ được dùng lại nếu RTL và "
          "`asic/<top>/config.json` không đổi).", ""]
    (OUT / "summary.md").write_text("\n".join(L))
    print("\n".join(L))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--flow", action="store_true")
    ap.add_argument("--gl", action="store_true")
    ap.add_argument("--report", action="store_true")
    ap.add_argument("--force", action="store_true", help="rerun OpenLane even if up to date")
    ap.add_argument("--top", nargs="*", default=list(DESIGNS))
    a = ap.parse_args()
    steps = [s for s in ("flow", "gl", "report") if getattr(a, s)] or ["flow", "gl", "report"]
    WORK.mkdir(parents=True, exist_ok=True)
    ok = True
    if "flow" in steps:
        for t in a.top:  # one at a time: routing needs most of the 7.5 GB RAM
            flow(t, a.force)
    if "gl" in steps:
        for t in a.top:
            ok &= gate_level(t)
    if "report" in steps:
        report()
    if not ok:
        sys.exit(1)


if __name__ == "__main__":
    main()

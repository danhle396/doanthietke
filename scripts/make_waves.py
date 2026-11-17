#!/usr/bin/env python3
"""Waveform figures, pipeline walkthrough table and GTKWave save files.

Runs short simulations on a VCD build of tb_soc (m1c1_bp2), finds the time
window of each scene automatically from the signals, and draws it with
scripts/vcd2png.py:
  forwarding, load-use stall, misprediction + flush, compressed instructions,
  trap entry/exit (MSI interrupt and ECALL), APB transaction, UART frame,
  SPI frame mode 0 and mode 3.
Outputs: results/waves/*.png, results/waves/walkthrough_table.md, docs/gtkw/*.gtkw

Usage: make_waves.py
"""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import BUILD, RESULTS, ROOT, build_soc, make_cfg, run_sim, symbol_addr  # noqa: E402
from build_sw import build_program  # noqa: E402
from vcd2png import Vcd, plot  # noqa: E402
from md_table import write_md  # noqa: E402

OUT = RESULTS / "waves"
GTKW = ROOT / "docs/gtkw"
PERIOD = 20
C = "dut.g_pipe.u_core."

PIPE = ["clk", C + "u_if.pc_q", C + "id_valid", C + "id_pc", C + "ex_valid", C + "ex_pc",
        C + "mem_valid", C + "mem_pc", C + "wb_valid", C + "wb_pc"]
CTRL = [C + "stall_id", C + "stall_ex", C + "flush_if_id", C + "flush_id_ex", C + "flush_ex_mem",
        C + "id_redirect", C + "ex_redirect", C + "mem_redirect", C + "mem_trap", C + "fwd_a",
        C + "fwd_b", C + "id_is_c", C + "ex_is_c", C + "md_stall", C + "bus_wait", C + "irq_req",
        C + "trap_cause", C + "trap_irq", C + "u_csr.mepc_q", C + "rf_wdata", C + "rf_waddr", C + "rf_we"]


def sim_vcd(kind, prog, variant, console, plusargs=(), name=None):
    exe = build_soc(make_cfg(), trace="vcd")
    pdir = ROOT / ("sw/examples" if kind == "examples" else "sw/tests") / prog
    elf = build_program(kind, pdir, variant, console)
    vcd = BUILD / "waves" / f"{name or prog}.vcd"
    vcd.parent.mkdir(parents=True, exist_ok=True)
    ok, out = run_sim(exe, elf.with_suffix(".hex"),
                      ["+trace", f"+trace_file={vcd}"] + list(plusargs),
                      log=BUILD / "waves" / f"{name or prog}.log")
    if not ok:
        raise RuntimeError(f"simulation of {prog} failed")
    return vcd, elf


def first_time(v, sig, pred, after=0):
    for t, val in v.changes(sig):
        if t >= after and val is not None and pred(val):
            return t
    raise RuntimeError(f"condition on {sig} never met")


def window(t_center, before, after):
    return t_center - before * PERIOD, t_center + after * PERIOD


def disasm_map(elf):
    dump = Path(str(elf).replace(".elf", ".dump")).read_text()
    m = {}
    for line in dump.splitlines():
        mm = re.match(r"^\s*([0-9a-f]+):\s+[0-9a-f]+\s+(.*)$", line)
        if mm:
            m[int(mm.group(1), 16)] = re.sub(r"\s+", " ", mm.group(2).split("#")[0]).strip()
    return m


def gtkw(name, dumpfile, signals):
    GTKW.mkdir(parents=True, exist_ok=True)
    lines = [f'[dumpfile] "{dumpfile}"', "[timestart] 0", "[size] 1400 700",
             "[signals_width] 280"]
    for s, w in signals:
        full = "TOP.tb_soc." + s
        if w == 1:
            lines += ["@28", full]
        else:
            lines += ["@22", f"{full}[{w-1}:0]"]
    (GTKW / f"{name}.gtkw").write_text("\n".join(lines) + "\n")


def walkthrough():
    vcd_path, elf = sim_vcd("examples", "walkthrough", "imc", "sim")
    v = Vcd(vcd_path, PIPE + CTRL)
    start = int(symbol_addr(elf, "walk_start"), 16)
    end = int(symbol_addr(elf, "walk_end"), 16)
    dis = disasm_map(elf)
    t_if = first_time(v, C + "u_if.pc_q", lambda x: x == start)
    t_wb = first_time(v, C + "wb_pc", lambda x: x == end, after=t_if)
    t0, t1 = t_if - 2 * PERIOD, t_wb + 3 * PERIOD
    lab = {s: s.replace(C, "") for s in PIPE + CTRL}
    sigs = [C + "u_if.pc_q", C + "id_pc", C + "ex_pc", C + "mem_pc", C + "wb_pc", C + "stall_id",
            C + "flush_id_ex", C + "ex_redirect", C + "mem_trap", C + "fwd_a", C + "fwd_b"]
    plot(v, sigs, t0, t1, OUT / "walkthrough_pipeline.png",
         "Hình W1. Toàn bộ đoạn walkthrough (m1c1_bp2): PC ở từng tầng và tín hiệu điều khiển",
         labels=[lab[s] for s in sigs])

    # ---- table: one row per clock cycle ----
    first_edge = ((t0 // PERIOD) + 1) * PERIOD - PERIOD // 2  # rising edges at 10, 30, ...
    rows = ["| Chu kỳ | IF | ID | EX | MEM | WB | Sự kiện |", "|---|---|---|---|---|---|---|"]
    def stage(valid, pc_sig, t):
        if valid and not v.value(valid, t):
            return "–"
        pc = v.value(pc_sig, t)
        txt = dis.get(pc, "")
        return f"`{pc:08x}` {txt}" if pc is not None else "x"
    k = 0
    t = first_edge + 5
    while t < t1:
        ev = []
        if v.value(C + "bus_wait", t): ev.append("chờ bus APB: stall IF–MEM, bubble → WB")
        elif v.value(C + "md_stall", t): ev.append("MulDiv bận: stall IF–EX")
        elif v.value(C + "stall_id", t): ev.append("load/CSR-use: stall IF, ID")
        if v.value(C + "flush_id_ex", t) and not v.value(C + "stall_ex", t) and not v.value(C + "ex_redirect", t) and not v.value(C + "mem_redirect", t):
            ev.append("bubble → EX")
        if v.value(C + "id_redirect", t): ev.append("redirect ở ID")
        if v.value(C + "ex_redirect", t): ev.append("**sai dự đoán: flush IF, ID**")
        if v.value(C + "mem_trap", t):
            kind = "ngắt" if v.value(C + "trap_irq", t) else "ngoại lệ"
            ev.append(f"**trap ({kind}, cause {v.value(C + 'trap_cause', t)})**: flush, PC ← mtvec")
        elif v.value(C + "mem_redirect", t): ev.append("MRET/FENCE.I: flush")
        fa, fb = v.value(C + "fwd_a", t), v.value(C + "fwd_b", t)
        if v.value(C + "ex_valid", t):
            names = {1: "ex_mem", 2: "mem_wb"}
            if fa in names: ev.append(f"rs1 ← {names[fa]}")
            if fb in names: ev.append(f"rs2 ← {names[fb]}")
        if v.value(C + "irq_req", t): ev.append("irq pending")
        rows.append(f"| {k} | {stage(None, C + 'u_if.pc_q', t)} | {stage(C + 'id_valid', C + 'id_pc', t)} | "
                    f"{stage(C + 'ex_valid', C + 'ex_pc', t)} | {stage(C + 'mem_valid', C + 'mem_pc', t)} | "
                    f"{stage(C + 'wb_valid', C + 'wb_pc', t)} | {'; '.join(ev)} |")
        k += 1
        t += PERIOD
    write_md(OUT / "walkthrough_table.md",
        "# Bảng pipeline theo chu kỳ – walkthrough\n\nSinh tự động bởi `scripts/make_waves.py` từ VCD của "
        "`sw/examples/walkthrough/walk.S` trên `m1c1_bp2`. Giá trị lấy ngay sau cạnh lên của mỗi chu kỳ. "
        "\"rs ← ex_mem/mem_wb\" là lựa chọn của bộ forward cho lệnh ở EX (hiển thị cả khi lệnh không dùng "
        "toán hạng đó, ví dụ `lui`).\n\n"
        + "\n".join(rows) + "\n")

    # ---- focused scenes ----
    t_lw = first_time(v, C + "ex_pc", lambda x: x == start, after=t_if)
    sigs = ["clk", C + "id_pc", C + "ex_pc", C + "mem_pc", C + "wb_pc", C + "stall_id", C + "flush_id_ex",
            C + "fwd_a", C + "fwd_b", C + "rf_waddr", C + "rf_wdata"]
    a, b = window(t_lw, 2, 8)
    plot(v, sigs, a, b, OUT / "load_use_forwarding.png",
         "Hình W2. Load-use stall (1 chu kỳ) và forwarding ex_mem / mem_wb (fwd: 1 = ex_mem, 2 = mem_wb)",
         labels=[lab.get(s, s) for s in sigs])
    t_c = first_time(v, C + "id_is_c", lambda x: x == 1, after=t_if)
    sigs = ["clk", C + "u_if.pc_q", C + "id_pc", C + "id_is_c", C + "ex_pc", C + "ex_is_c", C + "wb_pc"]
    a, b = window(t_c, 3, 7)
    plot(v, sigs, a, b, OUT / "compressed.png",
         "Hình W3. Lệnh nén: PC tăng 2, lệnh 32 bit sau đó nằm vắt qua ranh giới word",
         labels=[lab.get(s, s) for s in sigs])
    t_m = first_time(v, C + "ex_redirect", lambda x: x == 1, after=t_if)
    sigs = ["clk", C + "u_if.pc_q", C + "id_valid", C + "id_pc", C + "ex_valid", C + "ex_pc",
            C + "ex_redirect", C + "flush_if_id", C + "flush_id_ex", C + "mem_valid", C + "mem_pc"]
    a, b = window(t_m, 3, 5)
    plot(v, sigs, a, b, OUT / "mispredict_flush.png",
         "Hình W4. Nhánh taken bị đoán sai ở EX: flush if_id, id_ex (2 bubble), nạp actual_npc",
         labels=[lab.get(s, s) for s in sigs])
    t_tr = first_time(v, C + "mem_trap", lambda x: x == 1, after=t_if)
    t_end = first_time(v, C + "wb_pc", lambda x: x == end, after=t_tr)
    sigs = ["clk", C + "irq_req", C + "mem_valid", C + "mem_pc", C + "mem_trap", C + "trap_cause",
            C + "mem_redirect", C + "u_if.pc_q", C + "u_csr.mepc_q", C + "wb_pc"]
    plot(v, sigs, t_tr - 3 * PERIOD, t_end + 2 * PERIOD, OUT / "trap_entry_exit.png",
         "Hình W5. Vào/ra trap: ngắt MSI rồi ECALL, nhảy tới handler, MRET quay về mepc",
         labels=[lab.get(s, s) for s in sigs])
    gtkw("pipeline", str(BUILD / "logs/systest/m1c1_bp2/hello.fst"),
         [(s.replace("dut.", "dut.") if s != "clk" else "clk", v.width[s]) for s in PIPE + CTRL])
    vcd_path.unlink()


def apb_uart():
    sigs_apb = ["clk", "dut.dbus_cyc", "dut.dbus_stb", "dut.dbus_we", "dut.dbus_adr",
                "dut.dbus_ack", "dut.dbus_err", "dut.paddr", "dut.psel", "dut.penable", "dut.pwrite", "dut.pwdata", "dut.pstrb",
                "dut.pready", "dut.pslverr"]
    vcd_path, _ = sim_vcd("tests", "hello", "imc", "uart", name="hello")
    v = Vcd(vcd_path, sigs_apb + ["dut.uart_tx", "dut.u_uart.u_tx.state_q", "dut.u_uart.tx_level"])
    t = first_time(v, "dut.psel", lambda x: x == 1)
    a, b = window(t, 3, 6)
    plot(v, sigs_apb, a, b, OUT / "apb_transaction.png",
         "Hình W6. Ghi UART.DATA: Wishbone (CYC/STB giữ đến ACK) → cầu APB4 IDLE → SETUP (PSEL) "
         "→ ACCESS (PENABLE, PREADY)",
         labels=[s.replace("dut.", "") for s in sigs_apb])
    t = first_time(v, "dut.uart_tx", lambda x: x == 0)
    s2 = ["clk", "dut.uart_tx", "dut.u_uart.u_tx.state_q", "dut.u_uart.tx_level"]
    plot(v, s2, t - 8 * PERIOD, t + 168 * PERIOD, OUT / "uart_frame.png",
         "Hình W7. Một khung UART 8N1 (BAUD_DIV = 0: 16 chu kỳ/bit): start, 8 bit LSB trước, stop",
         labels=[s.replace("dut.", "") for s in s2])
    gtkw("apb_uart", str(BUILD / "logs/systest/m1c1_bp2/hello.fst"),
         [(s, v.width[s]) for s in sigs_apb + ["dut.uart_tx"]])
    vcd_path.unlink()


def spi():
    sigs = ["clk", "dut.spi_cs_n", "dut.spi_sclk", "dut.spi_mosi", "dut.spi_miso",
            "dut.u_spi.ctrl_q", "dut.u_spi.u_eng.state_q", "dut.u_spi.u_eng.edge_q"]
    vcd_path, _ = sim_vcd("tests", "spi_modes", "imc", "uart", name="spi_modes",
                          plusargs=["+max_cycles=200000"])
    v = Vcd(vcd_path, sigs + ["dut.u_spi.eng_busy"])
    for mode, ctrl in ((0, 0b0001), (3, 0b0111)):
        t_cfg = first_time(v, "dut.u_spi.ctrl_q", lambda x, c=ctrl: x == c)
        t = first_time(v, "dut.u_spi.eng_busy", lambda x: x == 1, after=t_cfg)
        plot(v, sigs, t - 4 * PERIOD, t + 40 * PERIOD, OUT / f"spi_mode{mode}.png",
             f"Hình W{8 + (mode == 3)}. Khung SPI mode {mode} (CPOL={mode >> 1}, CPHA={mode & 1}), "
             "CLK_DIV = 0, MSB trước",
             labels=[s.replace("dut.", "") for s in sigs])
    gtkw("spi", str(BUILD / "logs/systest/m1c1_bp2/spi_modes.fst"), [(s, v.width[s]) for s in sigs])
    vcd_path.unlink()


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    walkthrough()
    apb_uart()
    spi()
    print("[waves] " + ", ".join(sorted(p.name for p in OUT.glob("*.png"))))


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""jtag_uart.py - UART console of the DE2 SoC over the USB-Blaster cable
(JTAG console, fpga/board/jtag_uart_bridge.sv) and automatic board tests.
Windows, Python 3, Quartus II 13.0sp1 (quartus_stp / quartus_cdb / quartus_asm /
quartus_pgm). Run from anywhere; paths are relative to the fpga/ folder.

  python tools/jtag_uart.py term              interactive terminal
                                              (Ctrl+R reset the CPU, Ctrl+Q quit)
  python tools/jtag_uart.py run [-c CMD ...]  reset, print the boot output, send
                                              each CMD after a '>' prompt
      --no-reset  print what the program wrote since it was loaded (first run;
                  a reset does not reload the RAM)
  python tools/jtag_uart.py load NAME         load firmware NAME (mem/ -> MIF
                                              update -> assembler -> program)
  python tools/jtag_uart.py test [NAME ...]   load each firmware, run it, compare
                                              with firmware/NAME/uart_sim.txt;
                                              report: board_results.md
      --flash   also run spi_flash and demo (W25Qxx module on GPIO_0 / JP1)
      --keep    do not reload board_demo at the end

The board must be programmed with a de2_soc.sof that contains the JTAG console
(any build after the bridge was added). Quartus is looked up in QUARTUS_BIN,
then PATH, then the usual install folders.
"""
import argparse
import difflib
import os
import re
import shutil
import subprocess
import sys
import threading
import time
from pathlib import Path

FPGA = Path(__file__).resolve().parent.parent
TCL = Path(__file__).resolve().parent / "jtag_uart.tcl"
QUARTUS_CANDIDATES = [
    r"F:\merged_partition_content\altera\quartus\bin64",
    r"C:\altera\13.0sp1\quartus\bin64",
    r"C:\altera\13.0\quartus\bin64",
    r"C:\altera\13.0sp1\quartus\bin",
]

# firmware run by `test` (self-checking tests and benchmarks: the whole UART
# output must equal the RTL simulation of the same binary)
AUTO = ["hello", "exceptions", "timer_irq", "irq_priority", "irq_during_div", "branch_smc",
        "muldiv_rand",
        "dhrystone", "coremark", "median", "multiply", "qsort", "towers", "vvadd"]
FLASH = ["spi_flash", "demo"]


def quartus_bin():
    env = os.environ.get("QUARTUS_BIN")
    cands = ([env] if env else [])
    exe = shutil.which("quartus_stp")
    if exe:
        cands.append(str(Path(exe).parent))
    cands += QUARTUS_CANDIDATES
    for c in cands:
        if c and (Path(c) / "quartus_stp.exe").exists():
            return Path(c)
    sys.exit("quartus_stp.exe not found: set QUARTUS_BIN to <quartus>\\bin64")


# ----------------------------------------------------------------- console
class Console:
    def __init__(self, qbin):
        self.buf = bytearray()
        self.cv = threading.Condition()
        self.error = None
        self.overflow = False
        self.ready = threading.Event()
        self.echo = None                     # callback(bytes) for the terminal
        self.p = subprocess.Popen([str(qbin / "quartus_stp.exe"), "-t", str(TCL)],
                                  stdin=subprocess.PIPE, stdout=subprocess.DEVNULL,
                                  stderr=subprocess.PIPE, text=True, bufsize=1, cwd=str(FPGA))
        self.th = threading.Thread(target=self._reader, daemon=True)
        self.th.start()
        if not self.ready.wait(30) or self.error or not hasattr(self, "info"):
            self.close()
            raise SystemExit("JTAG console: " + (self.error or "không kết nối được (cáp USB-Blaster cắm "
                                                 "chưa, board bật nguồn chưa?)"))

    def _reader(self):
        for line in self.p.stderr:
            line = line.rstrip("\r\n")
            if line.startswith("D "):
                data = bytes.fromhex(line[2:])
                with self.cv:
                    self.buf += data
                    self.cv.notify_all()
                if self.echo:
                    self.echo(data)
            elif line.startswith("OK "):
                self.info = line[3:]
                self.ready.set()
            elif line == "O":
                self.overflow = True
            elif line.startswith("E "):
                self.error = line[2:]
                self.ready.set()
        self.ready.set()
        with self.cv:
            self.cv.notify_all()

    def _cmd(self, s):
        self.p.stdin.write(s + "\n")
        self.p.stdin.flush()

    def send(self, text):
        data = text.encode("latin-1") if isinstance(text, str) else text
        if data:
            self._cmd("S " + data.hex())

    def reset(self, hold=0.3):
        """Hold the CPU in reset, drain and drop what the bridge FIFO still holds
        from before (up to 8 KB), release."""
        self._cmd("R 1")
        time.sleep(hold)
        self.wait_idle(idle=0.5, timeout=30)
        self.clear()
        self.overflow = False
        self._cmd("R 0")

    def clear(self):
        with self.cv:
            self.buf.clear()

    def text(self):
        with self.cv:
            return self.buf.decode("latin-1")

    def wait_for(self, pattern, timeout=10.0, start=0):
        """Wait until regex `pattern` matches the received text after `start`."""
        rx = re.compile(pattern)
        end = time.time() + timeout
        with self.cv:
            while True:
                m = rx.search(self.buf.decode("latin-1"), start)
                if m:
                    return m
                left = end - time.time()
                if left <= 0 or self.p.poll() is not None:
                    return None
                self.cv.wait(min(left, 0.2))

    def wait_idle(self, idle=1.5, timeout=60.0):
        """Wait until nothing arrives for `idle` seconds."""
        end = time.time() + timeout
        last_len, last_t = -1, time.time()
        while time.time() < end:
            with self.cv:
                n = len(self.buf)
            if n != last_len:
                last_len, last_t = n, time.time()
            elif time.time() - last_t >= idle:
                return True
            time.sleep(0.05)
        return False

    def close(self):
        if not hasattr(self, "p"):
            return
        try:
            if self.p.poll() is None:
                self._cmd("Q")
                self.p.stdin.close()
                self.p.wait(10)
        except Exception:
            self.p.kill()


# --------------------------------------------------------------- programming
def qrun(qbin, tool, *args):
    res = subprocess.run([str(qbin / f"{tool}.exe"), *args], cwd=str(FPGA),
                         stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                         errors="replace")
    if res.returncode != 0:
        if "cable not detected" in res.stdout:
            raise SystemExit("Không thấy cáp USB-Blaster: cắm cáp vào cổng USB BLASTER của board, "
                             "bật nguồn board.")
        tail = "\n".join(l for l in res.stdout.splitlines() if "Error" in l)[-2000:]
        raise RuntimeError(f"{tool} failed:\n{tail}")
    return res.stdout


def program(qbin):
    qrun(qbin, "quartus_pgm", "-c", "USB-Blaster", "-m", "JTAG",
         "-o", "p;output_files/de2_soc.sof")


def load_firmware(qbin, name, log=print):
    src = FPGA / "firmware" / name
    if not (src / "bank0.mif").exists():
        raise SystemExit(f"no firmware {name} (see firmware/DANH_SACH.md)")
    for b in ("bank0.mif", "bank1.mif"):
        shutil.copyfile(src / b, FPGA / "mem" / b)
    log(f"  [{name}] update MIF ...")
    qrun(qbin, "quartus_cdb", "de2_soc", "-c", "de2_soc", "--update_mif")
    log(f"  [{name}] assembler ...")
    qrun(qbin, "quartus_asm", "de2_soc", "-c", "de2_soc")
    log(f"  [{name}] program ...")
    program(qbin)


# ------------------------------------------------------------------ checks
def norm(text):
    lines = [l.rstrip() for l in text.replace("\r", "").split("\n")]
    while lines and not lines[-1]:
        lines.pop()
    while lines and not lines[0]:
        lines.pop(0)
    return lines


def compare(got, exp):
    g, e = norm(got), norm(exp)
    if g == e:
        return True, ""
    diff = list(difflib.unified_diff(e, g, "mô phỏng (uart_sim.txt)", "board", lineterm="", n=1))
    return False, "\n".join(diff[:40])


def run_auto(con, name):
    # No reset here: the first run after configuration is the one to check.
    # A reset (KEY0 or the host bit) restarts the CPU but does not reload the
    # RAM from the MIF, so programs that change their own code or data
    # (branch_smc patches code, qsort sorts its input in place) would run on
    # what the first run left behind. The bridge FIFO (8 KB) has kept the
    # output of the first run since configuration.
    con.wait_idle(idle=1.5, timeout=60)
    got = con.text()
    exp = (FPGA / "firmware" / name / "uart_sim.txt").read_text(encoding="utf-8", errors="replace")
    ok, diff = compare(got, exp)
    m = re.search(r"RESULT \S+: (PASS|FAIL)[^\n]*", got) or \
        re.search(r"\[bench\] name=\S+ cycles=(\d+) instret=(\d+) cpi_x1000=(\d+)", got)
    summary = m.group(0) if m else (norm(got)[0] if norm(got) else "(không có đầu ra)")
    return ok, summary, got, diff


def run_board_demo(con):
    """board_demo: the commands of the simulation (rx_sim.txt); lines that depend
    on time, switches or the flash module are checked for their form only."""
    checks = []
    con.reset()
    if not con.wait_for(r"> $", 10):
        return False, [("banner + prompt", False, con.text()[-200:])], con.text()

    def cmd(c, done, timeout=15):
        start = len(con.text())
        con.send(c + "\n")
        m = con.wait_for(done, timeout, start)
        return con.text()[start:], m

    out, m = cmd("h", r"commands:.*\n> $")
    checks.append(("h: help", m is not None, out.strip().splitlines()[1] if m else out))
    out, m = cmd("i", r"CPI x1000: \d+\n> $")
    ok = m is not None and "misa = 0x40001104" in out and "24000000 Hz" in out
    checks.append(("i: 24 MHz, misa = 0x40001104", ok, out.strip()))
    out, m = cmd("s", r"SW\[15:0\] = 0x[0-9a-f]{4}\n> $")
    checks.append(("s: đọc công tắc", m is not None, out.strip()))
    out, m = cmd("b", r"result = 0x[0-9a-f]+\n> $", 30)
    run2 = re.search(r"run 2:\n(\[bench\] name=board_demo cycles=(\d+) instret=(\d+).*)", out or "")
    sim = (FPGA / "firmware" / "board_demo" / "uart_sim.txt").read_text(encoding="utf-8")
    m_sim = re.search(r"run 2:\n\[bench\] name=board_demo (cycles=\d+ instret=\d+ cpi_x1000=\d+)", sim)
    exp_run2 = m_sim.group(1) if m_sim else "(uart_sim.txt không có run 2)"
    ok_b = m is not None and run2 is not None and exp_run2 in run2.group(1)
    checks.append(("b: run 2 " + exp_run2, ok_b, run2.group(1) if run2 else out.strip()))
    checks.append(("b: result = 0x1dfc7c31", "result = 0x1dfc7c31" in (out or ""),
                   (re.search(r"result = \S+", out or "") or [""])[0]))
    out, m = cmd("t", r"RESULT selftest: [^\n]*\n> $", 20)
    res = re.search(r"RESULT selftest: [^\n]*", out or "")
    checks.append(("t: RESULT selftest: PASS", res is not None and "PASS" in res.group(0),
                   res.group(0) if res else out.strip()))
    out, m = cmd("f", r"JEDEC ID : [^\n]*\n> $")
    checks.append(("f: JEDEC ID (hoặc không có flash)", m is not None, out.strip()))
    out, m = cmd("q", r"bye")
    checks.append(("q: bye", m is not None, out.strip()))
    return all(c[1] for c in checks), checks, con.text()


# ---------------------------------------------------------------- commands
def cmd_term(qbin, args):
    import msvcrt
    con = Console(qbin)
    con.echo = lambda d: (sys.stdout.write(d.decode("latin-1")), sys.stdout.flush())
    print(f"[JTAG console: {con.info}]  Ctrl+R = reset CPU, Ctrl+Q = thoát\n", flush=True)
    try:
        while con.p.poll() is None:
            if msvcrt.kbhit():
                ch = msvcrt.getwch()
                if ch in ("\x11", "\x1d"):
                    break
                if ch == "\x12":
                    con._cmd("R 1"); time.sleep(0.2); con._cmd("R 0")
                    continue
                if ch in ("\x00", "\xe0"):
                    msvcrt.getwch()          # arrow/function key: ignore
                    continue
                con.send("\n" if ch == "\r" else ch)
            else:
                time.sleep(0.01)
    finally:
        con.close()
        if con.error:
            print(f"\n[lỗi: {con.error}]")


def cmd_run(qbin, args):
    con = Console(qbin)
    try:
        if not args.no_reset:
            con.reset()
        if args.cmd:
            for c in args.cmd:
                start = len(con.text())
                if not con.wait_for(r"> $", args.timeout, max(0, start - 2)):
                    break
                con.send(c + "\n")
                con.wait_for(r"\n> $", args.timeout, start + 1)
        con.wait_idle(idle=args.idle, timeout=args.timeout)
        sys.stdout.write(con.text())
        sys.stdout.flush()
        if con.overflow:
            print("\n[cảnh báo: FIFO của cầu bị tràn, mất byte]")
    finally:
        con.close()


def cmd_load(qbin, args):
    load_firmware(qbin, args.name)
    print(f"firmware {args.name} đã nạp")


def cmd_test(qbin, args):
    names = args.names or (["board_demo"] + AUTO + (FLASH if args.flash else []))
    rows, details = [], []
    t0 = time.time()
    try:
        for name in names:
            print(f"== {name}", flush=True)
            load_firmware(qbin, name)
            con = Console(qbin)
            try:
                if name == "board_demo":
                    ok, checks, got = run_board_demo(con)
                    summary = "; ".join(f"{c[0]}: {'ĐẠT' if c[1] else 'SAI'}" for c in checks)
                    diff = "\n".join(f"{'ĐẠT' if c[1] else 'SAI'}  {c[0]}\n      {c[2]}"
                                     for c in checks)
                else:
                    ok, summary, got, diff = run_auto(con, name)
                if con.overflow:
                    ok, summary = False, summary + " (FIFO tràn)"
            finally:
                con.close()
            print(f"   {'PASS' if ok else 'FAIL'}  {summary}", flush=True)
            if not ok and diff:
                print("   " + diff.replace("\n", "\n   "), flush=True)
            rows.append((name, ok, summary))
            details.append((name, got, diff))
    finally:
        if not args.keep and names != ["board_demo"]:
            print("== nạp lại board_demo (mặc định)", flush=True)
            try:
                load_firmware(qbin, "board_demo", log=lambda *_: None)
            except Exception as e:  # report, but keep the results
                print(f"   không nạp lại được board_demo: {e}")
        if rows:                     # never overwrite a report with an empty one
            # only a run of every firmware replaces board_results.md; a subset goes elsewhere
            name = "board_results.md" if not args.names else "board_results_partial.md"
            write_report(rows, details, time.time() - t0, FPGA / name)


def write_report(rows, details, secs, out):
    n_ok = sum(1 for r in rows if r[1])
    L = ["# Kết quả kiểm thử trên board DE2 (qua JTAG console)", "",
         f"Ngày chạy: {time.strftime('%d/%m/%Y %H:%M')}. Thời gian: {secs:.0f} s. "
         f"Kết quả: **{n_ok}/{len(rows)} ĐẠT**.", "",
         "Mỗi firmware được nạp vào RAM (MIF → Assembler → JTAG), CPU được reset qua JTAG và toàn bộ "
         "đầu ra UART được so với `firmware/<tên>/uart_sim.txt` (mô phỏng RTL của cùng file nhị phân). "
         "`board_demo` chạy các lệnh h, i, s, b, f, q; dòng phụ thuộc thời gian / công tắc / flash chỉ "
         "kiểm tra dạng. Tái tạo: `python tools/jtag_uart.py test`.", "",
         "| Firmware | Kết quả | Tóm tắt |", "|---|---|---|"]
    for name, ok, summ in rows:
        L.append(f"| `{name}` | {'ĐẠT' if ok else 'SAI'} | {summ.replace('|', '/')} |")
    L += ["", "## Đầu ra UART trên board", ""]
    for name, got, diff in details:
        L += [f"### {name}", "", "```", got.replace("\r", "").rstrip(), "```", ""]
        if diff and not got.strip() == "":
            L += ["Khác biệt / kiểm tra:", "", "```", diff, "```", ""]
    try:
        sys.path.insert(0, str(FPGA.parent / "scripts"))
        from md_table import write_md  # noqa: E402
        write_md(out, "\n".join(L) + "\n")
    except Exception:
        out.write_text("\n".join(L) + "\n", encoding="utf-8")
    print(f"\nbáo cáo: {out}")


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="what", required=True)
    sub.add_parser("term")
    r = sub.add_parser("run")
    r.add_argument("-c", "--cmd", action="append", default=[])
    r.add_argument("--idle", type=float, default=1.5)
    r.add_argument("--timeout", type=float, default=30)
    r.add_argument("--no-reset", action="store_true")
    lo = sub.add_parser("load")
    lo.add_argument("name")
    t = sub.add_parser("test")
    t.add_argument("names", nargs="*")
    t.add_argument("--flash", action="store_true")
    t.add_argument("--keep", action="store_true")
    args = ap.parse_args()
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    qbin = quartus_bin()
    {"term": cmd_term, "run": cmd_run, "load": cmd_load, "test": cmd_test}[args.what](qbin, args)


if __name__ == "__main__":
    main()

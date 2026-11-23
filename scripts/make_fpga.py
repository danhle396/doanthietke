#!/usr/bin/env python3
"""Build the self-contained Quartus II project folder fpga/ for the DE2 board.

fpga/ can be copied alone to a Windows PC with Quartus II 13.0sp1:
  rtl/        copy of the RTL (rtl/mem/ram_bank16.sv replaced by board/ram_bank16_m4k.sv)
  board/      de2_top, PLL, M4K RAM wrapper (hand written, not touched here)
  mem/        bank0.mif / bank1.mif = firmware loaded at configuration time
  firmware/   every board firmware: <name>/bank0.mif, bank1.mif, <name>.elf,
              uart_sim.txt (UART output of the same binary in RTL simulation)
  de2_soc.qpf / .qsf (generated: file list + pins) / .sdc, chon_firmware.bat

Each firmware is built with console = de2 (scripts/build_sw.py: 24 MHz CPU,
115200 baud, 32 KB RAM) and simulated on tb_soc with the board RAM
configuration (RAM_SYNC = 1, 32 KB). The script fails if a simulation fails.

Usage: make_fpga.py [--no-sim] [--default board_demo]
"""
import argparse
import re
import shutil
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import BUILD, JOBS, ROOT, VERILATOR, build_soc, rtl_files, run, run_sim  # noqa: E402
from build_sw import KIND_DIR, build_program  # noqa: E402
from run_isa import CONFIGS  # noqa: E402
from md_table import write_md  # noqa: E402

FPGA = ROOT / "fpga"
SIM_CFG = CONFIGS["m1c1_bp2_sync"]
DEPTH = SIM_CFG["RAM_DEPTH"]          # 32-bit words = entries per 16-bit bank

# (name, kind, Vietnamese description, extra hardware needed)
FIRMWARE = [
    ("board_demo", "fpga", "Demo tương tác: LED theo công tắc (ngắt GPIO), đếm giây (ngắt timer), "
     "lệnh UART, đo hiệu năng bằng performance counter", "–"),
    ("hello", "tests", "In chuỗi chào qua UART", "–"),
    ("timer_irq", "tests", "8 ngắt timer định kỳ, kiểm tra khoảng cách", "–"),
    ("irq_priority", "tests", "Thứ tự ưu tiên MEI > MSI > MTI, mtvec direct/vectored", "–"),
    ("exceptions", "tests", "Illegal, ecall, ebreak, misaligned, access fault", "–"),
    ("irq_during_div", "tests", "Ngắt khi bộ chia đang chạy", "–"),
    ("muldiv_rand", "tests", "8 lệnh RV32M và phép chia 64 bit (libgcc) trên toán hạng biên + ngẫu nhiên, "
     "so với mô hình chỉ dùng cộng/dịch", "–"),
    ("branch_smc", "tests", "Trap sau nhánh đoán sai; self-modifying code + FENCE.I", "–"),
    ("spi_flash", "tests", "JEDEC ID, xóa sector, ghi/đọc page qua SPI", "module flash W25Qxx trên GPIO_0"),
    ("demo", "tests", "Đọc flash định kỳ theo ngắt timer + lệnh UART r/w/s/q", "module flash W25Qxx trên GPIO_0"),
    ("dhrystone", "bench", "Benchmark Dhrystone", "–"),
    ("coremark", "bench", "Benchmark CoreMark", "–"),
    ("median", "bench", "Benchmark median (riscv-tests)", "–"),
    ("multiply", "bench", "Benchmark multiply (riscv-tests)", "–"),
    ("qsort", "bench", "Benchmark qsort (riscv-tests)", "–"),
    ("towers", "bench", "Benchmark towers (riscv-tests)", "–"),
    ("vvadd", "bench", "Benchmark vvadd (riscv-tests)", "–"),
]
# Not on the board (need more than the 32 KB of on-chip RAM; they pass in simulation with 128 KB)
EXCLUDED = [("rsort", "29.6 KB dữ liệu + 8 KB stack"),
            ("memcpy", "mảng 16 KB trên stack + 16 KB dữ liệu vào"),
            ("gpio_irq", "cần loopback GPIO và kích thích của testbench"),
            ("spi_modes", "cần SPI slave echo (BFM)"),
            ("uart_irq_echo", "phần kiểm tra overrun cần BFM gửi dồn dập")]

# DE2 pin assignments (DE2 User Manual / DE2_pin_assignments.csv)
PINS = {
    "CLOCK_50": "N2",
    "UART_TXD": "B25", "UART_RXD": "C25",
}
_KEY = ["G26", "N23", "P23", "W26"]
_SW = ["N25", "N26", "P25", "AE14", "AF14", "AD13", "AC13", "C13", "B13", "A13",
       "N1", "P1", "P2", "T7", "U3", "U4", "V1", "V2"]
_LEDR = ["AE23", "AF23", "AB21", "AC22", "AD22", "AD23", "AD21", "AC21", "AA14",
         "Y13", "AA13", "AC14", "AD15", "AE15", "AF13", "AE13", "AE12", "AD12"]
_LEDG = ["AE22", "AF22", "W19", "V18", "U18", "U17", "AA20", "Y18", "Y12"]
_GPIO0 = ["D25", "J22", "E26", "E25", "F24", "F23", "J21"]
# 7-segment digits, segments [0..6] = a..g, active low (DE2 User Manual table 4.4)
_HEX = [["AF10", "AB12", "AC12", "AD11", "AE11", "V14", "V13"],
        ["V20", "V21", "W21", "Y22", "AA24", "AA23", "AB24"],
        ["AB23", "V22", "AC25", "AC26", "AB26", "AB25", "Y24"],
        ["Y23", "AA25", "AA26", "Y26", "Y25", "U22", "W24"],
        ["U9", "U1", "U2", "T4", "R7", "R6", "T3"],
        ["T2", "P6", "P7", "T9", "R5", "R4", "R3"],
        ["R2", "P4", "P3", "M2", "M3", "M5", "M4"],
        ["L3", "L2", "L9", "L6", "L7", "P9", "N9"]]
_GROUPS = [("KEY", _KEY), ("SW", _SW), ("LEDR", _LEDR), ("LEDG", _LEDG), ("GPIO_0", _GPIO0)]
_GROUPS += [(f"HEX{d}", segs) for d, segs in enumerate(_HEX)]
for name, lst in _GROUPS:
    for i, p in enumerate(lst):
        PINS[f"{name}[{i}]"] = p

BOARD_FILES = ["board/ram_bank16_m4k.sv", "board/pll_cpu.v", "board/jtag_uart_bridge.sv",
               "board/board_display.sv", "board/key_cmd.sv",
               "board/de2_top.sv"]


# --------------------------------------------------------------------------
def read_cfg(path):
    cfg = {}
    if path.exists():
        for line in path.read_text().splitlines():
            line = line.split("#", 1)[0].strip()
            if "=" in line:
                k, v = line.split("=", 1)
                cfg[k.strip()] = v.strip()
    return cfg


def write_mif(path, values, depth, width=16):
    """Quartus MIF; runs of zeros are written as ranges."""
    lines = [f"-- {path.name}: generated by scripts/make_fpga.py", f"WIDTH={width};",
             f"DEPTH={depth};", "ADDRESS_RADIX=HEX;", "DATA_RADIX=HEX;", "", "CONTENT BEGIN"]
    a = 0
    while a < depth:
        v = values[a] if a < len(values) else 0
        if v == 0:
            b = a
            while b + 1 < depth and (values[b + 1] if b + 1 < len(values) else 0) == 0:
                b += 1
            lines.append(f"\t[{a:X}..{b:X}] : 0000;" if b > a else f"\t{a:X} : 0000;")
            a = b + 1
        else:
            lines.append(f"\t{a:X} : {v:04X};")
            a += 1
    lines.append("END;")
    path.write_text("\n".join(lines) + "\n")


def hex_to_banks(hexfile):
    words = [int(l, 16) for l in hexfile.read_text().split()]
    if len(words) > DEPTH:
        raise SystemExit(f"{hexfile}: {len(words)} words > {DEPTH} (32 KB RAM)")
    return [w & 0xFFFF for w in words], [w >> 16 for w in words]


def build_one(entry):
    name, kind = entry[0], entry[1]
    elf = build_program(kind, KIND_DIR[kind] / name, "imc", "de2")
    out = FPGA / "firmware" / name
    out.mkdir(parents=True, exist_ok=True)
    b0, b1 = hex_to_banks(elf.with_suffix(".hex"))
    write_mif(out / "bank0.mif", b0, DEPTH)
    write_mif(out / "bank1.mif", b1, DEPTH)
    shutil.copy2(elf, out / f"{name}.elf")
    return name, elf, len(b0) * 4


def simulate(exe, entry, elf):
    name, kind = entry[0], entry[1]
    pdir = KIND_DIR[kind] / name
    out = FPGA / "firmware" / name
    log = BUILD / "logs" / "fpga" / f"{name}.sim.txt"
    uart = out / "uart_sim.txt"
    cfg = read_cfg(pdir / "test.cfg")
    args = [f"+uart_log={uart}", "+max_cycles=80000000"]
    if cfg.get("expect"):
        args.append(f"+uart_expect={pdir / cfg['expect']}")
    rx = pdir / cfg.get("rx_file", "rx.txt")
    if rx.exists():
        args += [f"+uart_rx_file={rx}", f"+uart_rx_mode={cfg.get('rx_mode', 'line')}"]
        shutil.copy2(rx, out / "rx_sim.txt")
    ok, text = run_sim(exe, elf.with_suffix(".hex"), args, log=log)
    return name, ok, text


def summary(kind, uart_text, has_expect):
    r = re.search(r"RESULT \S+: (PASS[^\n]*)", uart_text)
    if r and kind != "fpga":     # board_demo: report the benchmark (its self-test is checked too)
        return r.group(1)
    if kind == "tests":
        return "khớp expect.txt" if has_expect else ""
    m = list(re.finditer(r"\[bench\] name=\S+ cycles=(\d+) instret=(\d+) cpi_x1000=(\d+)", uart_text))
    if m:
        c, i, cpi = m[-1].groups()   # board_demo: run 2 (deterministic predictor state)
        return f"{c} chu kỳ, {i} lệnh, CPI {int(cpi) / 1000:.3f}"
    return ""


def bridge_sim():
    """Unit test of the JTAG console bridge (fpga/board/jtag_uart_bridge.sv)
    against a model of the host protocol of fpga/tools/jtag_uart.tcl."""
    out = BUILD / "verilator" / "tb_jtag_bridge"
    obj = out / "obj"
    if obj.exists():
        shutil.rmtree(obj)
    obj.mkdir(parents=True)
    run([VERILATOR, "--binary", "--timing", "-j", str(JOBS), "--top-module", "tb_jtag_bridge",
         "-Mdir", str(obj), "-o", "Vtb", "-O2", "-Wno-fatal", "-Wno-lint", "-Wno-style",
         "--timescale", "1ns/1ps", str(FPGA / "board/jtag_uart_bridge.sv"),
         str(ROOT / "tb/fpga/tb_jtag_bridge.sv")], log=out / "build.log")
    log = BUILD / "logs" / "fpga" / "tb_jtag_bridge.txt"
    res = run([str(obj / "Vtb")], log=log, check=False, timeout=600)
    ok = res.returncode == 0 and re.search(r"^PASS\s*$", res.stdout, re.M) is not None
    shutil.rmtree(obj)
    return ok, log


def board_top_sim():
    """Simulate fpga/board/de2_top (M4K wrapper, PLL, pins) with the megafunction
    stand-ins of tb/fpga/altera_stubs.sv; the RAM is loaded from fpga/mem/*.mif."""
    out = BUILD / "verilator" / "tb_de2"
    obj = out / "obj"
    if obj.exists():
        shutil.rmtree(obj)
    obj.mkdir(parents=True)
    srcs = [f for f in rtl_files() if not f.endswith("rtl/mem/ram_bank16.sv")]
    srcs += [str(FPGA / f) for f in BOARD_FILES]
    srcs += [str(ROOT / f) for f in ("tb/fpga/altera_stubs.sv", "tb/bfm/uart_bfm.sv",
                                     "tb/fpga/tb_de2.sv")]
    run([VERILATOR, "--binary", "--timing", "-j", str(JOBS), "--top-module", "tb_de2",
         "-Mdir", str(obj), "-o", "Vtb_de2", "-O2", "-Wno-fatal", "-Wno-lint", "-Wno-style",
         "--timescale", "1ns/1ps"] + srcs, log=out / "build.log")
    log = BUILD / "logs" / "fpga" / "tb_de2.txt"
    res = run([str(obj / "Vtb_de2"), f"+uart_log={BUILD / 'logs/fpga/tb_de2_uart.txt'}"],
              cwd=FPGA, log=log, check=False, timeout=1800)
    ok = res.returncode == 0 and re.search(r"^PASS\s*$", res.stdout, re.M) is not None
    shutil.rmtree(obj)
    return ok, log


def write_qsf(files):
    q = ["# de2_soc.qsf - Quartus II 13.0sp1 project for the DE2 board (Cyclone II EP2C35F672C6).",
         "# Generated by scripts/make_fpga.py: file list and pin assignments.",
         "",
         'set_global_assignment -name FAMILY "Cyclone II"',
         "set_global_assignment -name DEVICE EP2C35F672C6",
         "set_global_assignment -name TOP_LEVEL_ENTITY de2_top",
         'set_global_assignment -name ORIGINAL_QUARTUS_VERSION "13.0 SP1"',
         "set_global_assignment -name PROJECT_OUTPUT_DIRECTORY output_files",
         "set_global_assignment -name MIN_CORE_JUNCTION_TEMP 0",
         "set_global_assignment -name MAX_CORE_JUNCTION_TEMP 85",
         "set_global_assignment -name VERILOG_INPUT_VERSION SYSTEMVERILOG_2005",
         'set_global_assignment -name VERILOG_MACRO "SYNTHESIS=1"',
         'set_global_assignment -name RESERVE_ALL_UNUSED_PINS "AS INPUT TRI-STATED"',
         'set_global_assignment -name CYCLONEII_RESERVE_NCEO_AFTER_CONFIGURATION "USE AS REGULAR IO"',
         "set_global_assignment -name SDC_FILE de2_soc.sdc",
         ""]
    for f in files:
        kind = "VERILOG_FILE" if f.endswith(".v") else "SYSTEMVERILOG_FILE"
        q.append(f"set_global_assignment -name {kind} {f}")
    q += ["set_global_assignment -name MIF_FILE mem/bank0.mif",
          "set_global_assignment -name MIF_FILE mem/bank1.mif", ""]
    for port, pin in PINS.items():
        q.append(f"set_location_assignment PIN_{pin} -to {port}")
    q += ["", "set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to GPIO_0[2]",
          "set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to UART_RXD", "",
          # what Quartus 13.0sp1 itself appends on the first compile (kept so that
          # regenerating the file does not show up as a change after a compile)
          'set_global_assignment -name LAST_QUARTUS_VERSION "13.0 SP1"',
          'set_global_assignment -name RESERVE_ALL_UNUSED_PINS_NO_OUTPUT_GND "AS INPUT TRI-STATED"',
          "set_instance_assignment -name PARTITION_HIERARCHY root_partition -to | -section_id Top",
          "set_global_assignment -name PARTITION_NETLIST_TYPE SOURCE -section_id Top",
          "set_global_assignment -name PARTITION_FITTER_PRESERVATION_LEVEL PLACEMENT_AND_ROUTING "
          "-section_id Top",
          "set_global_assignment -name PARTITION_COLOR 16764057 -section_id Top"]
    (FPGA / "de2_soc.qsf").write_text("\n".join(q) + "\n")
    (FPGA / "de2_soc.qpf").write_text('QUARTUS_VERSION = "13.0"\nPROJECT_REVISION = "de2_soc"\n')


BAT = r"""@echo off
rem chon_firmware.bat <ten> : chon firmware nap vao RAM (copy firmware\<ten>\*.mif -> mem\)
cd /d "%~dp0"
if "%~1"=="" goto usage
if not exist "firmware\%~1\bank0.mif" goto notfound
copy /Y "firmware\%~1\bank0.mif" "mem\bank0.mif" >nul
copy /Y "firmware\%~1\bank1.mif" "mem\bank1.mif" >nul
echo Da chon firmware: %~1
echo Trong Quartus: Processing - Update Memory Initialization File,
echo roi Processing - Start - Start Assembler, sau do nap lai output_files\de2_soc.sof
goto :eof
:usage
echo Cach dung: chon_firmware.bat ^<ten^>   (vi du: chon_firmware.bat board_demo)
echo Cac firmware co san:
dir /b firmware
goto :eof
:notfound
echo Khong tim thay firmware\%~1
dir /b firmware
"""


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--no-sim", action="store_true")
    ap.add_argument("--default", default="board_demo")
    args = ap.parse_args()

    # 1. RTL copy
    dst = FPGA / "rtl"
    if dst.exists():
        shutil.rmtree(dst)
    files = []
    for f in rtl_files():
        rel = Path(f).relative_to(ROOT / "rtl")
        if rel.as_posix() == "mem/ram_bank16.sv":     # replaced by the M4K wrapper
            continue
        (dst / rel).parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(f, dst / rel)
        files.append(f"rtl/{rel.as_posix()}")
    write_qsf(files + BOARD_FILES)
    (FPGA / "chon_firmware.bat").write_bytes(BAT.replace("\n", "\r\n").encode("ascii"))

    # 2. firmware + MIF
    if (FPGA / "firmware").exists():
        shutil.rmtree(FPGA / "firmware")
    with ThreadPoolExecutor(max_workers=JOBS) as ex:
        built = list(ex.map(build_one, FIRMWARE))
    for name, _, nbytes in built:
        print(f"[fpga] firmware {name:15s} {nbytes:6d} byte")
    (FPGA / "mem").mkdir(exist_ok=True)
    for b in ("bank0.mif", "bank1.mif"):
        shutil.copy2(FPGA / "firmware" / args.default / b, FPGA / "mem" / b)

    # 3. simulation of every image on the board configuration
    results = {}
    if not args.no_sim:
        exe = build_soc(SIM_CFG)
        elfs = {n: e for n, e, _ in built}
        with ThreadPoolExecutor(max_workers=JOBS) as ex:
            for e, (name, ok, _) in zip(FIRMWARE, ex.map(lambda e: simulate(exe, e, elfs[e[0]]),
                                                         FIRMWARE)):
                uart = (FPGA / "firmware" / name / "uart_sim.txt").read_text(errors="replace")
                has_expect = bool(read_cfg(KIND_DIR[e[1]] / name / "test.cfg").get("expect"))
                results[name] = (ok, summary(e[1], uart, has_expect))
                print(f"[fpga] sim {name:15s} {'PASS' if ok else 'FAIL'}  {results[name][1]}")

    # 4. firmware list
    rows = ["# Firmware cho board DE2", "",
            "Sinh bởi `scripts/make_fpga.py`. CPU 24 MHz, UART 115200 8N1, RAM 32 KB.",
            "Chọn firmware: `chon_firmware.bat <tên>` rồi Update Memory Initialization File → "
            "Assembler → nạp lại (xem `README.md`).",
            "`uart_sim.txt`: đầu ra UART của **cùng file nhị phân** khi mô phỏng RTL (cấu hình RAM "
            "của board); trên board phải thấy nội dung tương tự (số chu kỳ trùng khớp).", "",
            "| Firmware | Nội dung | Cần thêm | Mô phỏng | Kết quả mô phỏng |", "|---|---|---|---|---|"]
    for name, kind, desc, hw in FIRMWARE:
        ok, summ = results.get(name, (None, ""))
        st = "–" if ok is None else ("PASS" if ok else "FAIL")
        rows.append(f"| `{name}` | {desc} | {hw} | {st} | {summ} |")
    rows += ["", f"Mặc định trong `mem/`: `{args.default}`.", "",
             "Không đưa lên board: " + "; ".join(f"`{n}` ({why})" for n, why in EXCLUDED) + "."]
    write_md(FPGA / "firmware" / "DANH_SACH.md", "\n".join(rows) + "\n")

    # 5. JTAG console bridge, then the board top level with the megafunction
    #    stand-ins (default firmware)
    if not args.no_sim:
        ok, log = bridge_sim()
        print(f"[fpga] jtag_uart_bridge (host protocol model) {'PASS' if ok else 'FAIL'}  log: "
              f"{log.relative_to(ROOT)}")
        if not ok:
            results["jtag_uart_bridge"] = (False, "")
    if not args.no_sim and args.default == "board_demo":
        ok, log = board_top_sim()
        print(f"[fpga] de2_top (stubs, mem/*.mif) {'PASS' if ok else 'FAIL'}  log: "
              f"{log.relative_to(ROOT)}")
        if not ok:
            results["de2_top"] = (False, "")

    bad = [n for n, (ok, _) in results.items() if not ok]
    if bad:
        raise SystemExit(f"[fpga] simulation FAILED: {', '.join(bad)}")
    print(f"[fpga] {FPGA.relative_to(ROOT)}/ ready")


if __name__ == "__main__":
    main()

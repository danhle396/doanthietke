#!/usr/bin/env python3
"""Assemble docs/results.md from the generated result files, so every number
in it comes from results/ (no manual copying).

Usage: make_results_md.py
"""
import re
from pathlib import Path
from md_table import write_md  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
R = ROOT / "results"


def shots(path):
    """Terminal screenshots (scripts/capture_results.py) of the run that produced `path`,
    unless the summary already links them."""
    d = (R / path).parent
    text = (R / path).read_text() if (R / path).exists() else ""
    out = []
    for png in sorted(d.glob("terminal_*.png")):
        if png.name in text:
            continue
        rel = Path("../results") / png.relative_to(R)
        out += [f"![Ảnh chụp terminal: `{png.stem[len('terminal_'):]}`]({rel.as_posix()})", ""]
    return out


def section(path, title, fix_links=True):
    p = R / path
    if not p.exists():
        return [f"## {title}", "", f"(chưa có `{path}`)", ""]
    text = p.read_text()
    text = re.sub(r"^# .*\n", "", text, count=1)              # drop own title
    text = re.sub(r"^(#+) ", lambda m: "#" + m.group(1) + " ", text, flags=re.M)  # demote
    if fix_links:  # image links relative to docs/
        base = (Path("../results") / path).parent
        text = re.sub(r"!\[([^\]]*)\]\(([^)/]+\.png)\)", lambda m: f"![{m.group(1)}]({base}/{m.group(2)})", text)
    return [f"## {title}", "", f"Nguồn: `results/{path}`.", "", text.strip(), ""] + \
        (shots(path) if path.endswith("summary.md") or path == "regress.md" else [])


def main():
    out = ["# Kết quả", "",
           "Tài liệu này được ghép tự động từ các file trong `results/` bằng `scripts/make_results_md.py`; mọi "
           "số liệu là số đo thật từ các lần chạy gần nhất. Lệnh tái tạo ghi trong từng mục và trong "
           "`docs/giai_thich/huong_dan_chay.md`.", ""]
    out += section("regress.md", "1. Regression tổng")
    out += section("unit/summary.md", "2. Unit testbench")
    out += section("isa/summary.md", "3. riscv-tests – ma trận cấu hình")
    out += ["Ghi chú loại trừ: `rv32ui-p-ma_data` được phép loại trừ theo spec (lõi trap khi truy cập không căn lề, "
            "hành vi trap được kiểm bởi `rv32mi-p-ma_addr` và `*-misaligned`); `rv32mi-p-breakpoint` và "
            "`rv32mi-p-pmpaddr` phụ thuộc debug trigger / PMP mà lõi không có – dòng nguồn phụ thuộc được ghi ở trên.", ""]
    out += section("spike/summary.md", "4. So sánh với Spike")
    out += ["Mức so sánh: `--log-commits` (PC, mã lệnh, thanh ghi đích + giá trị, địa chỉ + dữ liệu store), so khớp "
            "từng lệnh bằng regex (`scripts/compare_spike.py`). Khác biệt đã biết và được liệt kê (không che giấu): "
            "giá trị đọc `marchid` (RTL 0, Spike 5); `misa` ghi được trong Spike (test `rv32mi-p-ma_fetch` xóa bit C "
            "rồi rẽ nhánh khác – kết quả KNOWN); các giá trị đọc từ `cycle/mcycle/instret/minstret/time/mhpmcounter*` "
            "phụ thuộc thời gian, được theo dõi taint qua thanh ghi và bộ nhớ (decision D19). Truy cập không căn lề: "
            "cả RTL và Spike đều trap nên không phát sinh khác biệt. Chi tiết từng chương trình: "
            "`results/spike/<cấu hình>.md`.", ""]
    out += section("cosim/summary.md", "5. Co-simulation C++ lock-step với Spike")
    out += ["Harness Verilator C++ `cosim/cosim_main.cpp` chạy `soc_top` và Spike (tiến trình con) cùng lúc; mỗi lệnh "
            "RTL retire (DPI `cosim_commit` ở WB) được so ngay với lệnh Spike commit kế tiếp, lệch là dừng. Kiểm tra "
            "chính harness: RTL có lỗi SLTU cài sẵn (`-DCOSIM_MUTANT`) bị phát hiện tại lệnh sai đầu tiên "
            "(`results/cosim/mutant.md`). Hình lock-step: `results/cosim/lockstep.png`.", ""]
    out += section("systest/summary.md", "6. System test")
    out += section("perf/summary.md", "7. Hiệu năng")
    out += section("perf/throughput.md", "8. Thông lượng")
    out += section("synth/summary.md", "9. Tổng hợp")
    out += section("asic/summary.md", "10. Layout ASIC (OpenLane 2 / sky130A)")
    out += section("coverage/summary.md", "11. Coverage")
    out += section("coverage/functional.md", "12. Functional coverage")
    out += ["## 13. Hình waveform", "",
            "Ảnh chụp cửa sổ GTKWave mở VCD của mô phỏng RTL, khung thời gian và marker do "
            "`scripts/make_waves.py` chọn (thư mục `results/waves/`): "
            "`load_use_forwarding.png`, `compressed.png`, `mispredict_flush.png`, `trap_entry_exit.png`, "
            "`apb_transaction.png` (Wishbone → APB4), `uart_frame.png`, `spi_mode0.png`, `spi_mode3.png`, "
            "`walkthrough_pipeline.png`; lock-step RTL/Spike: `results/cosim/lockstep.png`; "
            "bảng pipeline theo chu kỳ: `results/waves/walkthrough_table.md`.", ""]
    for name in ("waves/apb_transaction.png", "waves/load_use_forwarding.png",
                 "waves/mispredict_flush.png", "waves/trap_entry_exit.png"):
        if (R / name).exists():
            out += [f"![`{name}`](../results/{name})", ""]
    if (R / "fpga").exists():
        out += ["## 14. Board DE2 (FPGA)", "",
                "Ảnh chụp terminal `make fpga` (mô phỏng 16 firmware với cấu hình của board) và ảnh Quartus II "
                "(thư mục `results/fpga/`); ảnh board thật: `results/board/`; log chạy trên board: "
                "`fpga/board_results.md`.", ""]
        for png in sorted((R / "fpga").glob("*.png")):
            out += [f"![`{png.name}`](../results/fpga/{png.name})", ""]
        for img in sorted((R / "board").glob("*.jpg")) if (R / "board").exists() else []:
            out += [f"![`{img.name}`](../results/board/{img.name})", ""]
    write_md(ROOT / "docs/results.md", "\n".join(out))
    print("[results] docs/results.md written")


if __name__ == "__main__":
    main()

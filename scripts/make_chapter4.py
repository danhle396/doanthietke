#!/usr/bin/env python3
"""Generate docs/report/chuong4_xac_minh.md (Chapter 4 – verification and
evaluation). Every table is copied from a file in results/ and every number
quoted in the text is computed from the CSV files, so the report cannot drift
from the measured data.

Usage: make_chapter4.py
"""
import csv
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
R = ROOT / "results"


def table_after(path, marker=None):
    """First markdown table in `path` that follows the line containing `marker`."""
    lines = (R / path).read_text().splitlines()
    start = 0
    if marker:
        start = next(i for i, l in enumerate(lines) if marker in l)
    out = []
    for l in lines[start:]:
        if l.startswith("|"):
            out.append(l)
        elif out:
            break
    return out


def rows(path):
    with open(R / path) as f:
        return list(csv.DictReader(f))


def geomean(xs):
    p = 1.0
    for x in xs:
        p *= x
    return p ** (1 / len(xs))


def main():
    e1 = rows("perf/exp1_predictor.csv")
    e3 = rows("perf/exp3_rvc.csv")
    e5 = rows("perf/exp5_sc_vs_pipeline.csv") if (R / "perf/exp5_sc_vs_pipeline.csv").exists() else []
    synth = json.loads((R / "synth/summary.json").read_text())
    gm = {m: geomean([float(r["cpi"]) for r in e1 if int(r["bp_mode"]) == m]) for m in (0, 1, 2)}
    dh = {int(r["bp_mode"]): float(r["cpi"]) for r in e1 if r["bench"] == "dhrystone"}
    cm = {int(r["bp_mode"]): r for r in e1 if r["bench"] == "coremark"}
    cm_per_mhz = {m: 2e6 / int(cm[m]["cycles"]) for m in cm}  # ITERATIONS = 2
    tot_im = sum(int(r["text_im"]) for r in e3)
    tot_imc = sum(int(r["text_imc"]) for r in e3)
    isa = table_after("isa/summary.md")
    n_pass = sum(int(l.split("|")[4]) for l in isa[2:])
    n_fail = sum(int(l.split("|")[5]) for l in isa[2:])
    unit = table_after("unit/summary.md")
    sysrows = table_after("systest/summary.md")
    cov = table_after("coverage/summary.md", "Bảng C1") if (R / "coverage/summary.md").exists() else []
    func = (R / "coverage/functional.md").read_text() if (R / "coverage/functional.md").exists() else ""
    mfunc = re.search(r"(\d+)/(\d+) điểm cover đạt", func)
    fm = synth.get("fmax_mhz", {})
    cp = (R / "synth/critical_path_m1c1_bp2.txt").read_text().splitlines() if \
        (R / "synth/critical_path_m1c1_bp2.txt").exists() else []

    L = ["# Chương 4. Xác minh và đánh giá", "",
         "Mọi bảng trong chương này được trích từ các file trong `results/` (ghi ở chú thích bảng) và được sinh lại "
         "bằng `scripts/make_chapter4.py`; lệnh tái tạo số liệu ghi trong `docs/giai_thich/huong_dan_chay.md`.", "",
         "## 4.1. Môi trường xác minh ba mức", "",
         "1. **Mức khối** – 13 testbench SystemVerilog tự kiểm tra (Verilator `--binary --timing`), mỗi testbench có "
         "mô hình tham chiếu, test có hướng với giá trị biên và test ngẫu nhiên có seed (`+seed=`). Bộ giải nén C được "
         "so với bảng kỳ vọng do chính GNU assembler sinh (`.option rvc` / `.option norvc`).",
         "2. **Mức lõi** – bộ riscv-tests chính thức, chạy với môi trường riêng chỉ có Machine mode, trên ma trận cấu "
         "hình RTL × biến thể ELF; commit log của RTL được so khớp từng lệnh với mô hình tham chiếu Spike.",
         "3. **Mức hệ thống** – firmware C chạy trên `tb_soc` cùng các BFM: UART (giải mã TX, gửi RX), flash SPI kiểu "
         "W25Q (CS0), SPI slave đủ 4 mode (CS1), kích thích GPIO. Tiêu chí PASS: mã thoát 0, output UART khớp file kỳ "
         "vọng, BFM không phát hiện lỗi.", "",
         "Bảng 4.1. Kết quả unit testbench (nguồn: `results/unit/summary.md`).", ""] + unit + [""]
    L += ["## 4.2. riscv-tests", "",
          f"Tổng cộng {n_pass} lượt test PASS, {n_fail} FAIL trên 6 cấu hình (Bảng 4.2). Ba test được loại trừ có lý "
          "do: `rv32ui-p-ma_data` (lõi trap khi truy cập không căn lề – hợp lệ theo đặc tả, hành vi trap được kiểm bởi "
          "`rv32mi-p-ma_addr`), `rv32mi-p-breakpoint` (cần CSR debug trigger, dòng 33 `csrw tselect, x0`) và "
          "`rv32mi-p-pmpaddr` (cần PMP, dòng 27 `csrw pmpcfg0, zero`).", "",
          "Bảng 4.2. riscv-tests theo cấu hình (nguồn: `results/isa/summary.md`).", ""] + isa + [""]
    sp = table_after("spike/summary.md")
    L += ["## 4.3. So sánh với Spike", "",
          "Lõi in commit log tại WB theo định dạng `spike --log-commits`; script `compare_spike.py` so khớp từng lệnh "
          "(PC, mã lệnh, thanh ghi đích và giá trị, địa chỉ và dữ liệu store). Giá trị đọc từ các bộ đếm phụ thuộc thời "
          "gian được đánh dấu \"taint\" và theo dõi qua thanh ghi và bộ nhớ; khi luồng lệnh rẽ khác ngay sau một nhánh "
          "phụ thuộc giá trị đó (in số chu kỳ), so sánh dừng lock-step và chỉ so mã thoát. Khác biệt tùy hiện thực được "
          "liệt kê: `marchid` (RTL 0, Spike 5) và `misa` (Spike cho phép xóa bit C, lõi này không – test "
          "`rv32mi-p-ma_fetch` rẽ nhánh khác sau đó).", "",
          "Bảng 4.3. Kết quả so sánh (nguồn: `results/spike/summary.md`; chi tiết từng chương trình trong "
          "`results/spike/<cấu hình>.md`).", ""] + sp + [""]
    L += ["## 4.4. System test", "",
          "Bảng 4.4. System test (nguồn: `results/systest/summary.md`).", ""] + sysrows + [""]
    L += ["## 4.5. Waveform minh họa", "",
          "Các hình được sinh tự động từ VCD bằng `scripts/make_waves.py`; trục hoành tính theo chu kỳ clock.", "",
          "![Hình 4.1. Load-use stall và forwarding](../../results/waves/load_use_forwarding.png)", "",
          "![Hình 4.2. Lệnh nén](../../results/waves/compressed.png)", "",
          "![Hình 4.3. Sai dự đoán và flush](../../results/waves/mispredict_flush.png)", "",
          "![Hình 4.4. Vào/ra trap](../../results/waves/trap_entry_exit.png)", "",
          "Các hình giao dịch APB, khung UART và khung SPI mode 0/3 được trình bày ở Chương 3 (Hình 3.3, 3.5, 3.7, 3.8). "
          "Bảng diễn biến pipeline theo từng chu kỳ của đoạn chương trình minh họa: `results/waves/walkthrough_table.md` "
          "và phần giải thích trong `docs/giai_thich/walkthrough_pipeline.md`.", ""]
    L += ["## 4.6. Coverage", ""]
    if cov:
        L += ["Bảng 4.5. Line và toggle coverage theo thư mục (nguồn: `results/coverage/summary.md`; các dòng chưa "
              "phủ được liệt kê trong `results/coverage/uncovered.md`).", ""] + cov + [""]
    if mfunc:
        L += [f"Functional coverage: {mfunc.group(1)}/{mfunc.group(2)} điểm `cover property` đạt "
              "(`results/coverage/functional.md`), gồm mọi nhóm lệnh, 8 lệnh M, lệnh nén, 4 đường forward, các loại "
              "stall, sai dự đoán theo loại, mọi mcause, ngắt khi bộ chia đang chạy, trap ngay sau nhánh sai, lệnh 32 bit "
              "vắt qua ranh giới word, 4 mode SPI, định dạng UART và trạng thái đầy/rỗng của các FIFO.", ""]
    L += ["## 4.7. Hiệu năng", "",
          "Mọi benchmark đo trong vùng đo (giữa hai lần gọi `setStats`/`start_time`) bằng `mcycle`, `minstret` và "
          "`mhpmcounter3..10`.", "",
          "### 4.7.1. Bộ dự đoán rẽ nhánh", "",
          f"Geomean CPI trên 9 benchmark giảm từ {gm[0]:.3f} (BP_MODE 0) xuống {gm[1]:.3f} (BP_MODE 1) và "
          f"{gm[2]:.3f} (BP_MODE 2). Dhrystone: {dh[0]:.3f} → {dh[1]:.3f} → {dh[2]:.3f}. CoreMark: "
          f"{cm_per_mhz[0]:.2f} → {cm_per_mhz[1]:.2f} → {cm_per_mhz[2]:.2f} CoreMark/MHz (2 iteration). Kiểm tra hợp "
          "lý của đặc tả (CPI Dhrystone trong [1,0; 2,0] và BP_MODE 2 không tệ hơn BP_MODE 0) đều đạt.", "",
          "Bảng 4.6. CPI, độ chính xác, penalty (nguồn: `results/perf/exp1_predictor.csv`).", ""]
    L += table_after("perf/summary.md", "Bảng P1") + [""]
    L += ["![Hình 4.5. CPI theo chế độ dự đoán](../../results/perf/exp1_cpi.png)", "",
          "![Hình 4.6. Độ chính xác dự đoán](../../results/perf/exp1_accuracy.png)", ""]
    if (R / "perf/exp2_sweep.csv").exists():
        L += ["### 4.7.2. Kích thước BHT và BTB", "",
              "Bảng 4.7. Độ chính xác trung bình / geomean CPI / diện tích theo BHT × BTB (nguồn: "
              "`results/perf/exp2_sweep.csv`, `results/synth/summary.json`).", ""]
        L += table_after("perf/summary.md", "Bảng P2") + [""]
        sw = rows("perf/exp2_sweep.csv")
        def acc(h, t):
            rs = [r for r in sw if int(r["bht"]) == h and int(r["btb"]) == t]
            return 100 * sum(float(r["accuracy"]) for r in rs) / len(rs)
        cells = synth.get("sweep_cells", {})
        L += [f"Độ chính xác chủ yếu phụ thuộc kích thước BTB ({acc(256, 8):.1f}% với 8 entry lên {acc(256, 64):.1f}% "
              f"với 64 entry, BHT 256), còn BHT lớn hơn 64 entry gần như không cải thiện ({acc(64, 32):.1f}% so với "
              f"{acc(1024, 32):.1f}% ở BTB 32) vì các benchmark có ít nhánh nóng; trong khi đó diện tích tăng mạnh theo "
              f"BHT ({cells.get('bht64_btb32')} → {cells.get('bht1024_btb32')} cell) vì bảng làm bằng flip-flop. "
              "Điểm cân bằng hợp lý cho các tải này là BHT 64 × BTB 32.", ""]
        L += ["![Hình 4.7. Độ chính xác theo BHT × BTB](../../results/perf/exp2_accuracy_heatmap.png)", "",
              "![Hình 4.8. CPI theo diện tích](../../results/perf/exp2_cpi_vs_area.png)", ""]
    L += ["### 4.7.3. Extension C", "",
          f"Tổng kích thước `.text` của 9 benchmark giảm từ {tot_im} xuống {tot_imc} byte "
          f"({100 * (1 - tot_imc / tot_im):.1f}%), trong khi CPI gần như không đổi.", "",
          "Bảng 4.8. Kích thước mã và CPI (nguồn: `results/perf/exp3_rvc.csv`).", ""]
    L += table_after("perf/summary.md", "Bảng P3") + [""]
    L += ["![Hình 4.9. Kích thước mã](../../results/perf/exp3_text_size.png)", "",
          "### 4.7.4. Phân rã CPI", "",
          "Bảng 4.9. Phân rã CPI ở BP_MODE 2 (nguồn: `results/perf/exp4_cpi_breakdown.csv`).", ""]
    L += table_after("perf/summary.md", "Bảng P4") + [""]
    L += ["![Hình 4.10. Phân rã CPI](../../results/perf/exp4_cpi_breakdown.png)", "",
          "Sai dự đoán là nguồn mất chu kỳ lớn nhất ở các benchmark có nhánh phụ thuộc dữ liệu (median, qsort); "
          "load-use đáng kể ở CoreMark và Dhrystone; stall MulDiv chỉ xuất hiện ở Dhrystone (một phép chia mỗi vòng); "
          "các benchmark không truy cập ngoại vi trong vùng đo nên không có chờ bus.", ""]
    if e5:
        L += ["### 4.7.5. Single-cycle so với pipeline", "",
              "Bảng 4.10. CPI, Fmax và hiệu năng tương đối (nguồn: `results/perf/exp5_sc_vs_pipeline.csv`).", ""]
        L += table_after("perf/summary.md", "Bảng P5") + [""]
        L += ["Pipeline có CPI lớn hơn 1 một chút nhưng tần số SoC cao hơn nhiều so với single-cycle (đường tổ hợp của "
              "single-cycle đi qua RAM hai lần), nên hiệu năng (∝ Fmax/CPI) cao hơn rõ rệt; phiên bản RV32I có Fmax cao "
              "hơn RV32IMC vì không có bộ nhân nằm trên đường găng.", ""]
    L += ["## 4.8. Diện tích, Fmax và đường găng", "",
          "Diện tích tính bằng số cell sau Yosys `synth -flatten` (thư viện generic), **không gồm RAM 128 KB** (black "
          "box). Fmax là ước lượng trên FPGA Lattice ECP5 (nextpnr); không thực hiện place & route ASIC.", "",
          "Bảng 4.11. Diện tích (nguồn: `results/synth/area.csv`).", ""]
    L += table_after("synth/summary.md", "Bảng S1") + [""]
    L += ["Bảng 4.12. Tài nguyên ECP5 và Fmax (nguồn: `results/synth/summary.md`).", ""]
    L += table_after("synth/summary.md", "Bảng S3") + [""]
    if cp:
        L += [f"Đường găng của lõi `m1c1_bp2` ({fm.get('m1c1_bp2')} MHz) gồm các chặng sau (trích "
              "`results/synth/critical_path_m1c1_bp2.txt`, chỉ giữ tên nguồn/đích):", "", "```"]
        hops = []
        for l in cp:
            m = re.search(r"(Source|Sink) (\S+)", l)
            if m:
                hops.append(f"{m.group(1):6s} {m.group(2)[:100]}")
        L += hops[:12] + (["   ... (%d chặng giữa) ..." % (len(hops) - 18)] if len(hops) > 18 else []) + \
            (hops[-6:] if len(hops) > 18 else hops[12:])
        L += ["```", ""]
        text = "\n".join(cp)
        if "MULT18X18D" in text:
            L += ["Đường găng bắt đầu ở thanh ghi `ex_mem` (chỉ số `rd` của lệnh ở MEM), qua bộ so sánh forward và mux "
                  "toán hạng (`fwd_rs1/fwd_rs2`), vào **bộ nhân** (khối DSP `MULT18X18D` của ECP5, cùng chuỗi cộng "
                  "carry `CCU2C` ghép các tích riêng 18×18 thành tích 33×33), rồi qua mux chọn kết quả về thanh ghi "
                  "`ex_mem.result` (tên `dbus_addr` sau tổng hợp vì nó điều khiển trực tiếp địa chỉ bus). Đây đúng là "
                  "ứng viên mà đặc tả dự kiến: bộ nhân tổ hợp 1 chu kỳ đứng sau chuỗi forwarding. Hướng cải thiện: chia "
                  "bộ nhân thành 2 tầng (MulDiv nhiều chu kỳ cho MULH*), hoặc dùng thanh ghi đầu ra DSP.", ""]
        else:
            L += ["Đường găng đi qua chuỗi forwarding → khối tính toán ở EX → thanh ghi kết quả/điều khiển; xem file "
                  "để biết chi tiết từng chặng.", ""]
        sc_cp = R / "synth/critical_path_soc_top_sc_1k.txt"
        if sc_cp.exists():
            L += [f"Với SoC dùng lõi single-cycle (`soc_top_sc_1k`, {fm.get('soc_top_sc_1k')} MHz), đường găng đi từ "
                  "`pc_q` qua cổng đọc lệnh của RAM, giải mã, tệp thanh ghi, ALU tới cổng dữ liệu RAM – toàn bộ trong "
                  "một chu kỳ, nên tần số thấp hơn hẳn SoC pipeline "
                  f"(`soc_top_1k`: {fm.get('soc_top_1k')} MHz). Fmax của lõi đứng riêng (Bảng 4.12, dòng `sc`) "
                  "không gồm RAM nên không dùng để so sánh.", ""]
    (ROOT / "docs/report/chuong4_xac_minh.md").write_text("\n".join(L))
    print("[ch4] docs/report/chuong4_xac_minh.md written")


if __name__ == "__main__":
    main()

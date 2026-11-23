# PROGRESS

## Phase hiện tại

Hoàn thành – Phase 0–8 xong, nghiệm thu mục 17 đạt

## Checklist từng Phase

### Phase 0 – Môi trường, khung project
- [x] Dò môi trường (Verilator, Yosys, GCC, nextpnr, OpenSTA)
- [x] Cài dtc vào `~/tools/dtc`
- [x] Build Spike vào `~/tools/spike` (commit 436fc16)
- [x] `git init`, `.gitignore`, `CLAUDE.md`, `PROGRESS.md`
- [x] Khung thư mục (mục 14)
- [x] `.venv` với matplotlib, pyelftools
- [x] `scripts/fetch_third_party.sh` (riscv-tests, coremark)
- [x] `scripts/elf2hex.py`
- [x] `Makefile` (check-env, ...)
- [x] `docs/env.md`, `docs/spec.md`, `docs/memory_map.md`, `docs/register_map.md`
- [x] Commit phase0

### Phase 1 – Core single-cycle + SoC tối thiểu
- [x] rv_pkg, decoder, imm_gen, alu, regfile, csr_file tối thiểu
- [x] rv_core_sc
- [x] ram_dp, dbus_xbar, apb_bridge, sim_ctrl, rst_sync, soc_top
- [x] tb_soc
- [x] env riscv-tests, run_isa.py
- [x] compare_spike.py
- [x] C hello qua SIM_CTRL
- [x] Yosys đọc được RTL

### Phase 2 – Pipeline RV32I
- [x] Pipeline 5 tầng, forwarding, hazard, BP_MODE=0
- [x] rv32ui pass, khớp Spike
- [x] tb_regfile, tb_alu
- [x] lint sạch

### Phase 3 – M và C
- [x] muldiv, compressed_decoder
- [x] rv32um, rv32uc, ma trận ENABLE_M/ENABLE_C
- [x] tb_muldiv, tb_compressed_decoder

### Phase 4 – Predictor & perf counter
- [x] BHT, BTB, BP_MODE 1/2, perf counter
- [x] Dhrystone
- [x] tb_bp

### Phase 5 – CSR đầy đủ, trap/ngắt, bus hoàn chỉnh
- [x] rv32mi
- [x] tb_csr, tb_apb_bridge, tb_intc

### Phase 6 – Ngoại vi
- [x] sync_fifo, UART, SPI, TIMER64, GPIO, BFM
- [x] unit TB ngoại vi pass

### Phase 7 – SoC, firmware, perf, coverage, synth
- [x] system tests (mục 10.4): 10/10 + branch_smc PASS (exceptions, irq_priority, timer_irq, branch_smc chạy cả trên sc)
- [x] benchmark (8 riscv-tests + CoreMark), run_perf.py: 5 thí nghiệm, kiểm tra hợp lý ĐẠT
- [x] coverage: line rtl/core 99.8%, rtl/periph 97.5%, functional 71/71
- [x] synth: generic (32 cấu hình) + ECP5 (lõi và SoC RAM 1 KB)
- [x] docs/results.md (ghép tự động từ results/)

### Phase 8 – Tài liệu
- [x] docs/giai_thich/
- [x] docs/report/
- [x] docs/compliance.md
- [x] Nghiệm thu mục 17 (clone sạch `make fetch regress` PASS)
- [x] Commit final

### Bổ sung sau nghiệm thu (yêu cầu đề cương)
- [x] Sơ đồ draw.io: `docs/diagrams/so_do_khoi.drawio` (7 trang: SoC, pipeline, dự đoán rẽ nhánh, UART/SPI, board DE2, quy trình thiết kế, luồng xác minh), sinh cùng ảnh PNG bằng `scripts/draw_simple_diagrams.py`; hình matplotlib/Mermaid/WaveDrom cũ nằm ở `docs/report/hinh/`
- [x] RAM đồng bộ cho FPGA (`RAM_SYNC`, D27) – số chu kỳ trùng khớp
- [x] Thư mục `fpga/` cho board DE2 (Quartus II 13.0sp1, PLL 24 MHz, 16 firmware `.mif`, `make fpga`)
- [x] Bus Wishbone B4 classic (D28), `wb_checker`, `tb_dbus_xbar` – số chu kỳ trùng khớp
- [x] Compile Quartus II 13.0sp1 (12/11/2026): 10 767 LE (32 %), 262 656 bit nhớ, Fmax 36,02 MHz > 24 MHz, setup slack +7,218 ns (sửa RTL: bọc `generate`/`endgenerate`, `genvar` khai báo riêng cho Quartus 13)
- [x] Chạy trên board DE2 (17/11/2026): console UART qua cáp USB-Blaster (`jtag_uart_bridge`, `fpga/tools/jtag_uart.py`), màn hình 7 đoạn + LED (`board_display`), phím KEY1–3 (`key_cmd`), lệnh tự kiểm tra `t`; video demo; phát hiện và sửa lỗi Quartus tổng hợp sai `MULH*` (`muldiv.sv`), thêm test `muldiv_rand`
- [x] Log chạy 15 firmware trên board (17/11/2026, `fpga/board_results.md`): 15/15 ĐẠT, số chu kỳ trùng mô phỏng
- [ ] Công suất (Quartus PowerPlay, ước lượng) – tùy chọn
- [x] `results/` chỉ gồm ảnh chụp thật (22/11/2026): sóng = ảnh GTKWave, layout = ảnh KLayout, terminal của từng bước (`scripts/capture_results.py`), Quartus GUI, ảnh board; bỏ biểu đồ matplotlib
- [x] Co-simulation C++ lock-step với Spike (`make cosim`, D29), RTL có lỗi cài sẵn bị bắt, hình lock-step
- [x] Bảng thông lượng (`scripts/throughput.py`)
- [x] Layout ASIC hai lõi bằng OpenLane 2 / sky130A (`make asic`, D30): DRC/LVS/XOR sạch, Fmax 3 góc PVT, gate-level netlist sau đi dây ≡ RTL

## Kết quả regression gần nhất

- 22/11/2026 Chạy lại toàn bộ để chụp kết quả thật: `make regress` PASS (isa 7 cấu hình 0 FAIL, Spike 73/73, 72/72, 64/64, 50/50 MATCH, systest gồm `muldiv_rand` PASS); coverage line core 99,8 %, periph 97,5 %, functional 71/71; `make synth`: Fmax SoC pipeline 43,73 MHz (trước 44,07, do sửa bộ nhân và cổng quan sát `soc_top`); `make cosim` 4 cấu hình MATCH; `make asic` (OpenLane chạy lại): `rv_core` 0,935 mm², 62 890 cell, Fmax 67,7 / 34,6 / 87,0 MHz (TT/SS/FF), DRC/LVS/XOR 0, 33 net antenna; `rv_core_sc` 0,284 mm², 10 net antenna; gate-level ≡ RTL 64/64 và 41/41.
- 17/11/2026 Board DE2: Quartus 12 228 LE (37 %), Fmax 35,5 MHz, slack +6,75 ns; trên board 13/15 firmware ĐẠT ngay, 2 (`branch_smc`, `qsort`) ĐẠT sau khi công cụ đọc lần chạy đầu (reset không nạp lại RAM); `board_demo` run 2 trùng mô phỏng.
- 28/10/2026 Layout ASIC (`make asic`, cấu hình 4 trong D30): `rv_core` die 0,94 mm², 62 600 cell, Fmax 66,0 / 34,5 / 87,4 MHz (TT/SS/FF), DRC 0, LVS 0, XOR 0, 26 net antenna; `rv_core_sc` 0,28 mm², 8 net antenna; gate-level ≡ RTL 64/64 và 41/41 riscv-tests.
- 27/10/2026 Bus Wishbone + RAM đồng bộ: `make regress` PASS (lint 9 cấu hình; unit 14/14; isa 415 PASS / 0 FAIL trên 7 cấu hình; Spike 259/259 MATCH; systest PASS; 0 vi phạm Wishbone); 9 benchmark trùng khớp số chu kỳ trước/sau; `make fpga`: 16/16 firmware + `de2_top` PASS trong mô phỏng.
- 26/10/2026 Nghiệm thu: `git clone . /tmp/check && make fetch regress` → PASS (lint; unit 13/13; isa 351 PASS / 0 FAIL / 16 EXCLUDED có lý do; Spike 259/259 MATCH, khác biệt KNOWN: marchid, misa; systest 15 lượt PASS).
- 22/10/2026 Phase 7: `make regress` PASS (lint, unit 13/13, isa 351 PASS/0 FAIL, Spike 259/259 MATCH, systest 15 lượt PASS); coverage line core 99.8%, periph 97.5%, functional 71/71; perf: geomean CPI 1.320/1.223/1.097 (BP0/1/2); Fmax SoC pipeline 42.3 MHz, SoC single-cycle 25.6 MHz.
- 22/10/2026 Phase 1: `run_isa.py --config sc` rv32ui 41 PASS / 0 FAIL / 1 EXCLUDED (ma_data); `compare_spike.py --config sc` 41/41 MATCH; hello (CONSOLE=sim) PASS trên sc và m1c1_bp2; lint sạch 8 cấu hình; Yosys elaborate rv_core_sc/rv_core/soc_top OK.
- 22/10/2026 Phase 2: ma trận riscv-tests (6 cấu hình) 0 FAIL; Spike 4 cấu hình MATCH (KNOWN: marchid, misa); tb_alu (15440 checks), tb_regfile (40134 checks) PASS; lint sạch.
- 22/10/2026 Phase 3: ma trận riscv-tests 0 FAIL (rv32um, rv32uc pass); tb_muldiv (4316 checks, latency chia 33), tb_compressed_decoder (1061 vector + 43 illegal) PASS.
- 22/10/2026 Phase 4: riscv-tests BP_MODE 0/1/2 0 FAIL; tb_bp PASS (6304 checks); 8 benchmark (dhrystone, median, multiply, qsort, rsort, towers, vvadd, memcpy) chạy trên mọi biến thể, khớp Spike (taint tracking cho counter); Dhrystone CPI 1.434 (BP0) / 1.209 (BP2) trên m1c1.
- 22/10/2026 Phase 5: rv32mi PASS mọi cấu hình (loại trừ breakpoint, pmpaddr có lý do); tb_csr (136 checks), tb_apb_bridge (3037 checks, wait state ngẫu nhiên, PSLVERR, slot trống), tb_intc (2209 checks) PASS.
- 22/10/2026 Phase 6: 13/13 unit TB PASS (thêm tb_fifo, tb_uart, tb_spi, tb_timer, tb_gpio); BFM: apb_master, apb_slave_model, uart, spi_slave (4 mode), spi_flash (W25Q rút gọn).

## BLOCKED

(trống)

## Ghi chú cho lần chạy sau

- Project hoàn thành. Phần tùy chọn chưa làm: Return Address Stack (RAS). Fmax SoC: nextpnr ECP5; Fmax lõi trên ASIC: OpenLane/sky130 (`results/asic/`). `make asic` cần Docker và image `ghcr.io/efabless/openlane2:2.3.10`; không chạy song song việc nặng khác (đi dây cần ~4,5 GB RAM). Lần chạy dài: dùng `setsid nohup` và không để máy ảo khởi động lại/ngủ.

- Thư mục gốc: `/home/danhle/Desktop/doanthietke`.
- Công cụ: OSS CAD Suite ở `~/tools/oss-cad-suite`, Spike ở `~/tools/spike`, dtc ở `~/tools/dtc`.

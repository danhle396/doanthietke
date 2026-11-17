# Kết quả

Tài liệu này được ghép tự động từ các file trong `results/` bằng `scripts/make_results_md.py`; mọi số liệu là số đo thật từ các lần chạy gần nhất. Lệnh tái tạo ghi trong từng mục và trong `docs/giai_thich/huong_dan_chay.md`.

## 1. Regression tổng

Nguồn: `results/regress.md`.

| Bước    | Kết quả | Thời gian (s) |
| ------- | ------- | ------------- |
| lint    | PASS    |             3 |
| unit    | PASS    |             3 |
| sw      | PASS    |             0 |
| isa     | PASS    |            86 |
| spike   | PASS    |           129 |
| systest | PASS    |             5 |

Tổng: PASS. Tái tạo: `make regress`.

## 2. Unit testbench

Nguồn: `results/unit/summary.md`.

| Testbench             | Kết quả | Seed | Thời gian (s) | Ghi chú      |
| --------------------- | ------- | ---- | ------------- | ------------ |
| tb_alu                | PASS    |    1 |           2.8 | 15440 checks |
| tb_regfile            | PASS    |    1 |           0.0 | 40134 checks |
| tb_muldiv             | PASS    |    1 |           0.0 | 4316 checks  |
| tb_compressed_decoder | PASS    |    1 |           0.1 | 2104 checks  |
| tb_bp                 | PASS    |    1 |           0.0 | 6304 checks  |
| tb_csr                | PASS    |    1 |           0.0 | 136 checks   |
| tb_fifo               | PASS    |    1 |           0.0 | 77335 checks |
| tb_apb_bridge         | PASS    |    1 |           0.0 | 3038 checks  |
| tb_dbus_xbar          | PASS    |    1 |           0.0 | 5815 checks  |
| tb_uart               | PASS    |    1 |           0.0 | 549 checks   |
| tb_spi                | PASS    |    1 |           0.0 | 395 checks   |
| tb_timer              | PASS    |    1 |           0.0 | 220 checks   |
| tb_gpio               | PASS    |    1 |           0.0 | 617 checks   |
| tb_intc               | PASS    |    1 |           0.0 | 2209 checks  |

Tái tạo: `make unit` (= `.venv/bin/python scripts/run_unit.py`)

## 3. riscv-tests – ma trận cấu hình

Nguồn: `results/isa/summary.md`.

| Cấu hình RTL    | ELF   | Bộ test                     | PASS | FAIL | EXCLUDED |
| --------------- | ----- | --------------------------- | ---- | ---- | -------- |
| `m1c1_bp0`      | `imc` | rv32ui,rv32um,rv32uc,rv32mi |   64 |    0 |        3 |
| `m1c1_bp1`      | `imc` | rv32ui,rv32um,rv32uc,rv32mi |   64 |    0 |        3 |
| `m1c1_bp2`      | `imc` | rv32ui,rv32um,rv32uc,rv32mi |   64 |    0 |        3 |
| `m1c0_bp2`      | `im`  | rv32ui,rv32um,rv32mi        |   63 |    0 |        3 |
| `m0c0_bp2`      | `i`   | rv32ui,rv32mi               |   55 |    0 |        3 |
| `sc`            | `i`   | rv32ui                      |   41 |    0 |        1 |
| `m1c1_bp2_sync` | `imc` | rv32ui,rv32um,rv32uc,rv32mi |   64 |    0 |        3 |

Test bị loại trừ và lý do:

- `rv32mi-p-breakpoint`: cần CSR debug trigger (Sdtrig) – isa/rv64mi/breakpoint.S dòng 33 `csrw tselect, x0` trap illegal vì lõi không hiện thực tselect/tdata1/tdata2 (chỉ M-mode, không có debug module)
- `rv32mi-p-pmpaddr`: cần PMP – isa/rv64mi/pmpaddr.S dòng 27 `csrw pmpcfg0, zero` trap illegal vì lõi không hiện thực PMP (spec mục 10.2 cho phép loại trừ)
- `rv32ui-p-ma_data`: core traps on misaligned load/store (allowed by the spec); the trap behaviour is checked by rv32mi-p-ma_addr

Tái tạo: `make isa` (= `.venv/bin/python scripts/run_isa.py --matrix`)

Ghi chú loại trừ: `rv32ui-p-ma_data` được phép loại trừ theo spec (lõi trap khi truy cập không căn lề, hành vi trap được kiểm bởi `rv32mi-p-ma_addr` và `*-misaligned`); `rv32mi-p-breakpoint` và `rv32mi-p-pmpaddr` phụ thuộc debug trigger / PMP mà lõi không có – dòng nguồn phụ thuộc được ghi ở trên.

## 4. So sánh với Spike

Nguồn: `results/spike/summary.md`.

| Cấu hình   | MATCH | Tổng |
| ---------- | ----- | ---- |
| `m1c1_bp2` |    73 |   73 |
| `m1c0_bp2` |    72 |   72 |
| `m0c0_bp2` |    64 |   64 |
| `sc`       |    50 |   50 |

Tái tạo: `make spike`

Mức so sánh: `--log-commits` (PC, mã lệnh, thanh ghi đích + giá trị, địa chỉ + dữ liệu store), so khớp từng lệnh bằng regex (`scripts/compare_spike.py`). Khác biệt đã biết và được liệt kê (không che giấu): giá trị đọc `marchid` (RTL 0, Spike 5); `misa` ghi được trong Spike (test `rv32mi-p-ma_fetch` xóa bit C rồi rẽ nhánh khác – kết quả KNOWN); các giá trị đọc từ `cycle/mcycle/instret/minstret/time/mhpmcounter*` phụ thuộc thời gian, được theo dõi taint qua thanh ghi và bộ nhớ (decision D19). Truy cập không căn lề: cả RTL và Spike đều trap nên không phát sinh khác biệt. Chi tiết từng chương trình: `results/spike/<cấu hình>.md`.

## 5. Co-simulation C++ lock-step với Spike

Nguồn: `results/cosim/summary.md`.

| Cấu hình   | MATCH | Tổng | Lệnh so khớp | Thời gian (s) |
| ---------- | ----- | ---- | ------------ | ------------- |
| `m1c1_bp2` |    73 |   73 |      1639070 |          21.8 |
| `m1c0_bp2` |    72 |   72 |      1638940 |          22.3 |
| `m0c0_bp2` |    64 |   64 |      2516910 |          31.4 |
| `sc`       |    50 |   50 |      2528472 |          36.3 |

Mutant (lỗi SLTU cài sẵn): phát hiện ở 2 / 73 chương trình – xem `mutant.md`.

Hình lock-step: `results/cosim/lockstep.png`.

Tái tạo: `make cosim`

Harness Verilator C++ `cosim/cosim_main.cpp` chạy `soc_top` và Spike (tiến trình con) cùng lúc; mỗi lệnh RTL retire (DPI `cosim_commit` ở WB) được so ngay với lệnh Spike commit kế tiếp, lệch là dừng. Kiểm tra chính harness: RTL có lỗi SLTU cài sẵn (`-DCOSIM_MUTANT`) bị phát hiện tại lệnh sai đầu tiên (`results/cosim/mutant.md`). Hình lock-step: `results/cosim/lockstep.png`.

## 6. System test

Nguồn: `results/systest/summary.md`.

| Test           | Cấu hình RTL | Kết quả | Chu kỳ  | Ghi chú                                          |
| -------------- | ------------ | ------- | ------- | ------------------------------------------------ |
| hello          | `m1c1_bp2`   | PASS    |   12135 |                                                  |
| uart_irq_echo  | `m1c1_bp2`   | PASS    |   44819 | RESULT uart_irq_echo: PASS (79 checks, 0 errors) |
| spi_flash      | `m1c1_bp2`   | PASS    |   71663 | RESULT spi_flash: PASS (281 checks, 0 errors)    |
| spi_modes      | `m1c1_bp2`   | PASS    |   63188 | RESULT spi_modes: PASS (16 checks, 0 errors)     |
| timer_irq      | `m1c1_bp2`   | PASS    |   40534 | RESULT timer_irq: PASS (23 checks, 0 errors)     |
| timer_irq      | `sc`         | PASS    |   40355 | RESULT timer_irq: PASS (23 checks, 0 errors)     |
| gpio_irq       | `m1c1_bp2`   | PASS    |   15795 | RESULT gpio_irq: PASS (11 checks, 0 errors)      |
| irq_priority   | `m1c1_bp2`   | PASS    |   21746 | RESULT irq_priority: PASS (8 checks, 0 errors)   |
| irq_priority   | `sc`         | PASS    |   21546 | RESULT irq_priority: PASS (8 checks, 0 errors)   |
| exceptions     | `m1c1_bp2`   | PASS    |  129554 | RESULT exceptions: PASS (62 checks, 0 errors)    |
| exceptions     | `m1c0_bp2`   | PASS    |  132125 | RESULT exceptions: PASS (66 checks, 0 errors)    |
| exceptions     | `sc`         | PASS    |  132102 | RESULT exceptions: PASS (66 checks, 0 errors)    |
| irq_during_div | `m1c1_bp2`   | PASS    |  494430 | RESULT irq_during_div: PASS (3 checks, 0 errors) |
| demo           | `m1c1_bp2`   | PASS    | 4088021 |                                                  |
| branch_smc     | `m1c1_bp2`   | PASS    |   24718 | RESULT branch_smc: PASS (4 checks, 0 errors)     |
| branch_smc     | `m1c1_bp0`   | PASS    |   24775 | RESULT branch_smc: PASS (4 checks, 0 errors)     |
| branch_smc     | `sc`         | PASS    |   24691 | RESULT branch_smc: PASS (4 checks, 0 errors)     |

Tiêu chí PASS: mã thoát 0 từ SIM_CTRL, output UART khớp file kỳ vọng (nếu có), không có lỗi frame/parity ở BFM UART, không có lỗi giao thức ở BFM flash.

Tái tạo: `make systest` (= `.venv/bin/python scripts/run_systest.py`)

## 7. Hiệu năng

Nguồn: `results/perf/summary.md`.

Số liệu đo trong vùng đo của từng benchmark (giữa hai lần `setStats`/`start_time`) bằng `mcycle`, `minstret`, `mhpmcounter3..10`. Tái tạo: `make perf` (= `.venv/bin/python scripts/run_perf.py`).

### Thí nghiệm 1 – Bộ dự đoán rẽ nhánh (rv32imc, BHT 256, BTB 32)

Bảng P1. CPI, độ chính xác dự đoán (branch + jump) và chu kỳ penalty (toàn chương trình = 2×redirect ở EX + 1×redirect ở ID). Nguồn: `results/perf/exp1_predictor.csv`.

| Benchmark       | CPI BP0 | CPI BP1 | CPI BP2 | Acc BP0 | Acc BP1 | Acc BP2 | Penalty BP0 | Penalty BP1 | Penalty BP2 |
| --------------- | ------- | ------- | ------- | ------- | ------- | ------- | ----------- | ----------- | ----------- |
| dhrystone       |   1.435 |   1.307 |   1.204 |   24.2% |   85.0% |   83.3% |       98704 |       60615 |       27516 |
| coremark        |   1.314 |   1.220 |   1.110 |   39.8% |   89.5% |   90.2% |      165288 |      108586 |       29885 |
| median          |   1.396 |   1.375 |   1.255 |   43.1% |   63.6% |   63.6% |        5276 |        4725 |        2414 |
| multiply        |   1.585 |   1.350 |   1.063 |    8.9% |   88.7% |   90.2% |       26096 |       16508 |        2884 |
| qsort           |   1.399 |   1.341 |   1.199 |   42.3% |   74.5% |   74.5% |       90000 |       68981 |       23089 |
| rsort           |   1.066 |   1.033 |   1.000 |    0.7% |   99.7% |   99.6% |       32226 |       16377 |         353 |
| towers          |   1.119 |   1.099 |   1.067 |   26.6% |   64.0% |   65.1% |        2412 |        1656 |         678 |
| vvadd           |   1.250 |   1.129 |   1.008 |    3.5% |   98.7% |   98.7% |        2984 |        1645 |         246 |
| memcpy          |   1.399 |   1.200 |   1.001 |    0.4% |   99.9% |   99.9% |       21508 |       10905 |         250 |
| **geomean CPI** |   1.320 |   1.223 |   1.097 |         |         |         |             |             |             |

![Hình P1](../results/perf/exp1_cpi.png)

![Hình P2](../results/perf/exp1_accuracy.png)

### Thí nghiệm 2 – Quét kích thước BHT × BTB (BP_MODE 2)

Bảng P2. Độ chính xác trung bình (%) / geomean CPI trên 9 benchmark; diện tích = số cell Yosys của `rv_core` (generic, không tính RAM). Nguồn: `results/perf/exp2_sweep.csv`, `results/synth/summary.json`.

| BHT \ BTB | 8                          | 16                         | 32                         | 64                         |
| --------- | -------------------------- | -------------------------- | -------------------------- | -------------------------- |
|        16 | 82.0% / 1.116 / 26427 cell | 83.7% / 1.106 / 27412 cell | 84.7% / 1.099 / 29403 cell | 85.2% / 1.096 / 33277 cell |
|        64 | 82.1% / 1.115 / 27170 cell | 84.0% / 1.104 / 28112 cell | 85.0% / 1.097 / 30096 cell | 85.6% / 1.093 / 33915 cell |
|       256 | 82.1% / 1.115 / 29826 cell | 83.9% / 1.104 / 30811 cell | 85.0% / 1.097 / 32801 cell | 85.5% / 1.093 / 36664 cell |
|      1024 | 82.1% / 1.115 / 40870 cell | 83.9% / 1.104 / 41829 cell | 85.0% / 1.097 / 43819 cell | 85.6% / 1.093 / 47690 cell |

![Hình P3](../results/perf/exp2_accuracy_heatmap.png)

![Hình P4](../results/perf/exp2_cpi_vs_area.png)

### Thí nghiệm 3 – Extension C

Bảng P3. Kích thước `.text` (byte) và CPI của ELF rv32im so với rv32imc, cùng lõi `m1c1_bp2`. Nguồn: `results/perf/exp3_rvc.csv`.

| Benchmark | .text im | .text imc | Giảm  | Lệnh nén (%) | Chu kỳ im | Chu kỳ imc | CPI im | CPI imc |
| --------- | -------- | --------- | ----- | ------------ | --------- | ---------- | ------ | ------- |
| dhrystone |     7068 |      5488 | 22.4% |        54.5% |    338104 |     333617 |  1.220 |   1.204 |
| coremark  |    12404 |      8992 | 27.5% |        54.8% |    702058 |     695588 |  1.120 |   1.110 |
| median    |     4496 |      3504 | 22.1% |        64.7% |      5402 |       5404 |  1.254 |   1.255 |
| multiply  |     4508 |      3520 | 21.9% |        83.1% |     22282 |      22282 |  1.063 |   1.063 |
| qsort     |     4796 |      3716 | 22.5% |        42.9% |    148615 |     148150 |  1.203 |   1.199 |
| rsort     |     5328 |      4140 | 22.3% |        47.3% |    171250 |     171242 |  1.000 |   1.000 |
| towers    |     5812 |      4332 | 25.5% |        66.1% |      4037 |       4028 |  1.069 |   1.067 |
| vvadd     |     4440 |      3468 | 21.9% |        74.1% |      2489 |       2489 |  1.008 |   1.008 |
| memcpy    |     4536 |      3516 | 22.5% |        40.0% |     20110 |      20110 |  1.001 |   1.001 |
| **tổng**  |    53388 |     40676 | 23.8% |              |           |            |        |         |

![Hình P5](../results/perf/exp3_text_size.png)

### Thí nghiệm 4 – Phân rã CPI (m1c1_bp2, rv32imc)

Bảng P4. CPI = 1 (lệnh) + các thành phần stall/lệnh. `mispredict` = 2 chu kỳ × số lần sai dự đoán ở EX; `other` = phần còn lại (chủ yếu redirect 1 chu kỳ ở ID cho JAL). Nguồn: `results/perf/exp4_cpi_breakdown.csv`.

| Benchmark | CPI   | load-use | MulDiv | bus   | mispredict | other |
| --------- | ----- | -------- | ------ | ----- | ---------- | ----- |
| dhrystone | 1.204 |    0.047 |  0.059 | 0.000 |      0.072 | 0.025 |
| coremark  | 1.110 |    0.065 |  0.000 | 0.000 |      0.041 | 0.004 |
| median    | 1.255 |    0.002 |  0.000 | 0.000 |      0.252 | 0.001 |
| multiply  | 1.063 |    0.001 |  0.000 | 0.000 |      0.063 | 0.000 |
| qsort     | 1.199 |    0.036 |  0.000 | 0.000 |      0.161 | 0.003 |
| rsort     | 1.000 |    0.000 |  0.000 | 0.000 |      0.000 | 0.000 |
| towers    | 1.067 |    0.012 |  0.000 | 0.000 |      0.051 | 0.004 |
| vvadd     | 1.008 |    0.004 |  0.000 | 0.000 |      0.003 | 0.001 |
| memcpy    | 1.001 |    0.001 |  0.000 | 0.000 |      0.000 | 0.000 |

![Hình P6](../results/perf/exp4_cpi_breakdown.png)

### Thí nghiệm 5 – Single-cycle so với pipeline

Bảng P5. CPI (geomean), Fmax ước lượng của SoC tương ứng (nextpnr ECP5, RAM 1 KB, xem `results/synth/summary.md`) và hiệu năng tương đối ∝ Fmax / CPI (chuẩn hóa theo lõi single-cycle). Nguồn: `results/perf/exp5_sc_vs_pipeline.csv`.

| Lõi                              | geomean CPI | Dhrystone CPI | Fmax (MHz) | Fmax/CPI | Hiệu năng tương đối |
| -------------------------------- | ----------- | ------------- | ---------- | -------- | ------------------- |
| rv_core_sc (single-cycle, RV32I) |       1.000 |         1.000 |      25.95 |     25.9 |               1.00× |
| rv_core pipeline RV32I           |       1.104 |         1.178 |      42.64 |     38.6 |               1.49× |
| rv_core pipeline RV32IMC         |       1.097 |         1.204 |      44.07 |     40.2 |               1.55× |

### Kiểm tra hợp lý (spec 12.1)

| Kiểm tra                                         | Kết quả | Giá trị |
| ------------------------------------------------ | ------- | ------- |
| CPI Dhrystone (BP2) trong [1.0, 2.0]             | ĐẠT     | 1.204   |
| BP_MODE=2 không tệ hơn BP_MODE=0 (mọi benchmark) | ĐẠT     | đạt     |

## 8. Thông lượng

Nguồn: `results/perf/throughput.md`.

Lõi `rv_core` RV32IMC, BP_MODE 2 (BHT 256, BTB 32), ELF `imc`; số chu kỳ/lệnh của vùng đo trong mỗi benchmark (nguồn: `results/perf/exp1_predictor.csv`). Tần số: **24 MHz** (clock CPU trên board DE2) và **44.07 MHz** (Fmax trung vị 5 seed của `soc_top_1k`, ước lượng ECP5). Thời gian = chu kỳ ÷ f; MIPS = f ÷ CPI. Sinh bởi `scripts/throughput.py`.

### Bảng T1 – Thời gian chạy và MIPS

| Benchmark        | Lệnh   | Chu kỳ | CPI   | Thời gian @24 MHz (µs) | MIPS @24 MHz | Thời gian @44.07 MHz (µs) | MIPS @44.07 MHz |
| ---------------- | ------ | ------ | ----- | ---------------------- | ------------ | ------------------------- | --------------- |
| dhrystone        | 277083 | 333617 | 1.204 |                13900.7 |         19.9 |                    7570.2 |            36.6 |
| coremark         | 626769 | 695588 | 1.110 |                28982.8 |         21.6 |                   15783.7 |            39.7 |
| median           |   4307 |   5404 | 1.255 |                  225.2 |         19.1 |                     122.6 |            35.1 |
| multiply         |  20953 |  22282 | 1.063 |                  928.4 |         22.6 |                     505.6 |            41.4 |
| qsort            | 123560 | 148150 | 1.199 |                 6172.9 |         20.0 |                    3361.7 |            36.8 |
| rsort            | 171186 | 171242 | 1.000 |                 7135.1 |         24.0 |                    3885.7 |            44.1 |
| towers           |   3777 |   4028 | 1.066 |                  167.8 |         22.5 |                      91.4 |            41.3 |
| vvadd            |   2469 |   2489 | 1.008 |                  103.7 |         23.8 |                      56.5 |            43.7 |
| memcpy           |  20089 |  20110 | 1.001 |                  837.9 |         24.0 |                     456.3 |            44.0 |
| **geomean MIPS** |        |        |       |                        |     **21.9** |                           |        **40.2** |

### Bảng T2 – Điểm chuẩn

| Chỉ số                                                        | /MHz  | @24 MHz | @44.07 MHz |
| ------------------------------------------------------------- | ----- | ------- | ---------- |
| Dhrystone (DMIPS; 500 vòng, 1 DMIPS = 1757 vòng/s)            | 0.853 |    20.5 |       37.6 |
| CoreMark (2 vòng, không phải lần chạy hợp lệ theo luật EEMBC) |  2.88 |    69.0 |      126.7 |

### Bảng T3 – Bus và ngoại vi

| Đường truyền                                               | Chu kỳ / đơn vị | Nguồn                                                            | @24 MHz           | @44.07 MHz         |
| ---------------------------------------------------------- | --------------- | ---------------------------------------------------------------- | ----------------- | ------------------ |
| RAM qua Wishbone (load/store 32 bit, ACK cùng chu kỳ)      |               1 | RTL; số chu kỳ benchmark trùng khớp với RAM tổ hợp               | 96.00 MB/s        | 176.28 MB/s        |
| Thanh ghi ngoại vi qua Wishbone → APB4                     |               3 | đo bằng `wb_checker` (system test `hello`: 3.00 chu kỳ/truy cập) | 8.00 M truy cập/s | 14.69 M truy cập/s |
| UART 115200 baud (BAUD_DIV 12 @24 MHz, khung 8N1 = 10 bit) |            2080 | 16 × (12 + 1) chu kỳ/bit                                         | 11.5 kB/s         | 21.2 kB/s          |
| UART tối đa (BAUD_DIV 0, khung 8N1)                        |             160 | 16 chu kỳ/bit                                                    | 150.0 kB/s        | 275.4 kB/s         |
| SPI tối đa (CLK_DIV 0, SCLK = f/2, burst)                  |              17 | 17 × (CLK_DIV + 1) chu kỳ/byte                                   | 1.41 MB/s         | 2.59 MB/s          |
| SPI flash trong firmware (CLK_DIV 1, SCLK = f/4)           |              34 | 17 × 2 chu kỳ/byte                                               | 0.71 MB/s         | 1.30 MB/s          |

Ghi chú: tốc độ UART ở dòng 115200 baud đúng cho clock 24 MHz của board; ở tần số khác BAUD_DIV phải tính lại. CoreMark chạy 2 vòng để vừa thời gian mô phỏng nên chỉ dùng để so sánh tương đối.

## 9. Tổng hợp

Nguồn: `results/synth/summary.md`.

Diện tích: Yosys `synth -flatten` (thư viện generic, đơn vị = số cell logic sau tối ưu); `ram_dp` là black box nên **RAM 128 KB không được tính**. Fmax: Yosys `synth_ecp5` + `nextpnr-ecp5` (LFE5U-85F, CABGA756), 5 seed đặt–định tuyến trên cùng netlist, báo **trung vị** và khoảng min–max (một seed riêng lẻ dao động tới vài chục %) – chỉ là **ước lượng trên FPGA**; không làm place & route ASIC (ngoài phạm vi). Tái tạo: `make synth`.

### Bảng S1 – Diện tích lõi và ngoại vi (generic)

| Khối               | Tham số                                      | Cell  | Flip-flop |
| ------------------ | -------------------------------------------- | ----- | --------- |
| `rv_core_m1c1_bp0` | {'ENABLE_M': 1, 'ENABLE_C': 1, 'BP_MODE': 0} | 24567 |      2532 |
| `rv_core_m1c1_bp1` | {'ENABLE_M': 1, 'ENABLE_C': 1, 'BP_MODE': 1} | 28970 |      3045 |
| `rv_core_m1c1_bp2` | {'ENABLE_M': 1, 'ENABLE_C': 1, 'BP_MODE': 2} | 32801 |      4966 |
| `rv_core_m1c0_bp2` | {'ENABLE_M': 1, 'ENABLE_C': 0, 'BP_MODE': 2} | 30995 |      4871 |
| `rv_core_m0c0_bp2` | {'ENABLE_M': 0, 'ENABLE_C': 0, 'BP_MODE': 2} | 21370 |      4699 |
| `rv_core_sc`       | –                                            | 10477 |      1509 |
| `uart_apb`         | –                                            |  1457 |       411 |
| `spi_apb`          | –                                            |  1145 |       364 |
| `timer64_apb`      | –                                            |  1245 |       146 |
| `gpio_apb`         | –                                            |   611 |       130 |
| `intc_apb`         | –                                            |    54 |         3 |
| `apb_bridge`       | –                                            |   182 |        71 |
| `dbus_xbar`        | –                                            |   173 |         0 |
| `sim_ctrl`         | –                                            |    18 |         0 |
| `rst_sync`         | –                                            |     2 |         2 |
| `soc_top`          | –                                            | 37779 |      6077 |

Nguồn: `results/synth/area.csv`.

### Bảng S2 – Diện tích `rv_core` theo BHT × BTB (BP_MODE 2, số cell)

| BHT \ BTB | 8     | 16    | 32    | 64    |
| --------- | ----- | ----- | ----- | ----- |
|        16 | 26427 | 27412 | 29403 | 33277 |
|        64 | 27170 | 28112 | 30096 | 33915 |
|       256 | 29826 | 30811 | 32801 | 36664 |
|      1024 | 40870 | 41829 | 43819 | 47690 |

### Bảng S3 – ECP5: tài nguyên và Fmax ước lượng

| Thiết kế          | LUT4  | FF   | Fmax trung vị (MHz) | min – max (5 seed) | Đường găng (seed trung vị, tóm tắt)                                                         |
| ----------------- | ----- | ---- | ------------------- | ------------------ | ------------------------------------------------------------------------------------------- |
| `m1c1_bp2`        |  9715 | 4966 |               40.44 | 38.21 – 42.38      | `u_ex.mem_rd` → `u_ex.fwd_rs1` (36 chặng logic/định tuyến)                                  |
| `m1c1_bp0`        |  5493 | 2532 |               44.76 | 41.92 – 46.27      | `u_ex.mem_rd_we` → `u_ex.mem_rd_we` (25 chặng logic/định tuyến)                             |
| `m0c0_bp2`        |  8446 | 4699 |               45.48 | 43.7 – 46.64       | `u_ex.mem_rd_we` → `u_if.pc_q` (46 chặng logic/định tuyến)                                  |
| `sc`              |  4501 | 1509 |               46.22 | 44.09 – 47.74      | `u_csr.wdata` → `u_csr.wdata` (42 chặng logic/định tuyến)                                   |
| `soc_top_1k`      | 11413 | 5565 |               44.07 | 41.43 – 45.76      | `g_pipe.u_core.u_ex.mem_rd_we` → `g_pipe.u_core.u_ex.mem_rd_we` (19 chặng logic/định tuyến) |
| `soc_top_m0c0_1k` | 10240 | 5298 |               42.64 | 34.78 – 44.0       | `g_pipe.u_core.u_ex.mem_rd_we` → `g_pipe.u_core.u_if.id_insn` (51 chặng logic/định tuyến)   |
| `soc_top_sc_1k`   |  8886 | 2108 |               25.95 | 24.6 – 26.42       | `g_sc.u_core.pc_q` → `g_sc.u_core.u_csr.wdata` (37 chặng logic/định tuyến)                  |

Chi tiết từng chặng: `results/synth/critical_path_<tên>.txt`. `soc_top_*_1k` dùng RAM 1 KB (LUT RAM) thay cho 128 KB để đặt được trên FPGA và tính cả đường đọc RAM tổ hợp; Fmax của lõi đứng riêng (`m1c1_bp2`, `sc`…) **không** gồm đường qua RAM (cổng vào/ra lõi không được ràng buộc), nên so sánh single-cycle với pipeline phải dùng các dòng `soc_top_*`.

## 10. Layout ASIC (OpenLane 2 / sky130A)

Nguồn: `results/asic/summary.md`.

OpenLane 2.3.10 (flow `Classic`, image Docker `ghcr.io/efabless/openlane2:2.3.10`), PDK sky130A (open_pdks `0fe599b`), thư viện cell `sky130_fd_sc_hd`. Chỉ làm layout cho **lõi** (cổng Wishbone là chân I/O của khối); RAM 128 KB của SoC không đưa vào vì flow không có macro SRAM (quyết định D30). Sinh bởi `scripts/run_asic.py` (`make asic`).

### Bảng A1 – Kết quả place & route

| Chỉ số                                       | `rv_core`                     | `rv_core_sc`                 |
| -------------------------------------------- | ----------------------------- | ---------------------------- |
| Chu kỳ ràng buộc (SDC)                       | 25 ns (40 MHz)                | 25 ns (40 MHz)               |
| Kích thước die                               | 961.8 × 972.5 µm (0.935 mm²)  | 527.7 × 538.4 µm (0.284 mm²) |
| Số cell chuẩn (gồm tap, fill, diode, buffer) | 62,600                        | 18,069                       |
| Diện tích cell chuẩn                         | 459,999 µm²                   | 139,680 µm²                  |
| Mật độ (utilization)                         | 51.0 %                        | 52.6 %                       |
| Tổng chiều dài dây                           | 1,761,890 µm                  | 548,711 µm                   |
| Setup slack / Fmax – TT 25 °C 1,80 V         | +9.85 ns / **66.0 MHz**       | +5.46 ns / **51.2 MHz**      |
| Setup slack / Fmax – SS 100 °C 1,60 V        | -3.99 ns / **34.5 MHz**       | -4.08 ns / **34.4 MHz**      |
| Setup slack / Fmax – FF −40 °C 1,95 V        | +13.56 ns / **87.4 MHz**      | +8.80 ns / **61.7 MHz**      |
| Hold slack (TT)                              | +0.304 ns                     | +0.322 ns                    |
| Công suất tổng (TT, ước lượng)               | 80.00 mW                      | 7.50 mW                      |
| – trong đó: internal / switching / leakage   | 34.14 mW / 45.86 mW / 0.50 µW | 4.79 mW / 2.71 mW / 0.16 µW  |
| DRC (Magic / KLayout / router)               | 0 / 0 / 0                     | 0 / 0 / 0                    |
| LVS (Netgen) – số lỗi                        | 0                             | 0                            |
| Antenna – số net vi phạm                     | 26                            | 8                            |
| XOR GDS Magic ↔ KLayout                      | 0                             | 0                            |
| Vi phạm max slew / max cap – TT              | 7 / 21                        | 15 / 0                       |
| Vi phạm max slew / max cap – góc xấu nhất    | 1,187 / 44                    | 347 / 0                      |
| Gate-level (netlist sau đi dây) ≡ RTL        | 64/64 riscv-tests             | 41/41 riscv-tests            |

Fmax = 1 / (chu kỳ ràng buộc − setup slack) tại từng góc PVT, theo STA của OpenROAD sau đi dây (có ký sinh SPEF). Công suất do OpenSTA ước lượng với hoạt động chuyển mạch mặc định, không lấy từ mô phỏng – chỉ dùng để so sánh tương đối. Gate-level: netlist cuối cùng chạy bằng Icarus Verilog với mô hình chức năng `sky130_fd_sc_hd`, cùng testbench `tb/asic/tb_core_gl.v` với RTL (Verilator); một test khớp khi cả hai PASS với cùng số chu kỳ, số lần ghi và chữ ký ghi bộ nhớ (`results/asic/gl_<top>.csv`).

### Hình

![Layout rv_core](../results/asic/layout_rv_core.png)

*Layout `rv_core` (GDS cuối, KLayout).* Đường găng: `results/asic/timing_rv_core.txt`.

![Layout rv_core_sc](../results/asic/layout_rv_core_sc.png)

*Layout `rv_core_sc` (GDS cuối, KLayout).* Đường găng: `results/asic/timing_rv_core_sc.txt`.

Tái tạo: `make asic` (lần đầu khoảng 1 giờ; kết quả cũ được dùng lại nếu RTL và `asic/<top>/config.json` không đổi).

## 11. Coverage

Nguồn: `results/coverage/summary.md`.

Gộp mọi lần chạy: unit testbench, riscv-tests (cả ma trận cấu hình), system test, benchmark (m1c1_bp2, m1c1_bp1, sc). Công cụ: Verilator `--coverage-line --coverage-toggle --coverage-user`, gộp bằng `verilator_coverage`. Tái tạo: `make cov`. (Không có `genhtml` trên máy nên không xuất HTML; file lcov: `build/cov/line.info`.)

### Bảng C1 – Theo thư mục (mục tiêu line ≥ 90% cho rtl/core và rtl/periph)

| Thư mục    | Line            | Toggle           |
| ---------- | --------------- | ---------------- |
| rtl (khác) | 100.0% (98/98)  | 97.8% (180/184)  |
| rtl/core   | 99.8% (592/593) | 100.0% (477/477) |
| rtl/periph | 97.5% (119/122) | 98.6% (212/215)  |

### Bảng C2 – Theo file

| File                              | Line             | Toggle         |
| --------------------------------- | ---------------- | -------------- |
| `rtl/bus/apb_bridge.sv`           | 100.0% (6/6)     | 95.8% (23/24)  |
| `rtl/bus/dbus_xbar.sv`            | 100.0% (13/13)   | 100.0% (27/27) |
| `rtl/core/alu.sv`                 | 92.3% (12/13)    | 100.0% (7/7)   |
| `rtl/core/bp/bht.sv`              | 100.0% (3/3)     | 100.0% (10/10) |
| `rtl/core/bp/btb.sv`              | 100.0% (11/11)   | 100.0% (21/21) |
| `rtl/core/branch_unit.sv`         | 100.0% (9/9)     | 100.0% (18/18) |
| `rtl/core/compressed_decoder.sv`  | 100.0% (59/59)   | 100.0% (11/11) |
| `rtl/core/csr_file.sv`            | 100.0% (95/95)   | 100.0% (40/40) |
| `rtl/core/decoder.sv`             | 100.0% (112/112) | 100.0% (27/27) |
| `rtl/core/ex_stage.sv`            | 100.0% (38/38)   | 100.0% (80/80) |
| `rtl/core/forward_unit.sv`        | 100.0% (7/7)     | 100.0% (12/12) |
| `rtl/core/id_stage.sv`            | 100.0% (81/81)   | 100.0% (68/68) |
| `rtl/core/if_stage.sv`            | 100.0% (17/17)   | 100.0% (27/27) |
| `rtl/core/imm_gen.sv`             | 100.0% (8/8)     | 100.0% (3/3)   |
| `rtl/core/lsu.sv`                 | 100.0% (21/21)   | 100.0% (16/16) |
| `rtl/core/mem_stage.sv`           | 100.0% (71/71)   | 100.0% (77/77) |
| `rtl/core/muldiv.sv`              | 100.0% (32/32)   | 100.0% (23/23) |
| `rtl/core/regfile.sv`             | 100.0% (9/9)     | 100.0% (10/10) |
| `rtl/core/wb_stage.sv`            | 100.0% (7/7)     | 100.0% (27/27) |
| `rtl/core_sc/rv_core_sc.sv`       | 100.0% (59/59)   | 100.0% (58/58) |
| `rtl/mem/ram_bank16.sv`           | 100.0% (6/6)     | 100.0% (8/8)   |
| `rtl/mem/ram_dp.sv`               | 100.0% (4/4)     | 96.4% (27/28)  |
| `rtl/periph/gpio/gpio_apb.sv`     | 100.0% (14/14)   | 100.0% (22/22) |
| `rtl/periph/intc/intc_apb.sv`     | 100.0% (10/10)   | 100.0% (15/15) |
| `rtl/periph/sim/sim_ctrl.sv`      | 75.0% (9/12)     | 82.4% (14/17)  |
| `rtl/periph/spi/spi_apb.sv`       | 100.0% (15/15)   | 100.0% (31/31) |
| `rtl/periph/spi/spi_master.sv`    | 100.0% (11/11)   | 100.0% (25/25) |
| `rtl/periph/sync_fifo.sv`         | 100.0% (5/5)     | 100.0% (12/12) |
| `rtl/periph/timer/timer64_apb.sv` | 100.0% (17/17)   | 100.0% (21/21) |
| `rtl/periph/uart/uart_apb.sv`     | 100.0% (15/15)   | 100.0% (32/32) |
| `rtl/periph/uart/uart_rx.sv`      | 100.0% (7/7)     | 100.0% (20/20) |
| `rtl/periph/uart/uart_tx.sv`      | 100.0% (16/16)   | 100.0% (20/20) |
| `rtl/rst_sync.sv`                 | 100.0% (1/1)     | 100.0% (4/4)   |
| `rtl/soc_top.sv`                  | 100.0% (9/9)     | 94.3% (33/35)  |

Các dòng chưa phủ và giải thích: `results/coverage/uncovered.md`. Functional coverage: `results/coverage/functional.md`.

## 12. Functional coverage

Nguồn: `results/coverage/functional.md`.

71/71 điểm cover đạt (gộp theo tên, mọi instance). Điểm định nghĩa trong `tb/cov/*.sv`, gắn bằng `bind`. Tái tạo: `make cov`.

| Điểm cover               | Số lần   | Instance đạt / tổng | Kết quả |
| ------------------------ | -------- | ------------------- | ------- |
| `c_btb_alloc`            |     3574 | 2/2                 | ĐẠT     |
| `c_btb_hit`              |  2749218 | 1/1                 | ĐẠT     |
| `c_btb_lookup_hit`       |  2749640 | 2/2                 | ĐẠT     |
| `c_btb_lookup_miss`      |  4396644 | 2/2                 | ĐẠT     |
| `c_btb_replace`          |  1150812 | 2/2                 | ĐẠT     |
| `c_exc_breakpoint`       |        8 | 1/1                 | ĐẠT     |
| `c_exc_ecall`            |       10 | 1/1                 | ĐẠT     |
| `c_exc_illegal`          |       24 | 1/1                 | ĐẠT     |
| `c_exc_insn_access`      |        2 | 1/1                 | ĐẠT     |
| `c_exc_insn_misaligned`  |        9 | 1/1                 | ĐẠT     |
| `c_exc_load_access`      |        4 | 1/1                 | ĐẠT     |
| `c_exc_load_misaligned`  |       58 | 1/1                 | ĐẠT     |
| `c_exc_store_access`     |        2 | 1/1                 | ĐẠT     |
| `c_exc_store_misaligned` |       50 | 1/1                 | ĐẠT     |
| `c_fifo_empty`           | 44516920 | 4/4                 | ĐẠT     |
| `c_fifo_full`            |  3291009 | 4/4                 | ĐẠT     |
| `c_fifo_push_full`       |     2792 | 2/4                 | ĐẠT     |
| `c_fifo_push_pop`        |     9324 | 3/4                 | ĐẠT     |
| `c_fwd_exmem_rs1`        |  1003047 | 1/1                 | ĐẠT     |
| `c_fwd_exmem_rs2`        |   221741 | 1/1                 | ĐẠT     |
| `c_fwd_memwb_rs1`        |  1352453 | 1/1                 | ĐẠT     |
| `c_fwd_memwb_rs2`        |   331555 | 1/1                 | ĐẠT     |
| `c_id_redirect`          |   231897 | 1/1                 | ĐẠT     |
| `c_insn32_straddle`      |   795151 | 1/1                 | ĐẠT     |
| `c_irq_during_div`       |     2879 | 1/1                 | ĐẠT     |
| `c_irq_mei`              |      144 | 1/1                 | ĐẠT     |
| `c_irq_msi`              |        2 | 1/1                 | ĐẠT     |
| `c_irq_mti`              |     1187 | 1/1                 | ĐẠT     |
| `c_m_div`                |     1449 | 1/1                 | ĐẠT     |
| `c_m_divu`               |     1923 | 1/1                 | ĐẠT     |
| `c_m_mul`                |    39147 | 1/1                 | ĐẠT     |
| `c_m_mulh`               |      245 | 1/1                 | ĐẠT     |
| `c_m_mulhsu`             |      245 | 1/1                 | ĐẠT     |
| `c_m_mulhu`              |      283 | 1/1                 | ĐẠT     |
| `c_m_rem`                |      445 | 1/1                 | ĐẠT     |
| `c_m_remu`               |     3085 | 1/1                 | ĐẠT     |
| `c_mispred_branch`       |    86378 | 1/1                 | ĐẠT     |
| `c_mispred_btb_alias`    |        1 | 1/1                 | ĐẠT     |
| `c_mispred_jal`          |      710 | 1/1                 | ĐẠT     |
| `c_mispred_jalr`         |    25060 | 1/1                 | ĐẠT     |
| `c_ret_auipc`            |     4184 | 1/1                 | ĐẠT     |
| `c_ret_branch`           |   724752 | 1/1                 | ĐẠT     |
| `c_ret_compressed`       |  3855488 | 1/1                 | ĐẠT     |
| `c_ret_csr`              |     9024 | 1/1                 | ĐẠT     |
| `c_ret_fence`            |      374 | 1/1                 | ĐẠT     |
| `c_ret_fencei`           |       16 | 1/1                 | ĐẠT     |
| `c_ret_jal`              |    46851 | 1/1                 | ĐẠT     |
| `c_ret_jalr`             |     1201 | 1/1                 | ĐẠT     |
| `c_ret_load`             |   814017 | 1/1                 | ĐẠT     |
| `c_ret_lui`              |    48792 | 1/1                 | ĐẠT     |
| `c_ret_mret`             |     1488 | 1/1                 | ĐẠT     |
| `c_ret_op`               |   198169 | 1/1                 | ĐẠT     |
| `c_ret_opimm`            |   428950 | 1/1                 | ĐẠT     |
| `c_ret_store`            |   223282 | 1/1                 | ĐẠT     |
| `c_spi_lsb`              |     6936 | 2/2                 | ĐẠT     |
| `c_spi_mode0`            |    39967 | 2/2                 | ĐẠT     |
| `c_spi_mode1`            |     3468 | 2/2                 | ĐẠT     |
| `c_spi_mode2`            |     3468 | 2/2                 | ĐẠT     |
| `c_spi_mode3`            |     4216 | 2/2                 | ĐẠT     |
| `c_spi_msb`              |    44183 | 2/2                 | ĐẠT     |
| `c_stall_bus`            |  1063536 | 1/1                 | ĐẠT     |
| `c_stall_csr_use`        |     1564 | 1/1                 | ĐẠT     |
| `c_stall_load_use`       |   955009 | 1/1                 | ĐẠT     |
| `c_stall_muldiv`         |   225449 | 1/1                 | ĐẠT     |
| `c_trap_after_mispred`   |      127 | 1/1                 | ĐẠT     |
| `c_uart_8n1`             |  4104640 | 2/2                 | ĐẠT     |
| `c_uart_err`             |     7552 | 2/2                 | ĐẠT     |
| `c_uart_even`            |    30912 | 1/2                 | ĐẠT     |
| `c_uart_odd`             |    30912 | 1/2                 | ĐẠT     |
| `c_uart_rx`              |      326 | 2/2                 | ĐẠT     |
| `c_uart_stop2`           |    47040 | 1/2                 | ĐẠT     |

## 13. Hình waveform

Sinh tự động từ VCD bằng `scripts/make_waves.py` (thư mục `results/waves/`): `load_use_forwarding.png`, `compressed.png`, `mispredict_flush.png`, `trap_entry_exit.png`, `apb_transaction.png` (Wishbone → APB4), `uart_frame.png`, `spi_mode0.png`, `spi_mode3.png`, `walkthrough_pipeline.png`; lock-step RTL/Spike: `results/cosim/lockstep.png`; bảng pipeline theo chu kỳ: `results/waves/walkthrough_table.md`.

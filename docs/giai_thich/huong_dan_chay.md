# Hướng dẫn tự chạy lại mọi kết quả

Mọi lệnh chạy từ thư mục gốc project. Makefile tự thêm `~/tools/oss-cad-suite/bin`, `~/tools/spike/bin`,
`~/tools/dtc/bin` vào `PATH`; Python luôn chạy bằng `.venv/bin/python`.

## 1. Chuẩn bị (một lần)

```bash
make check-env        # in phiên bản mọi công cụ, kiểm tra libgcc rv32
make fetch            # clone riscv-tests và coremark vào third_party/ (đúng commit đã ghi)
```

## 2. Regression đầy đủ

```bash
make regress          # lint + unit + riscv-tests (6 cấu hình) + so sánh Spike + system test
```

In bảng PASS/FAIL; exit code ≠ 0 nếu có lỗi. Từng phần:

| Lệnh | Việc | Kết quả |
|---|---|---|
| `make lint` | Verilator `-Wall` trên 8 cấu hình | màn hình |
| `make unit` | 13 unit testbench | `results/unit/summary.md` |
| `make sw` | build firmware (tests: imc/uart; benchmark: i, im, imc / sim) | `build/sw/` |
| `make isa` | riscv-tests, ma trận cấu hình | `results/isa/*.md`, `*.csv` |
| `make spike` | so sánh commit log với Spike | `results/spike/*.md` |
| `make systest` | 11 system test C | `results/systest/summary.md` |
| `make perf` | 5 thí nghiệm hiệu năng + biểu đồ | `results/perf/` |
| `make synth` | Yosys (diện tích) + nextpnr ECP5 (Fmax) | `results/synth/` |
| `make cov` | code + functional coverage | `results/coverage/` |
| `make docs` | hình waveform, walkthrough, báo cáo `.docx` (nếu có pandoc) | `results/waves/`, `docs/report/` |

## 3. Chạy một test riêng

```bash
.venv/bin/python scripts/run_isa.py --config m1c1_bp2 --tests add,lw,rvc
.venv/bin/python scripts/run_systest.py --test spi_flash
.venv/bin/python scripts/run_unit.py --tb tb_uart --seed 7          # seed khác
.venv/bin/python scripts/compare_spike.py --config m1c1_bp2 --tests fence_i
```

Log ở `build/logs/...`; output UART của system test ở `build/logs/systest/<cfg>/<test>.uart.txt`.

## 4. Xem waveform bằng GTKWave

```bash
.venv/bin/python scripts/run_systest.py --test hello --trace
gtkwave build/logs/systest/m1c1_bp2/hello.fst docs/gtkw/pipeline.gtkw
```

Các file `.gtkw` trong `docs/gtkw/` đã chọn sẵn tín hiệu cho từng cảnh (pipeline, APB, UART, SPI). Trong GTKWave:
File → Read Save File để nạp `.gtkw` khác. Có thể chạy trực tiếp file thực thi với plusarg:

```bash
build/verilator/m1c1_bp2_bht256_btb32/Vtb_soc +hex=build/sw/tests/imc_uart/hello.hex \
    +trace +trace_file=hello.fst +commitlog=hello.commit.log
```

## 5. Đổi tham số rồi chạy lại thí nghiệm

Cấu hình RTL được truyền bằng `-G` khi build Verilator; trong script dùng `make_cfg(...)`:

```bash
# ví dụ: CPI của Dhrystone với BHT 64, BTB 8
.venv/bin/python - <<'PY'
import sys; sys.path.insert(0, "scripts")
from run_perf import run_bench
from common import make_cfg
r = run_bench(make_cfg(BP_MODE=2, BHT_ENTRIES=64, BTB_ENTRIES=8), "imc", "dhrystone")
print(r["cpi"], r["accuracy"])
PY
```

Đổi tham số mặc định của SoC: sửa `parameter` trong `rtl/soc_top.sv` / `tb/soc/tb_soc.sv`, hoặc thêm cấu hình vào
`CONFIGS` trong `scripts/run_isa.py`. Thay đổi RTL được phát hiện tự động (build lại khi file nguồn mới hơn).

## 6. Demo

```bash
.venv/bin/python scripts/run_systest.py --test demo
cat build/logs/systest/m1c1_bp2/demo.uart.txt
```

Demo chạy UART ở 115200 baud: timer ngắt định kỳ đọc flash và in hex, sau đó nhận lệnh `r`/`w`/`s`/`q` qua ngắt RX
(chuỗi lệnh BFM gửi nằm trong `sw/tests/demo/rx.txt`).

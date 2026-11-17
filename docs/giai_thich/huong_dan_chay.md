# Hướng dẫn tự chạy lại mọi kết quả

Mọi lệnh chạy từ thư mục gốc project. Makefile tự thêm `~/tools/oss-cad-suite/bin`, `~/tools/spike/bin`,
`~/tools/dtc/bin` vào `PATH`; Python luôn chạy bằng `.venv/bin/python`.

## 1. Chuẩn bị (một lần)

```bash
make check-env        # in phiên bản mọi công cụ, kiểm tra libgcc rv32
make fetch            # clone riscv-tests và coremark vào third_party/ (đúng commit đã ghi)
```

Máy mới (Ubuntu 24.04 chưa có công cụ nào): `bash scripts/setup_wsl.sh` cài mọi thứ ở trên với đúng phiên bản trong
`docs/env.md` (gói apt cần `sudo` một lần; OSS CAD Suite, dtc, Spike, pandoc vào `~/tools`; image OpenLane và PDK
sky130 cho `make asic` – thêm `--no-asic` để bỏ qua phần này, khoảng 10 GB). Chạy lại được nếu bị ngắt giữa chừng.

### Chạy trên Windows (WSL2)

Các công cụ đều là bản Linux, nên trên Windows chạy trong WSL2 (Ubuntu bên trong Windows). Riêng `fpga/` (Quartus II)
vẫn mở trực tiếp trên Windows.

1. PowerShell (Administrator): `wsl --install -d Ubuntu-24.04`, đặt tên người dùng và mật khẩu.
2. Docker Desktop → *Settings → Resources → WSL integration* → bật `Ubuntu-24.04` (chỉ cần cho `make asic`).
3. Cho WSL đủ RAM: file `C:\Users\<tên>\.wslconfig` gồm hai dòng `[wsl2]` và `memory=8GB`, rồi `wsl --shutdown`.
4. Chép **cả thư mục** project vào ổ Linux của WSL, ví dụ `\\wsl$\Ubuntu-24.04\home\<tên>\doanthietke` (dán vào
   thanh địa chỉ của File Explorer). Không để project ở `C:\` (`/mnt/c/...` chậm, sai quyền file) và không clone bằng
   git của Windows (đổi xuống dòng sang CRLF làm hỏng script bash – `setup_wsl.sh` sẽ dừng và báo lỗi này).
5. Trong Ubuntu: `cd ~/doanthietke && bash scripts/setup_wsl.sh`, sau đó `make regress` / `make asic` như trên Linux.

## 2. Regression đầy đủ

```bash
make regress          # lint + unit + riscv-tests (7 cấu hình) + so sánh Spike + system test
```

In bảng PASS/FAIL; exit code ≠ 0 nếu có lỗi. Từng phần:

| Lệnh           | Việc                                                                                                                                                                                | Kết quả                                            |
| -------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------- |
| `make lint`    | Verilator `-Wall` trên 9 cấu hình                                                                                                                                                   | màn hình                                           |
| `make unit`    | 14 unit testbench                                                                                                                                                                   | `results/unit/summary.md`                          |
| `make sw`      | build firmware (tests: imc/uart; benchmark: i, im, imc / sim)                                                                                                                       | `build/sw/`                                        |
| `make isa`     | riscv-tests, ma trận cấu hình                                                                                                                                                       | `results/isa/*.md`, `*.csv`                        |
| `make spike`   | so sánh commit log với Spike                                                                                                                                                        | `results/spike/*.md`                               |
| `make cosim`   | co-simulation C++ lock-step với Spike khi đang chạy + kiểm tra bằng RTL có lỗi cài sẵn                                                                                              | `results/cosim/`                                   |
| `make systest` | 11 system test C                                                                                                                                                                    | `results/systest/summary.md`                       |
| `make perf`    | 5 thí nghiệm hiệu năng + biểu đồ + bảng thông lượng                                                                                                                                 | `results/perf/` (`throughput.md`)                  |
| `make synth`   | Yosys (diện tích) + nextpnr ECP5 (Fmax)                                                                                                                                             | `results/synth/`                                   |
| `make cov`     | code + functional coverage                                                                                                                                                          | `results/coverage/`                                |
| `make docs`    | hình waveform, walkthrough, báo cáo `.docx` (nếu có pandoc)                                                                                                                         | `results/waves/`, `docs/report/`                   |
| `make fpga`    | project Quartus II cho board DE2: RTL, firmware `.mif`, mô phỏng trên cấu hình board                                                                                                | `fpga/` (xem `fpga/README.md`)                     |
| `make asic`    | layout ASIC của hai lõi bằng OpenLane 2 / sky130A (Docker) + mô phỏng gate-level so với RTL; lần đầu khoảng 1–1,5 giờ, không chạy song song việc nặng khác (đi dây cần ~4,5 GB RAM) | `results/asic/` (ảnh layout, bảng PPA, đường găng) |

Riêng `make asic`: chỉ chạy lại OpenLane khi RTL lõi hoặc `asic/<top>/config.json` thay đổi; `.venv/bin/python scripts/run_asic.py --gl` chỉ chạy lại gate-level, `--report` chỉ sinh lại bảng và ảnh, `--force` ép chạy lại OpenLane. Kết quả đầy đủ của từng lần (GDS, DEF, báo cáo từng bước) nằm trong `asic/<top>/runs/base/` (không đưa vào git). Xem GDS: file `asic/rv_core/runs/base/final/gds/rv_core.gds` mở được bằng KLayout (máy này chỉ có KLayout trong Docker image, không có giao diện; có thể chép file sang Windows và mở bằng KLayout bản Windows, kèm file màu lớp `sky130A.lyp` trong `~/.volare/.../sky130A/libs.tech/klayout/tech/`).

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

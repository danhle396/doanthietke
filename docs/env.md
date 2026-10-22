# Môi trường công cụ

Dò bằng `make check-env` (script `scripts/check_env.sh`). Máy: Ubuntu 24.04.4 LTS, kernel 6.17, 4 nhân, 7 GB RAM.

## Phiên bản công cụ

| Công cụ | Phiên bản | Đường dẫn / nguồn | Dùng cho |
|---|---|---|---|
| Verilator | 5.047 devel (rev v5.046-78-g5bf1d060c) | `~/tools/oss-cad-suite/bin` (có sẵn) | lint, mô phỏng, coverage |
| Yosys | 0.63+89 (git de99d67bb) | `~/tools/oss-cad-suite/bin` | tổng hợp |
| nextpnr-ecp5 | nextpnr-0.9-102-ge9b7da5a | `~/tools/oss-cad-suite/bin` | ước lượng Fmax trên FPGA ECP5 |
| Icarus Verilog | 14.0 (devel) | `~/tools/oss-cad-suite/bin` | dự phòng (không dùng) |
| OpenSTA | 3.0.0 | `~/.local/bin/sta` | (tùy chọn) phân tích timing sky130 |
| Liberty sky130 | `sky130_fd_sc_hd__tt_025C_1v80.lib` | `~/.volare/volare/sky130/...` | (tùy chọn) |
| RISC-V GCC | riscv64-unknown-elf-gcc 13.2.0 (Ubuntu 13.2.0-11ubuntu1+12) | `/usr/bin` | firmware, riscv-tests, benchmark |
| binutils | GNU objdump 2.42 | `/usr/bin` | |
| libgcc rv32 | `rv32im/ilp32/libgcc.a`, `rv32i/ilp32/libgcc.a` | `/usr/lib/gcc/riscv64-unknown-elf/13.2.0/` | `-lgcc` (không cần `libgcc_min.c`) |
| Spike | 1.1.1-dev, commit `436fc163a831218508378d7e7f8fd480994b64fe` | **tự build** vào `~/tools/spike` | mô hình tham chiếu |
| dtc | 1.8.1, commit `f99e3af0ecb67a9085478a9b8ddbcc25aa64931d` | **tự build** vào `~/tools/dtc` | Spike cần lúc chạy |
| make / git / g++ | GNU Make 4.3 / git 2.43.0 / g++ 13.3.0 | `/usr/bin` | |
| Python | 3.12.3, `.venv` với matplotlib 3.11.2, pyelftools 0.33 | `.venv/` trong project | script, biểu đồ |
| pandoc | không có (xem `PROGRESS.md`) | | xuất `.docx` |
| genhtml (lcov) | không có | | HTML coverage |

## Những gì đã cài thêm (không cần sudo)

1. **dtc**: `git clone --depth 1 https://github.com/dgibson/dtc.git ~/tools/src/dtc` rồi
   `make NO_PYTHON=1 NO_YAML=1 NO_VALGRIND=1 PREFIX=$HOME/tools/dtc install`.
2. **Spike**: clone `https://github.com/riscv-software-src/riscv-isa-sim` vào `~/tools/src/riscv-isa-sim`.
   - Bản master ngày 21/10/2026 (`2c300cd`) lỗi build (`specialize_upstream.h` không tìm thấy khi tạo
     precompiled header), nên dùng commit ổn định `436fc16` (12/10/2026).
   - Build lần đầu với `-g` làm đầy đĩa (3,5 GB thư mục build); build lại với
     `CFLAGS="-O2 -g0" CXXFLAGS="-O2 -g0" ../configure --prefix=$HOME/tools/spike`, sau đó xóa thư mục build.
3. **Python**: `python3 -m venv .venv && .venv/bin/pip install matplotlib pyelftools`.

Makefile và `scripts/common.py` tự thêm `~/tools/oss-cad-suite/bin`, `~/tools/spike/bin`, `~/tools/dtc/bin`
vào `PATH` (không sửa `~/.bashrc`). Toolchain RISC-V dò tự động theo thứ tự
`riscv64-unknown-elf-`, `riscv32-unknown-elf-`, `riscv-none-elf-` (biến `RISCV_PREFIX`).

## Mã nguồn bên thứ ba (`scripts/fetch_third_party.sh`)

| Repo | Commit | Ngày |
|---|---|---|
| https://github.com/riscv-software-src/riscv-tests (có submodule `env` @ `6de71ed`) | `3df703cd52d5f0d8224e3c50bf03c6cb70efff98` | 19/10/2026 |
| https://github.com/eembc/coremark | `1f483d5b8316753a742cbf5590caf5bd0a4e4777` | |

Script checkout đúng commit trên; `FETCH_LATEST=1` để lấy bản mới nhất.

## Lưu ý

- Gói `gcc-riscv64-unknown-elf` của Ubuntu có multilib `rv32i`, `rv32im`, `rv32imac` (không có `rv32imc`);
  với `-march=rv32imc` GCC chọn `rv32im/ilp32/libgcc.a` (không chứa lệnh nén – vẫn chạy đúng trên lõi có C).
- GAS tự nén lệnh khi `-march` có `c`, nên mọi phần mềm được build theo đúng biến thể (`i`, `im`, `imc`).
- Ổ đĩa còn ~3,7 GB trống: `scripts/common.py` xóa thư mục object của Verilator sau khi build,
  chỉ giữ file thực thi `build/verilator/<cấu hình>/Vtb_soc`.

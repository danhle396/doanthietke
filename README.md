# Thiết kế SoC dựa trên lõi RISC-V RV32IMC pipeline 5 tầng có dự đoán rẽ nhánh, tích hợp ngoại vi truyền thông UART và SPI

Đồ án Thiết kế 1 – Khoa Kỹ thuật Máy tính & Điện tử, VKU.
Sinh viên: Lê Thành Danh (23CE010, 23IC). GVHD: TS. Dương Ngọc Pháp.

## Nội dung

- **Lõi `rv_core`** (`rtl/core/`): RV32I + M + C + Zicsr + Zifencei + Zicntr, Machine mode, pipeline 5 tầng
  IF–ID–EX–MEM–WB, forwarding, phát hiện hazard, dự đoán rẽ nhánh cấu hình được (tĩnh / BHT ở ID / BHT + BTB ở IF),
  ngoại lệ chính xác, ngắt (direct/vectored), performance counter.
- **Lõi tham chiếu `rv_core_sc`** (`rtl/core_sc/`): RV32I single-cycle.
- **SoC `soc_top`** (`rtl/soc_top.sv`): bus **Wishbone B4** (lõi ↔ RAM 128 KB hai cổng, interconnect `dbus_xbar`,
  cầu Wishbone → **APB4**), **UART** và **SPI master** (FIFO 16, ngắt), TIMER64, GPIO 16 chân, INTC, SIM_CTRL (mô
  phỏng).
- **Phần mềm** (`sw/`): crt0, trap, printf, driver (UART, SPI, flash SPI, timer, GPIO, INTC), 11 system test,
  8 benchmark riscv-tests + CoreMark.
- **Xác minh**: 14 unit testbench, riscv-tests trên 7 cấu hình, kiểm tra giao thức Wishbone trong mọi mô phỏng, so
  sánh từng lệnh với Spike (sau khi chạy và **co-simulation C++ lock-step trong lúc chạy**), system test với BFM
  UART / SPI flash / SPI slave, code + functional coverage.
- **Đánh giá**: CPI theo chế độ dự đoán, quét kích thước BHT × BTB, hiệu quả extension C, phân rã CPI, single-cycle so
  với pipeline, diện tích (Yosys) và Fmax (nextpnr ECP5).
- **Board DE2** (`fpga/`): project Quartus II tự chứa cho Cyclone II EP2C35 – PLL 24 MHz, RAM 32 KB trên M4K
  (`ram_dp` chế độ `SYNC`), 16 firmware dựng sẵn dạng `.mif` kèm đầu ra UART mô phỏng để đối chiếu. Hướng dẫn:
  [`fpga/README.md`](fpga/README.md); sinh lại bằng `make fpga`.

## Bắt đầu nhanh

Máy mới (Ubuntu 24.04, kể cả WSL2 trên Windows): `bash scripts/setup_wsl.sh` cài toàn bộ công cụ đúng phiên bản (xem `docs/giai_thich/huong_dan_chay.md`, mục "Chạy trên Windows").

```bash
make check-env      # kiểm tra công cụ (Verilator, Yosys, RISC-V GCC, Spike, Python .venv)
make fetch          # tải riscv-tests và CoreMark (đúng commit) vào third_party/
make regress        # lint + unit + riscv-tests + Spike + system test -> bảng PASS/FAIL
```

Các bước khác: `make unit`, `make isa`, `make spike`, `make cosim`, `make systest`, `make perf`, `make synth`, `make cov`,
`make docs`, `make fpga`, `make asic` (layout ASIC của lõi bằng OpenLane/sky130 trong Docker, khoảng 1 giờ). Chạy demo: `.venv/bin/python scripts/run_systest.py --test demo` (output UART ở
`build/logs/systest/m1c1_bp2/demo.uart.txt`). Hướng dẫn chi tiết: `docs/giai_thich/huong_dan_chay.md`.

## Kết quả

| Nội dung                                                  | File                         |
| --------------------------------------------------------- | ---------------------------- |
| Unit test                                                 | `results/unit/summary.md`    |
| riscv-tests (ma trận cấu hình)                            | `results/isa/summary.md`     |
| So sánh Spike                                             | `results/spike/summary.md`   |
| Co-simulation C++ lock-step                               | `results/cosim/summary.md`   |
| Thông lượng (MIPS, DMIPS, bus/ngoại vi)                   | `results/perf/throughput.md` |
| System test                                               | `results/systest/summary.md` |
| Hiệu năng (bảng + biểu đồ)                                | `results/perf/summary.md`    |
| Diện tích, Fmax, đường găng                               | `results/synth/summary.md`   |
| Layout ASIC sky130 (PPA, DRC/LVS, ảnh layout, gate-level) | `results/asic/summary.md`    |
| Coverage                                                  | `results/coverage/`          |
| Tổng hợp kết quả                                          | `docs/results.md`            |
| Truy vết yêu cầu                                          | `docs/compliance.md`         |

## Tài liệu

- `docs/spec.md`, `docs/memory_map.md`, `docs/register_map.md`, `docs/microarch.md`, `docs/verification_plan.md`
- `docs/decisions.md` – nhật ký quyết định thiết kế; `docs/env.md` – công cụ và phiên bản
- `docs/giai_thich/` – giải thích từng khối, walkthrough pipeline, câu hỏi bảo vệ
- `docs/report/` – báo cáo 5 chương (`baocao.docx` khi có pandoc)

## Cấu trúc thư mục

```
rtl/        RTL (pkg, core, core_sc, mem, bus, periph, soc_top)
tb/         unit/, bfm/, soc/ (tb_soc), cov/ (functional coverage), fpga/, asic/ (gate-level)
sw/         common/, drivers/, tests/, benchmarks/, examples/, riscv-tests-env/, fpga/
cosim/      harness C++ co-simulation với Spike
scripts/    build, run, so sánh Spike, perf, coverage, synth, waveform, fpga, asic
syn/        script Yosys
fpga/       project Quartus II cho board DE2 (tự chứa)
asic/       cấu hình OpenLane cho rv_core, rv_core_sc (runs/ không đưa vào git)
results/    kết quả (có trong git)
docs/       tài liệu
```

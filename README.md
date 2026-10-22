# Thiết kế SoC dựa trên lõi RISC-V RV32IMC pipeline 5 tầng có dự đoán rẽ nhánh, tích hợp ngoại vi truyền thông UART và SPI

Đồ án Thiết kế 1 – Khoa Kỹ thuật Máy tính & Điện tử, VKU.
Sinh viên: Lê Thành Danh (23CE010, 23IC). GVHD: TS. Dương Ngọc Pháp.

## Nội dung

- **Lõi `rv_core`** (`rtl/core/`): RV32I + M + C + Zicsr + Zifencei + Zicntr, Machine mode, pipeline 5 tầng
  IF–ID–EX–MEM–WB, forwarding, phát hiện hazard, dự đoán rẽ nhánh cấu hình được (tĩnh / BHT ở ID / BHT + BTB ở IF),
  ngoại lệ chính xác, ngắt (direct/vectored), performance counter.
- **Lõi tham chiếu `rv_core_sc`** (`rtl/core_sc/`): RV32I single-cycle.
- **SoC `soc_top`** (`rtl/soc_top.sv`): RAM 128 KB hai cổng, `dbus_xbar`, cầu APB4, **UART** và **SPI master** (FIFO
  16, ngắt), TIMER64, GPIO 16 chân, INTC, SIM_CTRL (mô phỏng).
- **Phần mềm** (`sw/`): crt0, trap, printf, driver (UART, SPI, flash SPI, timer, GPIO, INTC), 11 system test,
  8 benchmark riscv-tests + CoreMark.
- **Xác minh**: 13 unit testbench, riscv-tests trên 6 cấu hình, so sánh từng lệnh với Spike, system test với BFM
  UART / SPI flash / SPI slave, code + functional coverage.
- **Đánh giá**: CPI theo chế độ dự đoán, quét kích thước BHT × BTB, hiệu quả extension C, phân rã CPI, single-cycle so
  với pipeline, diện tích (Yosys) và Fmax (nextpnr ECP5).

## Bắt đầu nhanh

```bash
make check-env      # kiểm tra công cụ (Verilator, Yosys, RISC-V GCC, Spike, Python .venv)
make fetch          # tải riscv-tests và CoreMark (đúng commit) vào third_party/
make regress        # lint + unit + riscv-tests + Spike + system test -> bảng PASS/FAIL
```

Các bước khác: `make unit`, `make isa`, `make spike`, `make systest`, `make perf`, `make synth`, `make cov`,
`make docs`. Chạy demo: `.venv/bin/python scripts/run_systest.py --test demo` (output UART ở
`build/logs/systest/m1c1_bp2/demo.uart.txt`). Hướng dẫn chi tiết: `docs/giai_thich/huong_dan_chay.md`.

## Kết quả

| Nội dung | File |
|---|---|
| Unit test | `results/unit/summary.md` |
| riscv-tests (ma trận cấu hình) | `results/isa/summary.md` |
| So sánh Spike | `results/spike/summary.md` |
| System test | `results/systest/summary.md` |
| Hiệu năng (bảng + biểu đồ) | `results/perf/summary.md` |
| Diện tích, Fmax, đường găng | `results/synth/summary.md` |
| Coverage | `results/coverage/` |
| Tổng hợp kết quả | `docs/results.md` |
| Truy vết yêu cầu | `docs/compliance.md` |

## Tài liệu

- `docs/spec.md`, `docs/memory_map.md`, `docs/register_map.md`, `docs/microarch.md`, `docs/verification_plan.md`
- `docs/decisions.md` – nhật ký quyết định thiết kế; `docs/env.md` – công cụ và phiên bản
- `docs/giai_thich/` – giải thích từng khối, walkthrough pipeline, câu hỏi bảo vệ
- `docs/report/` – báo cáo 5 chương (`baocao.docx` khi có pandoc)

## Cấu trúc thư mục

```
rtl/        RTL (pkg, core, core_sc, mem, bus, periph, soc_top)
tb/         unit/, bfm/, soc/ (tb_soc), cov/ (functional coverage)
sw/         common/, drivers/, tests/, benchmarks/, examples/, riscv-tests-env/
scripts/    build, run, so sánh Spike, perf, coverage, synth, waveform
syn/        script Yosys
results/    kết quả (có trong git)
docs/       tài liệu
```

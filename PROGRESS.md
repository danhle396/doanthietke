# PROGRESS

## Phase hiện tại

Phase 5 – đang thực hiện

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
- [ ] rv32mi
- [ ] tb_csr, tb_apb_bridge, tb_intc

### Phase 6 – Ngoại vi
- [ ] sync_fifo, UART, SPI, TIMER64, GPIO, BFM
- [ ] unit TB ngoại vi pass

### Phase 7 – SoC, firmware, perf, coverage, synth
- [ ] system tests (mục 10.4)
- [ ] benchmark, run_perf.py
- [ ] coverage
- [ ] synth
- [ ] docs/results.md

### Phase 8 – Tài liệu
- [ ] docs/giai_thich/
- [ ] docs/report/
- [ ] docs/compliance.md
- [ ] Nghiệm thu mục 17

## Kết quả regression gần nhất

- 22/10/2026 Phase 1: `run_isa.py --config sc` rv32ui 41 PASS / 0 FAIL / 1 EXCLUDED (ma_data); `compare_spike.py --config sc` 41/41 MATCH; hello (CONSOLE=sim) PASS trên sc và m1c1_bp2; lint sạch 8 cấu hình; Yosys elaborate rv_core_sc/rv_core/soc_top OK.
- 22/10/2026 Phase 2: ma trận riscv-tests (6 cấu hình) 0 FAIL; Spike 4 cấu hình MATCH (KNOWN: marchid, misa); tb_alu (15440 checks), tb_regfile (40134 checks) PASS; lint sạch.
- 22/10/2026 Phase 3: ma trận riscv-tests 0 FAIL (rv32um, rv32uc pass); tb_muldiv (4316 checks, latency chia 33), tb_compressed_decoder (1061 vector + 43 illegal) PASS.
- 22/10/2026 Phase 4: riscv-tests BP_MODE 0/1/2 0 FAIL; tb_bp PASS (6304 checks); 8 benchmark (dhrystone, median, multiply, qsort, rsort, towers, vvadd, memcpy) chạy trên mọi biến thể, khớp Spike (taint tracking cho counter); Dhrystone CPI 1.434 (BP0) / 1.209 (BP2) trên m1c1.

## BLOCKED

(trống)

## Ghi chú cho lần chạy sau

- Thư mục gốc: `/home/danhle/Desktop/doanthietke`.
- Công cụ: OSS CAD Suite ở `~/tools/oss-cad-suite`, Spike ở `~/tools/spike`, dtc ở `~/tools/dtc`.

# Ma trận truy vết yêu cầu

Mỗi yêu cầu của `PROJECT_SPEC.md` mục 3–12 → file hiện thực → test/bằng chứng → trạng thái.
"ĐẠT" chỉ được ghi khi bằng chứng tương ứng PASS trong `results/` ở lần chạy gần nhất (`results/regress.md`).

## Mục 3 – Bản đồ bộ nhớ

| Yêu cầu                                             | Hiện thực                                                | Bằng chứng                                                            | Trạng thái |
| --------------------------------------------------- | -------------------------------------------------------- | --------------------------------------------------------------------- | ---------- |
| RAM 128 KB tại `0x8000_0000`, reset PC              | `rtl/mem/ram_dp.sv`, `rtl/core/if_stage.sv` (`RESET_PC`) | mọi riscv-test, system test                                           | ĐẠT        |
| UART/SPI/TIMER/GPIO/INTC/SIM_CTRL ở slot 0–4, 15    | `rtl/soc_top.sv`                                         | system test `hello`, `spi_*`, `timer_irq`, `gpio_irq`, `irq_priority` | ĐẠT        |
| Slot trống → PSLVERR (→ Wishbone `ERR`)             | `rtl/bus/apb_bridge.sv` (`SLOT_MASK`)                    | `tb_apb_bridge`, system test `exceptions` (apb empty slot)            | ĐẠT        |
| Vùng khác → access fault (fetch 1, load 5, store 7) | `rtl/bus/dbus_xbar.sv`, `ram_dp` (Wishbone `ERR`)        | `exceptions`, `tb_dbus_xbar`                                          | ĐẠT        |

## Mục 4 – Lõi

| Yêu cầu                                                                          | Hiện thực                                                                    | Bằng chứng                                                                                         | Trạng thái                                   |
| -------------------------------------------------------------------------------- | ---------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- | -------------------------------------------- |
| Tham số RESET_PC, ENABLE_M, ENABLE_C, BP_MODE, BHT/BTB_ENTRIES                   | `rtl/core/rv_core.sv`                                                        | ma trận riscv-tests (7 cấu hình), quét 16 cấu hình BHT×BTB                                         | ĐẠT                                          |
| `misa = 0x4000_1104` (đầy đủ)                                                    | `rtl/core/csr_file.sv`                                                       | `tb_csr`; Spike KNOWN (misa writable trong Spike)                                                  | ĐẠT                                          |
| Port lõi: master Wishbone B4 (ibus chỉ đọc, dbus giữ tới ACK/ERR)                | `rv_core.sv`, `rv_core_sc.sv`, `if_stage.sv`, `mem_stage.sv`                 | `wb_checker` trong mọi mô phỏng `tb_soc` (0 vi phạm), system test với APB wait                     | ĐẠT                                          |
| Load/store không căn lề → trap 4/6, không request                                | `rtl/core/lsu.sv`, `mem_stage.sv`                                            | `rv32mi-p-ma_addr`, `*-misaligned`, `exceptions`                                                   | ĐẠT                                          |
| 4 thanh ghi pipeline có `valid`, mang pc/insn_raw/is_c/pred_npc/exc              | `*_stage.sv`                                                                 | Spike lock-step (commit log dùng insn_raw)                                                         | ĐẠT                                          |
| Lệnh có ngoại lệ là NOP                                                          | `id_stage.sv` (xóa cờ), `ex_stage.sv`, `mem_stage.sv`                        | `rv32mi-p-illegal`, `exceptions`                                                                   | ĐẠT                                          |
| IF: is_c, seq_npc, ibus_err, dự đoán mode 2, ưu tiên PC                          | `if_stage.sv`                                                                | `rv32uc-p-rvc`, `exceptions` (fetch fault), BP mode 2 runs                                         | ĐẠT                                          |
| ID: giải nén C ở ID, regfile write-through, redirect ID mode ≥1/1                | `id_stage.sv`, `compressed_decoder.sv`, `regfile.sv`                         | `tb_compressed_decoder`, `tb_regfile`, BP1/BP2 riscv-tests                                         | ĐẠT                                          |
| ID: illegal, ECALL 11, EBREAK 3 (mtval = pc)                                     | `id_stage.sv`, `decoder.sv`                                                  | `rv32mi-p-illegal/scall/sbreak`, `exceptions`                                                      | ĐẠT                                          |
| EX: ALU, actual_npc, sai dự đoán `actual_npc != pred_npc`, flush 2               | `ex_stage.sv`, `branch_unit.sv`, `alu.sv`                                    | `tb_alu`, riscv-tests nhánh, `walkthrough` (hình W4)                                               | ĐẠT                                          |
| EX: cập nhật BHT/BTB, xóa entry alias                                            | `ex_stage.sv`, `bp/*.sv`                                                     | `tb_bp`; system test `branch_smc` (self-modifying code tạo BTB alias), cover `c_mispred_btb_alias` | ĐẠT                                          |
| ENABLE_C=0: đích bit1=1 → misaligned (mcause 0, không redirect)                  | `ex_stage.sv`                                                                | `rv32mi-p-ma_fetch` (m1c0, m0c0), `exceptions` trên m1c0                                           | ĐẠT                                          |
| MEM: LSU, CSR RMW ở MEM, trap ở MEM, MRET/FENCE.I ở MEM                          | `mem_stage.sv`, `csr_file.sv`                                                | `rv32mi-p-csr/mcsr`, `rv32ui-p-fence_i`, `branch_smc`, `irq_priority`                              | ĐẠT                                          |
| WB: ghi regfile, minstret, hpm, commit log                                       | `wb_stage.sv`                                                                | `rv32mi-p-instret_overflow`, `zicntr`, so sánh Spike                                               | ĐẠT                                          |
| Forward ex_mem (không load/CSR) > mem_wb, kể cả store data                       | `forward_unit.sv`, `ex_stage.sv`                                             | riscv-tests bypass, cover `c_fwd_*`, walkthrough                                                   | ĐẠT                                          |
| Load-use / CSR-use stall 1 chu kỳ; MulDiv stall; chờ bus                         | `hazard_unit.sv`                                                             | cover `c_stall_*`, walkthrough, hpm 7/8/9                                                          | ĐẠT                                          |
| Flush theo nguồn; tầng già thắng; flush hủy divider                              | `hazard_unit.sv`, `muldiv.sv` (`kill`)                                       | `tb_muldiv` (abort), `irq_during_div`                                                              | ĐẠT                                          |
| Side effect đúng một lần khi rời tầng                                            | `hazard_unit.sv` (`ex_redirect`/`id_redirect` gated), `ex_stage.sv` (`fire`) | Spike lock-step với APB wait trong benchmark/system test                                           | ĐẠT                                          |
| BHT 2 bit reset 01, chỉ số pc[log2:1]; BTB direct-mapped {valid,tag,target,type} | `bp/bht.sv`, `bp/btb.sv`                                                     | `tb_bp`                                                                                            | ĐẠT                                          |
| RAS (tùy chọn)                                                                   | –                                                                            | –                                                                                                  | KHÔNG LÀM (tùy chọn; ghi ở hướng phát triển) |
| M: nhân 1 chu kỳ 33×33; chia radix-2 ~32–34 chu kỳ; trường hợp đặc biệt          | `muldiv.sv`                                                                  | `tb_muldiv` (latency 33), `rv32um-p-*`                                                             | ĐẠT                                          |
| C: đủ RV32C (trừ FP), encoding illegal                                           | `compressed_decoder.sv`                                                      | `tb_compressed_decoder` (1061 vector + 43 illegal), `rv32uc-p-rvc`                                 | ĐẠT                                          |
| CSR theo bảng 4.8, read-only → illegal                                           | `csr_file.sv`                                                                | `tb_csr`, `rv32mi-p-csr`, `mcsr`, `zicntr`                                                         | ĐẠT                                          |
| Ưu tiên ngoại lệ, mcause/mtval                                                   | `id_stage.sv`, `mem_stage.sv`                                                | `exceptions`, `rv32mi-p-*`                                                                         | ĐẠT                                          |
| `take_irq`, MEI > MSI > MTI, chặn dbus_req                                       | `mem_stage.sv`, `csr_file.sv`                                                | `irq_priority`, `timer_irq`, `tb_csr`                                                              | ĐẠT                                          |
| mtvec direct + vectored                                                          | `csr_file.sv`                                                                | `irq_priority` (kiểm slot vector), `tb_csr`                                                        | ĐẠT                                          |
| Performance counter 3..10                                                        | `csr_file.sv`, `wb_stage.sv`, `hazard_unit.sv`                               | `tb_csr`, `[bench]` output, `results/perf`                                                         | ĐẠT                                          |

## Mục 5 – Bộ nhớ

| Yêu cầu                                                               | Hiện thực                           | Bằng chứng                                | Trạng thái |
| --------------------------------------------------------------------- | ----------------------------------- | ----------------------------------------- | ---------- |
| Cổng I đọc tổ hợp, ghép nửa word khi addr[1]=1, 0 khi vượt            | `ram_dp.sv`                         | `rv32uc-p-rvc`, cover `c_insn32_straddle` | ĐẠT        |
| Cổng D đọc tổ hợp, ghi byte enable, ready ngay                        | `ram_dp.sv`                         | riscv-tests load/store                    | ĐẠT        |
| `$readmemh` từ `+hex=` trong ifndef SYNTHESIS; black box khi tổng hợp | `ram_dp.sv`, `syn/synth_generic.ys` | mọi mô phỏng; `results/synth`             | ĐẠT        |

## Mục 6 – Bus

| Yêu cầu                                                                              | Hiện thực       | Bằng chứng                                                                      | Trạng thái |
| ------------------------------------------------------------------------------------ | --------------- | ------------------------------------------------------------------------------- | ---------- |
| dbus_xbar: interconnect Wishbone RAM / APB / lỗi                                     | `dbus_xbar.sv`  | `tb_dbus_xbar`, `exceptions`                                                    | ĐẠT        |
| Cầu Wishbone → APB4: FSM, chốt khi SETUP, PSTRB=0 khi đọc, PSLVERR → ERR, slot trống | `apb_bridge.sv` | `tb_apb_bridge` (giao thức APB kiểm bởi slave model, Wishbone bởi `wb_checker`) | ĐẠT        |
| Quy ước slave (PSTRB, push, pop 1 lần, PSLVERR offset lạ)                            | `rtl/periph/*`  | `tb_uart`, `tb_spi`, `tb_timer`, `tb_gpio`, `tb_intc`                           | ĐẠT        |

## Mục 7 – Ngắt

| Yêu cầu                                              | Hiện thực                          | Bằng chứng                               | Trạng thái |
| ---------------------------------------------------- | ---------------------------------- | ---------------------------------------- | ---------- |
| mtip/msip từ TIMER, meip = \|(PENDING & ENABLE)      | `soc_top.sv`, `intc_apb.sv`        | `timer_irq`, `irq_priority`, `tb_intc`   | ĐẠT        |
| Nguồn INTC: UART, SPI, GPIO theo mức; ISR đọc ACTIVE | `intc_apb.sv`, `sw/drivers/intc.c` | `uart_irq_echo`, `spi_flash`, `gpio_irq` | ĐẠT        |

## Mục 8 – Ngoại vi

| Yêu cầu                                                                           | Hiện thực                         | Bằng chứng                               | Trạng thái                                  |
| --------------------------------------------------------------------------------- | --------------------------------- | ---------------------------------------- | ------------------------------------------- |
| sync_fifo FWFT, full/empty/level, push+pop                                        | `rtl/periph/sync_fifo.sv`         | `tb_fifo`                                | ĐẠT                                         |
| UART: 8 bit LSB, parity, 1/2 stop, RX 2FF ×16, start check giữa bit, register map | `rtl/periph/uart/*`               | `tb_uart`, `hello`, `uart_irq_echo`      | ĐẠT                                         |
| SPI master: 4 mode, MSB/LSB, CS phần mềm, FIFO, DONE/OVERRUN                      | `rtl/periph/spi/*`                | `tb_spi`, `spi_modes`, `spi_flash`       | ĐẠT                                         |
| TIMER64 register map, mtip theo mức, prescale                                     | `rtl/periph/timer/timer64_apb.sv` | `tb_timer`, `timer_irq`                  | ĐẠT (IP ĐACS4 không có – tự hiện thực, D15) |
| GPIO 16 chân, IN 2FF, ngắt cạnh, W1C                                              | `rtl/periph/gpio/gpio_apb.sv`     | `tb_gpio`, `gpio_irq`                    | ĐẠT                                         |
| INTC PENDING/ENABLE/ACTIVE                                                        | `rtl/periph/intc/intc_apb.sv`     | `tb_intc`                                | ĐẠT                                         |
| SIM_CTRL PUTCHAR/EXIT                                                             | `rtl/periph/sim/sim_ctrl.sv`      | mọi benchmark (CONSOLE=sim), system test | ĐẠT                                         |

## Mục 9 – soc_top

| Yêu cầu                                     | Hiện thực                           | Bằng chứng                        | Trạng thái |
| ------------------------------------------- | ----------------------------------- | --------------------------------- | ---------- |
| Port, tham số, rst_sync, CORE_SC            | `rtl/soc_top.sv`, `rtl/rst_sync.sv` | ma trận (sc), lint 9 cấu hình     | ĐẠT        |
| Một TB top `tb_soc` cho mọi loại test, `-G` | `tb/soc/tb_soc.sv`                  | `scripts/common.py` (`build_soc`) | ĐẠT        |
| Mỗi cấu hình build Verilator một lần        | `build/verilator/<cfg>/Vtb_soc`     | `scripts/common.py`               | ĐẠT        |

## Mục 10 – Xác minh

| Yêu cầu                                                              | Hiện thực                                                            | Bằng chứng                                                                                                                  | Trạng thái |
| -------------------------------------------------------------------- | -------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- | ---------- |
| 10.1 unit TB tự kiểm tra, seed, `make unit`                          | `tb/unit/*`, `scripts/run_unit.py`                                   | `results/unit/summary.md`                                                                                                   | ĐẠT        |
| BFM apb_master, uart, spi_slave, spi_flash                           | `tb/bfm/*`                                                           | dùng trong unit + system test                                                                                               | ĐẠT        |
| 10.2 riscv-tests env riêng, ma trận, loại trừ có lý do               | `sw/riscv-tests-env/p/*`, `scripts/run_isa.py`, `isa_exclusions.txt` | `results/isa/summary.md`                                                                                                    | ĐẠT        |
| 10.3 commit log + so sánh Spike                                      | `wb_stage.sv`, `scripts/compare_spike.py`                            | `results/spike/summary.md`                                                                                                  | ĐẠT        |
| 10.4 system test (10 test của spec + `branch_smc`), `run_systest.py` | `sw/tests/*`, `tb/soc/tb_soc_bfms.svh`                               | `results/systest/summary.md`                                                                                                | ĐẠT        |
| 10.5 code + functional coverage (line ≥ 90% core/periph)             | `scripts/run_cov.py`, `tb/cov/*`, `scripts/cov_report.py`            | `results/coverage/summary.md` (line rtl/core 99,8%, rtl/periph 97,5%), `functional.md` (71/71), `uncovered.md` (giải thích) | ĐẠT        |

## Mục 11 – Phần mềm

| Yêu cầu                                                                                      | Hiện thực                      | Bằng chứng                           | Trạng thái |
| -------------------------------------------------------------------------------------------- | ------------------------------ | ------------------------------------ | ---------- |
| crt0, exit (SIM_CTRL rồi tohost), link.ld (tohost/fromhost, stack 8 KB), trap_entry + vector | `sw/common/*`                  | system test, so sánh Spike benchmark | ĐẠT        |
| platform.h, csr.h, perf.h, xprintf, libc_min                                                 | `sw/common/*`                  | build mọi chương trình               | ĐẠT        |
| Driver polling + ngắt                                                                        | `sw/drivers/*`                 | system test                          | ĐẠT        |
| libgcc rv32 có sẵn (không cần libgcc_min)                                                    | toolchain Ubuntu               | `make check-env`                     | ĐẠT        |
| CONSOLE=uart/sim                                                                             | `sw/common/xprintf.c`, `sys.c` | benchmark (sim), system test (uart)  | ĐẠT        |
| elf2hex                                                                                      | `scripts/elf2hex.py`           | mọi mô phỏng                         | ĐẠT        |
| Benchmark riscv-tests (8) + CoreMark                                                         | `sw/benchmarks/*`              | `results/perf/*`                     | ĐẠT        |

## Mục 12 – Hiệu năng và tổng hợp

| Yêu cầu                                        | Hiện thực                             | Bằng chứng                                          | Trạng thái |
| ---------------------------------------------- | ------------------------------------- | --------------------------------------------------- | ---------- |
| 5 thí nghiệm, CSV, bảng, biểu đồ               | `scripts/run_perf.py`                 | `results/perf/*` (exp1–exp5 CSV, PNG, `summary.md`) | ĐẠT        |
| Kiểm tra hợp lý (Dhrystone CPI 1–2, BP2 ≤ BP0) | `run_perf.py`                         | `results/perf/summary.md`                           | ĐẠT        |
| Tổng hợp generic + Fmax (ECP5 nextpnr)         | `syn/*.ys`, `scripts/synth_report.py` | `results/synth/summary.md`                          | ĐẠT        |

## Mục 13–17 – Quy trình và tài liệu

| Yêu cầu                                                                                                 | Hiện thực                                                          | Bằng chứng                                              | Trạng thái |
| ------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------ | ------------------------------------------------------- | ---------- |
| Makefile: check-env, fetch, lint, unit, sw, isa, spike, systest, perf, cov, synth, docs, regress, clean | `Makefile`                                                         | `make regress` từ bản clone sạch (`results/regress.md`) | ĐẠT        |
| Cấu trúc thư mục mục 14                                                                                 | toàn repo                                                          | –                                                       | ĐẠT        |
| `docs/giai_thich/` đủ file, walkthrough, hướng dẫn chạy, ≥ 50 câu hỏi                                   | `docs/giai_thich/*`                                                | 70 câu trong `bao_ve_QA.md`                             | ĐẠT        |
| Báo cáo 5 chương, hình/bảng có số và nguồn, `.docx`                                                     | `docs/report/*`                                                    | `docs/report/baocao.docx` (pandoc 3.6.4)                | ĐẠT        |
| Hình Mermaid/WaveDrom + waveform từ VCD                                                                 | `docs/report/hinh/`, `scripts/vcd2png.py`, `scripts/make_waves.py` | `results/waves/*.png`                                   | ĐẠT        |
| `.gtkw` cho các cảnh waveform                                                                           | `docs/gtkw/*.gtkw`                                                 | –                                                       | ĐẠT        |

## Bổ sung ngoài spec (yêu cầu của đề cương)

| Yêu cầu                                                                  | Hiện thực                                                                                                                      | Bằng chứng                                                                                                                                                                               | Trạng thái                                             |
| ------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------ |
| SoC interconnect theo chuẩn (Wishbone)                                   | `rv_core.sv`, `rv_core_sc.sv`, `ram_dp.sv`, `dbus_xbar.sv`, `apb_bridge.sv` (D28)                                              | `wb_checker` trên 4 liên kết trong mọi mô phỏng `tb_soc` (0 vi phạm); `tb_dbus_xbar`; số chu kỳ 9 benchmark trùng khớp trước/sau                                                         | ĐẠT                                                    |
| RAM dùng được block RAM đồng bộ của FPGA                                 | `ram_dp.sv` (`SYNC`), `ram_bank16.sv` (D27)                                                                                    | riscv-tests `m1c1_bp2_sync` 64/64, Spike 64/64, số chu kỳ trùng khớp                                                                                                                     | ĐẠT                                                    |
| Project FPGA cho board DE2 (Quartus II, gán chân, PLL, firmware `.mif`)  | `fpga/`, `scripts/make_fpga.py`                                                                                                | 16 firmware mô phỏng PASS trên cấu hình board; `de2_top` mô phỏng với stub PASS; elaborate Yosys sạch                                                                                    | ĐẠT (mô phỏng)                                         |
| Co-simulation Verilator + C/C++ + firmware, lock-step với Spike khi chạy | `cosim/cosim_main.cpp`, DPI-C trong `wb_stage.sv`, `scripts/run_cosim.py` (D29)                                                | `results/cosim/summary.md` (259/259, ~8,3 triệu lệnh); RTL có lỗi cài sẵn bị bắt (`mutant.md`)                                                                                           | ĐẠT                                                    |
| Waveform chứng minh lock-step                                            | `scripts/run_cosim.py` (`+trace_csv`)                                                                                          | `results/cosim/lockstep.png` (Hình 4.11)                                                                                                                                                 | ĐẠT                                                    |
| Bảng thông lượng (MIPS, DMIPS, CoreMark, bus/ngoại vi)                   | `scripts/throughput.py`                                                                                                        | `results/perf/throughput.md` (Bảng 4.15–4.17)                                                                                                                                            | ĐẠT                                                    |
| Layout ASIC (RTL → GDSII) và PPA trên quy trình thật                     | `asic/<top>/config.json`, `scripts/run_asic.py`, `tb/asic/tb_core_gl.v` (D30)                                                  | `results/asic/summary.md`: hai lõi DRC/LVS/XOR = 0, Fmax 3 góc PVT, công suất ước lượng (Bảng 4.18, Hình 4.12–4.13); gate-level netlist sau đi dây ≡ RTL trên 64/64 và 41/41 riscv-tests | ĐẠT (chỉ lõi; còn vi phạm antenna/slew ghi trong bảng) |
| Compile Quartus, timing, nạp board, đo thực nghiệm, công suất            | `fpga/README.md` (hướng dẫn)                                                                                                   | –                                                                                                                                                                                        | CHƯA – chờ chạy trên máy có Quartus II và board        |
| Sơ đồ hệ thống chỉnh sửa được                                            | `docs/diagrams/so_do_khoi.drawio` (7 trang), ảnh xuất `docs/diagrams/png/` | –                                                                                                                                                                                        | ĐẠT                                                    |

# Coverage

Gộp mọi lần chạy: unit testbench, riscv-tests (cả ma trận cấu hình), system test, benchmark (m1c1_bp2, m1c1_bp1, sc). Công cụ: Verilator `--coverage-line --coverage-toggle --coverage-user`, gộp bằng `verilator_coverage`. Tái tạo: `make cov`. (Không có `genhtml` trên máy nên không xuất HTML; file lcov: `build/cov/line.info`.)

## Bảng C1 – Theo thư mục (mục tiêu line ≥ 90% cho rtl/core và rtl/periph)

| Thư mục    | Line            | Toggle           |
| ---------- | --------------- | ---------------- |
| rtl (khác) | 100.0% (98/98)  | 97.8% (180/184)  |
| rtl/core   | 99.8% (592/593) | 100.0% (477/477) |
| rtl/periph | 97.5% (119/122) | 98.6% (212/215)  |

## Bảng C2 – Theo file

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

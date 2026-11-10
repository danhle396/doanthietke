# Kế hoạch xác minh

Ba mức, chạy chung bằng `make regress` (lint + unit + riscv-tests ma trận + so sánh Spike + system test).

## Mức 1 – Unit testbench (`tb/unit`, `make unit`)

Testbench SystemVerilog tự kiểm tra, Verilator `--binary --timing`, có test có hướng và ngẫu nhiên với `+seed=`.
PASS = exit code 0 và dòng `PASS`.

| Testbench | Nội dung |
|---|---|
| `tb_alu` | mọi phép × 12 giá trị biên × 12, 14.000 vector ngẫu nhiên, so mô hình |
| `tb_regfile` | x0, write-through 2 cổng, 20.000 thao tác ngẫu nhiên |
| `tb_muldiv` | 8 phép × 8×8 giá trị biên (0, ±1, INT_MIN, INT_MAX, …), chia 0, tràn, ngẫu nhiên, giữ kết quả khi EX stall, hủy (kill) giữa chừng, độ trễ chia |
| `tb_compressed_decoder` | mọi lệnh RV32C với toán hạng biên + ngẫu nhiên; kỳ vọng sinh bằng GNU as (`.option rvc` / `.option norvc`) đọc qua `objdump`; 43 encoding illegal/reserved |
| `tb_bp` | BHT bão hòa 2 chiều, BTB hit/miss/alias/thay thế/xóa, wrapper mode 1 và 2 |
| `tb_csr` | reset, RW/RS/RC, mặt nạ WARL, illegal (không tồn tại / ghi read-only), trap/mret, vectored, ưu tiên ngắt, counter |
| `tb_fifo` | full/empty/level, push+pop đồng thời, FWFT, ngẫu nhiên (độ sâu 4 và 16) |
| `tb_apb_bridge` | cầu Wishbone → APB4: 2 slave có wait state ngẫu nhiên, PSLVERR → ERR, slot trống, kiểm tra giao thức APB và Wishbone |
| `tb_dbus_xbar` | interconnect Wishbone: biên vùng RAM/APB, vùng trống → ERR cùng chu kỳ, 4.000 truy cập ngẫu nhiên (slave APB có wait state, ERR), định tuyến CYC/STB, mux phản hồi, `wb_checker` trên 3 liên kết |
| `tb_uart` | loopback 6 định dạng × 3 baud, lỗi frame/parity, overrun, false start, ngắt watermark |
| `tb_spi` | 4 mode × MSB/LSB × 3 CLK_DIV với `spi_slave_bfm`, chu kỳ SCLK, DONE/overrun, flash mode 0/3 |
| `tb_timer`, `tb_gpio`, `tb_intc` | mọi thanh ghi, ngắt, PSTRB, PSLVERR |

BFM và checker (`tb/bfm`): `wb_checker` (giao thức Wishbone B4 classic), `apb_master_bfm`, `apb_slave_model`, `uart_bfm`, `spi_slave_bfm` (4 mode, chế độ echo),
`spi_flash_bfm` (W25Q rút gọn: 9F, 03, 06, 04, 02, 05, 20).

## Mức 2 – Lõi: riscv-tests + Spike (`make isa`, `make spike`)

- Môi trường riêng `sw/riscv-tests-env/p` (chỉ M-mode).
- Ma trận: `m1c1` × BP_MODE 0/1/2 (ELF `imc`), `m1c0_bp2` (`im`), `m0c0_bp2` (`i`), single-cycle (`i`, rv32ui),
  `m1c1_bp2_sync` (RAM đồng bộ 32 KB của board DE2, D27).
- Loại trừ có lý do: `rv32ui-p-ma_data`, `rv32mi-p-breakpoint`, `rv32mi-p-pmpaddr` (xem `results/isa/summary.md`).
- So sánh commit log với `spike --log-commits` cho mọi riscv-test và benchmark (CONSOLE=sim), có taint tracking cho
  giá trị counter (D19).
- Co-simulation C++ (`make cosim`, D29): cùng phép so sánh nhưng **trong lúc chạy** – harness Verilator C++ + Spike
  qua pipe + DPI-C ở WB, dừng tại lệnh sai đầu tiên; kiểm chứng harness bằng RTL có lỗi cài sẵn (`-DCOSIM_MUTANT`).

## Mức 3 – Hệ thống (`sw/tests`, `make systest`)

Firmware C chạy trên `tb_soc` với BFM UART, flash SPI (CS0), SPI slave (CS1), GPIO loopback + kích thích.
Tiêu chí: mã thoát SIM_CTRL = 0, output UART khớp file kỳ vọng (`*` cho số phụ thuộc thời gian), BFM không thấy lỗi,
0 vi phạm giao thức Wishbone (`wb_checker` trên ibus, dbus, cổng dữ liệu RAM, cầu APB – chạy trong mọi mô phỏng
`tb_soc`, kể cả riscv-tests và benchmark).

| Test | Kiểm tra |
|---|---|
| `hello` | printf qua UART |
| `uart_irq_echo` | echo bằng ngắt RX, overrun |
| `spi_flash` | JEDEC ID, xóa sector, ghi page, đọc lại, WIP, ngắt DONE, mode 3 |
| `spi_modes` | 4 mode × MSB/LSB × 2 tốc độ, dữ liệu hai chiều |
| `timer_irq` | 8 ngắt định kỳ, khoảng cách và độ trễ |
| `gpio_irq` | output loopback, ngắt cạnh lên/xuống |
| `irq_priority` | MEI > MSI > MTI, mtvec direct và vectored (kiểm tra slot vector) |
| `exceptions` | illegal, ecall, ebreak, misaligned, access fault (kể cả slot APB trống), fetch fault, instruction-misaligned (cấu hình không C) |
| `irq_during_div` | ngắt khi bộ chia chạy, kết quả đúng |
| `demo` | kịch bản trình diễn ở 115200 baud |
| `branch_smc` | (bổ sung) trap ngay sau nhánh đoán sai; self-modifying code + FENCE.I làm BTB alias |

## Coverage (`make cov`)

Code coverage (line + toggle) gộp unit + ISA + system + benchmark; functional coverage bằng `cover property`
trong `tb/cov` (opcode, lệnh M, lệnh nén, 4 đường forward, các loại stall, sai dự đoán theo loại, BTB, mọi mcause,
ngắt khi đang chia, trap sau nhánh sai, lệnh vắt qua word, mode SPI, định dạng UART, FIFO đầy/rỗng).
Kết quả: `results/coverage/`.

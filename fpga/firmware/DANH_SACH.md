# Firmware cho board DE2

Sinh bởi `scripts/make_fpga.py`. CPU 24 MHz, UART 115200 8N1, RAM 32 KB.
Chọn firmware: `chon_firmware.bat <tên>` rồi Update Memory Initialization File → Assembler → nạp lại (xem `README.md`).
`uart_sim.txt`: đầu ra UART của **cùng file nhị phân** khi mô phỏng RTL (cấu hình RAM của board); trên board phải thấy nội dung tương tự (số chu kỳ trùng khớp).

| Firmware | Nội dung | Cần thêm | Mô phỏng | Kết quả mô phỏng |
|---|---|---|---|---|
| `board_demo` | Demo tương tác: LED theo công tắc (ngắt GPIO), đếm giây (ngắt timer), lệnh UART, đo hiệu năng bằng performance counter | – | PASS | 391205 chu kỳ, 323166 lệnh, CPI 1.210 |
| `hello` | In chuỗi chào qua UART | – | PASS | khớp expect.txt |
| `timer_irq` | 8 ngắt timer định kỳ, kiểm tra khoảng cách | – | PASS | PASS (23 checks, 0 errors) |
| `irq_priority` | Thứ tự ưu tiên MEI > MSI > MTI, mtvec direct/vectored | – | PASS | PASS (8 checks, 0 errors) |
| `exceptions` | Illegal, ecall, ebreak, misaligned, access fault | – | PASS | PASS (62 checks, 0 errors) |
| `irq_during_div` | Ngắt khi bộ chia đang chạy | – | PASS | PASS (3 checks, 0 errors) |
| `branch_smc` | Trap sau nhánh đoán sai; self-modifying code + FENCE.I | – | PASS | PASS (4 checks, 0 errors) |
| `spi_flash` | JEDEC ID, xóa sector, ghi/đọc page qua SPI | module flash W25Qxx trên GPIO_0 | PASS | PASS (281 checks, 0 errors) |
| `demo` | Đọc flash định kỳ theo ngắt timer + lệnh UART r/w/s/q | module flash W25Qxx trên GPIO_0 | PASS | khớp expect.txt |
| `dhrystone` | Benchmark Dhrystone | – | PASS | 333617 chu kỳ, 277083 lệnh, CPI 1.204 |
| `coremark` | Benchmark CoreMark | – | PASS | 695588 chu kỳ, 626769 lệnh, CPI 1.109 |
| `median` | Benchmark median (riscv-tests) | – | PASS | 5404 chu kỳ, 4307 lệnh, CPI 1.254 |
| `multiply` | Benchmark multiply (riscv-tests) | – | PASS | 22282 chu kỳ, 20953 lệnh, CPI 1.063 |
| `qsort` | Benchmark qsort (riscv-tests) | – | PASS | 148150 chu kỳ, 123560 lệnh, CPI 1.199 |
| `towers` | Benchmark towers (riscv-tests) | – | PASS | 4028 chu kỳ, 3777 lệnh, CPI 1.066 |
| `vvadd` | Benchmark vvadd (riscv-tests) | – | PASS | 2489 chu kỳ, 2469 lệnh, CPI 1.008 |

Mặc định trong `mem/`: `board_demo`.

Không đưa lên board: `rsort` (29.6 KB dữ liệu + 8 KB stack); `memcpy` (mảng 16 KB trên stack + 16 KB dữ liệu vào); `gpio_irq` (cần loopback GPIO và kích thích của testbench); `spi_modes` (cần SPI slave echo (BFM)); `uart_irq_echo` (phần kiểm tra overrun cần BFM gửi dồn dập).

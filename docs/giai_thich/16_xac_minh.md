# Xác minh – đã kiểm chứng thiết kế như thế nào

## Ba mức

1. **Unit testbench** (13 TB, `make unit`): mỗi khối có mô hình tham chiếu trong TB, test có hướng (giá trị biên) và
   ngẫu nhiên có seed. Ví dụ `tb_compressed_decoder` lấy kỳ vọng từ chính GNU assembler.
2. **riscv-tests** (`make isa`): bộ test tuân thủ ISA chính thức, chạy trên ma trận 6 cấu hình RTL với đúng biến thể
   ELF. 3 test được loại trừ có lý do (misaligned được phép trap; debug trigger; PMP).
3. **System test C** (`make systest`): firmware thật trên SoC với BFM UART / SPI flash / SPI slave / GPIO.

## So sánh lock-step với Spike (`make spike`)

Spike là mô phỏng ISA chuẩn của RISC-V. RTL in commit log ở WB theo đúng định dạng `spike --log-commits`; script so
khớp **từng lệnh**: PC, mã lệnh, thanh ghi đích và giá trị, địa chỉ và dữ liệu store. Giá trị phụ thuộc thời gian
(cycle, mhpmcounter, time) được "taint" và theo dõi qua thanh ghi và bộ nhớ (D19); khác biệt tùy hiện thực (`misa`,
`marchid`) được liệt kê là KNOWN. Mọi riscv-test và benchmark đều khớp – nghĩa là pipeline (forwarding, stall, flush,
dự đoán) không làm sai kết quả của bất kỳ lệnh nào trong hàng trăm nghìn lệnh.

## Coverage (`make cov`)

- Line + toggle coverage của RTL, gộp mọi lần chạy; mục tiêu ≥ 90% line cho `rtl/core` và `rtl/periph`.
- Functional coverage: `cover property` (gắn bằng `bind`) cho các tình huống quan trọng: mọi nhóm lệnh, 4 đường
  forward, các loại stall, sai dự đoán theo loại, mọi mcause, ngắt khi đang chia, trap ngay sau nhánh sai, lệnh 32 bit
  vắt qua word, 4 mode SPI, định dạng UART, FIFO đầy/rỗng. Kết quả và giải thích điểm chưa đạt: `results/coverage/`.

## Lint và tổng hợp

`verilator --lint-only -Wall` sạch trên 8 cấu hình; Yosys `check -assert` sạch – RTL tổng hợp được (một clock, reset
bất đồng bộ, không latch, không `initial`/`#delay` ngoài `ifndef SYNTHESIS`).

## Một lệnh chạy tất cả

`make regress` = lint + unit + ma trận riscv-tests + Spike + system test, in bảng PASS/FAIL, exit code ≠ 0 nếu lỗi.

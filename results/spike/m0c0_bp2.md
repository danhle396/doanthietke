# So sánh commit log RTL với Spike – cấu hình `m0c0_bp2`

Mức so sánh: `--log-commits` (pc, mã lệnh, thanh ghi đích + giá trị, địa chỉ + dữ liệu store), so khớp từng lệnh bằng regex.

MATCH (kể cả KNOWN) 64 / 64

KNOWN = khớp tới lệnh đọc một CSR có giá trị tùy hiện thực (misa/marchid/mimpid), sau đó luồng chương trình rẽ khác một cách hợp lệ.

| Chương trình | Kết quả | Chi tiết | Giá trị bị che (counter) | Khác biệt đã biết |
|---|---|---|---|---|
| rv32ui-p-simple | MATCH | 45 lệnh khớp | 0 |  |
| rv32ui-p-add | MATCH | 469 lệnh khớp | 0 |  |
| rv32ui-p-addi | MATCH | 246 lệnh khớp | 0 |  |
| rv32ui-p-and | MATCH | 489 lệnh khớp | 0 |  |
| rv32ui-p-andi | MATCH | 202 lệnh khớp | 0 |  |
| rv32ui-p-auipc | MATCH | 63 lệnh khớp | 0 |  |
| rv32ui-p-beq | MATCH | 295 lệnh khớp | 0 |  |
| rv32ui-p-bge | MATCH | 313 lệnh khớp | 0 |  |
| rv32ui-p-bgeu | MATCH | 338 lệnh khớp | 0 |  |
| rv32ui-p-blt | MATCH | 295 lệnh khớp | 0 |  |
| rv32ui-p-bltu | MATCH | 320 lệnh khớp | 0 |  |
| rv32ui-p-bne | MATCH | 295 lệnh khớp | 0 |  |
| rv32ui-p-fence_i | MATCH | 305 lệnh khớp | 0 |  |
| rv32ui-p-jal | MATCH | 59 lệnh khớp | 0 |  |
| rv32ui-p-jalr | MATCH | 119 lệnh khớp | 0 |  |
| rv32ui-p-lb | MATCH | 257 lệnh khớp | 0 |  |
| rv32ui-p-lbu | MATCH | 257 lệnh khớp | 0 |  |
| rv32ui-p-lh | MATCH | 273 lệnh khớp | 0 |  |
| rv32ui-p-lhu | MATCH | 282 lệnh khớp | 0 |  |
| rv32ui-p-lw | MATCH | 287 lệnh khớp | 0 |  |
| rv32ui-p-ld_st | MATCH | 967 lệnh khớp | 0 |  |
| rv32ui-p-lui | MATCH | 69 lệnh khớp | 0 |  |
| rv32ui-p-or | MATCH | 492 lệnh khớp | 0 |  |
| rv32ui-p-ori | MATCH | 209 lệnh khớp | 0 |  |
| rv32ui-p-sb | MATCH | 458 lệnh khớp | 0 |  |
| rv32ui-p-sh | MATCH | 511 lệnh khớp | 0 |  |
| rv32ui-p-sw | MATCH | 518 lệnh khớp | 0 |  |
| rv32ui-p-st_ld | MATCH | 487 lệnh khớp | 0 |  |
| rv32ui-p-sll | MATCH | 497 lệnh khớp | 0 |  |
| rv32ui-p-slli | MATCH | 245 lệnh khớp | 0 |  |
| rv32ui-p-slt | MATCH | 463 lệnh khớp | 0 |  |
| rv32ui-p-slti | MATCH | 241 lệnh khớp | 0 |  |
| rv32ui-p-sltiu | MATCH | 241 lệnh khớp | 0 |  |
| rv32ui-p-sltu | MATCH | 463 lệnh khớp | 0 |  |
| rv32ui-p-sra | MATCH | 516 lệnh khớp | 0 |  |
| rv32ui-p-srai | MATCH | 260 lệnh khớp | 0 |  |
| rv32ui-p-srl | MATCH | 510 lệnh khớp | 0 |  |
| rv32ui-p-srli | MATCH | 254 lệnh khớp | 0 |  |
| rv32ui-p-sub | MATCH | 461 lệnh khớp | 0 |  |
| rv32ui-p-xor | MATCH | 491 lệnh khớp | 0 |  |
| rv32ui-p-xori | MATCH | 211 lệnh khớp | 0 |  |
| rv32mi-p-csr | MATCH | 131 lệnh khớp | 0 |  |
| rv32mi-p-mcsr | MATCH | 64 lệnh khớp | 0 | pc 0x8000012c read marchid: RTL 0x00000000 Spike 0x00000005 |
| rv32mi-p-illegal | MATCH | 75 lệnh khớp | 0 |  |
| rv32mi-p-ma_fetch | MATCH | 168 lệnh khớp | 0 |  |
| rv32mi-p-ma_addr | MATCH | 208 lệnh khớp | 0 |  |
| rv32mi-p-scall | MATCH | 79 lệnh khớp | 0 |  |
| rv32mi-p-sbreak | MATCH | 64 lệnh khớp | 0 |  |
| rv32mi-p-shamt | MATCH | 64 lệnh khớp | 0 |  |
| rv32mi-p-lw-misaligned | MATCH | 118 lệnh khớp | 0 |  |
| rv32mi-p-lh-misaligned | MATCH | 74 lệnh khớp | 0 |  |
| rv32mi-p-sh-misaligned | MATCH | 82 lệnh khớp | 0 |  |
| rv32mi-p-sw-misaligned | MATCH | 122 lệnh khớp | 0 |  |
| rv32mi-p-zicntr | MATCH | 113 lệnh khớp | 0 |  |
| rv32mi-p-instret_overflow | MATCH | 71 lệnh khớp | 0 |  |
| bench-coremark | MATCH | 1514607 lệnh khớp lock-step; luồng lệnh rẽ khác sau nhánh phụ thuộc giá trị counter tại pc 0x800035e4; mã thoát tohost khớp (RTL còn 23251, Spike còn 18572 lệnh không so) | 45 |  |
| bench-dhrystone | MATCH | 303252 lệnh khớp lock-step; luồng lệnh rẽ khác sau nhánh phụ thuộc giá trị counter tại pc 0x80001ec4; mã thoát tohost khớp (RTL còn 13704, Spike còn 10130 lệnh không so) | 82 |  |
| bench-median | MATCH | 9016 lệnh khớp lock-step; luồng lệnh rẽ khác sau nhánh phụ thuộc giá trị counter tại pc 0x80001478; mã thoát tohost khớp (RTL còn 9044, Spike còn 7919 lệnh không so) | 78 |  |
| bench-memcpy | MATCH | 40645 lệnh khớp lock-step; luồng lệnh rẽ khác sau nhánh phụ thuộc giá trị counter tại pc 0x800014a8; mã thoát tohost khớp (RTL còn 27119, Spike còn 26210 lệnh không so) | 76 |  |
| bench-multiply | MATCH | 42321 lệnh khớp lock-step; luồng lệnh rẽ khác sau nhánh phụ thuộc giá trị counter tại pc 0x80001484; mã thoát tohost khớp (RTL còn 8287, Spike còn 6822 lệnh không so) | 78 |  |
| bench-qsort | MATCH | 215711 lệnh khớp lock-step; luồng lệnh rẽ khác sau nhánh phụ thuộc giá trị counter tại pc 0x800015a4; mã thoát tohost khớp (RTL còn 20780, Spike còn 18048 lệnh không so) | 78 |  |
| bench-rsort | MATCH | 362512 lệnh khớp lock-step; luồng lệnh rẽ khác sau nhánh phụ thuộc giá trị counter tại pc 0x80000858; mã thoát tohost khớp (RTL còn 18922, Spike còn 17920 lệnh không so) | 96 |  |
| bench-towers | MATCH | 8254 lệnh khớp lock-step; luồng lệnh rẽ khác sau nhánh phụ thuộc giá trị counter tại pc 0x8000199c; mã thoát tohost khớp (RTL còn 6978, Spike còn 5933 lệnh không so) | 78 |  |
| bench-vvadd | MATCH | 5386 lệnh khớp lock-step; luồng lệnh rẽ khác sau nhánh phụ thuộc giá trị counter tại pc 0x80001448; mã thoát tohost khớp (RTL còn 7934, Spike còn 7261 lệnh không so) | 83 |  |

Tái tạo: `.venv/bin/python scripts/compare_spike.py --config m0c0_bp2`

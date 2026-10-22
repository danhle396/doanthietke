# So sánh commit log RTL với Spike – cấu hình `m1c0_bp2`

Mức so sánh: `--log-commits` (pc, mã lệnh, thanh ghi đích + giá trị, địa chỉ + dữ liệu store), so khớp từng lệnh bằng regex.

MATCH (kể cả KNOWN) 72 / 72

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
| rv32um-p-div | MATCH | 100 lệnh khớp | 0 |  |
| rv32um-p-divu | MATCH | 101 lệnh khớp | 0 |  |
| rv32um-p-mul | MATCH | 463 lệnh khớp | 0 |  |
| rv32um-p-mulh | MATCH | 463 lệnh khớp | 0 |  |
| rv32um-p-mulhsu | MATCH | 463 lệnh khớp | 0 |  |
| rv32um-p-mulhu | MATCH | 463 lệnh khớp | 0 |  |
| rv32um-p-rem | MATCH | 100 lệnh khớp | 0 |  |
| rv32um-p-remu | MATCH | 100 lệnh khớp | 0 |  |
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
| bench-coremark | MATCH | 650515 lệnh khớp lock-step; luồng lệnh rẽ khác sau nhánh phụ thuộc giá trị counter tại pc 0x800023b8; mã thoát tohost khớp (RTL còn 3898, Spike còn 3492 lệnh không so) | 160 |  |
| bench-dhrystone | MATCH | 288155 lệnh khớp lock-step; luồng lệnh rẽ khác sau nhánh phụ thuộc giá trị counter tại pc 0x80000ec4; mã thoát tohost khớp (RTL còn 6106, Spike còn 5666 lệnh không so) | 83 |  |
| bench-median | MATCH | 8919 lệnh khớp lock-step; luồng lệnh rẽ khác sau nhánh phụ thuộc giá trị counter tại pc 0x80000500; mã thoát tohost khớp (RTL còn 5554, Spike còn 5402 lệnh không so) | 74 |  |
| bench-memcpy | MATCH | 40494 lệnh khớp lock-step; luồng lệnh rẽ khác sau nhánh phụ thuộc giá trị counter tại pc 0x80000528; mã thoát tohost khớp (RTL còn 23557, Spike còn 23441 lệnh không so) | 70 |  |
| bench-multiply | MATCH | 42224 lệnh khớp lock-step; luồng lệnh rẽ khác sau nhánh phụ thuộc giá trị counter tại pc 0x8000050c; mã thoát tohost khớp (RTL còn 4155, Spike còn 3967 lệnh không so) | 74 |  |
| bench-qsort | MATCH | 215614 lệnh khớp lock-step; luồng lệnh rẽ khác sau nhánh phụ thuộc giá trị counter tại pc 0x8000062c; mã thoát tohost khớp (RTL còn 15023, Spike còn 14727 lệnh không so) | 74 |  |
| bench-rsort | MATCH | 362150 lệnh khớp lock-step; luồng lệnh rẽ khác sau nhánh phụ thuộc giá trị counter tại pc 0x80000824; mã thoát tohost khớp (RTL còn 14862, Spike còn 14728 lệnh không so) | 66 |  |
| bench-towers | MATCH | 8157 lệnh khớp lock-step; luồng lệnh rẽ khác sau nhánh phụ thuộc giá trị counter tại pc 0x80000a24; mã thoát tohost khớp (RTL còn 3618, Spike còn 3448 lệnh không so) | 74 |  |
| bench-vvadd | MATCH | 5253 lệnh khớp lock-step; luồng lệnh rẽ khác sau nhánh phụ thuộc giá trị counter tại pc 0x800004c8; mã thoát tohost khớp (RTL còn 4990, Spike còn 4892 lệnh không so) | 74 |  |

Tái tạo: `.venv/bin/python scripts/compare_spike.py --config m1c0_bp2`

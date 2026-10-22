# So sánh commit log RTL với Spike – cấu hình `sc`

Mức so sánh: `--log-commits` (pc, mã lệnh, thanh ghi đích + giá trị, địa chỉ + dữ liệu store), so khớp từng lệnh bằng regex.

MATCH (kể cả KNOWN) 49 / 49

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
| bench-dhrystone | MATCH | 303427 lệnh khớp lock-step; luồng lệnh rẽ khác sau nhánh phụ thuộc giá trị counter tại pc 0x80000f38; mã thoát tohost khớp (RTL còn 11728, Spike còn 9865 lệnh không so) | 36 |  |
| bench-median | MATCH | 9191 lệnh khớp lock-step; luồng lệnh rẽ khác sau nhánh phụ thuộc giá trị counter tại pc 0x80000534; mã thoát tohost khớp (RTL còn 8468, Spike còn 7654 lệnh không so) | 32 |  |
| bench-memcpy | MATCH | 40766 lệnh khớp lock-step; luồng lệnh rẽ khác sau nhánh phụ thuộc giá trị counter tại pc 0x8000055c; mã thoát tohost khớp (RTL còn 26877, Spike còn 25999 lệnh không so) | 32 |  |
| bench-multiply | MATCH | 42496 lệnh khớp lock-step; luồng lệnh rẽ khác sau nhánh phụ thuộc giá trị counter tại pc 0x80000540; mã thoát tohost khớp (RTL còn 7701, Spike còn 6557 lệnh không so) | 32 |  |
| bench-qsort | MATCH | 215886 lệnh khớp lock-step; luồng lệnh rẽ khác sau nhánh phụ thuộc giá trị counter tại pc 0x80000660; mã thoát tohost khớp (RTL còn 19437, Spike còn 17783 lệnh không so) | 32 |  |
| bench-rsort | MATCH | 362422 lệnh khớp lock-step; luồng lệnh rẽ khác sau nhánh phụ thuộc giá trị counter tại pc 0x80000858; mã thoát tohost khớp (RTL còn 18842, Spike còn 17920 lệnh không so) | 32 |  |
| bench-towers | MATCH | 8429 lệnh khớp lock-step; luồng lệnh rẽ khác sau nhánh phụ thuộc giá trị counter tại pc 0x80000a58; mã thoát tohost khớp (RTL còn 6489, Spike còn 5668 lệnh không so) | 32 |  |
| bench-vvadd | MATCH | 5525 lệnh khớp lock-step; luồng lệnh rẽ khác sau nhánh phụ thuộc giá trị counter tại pc 0x800004fc; mã thoát tohost khớp (RTL còn 7699, Spike còn 7032 lệnh không so) | 32 |  |

Tái tạo: `.venv/bin/python scripts/compare_spike.py --config sc`

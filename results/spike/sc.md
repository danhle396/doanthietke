# So sánh commit log RTL với Spike – cấu hình `sc`

Mức so sánh: `--log-commits` (pc, mã lệnh, thanh ghi đích + giá trị, địa chỉ + dữ liệu store), so khớp từng lệnh bằng regex.

MATCH (kể cả KNOWN) 41 / 41

KNOWN = khớp tới lệnh đọc một CSR có giá trị tùy hiện thực (misa/marchid/mimpid), sau đó luồng chương trình rẽ khác một cách hợp lệ.

| Chương trình | Kết quả | Chi tiết | Giá trị bị che (counter) | Khác biệt đã biết |
|---|---|---|---|---|
| rv32ui-p-simple | MATCH | 45 instructions | 0 |  |
| rv32ui-p-add | MATCH | 469 instructions | 0 |  |
| rv32ui-p-addi | MATCH | 246 instructions | 0 |  |
| rv32ui-p-and | MATCH | 489 instructions | 0 |  |
| rv32ui-p-andi | MATCH | 202 instructions | 0 |  |
| rv32ui-p-auipc | MATCH | 63 instructions | 0 |  |
| rv32ui-p-beq | MATCH | 295 instructions | 0 |  |
| rv32ui-p-bge | MATCH | 313 instructions | 0 |  |
| rv32ui-p-bgeu | MATCH | 338 instructions | 0 |  |
| rv32ui-p-blt | MATCH | 295 instructions | 0 |  |
| rv32ui-p-bltu | MATCH | 320 instructions | 0 |  |
| rv32ui-p-bne | MATCH | 295 instructions | 0 |  |
| rv32ui-p-fence_i | MATCH | 305 instructions | 0 |  |
| rv32ui-p-jal | MATCH | 59 instructions | 0 |  |
| rv32ui-p-jalr | MATCH | 119 instructions | 0 |  |
| rv32ui-p-lb | MATCH | 257 instructions | 0 |  |
| rv32ui-p-lbu | MATCH | 257 instructions | 0 |  |
| rv32ui-p-lh | MATCH | 273 instructions | 0 |  |
| rv32ui-p-lhu | MATCH | 282 instructions | 0 |  |
| rv32ui-p-lw | MATCH | 287 instructions | 0 |  |
| rv32ui-p-ld_st | MATCH | 967 instructions | 0 |  |
| rv32ui-p-lui | MATCH | 69 instructions | 0 |  |
| rv32ui-p-or | MATCH | 492 instructions | 0 |  |
| rv32ui-p-ori | MATCH | 209 instructions | 0 |  |
| rv32ui-p-sb | MATCH | 458 instructions | 0 |  |
| rv32ui-p-sh | MATCH | 511 instructions | 0 |  |
| rv32ui-p-sw | MATCH | 518 instructions | 0 |  |
| rv32ui-p-st_ld | MATCH | 487 instructions | 0 |  |
| rv32ui-p-sll | MATCH | 497 instructions | 0 |  |
| rv32ui-p-slli | MATCH | 245 instructions | 0 |  |
| rv32ui-p-slt | MATCH | 463 instructions | 0 |  |
| rv32ui-p-slti | MATCH | 241 instructions | 0 |  |
| rv32ui-p-sltiu | MATCH | 241 instructions | 0 |  |
| rv32ui-p-sltu | MATCH | 463 instructions | 0 |  |
| rv32ui-p-sra | MATCH | 516 instructions | 0 |  |
| rv32ui-p-srai | MATCH | 260 instructions | 0 |  |
| rv32ui-p-srl | MATCH | 510 instructions | 0 |  |
| rv32ui-p-srli | MATCH | 254 instructions | 0 |  |
| rv32ui-p-sub | MATCH | 461 instructions | 0 |  |
| rv32ui-p-xor | MATCH | 491 instructions | 0 |  |
| rv32ui-p-xori | MATCH | 211 instructions | 0 |  |

Tái tạo: `.venv/bin/python scripts/compare_spike.py --config sc`

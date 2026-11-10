# Co-simulation C++ lock-step với Spike – cấu hình `m1c0_bp2`

Harness `cosim/cosim_main.cpp` (Verilator C++): mỗi lệnh RTL retire được so **ngay khi chạy** với lệnh kế tiếp Spike commit (pc, mã lệnh, thanh ghi đích + giá trị, địa chỉ load, địa chỉ + dữ liệu store); lệch là dừng. Giá trị đọc từ counter được theo dõi (taint) như `compare_spike.py`.

MATCH (kể cả KNOWN) 72 / 72; 1638940 lệnh được so khớp; tổng thời gian chạy 22.3 s.

| Chương trình | Kết quả | Lệnh so khớp | Giá trị counter bị che | Chu kỳ | Chi tiết |
|---|---|---|---|---|---|
| rv32ui-p-simple | MATCH | 45 | 0 | 59 | 45 instructions identical, exit code 0 |
| rv32ui-p-add | MATCH | 469 | 0 | 539 | 469 instructions identical, exit code 0 |
| rv32ui-p-addi | MATCH | 246 | 0 | 286 | 246 instructions identical, exit code 0 |
| rv32ui-p-and | MATCH | 489 | 0 | 561 | 489 instructions identical, exit code 0 |
| rv32ui-p-andi | MATCH | 202 | 0 | 242 | 202 instructions identical, exit code 0 |
| rv32ui-p-auipc | MATCH | 63 | 0 | 79 | 63 instructions identical, exit code 0 |
| rv32ui-p-beq | MATCH | 295 | 0 | 387 | 295 instructions identical, exit code 0 |
| rv32ui-p-bge | MATCH | 313 | 0 | 423 | 313 instructions identical, exit code 0 |
| rv32ui-p-bgeu | MATCH | 338 | 0 | 446 | 338 instructions identical, exit code 0 |
| rv32ui-p-blt | MATCH | 295 | 0 | 387 | 295 instructions identical, exit code 0 |
| rv32ui-p-bltu | MATCH | 320 | 0 | 410 | 320 instructions identical, exit code 0 |
| rv32ui-p-bne | MATCH | 295 | 0 | 391 | 295 instructions identical, exit code 0 |
| rv32ui-p-fence_i | MATCH | 305 | 0 | 339 | 305 instructions identical, exit code 0 |
| rv32ui-p-jal | MATCH | 59 | 0 | 77 | 59 instructions identical, exit code 0 |
| rv32ui-p-jalr | MATCH | 119 | 0 | 159 | 119 instructions identical, exit code 0 |
| rv32ui-p-lb | MATCH | 257 | 0 | 299 | 257 instructions identical, exit code 0 |
| rv32ui-p-lbu | MATCH | 257 | 0 | 299 | 257 instructions identical, exit code 0 |
| rv32ui-p-lh | MATCH | 273 | 0 | 313 | 273 instructions identical, exit code 0 |
| rv32ui-p-lhu | MATCH | 282 | 0 | 324 | 282 instructions identical, exit code 0 |
| rv32ui-p-lw | MATCH | 287 | 0 | 329 | 287 instructions identical, exit code 0 |
| rv32ui-p-ld_st | MATCH | 967 | 0 | 1127 | 967 instructions identical, exit code 0 |
| rv32ui-p-lui | MATCH | 69 | 0 | 85 | 69 instructions identical, exit code 0 |
| rv32ui-p-or | MATCH | 492 | 0 | 566 | 492 instructions identical, exit code 0 |
| rv32ui-p-ori | MATCH | 209 | 0 | 249 | 209 instructions identical, exit code 0 |
| rv32ui-p-sb | MATCH | 458 | 0 | 528 | 458 instructions identical, exit code 0 |
| rv32ui-p-sh | MATCH | 511 | 0 | 577 | 511 instructions identical, exit code 0 |
| rv32ui-p-sw | MATCH | 518 | 0 | 588 | 518 instructions identical, exit code 0 |
| rv32ui-p-st_ld | MATCH | 487 | 0 | 503 | 487 instructions identical, exit code 0 |
| rv32ui-p-sll | MATCH | 497 | 0 | 565 | 497 instructions identical, exit code 0 |
| rv32ui-p-slli | MATCH | 245 | 0 | 283 | 245 instructions identical, exit code 0 |
| rv32ui-p-slt | MATCH | 463 | 0 | 535 | 463 instructions identical, exit code 0 |
| rv32ui-p-slti | MATCH | 241 | 0 | 279 | 241 instructions identical, exit code 0 |
| rv32ui-p-sltiu | MATCH | 241 | 0 | 279 | 241 instructions identical, exit code 0 |
| rv32ui-p-sltu | MATCH | 463 | 0 | 535 | 463 instructions identical, exit code 0 |
| rv32ui-p-sra | MATCH | 516 | 0 | 588 | 516 instructions identical, exit code 0 |
| rv32ui-p-srai | MATCH | 260 | 0 | 300 | 260 instructions identical, exit code 0 |
| rv32ui-p-srl | MATCH | 510 | 0 | 584 | 510 instructions identical, exit code 0 |
| rv32ui-p-srli | MATCH | 254 | 0 | 294 | 254 instructions identical, exit code 0 |
| rv32ui-p-sub | MATCH | 461 | 0 | 535 | 461 instructions identical, exit code 0 |
| rv32ui-p-xor | MATCH | 491 | 0 | 561 | 491 instructions identical, exit code 0 |
| rv32ui-p-xori | MATCH | 211 | 0 | 251 | 211 instructions identical, exit code 0 |
| rv32um-p-div | MATCH | 100 | 0 | 281 | 100 instructions identical, exit code 0 |
| rv32um-p-divu | MATCH | 101 | 0 | 315 | 101 instructions identical, exit code 0 |
| rv32um-p-mul | MATCH | 463 | 0 | 535 | 463 instructions identical, exit code 0 |
| rv32um-p-mulh | MATCH | 463 | 0 | 535 | 463 instructions identical, exit code 0 |
| rv32um-p-mulhsu | MATCH | 463 | 0 | 535 | 463 instructions identical, exit code 0 |
| rv32um-p-mulhu | MATCH | 463 | 0 | 535 | 463 instructions identical, exit code 0 |
| rv32um-p-rem | MATCH | 100 | 0 | 281 | 100 instructions identical, exit code 0 |
| rv32um-p-remu | MATCH | 100 | 0 | 314 | 100 instructions identical, exit code 0 |
| rv32mi-p-csr | MATCH | 131 | 0 | 151 | 131 instructions identical, exit code 0 |
| rv32mi-p-mcsr | MATCH | 64 | 0 | 81 | 64 instructions identical, exit code 0; known: pc 0x8000012c read marchid: RTL 0x00000000 Spike 0x00000005 |
| rv32mi-p-illegal | MATCH | 75 | 0 | 108 | 75 instructions identical, exit code 0 |
| rv32mi-p-ma_fetch | MATCH | 168 | 0 | 243 | 168 instructions identical, exit code 0 |
| rv32mi-p-ma_addr | MATCH | 208 | 0 | 318 | 208 instructions identical, exit code 0 |
| rv32mi-p-scall | MATCH | 79 | 0 | 108 | 79 instructions identical, exit code 0 |
| rv32mi-p-sbreak | MATCH | 64 | 0 | 89 | 64 instructions identical, exit code 0 |
| rv32mi-p-shamt | MATCH | 64 | 0 | 85 | 64 instructions identical, exit code 0 |
| rv32mi-p-lw-misaligned | MATCH | 118 | 0 | 163 | 118 instructions identical, exit code 0 |
| rv32mi-p-lh-misaligned | MATCH | 74 | 0 | 101 | 74 instructions identical, exit code 0 |
| rv32mi-p-sh-misaligned | MATCH | 82 | 0 | 109 | 82 instructions identical, exit code 0 |
| rv32mi-p-sw-misaligned | MATCH | 122 | 0 | 165 | 122 instructions identical, exit code 0 |
| rv32mi-p-zicntr | MATCH | 113 | 0 | 129 | 113 instructions identical, exit code 0 |
| rv32mi-p-instret_overflow | MATCH | 71 | 0 | 87 | 71 instructions identical, exit code 0 |
| bench-coremark | MATCH | 650515 | 159 | 739189 | 650515 instructions identical in lock-step; control flow diverges after a branch on a counter value; exit codes RTL 0 / Spike 0 |
| bench-dhrystone | MATCH | 288155 | 82 | 360539 | 288155 instructions identical in lock-step; control flow diverges after a branch on a counter value; exit codes RTL 0 / Spike 0 |
| bench-median | MATCH | 8919 | 73 | 19540 | 8919 instructions identical in lock-step; control flow diverges after a branch on a counter value; exit codes RTL 0 / Spike 0 |
| bench-memcpy | MATCH | 40494 | 69 | 66957 | 40494 instructions identical in lock-step; control flow diverges after a branch on a counter value; exit codes RTL 0 / Spike 0 |
| bench-multiply | MATCH | 42224 | 73 | 52197 | 42224 instructions identical in lock-step; control flow diverges after a branch on a counter value; exit codes RTL 0 / Spike 0 |
| bench-qsort | MATCH | 215614 | 73 | 264218 | 215614 instructions identical in lock-step; control flow diverges after a branch on a counter value; exit codes RTL 0 / Spike 0 |
| bench-rsort | MATCH | 362150 | 65 | 380230 | 362150 instructions identical in lock-step; control flow diverges after a branch on a counter value; exit codes RTL 0 / Spike 0 |
| bench-towers | MATCH | 8157 | 73 | 15278 | 8157 instructions identical in lock-step; control flow diverges after a branch on a counter value; exit codes RTL 0 / Spike 0 |
| bench-vvadd | MATCH | 5253 | 73 | 12937 | 5253 instructions identical in lock-step; control flow diverges after a branch on a counter value; exit codes RTL 0 / Spike 0 |

Tái tạo: `.venv/bin/python scripts/run_cosim.py --config m1c0_bp2`

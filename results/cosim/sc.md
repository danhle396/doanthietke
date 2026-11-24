# Co-simulation C++ lock-step với Spike – cấu hình `sc`

Harness `cosim/cosim_main.cpp` (Verilator C++): mỗi lệnh RTL retire được so **ngay khi chạy** với lệnh kế tiếp Spike commit (pc, mã lệnh, thanh ghi đích + giá trị, địa chỉ load, địa chỉ + dữ liệu store); lệch là dừng. Giá trị đọc từ counter được theo dõi (taint) như `compare_spike.py`.

MATCH (kể cả KNOWN) 50 / 50; 2528472 lệnh được so khớp; tổng thời gian chạy 12.9 s.

| Chương trình     | Kết quả | Lệnh so khớp | Giá trị counter bị che | Chu kỳ  | Chi tiết                                                                                                                         |
| ---------------- | ------- | ------------ | ---------------------- | ------- | -------------------------------------------------------------------------------------------------------------------------------- |
| rv32ui-p-simple  | MATCH   |           45 |                      0 |      52 | 45 instructions identical, exit code 0                                                                                           |
| rv32ui-p-add     | MATCH   |          469 |                      0 |     476 | 469 instructions identical, exit code 0                                                                                          |
| rv32ui-p-addi    | MATCH   |          246 |                      0 |     253 | 246 instructions identical, exit code 0                                                                                          |
| rv32ui-p-and     | MATCH   |          489 |                      0 |     496 | 489 instructions identical, exit code 0                                                                                          |
| rv32ui-p-andi    | MATCH   |          202 |                      0 |     209 | 202 instructions identical, exit code 0                                                                                          |
| rv32ui-p-auipc   | MATCH   |           63 |                      0 |      70 | 63 instructions identical, exit code 0                                                                                           |
| rv32ui-p-beq     | MATCH   |          295 |                      0 |     302 | 295 instructions identical, exit code 0                                                                                          |
| rv32ui-p-bge     | MATCH   |          313 |                      0 |     320 | 313 instructions identical, exit code 0                                                                                          |
| rv32ui-p-bgeu    | MATCH   |          338 |                      0 |     345 | 338 instructions identical, exit code 0                                                                                          |
| rv32ui-p-blt     | MATCH   |          295 |                      0 |     302 | 295 instructions identical, exit code 0                                                                                          |
| rv32ui-p-bltu    | MATCH   |          320 |                      0 |     327 | 320 instructions identical, exit code 0                                                                                          |
| rv32ui-p-bne     | MATCH   |          295 |                      0 |     302 | 295 instructions identical, exit code 0                                                                                          |
| rv32ui-p-fence_i | MATCH   |          305 |                      0 |     312 | 305 instructions identical, exit code 0                                                                                          |
| rv32ui-p-jal     | MATCH   |           59 |                      0 |      66 | 59 instructions identical, exit code 0                                                                                           |
| rv32ui-p-jalr    | MATCH   |          119 |                      0 |     126 | 119 instructions identical, exit code 0                                                                                          |
| rv32ui-p-lb      | MATCH   |          257 |                      0 |     264 | 257 instructions identical, exit code 0                                                                                          |
| rv32ui-p-lbu     | MATCH   |          257 |                      0 |     264 | 257 instructions identical, exit code 0                                                                                          |
| rv32ui-p-lh      | MATCH   |          273 |                      0 |     280 | 273 instructions identical, exit code 0                                                                                          |
| rv32ui-p-lhu     | MATCH   |          282 |                      0 |     289 | 282 instructions identical, exit code 0                                                                                          |
| rv32ui-p-lw      | MATCH   |          287 |                      0 |     294 | 287 instructions identical, exit code 0                                                                                          |
| rv32ui-p-ld_st   | MATCH   |          967 |                      0 |     974 | 967 instructions identical, exit code 0                                                                                          |
| rv32ui-p-lui     | MATCH   |           69 |                      0 |      76 | 69 instructions identical, exit code 0                                                                                           |
| rv32ui-p-or      | MATCH   |          492 |                      0 |     499 | 492 instructions identical, exit code 0                                                                                          |
| rv32ui-p-ori     | MATCH   |          209 |                      0 |     216 | 209 instructions identical, exit code 0                                                                                          |
| rv32ui-p-sb      | MATCH   |          458 |                      0 |     465 | 458 instructions identical, exit code 0                                                                                          |
| rv32ui-p-sh      | MATCH   |          511 |                      0 |     518 | 511 instructions identical, exit code 0                                                                                          |
| rv32ui-p-sw      | MATCH   |          518 |                      0 |     525 | 518 instructions identical, exit code 0                                                                                          |
| rv32ui-p-st_ld   | MATCH   |          487 |                      0 |     494 | 487 instructions identical, exit code 0                                                                                          |
| rv32ui-p-sll     | MATCH   |          497 |                      0 |     504 | 497 instructions identical, exit code 0                                                                                          |
| rv32ui-p-slli    | MATCH   |          245 |                      0 |     252 | 245 instructions identical, exit code 0                                                                                          |
| rv32ui-p-slt     | MATCH   |          463 |                      0 |     470 | 463 instructions identical, exit code 0                                                                                          |
| rv32ui-p-slti    | MATCH   |          241 |                      0 |     248 | 241 instructions identical, exit code 0                                                                                          |
| rv32ui-p-sltiu   | MATCH   |          241 |                      0 |     248 | 241 instructions identical, exit code 0                                                                                          |
| rv32ui-p-sltu    | MATCH   |          463 |                      0 |     470 | 463 instructions identical, exit code 0                                                                                          |
| rv32ui-p-sra     | MATCH   |          516 |                      0 |     523 | 516 instructions identical, exit code 0                                                                                          |
| rv32ui-p-srai    | MATCH   |          260 |                      0 |     267 | 260 instructions identical, exit code 0                                                                                          |
| rv32ui-p-srl     | MATCH   |          510 |                      0 |     517 | 510 instructions identical, exit code 0                                                                                          |
| rv32ui-p-srli    | MATCH   |          254 |                      0 |     261 | 254 instructions identical, exit code 0                                                                                          |
| rv32ui-p-sub     | MATCH   |          461 |                      0 |     468 | 461 instructions identical, exit code 0                                                                                          |
| rv32ui-p-xor     | MATCH   |          491 |                      0 |     498 | 491 instructions identical, exit code 0                                                                                          |
| rv32ui-p-xori    | MATCH   |          211 |                      0 |     218 | 211 instructions identical, exit code 0                                                                                          |
| bench-coremark   | MATCH   |      1525837 |                     33 | 1536798 | 1525837 instructions identical in lock-step; control flow diverges after a branch on a counter value; exit codes RTL 0 / Spike 0 |
| bench-dhrystone  | MATCH   |       303517 |                     35 |  315858 | 303517 instructions identical in lock-step; control flow diverges after a branch on a counter value; exit codes RTL 0 / Spike 0  |
| bench-median     | MATCH   |         9281 |                     31 |   18144 | 9281 instructions identical in lock-step; control flow diverges after a branch on a counter value; exit codes RTL 0 / Spike 0    |
| bench-memcpy     | MATCH   |        40856 |                     31 |   68132 | 40856 instructions identical in lock-step; control flow diverges after a branch on a counter value; exit codes RTL 0 / Spike 0   |
| bench-multiply   | MATCH   |        42586 |                     31 |   50694 | 42586 instructions identical in lock-step; control flow diverges after a branch on a counter value; exit codes RTL 0 / Spike 0   |
| bench-qsort      | MATCH   |       215976 |                     31 |  235822 | 215976 instructions identical in lock-step; control flow diverges after a branch on a counter value; exit codes RTL 0 / Spike 0  |
| bench-rsort      | MATCH   |       362512 |                     31 |  381755 | 362512 instructions identical in lock-step; control flow diverges after a branch on a counter value; exit codes RTL 0 / Spike 0  |
| bench-towers     | MATCH   |         8519 |                     31 |   15405 | 8519 instructions identical in lock-step; control flow diverges after a branch on a counter value; exit codes RTL 0 / Spike 0    |
| bench-vvadd      | MATCH   |         5615 |                     31 |   13705 | 5615 instructions identical in lock-step; control flow diverges after a branch on a counter value; exit codes RTL 0 / Spike 0    |

Tái tạo: `.venv/bin/python scripts/run_cosim.py --config sc`

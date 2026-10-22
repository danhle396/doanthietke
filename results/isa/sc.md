# riscv-tests – cấu hình `sc`

Tham số RTL: `{'ENABLE_M': 0, 'ENABLE_C': 0, 'BP_MODE': 0, 'BHT_ENTRIES': 256, 'BTB_ENTRIES': 32, 'CORE_SC': 1}` – biến thể ELF: `i`

PASS 41 / FAIL 0 / EXCLUDED 1 (tổng 42)

| Test | Kết quả | Chu kỳ | minstret | Ghi chú |
|---|---|---|---|---|
| rv32ui-p-simple | PASS | 54 | 52 |  |
| rv32ui-p-add | PASS | 478 | 476 |  |
| rv32ui-p-addi | PASS | 255 | 253 |  |
| rv32ui-p-and | PASS | 498 | 496 |  |
| rv32ui-p-andi | PASS | 211 | 209 |  |
| rv32ui-p-auipc | PASS | 72 | 70 |  |
| rv32ui-p-beq | PASS | 304 | 302 |  |
| rv32ui-p-bge | PASS | 322 | 320 |  |
| rv32ui-p-bgeu | PASS | 347 | 345 |  |
| rv32ui-p-blt | PASS | 304 | 302 |  |
| rv32ui-p-bltu | PASS | 329 | 327 |  |
| rv32ui-p-bne | PASS | 304 | 302 |  |
| rv32ui-p-fence_i | PASS | 314 | 312 |  |
| rv32ui-p-jal | PASS | 68 | 66 |  |
| rv32ui-p-jalr | PASS | 128 | 126 |  |
| rv32ui-p-lb | PASS | 266 | 264 |  |
| rv32ui-p-lbu | PASS | 266 | 264 |  |
| rv32ui-p-lh | PASS | 282 | 280 |  |
| rv32ui-p-lhu | PASS | 291 | 289 |  |
| rv32ui-p-lw | PASS | 296 | 294 |  |
| rv32ui-p-ld_st | PASS | 976 | 974 |  |
| rv32ui-p-lui | PASS | 78 | 76 |  |
| rv32ui-p-ma_data | EXCLUDED |  |  | core traps on misaligned load/store (allowed by the spec); the trap behaviour is checked by rv32mi-p-ma_addr |
| rv32ui-p-or | PASS | 501 | 499 |  |
| rv32ui-p-ori | PASS | 218 | 216 |  |
| rv32ui-p-sb | PASS | 467 | 465 |  |
| rv32ui-p-sh | PASS | 520 | 518 |  |
| rv32ui-p-sw | PASS | 527 | 525 |  |
| rv32ui-p-st_ld | PASS | 496 | 494 |  |
| rv32ui-p-sll | PASS | 506 | 504 |  |
| rv32ui-p-slli | PASS | 254 | 252 |  |
| rv32ui-p-slt | PASS | 472 | 470 |  |
| rv32ui-p-slti | PASS | 250 | 248 |  |
| rv32ui-p-sltiu | PASS | 250 | 248 |  |
| rv32ui-p-sltu | PASS | 472 | 470 |  |
| rv32ui-p-sra | PASS | 525 | 523 |  |
| rv32ui-p-srai | PASS | 269 | 267 |  |
| rv32ui-p-srl | PASS | 519 | 517 |  |
| rv32ui-p-srli | PASS | 263 | 261 |  |
| rv32ui-p-sub | PASS | 470 | 468 |  |
| rv32ui-p-xor | PASS | 500 | 498 |  |
| rv32ui-p-xori | PASS | 220 | 218 |  |

Tái tạo: `.venv/bin/python scripts/run_isa.py --config sc`

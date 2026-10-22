# riscv-tests – cấu hình `m1c1_bp0`

Tham số RTL: `{'ENABLE_M': 1, 'ENABLE_C': 1, 'BP_MODE': 0, 'BHT_ENTRIES': 256, 'BTB_ENTRIES': 32, 'CORE_SC': 0}` – biến thể ELF: `imc`

PASS 64 / FAIL 0 / EXCLUDED 3 (tổng 67)

| Test | Kết quả | Chu kỳ | minstret | Ghi chú |
|---|---|---|---|---|
| rv32ui-p-simple | PASS | 63 | 49 |  |
| rv32ui-p-add | PASS | 519 | 473 |  |
| rv32ui-p-addi | PASS | 278 | 250 |  |
| rv32ui-p-and | PASS | 539 | 493 |  |
| rv32ui-p-andi | PASS | 234 | 206 |  |
| rv32ui-p-auipc | PASS | 86 | 70 |  |
| rv32ui-p-beq | PASS | 367 | 299 |  |
| rv32ui-p-bge | PASS | 403 | 317 |  |
| rv32ui-p-bgeu | PASS | 428 | 342 |  |
| rv32ui-p-blt | PASS | 367 | 299 |  |
| rv32ui-p-bltu | PASS | 392 | 324 |  |
| rv32ui-p-bne | PASS | 371 | 299 |  |
| rv32ui-p-fence_i | PASS | 527 | 299 |  |
| rv32ui-p-jal | PASS | 83 | 63 |  |
| rv32ui-p-jalr | PASS | 163 | 123 |  |
| rv32ui-p-lb | PASS | 291 | 261 |  |
| rv32ui-p-lbu | PASS | 291 | 261 |  |
| rv32ui-p-lh | PASS | 307 | 277 |  |
| rv32ui-p-lhu | PASS | 316 | 286 |  |
| rv32ui-p-lw | PASS | 321 | 291 |  |
| rv32ui-p-ld_st | PASS | 1131 | 971 |  |
| rv32ui-p-lui | PASS | 89 | 73 |  |
| rv32ui-p-ma_data | EXCLUDED |  |  | core traps on misaligned load/store (allowed by the spec); the trap behaviour is checked by rv32mi-p-ma_addr |
| rv32ui-p-or | PASS | 542 | 496 |  |
| rv32ui-p-ori | PASS | 241 | 213 |  |
| rv32ui-p-sb | PASS | 518 | 462 |  |
| rv32ui-p-sh | PASS | 571 | 515 |  |
| rv32ui-p-sw | PASS | 578 | 522 |  |
| rv32ui-p-st_ld | PASS | 507 | 491 |  |
| rv32ui-p-sll | PASS | 547 | 501 |  |
| rv32ui-p-slli | PASS | 277 | 249 |  |
| rv32ui-p-slt | PASS | 513 | 467 |  |
| rv32ui-p-slti | PASS | 273 | 245 |  |
| rv32ui-p-sltiu | PASS | 273 | 245 |  |
| rv32ui-p-sltu | PASS | 513 | 467 |  |
| rv32ui-p-sra | PASS | 566 | 520 |  |
| rv32ui-p-srai | PASS | 292 | 264 |  |
| rv32ui-p-srl | PASS | 560 | 514 |  |
| rv32ui-p-srli | PASS | 286 | 258 |  |
| rv32ui-p-sub | PASS | 511 | 465 |  |
| rv32ui-p-xor | PASS | 541 | 495 |  |
| rv32ui-p-xori | PASS | 243 | 215 |  |
| rv32um-p-div | PASS | 285 | 104 |  |
| rv32um-p-divu | PASS | 319 | 105 |  |
| rv32um-p-mul | PASS | 513 | 467 |  |
| rv32um-p-mulh | PASS | 513 | 467 |  |
| rv32um-p-mulhsu | PASS | 513 | 467 |  |
| rv32um-p-mulhu | PASS | 513 | 467 |  |
| rv32um-p-rem | PASS | 285 | 104 |  |
| rv32um-p-remu | PASS | 318 | 104 |  |
| rv32uc-p-rvc | PASS | 275 | 227 |  |
| rv32mi-p-breakpoint | EXCLUDED |  |  | cần CSR debug trigger (Sdtrig) – isa/rv64mi/breakpoint.S dòng 33 `csrw tselect, x0` trap illegal vì lõi không hiện thực tselect/tdata1/tdata2 (chỉ M-mode, không có debug module) |
| rv32mi-p-csr | PASS | 153 | 135 |  |
| rv32mi-p-mcsr | PASS | 83 | 68 |  |
| rv32mi-p-illegal | PASS | 111 | 79 |  |
| rv32mi-p-ma_fetch | PASS | 128 | 92 |  |
| rv32mi-p-ma_addr | PASS | 352 | 212 |  |
| rv32mi-p-scall | PASS | 111 | 83 |  |
| rv32mi-p-sbreak | PASS | 92 | 68 |  |
| rv32mi-p-shamt | PASS | 88 | 68 |  |
| rv32mi-p-lw-misaligned | PASS | 169 | 122 |  |
| rv32mi-p-lh-misaligned | PASS | 103 | 78 |  |
| rv32mi-p-sh-misaligned | PASS | 112 | 86 |  |
| rv32mi-p-sw-misaligned | PASS | 172 | 126 |  |
| rv32mi-p-zicntr | PASS | 131 | 117 |  |
| rv32mi-p-instret_overflow | PASS | 89 | 16 |  |
| rv32mi-p-pmpaddr | EXCLUDED |  |  | cần PMP – isa/rv64mi/pmpaddr.S dòng 27 `csrw pmpcfg0, zero` trap illegal vì lõi không hiện thực PMP (spec mục 10.2 cho phép loại trừ) |

Tái tạo: `.venv/bin/python scripts/run_isa.py --config m1c1_bp0`

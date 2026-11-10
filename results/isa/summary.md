# riscv-tests – ma trận cấu hình

| Cấu hình RTL | ELF | Bộ test | PASS | FAIL | EXCLUDED |
|---|---|---|---|---|---|
| `m1c1_bp0` | `imc` | rv32ui,rv32um,rv32uc,rv32mi | 64 | 0 | 3 |
| `m1c1_bp1` | `imc` | rv32ui,rv32um,rv32uc,rv32mi | 64 | 0 | 3 |
| `m1c1_bp2` | `imc` | rv32ui,rv32um,rv32uc,rv32mi | 64 | 0 | 3 |
| `m1c0_bp2` | `im` | rv32ui,rv32um,rv32mi | 63 | 0 | 3 |
| `m0c0_bp2` | `i` | rv32ui,rv32mi | 55 | 0 | 3 |
| `sc` | `i` | rv32ui | 41 | 0 | 1 |
| `m1c1_bp2_sync` | `imc` | rv32ui,rv32um,rv32uc,rv32mi | 64 | 0 | 3 |

Test bị loại trừ và lý do:

- `rv32mi-p-breakpoint`: cần CSR debug trigger (Sdtrig) – isa/rv64mi/breakpoint.S dòng 33 `csrw tselect, x0` trap illegal vì lõi không hiện thực tselect/tdata1/tdata2 (chỉ M-mode, không có debug module)
- `rv32mi-p-pmpaddr`: cần PMP – isa/rv64mi/pmpaddr.S dòng 27 `csrw pmpcfg0, zero` trap illegal vì lõi không hiện thực PMP (spec mục 10.2 cho phép loại trừ)
- `rv32ui-p-ma_data`: core traps on misaligned load/store (allowed by the spec); the trap behaviour is checked by rv32mi-p-ma_addr

Tái tạo: `make isa` (= `.venv/bin/python scripts/run_isa.py --matrix`)

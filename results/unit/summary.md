# Unit testbench – tổng kết

| Testbench | Kết quả | Seed | Thời gian (s) | Ghi chú |
|---|---|---|---|---|
| tb_alu | PASS | 1 | 4.5 | 15440 checks |
| tb_regfile | PASS | 1 | 4.8 | 40134 checks |
| tb_muldiv | PASS | 1 | 4.5 | 4316 checks |
| tb_compressed_decoder | PASS | 1 | 5.1 | 2104 checks |
| tb_bp | PASS | 1 | 5.0 | 6304 checks |
| tb_csr | PASS | 1 | 0.0 | 136 checks |
| tb_apb_bridge | PASS | 1 | 0.0 | 3037 checks |
| tb_intc | PASS | 1 | 4.2 | 2209 checks |

Chưa có (chưa tới Phase tương ứng): tb_fifo, tb_uart, tb_spi, tb_timer, tb_gpio

Tái tạo: `make unit` (= `.venv/bin/python scripts/run_unit.py`)

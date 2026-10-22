# Unit testbench – tổng kết

| Testbench | Kết quả | Seed | Thời gian (s) | Ghi chú |
|---|---|---|---|---|
| tb_alu | PASS | 1 | 0.0 | 15440 checks |
| tb_regfile | PASS | 1 | 0.0 | 40134 checks |
| tb_muldiv | PASS | 1 | 0.0 | 4316 checks |
| tb_compressed_decoder | PASS | 1 | 0.1 | 2104 checks |
| tb_bp | PASS | 1 | 0.0 | 6304 checks |

Chưa có (chưa tới Phase tương ứng): tb_csr, tb_fifo, tb_apb_bridge, tb_uart, tb_spi, tb_timer, tb_gpio, tb_intc

Tái tạo: `make unit` (= `.venv/bin/python scripts/run_unit.py`)

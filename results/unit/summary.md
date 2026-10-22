# Unit testbench – tổng kết

| Testbench | Kết quả | Seed | Thời gian (s) | Ghi chú |
|---|---|---|---|---|
| tb_alu | PASS | 1 | 4.4 | 15440 checks |
| tb_regfile | PASS | 1 | 4.4 | 40134 checks |

Chưa có (chưa tới Phase tương ứng): tb_muldiv, tb_compressed_decoder, tb_bp, tb_csr, tb_fifo, tb_apb_bridge, tb_uart, tb_spi, tb_timer, tb_gpio, tb_intc

Tái tạo: `make unit` (= `.venv/bin/python scripts/run_unit.py`)

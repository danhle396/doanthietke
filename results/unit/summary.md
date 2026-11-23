# Unit testbench – tổng kết

| Testbench             | Kết quả | Seed | Thời gian (s) | Ghi chú      |
| --------------------- | ------- | ---- | ------------- | ------------ |
| tb_alu                | PASS    |    1 |           0.0 | 15440 checks |
| tb_regfile            | PASS    |    1 |           0.0 | 40134 checks |
| tb_muldiv             | PASS    |    1 |           0.1 | 4316 checks  |
| tb_compressed_decoder | PASS    |    1 |           0.1 | 2104 checks  |
| tb_bp                 | PASS    |    1 |           0.0 | 6304 checks  |
| tb_csr                | PASS    |    1 |           0.0 | 136 checks   |
| tb_fifo               | PASS    |    1 |           0.0 | 77335 checks |
| tb_apb_bridge         | PASS    |    1 |           0.0 | 3038 checks  |
| tb_dbus_xbar          | PASS    |    1 |           0.0 | 5815 checks  |
| tb_uart               | PASS    |    1 |           0.1 | 549 checks   |
| tb_spi                | PASS    |    1 |           0.0 | 395 checks   |
| tb_timer              | PASS    |    1 |           0.0 | 220 checks   |
| tb_gpio               | PASS    |    1 |           0.0 | 617 checks   |
| tb_intc               | PASS    |    1 |           0.0 | 2209 checks  |

Tái tạo: `make unit` (= `.venv/bin/python scripts/run_unit.py`)

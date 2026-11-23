# System test – tổng kết

| Test           | Cấu hình RTL | Kết quả | Chu kỳ  | Ghi chú                                          |
| -------------- | ------------ | ------- | ------- | ------------------------------------------------ |
| hello          | `m1c1_bp2`   | PASS    |   12135 |                                                  |
| uart_irq_echo  | `m1c1_bp2`   | PASS    |   44819 | RESULT uart_irq_echo: PASS (79 checks, 0 errors) |
| spi_flash      | `m1c1_bp2`   | PASS    |   71663 | RESULT spi_flash: PASS (281 checks, 0 errors)    |
| spi_modes      | `m1c1_bp2`   | PASS    |   63188 | RESULT spi_modes: PASS (16 checks, 0 errors)     |
| timer_irq      | `m1c1_bp2`   | PASS    |   40534 | RESULT timer_irq: PASS (23 checks, 0 errors)     |
| timer_irq      | `sc`         | PASS    |   40355 | RESULT timer_irq: PASS (23 checks, 0 errors)     |
| gpio_irq       | `m1c1_bp2`   | PASS    |   15795 | RESULT gpio_irq: PASS (11 checks, 0 errors)      |
| irq_priority   | `m1c1_bp2`   | PASS    |   21746 | RESULT irq_priority: PASS (8 checks, 0 errors)   |
| irq_priority   | `sc`         | PASS    |   21546 | RESULT irq_priority: PASS (8 checks, 0 errors)   |
| exceptions     | `m1c1_bp2`   | PASS    |  129554 | RESULT exceptions: PASS (62 checks, 0 errors)    |
| exceptions     | `m1c0_bp2`   | PASS    |  132125 | RESULT exceptions: PASS (66 checks, 0 errors)    |
| exceptions     | `sc`         | PASS    |  132102 | RESULT exceptions: PASS (66 checks, 0 errors)    |
| irq_during_div | `m1c1_bp2`   | PASS    |  494430 | RESULT irq_during_div: PASS (3 checks, 0 errors) |
| demo           | `m1c1_bp2`   | PASS    | 4088021 |                                                  |
| branch_smc     | `m1c1_bp2`   | PASS    |   24718 | RESULT branch_smc: PASS (4 checks, 0 errors)     |
| branch_smc     | `m1c1_bp0`   | PASS    |   24775 | RESULT branch_smc: PASS (4 checks, 0 errors)     |
| branch_smc     | `sc`         | PASS    |   24691 | RESULT branch_smc: PASS (4 checks, 0 errors)     |
| muldiv_rand    | `m1c1_bp2`   | PASS    | 6031222 | RESULT muldiv_rand: PASS (9 checks, 0 errors)    |
| muldiv_rand    | `m1c0_bp2`   | PASS    | 6040505 | RESULT muldiv_rand: PASS (9 checks, 0 errors)    |

Tiêu chí PASS: mã thoát 0 từ SIM_CTRL, output UART khớp file kỳ vọng (nếu có), không có lỗi frame/parity ở BFM UART, không có lỗi giao thức ở BFM flash.

Tái tạo: `make systest` (= `.venv/bin/python scripts/run_systest.py`)

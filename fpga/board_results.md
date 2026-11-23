# Kết quả kiểm thử trên board DE2 (qua JTAG console)

Chạy trên board DE2 thật ngày **17/11/2026** bằng `python tools/jtag_uart.py test` (Windows, Quartus II 13.0sp1,
cáp USB-Blaster). Mỗi firmware được nạp vào RAM (MIF → Assembler → JTAG); đầu ra UART của CPU đi qua cầu
`jtag_uart_bridge` về máy tính và được so với `firmware/<tên>/uart_sim.txt` (mô phỏng RTL của **cùng file nhị
phân**). `board_demo` chạy các lệnh h, i, s, b, f, q; dòng phụ thuộc thời gian / công tắc / flash chỉ kiểm tra dạng.

Bitstream: SoC đã sửa bộ nhân (`MULH*`), có console JTAG và màn hình 7 đoạn; chưa có phím KEY1–3 và lệnh `t`
(thêm sau, chỉ ở lớp vỏ board và `board_demo`; SoC và 14 firmware còn lại không đổi – xem mục cuối).

**Kết quả: 15/15 ĐẠT** (13 ở lần chạy đầu; 2 ĐẠT sau khi sửa cách chạy của công cụ – giải thích bên dưới).

| Firmware         | Kết quả | Tóm tắt (dòng đầu ra trên board)                                                                              |
| ---------------- | ------- | ------------------------------------------------------------------------------------------------------------- |
| `board_demo`     | ĐẠT     | 24 MHz, `misa = 0x40001104`; `b` run 2 `cycles=391205 instret=323166`, `result = 0x1dfc7c31`; h, s, f, q đúng |
| `hello`          | ĐẠT     | `Hello from RV32IMC SoC!`                                                                                     |
| `exceptions`     | ĐẠT     | `RESULT exceptions: PASS (62 checks, 0 errors)`                                                               |
| `timer_irq`      | ĐẠT     | `RESULT timer_irq: PASS (23 checks, 0 errors)`                                                                |
| `irq_priority`   | ĐẠT     | `RESULT irq_priority: PASS (8 checks, 0 errors)`                                                              |
| `irq_during_div` | ĐẠT     | `RESULT irq_during_div: PASS (3 checks, 0 errors)`                                                            |
| `branch_smc`     | ĐẠT \*  | `RESULT branch_smc: PASS (4 checks, 0 errors)`                                                                |
| `muldiv_rand`    | ĐẠT     | `RESULT muldiv_rand: PASS (9 checks, 0 errors)` – 8 lệnh RV32M + chia 64 bit                                  |
| `dhrystone`      | ĐẠT     | `cycles=333617 instret=277083 cpi_x1000=1204`                                                                 |
| `coremark`       | ĐẠT     | `cycles=695588 instret=626769 cpi_x1000=1109`                                                                 |
| `median`         | ĐẠT     | `cycles=5404 instret=4307 cpi_x1000=1254`                                                                     |
| `multiply`       | ĐẠT     | `cycles=22282 instret=20953 cpi_x1000=1063`                                                                   |
| `qsort`          | ĐẠT \*  | `cycles=148150 instret=123560 cpi_x1000=1199`                                                                 |
| `towers`         | ĐẠT     | `cycles=4028 instret=3777 cpi_x1000=1066`                                                                     |
| `vvadd`          | ĐẠT     | `cycles=2489 instret=2469 cpi_x1000=1008`                                                                     |

Mọi số chu kỳ ở trên **trùng tuyệt đối** với mô phỏng RTL (`firmware/DANH_SACH.md`). `spi_flash` và `demo` cần
module flash W25Qxx trên JP1, không có trong lần chạy này.

## \* `branch_smc` và `qsort`: lần chạy đầu SAI, nguyên nhân ở công cụ, không ở phần cứng

Ở lần chạy đầu (09:30), công cụ để firmware chạy ngay khi nạp bitstream, rồi **reset CPU** và lấy đầu ra của lần
chạy thứ hai. Reset (KEY0 hay bit reset của console) không nạp lại RAM từ MIF, nên hai chương trình tự sửa bộ nhớ
của mình cho kết quả khác ở lần chạy thứ hai:

```
branch_smc (lần chạy thứ hai, mã đã bị lần chạy đầu vá):
   CHECK FAILED line 46: before patch: 101 101
   self-modifying code: before=101,101 after=101,106      (mô phỏng: before=0,0 after=101,106)
   RESULT branch_smc: FAIL (4 checks, 1 errors)
qsort (lần chạy thứ hai, mảng đã được sắp xếp):
   [bench] name=qsort cycles=85159 instret=80471 cpi_x1000=1058      (mô phỏng: cycles=148150)
```

Công cụ được sửa để lấy đầu ra của **lần chạy đầu tiên** sau khi nạp (FIFO 8 KB của cầu giữ sẵn); chạy lại hai
firmware này (`python tools/jtag_uart.py test branch_smc qsort`): cả hai ĐẠT, `qsort` `cycles=148150` trùng mô
phỏng. 13 firmware còn lại không tự sửa bộ nhớ nên kết quả lần đầu đã đúng.

## Bitstream hiện tại (thêm phím KEY1–3 và lệnh `t`)

Sau lần chạy trên, chỉ thay đổi lớp vỏ board (`key_cmd.sv`, `board_display.sv`) và `board_demo` (thêm lệnh tự kiểm
tra `t`; mã máy dời chỗ nên số chu kỳ tham chiếu của lệnh `b` thành `391209`). Kiểm chứng trên board bằng video demo
(`results/board/`): KEY1 → HEX `391209` (trùng mô phỏng `firmware/board_demo/uart_sim.txt`), KEY2 → `tESt PASS`
(LEDG7 sáng), công tắc → LED (ngắt GPIO), KEY0 → reset.

Nguồn: đầu ra console của hai lần chạy ngày 17/11/2026 (chi tiết đầu ra UART đầy đủ của từng firmware không được lưu
lại; file báo cáo gốc bị ghi đè khi chạy riêng hai firmware). Tái tạo: `python tools/jtag_uart.py test`.

# MulDiv – extension M (`rtl/core/muldiv.sv`)

## Bộ nhân: 33×33 có dấu, tổ hợp, 1 chu kỳ

Mở rộng mỗi toán hạng thêm 1 bit: bit dấu nếu phép coi toán hạng là có dấu, 0 nếu không dấu.

| Lệnh | a | b | Lấy |
|---|---|---|---|
| MUL | – | – | `prod[31:0]` |
| MULH | có dấu | có dấu | `prod[63:32]` |
| MULHSU | có dấu | không dấu | `prod[63:32]` |
| MULHU | không dấu | không dấu | `prod[63:32]` |

Một bộ nhân 33×33 có dấu dùng chung cho cả 4 lệnh. Đây là khối lớn và thường nằm trên đường găng (critical path)
khi tổng hợp – xem `results/synth/summary.md`.

## Bộ chia: radix-2, lặp 32 vòng

```
IDLE --(DIV hợp lệ, không đặc biệt)--> BUSY (32 vòng) --> DONE --(lệnh rời EX)--> IDLE
  ^                                      |                  |
  +---------------- kill (flush) --------+------------------+
```

- Lúc bắt đầu chốt `|a|`, `|b|` và dấu kết quả; mỗi vòng: `r = {r, q[31]} - d`, nếu không âm thì nhận, bit thương = 1.
- Kết thúc: đổi dấu thương nếu dấu hai toán hạng khác nhau, dấu phần dư theo số bị chia.
- Trường hợp đặc biệt trả ngay (không lặp): chia 0 → DIV = -1, DIVU = 2³²-1, REM/REMU = số bị chia;
  `-2³¹ / -1` → DIV = -2³¹, REM = 0.
- Trong lúc BUSY: stall IF/ID/EX, bubble vào MEM; counter `mhpmcounter8` đếm chu kỳ này. `tb_muldiv` đo độ trễ
  (33 chu kỳ không ready).
- Toán hạng được chốt nên việc forward thay đổi trong lúc chia không ảnh hưởng.
- DONE giữ kết quả khi EX còn bị stall bởi MEM (chờ bus); chỉ về IDLE khi lệnh thực sự rời EX.
- `kill` (trap/mret/fence.i ở MEM) hủy phép chia đang dở – kiểm tra ở `tb_muldiv` (hủy ở mọi thời điểm rồi chia lại).

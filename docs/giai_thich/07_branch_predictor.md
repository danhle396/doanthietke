# Dự đoán rẽ nhánh (`rtl/core/bp/bht.sv`, `btb.sv`, `branch_predictor.sv`)

## Ba chế độ (`BP_MODE`)

| Mode | Cơ chế                                 | Penalty khi đúng / sai                                   |
| ---- | -------------------------------------- | -------------------------------------------------------- |
|    0 | luôn đoán not-taken                    | taken = sai: 2 chu kỳ                                    |
|    1 | BHT tra ở ID cho branch; JAL nhảy ở ID | đoán taken đúng: 1 bubble; sai: 2                        |
|    2 | BTB + BHT tra ở IF                     | đúng: 0; sai: 2; JAL lần đầu (BTB miss): 1 (redirect ID) |

## BHT – counter 2 bit bão hòa

```
 00 strongly NT <-> 01 weakly NT <-> 10 weakly T <-> 11 strongly T
   taken: +1 (tối đa 11), not-taken: -1 (tối thiểu 00); dự đoán = bit[1]
```

Reset `01`. Chỉ số `pc[log2(N):1]` – bắt đầu từ bit 1 vì có lệnh 16 bit (dùng bit 2 trở lên sẽ khiến hai lệnh nén
liền nhau chung một entry). **So với counter 1 bit**: vòng lặp chạy N lần có một lần thoát; counter 1 bit đoán sai
2 lần mỗi lượt vòng lặp (lần thoát và lần quay lại), counter 2 bit chỉ sai 1 lần vì một lần ngoại lệ chưa làm đổi
dự đoán (hysteresis).

## BTB – direct-mapped

Entry `{valid, tag, target[31:1], type}`; chỉ số `pc[log2(M):1]`, tag là phần còn lại. Cấp phát khi lệnh nhảy taken.
IF dự đoán nhảy nếu hit và (type là JAL/JALR hoặc BHT nói taken). JALR dùng đích lần trước (đúng cho `jalr` gọi hàm
qua con trỏ cố định, sai cho `ret` từ nhiều nơi gọi – lý do đề xuất RAS ở "hướng phát triển").

**Alias:** hai PC khác nhau cùng chỉ số → tag khác → miss. Nhưng sau khi entry bị ghi đè, một lệnh **không phải
nhánh** có thể nằm ở PC trùng chỉ số và tag của một nhánh cũ (ví dụ code bị ghi đè – self-modifying, hoặc tag bị
cắt ngắn ở BTB nhỏ – với tag đầy đủ như ở đây chỉ xảy ra khi bộ nhớ lệnh thay đổi). Khi đó IF đoán nhảy cho một lệnh
ALU; EX thấy `pred_npc != pc+len` → redirect và xóa entry (`upd_btb_inv`).

## Vì sao so sánh `pred_npc` bắt được mọi sai dự đoán?

Front-end có thể sai theo nhiều cách: sai hướng, sai đích (JALR), nhảy khi không phải nhánh (alias), hoặc đoán
không nhảy khi thật ra nhảy. Nhưng tất cả đều quy về một sự kiện: **địa chỉ lệnh tiếp theo đã lấy (`pred_npc`)
khác địa chỉ đúng (`actual_npc`)**. So sánh trực tiếp hai địa chỉ này thay cho việc phân loại từng trường hợp →
một bộ so sánh 32 bit, dùng chung cho cả 3 mode.

## Hiệu quả

Xem `results/perf/summary.md`: CPI và độ chính xác theo mode, quét BHT × BTB theo diện tích (`results/synth`).

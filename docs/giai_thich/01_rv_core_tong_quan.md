# `rv_core` – tổng quan pipeline 5 tầng

File: `rtl/core/rv_core.sv` (nối dây), các tầng trong `rtl/core/*_stage.sv`.

## 1. Năm tầng

```
        +------+   if_id   +------+   id_ex   +------+   ex_mem   +------+   mem_wb   +------+
 PC --> |  IF  | --------> |  ID  | --------> |  EX  | ---------> | MEM  | ---------> |  WB  |
        +------+           +------+           +------+            +------+            +------+
          ^  ^  ^             |                  |  ^                |                    |
          |  |  +-- redirect -+                  |  +-- forward -----+--------------------+
          |  +------ sai dự đoán ----------------+
          +--------- trap / mret / fence.i -----------------------------+
```

| Tầng | Việc chính                                                                                       | Kết quả ghi vào |
| ---- | ------------------------------------------------------------------------------------------------ | --------------- |
| IF   | đưa `pc_q` ra `ibus_addr`, nhận 32 bit, biết lệnh 16/32 bit, dự đoán (BP_MODE 2)                 | `if_id`         |
| ID   | giải nén C, decode, sinh imm, đọc regfile, phát hiện ngoại lệ ID, redirect JAL / branch (mode 1) | `id_ex`         |
| EX   | forward, ALU, so sánh nhánh, `actual_npc`, MulDiv, phát hiện sai dự đoán                         | `ex_mem`        |
| MEM  | load/store, CSR, **điểm commit**: trap, MRET, FENCE.I                                            | `mem_wb`        |
| WB   | ghi regfile, `minstret`, performance counter, commit log                                         | –               |

## 2. Một lệnh mang theo gì

Ngoài các trường điều khiển, mỗi lệnh mang: `valid`, `pc`, mã lệnh gốc `insn` (16 bit nếu là lệnh nén – dùng cho
`mtval` và commit log), `is_c`, `pred_npc` (PC kế đã dự đoán), `exc/exc_cause/exc_tval`. Nhờ mang `pred_npc` theo,
tầng EX chỉ cần một phép so sánh `actual_npc != pred_npc` để biết có đoán sai hay không.

## 3. Ví dụ dòng chảy (không hazard)

| Chu kỳ | IF  | ID  | EX  | MEM | WB  |
| ------ | --- | --- | --- | --- | --- |
|      1 | I1  |     |     |     |     |
|      2 | I2  | I1  |     |     |     |
|      3 | I3  | I2  | I1  |     |     |
|      4 | I4  | I3  | I2  | I1  |     |
|      5 | I5  | I4  | I3  | I2  | I1  |

Mỗi chu kỳ một lệnh hoàn tất → CPI lý tưởng = 1. CPI thật > 1 do stall load-use, MulDiv, chờ bus APB và
penalty dự đoán sai (xem `results/perf/summary.md`, phân rã CPI).

## 4. Ba nguyên tắc cần nhớ khi bảo vệ

1. **Tầng già hơn luôn thắng.** Trap ở MEM thắng sai dự đoán ở EX, sai dự đoán ở EX thắng redirect ở ID.
2. **Side effect đúng một lần, ở chu kỳ lệnh rời tầng.** Redirect, cập nhật predictor, đếm counter chỉ xảy ra khi
   tầng không bị stall – nên một nhánh bị giữ ở EX vì MEM đang chờ bus sẽ không redirect hai lần.
3. **Lệnh mang ngoại lệ là NOP.** Nó không ghi thanh ghi, không truy cập bus, không redirect; chỉ "trôi" tới MEM
   để gây trap đúng thứ tự chương trình (ngoại lệ chính xác).

## 5. Tín hiệu quan trọng trong `rv_core.sv`

| Tín hiệu                                     | Ý nghĩa                                                |
| -------------------------------------------- | ------------------------------------------------------ |
| `stall_if/id/ex/mem`                         | tầng giữ nguyên thanh ghi đầu vào                      |
| `flush_if_id/id_ex/ex_mem/mem_wb`            | thanh ghi nhận bubble                                  |
| `id_redirect`, `ex_redirect`, `mem_redirect` | ba nguồn đổi hướng PC                                  |
| `fwd_a`, `fwd_b`                             | 0 = giá trị đọc ở ID, 1 = từ `ex_mem`, 2 = từ `mem_wb` |
| `md_stall`, `bus_wait`                       | MulDiv chưa xong, dbus chưa ready                      |
| `mem_trap`, `trap_irq`, `trap_cause`         | trap đang xảy ra ở MEM                                 |

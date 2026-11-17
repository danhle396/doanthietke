# Walkthrough: theo dõi pipeline từng chu kỳ

Chương trình: `sw/examples/walkthrough/walk.S` (rv32imc), chạy trên cấu hình mặc định `m1c1_bp2`. Bảng đầy đủ theo
từng chu kỳ được **sinh tự động từ mô phỏng** (`scripts/make_waves.py`) ở `results/waves/walkthrough_table.md`;
hình tổng thể `results/waves/walkthrough_pipeline.png`. Mở waveform bằng GTKWave: `docs/gtkw/pipeline.gtkw`
(xem `huong_dan_chay.md`).

## Đoạn chương trình

```asm
80000144  lw    t0, 0(a0)          # load
80000148  add   t1, t0, t0         # dùng ngay kết quả load -> load-use
8000014c  addi  t2, t1, 1          # forward từ ex_mem
80000150  add   t3, t2, t1         # rs1 từ ex_mem, rs2 từ mem_wb
80000154  c.addi t3, 4             # lệnh nén 16 bit
80000156  c.mv  a2, t3
80000158  c.add a2, t2
8000015a  beq   t3, t3, 80000166   # luôn nhảy; lần đầu BTB chưa biết -> đoán sai; lệnh 32 bit ở địa chỉ ...a (vắt qua word)
8000015e  addi  a3, x0, 1          # đường sai, bị flush
80000162  addi  a3, x0, 2          # đường sai, bị flush
80000166  csrrsi x0, mstatus, 8    # MIE = 1
8000016a  sw    x0, 0(a1)          # ghi TIMER.MSIP = 0 (truy cập APB)
8000016e  addi  t4, x0, 1
80000172  sw    t4, 0(a1)          # MSIP = 1 -> ngắt phần mềm
80000176  addi  a4, x0, 3          # bị hủy bởi ngắt, chạy lại sau MRET
...
80000182  ecall                    # ngoại lệ mcause 11; handler cộng mepc 4
```

## Diễn biến (số chu kỳ theo cột "Chu kỳ" của bảng)

### 1. Load-use (chu kỳ 3–6)

| Chu kỳ | IF            | ID           | EX                         | MEM      | WB      |
| ------ | ------------- | ------------ | -------------------------- | -------- | ------- |
|      3 | add t1        | **lw t0**    | c.addi a1                  | lui a1   | addi a0 |
|      4 | addi t2       | **add t1**   | **lw t0**                  | c.addi   | lui     |
|      5 | addi t2 (giữ) | add t1 (giữ) | *bubble*                   | lw t0    | c.addi  |
|      6 | add t3        | addi t2      | add t1 (rs1, rs2 ← mem_wb) | *bubble* | lw t0   |

Ở chu kỳ 4, `lw` ở EX có `rd = t0` trùng nguồn của `add` ở ID → `load_use = 1`: IF và ID giữ nguyên, EX nhận bubble
(`flush_id_ex`). Ở chu kỳ 6 dữ liệu load đã nằm trong `mem_wb` và được forward vào cả hai toán hạng của `add`.
Mất đúng 1 chu kỳ. Hình: `results/waves/load_use_forwarding.png`.

### 2. Forwarding (chu kỳ 7–8)

Chu kỳ 7: `addi t2, t1, 1` ở EX lấy `t1` từ `ex_mem` (lệnh `add t1` vừa ở MEM). Chu kỳ 8: `add t3, t2, t1` lấy
`t2` từ `ex_mem` và `t1` từ `mem_wb` – thấy rõ quy tắc: cùng lúc có hai nguồn thì nguồn trẻ hơn (`ex_mem`) cho `t2`,
còn `t1` đã đi tới WB nên lấy từ `mem_wb`.

### 3. Lệnh nén (chu kỳ 7–10)

`c.addi` ở `0x154`, `c.mv` ở `0x156`, `c.add` ở `0x158`: PC ở IF tăng 2 mỗi chu kỳ. Lệnh `beq` tiếp theo nằm ở
`0x15a` (bit 1 = 1) – một lệnh 32 bit vắt qua hai word – vẫn được lấy trong một chu kỳ nhờ RAM ghép nửa word. Hình:
`results/waves/compressed.png`.

### 4. Nhánh đoán sai (chu kỳ 10–13)

`beq` vào IF ở chu kỳ 10 khi BTB chưa có entry → dự đoán tuần tự (`pred_npc = 0x15e`). Hai lệnh đường sai `addi a3`
được lấy ở chu kỳ 11, 12. Ở chu kỳ 12 `beq` tới EX: `actual_npc = 0x166 ≠ pred_npc` → `ex_redirect`, flush `if_id`
và `id_ex`; chu kỳ 13 IF lấy `0x166`, ID và EX là bubble. Penalty 2 chu kỳ; BTB/BHT được cập nhật nên lần sau nhánh
này được đoán đúng. Hình: `results/waves/mispredict_flush.png`.

### 5. Chờ bus APB (chu kỳ 17–19)

`sw x0, 0(a1)` ghi TIMER.MSIP qua APB: lệnh ở MEM giữ request 3 chu kỳ; IF–MEM đứng yên, WB nhận bubble.

### 6. Ngắt (chu kỳ 24–37)

`sw t4` đặt MSIP = 1; khi lệnh `addi a4, x0, 3` (`0x176`) tới MEM ở chu kỳ 24, `take_irq = 1`: lệnh này bị hủy,
`mepc = 0x176`, `mcause = 0x8000_0003`, các tầng trẻ hơn bị flush, IF nhảy tới `mtvec` (handler `0x194`). Handler đọc
`mcause` (CSR-use stall 1 chu kỳ ở chu kỳ 27), nhảy tới nhánh xử lý ngắt (một lần đoán sai), xóa MSIP và `mret`.
MRET ở MEM (chu kỳ 36) flush và nạp `mepc`: chu kỳ 37 IF lấy lại `0x176` – lệnh bị hủy được thực thi lại. Hình:
`results/waves/trap_entry_exit.png`.

### 7. Ngoại lệ ECALL (chu kỳ 43–…)

`ecall` tới MEM ở chu kỳ 43 → trap mcause 11, `mepc = 0x182`; handler cộng `mepc` thêm 4 và `mret` → tiếp tục ở
`0x186`. Ở lần này nhánh `blt` trong handler được BTB dự đoán theo lần trước (nhảy) nhưng thực tế không nhảy → một
lần sai dự đoán nữa: cho thấy predictor học theo lịch sử, không phải theo ngữ nghĩa.

## Điểm rút ra

- Mọi tình huống trong bài đều được giải quyết bởi `hazard_unit` theo đúng bảng quy tắc trong `06_hazard_forward.md`.
- Trap và MRET luôn xử lý ở MEM, nên lệnh tại `mepc` là lệnh đầu tiên chưa hoàn tất – ngoại lệ chính xác.
- Có thể tự tạo lại bảng và hình: `.venv/bin/python scripts/make_waves.py`.

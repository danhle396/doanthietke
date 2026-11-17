# EX – thực thi (`rtl/core/ex_stage.sv`, `alu.sv`, `branch_unit.sv`, `muldiv.sv`)

## Các khối

| Khối          | Việc                                                                                    |
| ------------- | --------------------------------------------------------------------------------------- |
| Forward mux   | chọn `rs1/rs2` từ `id_ex`, `ex_mem` hoặc `mem_wb` (xem `06_hazard_forward.md`)          |
| `alu`         | ADD/SUB/SLL/SLT/SLTU/XOR/SRL/SRA/OR/AND; dùng chung một bộ trừ 33 bit cho SUB/SLT/SLTU  |
| `branch_unit` | so sánh nhánh, `target` (`pc+imm` hoặc `(rs1+imm)&~1`), `link = pc + len`, `actual_npc` |
| `muldiv`      | nhân 1 chu kỳ, chia lặp 32 vòng (`09_muldiv.md`)                                        |

`len = is_c ? 2 : 4`. Link của JAL/JALR là `pc + len` – đúng cho cả `c.jal`/`c.jalr`.

## Phát hiện sai dự đoán – một phép so sánh cho mọi chế độ

```
actual_npc = taken ? target : pc + len
mispredict = ex_valid && !exception && (actual_npc != pred_npc)
```

`pred_npc` là PC mà front-end **đã thực sự** dùng để lấy lệnh tiếp theo. Bất kể lỗi đến từ đâu – BHT đoán sai
hướng, BTB trả đích cũ của JALR, BTB alias làm một lệnh ALU "nhảy", hoặc mode 0 luôn đoán not-taken – khác biệt
đều thể hiện thành `actual_npc != pred_npc`. Khi đó flush `if_id` và `id_ex` (2 bubble) và nạp `actual_npc`.

## Cập nhật predictor (chỉ khi lệnh rời EX và không bị flush)

- `upd_bht` cho branch có điều kiện (taken/not-taken).
- `upd_btb_wr` cho mọi lệnh nhảy taken: ghi `{tag, target, type}`.
- `upd_btb_inv`: lệnh **không** phải nhánh nhưng `pred_npc != pc+len` → BTB alias → xóa entry.

## Ngoại lệ ở EX

Chỉ có instruction-address-misaligned khi `ENABLE_C = 0` và đích nhảy taken có bit 1 = 1: mcause 0,
`mtval = đích`, **không redirect** (trap ở MEM sẽ đổi hướng). Lệnh có ngoại lệ không cập nhật predictor.

## Tình huống khó

- **EX bị stall vì MEM chờ bus**: lệnh ở WB vẫn retire và rời pipeline; nếu lệnh ở EX đang lấy toán hạng forward
  từ `mem_wb` thì nguồn đó biến mất. Giải pháp: khi EX stall, `id_ex` chép lại giá trị đã forward (decision D4).
- **Nhánh ở EX trong lúc MEM chờ bus**: chưa redirect; redirect ở chu kỳ nhánh được đi tiếp (đúng một lần).

# IF – lấy lệnh (`rtl/core/if_stage.sv`)

## Chức năng

- Giữ thanh ghi `pc_q` (reset = `0x8000_0000`), đưa thẳng ra `ibus_adr_o` (master Wishbone chỉ đọc).
- Nhận `ibus_dat_i` (32 bit bắt đầu tại `pc_q`) kèm `ACK` **trong cùng chu kỳ** vì RAM đọc tổ hợp; chu kỳ không có
  `ACK/ERR` → giữ PC, đưa bubble vào ID (không xảy ra với RAM của SoC).
- Biết lệnh dài 16 hay 32 bit: `is_c = ENABLE_C && rdata[1:0] != 2'b11`, `seq_npc = pc_q + (is_c ? 2 : 4)`.
- BP_MODE 2: tra BTB + BHT theo `pc_q`; nếu BTB hit và (JAL/JALR hoặc BHT đoán taken) → `pred_npc = btb_target`.
- Chọn PC kế và ghi `if_id = {valid, pc, insn 32 bit, is_c, pred_npc, fault}`.

## Mux chọn PC kế (ưu tiên giảm dần)

```
if (mem_redirect)     pc_d = mem_target;   // trap -> mtvec, mret -> mepc, fence.i -> pc+len
else if (ex_redirect) pc_d = ex_target;    // sửa sai dự đoán
else if (id_redirect) pc_d = id_target;    // JAL / branch đoán taken ở ID
else if (stall_if)    pc_d = pc_q;         // giữ
else                  pc_d = pred_npc;     // dự đoán IF hoặc tuần tự
```

Redirect đứng trên stall: nếu có trap trong lúc IF đang bị giữ (ví dụ load-use), PC vẫn phải nhảy tới `mtvec`.

## Tình huống khó: lệnh 32 bit nằm vắt qua ranh giới word

Với extension C, một lệnh 32 bit có thể bắt đầu ở địa chỉ `...2` (bit 1 = 1): nửa thấp nằm ở word i, nửa cao ở
word i+1. `ram_dp` giải quyết bằng cổng lệnh đặc biệt:

```
addr[1] = 0 -> rdata = word[i]
addr[1] = 1 -> rdata = {word[i+1][15:0], word[i][31:16]}
```

Nên IF **luôn** có đủ 32 bit trong một chu kỳ, không cần prefetch buffer hay trạng thái "đang chờ nửa sau".
Đây là lý do chính chọn RAM đọc tổ hợp (xem `11_bo_nho_bus.md`). Functional coverage có điểm
`c_insn32_straddle` chứng minh tình huống này đã xảy ra trong mô phỏng.

## Ngoại lệ ở IF

`ibus_err` (PC ngoài RAM) → lệnh được đánh dấu `fault`, ở ID trở thành instruction access fault (mcause 1,
`mtval = pc`). Dữ liệu lệnh lúc này vô nghĩa nên lệnh bị biến thành NOP.

## Câu hỏi hay gặp

- *Vì sao không giải nén C ngay ở IF?* Để đường tổ hợp IF ngắn: IF đã có RAM đọc + tra BTB/BHT + mux PC. Giải nén
  chuyển sang ID (spec 4.3).
- *Khi stall, IF có đọc lại RAM không?* Có, mỗi chu kỳ đọc lại cùng `pc_q` – vô hại vì đọc không có side effect.

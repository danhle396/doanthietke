# ID – giải mã (`rtl/core/id_stage.sv`, `decoder.sv`, `compressed_decoder.sv`, `imm_gen.sv`, `regfile.sv`)

## Luồng

```
if_id.insn ──> compressed_decoder ──┐ (nếu is_c)
           └────────────────────────┴─> insn32 ─> decoder ─> tín hiệu điều khiển
                                                 └> imm_gen ─> imm
rs1/rs2 ─> regfile (2R1W, write-through) ─> giá trị toán hạng
```

## `compressed_decoder`

Ánh xạ mỗi lệnh RV32C sang lệnh 32 bit tương đương, ví dụ `c.addi4spn rd', nzuimm` → `addi rd', x2, nzuimm`,
`c.mv rd, rs2` → `add rd, x0, rs2`, `c.j off` → `jal x0, off`. Các encoding phải báo illegal:
toàn 0, C.ADDI4SPN `nzuimm = 0`, C.ADDI16SP / C.LUI `imm = 0`, C.LWSP `rd = 0`, C.JR `rs1 = 0`,
shift với `shamt[5] = 1`, lệnh dấu phẩy động nén, C.SUBW/C.ADDW (chỉ RV64).
Khi illegal: `mtval` = 16 bit gốc (không phải lệnh đã giải nén).

Kiểm chứng: `tb_compressed_decoder` so với **bảng do assembler sinh** (`scripts/gen_rvc_vectors.py` dịch cùng
lệnh với `.option rvc` và `.option norvc`) – kỳ vọng không do tay viết nên không lặp lại lỗi của RTL.

## `decoder`

Sinh: `alu_op`, chọn toán hạng A (`rs1`/`pc`/0), B (`rs2`/imm), loại imm, cờ lớp lệnh (branch, jal, jalr, load,
store, M, CSR, ecall, ebreak, mret, fence.i), `use_rs1/use_rs2` (để phát hiện load-use chính xác), `rd_we`
(= 0 khi `rd = x0`). Mọi encoding không hỗ trợ → `illegal` (kể cả lệnh M khi `ENABLE_M = 0`, `funct7` sai,
SYSTEM lạ như `sret`).

## Regfile write-through

WB ghi và ID đọc cùng thanh ghi trong cùng chu kỳ → ID nhận ngay giá trị mới (mux trước cổng đọc). Nhờ vậy không cần
đường forward thứ ba từ WB vào ID. Lõi single-cycle tắt tính năng này (tham số `WRITE_THROUGH = 0`) vì ở đó nó tạo
vòng tổ hợp.

## Ngoại lệ ở ID (ưu tiên)

1. `fault` từ IF → mcause 1, `mtval = pc`
2. illegal → mcause 2, `mtval = mã lệnh`
3. ECALL → 11; EBREAK / C.EBREAK → 3, `mtval = pc`

Lệnh có ngoại lệ được ghi vào `id_ex` với **mọi cờ side effect bị xóa** (NOP).

## Redirect ở ID

- BP_MODE ≥ 1: JAL có đích biết ngay ở ID (`pc + imm`) → nếu `pred_npc` khác đích, đổi hướng, mất 1 bubble thay vì 2.
- BP_MODE = 1: branch tra BHT theo PC của lệnh ở ID; đoán taken → nhảy tới `pc + imm` (1 bubble).
- `pred_npc` của lệnh được cập nhật theo đích mới, để EX vẫn so sánh đúng.
- Không redirect khi lệnh bị stall (redirect phát ra đúng lúc lệnh rời ID), khi tầng già hơn đang đổi hướng, hoặc
  khi `ENABLE_C = 0` và đích có bit 1 = 1 (để EX gây ngoại lệ misaligned).

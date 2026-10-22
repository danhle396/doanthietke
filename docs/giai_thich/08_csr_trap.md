# CSR, ngoại lệ và ngắt (`rtl/core/csr_file.sv`, phần trap của `mem_stage.sv`)

## CSR được hiện thực

| Nhóm | CSR |
|---|---|
| Trạng thái | `mstatus` (MIE, MPIE; MPP cố định 11), `mstatush` (0), `misa` (read-only) |
| Ngắt | `mie` (MEIE/MTIE/MSIE), `mip` (phản ánh tín hiệu), `mtvec` (direct/vectored) |
| Trap | `mepc` (bit 0 = 0, bit 1 = 0 khi không có C), `mcause`, `mtval`, `mscratch` |
| ID | `mvendorid`, `marchid`, `mimpid`, `mhartid`, `mconfigptr` = 0 |
| Counter | `mcycle(h)`, `minstret(h)`, `mhpmcounter3..10(h)`, `mcountinhibit` (CY, IR), `mhpmevent3..10` = 0 |
| Zicntr | `cycle(h)`, `time(h)` (từ `mtime` của TIMER64), `instret(h)` – read-only |

CSR không tồn tại, hoặc **ghi** vào CSR read-only (`addr[11:10] = 11`) → illegal instruction. "Ghi" nghĩa là CSRRW,
hoặc CSRRS/CSRRC với `rs1 ≠ x0`, CSRRSI/CSRRCI với `uimm ≠ 0` (nên `csrr a0, cycle` hợp lệ).

## mcause / mtval

| mcause | Nguyên nhân | mtval |
|---|---|---|
| 0 | nhảy tới địa chỉ không căn 4 (không có C) | đích |
| 1 | lấy lệnh ngoài RAM | PC |
| 2 | lệnh không hợp lệ | mã lệnh (16 bit với lệnh nén) |
| 3 | EBREAK / C.EBREAK | PC |
| 4 / 6 | load / store không căn lề | địa chỉ |
| 5 / 7 | load / store access fault (vùng không có thiết bị, slot APB trống) | địa chỉ |
| 11 | ECALL từ M-mode | 0 |
| 0x8000_0003 / 7 / B | ngắt phần mềm / timer / ngoài | 0 |

Ưu tiên trên cùng một lệnh: access fault lấy lệnh > illegal > ecall/ebreak > misaligned lệnh > misaligned
load/store > access fault load/store. Ưu tiên ngắt: MEI > MSI > MTI.

## Vào và ra trap

```
vào:  mepc ← PC lệnh ở MEM;  mcause; mtval;  MPIE ← MIE;  MIE ← 0;
      PC ← mtvec.BASE            (direct, hoặc mọi ngoại lệ)
      PC ← mtvec.BASE + 4×cause  (vectored, chỉ ngắt)
mret: MIE ← MPIE;  MPIE ← 1;  PC ← mepc
```

Test `irq_priority` chạy cả hai chế độ và kiểm tra slot vector thực sự dùng (stub ghi số slot vào `mscratch`).

## Độ trễ ngắt

Ngắt được nhận khi có lệnh hợp lệ ở MEM. Độ trễ ≈ thời gian để một lệnh tới MEM + vài chu kỳ; xấu nhất khi MEM đang
chờ một giao dịch APB đã bắt đầu (không hủy được) hoặc khi bộ chia đang chạy (~34 chu kỳ, decision D21).
`timer_irq` đo được độ trễ thực tế (in trong log).

## Counter và `minstret`

`minstret` tăng ở WB. Khi một lệnh CSR ở MEM đọc `minstret` cùng chu kỳ lệnh trước nó retire ở WB, giá trị đọc được
cộng thêm 1 (bypass); lệnh ghi `minstret` thì giá trị ghi "thắng" việc tăng (decision D6) – test
`rv32mi-p-instret_overflow` kiểm tra đúng điều này.

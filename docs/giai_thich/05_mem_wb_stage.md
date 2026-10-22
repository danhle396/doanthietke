# MEM và WB (`rtl/core/mem_stage.sv`, `lsu.sv`, `wb_stage.sv`)

## MEM là điểm commit

Khi một lệnh ở MEM: mọi lệnh **già hơn** đã ghi xong (ở WB hoặc đã rời pipeline), mọi lệnh **trẻ hơn** (EX, ID,
IF) chưa thay đổi trạng thái kiến trúc nào (chưa ghi regfile, chưa store, chưa ghi CSR). Vì vậy nếu lệnh này trap,
chỉ cần flush các tầng trẻ hơn là trạng thái máy đúng như "mọi lệnh trước `mepc` đã xong, lệnh tại `mepc` và sau đó
chưa chạy" – đó là **ngoại lệ chính xác**.

## LSU

- Byte enable: SB `0001 << addr[1:0]`, SH `0011`/`1100`, SW `1111`; dữ liệu store nhân bản lên đúng lane.
- Kiểm tra căn lề: half lẻ hoặc word không chia hết 4 → trap misaligned (mcause 4/6), **không phát request**.
- Load: dịch `rdata >> 8*addr[1:0]`, mở rộng dấu/không dấu ngay trong MEM → `mem_wb` có giá trị cuối.
- Request giữ nguyên đến khi `dbus_ready`; RAM ready ngay, APB tối thiểu 3 chu kỳ. `dbus_err` khi ready → access
  fault (mcause 5/7, `mtval` = địa chỉ).

## CSR ở MEM

CSR read-modify-write đọc giá trị cũ, tính giá trị mới (RW/RS/RC) và ghi **chỉ khi lệnh không trap**. Đặt ở MEM vì:
(1) ghi CSR là side effect không thể hoàn tác, phải xảy ra ở điểm commit; (2) đọc `mepc/mcause/mstatus` cần thấy
mọi trap/MRET của lệnh trước đã có hiệu lực. Hệ quả: lệnh dùng kết quả CSR ngay sau đó phải stall 1 chu kỳ (CSR-use),
giống load-use.

## Trap và ngắt

```
take_irq = MIE && |(mip & mie) && mem_valid && !mem_exc && !mem_bus_started
trap     = take_irq || ngoại_lệ(lệnh ở MEM)
```

- Ưu tiên ngoại lệ trên một lệnh: mang theo từ IF/ID/EX > CSR illegal > misaligned > access fault.
- `dbus_req` bị chặn bởi `take_irq` trong cùng chu kỳ → không bắt đầu giao dịch cho lệnh sắp bị hủy;
  `mem_bus_started` ngăn hủy một giao dịch APB đã bắt đầu (không thể "rút lại" một lần ghi UART).
- Vào trap: `mepc ← pc`, `mcause`, `mtval`, `MPIE ← MIE`, `MIE ← 0`, PC ← `mtvec` (vectored: `BASE + 4×cause`
  cho ngắt). Flush `if_id`, `id_ex`, `ex_mem`; lệnh trap không vào WB.
- MRET và FENCE.I cũng xử lý ở MEM: flush các tầng trẻ hơn, nạp `mepc` hoặc `pc+len`; hai lệnh này vẫn retire.

## WB

- Ghi regfile, tăng `minstret` (trừ khi chính lệnh ghi `minstret` – decision D6).
- Sinh sự kiện cho `mhpmcounter3..6, 10` (branch, branch sai, jump, jump sai, lệnh nén).
- In commit log (chỉ mô phỏng) theo định dạng của `spike --log-commits` để so sánh từng lệnh.

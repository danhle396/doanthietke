# Đặc tả thiết kế

**Đề tài:** Thiết kế SoC dựa trên lõi RISC-V RV32IMC pipeline 5 tầng có dự đoán rẽ nhánh, tích hợp ngoại vi truyền thông UART và SPI

Tài liệu này tóm tắt đặc tả kỹ thuật được hiện thực; đặc tả gốc đầy đủ nằm ở `PROJECT_SPEC.md`.
Các quyết định bổ sung khi đặc tả thiếu chi tiết ghi ở `docs/decisions.md`.

## 1. Mục tiêu

- Lõi `rv_core`: RV32I + M + C + Zicsr + Zifencei + Zicntr, chỉ Machine mode, pipeline 5 tầng
  IF → ID → EX → MEM → WB, forwarding, phát hiện hazard, dự đoán rẽ nhánh cấu hình được
  (`BP_MODE` 0 = tĩnh not-taken, 1 = BHT tra ở ID, 2 = BHT + BTB tra ở IF).
- Lõi tham chiếu `rv_core_sc`: RV32I single-cycle, cùng danh sách port, dùng để so sánh hiệu năng.
- SoC `soc_top`: RAM hợp nhất 128 KB 2 cổng (đọc tổ hợp, ghi đồng bộ; chế độ `RAM_SYNC` cho FPGA), bus
  **Wishbone B4 classic** giữa lõi, RAM và interconnect `dbus_xbar`, cầu Wishbone → **APB4** (`apb_bridge`),
  ngoại vi truyền thông **UART** và **SPI Master** (có FIFO và ngắt), ngoại vi hỗ trợ TIMER64, GPIO 16 chân, INTC,
  SIM_CTRL (mô phỏng).
- RTL tổng hợp được: một clock `clk`, reset bất đồng bộ tích cực mức thấp `rst_n`
  (đồng bộ hóa khi nhả ở `soc_top`), không latch, lint Verilator `-Wall` sạch.

## 2. Tham số lõi

| Parameter | Mặc định | Ý nghĩa |
|---|---|---|
| `RESET_PC` | `32'h8000_0000` | |
| `ENABLE_M` | 1 | 0 → lệnh M là illegal |
| `ENABLE_C` | 1 | 0 → lệnh 16 bit illegal; nhảy taken tới địa chỉ có `bit[1]=1` → instruction-address-misaligned |
| `BP_MODE` | 2 | 0 / 1 / 2 như trên |
| `BHT_ENTRIES` | 256 | lũy thừa của 2, ≥ 16 |
| `BTB_ENTRIES` | 32 | lũy thừa của 2, ≥ 4, direct-mapped |

`misa = 0x4000_1104` ở cấu hình đầy đủ (MXL=1, I, M, C).

## 3. Giao tiếp lõi

Hai bus của lõi là master **Wishbone B4 classic** (D28):

```
input  clk, rst_n
// bus lệnh – Wishbone master, chỉ đọc
output        ibus_cyc_o, ibus_stb_o  // = 1 sau reset: mỗi chu kỳ một lần lấy lệnh
output [31:0] ibus_adr_o              // PC, căn 2 byte
input  [31:0] ibus_dat_i              // 32 bit bắt đầu tại ibus_adr_o
input         ibus_ack_i, ibus_err_i  // ERR → instruction access fault
// bus dữ liệu – Wishbone master
output        dbus_cyc_o, dbus_stb_o, dbus_we_o
output [3:0]  dbus_sel_o              // byte enable
output [31:0] dbus_adr_o, dbus_dat_o  // dat_o đã nằm đúng byte lane
input  [31:0] dbus_dat_i              // word aligned
input         dbus_ack_i, dbus_err_i  // ERR → load/store access fault
input         irq_mtip, irq_msip, irq_meip
input  [63:0] mtime
```

Lõi giữ nguyên CYC/STB, ADR, WE, SEL, DAT tới khi có ACK hoặc ERR (không hủy giữa chừng). Load/store không căn lề
→ trap (mcause 4/6), không phát giao dịch. Khác chuẩn duy nhất: ADR của bus lệnh có thể căn 2 byte và slave trả
32 bit bắt đầu tại đó (lệnh 32 bit vắt qua ranh giới word lấy trong một giao dịch).

## 4. Pipeline (tóm tắt)

| Tầng | Công việc |
|---|---|
| IF | `pc_q → ibus_adr_o`, chỉ nhận lệnh khi có ACK/ERR, phát hiện lệnh 16 bit, tra BTB+BHT (mode 2), chọn PC kế: MEM > EX > ID > dự đoán IF > tuần tự |
| ID | giải nén RV32C, decode, imm, đọc regfile (write-through), ngoại lệ ID, redirect JAL (mode ≥ 1) và branch theo BHT (mode 1), load-use/CSR-use |
| EX | forwarding, ALU, so sánh nhánh, `actual_npc`, phát hiện sai dự đoán `actual_npc != pred_npc`, cập nhật predictor, MulDiv |
| MEM | LSU, CSR read-modify-write, **điểm commit**: trap (ngoại lệ hoặc ngắt), MRET, FENCE.I |
| WB | ghi regfile, `minstret`, performance counter, commit log |

Chi tiết vi kiến trúc: `docs/microarch.md`. Bản đồ bộ nhớ: `docs/memory_map.md`. Thanh ghi: `docs/register_map.md`.

## 5. Ngoại lệ và ngắt

- mcause: 0 instr-misaligned, 1 instr-access-fault, 2 illegal, 3 breakpoint, 4 load-misaligned,
  5 load-access-fault, 6 store-misaligned, 7 store-access-fault, 11 ecall-M;
  ngắt `0x8000_0003` MSI, `0x8000_0007` MTI, `0x8000_000B` MEI (ưu tiên MEI > MSI > MTI).
- Ưu tiên ngoại lệ trên một lệnh: instruction access fault > illegal > ecall/ebreak >
  instruction-misaligned > load/store misaligned > load/store access fault.
- `take_irq = mstatus.MIE && |(mip & mie) && mem_valid && !mem_exc && !mem_bus_started`.

## 6. Xác minh

3 mức: unit testbench (`tb/unit`), riscv-tests (ma trận cấu hình) + so sánh Spike, system test C
(`sw/tests`) với BFM UART/SPI flash/SPI slave; bộ kiểm tra giao thức Wishbone (`tb/bfm/wb_checker.sv`) trên mọi
liên kết bus. Coverage dòng/toggle và functional coverage.
Kế hoạch chi tiết: `docs/verification_plan.md`.

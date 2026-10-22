# Đặc tả thiết kế

**Đề tài:** Thiết kế SoC dựa trên lõi RISC-V RV32IMC pipeline 5 tầng có dự đoán rẽ nhánh, tích hợp ngoại vi truyền thông UART và SPI

Tài liệu này tóm tắt đặc tả kỹ thuật được hiện thực; đặc tả gốc đầy đủ nằm ở `PROJECT_SPEC.md`.
Các quyết định bổ sung khi đặc tả thiếu chi tiết ghi ở `docs/decisions.md`.

## 1. Mục tiêu

- Lõi `rv_core`: RV32I + M + C + Zicsr + Zifencei + Zicntr, chỉ Machine mode, pipeline 5 tầng
  IF → ID → EX → MEM → WB, forwarding, phát hiện hazard, dự đoán rẽ nhánh cấu hình được
  (`BP_MODE` 0 = tĩnh not-taken, 1 = BHT tra ở ID, 2 = BHT + BTB tra ở IF).
- Lõi tham chiếu `rv_core_sc`: RV32I single-cycle, cùng danh sách port, dùng để so sánh hiệu năng.
- SoC `soc_top`: RAM hợp nhất 128 KB 2 cổng (đọc tổ hợp, ghi đồng bộ), `dbus_xbar`,
  `apb_bridge` (APB4), ngoại vi truyền thông **UART** và **SPI Master** (có FIFO và ngắt),
  ngoại vi hỗ trợ TIMER64, GPIO 16 chân, INTC, SIM_CTRL (mô phỏng).
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

```
input  clk, rst_n
output [31:0] ibus_addr        // halfword aligned
input  [31:0] ibus_rdata       // 32 bit bắt đầu tại ibus_addr
input         ibus_err
output        dbus_req, dbus_we
output [3:0]  dbus_be
output [31:0] dbus_addr, dbus_wdata   // wdata đã nằm đúng byte lane
input         dbus_ready, dbus_err
input  [31:0] dbus_rdata              // word aligned
input         irq_mtip, irq_msip, irq_meip
input  [63:0] mtime
```

Lõi giữ nguyên request tới khi `dbus_ready = 1`. Load/store không căn lề → trap (mcause 4/6), không phát request.

## 4. Pipeline (tóm tắt)

| Tầng | Công việc |
|---|---|
| IF | `pc_q → ibus_addr`, phát hiện lệnh 16 bit, tra BTB+BHT (mode 2), chọn PC kế: MEM > EX > ID > dự đoán IF > tuần tự |
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
(`sw/tests`) với BFM UART/SPI flash/SPI slave. Coverage dòng/toggle và functional coverage.
Kế hoạch chi tiết: `docs/verification_plan.md`.

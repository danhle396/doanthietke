# Bản đồ bộ nhớ

| Vùng | Base | Kích thước | Đích | Ghi chú |
|---|---|---|---|---|
| RAM | `0x8000_0000` | 128 KB (`0x8000_0000`–`0x8001_FFFF`) | `ram_dp` | lệnh + dữ liệu; reset PC = `0x8000_0000` |
| UART | `0x1000_0000` | 4 KB | APB slot 0 | |
| SPI | `0x1000_1000` | 4 KB | APB slot 1 | |
| TIMER64 | `0x1000_2000` | 4 KB | APB slot 2 | nguồn `mtip`, `msip`, `mtime` |
| GPIO | `0x1000_3000` | 4 KB | APB slot 3 | 16 chân |
| INTC | `0x1000_4000` | 4 KB | APB slot 4 | gom ngắt ngoại vi → `meip` |
| (slot 5–14) | `0x1000_5000`–`0x1000_EFFF` | | `apb_bridge` | không có slave → `PSLVERR = 1` (access fault) |
| SIM_CTRL | `0x1000_F000` | 4 KB | APB slot 15 | chỉ mô phỏng |
| Còn lại | – | – | `dbus_xbar` | access fault |

## Giải mã

- **Cổng lệnh** (`ibus`): chỉ RAM. Địa chỉ ngoài RAM → `ibus_err` → instruction access fault (mcause 1, `mtval` = PC).
- **Cổng dữ liệu** (`dbus_xbar`):
  - `0x8000_0000 ≤ addr < 0x8002_0000` → RAM, `ready = 1` ngay trong chu kỳ yêu cầu;
  - `0x1000_0000 ≤ addr < 0x1001_0000` → `apb_bridge`, slot = `addr[15:12]`;
  - còn lại → `ready = 1, err = 1` ngay trong chu kỳ đó → load access fault (mcause 5) / store access fault (mcause 7), `mtval` = địa chỉ.
- Truy cập APB tốn tối thiểu 3 chu kỳ (IDLE nhận yêu cầu → SETUP → ACCESS có `PREADY`).

## Bố trí phần mềm (`sw/common/link.ld`)

| Section | Vị trí |
|---|---|
| `.text` | bắt đầu tại `0x8000_0000` với `_start` (crt0), sau đó `trap_entry` |
| `.rodata`, `.tohost` (căn 64 B, chứa `tohost` và `fromhost`), `.data`, `.bss` | nối tiếp |
| stack 8 KB | đỉnh RAM: `_stack_top = 0x8002_0000` |

riscv-tests dùng `sw/riscv-tests-env/p/link.ld` (`.text.init` tại `0x8000_0000`, `.tohost` căn 64 B).
RAM đặt ở `0x8000_0000` để khớp mặc định của Spike và riscv-tests.

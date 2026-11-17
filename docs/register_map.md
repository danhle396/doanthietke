# Register map

Offset tính theo byte, thanh ghi 32 bit. "W1C" = ghi 1 để xóa. Bit không định nghĩa đọc ra 0, ghi bị bỏ qua.
Offset không định nghĩa → `PSLVERR = 1` (access fault ở lõi). Mọi slave trả `PREADY = 1` (không wait state).
Thanh ghi RW ghi theo `PSTRB`; thanh ghi "push" (DATA) đẩy dữ liệu khi `PSTRB[0] = 1`;
đọc có side effect (pop FIFO) xảy ra đúng 1 lần, tại chu kỳ ACCESS.

## UART – `0x1000_0000` (APB slot 0)

8 bit dữ liệu, LSB trước, parity tùy chọn, 1 hoặc 2 stop bit. RX: đồng bộ 2 FF, lấy mẫu ×16,
kiểm tra lại start bit ở giữa bit, lấy mẫu dữ liệu ở giữa bit. FIFO TX/RX sâu 16.

| Off  | Tên        | Truy cập | Mô tả                                                                                                                                                                           |
| ---- | ---------- | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 0x00 | DATA       | W / R    | W: đẩy `[7:0]` vào TX FIFO. R: `[7:0]` dữ liệu RX, `[31]` = RX_EMPTY; pop nếu không rỗng                                                                                        |
| 0x04 | STATUS     | RO       | [0] TX_FULL, [1] TX_EMPTY, [2] TX_IDLE (FIFO rỗng và shifter rảnh), [3] RX_EMPTY, [4] RX_FULL, [5] RX_OVERRUN, [6] FRAME_ERR, [7] PARITY_ERR, [12:8] TX_LEVEL, [20:16] RX_LEVEL |
| 0x08 | CTRL       | RW       | [0] TX_EN, [1] RX_EN, [2] PARITY_EN, [3] PARITY_ODD, [4] STOP2. Reset `0x3`                                                                                                     |
| 0x0C | BAUD_DIV   | RW       | [15:0]: 1 bit = 16×(DIV+1) chu kỳ clock. Reset 26 (≈ 115200 baud @ 50 MHz)                                                                                                      |
| 0x10 | IRQ_EN     | RW       | [0] TX_WM, [1] RX_WM, [2] ERR                                                                                                                                                   |
| 0x14 | IRQ_STATUS | R / W1C  | [0] TX_WM = (TX_LEVEL ≤ TX_WM_LVL), mức, RO; [1] RX_WM = (RX_LEVEL ≥ RX_WM_LVL), mức, RO; [2] ERR sticky, W1C (xóa luôn STATUS[7:5])                                            |
| 0x18 | WATERMARK  | RW       | [4:0] TX_WM_LVL (reset 0), [20:16] RX_WM_LVL (reset 1)                                                                                                                          |

`irq = |(IRQ_STATUS[2:0] & IRQ_EN[2:0])`. ERR được set khi có overrun, frame error hoặc parity error.

## SPI Master – `0x1000_1000` (APB slot 1)

Full-duplex, 8 bit/khung, 4 mode, MSB-first hoặc LSB-first, CS điều khiển bằng phần mềm. FIFO TX/RX sâu 16.

| Off  | Tên        | Truy cập | Mô tả                                                                                                                                                        |
| ---- | ---------- | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 0x00 | DATA       | W / R    | W: đẩy vào TX FIFO. R: `[7:0]` dữ liệu RX, `[31]` RX_EMPTY; pop                                                                                              |
| 0x04 | STATUS     | RO       | [0] TX_FULL, [1] TX_EMPTY, [2] RX_EMPTY, [3] RX_FULL, [4] BUSY, [5] RX_OVERRUN, [12:8] TX_LEVEL, [20:16] RX_LEVEL                                            |
| 0x08 | CTRL       | RW       | [0] EN, [1] CPOL, [2] CPHA, [3] LSB_FIRST. Reset 0                                                                                                           |
| 0x0C | CLK_DIV    | RW       | [15:0]: f_SCLK = f_clk / (2×(DIV+1)). Reset 3                                                                                                                |
| 0x10 | CS         | RW       | [3:0] CS_N, tích cực mức thấp. Reset `0xF`                                                                                                                   |
| 0x14 | IRQ_EN     | RW       | [0] TX_EMPTY, [1] RX_NOT_EMPTY, [2] DONE, [3] OVERRUN                                                                                                        |
| 0x18 | IRQ_STATUS | R / W1C  | [0] TX_EMPTY, [1] RX_NOT_EMPTY: mức (RO); [2] DONE sticky (set khi byte cuối truyền xong và TX FIFO rỗng), W1C; [3] OVERRUN sticky, W1C (xóa luôn STATUS[5]) |

`irq = |(IRQ_STATUS[3:0] & IRQ_EN[3:0])`.

## TIMER64 – `0x1000_2000` (APB slot 2)

Không có mã IP ĐACS4 trong `ip/timer64_dacs4/` nên tự hiện thực theo bảng (xem `docs/decisions.md`).

| Off  | Tên         | Truy cập | Mô tả                                                                               |
| ---- | ----------- | -------- | ----------------------------------------------------------------------------------- |
| 0x00 | MTIME_LO    | RW       |                                                                                     |
| 0x04 | MTIME_HI    | RW       |                                                                                     |
| 0x08 | MTIMECMP_LO | RW       | reset `0xFFFF_FFFF`                                                                 |
| 0x0C | MTIMECMP_HI | RW       | reset `0xFFFF_FFFF`                                                                 |
| 0x10 | CTRL        | RW       | [0] EN (reset 1), [15:8] PRESCALE (reset 0): mtime tăng 1 sau mỗi PRESCALE+1 chu kỳ |
| 0x14 | MSIP        | RW       | [0] → `msip`                                                                        |

`mtip = (mtime >= mtimecmp)`, theo mức. Driver đọc 64 bit bằng vòng hi–lo–hi; ghi mtimecmp theo
trình tự của Privileged spec (ghi LO = 0xFFFF_FFFF, ghi HI, ghi LO) để tránh ngắt giả.

## GPIO – `0x1000_3000` (APB slot 3), 16 chân

| Off  | Tên        | Truy cập | Mô tả                           |
| ---- | ---------- | -------- | ------------------------------- |
| 0x00 | OUT        | RW       | giá trị xuất                    |
| 0x04 | IN         | RO       | đã đồng bộ 2 flip-flop          |
| 0x08 | DIR        | RW       | 1 = output, reset 0 (`gpio_oe`) |
| 0x0C | IRQ_EN     | RW       | theo từng chân                  |
| 0x10 | IRQ_STATUS | R / W1C  | cờ cạnh sticky                  |
| 0x14 | IRQ_TYPE   | RW       | 0 = cạnh lên, 1 = cạnh xuống    |

`irq = |(IRQ_STATUS & IRQ_EN)`.

## INTC – `0x1000_4000` (APB slot 4)

| Off  | Tên     | Truy cập | Mô tả                                           |
| ---- | ------- | -------- | ----------------------------------------------- |
| 0x00 | PENDING | RO       | mức ngắt thô: bit 0 UART, bit 1 SPI, bit 2 GPIO |
| 0x04 | ENABLE  | RW       | reset 0                                         |
| 0x08 | ACTIVE  | RO       | PENDING & ENABLE                                |

`irq_meip = |(PENDING & ENABLE)`.

## SIM_CTRL – `0x1000_F000` (APB slot 15, chỉ mô phỏng)

| Off  | Tên     | Mô tả                                                                                              |
| ---- | ------- | -------------------------------------------------------------------------------------------------- |
| 0x00 | PUTCHAR | W: in `[7:0]` ra stdout và file `+console=<file>`                                                  |
| 0x04 | EXIT    | W: kết thúc mô phỏng; 0 → in `PASS` rồi `$finish`; khác 0 → in `FAIL: exit code N` rồi `$fatal(1)` |

## CSR của lõi (Machine mode)

| CSR                                                       | Địa chỉ                  | Ghi chú                                                        |
| --------------------------------------------------------- | ------------------------ | -------------------------------------------------------------- |
| `mstatus`                                                 | 0x300                    | MIE (3), MPIE (7); MPP (12:11) cố định `11`                    |
| `misa`                                                    | 0x301                    | `0x4000_1104` (cấu hình đầy đủ), ghi bị bỏ qua                 |
| `mie`                                                     | 0x304                    | MEIE (11), MTIE (7), MSIE (3)                                  |
| `mtvec`                                                   | 0x305                    | MODE 0 direct, 1 vectored (ngắt → `BASE + 4×cause`)            |
| `mstatush`                                                | 0x310                    | đọc 0                                                          |
| `mcountinhibit`                                           | 0x320                    | CY (0), IR (2)                                                 |
| `mhpmevent3..10`                                          | 0x323–0x32A              | đọc 0 (sự kiện cố định)                                        |
| `mscratch`, `mepc`, `mcause`, `mtval`                     | 0x340–0x343              | `mepc[0] = 0` (và `[1] = 0` khi không có C)                    |
| `mip`                                                     | 0x344                    | MEIP (11), MTIP (7), MSIP (3) phản ánh tín hiệu; ghi bị bỏ qua |
| `mcycle(h)`, `minstret(h)`                                | 0xB00/0xB80, 0xB02/0xB82 | 64 bit, ghi được                                               |
| `mhpmcounter3..10(h)`                                     | 0xB03–0xB0A, 0xB83–0xB8A | xem bảng dưới; ghi bị bỏ qua                                   |
| `cycle(h)`, `time(h)`, `instret(h)`                       | 0xC00–0xC02, 0xC80–0xC82 | read-only (Zicntr)                                             |
| `mvendorid`, `marchid`, `mimpid`, `mhartid`, `mconfigptr` | 0xF11–0xF15              | read-only, bằng 0                                              |

| Counter         | Sự kiện                                       |
| --------------- | --------------------------------------------- |
| `mhpmcounter3`  | branch có điều kiện retire                    |
| `mhpmcounter4`  | branch có điều kiện bị dự đoán sai (sửa ở EX) |
| `mhpmcounter5`  | JAL/JALR retire                               |
| `mhpmcounter6`  | JAL/JALR bị dự đoán sai (sửa ở EX)            |
| `mhpmcounter7`  | chu kỳ stall load-use/CSR-use                 |
| `mhpmcounter8`  | chu kỳ stall MulDiv                           |
| `mhpmcounter9`  | chu kỳ chờ bus                                |
| `mhpmcounter10` | lệnh nén retire                               |

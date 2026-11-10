# Chạy SoC RISC-V trên board DE2 (Cyclone II EP2C35F672C6) bằng Quartus II

Thư mục này **tự chứa đủ** để compile và nạp lên board: chỉ cần chép riêng thư mục `fpga/` sang máy Windows
có Quartus II. Không cần Linux, không cần trình biên dịch RISC-V (firmware đã được build sẵn thành file `.mif`).

| Thành phần | Giá trị |
|---|---|
| Lõi | `rv_core` RV32IMC, pipeline 5 tầng, BHT + BTB (BP_MODE 2) |
| Clock CPU | 24 MHz (PLL từ CLOCK_50: × 12 / 25) |
| RAM | 32 KB trên khối M4K (2 bank 16 bit, chạy cạnh xuống của clock) |
| UART | 115200 baud, 8N1, qua cổng RS-232 (DB9) của board |
| Ngoại vi | UART, SPI master, TIMER64, GPIO 16 bit, INTC |

## 1. Đã kiểm chứng gì trước khi giao (trên Linux)

- 16 firmware trong `firmware/` đều **PASS khi mô phỏng RTL** với đúng cấu hình của board (RAM đồng bộ 32 KB,
  UART 115200 @ 24 MHz). Đầu ra UART mô phỏng nằm ở `firmware/<tên>/uart_sim.txt`.
- RAM đồng bộ cạnh xuống cho **số chu kỳ trùng khớp tuyệt đối** với RAM đọc tổ hợp dùng trong toàn bộ báo cáo
  (9 benchmark, mọi performance counter giống hệt); riscv-tests 64/64 PASS và khớp Spike 64/64.
- Module `board/de2_top.sv` được mô phỏng với mô hình thay thế của `altsyncram`/`altpll`, nạp RAM từ chính các
  file `mem/*.mif`: reset bằng KEY[0], công tắc → LED, UART, lệnh `b` đều đúng (PASS).
- Danh sách file trong `de2_soc.qsf` elaborate sạch bằng Yosys (top `de2_top`).

**Chưa được kiểm chứng:** compile bằng chính Quartus II và chạy trên board thật – đó là phần bạn thực hiện theo
hướng dẫn dưới đây. Nếu Quartus báo lỗi, gửi lại nguyên văn thông báo lỗi (mục 9).

## 2. Chuẩn bị

1. **Quartus II 13.0sp1 Web Edition** (bản cuối cùng hỗ trợ Cyclone II) và gói thiết bị **Cyclone II**.
   Các bản Quartus Prime 14 trở lên **không** mở được Cyclone II.
2. **Driver USB-Blaster** trên Windows 11: Device Manager → *USB-Blaster* → Update driver → Browse →
   `C:\altera\13.0sp1\quartus\drivers\usb-blaster`.
3. **Cáp USB–RS232** nối PC với cổng DB9 (RS-232) của DE2, và phần mềm terminal (PuTTY / Tera Term).
4. (Tùy chọn) **Module flash SPI W25Qxx 3.3 V** để chạy `spi_flash`, `demo` và lệnh `f` của `board_demo`.

## 3. Nối board

- Cáp USB vào cổng **USB Blaster** của DE2, cắm nguồn 9 V, bật nguồn.
- Công tắc **RUN/PROG** (cạnh màn hình LCD) để ở **RUN** (nạp qua JTAG).
- Cáp RS-232 vào cổng DB9 của board.
- Module flash (nếu có) cắm vào header **JP1 (GPIO_0)**:

| Tín hiệu | Cổng FPGA | Chân JP1 |
|---|---|---|
| SCLK | GPIO_0[0] | 1 |
| MOSI (DI) | GPIO_0[1] | 2 |
| MISO (DO) | GPIO_0[2] | 3 |
| CS# (flash) | GPIO_0[3] | 4 |
| CS1#..CS3# (dự phòng) | GPIO_0[4..6] | 5..7 |
| 3.3 V | VCC33 | 29 |
| GND | GND | 30 |

> Đối chiếu sơ đồ chân JP1 với hình "I/O distribution of the expansion headers" trong *DE2 User Manual* trước khi
> cắm. Chỉ dùng module 3.3 V.

## 4. Compile

1. Quartus II → **File → Open Project** → chọn `de2_soc.qpf`.
2. **Processing → Start Compilation** (khoảng vài phút).
3. Kết quả cần xem (và chụp lại cho báo cáo):
   - **Compilation Report → Flow Summary**: số Logic Elements, Registers, Memory bits (≈ 262 144 bit = 32 KB),
     Embedded Multiplier 9-bit elements, PLL = 1.
   - **TimeQuest Timing Analyzer → Slow Model → Fmax Summary** của clock PLL (`u_pll|altpll_component|...clk[0]`):
     Fmax phải lớn hơn 24 MHz và **Setup slack dương**. Lưu ý RAM chạy cạnh xuống nên đường địa chỉ RAM và dữ
     liệu RAM chỉ có nửa chu kỳ – Fmax báo cáo đã tính điều này.

## 5. Nạp bitstream

**Tools → Programmer** → *Hardware Setup* chọn **USB-Blaster** → Mode **JTAG** → *Add File*
`output_files/de2_soc.sof` → tick *Program/Configure* → **Start**.

Sau khi nạp: **LEDG0** (PLL locked) và **LEDG1** (hết reset) sáng, **LEDG8** nhấp nháy ~1,4 Hz (clock CPU chạy).
Nhấn **KEY0** để reset CPU (chương trình chạy lại từ đầu).

## 6. Terminal

PuTTY: *Connection type* **Serial**, cổng **COMx** (xem Device Manager), **115200**, 8 data bit, không parity,
1 stop bit, *Flow control* **None**. Mục *Terminal*: tick **Implicit CR in every LF**, *Local echo* = Force off.

Firmware mặc định là `board_demo`. Nhấn KEY0, terminal hiện:

```
=== RISC-V RV32IMC SoC on DE2 (Cyclone II EP2C35) ===
commands: h help | i info | s switches | b benchmark | f flash ID | q quit
>
```

| Lệnh | Kết quả trên board |
|---|---|
| `h` | danh sách lệnh |
| `i` | tần số CPU, `misa = 0x40001104`, thời gian chạy, mcycle / minstret / CPI |
| `s` | giá trị SW[15:0] |
| `b` | chạy workload 2 lần, in performance counter. **Lần 2: `cycles=391205 instret=323166`** – phải trùng với mô phỏng (`firmware/board_demo/uart_sim.txt`) |
| `f` | JEDEC ID của flash (W25Q32: `ef 40 16`), hoặc `(no flash on GPIO_0)` |
| `q` | thoát (nhấn KEY0 để chạy lại) |

Gạt **SW0..SW7**: LEDR0..LEDR7 đổi theo ngay (ngắt GPIO). **LEDR8..LEDR15** đếm giây (ngắt timer).

## 7. Đổi firmware (không cần compile lại toàn bộ)

1. Mở Command Prompt trong thư mục `fpga`, chạy ví dụ `chon_firmware.bat dhrystone`
   (chạy không tham số để xem danh sách).
2. Quartus: **Processing → Update Memory Initialization File**.
3. **Processing → Start → Start Assembler**.
4. Nạp lại `output_files/de2_soc.sof` (mục 5), nhấn KEY0.

Danh sách firmware, phần cứng cần thêm và kết quả mô phỏng: [`firmware/DANH_SACH.md`](firmware/DANH_SACH.md).
Test tự kiểm tra in `RESULT <tên>: PASS (...)`; benchmark in `[bench] name=... cycles=... instret=... cpi_x1000=...`.
So sánh với `firmware/<tên>/uart_sim.txt`: **số chu kỳ của benchmark phải trùng khớp** (cùng file nhị phân, cùng
cấu hình RTL).

## 8. Số liệu cho báo cáo (Giai đoạn 3 – 4)

| Số liệu | Lấy ở đâu |
|---|---|
| Diện tích (LE, register, memory bit, multiplier) | Compilation Report → Flow Summary |
| Fmax, slack, đường găng | TimeQuest → Fmax Summary, *Report Top Failing Paths* / *Report Timing* (worst path) |
| Công suất (mW) | **Processing → PowerPlay Power Analyzer Tool** → Start: *Total Thermal Power Dissipation*, *Core Dynamic*, *Core Static*, *I/O*. Không có file hoạt động (VCD) thì Quartus dùng tỉ lệ toggle mặc định – ghi rõ "ước lượng, độ tin cậy thấp" trong báo cáo |
| Throughput | Chu kỳ đo trên board ÷ 24 MHz = thời gian chạy; MIPS = 24 ÷ CPI |
| Kiểm chứng thực nghiệm | Ảnh board (LED), ảnh terminal: `board_demo` (lệnh `i`, `s`, `b`), các test `RESULT ... PASS`, benchmark |

## 9. Xử lý sự cố

| Hiện tượng | Cách xử lý |
|---|---|
| Lỗi ở `pll_cpu` / `altpll` | Tạo lại PLL bằng **Tools → MegaWizard Plug-In Manager → ALTPLL**, tên `pll_cpu`, Verilog, inclk0 = 50 MHz, c0 = 24 MHz, bật cổng `locked`; ghi đè `board/pll_cpu.v` |
| Không tìm thấy `mem/bank0.mif` | Mở project từ đúng thư mục `fpga` (đường dẫn trong project là tương đối) |
| Lỗi cú pháp SystemVerilog | Gửi nguyên văn thông báo (file, dòng) để sửa |
| Setup slack âm | Gửi báo cáo TimeQuest; có thể giảm clock CPU (cần build lại firmware với tần số mới) |
| Terminal ra ký tự rác | Kiểm tra 115200 8N1; thử cáp null-modem (đảo TX/RX) |
| Terminal không hiện gì, LEDG8 nhấp nháy | Kiểm tra cổng COM; nhấn KEY0 sau khi mở terminal |
| LEDG0 tắt | PLL chưa khóa: kiểm tra pin CLOCK_50 (`PIN_N2`) |

Gán chân trong `de2_soc.qsf` lấy theo *DE2 User Manual*; có thể đối chiếu với file `DE2_pin_assignments.csv`
trên đĩa DE2 System CD (cùng tên cổng: `CLOCK_50`, `KEY`, `SW`, `LEDR`, `LEDG`, `UART_TXD`, `UART_RXD`, `GPIO_0`).

## 10. Cấu trúc thư mục

```
fpga/
├── de2_soc.qpf, de2_soc.qsf    project Quartus (thiết bị, danh sách file, gán chân)
├── de2_soc.sdc                 ràng buộc timing (CLOCK_50, clock PLL suy ra tự động)
├── chon_firmware.bat           chọn firmware nạp vào RAM
├── board/de2_top.sv            top cho board: PLL, reset, công tắc, LED, UART, SPI trên GPIO_0
├── board/pll_cpu.v             PLL 50 → 24 MHz (altpll)
├── board/ram_bank16_m4k.sv     bank RAM 16 bit trên M4K (altsyncram, khởi tạo từ mem/*.mif)
├── rtl/                        bản sao RTL của SoC (không sửa tay ở đây)
├── mem/bank0.mif, bank1.mif    firmware đang được chọn (mặc định board_demo)
└── firmware/<tên>/             bank0.mif, bank1.mif, <tên>.elf, uart_sim.txt (+ rx_sim.txt)
```

Thư mục được sinh lại từ repo bằng `make fpga` (Linux): chép RTL, build firmware cho board, sinh `.mif`, mô phỏng
từng firmware trên cấu hình của board và mô phỏng `de2_top`. Thay đổi RTL hoặc firmware thì chạy lại lệnh này
rồi chép lại thư mục `fpga/`.

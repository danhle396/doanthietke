# Chạy SoC RISC-V trên board DE2 (Cyclone II EP2C35F672C6) bằng Quartus II

Thư mục này **tự chứa đủ** để compile và nạp lên board: chỉ cần chép riêng thư mục `fpga/` sang máy Windows
có Quartus II. Không cần Linux, không cần trình biên dịch RISC-V (firmware đã được build sẵn thành file `.mif`).

| Thành phần | Giá trị                                                        |
| ---------- | -------------------------------------------------------------- |
| Lõi        | `rv_core` RV32IMC, pipeline 5 tầng, BHT + BTB (BP_MODE 2)      |
| Clock CPU  | 24 MHz (PLL từ CLOCK_50: × 12 / 25)                            |
| RAM        | 32 KB trên khối M4K (2 bank 16 bit, chạy cạnh xuống của clock) |
| UART       | 115200 baud, 8N1, qua cổng RS-232 (DB9) của board              |
| Ngoại vi   | UART, SPI master, TIMER64, GPIO 16 bit, INTC                   |

## 1. Đã kiểm chứng gì trước khi giao (trên Linux)

- 16 firmware trong `firmware/` đều **PASS khi mô phỏng RTL** với đúng cấu hình của board (RAM đồng bộ 32 KB,
  UART 115200 @ 24 MHz). Đầu ra UART mô phỏng nằm ở `firmware/<tên>/uart_sim.txt`.
- RAM đồng bộ cạnh xuống cho **số chu kỳ trùng khớp tuyệt đối** với RAM đọc tổ hợp dùng trong toàn bộ báo cáo
  (9 benchmark, mọi performance counter giống hệt); riscv-tests 64/64 PASS và khớp Spike 64/64.
- Module `board/de2_top.sv` được mô phỏng với mô hình thay thế của `altsyncram`/`altpll`, nạp RAM từ chính các
  file `mem/*.mif`: reset bằng KEY[0], công tắc → LED, UART, lệnh `b` đều đúng (PASS).
- Danh sách file trong `de2_soc.qsf` elaborate sạch bằng Yosys (top `de2_top`).

**Compile bằng Quartus II 13.0sp1 (17/11/2026, firmware `board_demo`, có console JTAG và màn hình 7 đoạn):**
thành công, 0 Critical Warning.

| Số liệu (Flow Summary / TimeQuest)    | Giá trị                                                     |
| ------------------------------------- | ----------------------------------------------------------- |
| Total logic elements                  | 12 127 / 33 216 (37 %)                                      |
| Dedicated logic registers             | 6 302 (19 %)                                                |
| Memory bits                           | 328 192 / 483 840 (68 %): RAM 32 KB + FIFO console 8 KB     |
| Embedded Multiplier 9-bit             | 8 / 70 (bộ nhân 33 × 33)                                    |
| PLL                                   | 1 / 4                                                       |
| Fmax clock CPU (Slow Model)           | 35,48 MHz (yêu cầu 24 MHz)                                  |
| Setup slack / Hold slack (Slow Model) | +6,739 ns / +0,391 ns                                       |
| Đường găng                            | thanh ghi địa chỉ RAM M4K (cạnh xuống) → `if_stage` của lõi |

Bản compile đầu tiên (12/11, chưa có console và màn hình): 10 767 LE, 6 khối nhân, Fmax 36,02 MHz.

**Lỗi tìm ra khi chạy trên board (17/11/2026) và đã sửa:** `MULH`, `MULHSU`, `MULHU` trả về toàn `0`/`1`
(chỉ là bản sao bit dấu), trong khi mô phỏng RTL (Verilator) đúng. Nguyên nhân: `rtl/core/muldiv.sv` viết phép nhân
trong một phép ép độ rộng `66'(a * b)`; Quartus II 13.0 tính tích ở 33 bit rồi mới mở rộng dấu (chỉ dùng 6 khối
nhân). Đã viết lại theo kiểu Verilog-2001 (toán hạng `signed` 33 bit, đích `signed` 66 bit, độ rộng theo ngữ cảnh
phép gán), Quartus dùng 8 khối nhân. Thêm test `muldiv_rand` (8 lệnh RV32M + chia 64 bit, so với mô hình chỉ dùng
cộng/dịch): trên bitstream cũ FAIL ở `mulh`, `mulhsu`, `mulhu`; mô phỏng PASS. Biểu hiện ban đầu: lệnh `i` của
`board_demo` in `CPI x1000` sai khi `mcycle × 1000` vượt 2³².

## 2. Chuẩn bị

1. **Quartus II 13.0sp1 Web Edition** (bản cuối cùng hỗ trợ Cyclone II) và gói thiết bị **Cyclone II**.
   Các bản Quartus Prime 14 trở lên **không** mở được Cyclone II.
2. **Driver USB-Blaster** trên Windows 11: Device Manager → *USB-Blaster* → Update driver → Browse →
   `<thư mục cài Quartus>\quartus\drivers\usb-blaster` (ví dụ `C:\altera\13.0sp1\quartus\drivers\usb-blaster`).
3. **Cáp USB–RS232** nối PC với cổng DB9 (RS-232) của DE2, và phần mềm terminal (PuTTY / Tera Term).
4. (Tùy chọn) **Module flash SPI W25Qxx 3.3 V** để chạy `spi_flash`, `demo` và lệnh `f` của `board_demo`.

## 3. Nối board

- Cáp USB vào cổng **USB Blaster** của DE2, cắm nguồn 9 V, bật nguồn.
- Công tắc **RUN/PROG** (cạnh màn hình LCD) để ở **RUN** (nạp qua JTAG).
- Cáp RS-232 vào cổng DB9 của board.
- Module flash (nếu có) cắm vào header **JP1 (GPIO_0)**:

| Tín hiệu              | Cổng FPGA    | Chân JP1 |
| --------------------- | ------------ | -------- |
| SCLK                  | GPIO_0[0]    |        1 |
| MOSI (DI)             | GPIO_0[1]    |        2 |
| MISO (DO)             | GPIO_0[2]    |        3 |
| CS# (flash)           | GPIO_0[3]    |        4 |
| CS1#..CS3# (dự phòng) | GPIO_0[4..6] |     5..7 |
| 3.3 V                 | VCC33        |       29 |
| GND                   | GND          |       30 |

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

### 5.1. Ghi vào chip cấu hình EPCS16 (bật nguồn là chạy, không cần máy tính)

Nạp JTAG ở trên chỉ giữ thiết kế đến khi tắt nguồn. Để board tự nạp lúc bật nguồn, ghi file `.pof` vào EPCS16:

1. Gạt công tắc **RUN/PROG** sang **PROG**.
2. Programmer: Mode **Active Serial Programming**, *Add File* `output_files/de2_soc.pof` (thiết bị EPCS16), tick
   *Program/Configure* (và *Verify*) → **Start**. Hoặc dòng lệnh:
   `quartus_pgm -c USB-Blaster -m AS -o "pv;output_files/de2_soc.pof"`.
3. Gạt **RUN/PROG** về **RUN**, tắt rồi bật nguồn: board chạy `board_demo` ngay, không cần cáp USB.

Đổi firmware mặc định trong EPCS: chọn firmware (mục 7), chạy Assembler (sinh lại `.pof`), ghi lại như trên.

## 6. Terminal

PuTTY: *Connection type* **Serial**, cổng **COMx** (xem Device Manager), **115200**, 8 data bit, không parity,
1 stop bit, *Flow control* **None**. Mục *Terminal*: tick **Implicit CR in every LF**, *Local echo* = Force off.

Firmware mặc định là `board_demo`. Nhấn KEY0, terminal hiện:

```
=== RISC-V RV32IMC SoC on DE2 (Cyclone II EP2C35) ===
commands: h help | i info | s switches | b benchmark | t self-test | f flash ID | q quit
>
```

| Lệnh | Kết quả trên board                                                                                                                                                                      |
| ---- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `h`  | danh sách lệnh                                                                                                                                                                          |
| `i`  | tần số CPU, `misa = 0x40001104`, thời gian chạy, mcycle / minstret / CPI                                                                                                                |
| `s`  | giá trị SW[15:0]                                                                                                                                                                        |
| `b`  | chạy workload 2 lần, in performance counter. **Lần 2: `cycles=391209 instret=323167`**, `result = 0x1dfc7c31` – phải trùng với mô phỏng (`firmware/board_demo/uart_sim.txt`)            |
| `t`  | tự kiểm tra: 8 lệnh RV32M và chia 64 bit (giá trị chuẩn tính độc lập), RAM 4 KB hai mẫu bù nhau, `misa`, timer so với `mcycle` (2 ms); in `RESULT selftest: PASS (13 checks, 0 errors)` |
| `f`  | JEDEC ID của flash (W25Q32: `ef 40 16`), hoặc `(no flash on GPIO_0)`                                                                                                                    |
| `q`  | thoát (nhấn KEY0 để chạy lại)                                                                                                                                                           |

Gạt **SW0..SW7**: LEDR0..LEDR7 đổi theo ngay (ngắt GPIO). **LEDR8..LEDR15** đếm giây (ngắt timer).

### 6.1. Không có cáp RS-232: console qua chính cáp USB-Blaster

Trong FPGA có thêm khối `board/jtag_uart_bridge.sv` (dùng megafunction `sld_virtual_jtag`). Khối này **nghe chính
chân TX của UART trong SoC**, giải mã từng byte (115200 8N1) vào FIFO 8 KB và gửi về máy tính qua cáp JTAG.
Chiều ngược lại, nó phát byte từ máy tính vào chân RX của SoC (AND với chân RS-232, cả hai nghỉ ở mức 1). Một bit
điều khiển cho phép máy tính giữ CPU ở trạng thái reset, thay cho việc bấm KEY0. SoC và firmware **không đổi**:
CPU vẫn phát UART thật, chỉ có đường truyền về máy tính là cáp USB-Blaster thay vì cáp RS-232.

Chạy trên Windows (Python 3 + Quartus, không cần Linux), trong thư mục `fpga`:

| Lệnh                                       | Tác dụng                                                                                        |
| ------------------------------------------ | ----------------------------------------------------------------------------------------------- |
| `python tools/jtag_uart.py term`           | terminal tương tác (Ctrl+R reset CPU, Ctrl+Q thoát)                                             |
| `python tools/jtag_uart.py run -c i -c b`  | reset CPU, in đầu ra, gửi từng lệnh sau dấu nhắc `>`                                            |
| `python tools/jtag_uart.py load dhrystone` | chép MIF vào `mem/` → Update MIF → Assembler → nạp JTAG                                         |
| `python tools/jtag_uart.py test`           | chạy lần lượt mọi firmware, so đầu ra với `firmware/<tên>/uart_sim.txt`, ghi `board_results.md` |
| `python tools/jtag_uart.py test --flash`   | như trên, thêm `spi_flash` và `demo` (cần module flash trên JP1)                                |

Không mở cửa sổ Programmer / SignalTap của Quartus khi đang dùng console (cùng dùng cáp JTAG).

**Reset không nạp lại RAM.** KEY0 (hoặc Ctrl+R / bit reset của console) chỉ khởi động lại CPU; nội dung RAM chỉ
được nạp từ MIF khi cấu hình FPGA. Chương trình tự sửa mã hoặc dữ liệu của mình (`branch_smc` vá lệnh,
`qsort` sắp xếp mảng tại chỗ) sẽ cho kết quả khác ở lần chạy thứ hai. Vì vậy `test` và `run --no-reset` lấy đầu
ra của **lần chạy đầu tiên** sau khi nạp (FIFO 8 KB của cầu đã giữ sẵn), còn `board_demo` thì chạy lại thoải mái.

### 6.2. Trình diễn không cần máy tính: phím, màn hình 7 đoạn và LED

Khối `board/key_cmd.sv` biến nút nhấn thành lệnh console (gửi ký tự + Enter vào chân RX của SoC):

| Phím | Lệnh | Thấy trên board (SW17 SW16 = 0 0)                                                         |
| ---- | ---- | ----------------------------------------------------------------------------------------- |
| KEY0 | –    | reset CPU; HEX về `--------`, LEDR8..15 về 0                                              |
| KEY1 | `b`  | HEX hiện số chu kỳ lần chạy 2 của benchmark (`391209`, trùng mô phỏng); LEDG2 chớp (UART) |
| KEY2 | `t`  | HEX hiện `tESt PASS`, LEDG7 sáng (lỗi: `tESt FAIL`, LEDR17 sáng)                          |
| KEY3 | `f`  | LEDR16 chớp (SPI hoạt động), đọc JEDEC ID của flash                                       |

Khối `board/board_display.sv` chỉ **quan sát** SoC (các byte UART CPU phát ra, địa chỉ nạp lệnh, các đường ngắt,
chân chọn SPI), không tác động vào SoC. **SW17, SW16** chọn nội dung HEX7..HEX0:

| SW17 SW16 | HEX7..HEX0                                                                                                                             |
| --------- | -------------------------------------------------------------------------------------------------------------------------------------- |
|       0 0 | **Kết quả** firmware in ra gần nhất: `tESt PASS` / `tESt FAIL` (dòng `RESULT ...`), hoặc số chu kỳ sau `cycles=` (benchmark, lệnh `b`) |
|       0 1 | **PC**: địa chỉ lệnh CPU đang nạp (hex, 8 lần/giây) – thấy CPU chạy vòng lặp nào                                                       |
|       1 0 | **Số lần nạp lệnh trong 1 giây** (thập phân) – khoảng 2 × 10⁷ ở 24 MHz                                                                 |
|       1 1 | **Số ký tự UART** CPU đã gửi từ lúc reset                                                                                              |

| LED    | Ý nghĩa                                    | LED       | Ý nghĩa                               |
| ------ | ------------------------------------------ | --------- | ------------------------------------- |
| LEDG0  | PLL đã khóa                                | LEDG5     | ngắt timer (nháy mỗi lần ngắt)        |
| LEDG1  | CPU đang chạy (hết reset)                  | LEDG6     | ngắt ngoài qua INTC (GPIO, UART, SPI) |
| LEDG2  | UART đang phát                             | LEDG7     | test in `PASS`                        |
| LEDG3  | máy tính đang giữ CPU reset (console JTAG) | LEDG8     | nhịp tim ~1,4 Hz (clock CPU chạy)     |
| LEDG4  | console JTAG đang trao đổi                 | LEDR16    | SPI đang chọn thiết bị (CS tích cực)  |
| LEDR17 | test in `FAIL`                             | LEDR0..15 | GPIO của SoC (firmware điều khiển)    |

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

| Số liệu                                          | Lấy ở đâu                                                                                                                                                                                                                                                 |
| ------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Diện tích (LE, register, memory bit, multiplier) | Compilation Report → Flow Summary                                                                                                                                                                                                                         |
| Fmax, slack, đường găng                          | TimeQuest → Fmax Summary, *Report Top Failing Paths* / *Report Timing* (worst path)                                                                                                                                                                       |
| Công suất (mW)                                   | **Processing → PowerPlay Power Analyzer Tool** → Start: *Total Thermal Power Dissipation*, *Core Dynamic*, *Core Static*, *I/O*. Không có file hoạt động (VCD) thì Quartus dùng tỉ lệ toggle mặc định – ghi rõ "ước lượng, độ tin cậy thấp" trong báo cáo |
| Throughput                                       | Chu kỳ đo trên board ÷ 24 MHz = thời gian chạy; MIPS = 24 ÷ CPI                                                                                                                                                                                           |
| Kiểm chứng thực nghiệm                           | Ảnh board (LED), ảnh terminal: `board_demo` (lệnh `i`, `s`, `b`), các test `RESULT ... PASS`, benchmark                                                                                                                                                   |

## 9. Xử lý sự cố

| Hiện tượng                              | Cách xử lý                                                                                                                                                          |
| --------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Lỗi ở `pll_cpu` / `altpll`              | Tạo lại PLL bằng **Tools → MegaWizard Plug-In Manager → ALTPLL**, tên `pll_cpu`, Verilog, inclk0 = 50 MHz, c0 = 24 MHz, bật cổng `locked`; ghi đè `board/pll_cpu.v` |
| Không tìm thấy `mem/bank0.mif`          | Mở project từ đúng thư mục `fpga` (đường dẫn trong project là tương đối)                                                                                            |
| Lỗi cú pháp SystemVerilog               | Gửi nguyên văn thông báo (file, dòng) để sửa                                                                                                                        |
| Setup slack âm                          | Gửi báo cáo TimeQuest; có thể giảm clock CPU (cần build lại firmware với tần số mới)                                                                                |
| Terminal ra ký tự rác                   | Kiểm tra 115200 8N1; thử cáp null-modem (đảo TX/RX)                                                                                                                 |
| Terminal không hiện gì, LEDG8 nhấp nháy | Kiểm tra cổng COM; nhấn KEY0 sau khi mở terminal                                                                                                                    |
| LEDG0 tắt                               | PLL chưa khóa: kiểm tra pin CLOCK_50 (`PIN_N2`)                                                                                                                     |

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

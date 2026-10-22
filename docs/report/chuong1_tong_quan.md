# Chương 1. Tổng quan về kiến trúc RISC-V và hệ thống SoC

## 1.1. Kiến trúc tập lệnh RISC-V

RISC-V là kiến trúc tập lệnh (ISA) mở, theo triết lý RISC: lệnh có độ dài cố định, định dạng đều, chỉ lệnh load/store
truy cập bộ nhớ, 32 thanh ghi nguyên `x0`–`x31` với `x0` luôn bằng 0. ISA được tổ chức thành một tập cơ sở và các
extension tùy chọn; mỗi lõi công bố tổ hợp của mình qua thanh ghi `misa` và chuỗi tên (ví dụ `rv32imc`).

### 1.1.1. Tập lệnh cơ sở RV32I

RV32I có khoảng 40 lệnh chia thành 6 định dạng mã hóa (Bảng 1.1). Trường `rs1`, `rs2`, `rd` luôn ở cùng vị trí trong
mọi định dạng, giúp bộ giải mã đọc thanh ghi song song với việc giải mã opcode; bit dấu của hằng số luôn là bit 31.

Bảng 1.1. Các định dạng lệnh RV32I (nguồn: RISC-V Unprivileged ISA, chương 2).

| Định dạng | Dùng cho | Trường |
|---|---|---|
| R | phép toán thanh ghi–thanh ghi (`add`, `sub`, `sll`…) | funct7, rs2, rs1, funct3, rd, opcode |
| I | phép toán với hằng, load, `jalr`, CSR | imm[11:0], rs1, funct3, rd, opcode |
| S | store | imm[11:5], rs2, rs1, funct3, imm[4:0], opcode |
| B | nhánh có điều kiện | imm[12\|10:5], rs2, rs1, funct3, imm[4:1\|11], opcode |
| U | `lui`, `auipc` | imm[31:12], rd, opcode |
| J | `jal` | imm[20\|10:1\|11\|19:12], rd, opcode |

Nhóm lệnh: số học/logic (ADD, SUB, AND, OR, XOR, SLT/SLTU, dịch SLL/SRL/SRA và các bản có hằng), LUI/AUIPC tạo hằng
và địa chỉ PC tương đối, nhánh có điều kiện (BEQ, BNE, BLT, BGE, BLTU, BGEU), nhảy JAL/JALR, load/store theo byte,
nửa word, word, FENCE và các lệnh hệ thống (ECALL, EBREAK).

### 1.1.2. Extension M

Extension M bổ sung 8 lệnh: MUL (32 bit thấp của tích), MULH / MULHSU / MULHU (32 bit cao của tích có dấu × có dấu,
có dấu × không dấu, không dấu × không dấu), DIV / DIVU (thương) và REM / REMU (phần dư). Đặc tả quy định rõ các trường
hợp đặc biệt thay vì gây ngoại lệ: chia cho 0 trả về thương toàn bit 1 và phần dư bằng số bị chia; phép tràn
`-2³¹ / -1` trả về thương `-2³¹`, phần dư 0.

### 1.1.3. Extension C

Extension C định nghĩa các lệnh 16 bit là dạng rút gọn của những lệnh 32 bit thường gặp (ví dụ `c.addi`, `c.lw`,
`c.j`, `c.mv`), dùng 8 thanh ghi phổ biến `x8`–`x15` cho các trường 3 bit. Hai bit thấp của lệnh phân biệt độ dài:
`11` là lệnh 32 bit, còn lại là lệnh 16 bit. Lệnh 32 bit chỉ cần căn lề 2 byte, nên có thể nằm vắt qua ranh giới
word – một thách thức cho khối lấy lệnh. Theo các nghiên cứu của nhóm thiết kế RISC-V, extension C giảm kích thước mã
khoảng 25–30%; trong đồ án này đo được mức giảm trên các benchmark ở Chương 4.

### 1.1.4. CSR và chế độ Machine

Zicsr định nghĩa các lệnh đọc–sửa–ghi thanh ghi điều khiển trạng thái (CSRRW/CSRRS/CSRRC và bản có hằng). Đặc tả
Privileged mô tả các chế độ đặc quyền M/S/U; thiết kế chỉ hiện thực Machine mode – đủ cho hệ nhúng. Các CSR chính:

- `mstatus` (bit MIE bật ngắt toàn cục, MPIE lưu MIE khi vào trap), `mie`/`mip` (cho phép/đang chờ ngắt theo nguồn);
- `mtvec` (địa chỉ trình xử lý trap, chế độ direct hoặc vectored);
- `mepc`, `mcause`, `mtval` (PC, nguyên nhân và thông tin bổ sung của trap);
- các bộ đếm `mcycle`, `minstret`, `mhpmcounter3..31` và bản chỉ đọc `cycle`, `time`, `instret` (Zicntr).

**Ngoại lệ chính xác (precise exception)**: khi trap xảy ra, mọi lệnh trước `mepc` đã hoàn tất, lệnh tại `mepc` và
sau đó chưa làm thay đổi trạng thái kiến trúc – trình xử lý có thể quay lại bằng MRET như chưa có gì xảy ra.

## 1.2. Pipeline, xung đột và dự đoán rẽ nhánh

### 1.2.1. Pipeline 5 tầng

Pipeline chia việc thực thi một lệnh thành các tầng nối tiếp có thanh ghi đệm ở giữa, để nhiều lệnh cùng được xử lý ở
các tầng khác nhau. Pipeline 5 tầng kinh điển gồm IF (lấy lệnh), ID (giải mã, đọc thanh ghi), EX (tính toán), MEM
(truy cập bộ nhớ), WB (ghi kết quả). Lý tưởng, mỗi chu kỳ một lệnh hoàn tất (CPI = 1) trong khi chu kỳ clock ngắn hơn
nhiều so với lõi single-cycle vì mỗi tầng chỉ chứa một phần logic. Hiệu năng tỷ lệ với `f_clk / CPI`.

### 1.2.2. Xung đột (hazard)

- **Xung đột dữ liệu (RAW)**: lệnh sau cần kết quả của lệnh trước chưa được ghi vào tệp thanh ghi. Giải quyết bằng
  **forwarding** (đưa kết quả từ thanh ghi pipeline ở tầng sau ngược về đầu vào EX) và, khi dữ liệu chưa sẵn sàng
  (load), bằng **stall** chèn bong bóng (bubble).
- **Xung đột điều khiển**: hướng và đích của lệnh nhánh chỉ biết ở EX, trong khi IF đã lấy các lệnh tiếp theo. Nếu
  đoán sai, các lệnh lấy nhầm phải bị hủy (flush) – mất một số chu kỳ gọi là penalty.
- **Xung đột cấu trúc**: một tài nguyên bận nhiều chu kỳ (bộ chia lặp, bus chậm) buộc các tầng trước phải chờ.

### 1.2.3. Dự đoán rẽ nhánh

- **Tĩnh**: luôn đoán không nhảy (not-taken) – đơn giản, đúng với các nhánh ít khi nhảy.
- **Động với BHT (Branch History Table)**: bảng counter bão hòa 2 bit, chỉ số bằng các bit thấp của PC. Counter tăng
  khi nhánh nhảy, giảm khi không nhảy; bit cao là dự đoán. So với counter 1 bit, counter 2 bit cần hai lần ngược
  hướng liên tiếp mới đổi dự đoán, nên vòng lặp chỉ bị đoán sai một lần ở lần thoát.
- **BTB (Branch Target Buffer)**: bộ đệm lưu đích của các lệnh nhảy, tra cứu bằng PC ngay ở IF. Kết hợp BTB (biết
  lệnh là nhánh và đích của nó) với BHT (biết hướng) cho phép nhảy tới đích ngay trong chu kỳ lấy lệnh, penalty 0
  khi đoán đúng.

## 1.3. Giao thức bus AMBA APB

AMBA APB (Advanced Peripheral Bus, phiên bản APB4 trong ARM IHI 0024) là bus đơn giản cho ngoại vi tốc độ thấp. Một
giao dịch gồm hai pha:

1. **SETUP**: master bật `PSEL` cho slave được chọn, đặt `PADDR`, `PWRITE`, `PWDATA`, `PSTRB`; `PENABLE = 0`.
2. **ACCESS**: `PENABLE = 1`; các tín hiệu giữ nguyên tới khi slave trả `PREADY = 1`. Slave có thể kéo dài pha này
   (wait state) và báo lỗi bằng `PSLVERR`.

APB4 bổ sung `PSTRB` (byte nào được ghi) và `PPROT` (thuộc tính bảo vệ). Một giao dịch tối thiểu 2 chu kỳ bus; ưu điểm
là logic slave rất nhỏ và không có pipeline giao dịch.

## 1.4. Giao thức UART

UART (Universal Asynchronous Receiver/Transmitter) truyền nối tiếp không đồng bộ trên một dây cho mỗi chiều. Đường
dây nghỉ ở mức 1; một khung gồm bit start (0), 5–9 bit dữ liệu (thường 8, LSB trước), bit parity tùy chọn (chẵn/lẻ)
và 1–2 bit stop (1). Hai bên thống nhất trước tốc độ baud. Bên thu không có clock của bên phát nên thường lấy mẫu
nhanh hơn baud 16 lần: phát hiện cạnh xuống của start, chờ nửa bit để kiểm tra lại (lọc nhiễu), rồi lấy mẫu mỗi bit ở
giữa. Các lỗi điển hình: frame error (stop bit = 0), parity error, overrun (dữ liệu mới đến khi bộ đệm đầy).

## 1.5. Giao thức SPI

SPI (Serial Peripheral Interface) là bus đồng bộ, song công: master phát clock `SCLK`, dữ liệu `MOSI` (master →
slave) và `MISO` (slave → master), mỗi slave một chân chọn `CS_N` tích cực thấp. Mỗi cạnh clock đồng thời đẩy một bit
ra và nhận một bit vào. Bốn mode được xác định bởi:

- **CPOL**: mức nghỉ của SCLK (0 thấp, 1 cao);
- **CPHA**: 0 – dữ liệu lấy mẫu ở cạnh đầu (bit đầu tiên phải được đặt trước cạnh đầu), 1 – lấy mẫu ở cạnh thứ hai.

Bảng 1.2. Bốn mode SPI.

| Mode | CPOL | CPHA | Lấy mẫu | Đổi dữ liệu |
|---|---|---|---|---|
| 0 | 0 | 0 | cạnh lên | cạnh xuống |
| 1 | 0 | 1 | cạnh xuống | cạnh lên |
| 2 | 1 | 0 | cạnh xuống | cạnh lên |
| 3 | 1 | 1 | cạnh lên | cạnh xuống |

Bộ nhớ flash NOR nối tiếp (họ W25Q) dùng mode 0 hoặc 3 với các lệnh: `0x9F` đọc JEDEC ID, `0x03` đọc, `0x06` cho phép
ghi, `0x02` ghi một trang (256 byte), `0x20` xóa sector 4 KB, `0x05` đọc thanh ghi trạng thái (bit WIP báo đang ghi/xóa).

## 1.6. Hệ thống trên chip (SoC)

SoC tích hợp lõi xử lý, bộ nhớ, bus và ngoại vi trên một chip. Ở mức đồ án này, SoC gồm lõi RISC-V, RAM hợp nhất cho
lệnh và dữ liệu, bộ giải mã địa chỉ, cầu nối sang bus APB, các ngoại vi giao tiếp (UART, SPI), bộ định thời 64 bit,
GPIO và bộ điều khiển ngắt. Phần mềm truy cập ngoại vi bằng load/store vào vùng địa chỉ ánh xạ bộ nhớ (memory-mapped
I/O) và phản ứng với sự kiện qua ngắt.

## 1.7. Công cụ

- **Verilator**: dịch SystemVerilog sang C++ để mô phỏng nhanh, lint, coverage.
- **GNU toolchain RISC-V** (GCC, binutils): biên dịch firmware, riscv-tests, benchmark.
- **Spike**: mô phỏng tập lệnh chuẩn của RISC-V, dùng làm mô hình tham chiếu.
- **riscv-tests**: bộ test tuân thủ ISA chính thức.
- **Yosys / nextpnr**: tổng hợp logic và đặt–định tuyến trên FPGA ECP5 để ước lượng diện tích và tần số.
- **CoreMark, Dhrystone**: benchmark đánh giá hiệu năng lõi.

# Layout ASIC – từ RTL tới GDSII bằng OpenLane

Số liệu (diện tích, Fmax, công suất, DRC/LVS) nằm trong `results/asic/summary.md`; quyết định và các lần thử cấu
hình ghi ở D30 (`docs/decisions.md`). File này giải thích **làm gì và vì sao**.

## Flow gồm những bước nào

OpenLane 2 là chuỗi công cụ mã nguồn mở biến RTL thành file layout (GDSII) để gửi đi sản xuất. PDK (process design
kit) sky130A của SkyWater mô tả quy trình 130 nm: luật thiết kế, lớp kim loại, thư viện cell chuẩn
`sky130_fd_sc_hd` (cổng logic, flip-flop đã vẽ sẵn layout, có thông số timing ở nhiều góc PVT).

| Bước | Công cụ | Làm gì |
|---|---|---|
| Lint, tổng hợp | Verilator, Yosys + Synlig | RTL → netlist gồm cell sky130 |
| Floorplan, lưới nguồn | OpenROAD | Chọn kích thước die (mật độ 40 %), đặt chân I/O, vẽ lưới VPWR/VGND trên met4/met5 |
| Đặt cell (placement) | OpenROAD | Đặt ~50 nghìn cell vào hàng; sửa slew/cap/fanout bằng buffer |
| CTS | OpenROAD (TritonCTS) | Dựng cây buffer clock để clock tới mọi flip-flop gần như cùng lúc (skew nhỏ) |
| Tối ưu timing | OpenROAD (resizer) | Đổi kích thước cell, nhân bản cell, chèn buffer để sửa setup/hold |
| Đi dây | OpenROAD (FastRoute, TritonRoute) | Đi dây toàn cục rồi chi tiết trên li1, met1–met5; sửa antenna bằng diode |
| Trích ký sinh, STA | OpenRCX, OpenSTA | Tính R, C thật của dây → timing ở 9 góc PVT, công suất |
| Xuất GDS | Magic, KLayout | Hai công cụ xuất độc lập; XOR so hai bản phải giống nhau |
| DRC | Magic, KLayout | Kiểm luật hình học (độ rộng, khoảng cách, mật độ kim loại) |
| LVS | Netgen | Trích mạch từ layout, so với netlist – layout phải đúng mạch đã tổng hợp |

Chạy: `make asic` (Docker image OpenLane 2.3.10, lần đầu khoảng 1–1,5 giờ trên máy 4 nhân, 7,5 GB RAM).

## Vì sao chỉ làm lõi, không làm cả SoC

RAM 128 KB của SoC trong ASIC phải là **macro SRAM** (khối nhớ vẽ sẵn). Flow mặc định không có macro SRAM cho sky130,
nên RAM sẽ thành ~1 triệu flip-flop – lớn gấp hàng chục lần lõi và vượt khả năng máy. Lõi có ranh giới rõ ràng: hai
cổng Wishbone trở thành chân của khối. Đây cũng là cách làm thực tế: lõi được "harden" thành một macro rồi ghép với
macro SRAM và ngoại vi ở cấp chip.

## Đọc các con số

- **Góc PVT:** TT (typical, 25 °C, 1,80 V) là góc điển hình; SS (chậm, 100 °C, 1,60 V) là xấu nhất về setup; FF
  (nhanh, −40 °C, 1,95 V) là xấu nhất về hold. Fmax = 1 / (chu kỳ − setup slack) ở từng góc.
- **Sign-off mặc định của OpenLane** chỉ coi setup ở góc TT là bắt buộc. Lõi pipeline đạt 40 MHz ở TT và FF nhưng
  không đạt ở SS – chip thật muốn chạy 40 MHz ở mọi điều kiện thì phải tối ưu thêm (hoặc chạy chậm hơn ở góc SS).
- **Fmax ASIC cao hơn ECP5** vì cell chuẩn nhanh hơn LUT + dây lập trình của FPGA. Hai con số bổ sung cho nhau:
  ECP5 là ước lượng cho board, sky130 là ước lượng cho chip.
- **Công suất** do OpenSTA tính với hoạt động chuyển mạch mặc định (không lấy từ mô phỏng thật) → chỉ để so sánh
  tương đối giữa hai lõi.
- **Lõi single-cycle**: Fmax đứng riêng không so được với pipeline – trong lõi không có đường thanh ghi → thanh ghi,
  mọi đường găng đi ra bộ nhớ ngoài khối rồi quay lại (20 % chu kỳ giả định cho mỗi phía).

## Antenna, slew, cap là gì

- **Antenna:** khi chế tạo, dây kim loại dài nối vào cổng transistor tích điện và có thể đánh thủng lớp oxide cổng.
  Luật antenna giới hạn tỉ lệ diện tích dây / diện tích cổng; cách sửa là chèn diode xả điện hoặc nhảy lớp kim loại.
- **Max slew / max cap:** cạnh tín hiệu quá chậm hoặc tải quá lớn so với giới hạn của thư viện → sửa bằng buffer
  hoặc cell lớn hơn.
- Bốn lần thử cấu hình (D30) cho thấy sự đánh đổi: chèn diode ở mọi net dài hơn 90 µm sửa gần hết antenna nhưng
  diode làm tăng tải → slew xấu đi và số cell tăng ~55 %; không chèn diode thì slew tốt nhưng còn 145 net vi phạm
  antenna. Cấu hình cuối chỉ chèn diode trên net dài hơn 250 µm: còn 26 net, slew ở góc TT gần như sạch. Các vi phạm còn lại được liệt kê trong bảng; OpenLane báo cảnh báo,
  không chặn sign-off, nhưng phải sửa hết trước khi tape-out thật.

## Làm sao biết layout vẫn đúng chức năng

LVS chỉ chứng minh layout đúng **netlist**. Để chứng minh netlist đúng **RTL**, netlist cuối cùng (sau đi dây, có
buffer, cell clone, diode) được mô phỏng gate-level: Icarus Verilog + mô hình chức năng `sky130_fd_sc_hd`, cùng một
testbench `tb/asic/tb_core_gl.v` chạy RTL bằng Verilator. Mọi riscv-tests PASS ở RTL phải PASS trên netlist với cùng
số chu kỳ, cùng số lần ghi và cùng chữ ký ghi bộ nhớ (`results/asic/gl_<top>.csv`). Mô hình cell dùng
`-DUNIT_DELAY=#1`: flip-flop có trễ 1 ns ở đầu ra để tránh race giữa các flip-flop khi mô phỏng không có trễ, còn cổng
tổ hợp không có trễ – tức là kiểm tra chức năng, không kiểm tra timing (timing do STA đảm nhận).

## Câu hỏi hay gặp

- *Vì sao dùng Synlig?* Bộ đọc Verilog của Yosys 0.46 trong image không nhận `import rv_pkg::*;` ở đầu file; Synlig
  (frontend SystemVerilog dựa trên Surelog) đọc được mà không phải sửa RTL.
- *Netlist ASIC có giống netlist ECP5 không?* Không: cùng RTL nhưng thư viện đích khác (cell sky130 thay cho LUT/DSP
  của ECP5), nên số cell và đường găng khác nhau.
- *Có thể tape-out được chưa?* Chưa: còn vi phạm antenna/slew/cap, chưa có pad I/O, macro SRAM và lớp chip-level
  (ví dụ Caravel của chương trình MPW). Phần này chứng minh thiết kế đi được hết flow vật lý với DRC/LVS sạch.

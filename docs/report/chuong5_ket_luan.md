# Chương 5. Kết luận và hướng phát triển

## 5.1. Đối chiếu với mục tiêu

Bảng 5.1. Mục tiêu của đề tài và kết quả đạt được (bằng chứng chi tiết: `docs/compliance.md`).

| Mục tiêu | Kết quả |
|---|---|
| Lõi RISC-V RV32IMC pipeline 5 tầng | Hoàn thành `rv_core`: RV32I + M + C + Zicsr + Zifencei + Zicntr, Machine mode; forwarding, stall, flush; ngoại lệ chính xác, ngắt direct/vectored |
| Dự đoán rẽ nhánh | 3 chế độ (tĩnh, BHT ở ID, BHT + BTB ở IF) chọn bằng tham số; phát hiện sai dự đoán thống nhất bằng `pred_npc`; CPI giảm rõ rệt ở chế độ 2 (Chương 4) |
| Ngoại vi truyền thông UART và SPI | UART (parity, 1/2 stop, lấy mẫu ×16, FIFO, ngắt watermark/lỗi) và SPI master (4 mode, MSB/LSB, FIFO, ngắt DONE/overrun), có driver polling và ngắt |
| SoC hoàn chỉnh | RAM 128 KB, bus nội bộ + APB4, TIMER64, GPIO, INTC; firmware chạy demo đọc flash SPI định kỳ và nhận lệnh qua UART |
| Tổng hợp được | Lint sạch, Yosys sạch, đặt–định tuyến trên ECP5 (Fmax ước lượng trong `results/synth/summary.md`) |
| Xác minh | 13 unit testbench; riscv-tests trên 6 cấu hình; khớp từng lệnh với Spike; 11 system test; coverage |
| Đánh giá | 5 thí nghiệm hiệu năng có số liệu tái tạo được bằng `make perf` |

## 5.2. Nhận xét

- Pipeline 5 tầng với BHT + BTB đạt CPI xấp xỉ 1,1 (geomean trên 9 benchmark), phần còn lại chủ yếu do sai dự đoán ở
  các benchmark phụ thuộc dữ liệu (median, qsort) và stall load-use; chi phí là bảng dự đoán làm bằng flip-flop chiếm
  phần đáng kể diện tích lõi (Bảng S1–S2).
- Extension C giảm khoảng một phần tư kích thước mã mà gần như không ảnh hưởng CPI nhờ RAM đọc tổ hợp ghép được lệnh
  vắt qua ranh giới word.
- Việc so sánh lock-step với Spike trên hàng trăm nghìn lệnh và taint tracking cho giá trị counter cho độ tin cậy cao
  rằng các cơ chế forwarding/stall/flush không làm sai kết quả lệnh nào.

## 5.3. Hạn chế

- Chỉ Machine mode; không PMP, không debug module, không S/U-mode (hai test rv32mi bị loại trừ vì lý do này).
- RAM đọc tổ hợp: không ánh xạ được sang SRAM/Block RAM đồng bộ; đường đọc RAM nằm trên đường tổ hợp của IF và MEM
  (quyết định Fmax của SoC single-cycle).
- Bộ nhân tổ hợp 1 chu kỳ đứng sau chuỗi forwarding là đường găng của lõi pipeline (Fmax ước lượng ~42–44 MHz trên
  ECP5, Bảng 4.12).
- JALR (đặc biệt `ret`) dự đoán bằng đích lần trước nên sai nhiều khi hàm được gọi từ nhiều nơi.
- Ngắt phải chờ bộ chia lặp hoàn tất rồi mới hủy lệnh chia (độ trễ ngắt xấu nhất tăng ~34 chu kỳ).
- Fmax chỉ là ước lượng trên FPGA; chưa làm luồng ASIC.

## 5.4. Hướng phát triển

1. **Return Address Stack** cho `ret` và bộ dự đoán có lịch sử toàn cục (gshare) để tăng độ chính xác ở JALR và các
   nhánh tương quan.
2. **SRAM đồng bộ + prefetch buffer** (hoặc I-cache/D-cache) để dùng Block RAM/SRAM, rút ngắn đường găng và mở rộng
   bộ nhớ.
3. **Extension A** (nguyên tử) và **lệnh tùy biến** (custom-0/1) cho các phép toán chuyên dụng.
4. Thêm ngoại vi truyền thông khác như **I2C**, CAN – ngoài phạm vi đề tài (chỉ UART và SPI).
5. **U-mode + PMP**, debug module theo RISC-V Debug Specification.
6. Cho phép nhận ngắt khi tầng MEM là bubble do bộ chia để giảm độ trễ ngắt.
7. Luồng **RTL-to-GDSII** (OpenLane, thư viện sky130) để có diện tích và tần số ASIC thực tế.

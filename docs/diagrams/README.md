# Sơ đồ draw.io

Mở `so_do_khoi.drawio` bằng [diagrams.net / draw.io](https://app.diagrams.net) (File → Open) hoặc extension
**Draw.io Integration** trong VS Code. Mỗi sơ đồ là một trang (tab ở dưới cùng cửa sổ draw.io).

| Trang                  | Nội dung                                                                | Ảnh xuất                                |
| ---------------------- | ----------------------------------------------------------------------- | --------------------------------------- |
| 1. Kiến trúc SoC       | lõi, RAM, bộ giải mã địa chỉ, cầu APB, 5 ngoại vi, đường ngắt           | `png/so_do_khoi_1_soc.png`              |
| 2. Lõi pipeline 5 tầng | các khối trong từng tầng, đổi hướng PC, forwarding, khối xử lý xung đột | `png/so_do_khoi_2_pipeline.png`         |
| 3. Dự đoán rẽ nhánh    | PC → BTB, BHT → chọn PC kế; kiểm tra ở EX, hủy lệnh, cập nhật           | `png/so_do_khoi_3_du_doan_re_nhanh.png` |
| 4. Ngoại vi UART, SPI  | thanh ghi, TX/RX FIFO, bộ phát/thu, bộ dịch SPI, bộ chia, ngắt          | `png/so_do_khoi_4_uart_spi.png`         |
| 5. Board DE2           | thạch anh, PLL, SoC, công tắc, LED, JP1 – flash SPI, RS-232, nạp JTAG   | `png/so_do_khoi_5_board_de2.png`        |
| 6. Quy trình thiết kế  | đặc tả → kiến trúc → RTL → xác minh → hiệu năng → tổng hợp → hiện thực  | `png/so_do_khoi_6_quy_trinh.png`        |
| 7. Luồng xác minh      | chương trình → GCC → mô phỏng RTL / Spike → so sánh, kiểm tra → kết quả | `png/so_do_khoi_7_xac_minh.png`         |

File `.drawio` và ảnh PNG được sinh cùng lúc bằng `python scripts/draw_simple_diagrams.py`. Sửa trong script rồi
chạy lại để hai bản luôn giống nhau; nếu sửa trực tiếp bằng draw.io thì xuất lại PNG bằng File → Export as → PNG.

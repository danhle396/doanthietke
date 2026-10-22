---
title: "Thiết kế SoC dựa trên lõi RISC-V RV32IMC pipeline 5 tầng có dự đoán rẽ nhánh, tích hợp ngoại vi truyền thông UART và SPI"
subtitle: "Báo cáo Đồ án Thiết kế 1"
author:
  - "Sinh viên thực hiện: Lê Thành Danh – MSSV 23CE010 – Lớp 23IC"
  - "Giảng viên hướng dẫn: TS. Dương Ngọc Pháp"
institute: "Khoa Kỹ thuật Máy tính và Điện tử – Trường Đại học Công nghệ Thông tin và Truyền thông Việt – Hàn (VKU)"
lang: vi
toc: true
toc-title: "Mục lục"
---

# Lời mở đầu {.unnumbered}

Báo cáo trình bày quá trình thiết kế, hiện thực và xác minh đề tài **"Thiết kế SoC dựa trên lõi RISC-V RV32IMC
pipeline 5 tầng có dự đoán rẽ nhánh, tích hợp ngoại vi truyền thông UART và SPI"**. Sản phẩm gồm mã RTL
SystemVerilog tổng hợp được, phần mềm nhúng (driver, chương trình kiểm thử, benchmark), môi trường xác minh ba mức
và bộ kết quả đo đạc có thể tái tạo bằng một lệnh.

Mọi con số trong báo cáo được trích trực tiếp từ các file trong thư mục `results/` của mã nguồn; mỗi bảng ghi rõ
file nguồn, và mỗi thí nghiệm ghi lệnh để chạy lại.

Bố cục:

- Chương 1 – Tổng quan về kiến trúc RISC-V và hệ thống SoC.
- Chương 2 – Thiết kế lõi RV32IMC pipeline 5 tầng.
- Chương 3 – Thiết kế SoC và các ngoại vi.
- Chương 4 – Xác minh và đánh giá.
- Chương 5 – Kết luận và hướng phát triển.

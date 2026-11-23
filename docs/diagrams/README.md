# Sơ đồ draw.io

Mở bằng [diagrams.net / draw.io](https://app.diagrams.net) (File → Open) hoặc extension **Draw.io Integration** trong
VS Code (mở thẳng file `.drawio`). Mỗi file có nhiều trang (tab ở dưới cùng cửa sổ draw.io).

## `kien_truc.drawio` – kiến trúc

| Trang                 | Nội dung                                                                                           | Ảnh xuất                         |
| --------------------- | -------------------------------------------------------------------------------------------------- | -------------------------------- |
| 1. SoC soc_top        | rv_core, ram_dp, dbus_xbar, apb_bridge, bus APB4, 6 slave APB, đường ngắt, chân I/O                | `png/kien_truc_1_soc.png`        |
| 2. Pipeline rv_core   | 5 tầng IF/ID/EX/MEM/WB, thanh ghi pipeline, forwarding, redirect, cập nhật BHT/BTB, hazard_unit    | `png/kien_truc_2_pipeline.png`   |
| 3. UART và SPI master | thanh ghi APB, FIFO 16 × 8, uart_tx / uart_rx, spi_master, CS, logic ngắt                          | `png/kien_truc_3_uart_spi.png`   |
| 4. Board DE2          | de2_top: PLL 24 MHz, reset, soc_top 32 KB M4K, RS-232, JP1 (SPI flash), SW / LEDR / LEDG, nạp JTAG | `png/kien_truc_4_board_de2.png`  |
| 5. Bản đồ bộ nhớ      | RAM 0x8000_0000, 16 slot APB 0x1000_x000, vùng lỗi, cách giải mã ibus / dbus                       | `png/kien_truc_5_memory_map.png` |

## `quy_trinh_thiet_ke.drawio` – quy trình thiết kế

| Trang                 | Nội dung                                                                                                                      | Ảnh xuất                        |
| --------------------- | ----------------------------------------------------------------------------------------------------------------------------- | ------------------------------- |
| 1. Quy trình thiết kế | đặc tả → kiến trúc → RTL → lint → xác minh (vòng gỡ lỗi) → hiệu năng → tổng hợp → FPGA / ASIC → tài liệu, đối chiếu Phase 0–8 | `png/quy_trinh_1_tong_quat.png` |
| 2. Luồng xác minh     | phần mềm → GCC → ELF / hex → Verilator, Spike, co-sim, BFM, unit TB → `make regress`                                          | `png/quy_trinh_2_xac_minh.png`  |
| 3. Luồng hiện thực    | Yosys + nextpnr-ecp5, Quartus II cho DE2, OpenLane 2 / sky130A                                                                | `png/quy_trinh_3_hien_thuc.png` |

Ảnh trong `png/` được xuất từ chính các file `.drawio` (độ phân giải ×2). Sau khi sửa sơ đồ, xuất lại bằng
draw.io: File → Export as → PNG (chọn trang, Zoom 200 %).

Các hình matplotlib / Mermaid / WaveDrom dùng trong báo cáo (FSM, sơ đồ khối cũ) nằm ở `docs/report/hinh/`, sinh lại
bằng `scripts/draw_diagrams.py` (`make docs`).

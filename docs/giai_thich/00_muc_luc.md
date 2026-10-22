# Tài liệu giải thích – mục lục

Bộ tài liệu này giúp sinh viên tự trình bày và bảo vệ thiết kế. Mỗi file giải thích một khối: chức năng, sơ đồ,
tín hiệu quan trọng và các tình huống khó. Số liệu (CPI, diện tích, Fmax, coverage) luôn lấy từ `results/` – không
nhớ thuộc lòng mà mở file kết quả khi cần.

| File | Nội dung |
|---|---|
| `01_rv_core_tong_quan.md` | Pipeline 5 tầng, thanh ghi pipeline, luồng một lệnh |
| `02_if_stage.md` | Lấy lệnh, lệnh 16/32 bit, lệnh vắt qua ranh giới word, chọn PC kế |
| `03_id_stage.md` | Giải nén RV32C, decoder, imm, ngoại lệ ở ID, redirect ở ID |
| `04_ex_stage.md` | Forwarding, ALU, branch_unit, phát hiện sai dự đoán, MulDiv |
| `05_mem_wb_stage.md` | LSU, CSR, trap/ngắt chính xác tại MEM, WB, commit log |
| `06_hazard_forward.md` | Stall, flush, forward – vì sao ưu tiên `ex_mem` |
| `07_branch_predictor.md` | BHT, BTB, 3 chế độ, vì sao so `pred_npc` bắt mọi sai dự đoán |
| `08_csr_trap.md` | CSR, mcause/mtval, ngắt, mtvec vectored, counter |
| `09_muldiv.md` | Bộ nhân 33×33, bộ chia radix-2, trường hợp đặc biệt, hủy |
| `10_rv_core_sc.md` | Lõi single-cycle tham chiếu |
| `11_bo_nho_bus.md` | `ram_dp` đọc tổ hợp, `dbus_xbar`, FSM `apb_bridge` |
| `12_uart.md` | UART: TX, RX lấy mẫu ×16, FIFO, ngắt |
| `13_spi.md` | SPI master: 4 mode, FSM, DONE/overrun |
| `14_timer_gpio_intc.md` | TIMER64, GPIO, INTC, SIM_CTRL |
| `15_soc_top_phan_mem.md` | soc_top, reset, firmware, driver |
| `16_xac_minh.md` | Môi trường xác minh 3 mức, Spike, coverage |
| `walkthrough_pipeline.md` | Theo dõi từng chu kỳ: load-use, nhánh sai, lệnh nén, ngắt |
| `huong_dan_chay.md` | Lệnh chạy lại mọi kết quả, mở waveform, đổi tham số |
| `bao_ve_QA.md` | Câu hỏi hội đồng và trả lời |

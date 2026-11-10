# Lõi single-cycle tham chiếu (`rtl/core_sc/rv_core_sc.sv`)

## Vai trò

1. Bước đầu tiên của dự án (Phase 1): kiểm tra decoder, ALU, regfile, CSR, bus, môi trường riscv-tests trước khi
   làm pipeline.
2. Điểm so sánh hiệu năng: CPI = 1 nhưng chu kỳ clock dài (toàn bộ đường tổ hợp từ PC → RAM → decode → regfile → ALU
   → RAM dữ liệu → regfile nằm trong một chu kỳ). Hiệu năng ∝ Fmax / CPI (thí nghiệm 5).

## Đặc điểm

- Cùng danh sách port với `rv_core`; chọn bằng `soc_top #(.CORE_SC(1))`.
- RV32I + Zicsr + Zifencei + trap/ngắt (dùng chung `csr_file`). Lệnh M và lệnh 16 bit → illegal.
- Dùng chung `decoder`, `imm_gen`, `alu`, `branch_unit`, `lsu`, `regfile` (tắt write-through), `wb_stage` (commit log).
- Khi giao dịch Wishbone (lấy lệnh hoặc dữ liệu) chưa có `ACK/ERR` (ví dụ truy cập APB), toàn lõi đứng yên: không
  ghi PC, regfile hay CSR.
- Ngắt được kiểm tra trước khi thực thi lệnh tại PC hiện tại (`mepc` = PC đó).

## Kết quả

rv32ui pass (41 test) và khớp Spike từng lệnh – xem `results/isa/sc.md`, `results/spike/sc.md`.

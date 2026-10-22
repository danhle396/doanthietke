# Nhật ký quyết định thiết kế

Mỗi mục: **Bối cảnh – Quyết định – Lý do**. Ghi lại khi `PROJECT_SPEC.md` thiếu chi tiết, mâu thuẫn với spec
RISC-V, hoặc khi công cụ buộc phải chọn cách làm khác.

## D1. Import package trong RTL
- **Bối cảnh:** Yosys `read_verilog -sv` (0.63) báo lỗi cú pháp với `module m import rv_pkg::*; (...)`
  và không nhận `typedef enum` của package khi import.
- **Quyết định:** đặt `import rv_pkg::*;` ở phạm vi file, ngay trước `module`; đổi `alu_op_e` thành các
  `localparam logic [3:0] ALU_*`. Verilator cảnh báo `IMPORTSTAR` → tắt có chú thích tại chỗ.
  `typedef enum` cục bộ trong module (FSM) vẫn dùng bình thường.
- **Lý do:** giữ được flow Yosys gốc (không cần chèn `sv2v`), mã vẫn đúng chuẩn SystemVerilog.

## D2. Phiên bản Spike
- **Bối cảnh:** master ngày 21/10/2026 không build được; build có debug info làm đầy đĩa.
- **Quyết định:** dùng commit `436fc16`, build `-O2 -g0`. Chạy Spike với `--isa=<march>_zicntr`
  (bản Spike mới tách Zicntr thành extension riêng; thiếu nó thì `rdcycle` trap illegal trong Spike
  nhưng lõi có Zicntr theo spec).
- **Lý do:** mô hình tham chiếu phải có cùng tập extension với RTL.

## D3. Write-through của regfile ở lõi single-cycle
- **Bối cảnh:** regfile write-through (cần cho pipeline: WB ghi, ID đọc cùng chu kỳ) tạo vòng tổ hợp ở lõi
  single-cycle (dữ liệu ghi phụ thuộc dữ liệu đọc của cùng lệnh).
- **Quyết định:** thêm parameter `WRITE_THROUGH` (mặc định 1); `rv_core_sc` dùng 0.
- **Lý do:** loại bỏ vòng tổ hợp, không ảnh hưởng chức năng.

## D4. Làm tươi toán hạng khi EX bị stall
- **Bối cảnh:** khi EX bị stall (chờ bus ở MEM, MulDiv), lệnh ở WB vẫn retire và rời pipeline; lệnh ở EX
  đang lấy toán hạng qua forwarding từ `mem_wb` sẽ mất nguồn forward.
- **Quyết định:** trong chu kỳ stall, thanh ghi `id_ex` vẫn giữ mọi trường nhưng chép giá trị toán hạng
  đã forward (`fwd_rs1/fwd_rs2`) vào `rs1_val/rs2_val`.
- **Lý do:** đơn giản, đúng trong mọi trường hợp (giá trị forward luôn là giá trị mới nhất).

## D5. Bộ chia
- **Quyết định:** FSM `IDLE → BUSY (32 vòng) → DONE`. Bắt đầu khi lệnh chia hợp lệ ở EX và bộ chia rảnh;
  toán hạng (giá trị tuyệt đối) chốt khi bắt đầu; kết quả giữ ở DONE tới khi lệnh rời EX (`advance`);
  `kill` (flush do trap/mret/fence.i ở MEM) đưa về IDLE. Chia cho 0 / tràn trả kết quả ngay ở IDLE.
  Tổng thời gian một lệnh DIV thường: 33 chu kỳ stall + 1.
- **Lý do:** đúng spec mục 4.6; không có side effect lặp lại khi EX bị stall bởi MEM.

## D6. `minstret` đếm ở WB
- **Bối cảnh:** spec yêu cầu đếm ở WB, nhưng CSR đọc ở MEM; test `rv32mi-p-instret_overflow` kiểm tra
  "giá trị ghi vào minstret là giá trị lệnh kế tiếp đọc được".
- **Quyết định:** (1) khi đọc `minstret(h)` ở MEM, cộng thêm lệnh đang retire ở WB cùng chu kỳ;
  (2) ghi CSR thắng việc tăng đếm trong cùng chu kỳ; (3) lệnh đã ghi `minstret/minstreth` mang cờ
  `instret_noinc` để không tự tăng khi tới WB. Ghi `mcycle` cũng thắng việc tăng của chu kỳ đó.
- **Lý do:** đúng ngữ nghĩa Privileged spec, khớp Spike.

## D7. `misa` chỉ đọc
- **Bối cảnh:** `rv32mi-p-ma_fetch` thử xóa `misa.C`; Spike cho phép tắt C động, lõi này không (spec: ghi `misa` bị bỏ qua – hợp lệ vì misa là WARL).
- **Quyết định:** giữ `misa` read-only. Trong so sánh Spike, lệnh đọc `misa`/`marchid`/`mimpid`
  khác giá trị được đánh dấu **KNOWN**; nếu sau đó luồng lệnh rẽ khác, kết quả là KNOWN (có ghi chi tiết),
  không tính là lỗi. Test vẫn PASS độc lập trên RTL.

## D8. Môi trường riscv-tests
- **Quyết định:** `RVTEST_PASS/FAIL` ghi `(code<<1)|1` trực tiếp vào `tohost` (không dùng ECALL) rồi lặp vô hạn.
  `trap_vector` nhảy vào `mtvec_handler` nếu test có định nghĩa, nếu không thì báo FAIL với mã
  `TESTNUM|1337`. Nhãn vòng lặp cuối dùng `8888:` (tránh trùng nhãn `1:` của `CHECK_XLEN`).
  Bỏ chuyển mode/PMP/satp/medeleg; thay `mret` vào U-mode bằng `j 1f`.

## D9. Kết thúc mô phỏng bằng SIM_CTRL
- **Quyết định:** `sim_ctrl` chốt yêu cầu EXIT và tự `$finish/$fatal` sau `EXIT_DELAY = 1000` chu kỳ;
  `tb_soc` phản ứng trước (sau 8 chu kỳ để WB in nốt commit log), chạy kiểm tra cuối (UART kỳ vọng, …),
  in performance counter rồi in `PASS`/`FAIL`.
- **Lý do:** module vẫn đúng spec khi dùng độc lập, testbench vẫn kiểm tra được đầu ra BFM.

## D10. Slot APB trống
- **Quyết định:** bridge vẫn đi qua SETUP/ACCESS nhưng không bật `PSEL`; ở ACCESS tự trả
  `ready = 1, err = 1`. Slot có slave do parameter `SLOT_MASK` khai báo.

## D11. Redirect ở ID khi đích không căn lề
- **Quyết định:** với `ENABLE_C = 0`, ID không redirect JAL/branch tới đích có `bit[1] = 1`; EX gắn
  ngoại lệ instruction-address-misaligned (mcause 0) và không redirect (spec 4.3).

## D12. Lệnh mang ngoại lệ
- **Quyết định:** ngoại lệ phát hiện ở IF/ID được chốt trong `id_ex`, đồng thời xóa mọi cờ có side effect
  (`rd_we`, load/store/CSR/MulDiv/nhánh/mret/fence.i). EX chỉ có thể thêm instruction-misaligned.
  CSR không tồn tại / ghi CSR read-only được phát hiện ở MEM (nơi có `csr_file`) → illegal, `mtval` = mã lệnh.

## D13. Ngắt so với ngoại lệ phát hiện ở MEM
- **Quyết định:** điều kiện `!mem_exc` trong `take_irq` chỉ xét ngoại lệ mang theo từ tầng trước. Nếu lệnh
  ở MEM sẽ bị misaligned/access fault mà có ngắt cùng lúc, ngắt được nhận trước (lệnh bị hủy, `mepc` = PC
  của nó, sẽ chạy lại sau MRET) – giống thứ tự của Spike (kiểm tra ngắt trước khi thực thi lệnh).

## D14. Định nghĩa "dự đoán sai" cho counter
- **Quyết định:** `mhpmcounter4/6` đếm lệnh có `actual_npc != pred_npc` tại EX (penalty 2 chu kỳ).
  Redirect ở ID (JAL ở mode ≥ 1, branch đoán taken ở mode 1) tốn 1 bubble nhưng không tính là sai;
  testbench đếm riêng số redirect ở ID và ở EX (in `[perf] id_redirects/ex_redirects`) để tính penalty.

## D15. TIMER64
- **Bối cảnh:** thư mục `ip/timer64_dacs4/` không tồn tại (sinh viên không cung cấp mã ĐACS4).
- **Quyết định:** tự hiện thực `timer64_apb` theo bảng ở spec mục 8.4.

## D16. Commit log
- **Quyết định:** định dạng giống `spike --log-commits`: `core   0: 3 0x<pc> (0x<insn>) x<rd> 0x<val> mem 0x<addr> [0x<data>]`.
  Không in ghi x0 (Spike cũng không in). Load in địa chỉ, store in địa chỉ + dữ liệu theo kích thước.
  Không in ghi CSR (Spike có in `c<addr>_<name>`; script so sánh bỏ qua).

## D17. Lõi single-cycle
- **Quyết định:** `rv_core_sc` hiện thực RV32I + Zicsr + Zifencei + trap/ngắt (dùng chung `csr_file`);
  lệnh M và lệnh 16 bit là illegal (ma trận spec chỉ yêu cầu biến thể `i`). Ngắt được nhận trước khi
  thực thi lệnh tại PC hiện tại.

## D18. Dung lượng đĩa
- **Quyết định:** sau khi Verilator build, chỉ giữ file thực thi, xóa thư mục object; log của các lần so sánh
  Spike khớp được xóa (chỉ giữ log của lần không khớp).

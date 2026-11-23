# Câu hỏi bảo vệ – trả lời ngắn

Số liệu trích từ `results/` (mở file tương ứng khi trả lời để có con số mới nhất).

## A. Kiến trúc tổng quát

**1. Đề tài làm gì?** Một SoC dựa trên lõi RISC-V RV32IMC pipeline 5 tầng có dự đoán rẽ nhánh, tích hợp UART và SPI
master (có FIFO, ngắt), cùng TIMER64, GPIO, INTC trên bus APB; kèm môi trường xác minh 3 mức và đánh giá hiệu năng.

**2. RV32IMC gồm những gì?** I: tập lệnh nguyên 32 bit cơ bản; M: nhân/chia; C: lệnh nén 16 bit. Thêm Zicsr (CSR),
Zifencei (FENCE.I), Zicntr (cycle/time/instret). Chỉ Machine mode.

**3. Năm tầng pipeline và việc của từng tầng?** IF lấy lệnh + dự đoán; ID giải nén C, decode, đọc thanh ghi;
EX ALU, nhánh, MulDiv; MEM load/store, CSR, trap; WB ghi thanh ghi, đếm lệnh.

**4. Vì sao chọn 5 tầng?** Cân bằng giữa tần số và độ phức tạp hazard; là mô hình kinh điển (Patterson–Hennessy),
dễ giải thích forwarding và stall; đủ để thấy rõ lợi ích của dự đoán rẽ nhánh.

**5. Khác gì PicoRV32 và Ibex?** PicoRV32 không pipeline (nhiều chu kỳ/lệnh, CPI ~4) tối ưu diện tích. Ibex 2–3 tầng,
không có BTB, nhánh tĩnh. Thiết kế này 5 tầng có BHT+BTB nên CPI thấp hơn (~1,1–1,2) đổi lại nhiều logic hơn; Ibex
có PMP, debug, U-mode mà thiết kế này không có.

**6. Thiết kế có tổng hợp được không?** Có: một clock, reset bất đồng bộ tích cực thấp, không latch, không `initial`/
`#delay` ngoài vùng mô phỏng; lint Verilator `-Wall` sạch; Yosys `check -assert` sạch; đã chạy synth_ecp5 + nextpnr.

## B. Hazard và forwarding

**7. Có những loại hazard nào?** Dữ liệu (RAW), điều khiển (nhánh/nhảy/trap), cấu trúc (MulDiv bận, bus chờ).

**8. Forwarding hoạt động thế nào?** Ở EX, mỗi toán hạng chọn giữa giá trị đọc ở ID, kết quả ở `ex_mem` hoặc ở
`mem_wb`, khi `rd` của lệnh trước trùng `rs` và `rd ≠ 0`.

**9. Vì sao ưu tiên `ex_mem` hơn `mem_wb`?** Lệnh ở MEM trẻ hơn lệnh ở WB; nếu cả hai ghi cùng thanh ghi, giá trị đúng
theo thứ tự chương trình là của lệnh trẻ hơn.

**10. Vì sao load không forward từ `ex_mem`?** Dữ liệu load chỉ có ở cuối MEM; nối vào EX sẽ tạo đường tổ hợp quá dài.
Thay vào đó stall 1 chu kỳ (load-use), sau đó forward từ `mem_wb`.

**11. Load-use tốn bao nhiêu chu kỳ?** 1 chu kỳ. Phân rã CPI cho thấy phần load-use (vd Dhrystone ~0,05 chu kỳ/lệnh,
`results/perf/exp4_cpi_breakdown.csv`).

**12. CSR-use là gì?** Giống load-use: CSR đọc ở MEM nên lệnh liền sau dùng kết quả phải stall 1 chu kỳ.

**13. Write-through regfile giải quyết gì?** WB ghi và ID đọc cùng thanh ghi trong một chu kỳ → ID thấy ngay giá trị
mới; không cần đường forward thứ ba vào ID.

**14. Khi MEM chờ bus APB, lệnh ở EX bị stall – có mất dữ liệu forward không?** Có nguy cơ (lệnh ở WB retire). Thiết kế
chép giá trị đã forward vào `id_ex` trong lúc stall (decision D4).

**15. Flush và stall khác nhau thế nào?** Stall giữ nguyên thanh ghi pipeline; flush ghi bubble (`valid = 0`). Flush
luôn thắng stall.

## C. Dự đoán rẽ nhánh

**16. Ba chế độ BP_MODE?** 0: luôn not-taken; 1: BHT tra ở ID (JAL và branch đoán taken nhảy ở ID, 1 bubble);
2: BHT + BTB tra ở IF (nhảy ngay, 0 bubble khi đúng).

**17. Penalty sai dự đoán?** 2 chu kỳ (nhánh giải quyết ở EX, flush IF và ID). Redirect ở ID: 1 chu kỳ.

**18. BHT 2 bit tốt hơn 1 bit ở đâu?** Có trễ (hysteresis): một lần ngược hướng chưa đổi dự đoán. Vòng lặp chỉ sai
1 lần ở lần thoát thay vì 2 lần (thoát và vào lại) như counter 1 bit.

**19. Vì sao chỉ số BHT/BTB lấy từ bit 1?** Có lệnh 16 bit nên PC có thể lẻ 2; dùng từ bit 2 sẽ khiến hai lệnh nén liền
nhau dùng chung entry.

**20. BTB lưu gì?** `valid`, tag (phần còn lại của PC), đích (bit 31:1), loại (BRANCH/JAL/JALR). Direct-mapped.

**21. BTB alias là gì, xử lý ra sao?** Khi BTB đoán nhảy cho một lệnh không phải nhánh (entry cũ còn lại sau khi bộ nhớ
lệnh thay đổi, hoặc tag ngắn ở thiết kế khác). EX thấy `pred_npc != pc+len` → redirect và xóa entry. Test
`branch_smc` tạo đúng tình huống này: thay một JAL đã được BTB học bằng một ADDI, FENCE.I rồi gọi lại.

**22. Vì sao so sánh `pred_npc` phát hiện được mọi loại sai?** Mọi lỗi của front-end (sai hướng, sai đích JALR, alias,
mode 0 đoán sai) cuối cùng đều là "địa chỉ lệnh kế đã lấy ≠ địa chỉ đúng". So sánh hai địa chỉ thay vì phân loại.

**23. JALR được dự đoán thế nào?** Bằng đích lần trước trong BTB. Đúng cho gọi hàm qua con trỏ cố định, sai nhiều với
`ret` từ nhiều nơi gọi → hướng phát triển: Return Address Stack.

**24. Hiệu quả thực tế?** Geomean CPI 9 benchmark: 1,320 (BP0) → 1,223 (BP1) → 1,097 (BP2); Dhrystone 1,435 → 1,204
(`results/perf/summary.md`, bảng P1).

**25. Tăng kích thước BHT/BTB có luôn tốt hơn?** Độ chính xác tăng rồi bão hòa khi bảng đủ chứa các nhánh nóng của
benchmark, trong khi diện tích tăng tuyến tính (bảng làm bằng flip-flop). Xem bảng P2 và S2.

## D. Extension M và C

**26. Bộ nhân làm thế nào?** Một bộ nhân 33×33 có dấu tổ hợp trong EX, 1 chu kỳ; mở rộng bit dấu theo loại lệnh
(MULH/MULHSU/MULHU) để dùng chung.

**27. Bộ chia?** Restoring radix-2, 32 vòng (~33 chu kỳ stall), chốt toán hạng khi bắt đầu, kết quả giữ ở DONE.

**28. Chia cho 0 và tràn?** Trả ngay: DIV = -1, DIVU = 2³²-1, REM(U) = số bị chia; -2³¹/-1 → DIV = -2³¹, REM = 0
(theo spec RISC-V, không trap).

**29. Lợi ích của C?** Giảm kích thước mã ~24% trên 9 benchmark (bảng P3); CPI gần như không đổi vì mỗi lệnh nén
được giải nén thành lệnh 32 bit tương đương.

**30. Lệnh 32 bit vắt qua ranh giới word fetch ra sao?** RAM trả `{word[i+1][15:0], word[i][31:16]}` khi `addr[1]=1`
nên IF có đủ 32 bit trong 1 chu kỳ. Coverage `c_insn32_straddle` xác nhận tình huống đã xảy ra.

**31. Encoding nén nào phải báo illegal?** Toàn 0, ADDI4SPN imm 0, ADDI16SP/LUI imm 0, LWSP rd 0, JR rs1 0,
shift shamt[5]=1, lệnh FP nén, SUBW/ADDW.

## E. CSR, ngoại lệ, ngắt

**32. Precise exception là gì, đạt được thế nào?** Khi trap, mọi lệnh trước đã xong, lệnh tại `mepc` và sau đó chưa có
tác động. Đạt được nhờ xử lý trap ở MEM (điểm commit) – lệnh trẻ hơn chưa ghi gì – và flush các tầng trẻ hơn.

**33. Vì sao CSR và trap ở MEM mà không ở EX?** Lệnh ở EX có thể còn bị hủy bởi lệnh ở MEM trap; ghi CSR/store là
không thể hoàn tác nên phải ở điểm chắc chắn commit. Thêm nữa load/store fault chỉ biết ở MEM.

**34. Ưu tiên ngoại lệ?** Instruction access fault > illegal > ecall/ebreak > instruction misaligned > load/store
misaligned > access fault. Ngắt: MEI > MSI > MTI.

**35. mtvec vectored?** Ngắt nhảy tới `BASE + 4×cause`; ngoại lệ vẫn vào BASE. Test `irq_priority` kiểm cả hai chế độ.

**36. Độ trễ ngắt?** Vài chu kỳ (ngắt được nhận khi có lệnh ở MEM); `timer_irq` đo được max latency (xem log). Xấu nhất
khi MEM đang chờ giao dịch APB đã bắt đầu hoặc bộ chia đang chạy (~34 chu kỳ).

**37. Vì sao chặn `dbus_req` bằng `take_irq`?** Để không bắt đầu giao dịch bus (ví dụ ghi UART – có side effect) cho
một lệnh sắp bị hủy; và không hủy giao dịch đã bắt đầu (`mem_bus_started`).

**38. Ngắt đến khi đang chia thì sao?** Chờ DIV tới MEM rồi hủy DIV, chạy lại sau MRET; kết quả vẫn đúng
(`irq_during_div`).

**39. `minstret` đếm ở đâu, có vấn đề gì?** Ở WB. Đọc ở MEM cần cộng lệnh đang retire ở WB; lệnh ghi `minstret`
không tự tăng (decision D6, test `instret_overflow`).

## F. Bus và ngoại vi

**40. Timing APB?** SETUP 1 chu kỳ (PSEL=1, PENABLE=0) → ACCESS (PENABLE=1) tới khi PREADY; bridge thêm 1 chu kỳ IDLE
nhận yêu cầu → tối thiểu 3 chu kỳ/truy cập.

**41. Vì sao ngoại vi dùng APB?** Đơn giản, công suất thấp, đủ băng thông cho UART/SPI; tách khỏi bus RAM nhanh.

**42. Slot APB trống hoặc địa chỉ không ánh xạ?** Trả lỗi → load/store access fault (mcause 5/7); test `exceptions`.

**43. UART lấy mẫu ×16 để làm gì?** Xác định cạnh start chính xác tới 1/16 bit và lấy mẫu giữa bit, chịu được lệch
baud vài phần trăm; kiểm tra lại start bit ở giữa để lọc nhiễu.

**44. Vì sao đồng bộ 2 flip-flop cho RX và GPIO?** Tín hiệu ngoài không đồng bộ với clock; 2 FF giảm xác suất
metastability lan vào logic.

**45. Bốn mode SPI?** CPOL = mức nghỉ SCLK; CPHA = 0 lấy mẫu ở cạnh đầu (bit đầu đặt trước), CPHA = 1 lấy mẫu ở cạnh
thứ hai. Đã kiểm 4 mode × MSB/LSB × nhiều tốc độ.

**46. DONE interrupt của SPI dùng để làm gì?** Firmware nạp ≤ 16 byte vào FIFO, ngủ (`wfi`) tới khi DONE thay vì
polling (`spi_xfer_buf_irq`, test `spi_flash`).

**47. Ghi `mtimecmp` 64 bit trên bus 32 bit thế nào để tránh ngắt giả?** Ghi LO = 0xFFFF_FFFF, ghi HI, rồi ghi LO thật.

## G. RAM đọc tổ hợp, đường găng, diện tích

**48. Vì sao RAM đọc tổ hợp?** Để lấy 32 bit ở địa chỉ chẵn bất kỳ trong 1 chu kỳ (hỗ trợ C không cần prefetch buffer)
và IF dự đoán ngay. Tương ứng LUTRAM trên FPGA. Đổi lại không dùng được SRAM/BRAM đồng bộ.

**49. Đường găng nằm ở đâu?** Theo nextpnr (ECP5, cả 5 seed): từ thanh ghi `ex_mem` (`rd`, `rd_we`) qua so khớp
forwarding → mux toán hạng → chuỗi carry dài (CCU2C) của khối tính toán ở EX → tín hiệu điều khiển tới chân enable của
thanh ghi (`results/synth/critical_path_m1c1_bp2.txt`). Tức là **forwarding nối thẳng vào EX** trong một chu kỳ. Bộ nhân
(4 khối DSP `MULT18X18D`) nằm cùng tầng nhưng không phải đường dài nhất ở các seed đã chạy. Cải thiện: chèn thanh ghi
sau mux forward (đổi lại thêm stall), tách bộ nhân 2 tầng, rút ngắn logic stall/redirect. Lưu ý Fmax một seed dao động
tới vài chục % nên báo trung vị 5 seed (D24).

**50. Fmax và diện tích?** Xem `results/synth/summary.md` (ECP5, ước lượng FPGA) và `results/asic/summary.md` (layout sky130 của lõi, câu 66–70). Diện tích lõi tính
bằng cell Yosys generic, không tính RAM.

**51. Single-cycle so với pipeline?** Single-cycle CPI = 1 nhưng chu kỳ dài; pipeline CPI ~1,1–1,2 nhưng Fmax cao hơn →
hiệu năng ∝ Fmax/CPI (thí nghiệm 5, `results/perf/summary.md`).

## H. Xác minh

**52. Đã xác minh thế nào?** 3 mức: 14 unit TB (có mô hình tham chiếu, ngẫu nhiên có seed), riscv-tests trên 7 cấu hình,
11 system test C với BFM; cộng so sánh từng lệnh với Spike và coverage.

**53. So sánh Spike chứng minh gì?** Mỗi lệnh retire (PC, mã lệnh, thanh ghi đích, store) giống mô hình chuẩn trong
mọi riscv-test và benchmark → pipeline không làm sai kết quả của lệnh nào.

**54. Test nào bị loại trừ, vì sao?** `ma_data` (trap khi không căn lề là hợp lệ), `breakpoint` (cần debug trigger),
`pmpaddr` (cần PMP) – kèm dòng nguồn phụ thuộc trong `results/isa/summary.md`.

**55. Coverage đạt bao nhiêu?** Xem `results/coverage/summary.md` (line/toggle theo thư mục) và `functional.md`; phần
chưa phủ được liệt kê và giải thích trong `uncovered.md`.

**56. Làm sao biết test thật sự kiểm tra (không pass giả)?** PASS cần exit code 0 **và** chữ PASS; BFM kiểm dữ liệu
độc lập; kỳ vọng RVC sinh từ assembler; nhiều test được kiểm chứng bằng cách cố tình gây lỗi trong quá trình phát triển
(ví dụ BFM bắt lỗi cấu hình, `irq_priority` bắt nguồn ngắt chưa pending).

## I. Giới hạn và hướng phát triển

**57. Giới hạn chính?** Chỉ M-mode, không PMP/debug/U-mode; không cache; RAM đọc tổ hợp; JALR/return dự đoán kém;
ngắt chờ bộ chia; Fmax giới hạn bởi đường forward → khối tính toán ở EX trong một chu kỳ.

**58. Hướng phát triển?** RAS cho `ret`; SRAM đồng bộ + prefetch buffer; I/D cache; extension A; lệnh tùy biến; I2C/CAN;
U-mode + PMP; macro SRAM để làm layout cả SoC và đóng timing ở góc SS.

## J. Bus Wishbone và board FPGA

**59. SoC dùng chuẩn bus nào?** Wishbone B4 classic giữa lõi, RAM và interconnect `dbus_xbar`; AMBA APB4 giữa cầu
`apb_bridge` và ngoại vi. Bus lệnh là master chỉ đọc, bus dữ liệu là master đầy đủ (`CYC, STB, WE, SEL, ADR, DAT,
ACK, ERR`). `ERR` từ vùng trống, slot APB trống hoặc `PSLVERR` trở thành access fault ở lõi.

**60. Vì sao Wishbone mà không phải AXI hay OBI?** Pipeline lấy lệnh và load/store trong một chu kỳ. Wishbone classic
cho slave trả `ACK` ngay trong chu kỳ yêu cầu; OBI và AXI bắt phản hồi sớm nhất ở chu kỳ sau → phải tách IF và đưa dữ
liệu load về WB, CPI tăng. Với Wishbone, số chu kỳ 9 benchmark trùng khớp tuyệt đối trước và sau khi đổi bus (D28).
AXI hợp với lõi có nhiều giao dịch treo và cache, không cần cho lõi in-order một giao dịch.

**61. Làm sao biết bus tuân thủ giao thức?** `wb_checker` chạy trong mọi mô phỏng SoC trên 4 liên kết: CYC/STB tắt khi
reset, STB ⇒ CYC, ACK và ERR loại trừ nhau và chỉ khi có STB, master giữ nguyên ADR/WE/SEL/DAT tới khi kết thúc. Vi
phạm làm test FAIL; toàn bộ regression có 0 vi phạm. Thêm unit test `tb_dbus_xbar` với truy cập ngẫu nhiên.

**62. Chạy trên board DE2 thế nào khi RAM của Cyclone II chỉ đọc đồng bộ?** `RAM_SYNC = 1`: hai bank 16 bit chạy ở
cạnh xuống của clock; địa chỉ đến từ thanh ghi nên ổn định trước cạnh xuống, dữ liệu có trước cạnh lên kế tiếp – lõi
không đổi, số chu kỳ trùng khớp (D27). Cái giá: đường địa chỉ → RAM và RAM → thanh ghi chỉ còn nửa chu kỳ. Project
Quartus trong `fpga/` (PLL 24 MHz, RAM 32 KB trên M4K, firmware `.mif`, đầu ra UART mô phỏng để đối chiếu).

**63. Co-simulation C++ khác so sánh Spike thường ở đâu?** `make spike` so hai file log sau khi chạy xong.
`make cosim` chạy Spike song song như tiến trình con, đọc commit log qua pipe; mỗi lệnh RTL retire gọi DPI-C
`cosim_commit` và được so ngay với lệnh Spike tương ứng – lệch là dừng tại đúng lệnh đó, chưa cần chạy hết chương
trình. Kết quả 259/259 chương trình, khoảng 8,3 triệu lệnh khớp (D29).

**64. Làm sao biết co-sim thật sự bắt được lỗi?** Cài lỗi có chủ đích (`-DCOSIM_MUTANT`: SLTU lấy bit 31 thay cho bit
mượn). Co-sim dừng ở lệnh #68 của `rv32ui-p-sltu` (`sltu a4,a1,a2` với `0 < 0xffff8000`: RTL 0, Spike 1). Các
benchmark không lộ lỗi này – bằng chứng cần cả test có hướng lẫn benchmark.

**65. Thông lượng của SoC?** Ở 24 MHz trên board: 21,9 MIPS (geomean), Dhrystone 0,853 DMIPS/MHz (20,5 DMIPS),
CoreMark 2,88/MHz; ở Fmax ước lượng 44 MHz khoảng 40 MIPS. RAM qua Wishbone 4 byte/chu kỳ; thanh ghi ngoại vi 3 chu kỳ
mỗi truy cập (đo bằng `wb_checker`); UART 115200 baud ≈ 11,5 kB/s; SPI tối đa f/17 byte/s (`results/perf/throughput.md`).

## K. Layout ASIC (OpenLane / sky130)

**66. Đã làm layout chưa?** Rồi, cho hai lõi: OpenLane 2.3.10 với PDK sky130A, đi hết RTL → GDSII (tổng hợp, floorplan,
lưới nguồn, đặt cell, CTS, đi dây, trích ký sinh, STA 9 góc, DRC, LVS). Lõi pipeline: die 962 × 972 µm,
62 890 cell, diện tích cell 0,462 mm²; DRC, LVS, XOR đều 0 (D30, `make asic`).
Không làm cả SoC vì RAM 128 KB cần macro SRAM – dựng bằng flip-flop sẽ là khoảng 1 triệu flip-flop.

**67. Fmax trên ASIC?** Ràng buộc 40 MHz. Sau đi dây: 67,7 MHz ở góc TT (25 °C, 1,80 V), 87,0 MHz ở FF,
nhưng chỉ 34,6 MHz ở SS (100 °C, 1,60 V) – không đạt 40 MHz ở góc chậm. Sign-off mặc định của OpenLane chỉ
bắt buộc góc TT. Cao hơn ECP5 (44 MHz) vì cell chuẩn nhanh hơn LUT. Đường găng vẫn là forwarding → EX → PC như trên FPGA.

**68. Làm sao biết layout đúng chức năng?** LVS chứng minh layout đúng netlist; mô phỏng gate-level chứng minh netlist
đúng RTL: netlist sau đi dây chạy bằng Icarus Verilog với mô hình cell sky130, cùng testbench với RTL (Verilator).
64/64 riscv-tests (lõi pipeline) và 41/41 (single-cycle) PASS với cùng số chu kỳ và cùng chữ ký ghi bộ nhớ.

**69. Còn vi phạm gì?** 33 net vi phạm antenna, vi phạm max slew/cap ở góc TT (22/48) và nhiều hơn ở SS. Đã thử 4 cấu
hình: chèn diode ở mọi net dài sửa gần hết antenna nhưng thêm ~29 nghìn diode làm tải tăng, slew xấu đi; cấu hình cuối
chỉ chèn diode trên net dài hơn 250 µm. OpenLane báo cảnh báo, không chặn sign-off; phải sửa hết trước khi tape-out.

**70. Công suất bao nhiêu?** Ước lượng OpenSTA ở góc TT, 40 MHz: lõi pipeline khoảng 80 mW, single-cycle khoảng
7,5 mW. Đây là ước lượng với hoạt động chuyển mạch mặc định, không phải đo và không lấy từ mô phỏng
benchmark – chỉ dùng so sánh tương đối (pipeline lớn hơn ~3,3 lần về diện tích cell).

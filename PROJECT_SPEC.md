# PROJECT SPEC – Thiết kế SoC dựa trên lõi RISC-V RV32IMC pipeline 5 tầng có dự đoán rẽ nhánh, tích hợp ngoại vi truyền thông UART và SPI

| | |
|---|---|
| **Đồ án** | Đồ án Thiết kế 1 – Khoa Kỹ thuật Máy tính & Điện tử, VKU |
| **Sinh viên** | Lê Thành Danh – 23CE010 – lớp 23IC |
| **GVHD** | TS. Dương Ngọc Pháp |
| **Tên đề tài** | **Thiết kế SoC dựa trên lõi RISC-V RV32IMC pipeline 5 tầng có dự đoán rẽ nhánh, tích hợp ngoại vi truyền thông UART và SPI** |
| **Ngoại vi truyền thông** | UART và SPI Master (đúng như tên đề tài) |
| **Người thực hiện** | Claude Code (VS Code, máy ảo Linux) – tự động từ đầu đến cuối |

---

## Hướng dẫn cho sinh viên (chỉ đọc phần này)

1. Tạo một thư mục trống trong máy ảo, ví dụ `~/riscv-soc/`, rồi chép **file này** vào đó.
   Nếu còn mã Timer IP 64-bit từ Đồ án cơ sở 4, chép thêm vào `~/riscv-soc/ip/timer64_dacs4/` (không bắt buộc).
2. Trong VS Code: **File → Open Folder… → chọn `~/riscv-soc/`**, rồi mở khung chat Claude Code (biểu tượng Claude ở thanh bên hoặc góc trên bên phải editor).
   - Project sẽ chạy hàng nghìn lệnh (build, mô phỏng, git). Ở ô chọn chế độ dưới khung nhập, chọn chế độ **tự động sửa file** (auto-accept edits). Khi Claude hỏi quyền chạy một lệnh, chọn tùy chọn **cho phép luôn** cho loại lệnh đó, để không bị hỏi lại.
   - Cách nhanh hơn, dùng được vì đây là máy ảo riêng: mở Terminal trong VS Code (**Terminal → New Terminal**), `cd ~/riscv-soc`, chạy `claude --dangerously-skip-permissions`, rồi gõ câu lệnh ở bước 3 vào đó. Chế độ này không hỏi quyền nữa; **chỉ dùng trong máy ảo, không dùng trên máy thật.**
   - Trước khi bắt đầu, kiểm tra máy ảo có Internet và có sẵn `git`, `make`, `g++`, `python3`.
3. Gõ đúng một câu:
   > **Đọc PROJECT_SPEC.md và thực hiện toàn bộ project theo đúng file đó.**
4. Nếu phiên làm việc bị dừng giữa chừng (hết lượt, tắt máy, lỗi mạng), mở lại và gõ:
   > **Tiếp tục PROJECT_SPEC.md.**

   Claude sẽ đọc `PROGRESS.md` và làm tiếp từ chỗ dừng.
5. Khi xong, Claude in ra **báo cáo nghiệm thu** (mục 17). Đọc `docs/giai_thich/` và `docs/giai_thich/bao_ve_QA.md` để chuẩn bị bảo vệ.

Mọi phần bên dưới là chỉ thị cho Claude.

---

## 0. Chỉ thị vận hành cho agent (BẮT BUỘC)

### 0.1 Chế độ tự chạy

- File này dài khoảng 800 dòng. **Đọc hết từ đầu đến cuối** (dùng nhiều lần Read với `offset` nếu công cụ giới hạn độ dài) trước khi bắt đầu Phase 0.
- Thực hiện **tuần tự toàn bộ Phase 0 → Phase 8** (mục 13) trong một mạch, **không dừng lại hỏi xác nhận giữa các Phase**. Sinh viên không theo dõi liên tục.
- Chỉ dừng hẳn khi gặp **chặn cứng** không tự giải quyết được, ví dụ cần mật khẩu `sudo` để cài công cụ bắt buộc. Khi đó:
  1. Ghi vào mục `BLOCKED` của `PROGRESS.md`: thiếu gì, lệnh chính xác để sinh viên tự chạy.
  2. Làm tiếp mọi phần không phụ thuộc vào thứ bị chặn.
  3. Cuối cùng báo cho sinh viên rõ ràng.
- Khi tài liệu này thiếu chi tiết: chọn phương án **đơn giản nhất, đúng spec RISC-V, tổng hợp được**, ghi vào `docs/decisions.md` (bối cảnh – quyết định – lý do), rồi làm tiếp. Không hỏi.
- Khi tài liệu này mâu thuẫn với spec RISC-V chính thức: làm theo spec RISC-V và ghi vào `docs/decisions.md`.

### 0.2 Theo dõi tiến độ & tiếp tục sau khi gián đoạn

- Phase 0 tạo `PROGRESS.md` ở thư mục gốc với các mục: `Phase hiện tại`, `Checklist từng Phase` (tick `[x]`), `Kết quả regression gần nhất`, `BLOCKED`, `Ghi chú cho lần chạy sau`.
- Phase 0 tạo thêm `CLAUDE.md` ngắn (≤ 10 dòng) ở thư mục gốc, nội dung: "Đặc tả: `PROJECT_SPEC.md` (đọc mục 0 trước). Tiến độ: `PROGRESS.md`. Làm tiếp từ Phase chưa xong. Trả lời sinh viên bằng tiếng Việt."
- Cập nhật `PROGRESS.md` **sau mỗi mục việc hoàn thành**, không chỉ cuối Phase.
- Khi được yêu cầu "Tiếp tục": đọc `PROGRESS.md` và `git log`, chạy lại regression của các Phase đã xong để xác nhận trạng thái, rồi làm tiếp.

### 0.3 Kỷ luật kỹ thuật

1. **Phát triển tăng dần.** Không sang Phase N+1 khi Phase N chưa đạt Definition of Done (DoD). Sau mỗi Phase: chạy toàn bộ regression đã có (không chỉ test mới), rồi `git commit -m "phaseN: <tóm tắt>"`.
2. **Không bịa kết quả.** Mọi con số (CPI, số test pass, coverage, diện tích, tần số) trong `docs/` và báo cáo phải lấy từ log thật trong `results/`, kèm lệnh tái tạo. Không sửa test để ép pass, không nới tiêu chí so sánh để che lỗi. Test bị loại trừ phải ghi lý do.
3. **RTL tổng hợp được:** một clock `clk`; reset bất đồng bộ tích cực mức thấp `rst_n` (đồng bộ hóa khi nhả reset ở `soc_top`); không latch; không `initial` trong RTL (trừ nạp bộ nhớ mô phỏng trong `` `ifndef SYNTHESIS ``); không `#delay`; không `$display` trong RTL (trừ trong `` `ifndef SYNTHESIS ``).
4. **Lint sạch:** `verilator --lint-only -Wall` trên toàn RTL không còn warning. Warning cố tình bỏ qua phải có `/* verilator lint_off <ID> */` kèm comment lý do.
5. **Tập SystemVerilog dùng trong RTL:** được dùng `logic`, `always_ff`, `always_comb`, `typedef enum logic [...]`, `package` (chỉ `localparam`/`typedef`/function thuần), packed struct nội bộ module, `generate`. **Không dùng:** `interface`/`modport`, class, `inside`, `unique`/`priority`, struct trên port, assertion trong `rtl/`. Ngay Phase 1 phải chạy `yosys -p "read_verilog -sv <files>; hierarchy -top rv_core_sc"` để bắt sớm cú pháp Yosys không hỗ trợ; nếu bị chặn thì chèn bước `sv2v` vào flow tổng hợp.
6. **Ngôn ngữ:** comment code bằng tiếng Anh, ngắn gọn. Mọi file trong `docs/` và báo cáo viết bằng tiếng Việt có dấu, giữ thuật ngữ tiếng Anh khi cần.
7. **Mỗi module RTL có đủ:** header (chức năng, port, tham số), testbench tự kiểm tra, và file giải thích trong `docs/giai_thich/` (mục 15). Testbench in `PASS` rồi `$finish` khi đạt; khi lỗi hoặc timeout thì in `FAIL: <lý do>` rồi gọi `$fatal(1, ...)` để exit code ≠ 0. Script chỉ coi là PASS khi exit code = 0 **và** có chữ `PASS` trong log.
8. **Gặp bug:** viết test tái hiện nhỏ nhất, sửa, rồi thêm test đó vào regression.
9. **Git:** `git init` ở Phase 0. Nếu chưa có `user.name`/`user.email` thì cấu hình **cục bộ cho repo**: `Le Thanh Danh` / `danhlt.23ce@vku.udn.vn`. `.gitignore` loại trừ: `build/`, `*.vcd`, `*.fst`, `obj_dir/`, `.venv/`, `third_party/*/` (clone lại bằng script). Không push lên remote.
10. **Không dùng toolchain đường dẫn cứng:** Makefile dùng biến `RISCV_PREFIX` (tự dò `riscv64-unknown-elf-`, `riscv32-unknown-elf-`, `riscv-none-elf-`), `VERILATOR`, `SPIKE`, `YOSYS`.

---

## 1. Môi trường & công cụ

Phase 0 phải dò và ghi phiên bản vào `docs/env.md`:

| Công cụ | Yêu cầu | Dùng cho | Nếu thiếu |
|---|---|---|---|
| Verilator | ≥ 5.006 (`--binary --timing`) | Lint, mô phỏng chính, coverage | Chặn cứng → BLOCKED |
| RISC-V GCC + binutils | hỗ trợ `rv32i/rv32im/rv32imc`, `ilp32` | firmware, riscv-tests, benchmark | Chặn cứng |
| Spike | có `--log-commits` | Mô hình tham chiếu | Bỏ mục 10.3, ghi vào BLOCKED, phần còn lại vẫn làm |
| Yosys | ≥ 0.30 | Tổng hợp | Bỏ mục 12.2, ghi BLOCKED |
| nextpnr-ecp5/ice40, hoặc OpenSTA + liberty sky130 | tùy chọn | Ước lượng Fmax | Chỉ báo cáo số cell, ghi rõ |
| Icarus Verilog ≥ 12 | tùy chọn | Mô phỏng dự phòng | Bỏ qua |
| Python 3 + `matplotlib`, `pyelftools` | | script, biểu đồ, hình waveform | cài vào `.venv` (xem dưới) |
| pandoc | tùy chọn | xuất báo cáo `.docx` | Chỉ để markdown |
| make, git, g++ (C++17), python3 | g++ dùng để biên dịch mô hình C++ Verilator sinh ra | | Chặn cứng |

- GCC ≥ 12 yêu cầu ghi rõ `_zicsr_zifencei` trong `-march`.
- **GAS tự nén lệnh khi `-march` có `c`**, nên mọi phần mềm phải build đúng biến thể cho từng cấu hình RTL (mục 10.2, 11).
- Kiểm tra libgcc cho rv32: `$(RISCV_PREFIX)gcc -march=rv32imc_zicsr_zifencei -mabi=ilp32 -print-libgcc-file-name` phải trả về một file tồn tại. Nếu không (thường gặp với gói `gcc-riscv64-unknown-elf` của Ubuntu), xem cách xử lý ở mục 11.

**Thiếu công cụ hoặc phiên bản quá cũ → tự cài vào `~/tools` (không cần sudo) trước khi coi là chặn cứng:**
- Verilator, Yosys, Icarus, nextpnr: tải bản Linux x64 mới nhất của **OSS CAD Suite** (`https://github.com/YosysHQ/oss-cad-suite-build/releases`), giải nén vào `~/tools/oss-cad-suite`, rồi thêm `bin/` vào `PATH` trong Makefile (không sửa `~/.bashrc`).
- RISC-V GCC: tải **xPack GNU RISC-V Embedded GCC** bản Linux x64 (`https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases`) vào `~/tools/`. Bản này có sẵn multilib rv32 và libgcc.
- Spike: build từ `https://github.com/riscv-software-src/riscv-isa-sim` với `--prefix=$HOME/tools/spike`. Spike cần `dtc` (device-tree-compiler) lúc chạy; nếu thiếu `dtc` và không có sudo thì ghi BLOCKED cho mục 10.3.
- Python: tạo môi trường ảo `python3 -m venv .venv` trong project, cài `matplotlib pyelftools` vào đó. Mọi script Python chạy bằng `.venv/bin/python`. Không dùng `pip install --user`, vì Ubuntu mới chặn lệnh này (PEP 668).
- Các bước trên cần Internet; nếu không có mạng thì ghi BLOCKED.
- Ghi lại mọi thứ đã cài và đường dẫn vào `docs/env.md`.

---

## 2. Tổng quan hệ thống

```
                 +------------------------------------------------------------------+
                 |                              soc_top                             |
   clk, rst_n -->|  rst_sync                                                        |
                 |  +-----------------------------------+                           |
                 |  |              rv_core              |<-- mtip, msip, meip       |
                 |  |  IF -> ID -> EX -> MEM -> WB      |<-- mtime[63:0]            |
                 |  |  BHT/BTB   MulDiv   CSR/Trap      |                           |
                 |  +--------+-----------------+--------+                           |
                 |      ibus |            dbus |                                    |
                 |           v                 v                                    |
                 |  +-----------------+   +-----------+                             |
                 |  | ram_dp  128 KB  |<--| dbus_xbar |--+                          |
                 |  | I-port | D-port |   +-----------+  |                          |
                 |  +-----------------+          +-------v------+                   |
                 |                               |  apb_bridge  |  APB4             |
                 |                               +-------+------+                   |
                 |     +---------+---------+---------+---+-----+---------+          |
                 |     v         v         v         v         v         v          |
                 |   UART       SPI     TIMER64     GPIO      INTC    SIM_CTRL      |
                 +-----|---------|---------|---------|---------|--------------------+
                    tx/rx   sclk/mosi/  mtip/msip  gpio[15:0]  meip = |(pending & enable)
                            miso/cs_n[3:0]
```

| Khối | Mô tả |
|---|---|
| `rv_core` | RV32I + M + C + Zicsr + Zifencei + Zicntr, chỉ Machine mode, pipeline 5 tầng, predictor cấu hình được |
| `ram_dp` | RAM hợp nhất 128 KB, 2 cổng, **đọc tổ hợp, ghi đồng bộ** (lý do ở mục 5) |
| `dbus_xbar` | giải mã địa chỉ cổng dữ liệu → RAM / APB / lỗi |
| `apb_bridge` | dbus → APB4 (PSTRB, PSLVERR; PPROT = 0) |
| Ngoại vi truyền thông | **UART** và **SPI Master** – trọng tâm của đề tài, có FIFO và ngắt |
| Ngoại vi hỗ trợ | TIMER64 (nguồn ngắt định thời, tái sử dụng từ ĐACS4), GPIO 16 chân, INTC (gom ngắt), SIM_CTRL (chỉ mô phỏng) |

Phạm vi ngoại vi truyền thông của đề tài **chỉ gồm UART và SPI**. Không thiết kế thêm giao thức nào khác (I2C, CAN…); chỉ nhắc tới chúng trong mục "Hướng phát triển" của báo cáo.

---

## 3. Bản đồ bộ nhớ

| Vùng | Base | Kích thước | Ghi chú |
|---|---|---|---|
| RAM | `0x8000_0000` | 128 KB (`0x8000_0000`–`0x8001_FFFF`) | lệnh + dữ liệu; **reset PC = `0x8000_0000`** |
| UART | `0x1000_0000` | 4 KB | APB slot 0 |
| SPI | `0x1000_1000` | 4 KB | APB slot 1 |
| TIMER64 | `0x1000_2000` | 4 KB | APB slot 2 |
| GPIO | `0x1000_3000` | 4 KB | APB slot 3 |
| INTC | `0x1000_4000` | 4 KB | APB slot 4 |
| SIM_CTRL | `0x1000_F000` | 4 KB | APB slot 15 |
| Còn lại | – | – | access fault: fetch → mcause 1, load → 5, store → 7 |

- Vùng APB: `0x1000_0000`–`0x1000_FFFF`, slot = `addr[15:12]`. Slot không có slave → `PSLVERR = 1`.
- RAM đặt ở `0x8000_0000` để khớp mặc định của Spike và riscv-tests (tránh debug module/bootrom của Spike ở địa chỉ thấp).

---

## 4. Lõi xử lý `rv_core`

### 4.1 Tham số

| Parameter | Mặc định | Ý nghĩa |
|---|---|---|
| `RESET_PC` | `32'h8000_0000` | |
| `ENABLE_M` | 1 | 0 → lệnh M là illegal |
| `ENABLE_C` | 1 | 0 → lệnh 16 bit là illegal; nhảy taken tới địa chỉ có `bit[1]=1` → instruction-address-misaligned |
| `BP_MODE` | 2 | 0 = static not-taken; 1 = BHT tra ở ID; 2 = BHT + BTB tra ở IF |
| `BHT_ENTRIES` | 256 | lũy thừa của 2, ≥ 16 |
| `BTB_ENTRIES` | 32 | lũy thừa của 2, ≥ 4, direct-mapped |

`misa`: `MXL=1`, bit I, bit M nếu `ENABLE_M`, bit C nếu `ENABLE_C`. Cấu hình đầy đủ: `misa = 32'h4000_1104`.

### 4.2 Port của core

```
input  clk, rst_n
// instruction bus (combinational)
output [31:0] ibus_addr        // halfword aligned
input  [31:0] ibus_rdata       // 32 bits starting at ibus_addr
input         ibus_err
// data bus (request held until ready)
output        dbus_req, dbus_we
output [3:0]  dbus_be
output [31:0] dbus_addr, dbus_wdata   // wdata already on correct byte lanes
input         dbus_ready, dbus_err
input  [31:0] dbus_rdata              // word aligned
// interrupts & time
input         irq_mtip, irq_msip, irq_meip
input  [63:0] mtime                   // for time/timeh CSR
```

- Core giữ nguyên request cho tới chu kỳ `dbus_ready = 1`. RAM trả ready ngay trong chu kỳ request; APB có wait state.
- Load/store không căn lề → trap (mcause 4/6), không phát request.

### 4.3 Các tầng pipeline

Thanh ghi pipeline: `if_id`, `id_ex`, `ex_mem`, `mem_wb`, mỗi thanh ghi có bit `valid`. Mỗi lệnh mang theo: `pc`, `insn_raw` (16 hoặc 32 bit gốc, dùng cho trace và `mtval`), `is_c`, `pred_npc` (PC kế tiếp đã dự đoán), `exc_valid`, `exc_cause`, `exc_tval`. **Lệnh đã mang cờ ngoại lệ được coi như NOP ở các tầng sau:** không ghi thanh ghi, không khởi động MulDiv, không redirect, không cập nhật predictor, không truy cập bus.

**IF**
- `pc_q` → `ibus_addr`; `is_c = ENABLE_C && (ibus_rdata[1:0] != 2'b11)`; `seq_npc = pc_q + (is_c ? 2 : 4)`.
- `ibus_err` → gắn ngoại lệ instruction-access-fault (mcause 1, `mtval = pc`).
- `BP_MODE = 2`: tra BTB và BHT tổ hợp theo `pc_q`. Nếu BTB hit và (`type ∈ {JAL, JALR}` hoặc BHT dự đoán taken) thì `pred_npc = btb_target`, ngược lại `pred_npc = seq_npc`.
- **Chọn PC kế tiếp, ưu tiên từ cao xuống thấp:** trap/mret/fence.i từ MEM > sửa sai dự đoán từ EX > redirect từ ID > dự đoán ở IF > `seq_npc`.
- Khi stall: giữ `pc_q`.

**ID**
- `compressed_decoder` giải nén lệnh 16 bit thành lệnh 32 bit tương đương (không làm ở IF, để rút ngắn đường tổ hợp IF). Lệnh nén không hợp lệ → illegal instruction, `mtval` = 16 bit gốc.
- `decoder`, `imm_gen`, đọc `regfile` (2R1W, x0 = 0, **write-through**: WB ghi cùng chu kỳ thì ID đọc được giá trị mới).
- Redirect tại ID (flush `if_id`, tốn 1 bubble), chỉ khi `pred_npc` hiện tại khác đích mới:
  - `BP_MODE ≥ 1`: JAL → `pc + imm`.
  - `BP_MODE = 1`: branch có điều kiện, tra BHT theo `pc`; nếu taken → `pc + imm`.
  - Cập nhật `pred_npc` của lệnh theo đích mới.
- Phát hiện hazard load-use / CSR-use (mục 4.4).
- Phát hiện illegal instruction, ECALL (mcause 11), EBREAK / C.EBREAK (mcause 3, `mtval = pc`).

**EX**
- ALU, so sánh branch, tính `actual_npc` (branch: taken ? `pc+imm` : `pc+len`; JAL: `pc+imm`; JALR: `(rs1+imm) & ~1`; lệnh khác: `pc+len`, với `len = is_c ? 2 : 4`).
- **Phát hiện sai dự đoán thống nhất cho mọi mode:** lệnh hợp lệ, không mang ngoại lệ, mà `actual_npc != pred_npc` → redirect về `actual_npc`, flush `if_id` và `id_ex` (penalty 2 chu kỳ). Cách này bao được cả trường hợp BTB alias (lệnh không phải nhánh mà bị dự đoán nhảy).
- Cập nhật predictor: BHT với branch có điều kiện; BTB cấp phát/cập nhật khi lệnh nhảy taken; xóa entry khi BTB dự đoán nhảy cho lệnh không phải nhánh.
- `ENABLE_C = 0` và đích nhảy taken có `bit[1] = 1` → gắn ngoại lệ instruction-address-misaligned (mcause 0, `mtval` = đích), **không redirect**.
- Link address của JAL/JALR: `pc + len`.
- `muldiv` (mục 4.6): stall EX khi đang bận.

**MEM – điểm commit**
- `lsu`: tính byte-enable, kiểm tra căn lề, phát request lên dbus; với load thì căn và mở rộng dấu dữ liệu ngay trong MEM. `dbus_err` → access fault (mcause 5/7, `mtval` = địa chỉ).
- **CSR read-modify-write thực hiện ở MEM.**
- **Trap được xử lý tại MEM:** ngoại lệ đồng bộ của lệnh đang ở MEM, hoặc ngắt. Store và ghi CSR chỉ xảy ra khi lệnh không trap.
- `MRET`, `FENCE.I` thực hiện ở MEM: flush các tầng trẻ hơn, nạp PC mới (`mepc` hoặc `pc + len`). `FENCE`, `WFI` là NOP.

**WB**
- Ghi `regfile`, tăng `minstret`, cập nhật performance counter, in commit log (mục 10.3).

### 4.4 Hazard & forwarding (toàn bộ logic nằm trong `hazard_unit.sv` + `forward_unit.sv`)

**Quy ước thuật ngữ (dùng thống nhất trong code và tài liệu):**
- "flush X" = thanh ghi pipeline X nhận bubble (`valid = 0`) ở cạnh clock kế tiếp.
- "stall tầng S" = thanh ghi đầu vào của tầng S giữ nguyên giá trị.
- **Mọi hành động có side effect của một lệnh chỉ xảy ra đúng một lần, ở chu kỳ lệnh đó rời tầng (tầng không bị stall):** redirect từ ID/EX, cập nhật BHT/BTB, tăng performance counter, khởi động MulDiv. Ví dụ: branch ở EX trong lúc MEM đang chờ bus thì chưa được redirect; nó redirect ở chu kỳ được đi tiếp. Ngoại lệ duy nhất là trap ở MEM (xem 4.8).

- **Forward vào EX** cho rs1 và rs2, kể cả dữ liệu store:
  - từ `ex_mem`: kết quả ALU / MulDiv / link address; **không** forward load/CSR (chưa có dữ liệu);
  - từ `mem_wb`: mọi loại kết quả.
  - Ưu tiên `ex_mem` hơn `mem_wb`. Không forward khi `rd = 0`.
- **Load-use / CSR-use:** lệnh ở EX là load hoặc CSR có `rd ≠ 0` trùng `rs1`/`rs2` (đang dùng) của lệnh ở ID → stall IF và ID 1 chu kỳ, chèn bubble vào EX.
- **MulDiv bận:** stall IF, ID, EX; chèn bubble vào MEM.
- **Chờ bus** (`dbus_req && !dbus_ready` ở MEM): stall IF, ID, EX, MEM; chèn bubble vào WB.
- **Flush:**
  - trap/mret/fence.i ở MEM → flush `if_id`, `id_ex`, `ex_mem`, và lệnh ở MEM không vào WB (trừ mret/fence.i, hai lệnh này vẫn retire);
  - sai dự đoán ở EX → flush `if_id`, `id_ex`;
  - redirect ở ID → flush `if_id`.
- **Quy tắc ưu tiên:** sự kiện của tầng già hơn luôn thắng. Flush trong lúc divider đang chạy phải hủy divider.

### 4.5 Branch predictor

- **BHT:** counter bão hòa 2 bit, reset `2'b01` (weakly not-taken), chỉ số `pc[log2(BHT_ENTRIES):1]` (dùng từ bit 1 vì có lệnh 16 bit). Cập nhật tại EX cho branch có điều kiện.
- **BTB:** direct-mapped, mỗi entry `{valid, tag, target[31:1], type ∈ {BRANCH, JAL, JALR}}`; chỉ số `pc[log2(BTB_ENTRIES):1]`, tag là các bit còn lại của `pc[31:1]`. Cấp phát khi lệnh nhảy taken. JALR dự đoán bằng target lần trước.
- Bảng hiện thực bằng thanh ghi, tra cứu tổ hợp; chỉ cập nhật từ lệnh hợp lệ không bị flush.
- **Tùy chọn khi dư thời gian:** Return Address Stack 4 entry cho `ret` (`jalr x0, 0(x1)`), bật/tắt bằng parameter `ENABLE_RAS`.

### 4.6 Extension M

- `MUL`, `MULH`, `MULHSU`, `MULHU`: bộ nhân tổ hợp 33×33 có dấu trong EX, xong trong 1 chu kỳ. Critical path của bộ nhân là điểm phân tích trong báo cáo.
- `DIV`, `DIVU`, `REM`, `REMU`: bộ chia lặp radix-2, khoảng 32–34 chu kỳ, stall EX. Toán hạng được chốt khi bắt đầu chia.
- Trường hợp đặc biệt, trả kết quả ngay không lặp:
  - chia cho 0: `DIV = -1`, `DIVU = 2^32-1`, `REM` và `REMU` = số bị chia;
  - tràn `-2^31 / -1`: `DIV = -2^31`, `REM = 0`.

### 4.7 Extension C

Hỗ trợ đủ RV32C trừ lệnh dấu phẩy động (C.FLW, C.FSW, C.FLWSP, C.FSWSP, C.FLD, C.FSD, C.FLDSP, C.FSDSP → illegal):
C.ADDI4SPN, C.LW, C.SW, C.NOP, C.ADDI, C.JAL, C.LI, C.ADDI16SP, C.LUI, C.SRLI, C.SRAI, C.ANDI, C.SUB, C.XOR, C.OR, C.AND, C.J, C.BEQZ, C.BNEZ, C.SLLI, C.LWSP, C.JR, C.MV, C.EBREAK, C.JALR, C.ADD, C.SWSP.

Các encoding illegal/reserved phải bắt đúng:
- lệnh toàn bit 0;
- C.ADDI4SPN với `nzuimm = 0`;
- C.ADDI16SP với `imm = 0`;
- C.LUI với `imm = 0`;
- C.LWSP với `rd = 0`;
- C.JR với `rs1 = 0`;
- trên RV32: C.SLLI, C.SRLI, C.SRAI với `shamt[5] = 1`.

Lệnh 32 bit nằm vắt qua ranh giới word được RAM ghép sẵn (mục 5), nên IF luôn có đủ 32 bit trong 1 chu kỳ.

### 4.8 CSR, ngoại lệ, ngắt

**CSR**

| CSR | Ghi chú |
|---|---|
| `mstatus` | MIE (bit 3), MPIE (bit 7); MPP (12:11) cố định `2'b11`; các bit khác bằng 0 |
| `misa` | ghi bị bỏ qua |
| `mie`, `mip` | MEIx (11), MTIx (7), MSIx (3). `mip` phản ánh tín hiệu ngắt; ghi bị bỏ qua |
| `mtvec` | MODE 0 (direct) và 1 (vectored: ngắt nhảy tới `BASE + 4×cause`) |
| `mepc` | bit 0 luôn bằng 0; bit 1 cũng bằng 0 khi `ENABLE_C = 0` |
| `mcause`, `mtval`, `mscratch` | |
| `mvendorid`, `marchid`, `mimpid`, `mhartid` | read-only, bằng 0 |
| `mcycle(h)`, `minstret(h)` | 64 bit, ghi được |
| `cycle(h)`, `instret(h)`, `time(h)` | read-only (Zicntr); `time` đọc từ port `mtime` |
| `mcountinhibit` | bit 0 (CY) và bit 2 (IR) |
| `mhpmcounter3..10(h)` | mục 4.9; ghi bị bỏ qua là chấp nhận được |
| `mhpmevent3..10` | read-only bằng 0 (sự kiện cố định) |

- CSR không tồn tại, hoặc ghi vào CSR read-only (`csr[11:10] = 2'b11`) → illegal instruction. `CSRRS`/`CSRRC` với `rs1 = x0` và `CSRRSI`/`CSRRCI` với `uimm = 0` không tính là ghi.
- **Ưu tiên ngoại lệ đồng bộ trên một lệnh:** instruction access fault > illegal instruction > ecall/ebreak > instruction-address-misaligned > load/store misaligned > load/store access fault.
- **mcause:** 0 instr-misaligned, 1 instr-access-fault, 2 illegal, 3 breakpoint, 4 load-misaligned, 5 load-access-fault, 6 store-misaligned, 7 store-access-fault, 11 ecall-M. Ngắt: `0x8000_0003` MSI, `0x8000_0007` MTI, `0x8000_000B` MEI.
- **mtval:** địa chỉ lỗi (misaligned, access fault), bit lệnh gốc (illegal), PC (ebreak), 0 cho các trường hợp khác.
- **Điều kiện nhận ngắt:** `take_irq = mstatus.MIE && |(mip & mie) && mem_valid && !mem_exc && !mem_bus_started`.
  - Lệnh ở MEM bị hủy, `mepc` = PC của nó.
  - Ưu tiên ngắt: MEI > MSI > MTI.
  - `mem_bus_started` = thanh ghi, bằng 1 khi lệnh ở MEM đã phát request ở chu kỳ trước mà chưa nhận ready.
  - `dbus_req` phải bị chặn bởi `take_irq` trong cùng chu kỳ, để giao dịch bus không bao giờ bắt đầu cho một lệnh sắp bị hủy.
- **Vào trap:** ghi `mepc`, `mcause`, `mtval`; `MPIE ← MIE`, `MIE ← 0`; PC ← `mtvec` (hoặc vector).
- **MRET:** `MIE ← MPIE`, `MPIE ← 1`; PC ← `mepc`.

### 4.9 Performance counter (64 bit, đếm tại WB, chỉ lệnh retire thật)

| CSR | Sự kiện |
|---|---|
| `mhpmcounter3` | branch có điều kiện |
| `mhpmcounter4` | branch có điều kiện bị dự đoán sai |
| `mhpmcounter5` | JAL/JALR |
| `mhpmcounter6` | JAL/JALR bị dự đoán sai |
| `mhpmcounter7` | chu kỳ stall load-use/CSR-use |
| `mhpmcounter8` | chu kỳ stall MulDiv |
| `mhpmcounter9` | chu kỳ chờ bus |
| `mhpmcounter10` | lệnh nén đã retire |

Các bộ đếm chu kỳ stall đếm theo chu kỳ trong `hazard_unit`. Testbench in toàn bộ counter (qua tham chiếu phân cấp) khi kết thúc mô phỏng.

---

## 5. Bộ nhớ `ram_dp`

- Mảng word 32 bit, `DEPTH = 32768` (128 KB), base `0x8000_0000`.
- **Cổng I (đọc tổ hợp):**
  - `addr[1] = 0` → `word[i]`;
  - `addr[1] = 1` → `{word[i+1][15:0], word[i][31:16]}`;
  - nửa trên vượt khỏi RAM thì trả 0;
  - `ibus_err = 1` khi địa chỉ ngoài vùng RAM.
- **Cổng D:** đọc tổ hợp, ghi đồng bộ theo byte-enable, `ready = 1` ngay khi có request.
- Mô phỏng: trong `` `ifndef SYNTHESIS ``, nạp `$readmemh` từ plusarg `+hex=<file>` (mỗi dòng 1 word; dòng đầu tiên ứng với `0x8000_0000`).
- Tổng hợp: RAM là blackbox; báo cáo diện tích không tính RAM và ghi rõ điều này.
- **Lý do chọn đọc tổ hợp (ghi vào báo cáo):** đọc được 32 bit tại địa chỉ căn lề 2 byte trong 1 chu kỳ, nên extension C không cần prefetch buffer và IF dự đoán được ngay trong cùng chu kỳ. Ánh xạ thực tế: LUTRAM trên FPGA. Hướng phát triển: SRAM/BRAM đồng bộ + prefetch buffer.

---

## 6. Bus

**`dbus_xbar`**
- Địa chỉ trong RAM → RAM.
- `0x1000_0000`–`0x1000_FFFF` → `apb_bridge`.
- Còn lại → trả `ready = 1, err = 1` ngay trong chu kỳ đó.

**`apb_bridge` (APB4)**
- FSM: `IDLE → SETUP (PSEL=1, PENABLE=0) → ACCESS (PENABLE=1, chờ PREADY) → IDLE`.
- Chốt `PADDR`, `PWRITE`, `PWDATA`, `PSTRB` (với read: `PSTRB = 0`) khi vào SETUP.
- Ở chu kỳ ACCESS có `PREADY = 1`: trả `dbus_ready = 1`, `dbus_rdata = PRDATA`, `dbus_err = PSLVERR`.
- `PSEL` theo slot `addr[15:12]`; slot không có slave thì bridge tự trả `PREADY = 1, PSLVERR = 1`.

**Quy ước cho slave APB**
- Thanh ghi RW ghi theo `PSTRB`.
- Thanh ghi kiểu "push" (DATA) đẩy dữ liệu khi `PSTRB[0] = 1`.
- Đọc có side effect (pop FIFO) xảy ra đúng 1 lần, tại chu kỳ ACCESS.
- `PREADY = 1` (không wait state) trừ khi có lý do riêng; offset không định nghĩa → `PSLVERR = 1`.

---

## 7. Hệ thống ngắt

- `irq_mtip`, `irq_msip` lấy từ TIMER64; `irq_meip = |(INTC.PENDING & INTC.ENABLE)`.
- Nguồn INTC (theo mức): bit 0 UART, bit 1 SPI, bit 2 GPIO.
- Firmware: ISR external đọc `INTC.ACTIVE` → gọi handler từng ngoại vi → handler xóa nguồn ngắt tại ngoại vi.

---

## 8. Ngoại vi – register map

Offset tính theo byte, thanh ghi 32 bit. "W1C" = ghi 1 để xóa. Bit không định nghĩa đọc ra 0, ghi bị bỏ qua.

### 8.1 `sync_fifo` dùng chung

Parameter `WIDTH`, `DEPTH` (mặc định 16, lũy thừa của 2). Tín hiệu `push`, `pop`, `wdata`, `rdata` (first-word-fall-through), `full`, `empty`, `level`. Push khi đầy → bỏ qua; pop khi rỗng → bỏ qua. Cho phép push và pop đồng thời.

### 8.2 UART – `0x1000_0000`

8 bit dữ liệu, LSB trước, parity tùy chọn, 1 hoặc 2 stop bit. RX: đồng bộ 2 flip-flop, lấy mẫu ×16, kiểm tra lại start bit ở giữa bit (start giả thì bỏ), lấy mẫu dữ liệu ở giữa bit.

| Off | Tên | Truy cập | Mô tả |
|---|---|---|---|
| 0x00 | DATA | W / R | W: đẩy `[7:0]` vào TX FIFO. R: `[7:0]` dữ liệu RX, `[31]` = RX_EMPTY; pop nếu không rỗng |
| 0x04 | STATUS | RO | [0] TX_FULL, [1] TX_EMPTY, [2] TX_IDLE (FIFO rỗng và shifter rảnh), [3] RX_EMPTY, [4] RX_FULL, [5] RX_OVERRUN, [6] FRAME_ERR, [7] PARITY_ERR, [12:8] TX_LEVEL, [20:16] RX_LEVEL |
| 0x08 | CTRL | RW | [0] TX_EN, [1] RX_EN, [2] PARITY_EN, [3] PARITY_ODD, [4] STOP2. Reset `0x3` |
| 0x0C | BAUD_DIV | RW | [15:0]: 1 bit = 16×(DIV+1) chu kỳ clock. Reset 26 (≈ 115200 baud @ 50 MHz) |
| 0x10 | IRQ_EN | RW | [0] TX_WM, [1] RX_WM, [2] ERR |
| 0x14 | IRQ_STATUS | R / W1C | [0] TX_WM = (TX_LEVEL ≤ TX_WM_LVL), mức, RO; [1] RX_WM = (RX_LEVEL ≥ RX_WM_LVL), mức, RO; [2] ERR sticky, W1C (xóa luôn STATUS[7:5]) |
| 0x18 | WATERMARK | RW | [4:0] TX_WM_LVL (reset 0), [20:16] RX_WM_LVL (reset 1) |

`irq = |(IRQ_STATUS[2:0] & IRQ_EN[2:0])`. Port: `uart_tx` (idle = 1), `uart_rx`.

### 8.3 SPI Master – `0x1000_1000`

Full-duplex, 8 bit/khung, đủ 4 mode, MSB-first hoặc LSB-first, CS điều khiển bằng phần mềm. Mỗi byte lấy từ TX FIFO được truyền đi; byte nhận về đẩy vào RX FIFO (RX FIFO đầy → bỏ byte và set OVERRUN).

- **CPHA = 0:** bit đầu tiên đặt lên MOSI trước cạnh SCLK đầu tiên; lấy mẫu MISO ở cạnh leading, đổi MOSI ở cạnh trailing.
- **CPHA = 1:** đổi MOSI ở cạnh leading, lấy mẫu ở cạnh trailing.
- **CPOL:** mức nghỉ của SCLK.

| Off | Tên | Truy cập | Mô tả |
|---|---|---|---|
| 0x00 | DATA | W / R | W: đẩy vào TX FIFO. R: `[7:0]` dữ liệu RX, `[31]` RX_EMPTY; pop |
| 0x04 | STATUS | RO | [0] TX_FULL, [1] TX_EMPTY, [2] RX_EMPTY, [3] RX_FULL, [4] BUSY, [5] RX_OVERRUN, [12:8] TX_LEVEL, [20:16] RX_LEVEL |
| 0x08 | CTRL | RW | [0] EN, [1] CPOL, [2] CPHA, [3] LSB_FIRST. Reset 0 |
| 0x0C | CLK_DIV | RW | [15:0]: f_SCLK = f_clk / (2×(DIV+1)). Reset 3 |
| 0x10 | CS | RW | [3:0] CS_N, tích cực mức thấp. Reset `0xF` |
| 0x14 | IRQ_EN | RW | [0] TX_EMPTY, [1] RX_NOT_EMPTY, [2] DONE, [3] OVERRUN |
| 0x18 | IRQ_STATUS | R / W1C | [0], [1]: mức (RO); [2] DONE sticky (set khi byte cuối truyền xong và TX FIFO rỗng), W1C; [3] OVERRUN sticky, W1C (xóa luôn STATUS[5]) |

Port: `spi_sclk`, `spi_mosi`, `spi_miso`, `spi_cs_n[3:0]`.

### 8.4 TIMER64 – `0x1000_2000`

> **Tái sử dụng IP từ ĐACS4:** nếu `ip/timer64_dacs4/` tồn tại và có mã nguồn, đọc toàn bộ, viết wrapper `rtl/periph/timer/timer64_apb.sv` sao cho IP tạo được `mtip`, `msip`, `mtime[63:0]` đúng ngữ nghĩa dưới đây; cập nhật bảng này theo register map thật của IP và ghi vào `docs/decisions.md`. Nếu không có, tự hiện thực theo bảng.

| Off | Tên | Truy cập | Mô tả |
|---|---|---|---|
| 0x00 | MTIME_LO | RW | |
| 0x04 | MTIME_HI | RW | |
| 0x08 | MTIMECMP_LO | RW | reset `0xFFFF_FFFF` |
| 0x0C | MTIMECMP_HI | RW | reset `0xFFFF_FFFF` |
| 0x10 | CTRL | RW | [0] EN (reset 1), [15:8] PRESCALE (reset 0): mtime tăng 1 sau mỗi PRESCALE+1 chu kỳ |
| 0x14 | MSIP | RW | [0] → `msip` |

`mtip = (mtime >= mtimecmp)`, theo mức. Driver đọc 64 bit bằng vòng hi–lo–hi; ghi mtimecmp theo trình tự trong Privileged spec để tránh ngắt giả.

### 8.5 GPIO – `0x1000_3000`, 16 chân

| Off | Tên | Truy cập | Mô tả |
|---|---|---|---|
| 0x00 | OUT | RW | |
| 0x04 | IN | RO | đã đồng bộ 2 flip-flop |
| 0x08 | DIR | RW | 1 = output, reset 0 |
| 0x0C | IRQ_EN | RW | theo từng chân |
| 0x10 | IRQ_STATUS | R / W1C | cờ cạnh sticky |
| 0x14 | IRQ_TYPE | RW | 0 = cạnh lên, 1 = cạnh xuống |

Port: `gpio_i[15:0]`, `gpio_o[15:0]`, `gpio_oe[15:0]` (tri-state nằm ngoài `soc_top`).

### 8.6 INTC – `0x1000_4000`

| Off | Tên | Truy cập | Mô tả |
|---|---|---|---|
| 0x00 | PENDING | RO | mức ngắt thô |
| 0x04 | ENABLE | RW | reset 0 |
| 0x08 | ACTIVE | RO | PENDING & ENABLE |

### 8.7 SIM_CTRL – `0x1000_F000` (chỉ mô phỏng)

| Off | Tên | Mô tả |
|---|---|---|
| 0x00 | PUTCHAR | W: in `[7:0]` ra stdout và file `+console=<file>` |
| 0x04 | EXIT | W: kết thúc mô phỏng; 0 → in `PASS` rồi `$finish`; khác 0 → in `FAIL: exit code N` rồi `$fatal(1)` |

Trong `` `ifndef SYNTHESIS `` module dùng `$write`/`$finish`/`$fatal`; khi tổng hợp là thanh ghi giả. Testbench xử lý `tohost` theo cùng quy tắc: `code = value >> 1`; 0 là PASS, khác 0 là FAIL.

---

## 9. Top-level `soc_top`

```
module soc_top #(parameter ENABLE_M=1, ENABLE_C=1, BP_MODE=2, BHT_ENTRIES=256, BTB_ENTRIES=32) (
  input  clk, rst_n,
  output uart_tx,  input uart_rx,
  output spi_sclk, output spi_mosi, input spi_miso, output [3:0] spi_cs_n,
  input  [15:0] gpio_i, output [15:0] gpio_o, output [15:0] gpio_oe
);
```

`rst_sync` (bật bất đồng bộ, nhả đồng bộ 2 flip-flop) → `rv_core`, `ram_dp`, `dbus_xbar`, `apb_bridge`, các slave APB, INTC. Tham số được truyền xuống core.

- Thêm parameter `CORE_SC` (mặc định 0). `CORE_SC = 1` thay `rv_core` bằng core single-cycle `rv_core_sc`; core này có **đúng cùng danh sách port** với `rv_core` (mục 4.2), stall cả core khi `dbus_ready = 0`, và cũng in commit log.
- `soc_top` được xây **tăng dần**: Phase 1 chỉ có core, RAM, `dbus_xbar`, `apb_bridge`, SIM_CTRL; các ngoại vi khác được gắn vào ở Phase 6–7. Slot chưa có slave trả `PSLVERR`.
- Dùng **một testbench top duy nhất** `tb/soc/tb_soc.sv` cho cả riscv-tests, benchmark và system test. `tb_soc` có đủ parameter của `soc_top` để đổi cấu hình bằng `-G`.
- Mỗi cấu hình RTL chỉ build Verilator **một lần** (thư mục `build/<config>/`). Các test chạy lại cùng file thực thi đó với `+hex=` khác nhau.

---

## 10. Xác minh

### 10.1 Mức khối – `tb/unit/`

- Testbench SystemVerilog tự kiểm tra, chạy bằng `verilator --binary --timing` (dự phòng: `iverilog -g2012`).
- Mỗi testbench có cả test có hướng lẫn ngẫu nhiên có seed (`+seed=`, seed được in ra log).
- `make unit` chạy tất cả và in bảng tổng kết.

| Testbench | Nội dung tối thiểu |
|---|---|
| `tb_alu` | so với mô hình trong TB, ≥ 10.000 vector ngẫu nhiên + giá trị biên |
| `tb_muldiv` | 8 phép; biên 0, −1, INT_MIN, chia 0, tràn; ngẫu nhiên; abort giữa chừng |
| `tb_compressed_decoder` | mọi lệnh RV32C so với bảng kỳ vọng, sinh tự động bằng cách assemble cùng lệnh với `.option rvc`/`.option norvc` rồi so `objdump`; mọi encoding illegal |
| `tb_regfile` | write-through, x0 |
| `tb_bp` | BHT bão hòa; BTB hit/miss/alias/thay thế |
| `tb_csr` | read/write/set/clear, read-only → illegal, trap entry/mret |
| `tb_fifo` | full/empty/level, push+pop đồng thời |
| `tb_apb_bridge` | slave có wait state, PSLVERR, slot trống |
| `tb_uart` | loopback; mọi tổ hợp parity/stop; frame error; overrun; ngắt watermark |
| `tb_spi` | 4 mode × MSB/LSB × ít nhất 3 CLK_DIV, so với `spi_slave_bfm`; DONE/overrun |
| `tb_timer`, `tb_gpio`, `tb_intc` | đầy đủ thanh ghi và ngắt |

BFM trong `tb/bfm/`:
- `apb_master_bfm.sv`: task `apb_write`, `apb_read`.
- `uart_bfm.sv`: giải mã TX → log + so với file kỳ vọng; task gửi byte vào RX; cấu hình baud/parity/stop.
- `spi_slave_bfm.sv`: slave đủ 4 mode, trả về một pattern định trước, ghi lại byte nhận được.
- `spi_flash_bfm.sv`: flash kiểu W25Q rút gọn, chạy mode 0 và 3, gồm `0x9F` JEDEC ID (`EF 40 16`), `0x03` READ, `0x06` WREN, `0x04` WRDI, `0x02` PAGE PROGRAM (256 B, cần WREN), `0x05` RDSR (bit WIP/WEL), `0x20` SECTOR ERASE (4 KB).

### 10.2 Mức lõi – riscv-tests

- `scripts/fetch_third_party.sh` clone `https://github.com/riscv-software-src/riscv-tests` (có `--recursive`) và `https://github.com/eembc/coremark` vào `third_party/`; ghi commit hash vào `docs/env.md`.
- **Env riêng** `sw/riscv-tests-env/p/riscv_test.h` + `link.ld` (env mặc định chuyển sang U-mode và đụng các CSR không có):
  - Định nghĩa `RVTEST_RV32U`, `RVTEST_RV64U`, `RVTEST_RV32M`, `RVTEST_RV64M`, `RVTEST_CODE_BEGIN/END`, `RVTEST_DATA_BEGIN/END`, `RVTEST_PASS`, `RVTEST_FAIL`, `TESTNUM` (= `gp`).
  - Trước khi viết env, chạy `grep -rhoE 'RVTEST_[A-Z0-9_]+' third_party/riscv-tests/isa/rv{32,64}{ui,um,uc,mi}` để liệt kê **mọi** macro mà các test dùng, rồi định nghĩa đủ. Macro dành cho S/U-mode (ví dụ `RVTEST_RV64S`) được định nghĩa để test vẫn biên dịch được; test nào thật sự cần S/U-mode thì loại trừ theo quy tắc dưới.
  - Lấy `env/p/riscv_test.h` gốc làm mẫu và giữ nguyên cấu trúc `_start → reset_vector`, `trap_vector`. Chỉ bỏ phần chuyển mode, PMP, `satp`, `medeleg`/`mideleg`.
  - Chạy hoàn toàn ở M-mode. Khởi tạo tối thiểu: xóa các thanh ghi, đặt `mtvec` → `trap_vector` của env. `trap_vector` gọi `mtvec_handler` (weak symbol) nếu test có định nghĩa; nếu không có thì báo FAIL.
  - `RVTEST_PASS`/`RVTEST_FAIL`: `fence`, rồi ghi `(code<<1)|1` vào `tohost` (pass: code = 0; fail: code = TESTNUM), rồi lặp vô hạn.
  - `tohost`/`fromhost` nằm trong section `.tohost` (căn 64 byte) trong RAM. Script lấy địa chỉ bằng `nm`, truyền `+tohost=<addr>`; testbench theo dõi lệnh ghi dbus tới địa chỉ đó.
  - Include path theo thứ tự: `sw/riscv-tests-env/p`, `third_party/riscv-tests/env`, `third_party/riscv-tests/isa/macros/scalar`.
- **Biến thể build** (do GAS tự nén lệnh):

  | Biến thể ELF | `-march` | Bộ test |
  |---|---|---|
  | `i` | `rv32i_zicsr_zifencei` | rv32ui, rv32mi |
  | `im` | `rv32im_zicsr_zifencei` | rv32ui, rv32um, rv32mi |
  | `imc` | `rv32imc_zicsr_zifencei` | rv32ui, rv32um, rv32uc, rv32mi |

- **Ma trận cấu hình phải pass:**

  | RTL | ELF |
  |---|---|
  | `ENABLE_M=1, ENABLE_C=1`, `BP_MODE ∈ {0,1,2}` | `imc` |
  | `ENABLE_M=1, ENABLE_C=0`, `BP_MODE=2` | `im` |
  | `ENABLE_M=0, ENABLE_C=0`, `BP_MODE=2` | `i` |
  | core single-cycle | `i` (chỉ rv32ui) |

- **Được phép loại trừ, phải ghi lý do trong `docs/results.md`:**
  - `rv32ui-p-ma_data`: core trap khi truy cập không căn lề. Điều này hợp lệ theo spec, và hành vi trap đã được kiểm qua `rv32mi-p-ma_addr`.
  - Các test rv32mi cần U/S-mode, PMP, hoặc debug trigger. Trước khi loại trừ phải đọc mã nguồn test và chỉ ra đúng dòng phụ thuộc.
- Timeout `+max_cycles` (mặc định 2.000.000) → FAIL.
- `scripts/run_isa.py`: build + chạy + xuất `results/isa/<config>.csv` và bảng markdown.

### 10.3 So sánh với Spike

- RTL in commit log tại WB khi có `+commitlog=<file>`, mỗi lệnh retire 1 dòng: `pc`, `insn` (16 bit với lệnh nén, 32 bit với lệnh thường), `rd` và giá trị ghi (nếu `rd ≠ 0`), địa chỉ và dữ liệu store (nếu có). Định dạng gần với `spike --log-commits`.
- Spike: `spike --isa=rv32imc_zicsr_zifencei --priv=m -m0x80000000:0x20000,0x1000F000:0x1000 --log-commits <elf>` (dùng ISA khớp với biến thể ELF; `--priv=m` để Spike cũng chỉ có Machine mode). Bỏ qua các lệnh của bootrom Spike (`pc < 0x8000_0000`).
- Nếu bản Spike không có `--log-commits`, dùng `-l` (chỉ có PC và lệnh) và so khớp chuỗi PC + mã lệnh. Ghi rõ mức so sánh đã dùng vào `docs/results.md`.
- Các khác biệt đã biết trước, cần liệt kê trong báo cáo: giá trị `misa`, `marchid`, `mimpid` đọc ra; hành vi truy cập không căn lề nếu Spike tự xử lý thay vì trap.
- `scripts/compare_spike.py` so khớp từng lệnh bằng regex, không so text thô; che giá trị đọc từ `cycle`, `mcycle`, `instret`, `minstret`, `time`, `mhpmcounter*`. Mọi khác biệt do hành vi tùy hiện thực phải được liệt kê, không che giấu.
- Áp dụng cho toàn bộ riscv-tests và các benchmark chạy `CONSOLE=sim`.

### 10.4 Mức hệ thống – firmware C (`sw/tests/`)

Testbench top `tb/soc/tb_soc.sv`:
- clock 50 MHz danh định, reset, nạp hex;
- `uart_bfm` gắn vào `uart_tx/uart_rx`; `spi_flash_bfm` ở `cs_n[0]`; `spi_slave_bfm` ở `cs_n[1]`; MISO ghép theo CS; TB điều khiển `gpio_i`;
- kết thúc khi gặp SIM_CTRL EXIT, `tohost`, hoặc timeout;
- plusargs: `+hex=`, `+tohost=`, `+max_cycles=`, `+trace` (FST), `+commitlog=`, `+console=`, `+uart_expect=`, `+uart_rx_file=` (dữ liệu BFM gửi vào RX).

Trong system test, UART dùng `BAUD_DIV = 0` để mô phỏng nhanh (16 chu kỳ/bit); `demo` dùng giá trị thật.

| Test | Tiêu chí PASS |
|---|---|
| `hello` | UART BFM nhận đúng chuỗi trong file kỳ vọng |
| `uart_irq_echo` | BFM gửi chuỗi; ISR RX echo lại bằng ngắt; khớp hoàn toàn; kiểm tra cờ overrun |
| `spi_flash` | đọc JEDEC ID đúng; erase → program page → đọc lại khớp; chờ WIP; dùng ngắt DONE |
| `spi_modes` | 4 mode × MSB/LSB với `spi_slave_bfm`, dữ liệu hai chiều khớp |
| `timer_irq` | N ngắt định kỳ, khoảng cách đúng theo mtime |
| `gpio_irq` | xuất pattern ra output; ngắt cạnh lên/xuống từ TB |
| `irq_priority` | MEI, MSI, MTI cùng pending → phục vụ đúng thứ tự ưu tiên; chạy cả mtvec direct và vectored |
| `exceptions` | illegal, ecall, ebreak, load/store misaligned, access fault → trap handler C ghi nhận đúng `mcause`/`mepc`/`mtval`, nhảy qua lệnh lỗi, quay lại |
| `irq_during_div` | ngắt đến khi DIV đang chạy → kết quả DIV vẫn đúng sau khi quay lại |
| `demo` | kịch bản trình diễn: Timer ngắt mỗi chu kỳ T → đọc 16 byte từ SPI flash → in ra UART dạng hex; ngắt RX nhận lệnh `r`/`w`/`s` (đọc / ghi flash / in performance counter); TB gửi chuỗi lệnh và kiểm tra output |

`scripts/run_systest.py` chạy tất cả và xuất `results/systest/summary.md`.

### 10.5 Coverage

- **Code coverage:** build với `--coverage-line --coverage-toggle`, gộp mọi lần chạy (unit + isa + systest) bằng `verilator_coverage --write-info`, xuất `results/coverage/summary.md` theo module (và HTML bằng `genhtml` nếu có).
  - Mục tiêu: line coverage ≥ 90% cho `rtl/core` và `rtl/periph`.
  - Phần chưa phủ phải liệt kê và giải thích.
- **Functional coverage:** viết `cover property` trong `tb/cov/` và gắn bằng `bind` (cần `--coverage-user`). Tối thiểu gồm:
  - từng nhóm opcode retire, từng lệnh M, lệnh nén;
  - 4 đường forwarding (EX/MEM → rs1/rs2, MEM/WB → rs1/rs2);
  - load-use stall, CSR-use stall, MulDiv stall, chờ bus;
  - sai dự đoán theo loại (branch, JAL, JALR, BTB alias), BTB hit/miss/replace;
  - từng giá trị `mcause`; ngắt khi divider đang chạy; trap ngay sau branch bị dự đoán sai; lệnh 32 bit vắt qua ranh giới word;
  - từng mode SPI; UART parity/stop; FIFO đầy/rỗng của mọi FIFO.

  `scripts/cov_report.py` in bảng điểm cover đạt/chưa đạt.

---

## 11. Phần mềm (`sw/`)

- `sw/common/`:
  - `crt0.S`: đặt `sp`, `gp`; xóa `.bss`; cài `mtvec`; gọi `main`; truyền giá trị trả về cho `exit`.
  - `exit(code)`: ghi SIM_CTRL EXIT, **sau đó** ghi `(code<<1)|1` vào `tohost` (để Spike cũng dừng), rồi lặp vô hạn.
  - `link.ld`: RAM 128 KB tại `0x8000_0000`, `.text` bắt đầu bằng `_start`, có section `.tohost` chứa cả hai symbol `tohost` và `fromhost` (Spike cần cả hai), stack 8 KB ở đỉnh RAM.
  - `trap_entry.S`: lưu/khôi phục `ra`, `t0–t6`, `a0–a7`, gọi `void trap_handler(uint32_t mcause, uint32_t mepc, uint32_t mtval)`; bảng vector cho mode vectored.
  - `platform.h` (địa chỉ, macro thanh ghi), `csr.h` (inline asm), `perf.h` (đọc mcycle/minstret/mhpm 64 bit).
  - `xprintf.c/.h`: `printf` tối giản (`%d %u %x %s %c %%`, độ rộng, pad 0).
  - `libc_min.c`: `memcpy`, `memset`, `memmove`, `memcmp`, `strcpy`, `strcmp`, `strlen` (GCC có thể tự sinh lời gọi tới các hàm này).
- `sw/drivers/`: `uart`, `spi`, `timer`, `gpio`, `intc`, mỗi driver có API polling và API dùng ngắt.
- Cờ build mặc định: `-march=rv32imc_zicsr_zifencei -mabi=ilp32 -O2 -g -ffreestanding -nostdlib -nostartfiles`, link `-lgcc`.
- **Nếu không có libgcc rv32** (mục 1): ưu tiên cài xPack GCC; nếu không cài được thì viết `sw/common/libgcc_min.c` gồm `__udivdi3`, `__umoddi3`, `__divdi3`, `__moddi3` (chia 64 bit, dùng khi tính CPI từ counter 64 bit) và `__mulsi3`, `__divsi3`, `__udivsi3`, `__modsi3`, `__umodsi3` (cho biến thể không có M), rồi link file này thay cho `-lgcc`. Ghi quyết định vào `docs/decisions.md`.
- Firmware không dùng số thực. In CPI dạng số nguyên ×1000 (ví dụ `CPI = 1.234` in từ `cycles*1000/instret`).
- `CONSOLE=uart` (mặc định, đi qua UART thật + BFM) hoặc `CONSOLE=sim` (SIM_CTRL PUTCHAR, dùng cho benchmark và so sánh với Spike).
- `scripts/elf2hex.py`: ELF → hex 32 bit/dòng cho `$readmemh` (dòng đầu tiên ứng với `0x8000_0000`, lấp 0 các khoảng trống); lấy địa chỉ `tohost`.

**Benchmark (`sw/benchmarks/`)**
- Từ `riscv-tests/benchmarks`: `dhrystone`, `median`, `multiply`, `qsort`, `rsort`, `towers`, `vvadd`, `memcpy`. **Không dùng** các benchmark có số thực (`spmv`, `mm`…) vì core không có extension F. Port phần `common/crt.S` + `syscalls.c` sang `crt0` + `xprintf` + SIM_CTRL, bỏ HTIF và phần đa nhân (multi-hart).
- CoreMark: port `core_portme` (dùng `mcycle`), `ITERATIONS` nhỏ (1–10) để mô phỏng trong vài phút. Nếu chạy ổn, có thể tăng iteration.
- Mỗi benchmark in: cycles, instret, CPI, số branch, số dự đoán sai, độ chính xác dự đoán, các loại stall (đọc từ mhpm).

---

## 12. Đánh giá hiệu năng & tổng hợp

### 12.1 Thí nghiệm – `scripts/run_perf.py`

Build RTL với `-G<param>`, chạy mọi benchmark, xuất `results/perf/*.csv`, bảng markdown và biểu đồ PNG (matplotlib, có nhãn trục, đơn vị, chú thích):

1. **Predictor:** `BP_MODE ∈ {0,1,2}` × mọi benchmark → cycles, CPI, độ chính xác dự đoán, số chu kỳ penalty.
2. **Quét kích thước:** `BHT_ENTRIES ∈ {16, 64, 256, 1024}` × `BTB_ENTRIES ∈ {8, 16, 32, 64}` (ở `BP_MODE=2`) → độ chính xác và CPI theo diện tích (kết hợp 12.2).
3. **Extension C:** kích thước `.text` (`size`) và CPI của ELF `rv32im` so với `rv32imc`, cho từng benchmark.
4. **Phân rã CPI:** phần chu kỳ mất do load-use, MulDiv, bus, sai dự đoán.
5. **Single-cycle so với pipeline:** CPI và Fmax → hiệu năng ∝ Fmax / CPI.

Kiểm tra hợp lý: CPI của pipeline với Dhrystone phải nằm trong khoảng 1.0–2.0, và `BP_MODE=2` phải không tệ hơn `BP_MODE=0`. Nếu sai, điều tra và sửa trước khi báo cáo.

### 12.2 Tổng hợp – `syn/`

- `syn/synth_generic.ys`: `synth -top rv_core -flatten` (RAM blackbox) → thống kê cell; lặp lại cho `rv_core_sc`, cho từng ngoại vi, và cho `soc_top` (không tính RAM). Đổi cấu hình bằng `chparam`, áp dụng cho các cấu hình ở 12.1.
- Ước lượng tần số, chọn một trong hai cách có sẵn trong VM và ghi lại cách đã chọn:
  - (a) `synth_ecp5` hoặc `synth_ice40` + `nextpnr` → Fmax, LUT/FF;
  - (b) liberty sky130 (`dfflibmap` + `abc -liberty`) + OpenSTA → critical path.
- `scripts/synth_report.py` → `results/synth/summary.md`: bảng diện tích theo cấu hình, Fmax, mô tả critical path (dự kiến nằm ở bộ nhân hoặc chuỗi forwarding → ALU → so sánh branch → chọn PC).
- Báo cáo ghi rõ: không làm place & route ASIC (ngoài phạm vi); nếu dùng nextpnr thì Fmax chỉ là ước lượng trên FPGA.

---

## 13. Các Phase & Definition of Done

Cột "Mốc đề cương" chỉ để đối chiếu với tiến độ đã nộp; agent làm liên tục, không chờ theo ngày.

| Phase | Mốc đề cương | Nội dung | Definition of Done |
|---|---|---|---|
| **0** | 12–18/10 | Dò môi trường; `git init`; `PROGRESS.md`, `CLAUDE.md`, `.gitignore`; khung thư mục (mục 14); Makefile; `fetch_third_party.sh`; `elf2hex.py`; `docs/spec.md`, `memory_map.md`, `register_map.md` | `make check-env` in đủ phiên bản; `docs/env.md` có hash third_party; commit |
| **1** | 19–25/10 | Core RV32I single-cycle `rv_core_sc` (dùng chung `decoder`/`alu`/`regfile`, `csr_file` tối thiểu); `ram_dp`; `dbus_xbar` + `apb_bridge` bản cơ bản; SIM_CTRL; `soc_top` tối thiểu (`CORE_SC=1`); `tb_soc`; env riscv-tests; `run_isa.py`; `compare_spike.py`; thử Yosys | rv32ui pass trên single-cycle; khớp Spike; chương trình C nhỏ in chữ qua SIM_CTRL PUTCHAR; Yosys đọc được RTL |
| **2** | 26/10–01/11 | Pipeline 5 tầng RV32I, forwarding, hazard, `BP_MODE=0`, Zicsr cơ bản, FENCE.I, commit log | rv32ui pass; khớp Spike; `tb_regfile`, `tb_alu` pass; lint sạch |
| **3** | 02–08/11 | Extension M và C | rv32um, rv32uc pass; ma trận ENABLE_M/ENABLE_C pass; `tb_muldiv`, `tb_compressed_decoder` pass |
| **4** | 09–15/11 | BHT, BTB, `BP_MODE` 1/2, performance counter; port Dhrystone | mọi riscv-tests pass ở BP_MODE 0/1/2; `tb_bp` pass; Dhrystone chạy, khớp Spike, in CPI |
| **5** | 16–22/11 | CSR đầy đủ, trap/ngắt, mtvec vectored; hoàn thiện `dbus_xbar`, `apb_bridge` (wait state, PSLVERR, access fault); INTC | rv32mi pass (trừ loại trừ có lý do); `tb_csr`, `tb_apb_bridge`, `tb_intc` pass |
| **6** | 23/11–06/12 | `sync_fifo`, UART, SPI, TIMER64, GPIO, mọi BFM | mọi unit TB ngoại vi pass |
| **7** | 07–20/12 | `soc_top`, driver, mọi system test, `demo`, benchmark, `run_perf.py`, coverage, tổng hợp | mọi test ở 10.4 pass; `results/perf`, `results/coverage`, `results/synth` đầy đủ; `docs/results.md` hoàn chỉnh |
| **8** | 21–27/12 | `docs/giai_thich/` (mục 15), báo cáo (mục 16), hình, `docs/compliance.md`, dọn repo | mục 17 đạt toàn bộ |
| (opt) | – | RAS, CoreMark nhiều iteration | không làm ảnh hưởng DoD của các Phase khác |

**Makefile tối thiểu:** `check-env`, `fetch`, `lint`, `unit`, `sw`, `isa`, `spike`, `systest`, `perf`, `cov`, `synth`, `docs`, `regress`, `clean`.
`make regress` = lint + unit + isa (cả ma trận) + spike + systest; chạy bằng 1 lệnh, in bảng PASS/FAIL, trả exit code ≠ 0 nếu có lỗi.

---

## 14. Cấu trúc thư mục

Thư mục gốc project là **thư mục chứa file này**.

```
./
├── PROJECT_SPEC.md          # file này (không sửa, trừ khi sinh viên yêu cầu)
├── CLAUDE.md, PROGRESS.md, README.md, Makefile, .gitignore
├── rtl/
│   ├── pkg/      rv_pkg.sv, soc_pkg.sv
│   ├── core/     rv_core.sv, if_stage.sv, id_stage.sv, ex_stage.sv, mem_stage.sv, wb_stage.sv,
│   │             regfile.sv, decoder.sv, imm_gen.sv, compressed_decoder.sv, alu.sv, branch_unit.sv,
│   │             muldiv.sv, lsu.sv, hazard_unit.sv, forward_unit.sv, csr_file.sv,
│   │             bp/bht.sv, bp/btb.sv, bp/branch_predictor.sv
│   ├── core_sc/  rv_core_sc.sv
│   ├── mem/      ram_dp.sv
│   ├── bus/      dbus_xbar.sv, apb_bridge.sv
│   ├── periph/   sync_fifo.sv, uart/, spi/, timer/, gpio/, intc/, sim/
│   ├── rst_sync.sv
│   └── soc_top.sv
├── ip/timer64_dacs4/        # (nếu sinh viên cung cấp)
├── tb/       unit/, bfm/, soc/, cov/
├── sw/       common/, drivers/, tests/, benchmarks/, riscv-tests-env/
├── third_party/             # clone bằng scripts/fetch_third_party.sh
├── scripts/  fetch_third_party.sh, elf2hex.py, run_isa.py, compare_spike.py, run_systest.py,
│             run_perf.py, cov_report.py, synth_report.py, vcd2png.py
├── syn/
├── results/  isa/, spike/, systest/, perf/, coverage/, synth/, waves/   # có trong git, trừ vcd/fst
└── docs/
    ├── spec.md, memory_map.md, register_map.md, microarch.md, verification_plan.md
    ├── decisions.md, env.md, results.md, compliance.md
    ├── diagrams/   # Mermaid + WaveDrom JSON (+ PNG/SVG nếu có công cụ render)
    ├── gtkw/       # file .gtkw cho từng cảnh waveform quan trọng
    ├── giai_thich/
    └── report/
```

---

## 15. Tài liệu giải thích cho sinh viên (`docs/giai_thich/`)

Sinh viên phải tự bảo vệ, nên phần này quan trọng ngang phần code.

- **Mỗi module chính 1 file:** chức năng, sơ đồ, giải thích tín hiệu quan trọng, các tình huống khó. Ví dụ:
  - vì sao forward từ `ex_mem` được ưu tiên hơn `mem_wb`;
  - vì sao CSR và trap được xử lý ở MEM;
  - vì sao so sánh `pred_npc` phát hiện được mọi loại sai dự đoán;
  - lệnh 32 bit nằm vắt qua ranh giới word được fetch thế nào;
  - FSM của APB bridge, UART RX, SPI.
- **`walkthrough_pipeline.md`:** theo dõi từng chu kỳ một đoạn chương trình ngắn có load-use, branch dự đoán sai, lệnh nén, ngắt. Kèm bảng pipeline theo chu kỳ, hình waveform và file `.gtkw` tương ứng.
- **`bao_ve_QA.md`:** ít nhất 50 câu hỏi hội đồng có thể hỏi, kèm câu trả lời ngắn gọn, dựa trên chính thiết kế này. Chủ đề: hazard, forwarding, BHT 2 bit so với 1 bit, BTB alias, precise exception, độ trễ ngắt, APB timing, UART oversampling, 4 mode SPI, lý do chọn RAM đọc tổ hợp, critical path, ý nghĩa của các con số CPI, giới hạn của thiết kế, khác biệt so với Ibex/PicoRV32, đã xác minh như thế nào.
- **`huong_dan_chay.md`:** lệnh để tự chạy lại mọi kết quả, cách mở waveform bằng GTKWave, cách sửa một tham số rồi chạy lại thí nghiệm.

---

## 16. Báo cáo (`docs/report/`)

Viết bằng tiếng Việt, khoảng 45 trang, đúng dàn ý trong đề cương. Mỗi chương 1 file markdown, số liệu trích trực tiếp từ `results/`.

Bìa, `README.md` và mọi chỗ nêu tên đề tài phải dùng **chính xác** chuỗi: *"Thiết kế SoC dựa trên lõi RISC-V RV32IMC pipeline 5 tầng có dự đoán rẽ nhánh, tích hợp ngoại vi truyền thông UART và SPI"*.

1. **Tổng quan về kiến trúc RISC-V và hệ thống SoC:** ISA RV32I, M, C, CSR; pipeline, xung đột, dự đoán rẽ nhánh; giao thức bus AMBA APB; giao thức UART và SPI.
2. **Thiết kế lõi RV32IMC pipeline 5 tầng:** datapath, điều khiển, hazard; MulDiv; fetch và giải nén C; BHT/BTB và cơ chế phục hồi; CSR, ngắt/ngoại lệ.
3. **Thiết kế SoC và ngoại vi:** sơ đồ khối, memory map, APB bridge, decoder; UART, SPI (kiến trúc, FIFO, register map, ngắt); Timer, GPIO, INTC, top-level.
4. **Xác minh và đánh giá:** môi trường 3 mức; bảng riscv-tests; so sánh Spike; system test; waveform minh họa; coverage; bảng và biểu đồ CPI, độ chính xác dự đoán, kích thước mã, diện tích, Fmax, critical path.
5. **Kết luận và hướng phát triển:** đối chiếu với mục tiêu; cache, extension A, lệnh tùy biến, SRAM đồng bộ + prefetch, I2C, RAS, RTL-to-GDSII.

Yêu cầu:
- **Hình:** sơ đồ khối và FSM vẽ bằng Mermaid/WaveDrom (render ra PNG/SVG nếu có `mmdc`/`wavedrom-cli`; nếu không, `scripts/vcd2png.py` hoặc matplotlib vẽ thay). Waveform minh họa sinh tự động từ VCD bằng `scripts/vcd2png.py` (matplotlib) cho: forwarding, load-use stall, dự đoán sai và flush, lệnh nén, vào/ra trap, giao dịch APB, khung UART, khung SPI mode 0 và 3. Mỗi hình có số thứ tự và chú thích.
- Mỗi bảng có số thứ tự, chú thích, và nguồn (file trong `results/`).
- Tài liệu tham khảo: đúng danh sách trong đề cương, thêm riscv-tests, Spike, Verilator, Yosys, CoreMark nếu có dùng.
- Nếu có `pandoc`: xuất `docs/report/baocao.docx` (ghép đủ 5 chương, có mục lục).

---

## 17. Nghiệm thu cuối (agent tự kiểm trước khi báo xong)

Tạo `docs/compliance.md`: bảng truy vết **yêu cầu → file hiện thực → test chứng minh → trạng thái** cho mọi yêu cầu ở mục 3–12. Chỉ tuyên bố hoàn thành khi tất cả mục dưới đây đạt:

- [ ] `make regress` từ một bản clone sạch (`git clone . /tmp/check && cd /tmp/check && make fetch regress`) → toàn bộ PASS
- [ ] Lint sạch
- [ ] riscv-tests: đủ ma trận cấu hình; loại trừ có lý do
- [ ] So sánh Spike: không có khác biệt chưa giải thích
- [ ] Mọi unit test và system test (mục 10.1, 10.4) PASS
- [ ] Coverage đạt mục tiêu hoặc có giải thích phần thiếu
- [ ] `results/perf`, `results/synth` đầy đủ, qua kiểm tra hợp lý ở 12.1
- [ ] `docs/results.md`, `docs/compliance.md`, `docs/decisions.md` hoàn chỉnh
- [ ] `docs/giai_thich/` đủ các file ở mục 15; `bao_ve_QA.md` ≥ 50 câu
- [ ] `docs/report/` đủ 5 chương, hình và bảng có số liệu thật
- [ ] `README.md` có hướng dẫn nhanh
- [ ] `PROGRESS.md` đánh dấu toàn bộ Phase hoàn thành; mục `BLOCKED` rỗng hoặc ghi rõ phần còn thiếu
- [ ] Commit cuối: `final: project complete`

**Tin nhắn cuối gửi sinh viên (tiếng Việt):**
1. Tóm tắt kết quả chính: số test pass, CPI theo từng BP_MODE, độ chính xác dự đoán, mức giảm kích thước mã, diện tích, Fmax.
2. Những gì chưa làm được hoặc bị chặn, và lý do.
3. Danh sách 5–7 file sinh viên nên đọc trước để chuẩn bị bảo vệ.
4. Các lệnh để tự chạy lại demo và regression.

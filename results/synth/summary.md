# Tổng hợp – diện tích và Fmax

Diện tích: Yosys `synth -flatten` (thư viện generic, đơn vị = số cell logic sau tối ưu); `ram_dp` là black box nên **RAM 128 KB không được tính**. Fmax: Yosys `synth_ecp5` + `nextpnr-ecp5` (LFE5U-85F, CABGA756, seed 1) – chỉ là **ước lượng trên FPGA**; không làm place & route ASIC (ngoài phạm vi). Tái tạo: `make synth`.

## Bảng S1 – Diện tích lõi và ngoại vi (generic)

| Khối | Tham số | Cell | Flip-flop |
|---|---|---|---|
| `rv_core_m1c1_bp0` | {'ENABLE_M': 1, 'ENABLE_C': 1, 'BP_MODE': 0} | 24568 | 2532 |
| `rv_core_m1c1_bp1` | {'ENABLE_M': 1, 'ENABLE_C': 1, 'BP_MODE': 1} | 28926 | 3045 |
| `rv_core_m1c1_bp2` | {'ENABLE_M': 1, 'ENABLE_C': 1, 'BP_MODE': 2} | 32797 | 4966 |
| `rv_core_m1c0_bp2` | {'ENABLE_M': 1, 'ENABLE_C': 0, 'BP_MODE': 2} | 30987 | 4871 |
| `rv_core_m0c0_bp2` | {'ENABLE_M': 0, 'ENABLE_C': 0, 'BP_MODE': 2} | 21368 | 4699 |
| `rv_core_sc` | – | 10474 | 1509 |
| `uart_apb` | – | 1457 | 411 |
| `spi_apb` | – | 1145 | 364 |
| `timer64_apb` | – | 1245 | 146 |
| `gpio_apb` | – | 611 | 130 |
| `intc_apb` | – | 54 | 3 |
| `apb_bridge` | – | 180 | 71 |
| `dbus_xbar` | – | 170 | 0 |
| `sim_ctrl` | – | 18 | 0 |
| `rst_sync` | – | 2 | 2 |
| `soc_top` | – | 37769 | 6077 |

Nguồn: `results/synth/area.csv`.

## Bảng S2 – Diện tích `rv_core` theo BHT × BTB (BP_MODE 2, số cell)

| BHT \ BTB | 8 | 16 | 32 | 64 |
|---|---|---|---|---|
| 16 | 26426 | 27402 | 29403 | 33265 |
| 64 | 27123 | 28115 | 30127 | 33911 |
| 256 | 29828 | 30808 | 32797 | 36671 |
| 1024 | 40824 | 41822 | 43843 | 47685 |

## Bảng S3 – ECP5: tài nguyên và Fmax ước lượng

| Thiết kế | LUT4 | FF | Fmax (MHz) | Đường găng (tóm tắt) |
|---|---|---|---|---|
| `m1c1_bp2` | 9039 | 4966 | 43.85 | `u_ex.mem_rd` → `dbus_addr` (41 chặng logic/định tuyến) |
| `m1c1_bp0` | 5780 | 2532 | 47.91 | `u_ex.mem_rd` → `dbus_addr` (35 chặng logic/định tuyến) |
| `m0c0_bp2` | 8078 | 4699 | 46.47 | `u_ex.mem_insn` → `u_if.id_insn` (37 chặng logic/định tuyến) |
| `sc` | 4493 | 1509 | 44.22 | `u_csr.wdata` → `irq_meip` (24 chặng logic/định tuyến) |
| `soc_top_1k` | 11397 | 5565 | 42.27 | `g_pipe.u_core.u_ex.mem_rd` → `g_pipe.u_core.u_ex.fwd_rs2` (42 chặng logic/định tuyến) |
| `soc_top_m0c0_1k` | 10518 | 5298 | 47.16 | `g_pipe.u_core.u_ex.mem_rd` → `g_pipe.u_core.u_if.id_insn` (46 chặng logic/định tuyến) |
| `soc_top_sc_1k` | 9061 | 2108 | 25.59 | `g_sc.u_core.pc_q` → `u_ram.mem.0.58_DO_1` (55 chặng logic/định tuyến) |

Chi tiết từng chặng: `results/synth/critical_path_<tên>.txt`. `soc_top_*_1k` dùng RAM 1 KB (LUT RAM) thay cho 128 KB để đặt được trên FPGA và tính cả đường đọc RAM tổ hợp; Fmax của lõi đứng riêng (`m1c1_bp2`, `sc`…) **không** gồm đường qua RAM (cổng vào/ra lõi không được ràng buộc), nên so sánh single-cycle với pipeline phải dùng các dòng `soc_top_*`.

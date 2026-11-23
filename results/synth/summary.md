# Tổng hợp – diện tích và Fmax

Diện tích: Yosys `synth -flatten` (thư viện generic, đơn vị = số cell logic sau tối ưu); `ram_dp` là black box nên **RAM 128 KB không được tính**. Fmax: Yosys `synth_ecp5` + `nextpnr-ecp5` (LFE5U-85F, CABGA756), 5 seed đặt–định tuyến trên cùng netlist, báo **trung vị** và khoảng min–max (một seed riêng lẻ dao động tới vài chục %) – chỉ là **ước lượng trên FPGA**; không làm place & route ASIC (ngoài phạm vi). Tái tạo: `make synth`.

## Bảng S1 – Diện tích lõi và ngoại vi (generic)

| Khối               | Tham số                                      | Cell  | Flip-flop |
| ------------------ | -------------------------------------------- | ----- | --------- |
| `rv_core_m1c1_bp0` | {'ENABLE_M': 1, 'ENABLE_C': 1, 'BP_MODE': 0} | 24567 |      2532 |
| `rv_core_m1c1_bp1` | {'ENABLE_M': 1, 'ENABLE_C': 1, 'BP_MODE': 1} | 28970 |      3045 |
| `rv_core_m1c1_bp2` | {'ENABLE_M': 1, 'ENABLE_C': 1, 'BP_MODE': 2} | 32801 |      4966 |
| `rv_core_m1c0_bp2` | {'ENABLE_M': 1, 'ENABLE_C': 0, 'BP_MODE': 2} | 30995 |      4871 |
| `rv_core_m0c0_bp2` | {'ENABLE_M': 0, 'ENABLE_C': 0, 'BP_MODE': 2} | 21370 |      4699 |
| `rv_core_sc`       | –                                            | 10477 |      1509 |
| `uart_apb`         | –                                            |  1457 |       411 |
| `spi_apb`          | –                                            |  1145 |       364 |
| `timer64_apb`      | –                                            |  1245 |       146 |
| `gpio_apb`         | –                                            |   611 |       130 |
| `intc_apb`         | –                                            |    54 |         3 |
| `apb_bridge`       | –                                            |   182 |        71 |
| `dbus_xbar`        | –                                            |   173 |         0 |
| `sim_ctrl`         | –                                            |    18 |         0 |
| `rst_sync`         | –                                            |     2 |         2 |
| `soc_top`          | –                                            | 37785 |      6077 |

Nguồn: `results/synth/area.csv`.

## Bảng S2 – Diện tích `rv_core` theo BHT × BTB (BP_MODE 2, số cell)

| BHT \ BTB | 8     | 16    | 32    | 64    |
| --------- | ----- | ----- | ----- | ----- |
|        16 | 26427 | 27412 | 29403 | 33277 |
|        64 | 27170 | 28112 | 30096 | 33915 |
|       256 | 29826 | 30811 | 32801 | 36664 |
|      1024 | 40870 | 41837 | 43817 | 47690 |

## Bảng S3 – ECP5: tài nguyên và Fmax ước lượng

| Thiết kế          | LUT4  | FF   | Fmax trung vị (MHz) | min – max (5 seed) | Đường găng (seed trung vị, tóm tắt)                                                    |
| ----------------- | ----- | ---- | ------------------- | ------------------ | -------------------------------------------------------------------------------------- |
| `m1c1_bp2`        |  9715 | 4966 |               40.68 | 40.23 – 42.55      | `u_id.ex_is_load` → `u_ex.fwd_rs1` (49 chặng logic/định tuyến)                         |
| `m1c1_bp0`        |  5493 | 2532 |               43.45 | 41.73 – 46.99      | `u_ex.mem_rd_we` → `dbus_adr_o` (27 chặng logic/định tuyến)                            |
| `m0c0_bp2`        |  8446 | 4699 |               45.48 | 43.7 – 46.64       | `u_ex.mem_rd_we` → `u_if.pc_q` (46 chặng logic/định tuyến)                             |
| `sc`              |  4501 | 1509 |               46.22 | 44.09 – 47.74      | `u_csr.wdata` → `u_csr.wdata` (42 chặng logic/định tuyến)                              |
| `soc_top_1k`      | 11663 | 5565 |               43.73 | 42.02 – 44.79      | `g_pipe.u_core.u_ex.mem_rd_we` → `g_pipe.u_core.u_if.pc_q` (22 chặng logic/định tuyến) |
| `soc_top_m0c0_1k` | 10211 | 5298 |               43.67 | 39.74 – 46.95      | `g_pipe.u_core.u_ex.mem_rd` → `g_pipe.u_core.u_if.id_insn` (33 chặng logic/định tuyến) |
| `soc_top_sc_1k`   |  8281 | 2108 |               25.67 | 24.97 – 26.11      | `g_sc.u_core.pc_q` → `g_sc.u_core.irq_mtip` (41 chặng logic/định tuyến)                |

Chi tiết từng chặng: `results/synth/critical_path_<tên>.txt`. `soc_top_*_1k` dùng RAM 1 KB (LUT RAM) thay cho 128 KB để đặt được trên FPGA và tính cả đường đọc RAM tổ hợp; Fmax của lõi đứng riêng (`m1c1_bp2`, `sc`…) **không** gồm đường qua RAM (cổng vào/ra lõi không được ràng buộc), nên so sánh single-cycle với pipeline phải dùng các dòng `soc_top_*`.

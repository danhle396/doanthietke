# `soc_top` và phần mềm

## `soc_top` (`rtl/soc_top.sv`)

- `rst_sync`: reset ngoài bật bất đồng bộ (tác dụng ngay) nhưng nhả đồng bộ qua 2 FF → mọi flip-flop thoát reset
  cùng một cạnh clock, tránh vi phạm recovery/removal.
- Lõi: `rv_core` hoặc `rv_core_sc` (`CORE_SC`), tham số truyền xuống (`ENABLE_M/C`, `BP_MODE`, `BHT/BTB_ENTRIES`).
- `ram_dp`, `dbus_xbar`, `apb_bridge` + 6 slave APB; mux phản hồi APB theo slot của giao dịch hiện tại.
- Ngắt: `mtip/msip` từ TIMER64, `meip` từ INTC (UART, SPI, GPIO).

## Phần mềm (`sw/`)

| Thư mục               | Nội dung                                                                               |
| --------------------- | -------------------------------------------------------------------------------------- |
| `common/crt0.S`       | đặt `sp`, `gp`, xóa `.bss`, `mtvec = trap_entry`, `console_init`, `main`, `exit`       |
| `common/trap_entry.S` | lưu/khôi phục `ra, t0–t6, a0–a7`, gọi `trap_handler(mcause, mepc, mtval)`; bảng vector |
| `common/sys.c`        | `exit()` (SIM_CTRL EXIT rồi `tohost`), dispatch trap mặc định (weak)                   |
| `common/xprintf.c`    | printf tối giản (`%d %u %x %s %c %%`, độ rộng, pad 0)                                  |
| `common/libc_min.c`   | memcpy, memset, memmove, memcmp, strcpy, strcmp, strlen                                |
| `common/perf.c`       | đọc counter 64 bit (hi-lo-hi), in CPI ×1000                                            |
| `drivers/`            | uart, spi, spi_flash, timer, gpio, intc – API polling và API ngắt                      |
| `tests/`              | 11 system test (mục 10.4)                                                              |
| `benchmarks/`         | 8 benchmark riscv-tests + CoreMark (port qua shim, không sửa mã gốc)                   |

`exit()` ghi SIM_CTRL (để mô phỏng RTL dừng) **rồi** `tohost` (để Spike dừng) – cùng một ELF chạy được trên cả hai.
Firmware không dùng số thực; CPI in dạng số nguyên ×1000.

Biến thể build: `i`, `im`, `imc` (`-march=rv32i/rv32im/rv32imc_zicsr_zifencei`), vì GAS tự nén lệnh khi có `c`.
Console: `CONSOLE=uart` (UART thật + BFM) hoặc `CONSOLE=sim` (SIM_CTRL, dùng cho benchmark và so sánh Spike).

# TIMER64, GPIO, INTC, SIM_CTRL

## TIMER64 (`rtl/periph/timer/timer64_apb.sv`)

- `mtime` 64 bit tăng 1 sau mỗi `PRESCALE+1` chu kỳ khi `EN = 1`; `mtimecmp` reset `0xFFFF_FFFF_FFFF_FFFF`.
- `mtip = (mtime >= mtimecmp)` theo **mức**: ISR xóa ngắt bằng cách ghi `mtimecmp` mới (lớn hơn).
- `msip` = bit 0 của thanh ghi MSIP (ngắt phần mềm).
- `mtime` nối thẳng vào lõi cho CSR `time/timeh`.
- **Đọc 64 bit trên bus 32 bit (hi-lo-hi)**: đọc HI, LO, HI lại; nếu hai lần HI khác nhau (LO vừa tràn) thì đọc lại.
- **Ghi `mtimecmp` không gây ngắt giả**: ghi LO = 0xFFFF_FFFF trước, rồi HI, rồi LO thật – trong suốt quá trình
  giá trị trung gian luôn ≥ giá trị cũ và ≥ đích, không bao giờ nhỏ hơn `mtime` một cách tạm thời (`tb_timer` kiểm
  `mtip` không nhấp nháy).
- Không có mã IP ĐACS4 trong `ip/` nên tự hiện thực theo đặc tả (decision D15).

## GPIO (`rtl/periph/gpio/gpio_apb.sv`)

- OUT, DIR (1 = output → `gpio_oe`, tri-state đặt ngoài `soc_top`), IN đồng bộ 2 FF.
- Ngắt cạnh theo từng chân: IRQ_TYPE 0 = cạnh lên, 1 = cạnh xuống; IRQ_STATUS dính, W1C; sự kiện mới thắng W1C cùng
  chu kỳ. Phát hiện cạnh bắt đầu sau 3 chu kỳ kể từ reset nên chân đang ở mức cao lúc reset không tạo "cạnh lên" giả.

## INTC (`rtl/periph/intc/intc_apb.sv`)

PENDING (mức thô của UART, SPI, GPIO), ENABLE, ACTIVE = PENDING & ENABLE, `meip = |ACTIVE`. Firmware: ISR MEI đọc
ACTIVE rồi gọi `uart_isr`/`spi_isr`/`gpio_isr`; mỗi handler xóa nguồn tại ngoại vi (`sw/drivers/intc.c`).
Vì tất cả theo mức, nếu hai nguồn cùng bật, sau MRET ngắt lại xảy ra ngay cho nguồn còn lại – không mất ngắt.

## SIM_CTRL (`rtl/periph/sim/sim_ctrl.sv`, chỉ mô phỏng)

PUTCHAR in ký tự ra stdout/file; EXIT kết thúc mô phỏng (0 = PASS). Khi tổng hợp chỉ còn hai thanh ghi giả.

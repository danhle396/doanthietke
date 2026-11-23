# Thông lượng (throughput)

Lõi `rv_core` RV32IMC, BP_MODE 2 (BHT 256, BTB 32), ELF `imc`; số chu kỳ/lệnh của vùng đo trong mỗi benchmark (nguồn: `results/perf/exp1_predictor.csv`). Tần số: **24 MHz** (clock CPU trên board DE2) và **43.73 MHz** (Fmax trung vị 5 seed của `soc_top_1k`, ước lượng ECP5). Thời gian = chu kỳ ÷ f; MIPS = f ÷ CPI. Sinh bởi `scripts/throughput.py`.

## Bảng T1 – Thời gian chạy và MIPS

| Benchmark        | Lệnh   | Chu kỳ | CPI   | Thời gian @24 MHz (µs) | MIPS @24 MHz | Thời gian @43.73 MHz (µs) | MIPS @43.73 MHz |
| ---------------- | ------ | ------ | ----- | ---------------------- | ------------ | ------------------------- | --------------- |
| dhrystone        | 277083 | 333617 | 1.204 |                13900.7 |         19.9 |                    7629.0 |            36.3 |
| coremark         | 626769 | 695588 | 1.110 |                28982.8 |         21.6 |                   15906.4 |            39.4 |
| median           |   4307 |   5404 | 1.255 |                  225.2 |         19.1 |                     123.6 |            34.9 |
| multiply         |  20953 |  22282 | 1.063 |                  928.4 |         22.6 |                     509.5 |            41.1 |
| qsort            | 123560 | 148150 | 1.199 |                 6172.9 |         20.0 |                    3387.8 |            36.5 |
| rsort            | 171186 | 171242 | 1.000 |                 7135.1 |         24.0 |                    3915.9 |            43.7 |
| towers           |   3777 |   4028 | 1.066 |                  167.8 |         22.5 |                      92.1 |            41.0 |
| vvadd            |   2469 |   2489 | 1.008 |                  103.7 |         23.8 |                      56.9 |            43.4 |
| memcpy           |  20089 |  20110 | 1.001 |                  837.9 |         24.0 |                     459.9 |            43.7 |
| **geomean MIPS** |        |        |       |                        |     **21.9** |                           |        **39.9** |

## Bảng T2 – Điểm chuẩn

| Chỉ số                                                        | /MHz  | @24 MHz | @43.73 MHz |
| ------------------------------------------------------------- | ----- | ------- | ---------- |
| Dhrystone (DMIPS; 500 vòng, 1 DMIPS = 1757 vòng/s)            | 0.853 |    20.5 |       37.3 |
| CoreMark (2 vòng, không phải lần chạy hợp lệ theo luật EEMBC) |  2.88 |    69.0 |      125.7 |

## Bảng T3 – Bus và ngoại vi

| Đường truyền                                               | Chu kỳ / đơn vị | Nguồn                                                            | @24 MHz           | @43.73 MHz         |
| ---------------------------------------------------------- | --------------- | ---------------------------------------------------------------- | ----------------- | ------------------ |
| RAM qua Wishbone (load/store 32 bit, ACK cùng chu kỳ)      |               1 | RTL; số chu kỳ benchmark trùng khớp với RAM tổ hợp               | 96.00 MB/s        | 174.92 MB/s        |
| Thanh ghi ngoại vi qua Wishbone → APB4                     |               3 | đo bằng `wb_checker` (system test `hello`: 3.00 chu kỳ/truy cập) | 8.00 M truy cập/s | 14.58 M truy cập/s |
| UART 115200 baud (BAUD_DIV 12 @24 MHz, khung 8N1 = 10 bit) |            2080 | 16 × (12 + 1) chu kỳ/bit                                         | 11.5 kB/s         | 21.0 kB/s          |
| UART tối đa (BAUD_DIV 0, khung 8N1)                        |             160 | 16 chu kỳ/bit                                                    | 150.0 kB/s        | 273.3 kB/s         |
| SPI tối đa (CLK_DIV 0, SCLK = f/2, burst)                  |              17 | 17 × (CLK_DIV + 1) chu kỳ/byte                                   | 1.41 MB/s         | 2.57 MB/s          |
| SPI flash trong firmware (CLK_DIV 1, SCLK = f/4)           |              34 | 17 × 2 chu kỳ/byte                                               | 0.71 MB/s         | 1.29 MB/s          |

Ghi chú: tốc độ UART ở dòng 115200 baud đúng cho clock 24 MHz của board; ở tần số khác BAUD_DIV phải tính lại. CoreMark chạy 2 vòng để vừa thời gian mô phỏng nên chỉ dùng để so sánh tương đối.

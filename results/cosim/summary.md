# Co-simulation C++ lock-step với Spike – tổng hợp

| Cấu hình | MATCH | Tổng | Lệnh so khớp | Thời gian (s) |
|---|---|---|---|---|
| `m1c1_bp2` | 73 | 73 | 1639070 | 21.8 |
| `m1c0_bp2` | 72 | 72 | 1638940 | 22.3 |
| `m0c0_bp2` | 64 | 64 | 2516910 | 31.4 |
| `sc` | 50 | 50 | 2528472 | 36.3 |

Mutant (lỗi SLTU cài sẵn): phát hiện ở 2 / 73 chương trình – xem `mutant.md`.

Hình lock-step: `results/cosim/lockstep.png`.

Tái tạo: `make cosim`

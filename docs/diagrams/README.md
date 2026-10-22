# Sơ đồ

- `*.mmd`: nguồn Mermaid của sơ đồ khối và FSM; `*.png` cùng tên được vẽ bằng matplotlib
  (`scripts/draw_diagrams.py`) vì máy không có `mmdc`.
- `*.wavedrom.json`: nguồn WaveDrom của các giản đồ thời gian lý tưởng (APB, UART, SPI, load-use). Không có
  `wavedrom-cli` nên hình waveform trong báo cáo được vẽ từ **mô phỏng thật** (VCD) bằng `scripts/vcd2png.py`
  / `scripts/make_waves.py` (thư mục `results/waves/`). Có thể dán JSON vào https://wavedrom.com/editor.html để xem.

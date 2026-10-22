# Dòng RTL chưa được phủ (line coverage)

## `rtl/core/alu.sv` – 1 dòng

| Dòng | Mã | Giải thích |
|---|---|---|
| 42 | `default:  result = a + b;` | nhánh `default` của `case (op)`: decoder chỉ sinh 10 mã ALU hợp lệ nên nhánh này không thể xảy ra; giữ lại để tránh latch / X khi tổng hợp |

## `rtl/periph/sim/sim_ctrl.sv` – 3 dòng

| Dòng | Mã | Giải thích |
|---|---|---|
| 78 | `if (exit_code_q == 32'b0) begin` | đường tự kết thúc dự phòng của SIM_CTRL (sau EXIT_DELAY = 1000 chu kỳ); trong mọi lần chạy `tb_soc` xử lý EXIT trước (D9) nên đường này không chạy – chỉ dùng khi SIM_CTRL được dùng mà không có testbench đó |
| 79 | `$display("PASS");` | đường tự kết thúc dự phòng của SIM_CTRL (sau EXIT_DELAY = 1000 chu kỳ); trong mọi lần chạy `tb_soc` xử lý EXIT trước (D9) nên đường này không chạy – chỉ dùng khi SIM_CTRL được dùng mà không có testbench đó |
| 80 | `$finish;` | đường tự kết thúc dự phòng của SIM_CTRL (sau EXIT_DELAY = 1000 chu kỳ); trong mọi lần chạy `tb_soc` xử lý EXIT trước (D9) nên đường này không chạy – chỉ dùng khi SIM_CTRL được dùng mà không có testbench đó |

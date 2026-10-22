# Functional coverage

29/70 điểm cover đạt (gộp theo tên, mọi instance). Điểm định nghĩa trong `tb/cov/*.sv`, gắn bằng `bind`. Tái tạo: `make cov`.

| Điểm cover | Số lần | Instance đạt / tổng | Kết quả |
|---|---|---|---|
| `c_btb_alloc` | 28 | 1/1 | ĐẠT |
| `c_btb_hit` | 13086 | 2/2 | ĐẠT |
| `c_btb_miss` | 5597 | 1/1 | ĐẠT |
| `c_btb_replace` | 1811 | 1/1 | ĐẠT |
| `c_exc_breakpoint` | 0 | 0/1 | CHƯA ĐẠT |
| `c_exc_ecall` | 0 | 0/1 | CHƯA ĐẠT |
| `c_exc_illegal` | 0 | 0/1 | CHƯA ĐẠT |
| `c_exc_insn_access` | 0 | 0/1 | CHƯA ĐẠT |
| `c_exc_insn_misaligned` | 0 | 0/1 | CHƯA ĐẠT |
| `c_exc_load_access` | 0 | 0/1 | CHƯA ĐẠT |
| `c_exc_load_misaligned` | 0 | 0/1 | CHƯA ĐẠT |
| `c_exc_store_access` | 0 | 0/1 | CHƯA ĐẠT |
| `c_exc_store_misaligned` | 0 | 0/1 | CHƯA ĐẠT |
| `c_fifo_empty` | 36837 | 1/1 | ĐẠT |
| `c_fifo_full` | 7408 | 1/1 | ĐẠT |
| `c_fifo_push_full` | 0 | 0/1 | CHƯA ĐẠT |
| `c_fifo_push_pop` | 0 | 0/1 | CHƯA ĐẠT |
| `c_fwd_exmem_rs1` | 1793 | 1/1 | ĐẠT |
| `c_fwd_exmem_rs2` | 98 | 1/1 | ĐẠT |
| `c_fwd_memwb_rs1` | 1751 | 1/1 | ĐẠT |
| `c_fwd_memwb_rs2` | 23 | 1/1 | ĐẠT |
| `c_id_redirect` | 36 | 1/1 | ĐẠT |
| `c_insn32_straddle` | 266 | 1/1 | ĐẠT |
| `c_irq_during_div` | 0 | 0/1 | CHƯA ĐẠT |
| `c_irq_mei` | 0 | 0/1 | CHƯA ĐẠT |
| `c_irq_msi` | 0 | 0/1 | CHƯA ĐẠT |
| `c_irq_mti` | 0 | 0/1 | CHƯA ĐẠT |
| `c_m_div` | 0 | 0/1 | CHƯA ĐẠT |
| `c_m_divu` | 11 | 1/1 | ĐẠT |
| `c_m_mul` | 0 | 0/1 | CHƯA ĐẠT |
| `c_m_mulh` | 0 | 0/1 | CHƯA ĐẠT |
| `c_m_mulhsu` | 0 | 0/1 | CHƯA ĐẠT |
| `c_m_mulhu` | 0 | 0/1 | CHƯA ĐẠT |
| `c_m_rem` | 0 | 0/1 | CHƯA ĐẠT |
| `c_m_remu` | 11 | 1/1 | ĐẠT |
| `c_mispred_branch` | 103 | 1/1 | ĐẠT |
| `c_mispred_btb_alias` | 0 | 0/1 | CHƯA ĐẠT |
| `c_mispred_jal` | 0 | 0/1 | CHƯA ĐẠT |
| `c_mispred_jalr` | 29 | 1/1 | ĐẠT |
| `c_ret_auipc` | 4 | 1/1 | ĐẠT |
| `c_ret_branch` | 171 | 1/1 | ĐẠT |
| `c_ret_compressed` | 5579 | 1/1 | ĐẠT |
| `c_ret_csr` | 1 | 1/1 | ĐẠT |
| `c_ret_fence` | 0 | 0/1 | CHƯA ĐẠT |
| `c_ret_fencei` | 0 | 0/1 | CHƯA ĐẠT |
| `c_ret_jal` | 0 | 0/1 | CHƯA ĐẠT |
| `c_ret_jalr` | 0 | 0/1 | CHƯA ĐẠT |
| `c_ret_load` | 226 | 1/1 | ĐẠT |
| `c_ret_lui` | 161 | 1/1 | ĐẠT |
| `c_ret_mret` | 0 | 0/1 | CHƯA ĐẠT |
| `c_ret_op` | 21 | 1/1 | ĐẠT |
| `c_ret_opimm` | 93 | 1/1 | ĐẠT |
| `c_ret_store` | 92 | 1/1 | ĐẠT |
| `c_spi_lsb` | 0 | 0/1 | CHƯA ĐẠT |
| `c_spi_mode0` | 0 | 0/1 | CHƯA ĐẠT |
| `c_spi_mode1` | 0 | 0/1 | CHƯA ĐẠT |
| `c_spi_mode2` | 0 | 0/1 | CHƯA ĐẠT |
| `c_spi_mode3` | 0 | 0/1 | CHƯA ĐẠT |
| `c_spi_msb` | 0 | 0/1 | CHƯA ĐẠT |
| `c_stall_bus` | 3118 | 1/1 | ĐẠT |
| `c_stall_csr_use` | 0 | 0/1 | CHƯA ĐẠT |
| `c_stall_load_use` | 1616 | 1/1 | ĐẠT |
| `c_stall_muldiv` | 726 | 1/1 | ĐẠT |
| `c_trap_after_mispred` | 0 | 0/1 | CHƯA ĐẠT |
| `c_uart_8n1` | 11840 | 1/1 | ĐẠT |
| `c_uart_err` | 0 | 0/1 | CHƯA ĐẠT |
| `c_uart_even` | 0 | 0/1 | CHƯA ĐẠT |
| `c_uart_odd` | 0 | 0/1 | CHƯA ĐẠT |
| `c_uart_rx` | 0 | 0/1 | CHƯA ĐẠT |
| `c_uart_stop2` | 0 | 0/1 | CHƯA ĐẠT |

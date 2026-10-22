// ============================================================================
// tb_soc_bfms.svh - BFM hookup for tb_soc (included inside module tb_soc).
//   Phase 1: inputs tied off; UART/SPI/GPIO BFMs are attached in Phase 7.
// ============================================================================
  assign uart_rx  = 1'b1;
  assign spi_miso = 1'b0;
  assign gpio_i   = 16'h0000;

  task automatic bfm_final_check(inout bit pass, inout string why);
  endtask

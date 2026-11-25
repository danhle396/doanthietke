module ram_bank16 #(
  parameter int DEPTH = 8192,
  parameter int HALF  = 0
) (
  input  logic                     clk,
  input  logic [$clog2(DEPTH)-1:0] a_addr,
  input  logic                     a_we,
  input  logic [1:0]               a_be,
  input  logic [15:0]              a_wdata,
  output logic [15:0]              a_rdata,
  input  logic [$clog2(DEPTH)-1:0] b_addr,
  output logic [15:0]              b_rdata
);

  localparam int AW = $clog2(DEPTH);

  logic clk_n;
  assign clk_n = ~clk;

  generate
  if (HALF == 0) begin : g_bank0
    altsyncram #(
      .operation_mode                    ("BIDIR_DUAL_PORT"),
      .width_a                           (16),
      .widthad_a                         (AW),
      .numwords_a                        (DEPTH),
      .width_byteena_a                   (2),
      .byte_size                         (8),
      .width_b                           (16),
      .widthad_b                         (AW),
      .numwords_b                        (DEPTH),
      .width_byteena_b                   (1),
      .outdata_reg_a                     ("UNREGISTERED"),
      .outdata_reg_b                     ("UNREGISTERED"),
      .outdata_aclr_a                    ("NONE"),
      .outdata_aclr_b                    ("NONE"),
      .address_reg_b                     ("CLOCK0"),
      .indata_reg_b                      ("CLOCK0"),
      .wrcontrol_wraddress_reg_b         ("CLOCK0"),
      .byteena_reg_b                     ("CLOCK0"),
      .clock_enable_input_a              ("BYPASS"),
      .clock_enable_input_b              ("BYPASS"),
      .clock_enable_output_a             ("BYPASS"),
      .clock_enable_output_b             ("BYPASS"),
      .read_during_write_mode_mixed_ports("DONT_CARE"),
      .power_up_uninitialized            ("FALSE"),
      .init_file                         ("mem/bank0.mif"),
      .intended_device_family            ("Cyclone II"),
      .ram_block_type                    ("M4K"),
      .lpm_type                          ("altsyncram")
    ) u_ram (
      .clock0   (clk_n),
      .address_a(a_addr),
      .data_a   (a_wdata),
      .wren_a   (a_we),
      .byteena_a(a_be),
      .q_a      (a_rdata),
      .address_b(b_addr),
      .data_b   (16'h0000),
      .wren_b   (1'b0),
      .q_b      (b_rdata)
    );
  end else begin : g_bank1
    altsyncram #(
      .operation_mode                    ("BIDIR_DUAL_PORT"),
      .width_a                           (16),
      .widthad_a                         (AW),
      .numwords_a                        (DEPTH),
      .width_byteena_a                   (2),
      .byte_size                         (8),
      .width_b                           (16),
      .widthad_b                         (AW),
      .numwords_b                        (DEPTH),
      .width_byteena_b                   (1),
      .outdata_reg_a                     ("UNREGISTERED"),
      .outdata_reg_b                     ("UNREGISTERED"),
      .outdata_aclr_a                    ("NONE"),
      .outdata_aclr_b                    ("NONE"),
      .address_reg_b                     ("CLOCK0"),
      .indata_reg_b                      ("CLOCK0"),
      .wrcontrol_wraddress_reg_b         ("CLOCK0"),
      .byteena_reg_b                     ("CLOCK0"),
      .clock_enable_input_a              ("BYPASS"),
      .clock_enable_input_b              ("BYPASS"),
      .clock_enable_output_a             ("BYPASS"),
      .clock_enable_output_b             ("BYPASS"),
      .read_during_write_mode_mixed_ports("DONT_CARE"),
      .power_up_uninitialized            ("FALSE"),
      .init_file                         ("mem/bank1.mif"),
      .intended_device_family            ("Cyclone II"),
      .ram_block_type                    ("M4K"),
      .lpm_type                          ("altsyncram")
    ) u_ram (
      .clock0   (clk_n),
      .address_a(a_addr),
      .data_a   (a_wdata),
      .wren_a   (a_we),
      .byteena_a(a_be),
      .q_a      (a_rdata),
      .address_b(b_addr),
      .data_b   (16'h0000),
      .wren_b   (1'b0),
      .q_b      (b_rdata)
    );
  end
  endgenerate

endmodule

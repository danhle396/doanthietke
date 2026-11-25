`timescale 1ns/1ps

module altsyncram #(
  parameter operation_mode                     = "BIDIR_DUAL_PORT",
  parameter integer width_a                    = 16,
  parameter integer widthad_a                  = 13,
  parameter integer numwords_a                 = 8192,
  parameter integer width_byteena_a            = 2,
  parameter integer byte_size                  = 8,
  parameter integer width_b                    = 16,
  parameter integer widthad_b                  = 13,
  parameter integer numwords_b                 = 8192,
  parameter integer width_byteena_b            = 1,
  parameter outdata_reg_a                      = "UNREGISTERED",
  parameter outdata_reg_b                      = "UNREGISTERED",
  parameter outdata_aclr_a                     = "NONE",
  parameter outdata_aclr_b                     = "NONE",
  parameter address_reg_b                      = "CLOCK0",
  parameter indata_reg_b                       = "CLOCK0",
  parameter wrcontrol_wraddress_reg_b          = "CLOCK0",
  parameter byteena_reg_b                      = "CLOCK0",
  parameter clock_enable_input_a               = "BYPASS",
  parameter clock_enable_input_b               = "BYPASS",
  parameter clock_enable_output_a              = "BYPASS",
  parameter clock_enable_output_b              = "BYPASS",
  parameter read_during_write_mode_mixed_ports = "DONT_CARE",
  parameter power_up_uninitialized             = "FALSE",
  parameter init_file                          = "",
  parameter intended_device_family             = "Cyclone II",
  parameter ram_block_type                     = "M4K",
  parameter lpm_type                           = "altsyncram"
) (
  input  logic                       clock0,
  input  logic [widthad_a-1:0]       address_a,
  input  logic [width_a-1:0]         data_a,
  input  logic                       wren_a,
  input  logic [width_byteena_a-1:0] byteena_a,
  output logic [width_a-1:0]         q_a,
  input  logic [widthad_b-1:0]       address_b,
  input  logic [width_b-1:0]         data_b,
  input  logic                       wren_b,
  output logic [width_b-1:0]         q_b
);

  logic [width_a-1:0] mem [numwords_a];

  always_ff @(posedge clock0) begin
    if (wren_a)
      for (int b = 0; b < width_byteena_a; b++)
        if (byteena_a[b]) mem[address_a][b*byte_size +: byte_size] <= data_a[b*byte_size +: byte_size];
    if (wren_b) mem[address_b] <= data_b;
    q_a <= mem[address_a];
    q_b <= mem[address_b];
  end

  initial begin
    integer fd, a, d;
    string  line;
    if (operation_mode != "BIDIR_DUAL_PORT" || outdata_reg_a != "UNREGISTERED" ||
        outdata_reg_b != "UNREGISTERED" || width_a != width_b || numwords_a != numwords_b ||
        width_a != width_byteena_a * byte_size)
      $fatal(1, "altsyncram stub: unsupported configuration");
    for (int i = 0; i < numwords_a; i++) mem[i] = '0;
    fd = $fopen(init_file, "r");
    if (fd == 0) $fatal(1, "altsyncram stub: cannot open %s", init_file);
    while (!$feof(fd)) begin
      void'($fgets(line, fd));
      // "addr : data;" lines; "[a..b] : 0000;" zero ranges are already zero
      if ($sscanf(line, " %h : %h;", a, d) == 2) mem[a] = d[width_a-1:0];
    end
    $fclose(fd);
  end

endmodule

module altpll #(
  parameter bandwidth_type          = "AUTO",
  parameter integer clk0_divide_by  = 1,
  parameter integer clk0_duty_cycle = 50,
  parameter integer clk0_multiply_by = 1,
  parameter clk0_phase_shift        = "0",
  parameter compensate_clock        = "CLK0",
  parameter integer inclk0_input_frequency = 20000,
  parameter intended_device_family  = "Cyclone II",
  parameter lpm_hint                = "",
  parameter lpm_type                = "altpll",
  parameter operation_mode          = "NORMAL",
  parameter gate_lock_signal        = "NO",
  parameter integer invalid_lock_multiplier = 5,
  parameter integer valid_lock_multiplier   = 1,
  parameter port_activeclock = "PORT_UNUSED", parameter port_areset = "PORT_UNUSED",
  parameter port_clkbad0 = "PORT_UNUSED", parameter port_clkbad1 = "PORT_UNUSED",
  parameter port_clkloss = "PORT_UNUSED", parameter port_clkswitch = "PORT_UNUSED",
  parameter port_configupdate = "PORT_UNUSED", parameter port_fbin = "PORT_UNUSED",
  parameter port_inclk0 = "PORT_USED", parameter port_inclk1 = "PORT_UNUSED",
  parameter port_locked = "PORT_USED", parameter port_pfdena = "PORT_UNUSED",
  parameter port_phasecounterselect = "PORT_UNUSED", parameter port_phasedone = "PORT_UNUSED",
  parameter port_phasestep = "PORT_UNUSED", parameter port_phaseupdown = "PORT_UNUSED",
  parameter port_pllena = "PORT_UNUSED", parameter port_scanaclr = "PORT_UNUSED",
  parameter port_scanclk = "PORT_UNUSED", parameter port_scanclkena = "PORT_UNUSED",
  parameter port_scandata = "PORT_UNUSED", parameter port_scandataout = "PORT_UNUSED",
  parameter port_scandone = "PORT_UNUSED", parameter port_scanread = "PORT_UNUSED",
  parameter port_scanwrite = "PORT_UNUSED",
  parameter port_clk0 = "PORT_USED", parameter port_clk1 = "PORT_UNUSED",
  parameter port_clk2 = "PORT_UNUSED", parameter port_clk3 = "PORT_UNUSED",
  parameter port_clk4 = "PORT_UNUSED", parameter port_clk5 = "PORT_UNUSED",
  parameter port_clkena0 = "PORT_UNUSED", parameter port_clkena1 = "PORT_UNUSED",
  parameter port_clkena2 = "PORT_UNUSED", parameter port_clkena3 = "PORT_UNUSED",
  parameter port_clkena4 = "PORT_UNUSED", parameter port_clkena5 = "PORT_UNUSED",
  parameter port_extclk0 = "PORT_UNUSED", parameter port_extclk1 = "PORT_UNUSED",
  parameter port_extclk2 = "PORT_UNUSED", parameter port_extclk3 = "PORT_UNUSED"
) (
  input  logic [1:0] inclk,
  output logic [5:0] clk,
  output logic       locked
);
  int n = 0;
  assign clk = {5'b0, inclk[0]};
  initial locked = 1'b0;
  always @(posedge inclk[0]) begin
    if (n < 8) n <= n + 1;
    locked <= (n >= 7);
  end
endmodule

// sld_virtual_jtag: no JTAG host in simulation - TCK never toggles, so the
// JTAG console of de2_top stays idle (uart_rx high, no host reset). The
// bridge itself is simulated by tb/fpga/tb_jtag_bridge.sv.
module sld_virtual_jtag #(
  parameter sld_auto_instance_index = "YES",
  parameter integer sld_instance_index = 0,
  parameter integer sld_ir_width = 1,
  parameter sld_sim_action = "",
  parameter integer sld_sim_n_scan = 0,
  parameter integer sld_sim_total_length = 0,
  parameter lpm_type = "sld_virtual_jtag"
) (
  output logic                    tck,
  output logic                    tdi,
  input  logic                    tdo,
  output logic [sld_ir_width-1:0] ir_in,
  input  logic [sld_ir_width-1:0] ir_out,
  output logic                    virtual_state_cdr,
  output logic                    virtual_state_sdr,
  output logic                    virtual_state_udr
);
  assign tck = 1'b0;
  assign tdi = 1'b0;
  assign ir_in = '0;
  assign virtual_state_cdr = 1'b0;
  assign virtual_state_sdr = 1'b0;
  assign virtual_state_udr = 1'b0;
endmodule

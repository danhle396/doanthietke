`timescale 1ns/1ps
`ifndef DUT
`define DUT rv_core
`endif

module tb_core_gl;

  localparam DEPTH = 32768;

  reg         clk = 1'b0;
  reg         rst_n = 1'b0;
  wire        ibus_cyc, ibus_stb, dbus_cyc, dbus_stb, dbus_we;
  wire [31:0] ibus_adr, dbus_adr, dbus_wdat;
  wire [3:0]  dbus_sel;
  reg  [31:0] ibus_rdat, dbus_rdat;
  wire        ibus_hit, dbus_hit;
  reg  [63:0] mtime = 64'd0;

  reg  [31:0] mem [0:DEPTH-1];
  reg  [31:0] tohost = 32'hFFFF_FFFF;
  reg  [31:0] max_cycles = 32'd200000;
  reg  [31:0] cycles = 32'd0;
  reg  [31:0] writes = 32'd0;
  reg  [31:0] wsig = 32'd0;
  reg  [1023:0] hex_file;
  integer     i;

  always #10 clk = ~clk;

  `DUT dut (
    .clk(clk), .rst_n(rst_n),
    .ibus_cyc_o(ibus_cyc), .ibus_stb_o(ibus_stb), .ibus_adr_o(ibus_adr),
    .ibus_dat_i(ibus_rdat), .ibus_ack_i(ibus_cyc & ibus_stb & ibus_hit),
    .ibus_err_i(ibus_cyc & ibus_stb & ~ibus_hit),
    .dbus_cyc_o(dbus_cyc), .dbus_stb_o(dbus_stb), .dbus_we_o(dbus_we),
    .dbus_sel_o(dbus_sel), .dbus_adr_o(dbus_adr), .dbus_dat_o(dbus_wdat),
    .dbus_dat_i(dbus_rdat), .dbus_ack_i(dbus_cyc & dbus_stb & dbus_hit),
    .dbus_err_i(dbus_cyc & dbus_stb & ~dbus_hit),
    .irq_mtip(1'b0), .irq_msip(1'b0), .irq_meip(1'b0), .mtime(mtime)
  );

  // ---------------- Memory ----------------
  assign ibus_hit = (ibus_adr[31:17] == 15'h4000);  // 0x8000_0000 .. 0x8001_FFFF
  assign dbus_hit = (dbus_adr[31:17] == 15'h4000);

  // Fetch returns the 32 bits starting at the halfword address.
  always @* begin
    if (ibus_adr[1])
      ibus_rdat = {mem[(ibus_adr[16:2] + 15'd1)][15:0], mem[ibus_adr[16:2]][31:16]};
    else
      ibus_rdat = mem[ibus_adr[16:2]];
    dbus_rdat = mem[dbus_adr[16:2]];
  end

  always @(posedge clk) begin
    if (dbus_cyc && dbus_stb && dbus_we && dbus_hit) begin
      if (dbus_sel[0]) mem[dbus_adr[16:2]][7:0]   <= dbus_wdat[7:0];
      if (dbus_sel[1]) mem[dbus_adr[16:2]][15:8]  <= dbus_wdat[15:8];
      if (dbus_sel[2]) mem[dbus_adr[16:2]][23:16] <= dbus_wdat[23:16];
      if (dbus_sel[3]) mem[dbus_adr[16:2]][31:24] <= dbus_wdat[31:24];
    end
  end

  // ---------------- Stimulus ----------------
  initial begin
    for (i = 0; i < DEPTH; i = i + 1) mem[i] = 32'd0;
    if ($value$plusargs("hex=%s", hex_file)) $readmemh(hex_file, mem);
    else begin
      $display("RESULT FAIL code=-1 cycles=0 writes=0 wsig=0 (no +hex)");
      $finish;
    end
    if ($value$plusargs("tohost=%h", tohost)) ;
    if ($value$plusargs("max_cycles=%d", max_cycles)) ;
    repeat (5) @(posedge clk);
    #1 rst_n = 1'b1;
  end

  // ---------------- Monitor ----------------
  always @(posedge clk) begin
    mtime <= mtime + 64'd1;
    if (rst_n) begin
      cycles <= cycles + 32'd1;
      if (dbus_cyc && dbus_stb && dbus_we && dbus_hit) begin
        writes <= writes + 32'd1;
        wsig   <= {wsig[30:0], wsig[31]} ^ dbus_adr ^ dbus_wdat ^ {28'd0, dbus_sel};
        if (dbus_adr == tohost && dbus_wdat[0]) begin
          $display("RESULT %s code=%0d cycles=%0d writes=%0d wsig=%08x",
                   (dbus_wdat[31:1] == 31'd0) ? "PASS" : "FAIL", dbus_wdat[31:1],
                   cycles + 32'd1, writes + 32'd1,
                   {wsig[30:0], wsig[31]} ^ dbus_adr ^ dbus_wdat ^ {28'd0, dbus_sel});
          $finish;
        end
      end
      if (^{ibus_adr, dbus_cyc} === 1'bx) begin
        $display("RESULT FAIL code=-2 cycles=%0d writes=%0d wsig=%08x (X on bus)",
                 cycles, writes, wsig);
        $finish;
      end
      if (cycles >= max_cycles) begin
        $display("RESULT FAIL code=-3 cycles=%0d writes=%0d wsig=%08x (timeout)",
                 cycles, writes, wsig);
        $finish;
      end
    end
  end

endmodule

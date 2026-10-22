// apb_slave_model.sv - APB4 slave model with random wait states.
//   1 KB register space (paddr[11:2]), byte writes by PSTRB, PSLVERR at
//   offset ERR_OFF, 0..MAX_WAIT wait states per access (random). Checks the
//   master's protocol and counts violations in `violations`:
//     - PENABLE only after a SETUP cycle (PSEL=1, PENABLE=0)
//     - PADDR/PWRITE/PWDATA/PSTRB stable from SETUP to the end of ACCESS
//     - PSTRB = 0 for reads
`timescale 1ns/1ps

module apb_slave_model #(
  parameter int          MAX_WAIT = 3,
  parameter logic [11:0] ERR_OFF  = 12'hFFC
) (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        psel,
  input  logic        penable,
  input  logic        pwrite,
  input  logic [11:0] paddr,
  input  logic [31:0] pwdata,
  input  logic [3:0]  pstrb,
  output logic [31:0] prdata,
  output logic        pready,
  output logic        pslverr
);

  logic [31:0] mem [1024];
  int          wait_left;
  int          violations = 0;
  int          accesses = 0;
  int          waits_total = 0;
  logic        in_access;
  logic [11:0] s_addr;
  logic        s_write;
  logic [31:0] s_wdata;
  logic [3:0]  s_strb;

  initial foreach (mem[i]) mem[i] = 32'h0;

  assign pready  = psel && penable && (wait_left == 0);
  assign pslverr = pready && (paddr == ERR_OFF);
  assign prdata  = (psel && penable && !pwrite) ? mem[paddr[11:2]] : 32'hxxxx_xxxx;

  always @(posedge clk) begin
    if (!rst_n) begin
      in_access <= 0;
      wait_left <= 0;
    end else begin
      // SETUP cycle: capture and choose the number of wait states
      if (psel && !penable) begin
        if (in_access) violations++;  // new SETUP without finishing ACCESS
        s_addr <= paddr; s_write <= pwrite; s_wdata <= pwdata; s_strb <= pstrb;
        if (!pwrite && pstrb != 0) violations++;
        wait_left <= $urandom_range(0, MAX_WAIT);
        in_access <= 1;
      end
      if (psel && penable) begin
        if (!in_access) violations++;  // ACCESS without SETUP
        if (paddr != s_addr || pwrite != s_write || pstrb != s_strb ||
            (pwrite && pwdata != s_wdata)) violations++;
        if (wait_left > 0) begin
          wait_left <= wait_left - 1;
          waits_total++;
        end else begin
          accesses++;
          in_access <= 0;
          if (pwrite && paddr != ERR_OFF)
            for (int b = 0; b < 4; b++)
              if (pstrb[b]) mem[paddr[11:2]][b*8 +: 8] <= pwdata[b*8 +: 8];
        end
      end
    end
  end

endmodule

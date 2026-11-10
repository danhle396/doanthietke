// ============================================================================
// wb_stage.sv - Write-back stage.
//   Writes the register file, signals retirement (minstret), produces the
//   per-instruction performance events and (simulation only) prints the
//   commit log selected with +commitlog=<file> (format close to
//   `spike --log-commits`).
//
// Ports:
//   wb_*        : mem_wb register contents
//   rf_*        : register file write port
//   retire      : an instruction retires this cycle
//   instret_inc : retire and the instruction did not write minstret
//   ev_*        : retired-instruction events for mhpmcounter3..6, 10
// ============================================================================
module wb_stage (
  input  logic        clk,
  input  logic        wb_valid,
  input  logic [31:0] wb_pc,
  input  logic [31:0] wb_insn,
  input  logic        wb_is_c,
  input  logic [4:0]  wb_rd,
  input  logic        wb_rd_we,
  input  logic [31:0] wb_result,
  input  logic        wb_is_load,
  input  logic        wb_is_store,
  input  logic [31:0] wb_mem_addr,
  input  logic [31:0] wb_store_data,
  input  logic [1:0]  wb_mem_size,
  input  logic        wb_is_branch,
  input  logic        wb_is_jump,
  input  logic        wb_mispred,
  input  logic        wb_instret_noinc,
  output logic        rf_we,
  output logic [4:0]  rf_waddr,
  output logic [31:0] rf_wdata,
  output logic        retire,
  output logic        instret_inc,
  output logic        ev_branch,
  output logic        ev_branch_miss,
  output logic        ev_jump,
  output logic        ev_jump_miss,
  output logic        ev_compressed
);

  assign rf_we    = wb_valid && wb_rd_we;
  assign rf_waddr = wb_rd;
  assign rf_wdata = wb_result;

  assign retire         = wb_valid;
  assign instret_inc    = wb_valid && !wb_instret_noinc;
  assign ev_branch      = wb_valid && wb_is_branch;
  assign ev_branch_miss = wb_valid && wb_is_branch && wb_mispred;
  assign ev_jump        = wb_valid && wb_is_jump;
  assign ev_jump_miss   = wb_valid && wb_is_jump && wb_mispred;
  assign ev_compressed  = wb_valid && wb_is_c;

`ifndef SYNTHESIS
  // ---------------- Commit log (simulation only) ----------------
  integer commit_fd = 0;
  string  commit_file;

  initial begin
    if ($value$plusargs("commitlog=%s", commit_file)) begin
      commit_fd = $fopen(commit_file, "w");
    end
  end

  always_ff @(posedge clk) begin
    if (commit_fd != 0 && wb_valid) begin
      if (wb_is_c) $fwrite(commit_fd, "core   0: 3 0x%08x (0x%04x)", wb_pc, wb_insn[15:0]);
      else         $fwrite(commit_fd, "core   0: 3 0x%08x (0x%08x)", wb_pc, wb_insn);
      if (wb_rd_we && wb_rd != 5'd0) begin
        if (wb_rd < 5'd10) $fwrite(commit_fd, " x%0d  0x%08x", wb_rd, wb_result);
        else               $fwrite(commit_fd, " x%0d 0x%08x", wb_rd, wb_result);
      end
      if (wb_is_load) $fwrite(commit_fd, " mem 0x%08x", wb_mem_addr);
      if (wb_is_store) begin
        case (wb_mem_size)
          2'b00:   $fwrite(commit_fd, " mem 0x%08x 0x%02x", wb_mem_addr, wb_store_data[7:0]);
          2'b01:   $fwrite(commit_fd, " mem 0x%08x 0x%04x", wb_mem_addr, wb_store_data[15:0]);
          default: $fwrite(commit_fd, " mem 0x%08x 0x%08x", wb_mem_addr, wb_store_data);
        endcase
      end
      $fwrite(commit_fd, "\n");
    end
  end

  final begin
    if (commit_fd != 0) $fclose(commit_fd);
  end
`endif

`ifdef COSIM
  // ---------------- Co-simulation hook (cosim/cosim_main.cpp) ----------------
  // Every retired instruction is passed to the C++ harness, which compares it
  // with the next instruction committed by Spike (lock-step while running).
  import "DPI-C" function void cosim_commit(
    input int pc, input int insn, input bit is_c, input bit rd_we, input int rd, input int rd_val,
    input bit is_load, input bit is_store, input int addr, input int st_data, input int size);

  always_ff @(posedge clk) begin
    if (wb_valid)
      cosim_commit(wb_pc, wb_is_c ? {16'b0, wb_insn[15:0]} : wb_insn, wb_is_c,
                   wb_rd_we && (wb_rd != 5'd0), {27'b0, wb_rd}, wb_result, wb_is_load, wb_is_store,
                   wb_mem_addr, wb_store_data, {30'b0, wb_mem_size});
  end
`endif

endmodule

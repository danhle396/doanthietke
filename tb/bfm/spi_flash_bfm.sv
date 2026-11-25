`timescale 1ns/1ps

module spi_flash_bfm #(
  parameter int T_PP_NS = 20000,
  parameter int T_SE_NS = 50000
) (
  input  logic sclk,
  input  logic mosi,
  input  logic cs_n,
  output logic miso
);

  logic [7:0] mem [int];
  bit         wip = 0, wel = 0;
  int         n_cmd[byte];      // command statistics
  int         errors = 0;       // protocol violations (CS released inside a byte)
  int         ignored = 0;      // commands ignored (busy, or program/erase without WEL)

  // per-transaction state
  logic [7:0] cmd, in_sh, out_byte;
  int         in_bits, n_in, out_bit;
  bit         out_en;
  int         addr;
  logic [7:0] page_buf [$];

  function automatic logic [7:0] init_byte(input int a);
    return 8'((a * 7 + 3) & 8'hFF);
  endfunction

  function automatic logic [7:0] rd_mem(input int a);
    a = a & 32'h3F_FFFF;
    if (mem.exists(a)) return mem[a];
    return (a < 4096) ? init_byte(a) : 8'hFF;
  endfunction

  initial miso = 1'b0;

  always @(negedge cs_n) begin
    in_bits = 0; n_in = 0; out_en = 0; out_bit = 0; cmd = 8'h00; addr = 0;
    page_buf.delete();
  end

  always @(posedge sclk) begin
    if (cs_n === 1'b0) begin
      in_sh = {in_sh[6:0], mosi};
      in_bits++;
      if (in_bits == 8) begin
        in_bits = 0;
        rx_byte(in_sh);
      end
    end
  end

  always @(negedge sclk) begin
    if (cs_n === 1'b0 && out_en) begin
      miso = out_byte[7 - out_bit];
      out_bit++;
      if (out_bit == 8) begin
        out_bit = 0;
        out_byte = next_out();
      end
    end
  end

  always @(posedge cs_n) begin
    miso = 1'b0;
    if (in_bits != 0) errors++;
    if (!wip && n_in >= 4 && wel) begin
      if (cmd == 8'h02) program_page();
      else if (cmd == 8'h20) erase_sector();
    end else if (!wip && n_in >= 1 && (cmd == 8'h02 || cmd == 8'h20) && !wel) begin
      ignored++;  // program/erase without WREN: ignored like a real device
    end
  end

  task automatic rx_byte(input logic [7:0] b);
    n_in++;
    if (n_in == 1) begin
      cmd = b;
      n_cmd[b]++;
      if (wip && b != 8'h05) begin
        cmd = 8'h00;  // busy: ignore
        ignored++;
        return;
      end
      case (b)
        8'h9F: begin out_en = 1; out_byte = 8'hEF; addr = 0; end
        8'h05: begin out_en = 1; out_byte = {6'b0, wel, wip}; end
        8'h06: wel = 1;
        8'h04: wel = 0;
        default: ;
      endcase
    end else if (n_in <= 4 && (cmd == 8'h03 || cmd == 8'h02 || cmd == 8'h20)) begin
      addr = (addr << 8) | b;
      if (n_in == 4 && cmd == 8'h03) begin
        out_en = 1;
        out_byte = rd_mem(addr);
      end
    end else if (cmd == 8'h02) begin
      if (page_buf.size() < 256) page_buf.push_back(b);
    end
  endtask

  function automatic logic [7:0] next_out();
    case (cmd)
      8'h9F: begin
        addr++;
        return (addr == 1) ? 8'h40 : (addr == 2) ? 8'h16 : 8'h00;
      end
      8'h05: return {6'b0, wel, wip};
      8'h03: begin
        addr++;
        return rd_mem(addr);
      end
      default: return 8'h00;
    endcase
  endfunction

  task automatic program_page();
    int base, a;
    base = addr & ~32'hFF;
    a = addr & 32'hFF;
    foreach (page_buf[i]) begin
      mem[(base + a) & 32'h3F_FFFF] = rd_mem(base + a) & page_buf[i];
      a = (a + 1) & 32'hFF;
    end
    fork begin
      wip = 1;
      #(T_PP_NS);
      wip = 0;
      wel = 0;
    end join_none
  endtask

  task automatic erase_sector();
    int base;
    base = addr & ~32'hFFF;
    for (int i = 0; i < 4096; i++) mem[(base + i) & 32'h3F_FFFF] = 8'hFF;
    fork begin
      wip = 1;
      #(T_SE_NS);
      wip = 0;
      wel = 0;
    end join_none
  endtask

endmodule

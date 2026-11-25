module dbus_xbar #(
  parameter logic [31:0] RAM_BASE = 32'h8000_0000,
  parameter logic [31:0] RAM_SIZE = 32'h0002_0000,
  parameter logic [31:0] APB_BASE = 32'h1000_0000,
  parameter logic [31:0] APB_SIZE = 32'h0001_0000
) (
  // master
  input  logic        m_cyc_i,
  input  logic        m_stb_i,
  input  logic        m_we_i,
  input  logic [3:0]  m_sel_i,
  input  logic [31:0] m_adr_i,
  input  logic [31:0] m_dat_i,
  output logic [31:0] m_dat_o,
  output logic        m_ack_o,
  output logic        m_err_o,
  // RAM slave
  output logic        ram_cyc_o,
  output logic        ram_stb_o,
  output logic        ram_we_o,
  output logic [3:0]  ram_sel_o,
  output logic [31:0] ram_adr_o,
  output logic [31:0] ram_dat_o,
  input  logic [31:0] ram_dat_i,
  input  logic        ram_ack_i,
  // APB bridge slave
  output logic        apb_cyc_o,
  output logic        apb_stb_o,
  output logic        apb_we_o,
  output logic [3:0]  apb_sel_o,
  output logic [31:0] apb_adr_o,
  output logic [31:0] apb_dat_o,
  input  logic [31:0] apb_dat_i,
  input  logic        apb_ack_i,
  input  logic        apb_err_i
);

  logic in_ram, in_apb;

  assign in_ram = (m_adr_i >= RAM_BASE) && ((m_adr_i - RAM_BASE) < RAM_SIZE);
  assign in_apb = (m_adr_i >= APB_BASE) && ((m_adr_i - APB_BASE) < APB_SIZE);

  assign ram_cyc_o = m_cyc_i && in_ram;
  assign ram_stb_o = m_stb_i && in_ram;
  assign ram_we_o  = m_we_i;
  assign ram_sel_o = m_sel_i;
  assign ram_adr_o = m_adr_i;
  assign ram_dat_o = m_dat_i;

  assign apb_cyc_o = m_cyc_i && in_apb;
  assign apb_stb_o = m_stb_i && in_apb;
  assign apb_we_o  = m_we_i;
  assign apb_sel_o = m_sel_i;
  assign apb_adr_o = m_adr_i;
  assign apb_dat_o = m_dat_i;

  always_comb begin
    if (in_ram) begin
      m_ack_o = ram_ack_i;
      m_err_o = 1'b0;
      m_dat_o = ram_dat_i;
    end else if (in_apb) begin
      m_ack_o = apb_ack_i;
      m_err_o = apb_err_i;
      m_dat_o = apb_dat_i;
    end else begin
      m_ack_o = 1'b0;
      m_err_o = m_cyc_i && m_stb_i;
      m_dat_o = 32'b0;
    end
  end

endmodule

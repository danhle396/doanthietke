// tb_common.svh - shared helpers for self-checking unit testbenches.
//   `TB_INIT       : reads +seed=<n> (default 1), prints it
//   `CHECK(c, msg) : counts an error and prints msg when c is false
//   tb_finish()    : prints PASS and $finish, or FAIL and $fatal(1)
//   `TB_TIMEOUT(n) : fails after n time units
// Use inside a module that declares `int unsigned seed;` via `TB_DECLS.

`define TB_DECLS \
  int unsigned seed; \
  int errors = 0; \
  int checks = 0;

`define TB_INIT \
  begin \
    if (!$value$plusargs("seed=%d", seed)) seed = 1; \
    $display("[%m] seed=%0d", seed); \
    void'($urandom(seed)); \
  end

`define CHECK(cond, msg) \
  begin \
    checks++; \
    if (!(cond)) begin \
      errors++; \
      if (errors <= 20) $display("ERROR @%0t: %s", $time, msg); \
    end \
  end

`define TB_TIMEOUT(t) \
  initial begin \
    #(t); \
    $display("FAIL: timeout"); \
    $fatal(1, "timeout"); \
  end

`define TB_FINISH \
  begin \
    if (errors == 0) begin \
      $display("[%m] %0d checks passed", checks); \
      $display("PASS"); \
      $finish; \
    end else begin \
      $display("FAIL: %0d errors in %0d checks", errors, checks); \
      $fatal(1, "FAIL"); \
    end \
  end

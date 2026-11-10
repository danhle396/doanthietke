// ============================================================================
// cosim_main.cpp - Verilator C++ co-simulation of soc_top with Spike in
//   lock-step.
//   The RTL (built with -DCOSIM) runs the program image; Spike, the RISC-V
//   reference ISA simulator, runs the same ELF as a child process and writes
//   its commit log (--log-commits) into a pipe. Every instruction retired by
//   the RTL (DPI call cosim_commit() from wb_stage) is compared at once with
//   the next instruction committed by Spike: pc, encoding, destination
//   register and value, load address, store address and data. The run stops
//   at the first difference and prints the last matching instructions.
//   Values read from cycle/time/instret/mhpmcounter CSRs depend on timing:
//   they are "tainted" and followed through registers and memory (rules of
//   scripts/compare_spike.py). If the control flow diverges right after a
//   branch on tainted data (e.g. printing a cycle count), the lock-step ends
//   and only the exit codes written to tohost are compared. Reads of
//   misa/marchid/mimpid are implementation defined (KNOWN).
//
// Plusargs:
//   +elf=<file> +hex=<file>      program (ELF for Spike, hex for the RTL RAM)
//   +tohost=<hex>                address of tohost (end of program)
//   +isa=<string>                Spike --isa (default rv32imc_zicsr_zifencei_zicntr)
//   +spike=<path>                Spike executable (default "spike")
//   +max_cycles=<n>              timeout (default 50,000,000)
//   +trace_csv=<file> +trace_from=<n> +trace_n=<n>
//                                write compared instructions n..n+N-1 as CSV
// Output: one line "COSIM <MATCH|KNOWN|DIFF> <detail> | commits=... masked=... cycles=..."
// Exit code: 0 = MATCH or KNOWN, 1 = DIFF / error / timeout.
// ============================================================================
#include <verilated.h>

#include "Vsoc_top.h"
#include "Vsoc_top__Dpi.h"

#include <fcntl.h>
#include <signal.h>
#include <sys/wait.h>
#include <unistd.h>

#include <cctype>
#include <chrono>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <deque>
#include <memory>
#include <string>
#include <unordered_set>
#include <vector>

namespace {

// One committed instruction.
struct Rec {
  uint32_t pc = 0, insn = 0;
  bool has_rd = false;
  uint32_t rd = 0, rd_val = 0;
  bool has_load = false;
  uint32_t load_addr = 0;
  bool has_store = false;
  uint32_t st_addr = 0, st_data = 0;
};

std::string fmt(const Rec& r) {
  char b[160];
  std::string s;
  snprintf(b, sizeof b, "pc 0x%08x (0x%0*x)", r.pc, (r.insn & 3) == 3 ? 8 : 4, r.insn);
  s += b;
  if (r.has_rd) { snprintf(b, sizeof b, " x%u=0x%08x", r.rd, r.rd_val); s += b; }
  if (r.has_load) { snprintf(b, sizeof b, " load[0x%08x]", r.load_addr); s += b; }
  if (r.has_store) { snprintf(b, sizeof b, " store[0x%08x]=0x%x", r.st_addr, r.st_data); s += b; }
  return s;
}

// ---------------- Spike as a child process ----------------
class Spike {
 public:
  bool start(const std::string& exe, const std::string& isa, const std::string& elf) {
    int fd[2];
    if (pipe(fd) != 0) return false;
    pid_ = fork();
    if (pid_ < 0) return false;
    if (pid_ == 0) {                       // child: commit log (stderr) -> pipe
      dup2(fd[1], 2);
      int nul = open("/dev/null", O_WRONLY);
      if (nul >= 0) dup2(nul, 1);
      close(fd[0]);
      close(fd[1]);
      std::string isa_arg = "--isa=" + isa;
      execlp(exe.c_str(), exe.c_str(), isa_arg.c_str(), "--priv=m",
             "-m0x80000000:0x20000,0x1000F000:0x1000", "--log-commits", elf.c_str(),
             static_cast<char*>(nullptr));
      _exit(127);
    }
    close(fd[1]);
    in_ = fdopen(fd[0], "r");
    return in_ != nullptr;
  }

  // Next instruction committed in RAM (Spike boot ROM skipped); false at end.
  bool next(Rec& r) {
    char line[1024];
    while (in_ && fgets(line, sizeof line, in_)) {
      if (parse(line, r)) {
        if (r.pc >= 0x80000000u) return true;
      } else {
        other_ = line;  // keep the last non-commit line (error message of Spike)
        while (!other_.empty() && (other_.back() == '\n' || other_.back() == '\r')) other_.pop_back();
      }
    }
    return false;
  }

  const std::string& last_message() const { return other_; }

  void stop() {
    if (pid_ > 0) {
      kill(pid_, SIGKILL);
      waitpid(pid_, nullptr, 0);
      pid_ = -1;
    }
    if (in_) {
      fclose(in_);
      in_ = nullptr;
    }
  }
  ~Spike() { stop(); }

 private:
  // "core   0: 3 0x80000000 (0x00000297) x5  0x80000000 mem 0x80001000 0x00000001"
  static bool parse(const char* line, Rec& r) {
    if (strncmp(line, "core", 4) != 0) return false;
    const char* p = strstr(line, ": ");
    unsigned priv = 0;
    unsigned long pc = 0, insn = 0;
    int n = 0;
    if (!p || sscanf(p + 2, "%u 0x%lx (0x%lx)%n", &priv, &pc, &insn, &n) != 3) return false;
    r = Rec{};
    r.pc = static_cast<uint32_t>(pc);
    r.insn = static_cast<uint32_t>(insn);
    std::vector<std::string> t;
    for (const char* q = p + 2 + n; *q;) {
      while (*q && isspace(static_cast<unsigned char>(*q))) q++;
      const char* s = q;
      while (*q && !isspace(static_cast<unsigned char>(*q))) q++;
      if (q > s) t.emplace_back(s, q - s);
    }
    for (size_t i = 0; i < t.size(); i++) {
      const std::string& k = t[i];
      bool next_is_val = i + 1 < t.size() && t[i + 1].rfind("0x", 0) == 0;
      if (k == "mem" && next_is_val) {
        uint32_t a = strtoul(t[i + 1].c_str(), nullptr, 16);
        if (i + 2 < t.size() && t[i + 2].rfind("0x", 0) == 0) {
          r.has_store = true;
          r.st_addr = a;
          r.st_data = strtoul(t[i + 2].c_str(), nullptr, 16);
          i += 2;
        } else {
          r.has_load = true;
          r.load_addr = a;
          i += 1;
        }
      } else if (k.size() > 1 && k[0] == 'x' && isdigit(static_cast<unsigned char>(k[1])) && next_is_val) {
        unsigned reg = atoi(k.c_str() + 1);
        if (reg != 0) {
          r.has_rd = true;
          r.rd = reg;
          r.rd_val = strtoul(t[i + 1].c_str(), nullptr, 16);
        }
        i += 1;
      } else if (next_is_val) {
        i += 1;  // CSR or other state written: name + value
      }
    }
    return true;
  }

  pid_t pid_ = -1;
  FILE* in_ = nullptr;
  std::string other_;
};

// ---------------- instruction helpers (same rules as compare_spike.py) ----------------
int csr_of(uint32_t insn) {
  if ((insn & 0x7F) == 0x73 && ((insn >> 12) & 7) != 0 && ((insn >> 12) & 7) != 4 && (insn & 3) == 3)
    return static_cast<int>((insn >> 20) & 0xFFF);
  return -1;
}

bool masked_csr(int c) {
  return c == 0xC00 || c == 0xC01 || c == 0xC02 || c == 0xC80 || c == 0xC81 || c == 0xC82 ||
         c == 0xB00 || c == 0xB02 || c == 0xB80 || c == 0xB82 || (c >= 0xB03 && c < 0xB20) ||
         (c >= 0xB83 && c < 0xBA0) || (c >= 0xC03 && c < 0xC20) || (c >= 0xC83 && c < 0xCA0);
}

const char* known_csr(int c) {
  switch (c) {
    case 0x301: return "misa";
    case 0xF12: return "marchid";
    case 0xF13: return "mimpid";
    default: return nullptr;
  }
}

std::vector<unsigned> src_regs(uint32_t insn) {
  if ((insn & 3) != 3) {  // compressed
    unsigned q = insn & 3, f3 = (insn >> 13) & 7, rd = (insn >> 7) & 31;
    unsigned r1p = 8 + ((insn >> 7) & 7), r2p = 8 + ((insn >> 2) & 7), rs2 = (insn >> 2) & 31;
    if (q == 0) {
      if (f3 == 0) return {2};
      if (f3 == 2) return {r1p};
      if (f3 == 6) return {r1p, r2p};
      return {};
    }
    if (q == 1) {
      if (f3 == 0) return {rd};
      if (f3 == 3) return rd == 2 ? std::vector<unsigned>{2} : std::vector<unsigned>{};
      if (f3 == 4) return ((insn >> 10) & 3) == 3 ? std::vector<unsigned>{r1p, r2p} : std::vector<unsigned>{r1p};
      if (f3 == 6 || f3 == 7) return {r1p};
      return {};
    }
    if (f3 == 0) return {rd};
    if (f3 == 2) return {2};
    if (f3 == 6) return {2, rs2};
    if (f3 == 4) {
      if (rs2 == 0) return {rd};
      return ((insn >> 12) & 1) ? std::vector<unsigned>{rd, rs2} : std::vector<unsigned>{rs2};
    }
    return {};
  }
  unsigned opc = insn & 0x7F, rs1 = (insn >> 15) & 31, rs2 = (insn >> 20) & 31;
  if (opc == 0x63 || opc == 0x23 || opc == 0x33) return {rs1, rs2};
  if (opc == 0x67 || opc == 0x03 || opc == 0x13) return {rs1};
  if (opc == 0x73 && ((insn >> 12) & 7) >= 1 && ((insn >> 12) & 7) <= 3) return {rs1};
  return {};
}

bool is_cti(uint32_t insn) {
  if ((insn & 3) == 3) return (insn & 0x7F) == 0x63 || (insn & 0x7F) == 0x67;
  unsigned f3 = (insn >> 13) & 7;
  if ((insn & 3) == 1) return f3 == 6 || f3 == 7;
  return (insn & 3) == 2 && f3 == 4 && ((insn >> 2) & 31) == 0;
}

// ---------------- lock-step checker ----------------
class Checker {
 public:
  enum State { RUN, MATCH, KNOWN, DIFF };

  Checker(Spike& spike, uint32_t tohost) : spike_(spike), tohost_(tohost) {}

  void open_trace(const std::string& file, uint64_t from, uint64_t count) {
    trace_ = fopen(file.c_str(), "w");
    trace_from_ = from;
    trace_n_ = count;
    if (trace_)
      fprintf(trace_, "cycle,idx,rtl_pc,rtl_insn,rtl_rd,rtl_val,spike_pc,spike_insn,spike_rd,spike_val,status\n");
  }

  void on_commit(const Rec& a, uint64_t cycle) {
    if (state_ != RUN) return;
    if (exit_only_) {
      if (a.has_store && a.st_addr == tohost_) finish_exit_only(a.st_data);
      return;
    }
    Rec b;
    if (!spike_.next(b)) {
      fail(cycle, a, nullptr, "Spike stopped before the RTL" +
           (spike_.last_message().empty() ? std::string() : " (spike: " + spike_.last_message() + ")"));
      return;
    }
    if (a.pc != b.pc || a.insn != b.insn) {
      if (prev_tainted_cti_) {  // counter-dependent branch: compare exit codes only
        exit_only_ = true;
        diverge_idx_ = n_;
        bool found = false;
        Rec s = b;
        do {
          if (s.has_store && s.st_addr == tohost_) {
            spike_exit_ = s.st_data;
            found = true;
            break;
          }
        } while (spike_.next(s));
        if (!found) {
          fail(cycle, a, &b, "Spike did not reach tohost after the counter-dependent branch");
          return;
        }
        if (a.has_store && a.st_addr == tohost_) finish_exit_only(a.st_data);
        return;
      }
      if (!known_.empty()) {
        finish(KNOWN, "#" + std::to_string(n_) + ": diverges after known difference (" + known_.back() + ")");
        return;
      }
      fail(cycle, a, &b, "pc/encoding differ");
      return;
    }
    // taint of this instruction's result
    bool tainted = false;
    for (unsigned r : src_regs(a.insn))
      if (r != 0 && (treg_ >> r) & 1u) tainted = true;
    if (a.has_load && tmem_.count(a.load_addr & ~3u)) tainted = true;
    int csr = csr_of(a.insn);
    if (csr >= 0 && masked_csr(csr)) tainted = true;
    prev_tainted_cti_ = tainted && is_cti(a.insn);
    const char* status = "MATCH";
    // stores
    bool st_eq = a.has_store == b.has_store && (!a.has_store || (a.st_addr == b.st_addr && a.st_data == b.st_data));
    if (!st_eq) {
      if (a.has_store && b.has_store && a.st_addr == b.st_addr && tainted) {
        masked_++;
        status = "MASKED";
      } else {
        fail(cycle, a, &b, "store differs");
        return;
      }
    }
    if (a.has_store) {
      if (tainted) tmem_.insert(a.st_addr & ~3u);
      else tmem_.erase(a.st_addr & ~3u);
    }
    // destination register
    bool rd_eq = a.has_rd == b.has_rd && (!a.has_rd || (a.rd == b.rd && a.rd_val == b.rd_val));
    if (!rd_eq) {
      if (a.has_rd && b.has_rd && a.rd == b.rd && tainted) {
        masked_++;
        status = "MASKED";
      } else if (csr >= 0 && known_csr(csr) && a.has_rd && b.has_rd && a.rd == b.rd) {
        char buf[128];
        snprintf(buf, sizeof buf, "pc 0x%08x read %s: RTL 0x%08x Spike 0x%08x", a.pc, known_csr(csr),
                 a.rd_val, b.rd_val);
        known_.push_back(buf);
        status = "KNOWN";
      } else if (!known_.empty()) {
        finish(KNOWN, "#" + std::to_string(n_) + ": diverges after known difference (" + known_.back() + ")");
        return;
      } else {
        fail(cycle, a, &b, "destination register differs");
        return;
      }
    }
    if (a.has_rd) {
      if (tainted) treg_ |= 1u << a.rd;
      else treg_ &= ~(1u << a.rd);
    }
    if (trace_ && n_ >= trace_from_ && n_ < trace_from_ + trace_n_)
      fprintf(trace_, "%llu,%llu,0x%08x,0x%x,%d,0x%08x,0x%08x,0x%x,%d,0x%08x,%s\n",
              static_cast<unsigned long long>(cycle), static_cast<unsigned long long>(n_), a.pc, a.insn,
              a.has_rd ? static_cast<int>(a.rd) : -1, a.rd_val, b.pc, b.insn,
              b.has_rd ? static_cast<int>(b.rd) : -1, b.rd_val, status);
    history_.push_back("  cycle " + std::to_string(cycle) + "  #" + std::to_string(n_) + "  " + fmt(a));
    if (history_.size() > 6) history_.pop_front();
    n_++;
    if (a.has_store && a.st_addr == tohost_) {
      char buf[160];
      snprintf(buf, sizeof buf, "%llu instructions identical, exit code %u", static_cast<unsigned long long>(n_),
               a.st_data >> 1);
      finish(a.st_data == 1 ? MATCH : DIFF, buf);
    }
  }

  State state() const { return state_; }
  const std::string& detail() const { return detail_; }
  uint64_t commits() const { return n_; }
  uint64_t masked() const { return masked_; }
  const std::vector<std::string>& known() const { return known_; }
  void timeout(const std::string& why) {
    if (state_ == RUN) finish(DIFF, why);
  }
  ~Checker() {
    if (trace_) fclose(trace_);
  }

 private:
  void finish(State s, const std::string& d) {
    state_ = s;
    detail_ = d;
  }

  void finish_exit_only(uint32_t rtl_exit) {
    char buf[256];
    snprintf(buf, sizeof buf,
             "%llu instructions identical in lock-step; control flow diverges after a branch on a counter "
             "value; exit codes RTL %u / Spike %u",
             static_cast<unsigned long long>(diverge_idx_), rtl_exit >> 1, spike_exit_ >> 1);
    finish(rtl_exit == spike_exit_ && rtl_exit == 1 ? MATCH : DIFF, buf);
  }

  void fail(uint64_t cycle, const Rec& a, const Rec* b, const std::string& what) {
    std::string d = "#" + std::to_string(n_) + " (cycle " + std::to_string(cycle) + "): " + what;
    fprintf(stderr, "[cosim] MISMATCH at instruction #%llu, cycle %llu: %s\n",
            static_cast<unsigned long long>(n_), static_cast<unsigned long long>(cycle), what.c_str());
    fprintf(stderr, "[cosim] last matching instructions:\n");
    for (const auto& h : history_) fprintf(stderr, "%s\n", h.c_str());
    fprintf(stderr, "[cosim]   RTL  : %s\n", fmt(a).c_str());
    fprintf(stderr, "[cosim]   Spike: %s\n", b ? fmt(*b).c_str() : "(end of commit log)");
    d += " | RTL " + fmt(a) + " | Spike " + (b ? fmt(*b) : std::string("(end)"));
    finish(DIFF, d);
  }

  Spike& spike_;
  uint32_t tohost_;
  State state_ = RUN;
  std::string detail_;
  uint64_t n_ = 0, masked_ = 0, diverge_idx_ = 0;
  uint32_t treg_ = 0, spike_exit_ = 0;
  std::unordered_set<uint32_t> tmem_;
  bool prev_tainted_cti_ = false, exit_only_ = false;
  std::vector<std::string> known_;
  std::deque<std::string> history_;
  FILE* trace_ = nullptr;
  uint64_t trace_from_ = 0, trace_n_ = 0;
};

Checker* g_checker = nullptr;
uint64_t g_cycle = 0;

std::string plusarg(VerilatedContext* ctx, const char* name, const char* dflt = "") {
  std::string key = std::string(name) + "=";
  const char* m = ctx->commandArgsPlusMatch(key.c_str());
  if (!m || !*m) return dflt;
  const char* eq = strchr(m, '=');
  return eq ? std::string(eq + 1) : std::string(dflt);
}

}  // namespace

// DPI-C import of wb_stage (called at every retired instruction)
void cosim_commit(int pc, int insn, svBit is_c, svBit rd_we, int rd, int rd_val, svBit is_load,
                  svBit is_store, int addr, int st_data, int size) {
  if (!g_checker) return;
  Rec r;
  r.pc = static_cast<uint32_t>(pc);
  r.insn = is_c ? (static_cast<uint32_t>(insn) & 0xFFFFu) : static_cast<uint32_t>(insn);
  r.has_rd = rd_we;
  r.rd = static_cast<uint32_t>(rd);
  r.rd_val = static_cast<uint32_t>(rd_val);
  r.has_load = is_load;
  r.load_addr = static_cast<uint32_t>(addr);
  r.has_store = is_store;
  r.st_addr = static_cast<uint32_t>(addr);
  uint32_t d = static_cast<uint32_t>(st_data);
  r.st_data = size == 0 ? (d & 0xFFu) : size == 1 ? (d & 0xFFFFu) : d;
  g_checker->on_commit(r, g_cycle);
}

int main(int argc, char** argv) {
  auto ctx = std::make_unique<VerilatedContext>();
  ctx->commandArgs(argc, argv);
  std::string elf = plusarg(ctx.get(), "elf");
  std::string isa = plusarg(ctx.get(), "isa", "rv32imc_zicsr_zifencei_zicntr");
  std::string spike_exe = plusarg(ctx.get(), "spike", "spike");
  uint32_t tohost = strtoul(plusarg(ctx.get(), "tohost", "0").c_str(), nullptr, 16);
  uint64_t max_cycles = strtoull(plusarg(ctx.get(), "max_cycles", "50000000").c_str(), nullptr, 10);
  if (elf.empty() || plusarg(ctx.get(), "hex").empty() || tohost == 0) {
    fprintf(stderr, "usage: Vcosim +elf=<f> +hex=<f> +tohost=<hex> [+isa=..] [+max_cycles=..]\n");
    return 2;
  }

  Spike spike;
  if (!spike.start(spike_exe, isa, elf)) {
    fprintf(stderr, "[cosim] cannot start %s\n", spike_exe.c_str());
    return 2;
  }
  Checker checker(spike, tohost);
  g_checker = &checker;
  std::string trace = plusarg(ctx.get(), "trace_csv");
  if (!trace.empty())
    checker.open_trace(trace, strtoull(plusarg(ctx.get(), "trace_from", "0").c_str(), nullptr, 10),
                       strtoull(plusarg(ctx.get(), "trace_n", "32").c_str(), nullptr, 10));

  auto top = std::make_unique<Vsoc_top>(ctx.get());
  top->clk = 0;
  top->rst_n = 0;
  top->uart_rx = 1;
  top->spi_miso = 0;
  top->gpio_i = 0;
  auto t0 = std::chrono::steady_clock::now();
  for (g_cycle = 0; checker.state() == Checker::RUN && !ctx->gotFinish(); g_cycle++) {
    if (g_cycle == 5) top->rst_n = 1;
    top->clk = 1;
    top->eval();
    ctx->timeInc(10);
    top->clk = 0;
    top->eval();
    ctx->timeInc(10);
    if (g_cycle >= max_cycles) checker.timeout("timeout after " + std::to_string(max_cycles) + " cycles");
  }
  if (checker.state() == Checker::RUN) checker.timeout("RTL simulation ended before tohost");
  double secs = std::chrono::duration<double>(std::chrono::steady_clock::now() - t0).count();
  top->final();
  spike.stop();

  static const char* names[] = {"RUN", "MATCH", "KNOWN", "DIFF"};
  std::string kn;
  for (const auto& k : checker.known()) kn += (kn.empty() ? "" : "; ") + k;
  printf("COSIM %s %s | commits=%llu masked=%llu cycles=%llu wall=%.2fs%s%s\n", names[checker.state()],
         checker.detail().c_str(), static_cast<unsigned long long>(checker.commits()),
         static_cast<unsigned long long>(checker.masked()), static_cast<unsigned long long>(g_cycle), secs,
         kn.empty() ? "" : " | known: ", kn.c_str());
  return checker.state() == Checker::DIFF ? 1 : 0;
}

#!/usr/bin/env bash
# Print versions of every tool used by the flow. Exit 1 if a mandatory tool is missing.
# Expects PATH/RISCV_PREFIX/VERILATOR/YOSYS/SPIKE to be exported by the Makefile.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail=0

show() {  # name mandatory command...
  local name=$1 mand=$2; shift 2
  local out rc
  out=$("$@" 2>&1); rc=$?
  out=$(printf "%s" "$out" | head -n 1)
  if [ $rc -eq 0 ] && [ -n "$out" ]; then
    printf "  %-14s OK    %s\n" "$name" "$out"
  else
    if [ "$mand" = 1 ]; then
      printf "  %-14s MISSING (mandatory)\n" "$name"; fail=1
    else
      printf "  %-14s missing (optional)\n" "$name"
    fi
  fi
}

echo "== Tool versions =="
show verilator 1 "${VERILATOR:-verilator}" --version
show yosys     1 "${YOSYS:-yosys}" -V
show gcc       1 "${RISCV_PREFIX}gcc" --version
show objdump   1 "${RISCV_PREFIX}objdump" --version
show spike     0 bash -c "command -v ${SPIKE:-spike} >/dev/null && ${SPIKE:-spike} --help 2>&1 | grep -m1 -o 'Spike RISC-V ISA Simulator[^)]*' || ls \$(command -v ${SPIKE:-spike})"
show dtc       0 dtc --version
show iverilog  0 bash -c "iverilog -V 2>&1 | head -n1"
show nextpnr   0 nextpnr-ecp5 --version
show opensta   0 sta -version
show make      1 make --version
show git       1 git --version
show g++       1 g++ --version
show python3   1 "$ROOT/.venv/bin/python" --version
show matplotlib 1 "$ROOT/.venv/bin/python" -c "import matplotlib; print('matplotlib', matplotlib.__version__)"
show pyelftools 1 "$ROOT/.venv/bin/python" -c "import elftools; print('pyelftools', elftools.__version__)"
show pandoc    0 pandoc --version
show genhtml   0 genhtml --version

echo "== RISC-V libgcc (rv32imc/ilp32) =="
lg=$("${RISCV_PREFIX}gcc" -march=rv32imc_zicsr_zifencei -mabi=ilp32 -print-libgcc-file-name 2>/dev/null)
if [ -f "$lg" ]; then echo "  $lg (exists)"; else echo "  NOT FOUND"; fail=1; fi
lg=$("${RISCV_PREFIX}gcc" -march=rv32i_zicsr_zifencei -mabi=ilp32 -print-libgcc-file-name 2>/dev/null)
if [ -f "$lg" ]; then echo "  $lg (exists, rv32i)"; else echo "  rv32i libgcc NOT FOUND"; fail=1; fi

echo "== third_party =="
for d in riscv-tests coremark; do
  if [ -d "$ROOT/third_party/$d/.git" ]; then
    echo "  $d @ $(git -C "$ROOT/third_party/$d" rev-parse HEAD)"
  else
    echo "  $d not fetched (run 'make fetch')"
  fi
done
exit $fail

#!/usr/bin/env bash
# Verilator lint (-Wall) of the whole RTL for every configuration of the matrix.
# Fails on any warning. Intentional waivers are in-source (lint_off + comment).
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
VERILATOR=${VERILATOR:-verilator}
FILES=$(grep -v '^#' rtl/rtl_files.f | tr '\n' ' ')
fail=0
configs=(
  "-GCORE_SC=0 -GENABLE_M=1 -GENABLE_C=1 -GBP_MODE=0"
  "-GCORE_SC=0 -GENABLE_M=1 -GENABLE_C=1 -GBP_MODE=1"
  "-GCORE_SC=0 -GENABLE_M=1 -GENABLE_C=1 -GBP_MODE=2"
  "-GCORE_SC=0 -GENABLE_M=1 -GENABLE_C=0 -GBP_MODE=2"
  "-GCORE_SC=0 -GENABLE_M=0 -GENABLE_C=0 -GBP_MODE=2"
  "-GCORE_SC=0 -GBHT_ENTRIES=16 -GBTB_ENTRIES=4"
  "-GCORE_SC=0 -GBHT_ENTRIES=1024 -GBTB_ENTRIES=64"
  "-GCORE_SC=1"
)
mkdir -p build
for cfg in "${configs[@]}"; do
  out=$($VERILATOR --lint-only -Wall --top-module soc_top $cfg $FILES 2>&1 | grep -E "^%")
  if [ -n "$out" ]; then
    echo "[lint] FAIL soc_top $cfg"; echo "$out" | head -40; fail=1
  else
    echo "[lint] clean soc_top $cfg"
  fi
done
exit $fail

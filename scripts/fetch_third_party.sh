#!/usr/bin/env bash
# Clone third-party sources (riscv-tests, coremark) into third_party/.
# Pinned commits are recorded in docs/env.md; set FETCH_LATEST=1 to skip pinning.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TP="$ROOT/third_party"
mkdir -p "$TP"

# name url pinned_commit
REPOS=(
  "riscv-tests https://github.com/riscv-software-src/riscv-tests 3df703cd52d5f0d8224e3c50bf03c6cb70efff98"
  "coremark https://github.com/eembc/coremark 1f483d5b8316753a742cbf5590caf5bd0a4e4777"
)

for entry in "${REPOS[@]}"; do
  read -r name url pin <<<"$entry"
  dst="$TP/$name"
  if [ ! -d "$dst/.git" ]; then
    echo "[fetch] cloning $name"
    git clone -q --recursive "$url" "$dst"
  else
    echo "[fetch] $name already present"
  fi
  if [ "${FETCH_LATEST:-0}" != "1" ] && [ "$pin" != "HEAD" ]; then
    if git -C "$dst" cat-file -e "$pin^{commit}" 2>/dev/null; then
      git -C "$dst" checkout -q "$pin"
      git -C "$dst" submodule update -q --init --recursive
    else
      echo "[fetch] WARNING: pinned commit $pin not found in $name, using HEAD"
    fi
  fi
  echo "[fetch] $name @ $(git -C "$dst" rev-parse HEAD)"
done

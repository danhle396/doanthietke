#!/usr/bin/env bash
# Install the tool environment of this project on a fresh Ubuntu 24.04
# (WSL2 on Windows, or a VM) with the same versions as docs/env.md.
#
#   bash scripts/setup_wsl.sh            # everything (needs sudo once for apt)
#   bash scripts/setup_wsl.sh --no-asic  # skip OpenLane image + sky130 PDK (~10 GB)
#
# Every step is skipped when its result already exists, so the script can be
# rerun after a failure. Tools go to ~/tools (Makefile and scripts/common.py
# add them to PATH), the PDK to ~/.volare. Build logs: ~/tools/src/*.log.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS="$HOME/tools"
SRC="$TOOLS/src"
JOBS="$(nproc)"
ASIC=1
[ "${1:-}" = "--no-asic" ] && ASIC=0

OSS_CAD_DATE="2026-03-11"
DTC_COMMIT="f99e3af0ecb67a9085478a9b8ddbcc25aa64931d"
SPIKE_COMMIT="436fc163a831218508378d7e7f8fd480994b64fe"
PANDOC_VER="3.6.4"
OPENLANE_IMAGE="ghcr.io/efabless/openlane2:2.3.10"
PDK_COMMIT="0fe599b2afb6708d281543108caf8310912f54af"

step() { printf '\n== %s ==\n' "$*"; }

# ---------------- Checks ----------------
. /etc/os-release
[ "${VERSION_ID:-}" = "24.04" ] || echo "WARNING: tested on Ubuntu 24.04, this is ${PRETTY_NAME:-unknown}"
case "$ROOT" in
  /mnt/*) echo "WARNING: project is on a Windows drive ($ROOT): slow and may break file permissions."
          echo "         Copy it into the Linux file system, e.g. ~/doanthietke, and run again." ;;
esac
if grep -q $'\r' "$ROOT/Makefile"; then
  echo "ERROR: files have Windows line endings (CRLF). Copy the folder instead of a Windows git checkout,"
  echo "       or run: git config core.autocrlf false && git rm -rq --cached . && git reset --hard"
  exit 1
fi
mkdir -p "$TOOLS" "$SRC"

# ---------------- apt packages ----------------
step "apt packages (sudo)"
sudo apt-get update -q
sudo apt-get install -y -q build-essential git make wget curl ca-certificates xz-utils \
  python3 python3-venv gcc-riscv64-unknown-elf binutils-riscv64-unknown-elf \
  bison flex gtkwave

# ---------------- OSS CAD Suite (Verilator, Yosys, nextpnr, Icarus, Volare) ----------------
step "OSS CAD Suite $OSS_CAD_DATE"
if [ ! -x "$TOOLS/oss-cad-suite/bin/verilator" ]; then
  tgz="oss-cad-suite-linux-x64-${OSS_CAD_DATE//-/}.tgz"
  wget -q --show-progress -O "$TOOLS/$tgz" \
    "https://github.com/YosysHQ/oss-cad-suite-build/releases/download/$OSS_CAD_DATE/$tgz"
  tar -xzf "$TOOLS/$tgz" -C "$TOOLS"
  rm -f "$TOOLS/$tgz"
else
  echo "present"
fi

# ---------------- dtc (needed by Spike at run time) ----------------
step "dtc @ ${DTC_COMMIT:0:7}"
if [ ! -x "$TOOLS/dtc/bin/dtc" ]; then
  [ -d "$SRC/dtc/.git" ] || git clone -q https://github.com/dgibson/dtc.git "$SRC/dtc"
  git -C "$SRC/dtc" checkout -q "$DTC_COMMIT"
  make -C "$SRC/dtc" -j"$JOBS" NO_PYTHON=1 NO_YAML=1 NO_VALGRIND=1 PREFIX="$TOOLS/dtc" install \
    > "$SRC/dtc_build.log" 2>&1
else
  echo "present"
fi
export PATH="$TOOLS/dtc/bin:$PATH"

# ---------------- Spike ----------------
step "Spike @ ${SPIKE_COMMIT:0:7} (about 15 minutes)"
if [ ! -x "$TOOLS/spike/bin/spike" ]; then
  [ -d "$SRC/riscv-isa-sim/.git" ] || git clone -q https://github.com/riscv-software-src/riscv-isa-sim "$SRC/riscv-isa-sim"
  git -C "$SRC/riscv-isa-sim" checkout -q "$SPIKE_COMMIT"
  rm -rf "$SRC/riscv-isa-sim/build" && mkdir "$SRC/riscv-isa-sim/build"
  # -g0: a debug build needs about 3.5 GB of disk
  (cd "$SRC/riscv-isa-sim/build" &&
   CFLAGS="-O2 -g0" CXXFLAGS="-O2 -g0" ../configure --prefix="$TOOLS/spike" \
     --without-boost --without-boost-asio --without-boost-regex > "$SRC/spike_conf.log" 2>&1 &&
   make -j"$JOBS" > "$SRC/spike_build.log" 2>&1 && make install >> "$SRC/spike_build.log" 2>&1)
  rm -rf "$SRC/riscv-isa-sim/build"
else
  echo "present"
fi

# ---------------- pandoc (report .docx) ----------------
step "pandoc $PANDOC_VER"
if [ ! -x "$TOOLS/pandoc/bin/pandoc" ]; then
  wget -q -O "$SRC/pandoc.tgz" \
    "https://github.com/jgm/pandoc/releases/download/$PANDOC_VER/pandoc-$PANDOC_VER-linux-amd64.tar.gz"
  mkdir -p "$TOOLS/pandoc"
  tar -xzf "$SRC/pandoc.tgz" -C "$TOOLS/pandoc" --strip-components=1
  rm -f "$SRC/pandoc.tgz"
else
  echo "present"
fi

# ---------------- make asic: OpenLane image + sky130 PDK ----------------
if [ "$ASIC" = 1 ]; then
  step "OpenLane image $OPENLANE_IMAGE"
  if ! docker info > /dev/null 2>&1; then
    echo "WARNING: docker not reachable. On Windows: Docker Desktop -> Settings -> Resources ->"
    echo "         WSL integration -> enable this distro, then rerun. 'make asic' is skipped until then."
  elif docker image inspect "$OPENLANE_IMAGE" > /dev/null 2>&1; then
    echo "present"
  else
    docker pull "$OPENLANE_IMAGE"
  fi
  step "sky130 PDK @ ${PDK_COMMIT:0:7}"
  if [ ! -d "$HOME/.volare/volare/sky130/versions/$PDK_COMMIT/sky130A" ]; then
    "$TOOLS/oss-cad-suite/bin/volare" enable --pdk sky130 --pdk-root "$HOME/.volare" "$PDK_COMMIT"
  else
    echo "present"
  fi
fi

# ---------------- Project: Python venv, third-party sources, check ----------------
step "project setup"
make -C "$ROOT" venv fetch check-env

cat <<EOF

Done. Next:
  cd $ROOT
  make regress          # lint + unit + riscv-tests + Spike + system test
  make asic             # ASIC layout (about 1 hour, Docker)
EOF

# Top-level Makefile – RISC-V RV32IMC SoC (UART + SPI)
# All heavy lifting is done by scripts in scripts/ (Python runs from .venv).

SHELL := /bin/bash
ROOT  := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

# ---- Tool discovery (no hard-coded toolchain paths) ----------------------
OSS_CAD ?= $(HOME)/tools/oss-cad-suite
empty :=
space := $(empty) $(empty)
EXTRA_PATH := $(wildcard $(OSS_CAD)/bin $(HOME)/tools/spike/bin $(HOME)/tools/dtc/bin $(HOME)/tools/pandoc/bin $(HOME)/tools/xpack-riscv-none-elf-gcc*/bin)
export PATH := $(subst $(space),:,$(strip $(EXTRA_PATH) $(PATH)))
export LD_LIBRARY_PATH := $(HOME)/tools/dtc/lib:$(LD_LIBRARY_PATH)

RISCV_PREFIX ?= $(firstword $(foreach p,riscv64-unknown-elf- riscv32-unknown-elf- riscv-none-elf-,$(if $(shell command -v $(p)gcc 2>/dev/null),$(p))))
VERILATOR    ?= verilator
YOSYS        ?= yosys
SPIKE        ?= spike
PYTHON       ?= $(ROOT)/.venv/bin/python
# system interpreter used to create .venv (the OSS CAD Suite python has no ensurepip)
SYS_PYTHON   ?= $(firstword $(wildcard /usr/bin/python3) python3)
JOBS         ?= $(shell nproc)
export RISCV_PREFIX VERILATOR YOSYS SPIKE PYTHON JOBS

.PHONY: all help check-env venv fetch lint unit sw isa spike systest perf cov synth docs regress clean

all: regress

help:
	@echo "Targets: check-env fetch lint unit sw isa spike systest perf cov synth docs regress clean"

$(PYTHON):
	$(SYS_PYTHON) -m venv $(ROOT)/.venv
	$(ROOT)/.venv/bin/pip install -q matplotlib pyelftools

venv: $(PYTHON)

check-env: $(PYTHON)
	@bash scripts/check_env.sh

fetch:
	bash scripts/fetch_third_party.sh

lint:
	@bash scripts/lint.sh

unit: $(PYTHON)
	$(PYTHON) scripts/run_unit.py

sw: $(PYTHON)
	$(PYTHON) scripts/build_sw.py

isa: $(PYTHON)
	$(PYTHON) scripts/run_isa.py --matrix

spike: $(PYTHON)
	$(PYTHON) scripts/compare_spike.py --all

systest: $(PYTHON)
	$(PYTHON) scripts/run_systest.py

perf: $(PYTHON)
	$(PYTHON) scripts/run_perf.py

cov: $(PYTHON)
	$(PYTHON) scripts/run_cov.py

synth: $(PYTHON)
	$(PYTHON) scripts/synth_report.py

docs: $(PYTHON)
	$(PYTHON) scripts/build_docs.py

regress: $(PYTHON)
	$(PYTHON) scripts/regress.py

clean:
	rm -rf build obj_dir

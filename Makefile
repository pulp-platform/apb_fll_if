# Copyright 2025 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51

BENDER          ?= bender
VSIM            ?= vsim
PEAKRDL         ?= peakrdl
RISCV_GCC       ?= riscv32-unknown-elf-gcc
RISCV_GCC_FLAGS ?= -march=rv32imc -mabi=ilp32 -O2 -Wall -std=c11
OSEDA           ?=
VLT             ?= $(OSEDA) verilator
WORK_DIR         = work
VLT_WORKDIR      = work-vlt
VLT_BIN          = $(VLT_WORKDIR)/Vapb_fll_tb

SW_BUILD_DIR = sw/build
SW_SRCS      = sw/fll.c
SW_OBJS      = $(addprefix $(SW_BUILD_DIR)/, $(notdir $(SW_SRCS:.c=.o)))
SW_INCDIRS   = -I sw/include

.PHONY: all compile run run-batch vlt-build vlt-run clean

all: sw/include/fll_regs.h $(SW_OBJS)

# ------------------------------------------------------------
# Software driver
# ------------------------------------------------------------

sw/include/fll_regs.h: rdl/fll.rdl
	@mkdir -p $(dir $@)
	$(PEAKRDL) c-header $< -o $@ -b ltoh
	@sed -i '1i// Copyright 2025 ETH Zurich and University of Bologna.\n// Licensed under the Apache License, Version 2.0, see LICENSE for details.\n// SPDX-License-Identifier: Apache-2.0\n' $@

$(SW_BUILD_DIR)/%.o: sw/%.c sw/include/fll_regs.h sw/include/fll.h
	@mkdir -p $(SW_BUILD_DIR)
	$(RISCV_GCC) $(RISCV_GCC_FLAGS) $(SW_INCDIRS) -c $< -o $@

# ------------------------------------------------------------
# Questasim simulation
# ------------------------------------------------------------

build/compile.tcl: Bender.yml Bender.lock
	@mkdir -p build
	$(BENDER) script vsim -t apb_fll_test > $@

compile: build/compile.tcl
	$(VSIM) -c -do "do build/compile.tcl; quit" 2>&1 | tee build/compile.log

run-batch: compile
	$(VSIM) -c $(WORK_DIR).apb_fll_tb -do "run -all; quit" 2>&1 | tee build/sim.log

run: compile
	$(VSIM) -voptargs=+acc $(WORK_DIR).apb_fll_tb -do "log -r /*" 2>&1 | tee build/sim.log

# ------------------------------------------------------------
# Verilator simulation
# ------------------------------------------------------------

vlt-build:
	$(VLT) $(shell $(BENDER) script verilator -t apb_fll_test) \
	    --binary --top-module apb_fll_tb \
	    --timing --timescale 1ns/1ps \
	    -Wno-fatal -Mdir $(VLT_WORKDIR)

vlt-run: vlt-build
	$(OSEDA) ./$(VLT_BIN)

# ------------------------------------------------------------

clean:
	rm -rf build $(WORK_DIR) $(VLT_WORKDIR) $(SW_BUILD_DIR) transcript vsim.wlf

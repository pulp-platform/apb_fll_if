BENDER       ?= bender
VSIM         ?= vsim
WORK_DIR      = work
OSEDA        ?=
VLT          ?= $(OSEDA) verilator
VLT_WORKDIR   = work-vlt
VLT_BIN       = $(VLT_WORKDIR)/Vapb_fll_tb

.PHONY: compile run run-batch vlt-build vlt-run clean

build/compile.tcl: Bender.yml Bender.lock
	@mkdir -p build
	$(BENDER) script vsim -t apb_fll_test > $@

compile: build/compile.tcl
	$(VSIM) -c -do "do build/compile.tcl; quit" 2>&1 | tee build/compile.log

run-batch: compile
	$(VSIM) -c $(WORK_DIR).apb_fll_tb -do "run -all; quit" 2>&1 | tee build/sim.log

run: compile
	$(VSIM) -voptargs=+acc $(WORK_DIR).apb_fll_tb -do "log -r /*" 2>&1 | tee build/sim.log

vlt-build:
	$(VLT) $(shell $(BENDER) script verilator -t apb_fll_test) \
	    --binary --top-module apb_fll_tb \
	    --timing --timescale 1ns/1ps \
	    -Wno-fatal -Mdir $(VLT_WORKDIR)

vlt-run: vlt-build
	$(OSEDA) ./$(VLT_BIN)

clean:
	rm -rf build $(WORK_DIR) $(VLT_WORKDIR) transcript vsim.wlf

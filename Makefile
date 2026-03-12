BENDER   ?= bender
VSIM     ?= vsim
WORK_DIR  = work

.PHONY: compile sim clean

build/compile.tcl: Bender.yml Bender.lock
	@mkdir -p build
	$(BENDER) script vsim -t apb_fll_test > $@

compile: build/compile.tcl
	$(VSIM) -c -do "do build/compile.tcl; quit" 2>&1 | tee build/compile.log

run-batch: compile
	$(VSIM) -c $(WORK_DIR).apb_fll_tb -do "run -all; quit" 2>&1 | tee build/sim.log

run: compile
	$(VSIM) -voptargs=+acc $(WORK_DIR).apb_fll_tb -do "log -r /*" 2>&1 | tee build/sim.log

clean:
	rm -rf build $(WORK_DIR) transcript vsim.wlf

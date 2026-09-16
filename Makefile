SHELL := /bin/bash

TEST ?= dma_smoke_test
SEED ?= 1
PROFILE ?= smoke
JOBS ?= 4
BUILD_DIR ?= build
RESULT_DIR ?= results/manual
TOP ?= tb_top

RTL_SOURCES := \
	rtl/dma_pkg.sv \
	rtl/dma_fifo.sv \
	rtl/dma_regs.sv \
	rtl/dma_read_engine.sv \
	rtl/dma_write_engine.sv \
	rtl/dma_ctrl_fsm.sv \
	rtl/dma_crc32.sv \
	rtl/dma_top.sv

TB_SOURCES := \
	tb/interfaces/axil_if.sv \
	tb/interfaces/axi_if.sv \
	tb/interfaces/reset_ctrl_if.sv \
	tb/interfaces/dma_probe_if.sv \
	model/dma_ref_pkg.sv \
	tb/uvc/axil/axil_uvc_pkg.sv \
	tb/uvc/axi_mem/axi_mem_uvc_pkg.sv \
	tb/env/dma_env_pkg.sv \
	tb/seq/dma_seq_pkg.sv \
	tb/tests/dma_test_pkg.sv \
	tb/sva/dma_sva.sv \
	tb/top/tb_top.sv

.PHONY: help check-tools lint rtl-smoke compile test wave smoke regression formal coverage \
	cpp-test script-test structure-check reuse-demo clean

help:
	@echo "VeriDMA targets"
	@echo "  make lint                         RTL lint with Verilator"
	@echo "  make compile                      Compile UVM testbench with xsim"
	@echo "  make test TEST=<name> SEED=<n>    Run one deterministic UVM test"
	@echo "  make wave TEST=<name> SEED=<n>    Rerun with waveform database"
	@echo "  make regression PROFILE=smoke     Parallel regression driver"
	@echo "  make formal                       Run all SymbiYosys proofs"
	@echo "  make cpp-test                     Test the independent CRC model"
	@echo "  make script-test                  Test regression and triage scripts"

check-tools:
	@command -v python3 >/dev/null || { echo "python3 is required"; exit 1; }
	@command -v make >/dev/null || { echo "make is required"; exit 1; }

lint:
	@command -v verilator >/dev/null || { echo "verilator is required for lint"; exit 2; }
	verilator --lint-only --Wall -Wno-fatal --timing --top-module dma_top $(RTL_SOURCES)

rtl-smoke:
	@command -v iverilog >/dev/null || { echo "iverilog is required for RTL smoke"; exit 2; }
	mkdir -p $(BUILD_DIR)/smoke
	iverilog -g2012 -s dma_smoke_tb -o $(BUILD_DIR)/smoke/dma_smoke \
		$(RTL_SOURCES) tb/smoke/dma_smoke_tb.sv
	vvp $(BUILD_DIR)/smoke/dma_smoke

$(BUILD_DIR)/xsim/.compiled: $(RTL_SOURCES) $(TB_SOURCES)
	@command -v xvlog >/dev/null || { echo "Vivado xsim tools are required"; exit 2; }
	mkdir -p $(BUILD_DIR)/xsim
	cd $(BUILD_DIR)/xsim && xvlog -sv -L uvm \
		-i ../../rtl -i ../../tb -i ../../tb/uvc/axil -i ../../tb/uvc/axi_mem \
		-i ../../tb/env -i ../../tb/seq -i ../../tb/tests \
		$(addprefix ../../,$(RTL_SOURCES) $(TB_SOURCES))
	cd $(BUILD_DIR)/xsim && xelab -L uvm -debug typical -timescale 1ns/1ps \
		-cc_type bcst -sv_lib ../../build/model/libdma_ref $(TOP) -s $(TOP)_snapshot
	touch $@

compile: $(BUILD_DIR)/model/libdma_ref.so $(BUILD_DIR)/xsim/.compiled

$(BUILD_DIR)/model/libdma_ref.so: model/dma_ref.cpp
	mkdir -p $(BUILD_DIR)/model
	$(CXX) -std=c++17 -O2 -fPIC -shared -I"$(XILINX_VIVADO)/data/xsim/include" $< -o $@

test: compile
	mkdir -p $(RESULT_DIR)
	cd $(BUILD_DIR)/xsim && VERIDMA_COV_DIR=../../$(RESULT_DIR)/coverage \
		VERIDMA_COV_NAME=$(TEST)_$(SEED) xsim $(TOP)_snapshot \
		-tclbatch ../../scripts/xsim_run.tcl \
		-sv_seed $(SEED) \
		-testplusarg UVM_TESTNAME=$(TEST) \
		-testplusarg VERIDMA_SEED=$(SEED) \
		-log ../../$(RESULT_DIR)/$(TEST)_$(SEED).log

wave: compile
	mkdir -p $(RESULT_DIR)
	cd $(BUILD_DIR)/xsim && VERIDMA_COV_DIR=../../$(RESULT_DIR)/coverage \
		VERIDMA_COV_NAME=$(TEST)_$(SEED) xsim $(TOP)_snapshot \
		-tclbatch ../../scripts/xsim_run.tcl \
		-sv_seed $(SEED) \
		-testplusarg UVM_TESTNAME=$(TEST) \
		-testplusarg VERIDMA_SEED=$(SEED) \
		-wdb ../../$(RESULT_DIR)/$(TEST)_$(SEED).wdb \
		-log ../../$(RESULT_DIR)/$(TEST)_$(SEED).log

smoke:
	python3 scripts/run_regression.py --profile smoke --jobs $(JOBS)

regression:
	python3 scripts/run_regression.py --profile $(PROFILE) --jobs $(JOBS)

formal:
	@command -v sby >/dev/null || { echo "SymbiYosys is required"; exit 2; }
	for target in formal/regs.sby formal/fifo.sby formal/fsm.sby; do sby -f $$target; done

reuse-demo:
	@command -v xvlog >/dev/null || { echo "Vivado xsim tools are required"; exit 2; }
	mkdir -p $(BUILD_DIR)/reuse
	cd $(BUILD_DIR)/reuse && xvlog -sv -L uvm -i ../../tb -i ../../tb/uvc/axil \
		../../tb/interfaces/axil_if.sv \
		../../tb/uvc/axil/axil_uvc_pkg.sv \
		../../tb/reuse_demo/axil_scratchpad.sv \
		../../tb/reuse_demo/reuse_demo_pkg.sv \
		../../tb/reuse_demo/reuse_demo_top.sv
	cd $(BUILD_DIR)/reuse && xelab -L uvm -debug typical reuse_demo_top -s reuse_demo_snapshot
	cd $(BUILD_DIR)/reuse && xsim reuse_demo_snapshot -runall -testplusarg UVM_TESTNAME=axil_reuse_test

coverage:
	python3 scripts/cov_merge.py --results results --output coverage/merged

cpp-test:
	mkdir -p $(BUILD_DIR)/model
	$(CXX) -std=c++17 -O2 -DVERIDMA_STANDALONE model/dma_ref.cpp -o $(BUILD_DIR)/model/dma_ref_test
	$(BUILD_DIR)/model/dma_ref_test

script-test:
	python3 -m unittest discover -s tests -v

structure-check:
	python3 scripts/check_structure.py

clean:
	rm -rf "$(CURDIR)/build" "$(CURDIR)/.Xil" "$(CURDIR)/xsim.dir"

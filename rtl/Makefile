SIM ?= vcs
VCS ?= vcs
VERILATOR ?= verilator
FILE_LIST_TB = file_list_tb.f
TOP_SRC = hnf
TOP_TB = tb_hnf
# TOP_TB = tb_rni
SIMV = simv
VCS_OPTS ?= -full64 +v2k -q -sverilog -fsdb +incdir+include+misc -Mupdate -debug_acc+dmptf -debug_region+cell+encrypt
ifeq ($(TOP_TB), tb_hnf)
VCS_OPTS_HNF += $(VCS_OPTS)
VCS_OPTS_TB  := $(VCS_OPTS_HNF) +incdir+src+misc -top $(TOP_TB)
else ifeq ($(TOP_TB), tb_rni)
VCS_OPTS_RNI += $(VCS_OPTS) +define+ASSERT_CHECKER_ON
VCS_OPTS_TB  := $(VCS_OPTS_RNI) +incdir+src+misc -top $(TOP_TB)
endif 
VCS_V2005 = -full64 +v2k -q -v2005 -fsdb +incdir+include+misc -debug_acc+dmptf -debug_region+cell+encrypt -Mupdate
VCS_OPTS_SRC := $(VCS_OPTS_HNF) -top $(TOP_SRC)
all:com sim
ifeq ($(SIM), verilator)
# Licence-free. ccache cannot see through the precompiled header Verilator compiles
# against and can serve objects of a stale layout, so it is off unless OBJCACHE names it.
OBJCACHE ?=
export OBJCACHE
VL_DEFINES := $(if $(filter tb_rni,$(TOP_TB)),+define+ASSERT_CHECKER_ON)
com:
	$(VERILATOR) --binary --timing -j 0 -Wno-fatal $(VL_DEFINES) -Iinclude -Imisc -Isrc --top-module $(TOP_TB) --Mdir obj_dir -o $(SIMV) -f $(FILE_LIST_TB)
sim:
	./obj_dir/$(SIMV) 2>&1 | tee sim.log; grep -q "All tests passed" sim.log
else
com:
	$(VCS) $(VCS_OPTS_TB) -o $(SIMV) -f $(FILE_LIST_TB)
sim:
	./simv -l sim.log
endif
run_dve:
	dve -full64 -vpd vcdplus.vpd &
clean:
	rm -rf obj_dir csrc *.vpd *.fsdb *.daidir *.log simv* *.key DVEfiles vivado_syn_output *.conf *.rc verdiLog

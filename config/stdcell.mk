#-----------------------------------------------------------------------------
# makefile Technology : STD CELL CONFIG
#-----------------------------------------------------------------------------

export TECH_NAME = stdcell

export TECH_DIR = /home/tools/design_kits/cadence/GPDK045

export LIB_DIR = $(TECH_DIR)/gsclib045_svt_v4.4/gsclib045/timing
export LEF_DIR = $(TECH_DIR)/gsclib045_svt_v4.4/gsclib045/lef

export WORST_LIST = $(LIB_DIR)/slow_vdd1v0_basicCells.lib
export BEST_LIST = $(LIB_DIR)/fast_vdd1v2_basicCells.lib

export LEF_LIST = \
$(LEF_DIR)/gsclib045_tech.lef \
$(LEF_DIR)/gsclib045_macro.lef

export WORST_CAP_LIST = $(TECH_DIR)/gpdk045_v_6_0/soce/gpdk045.basic.CapTbl

export QRC_LIST = $(TECH_DIR)/gpdk045_v_6_0/qrc/rcworst/qrcTechFile

export CAP_MAX = $(WORST_CAP_LIST)
export CAP_MIN = $(WORST_CAP_LIST)

export NET_ZERO = VSS
export NET_ONE = VDD

export BUFFERS_CTS = CLKBUFX20 CLKBUFX16 CLKBUFX12 CLKBUFX8 CLKBUFX6 CLKBUFX4 CLKBUFX3 CLKBUFX2

export INVERTERS_CTS = INVX20 CLKINVX20 INVX16 INVX12 INVX8 INVX6 INVX4 INVX3 INVX2 INVX1 INVXL

export TECH_V_LIB = $(TECH_DIR)/gsclib045_all_v4.4/gsclib045/verilog/slow_vdd1v0_basicCells.v


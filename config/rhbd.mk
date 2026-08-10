# =========================================================
# makefile RHBD TECHNOLOGY CONFIG
# =========================================================
export TECH_NAME = rhbd
export TECH      = rhbd
export TECH_DIR  = /home/epiphane/FSM_counter_RH

# LIBRARIES
export LIB_DIR   = $(TECH_DIR)/diglibs/xh018/D_CELLS_RH/liberty
export WORST_LIST = $(LIB_DIR)/D_CELLS_RH_LPMOS_slow_1_62V_125C.lib
export BEST_LIST  = $(LIB_DIR)/D_CELLS_RH_LPMOS_fast_1_98V_125C.lib
export TYP_LIST   = $(LIB_DIR)/D_CELLS_RH_LPMOS_typ_1_80V_25C.lib

# LEF
export LEF_DIR  = $(TECH_DIR)/backend/synthesis/library

export LEF_LIST = \
$(LEF_DIR)/xh018_xx43_MET4_METMID_METTHK.lef \
$(LEF_DIR)/xh018_D_CELLS_RH.lef

# VERILOG MODELS
export TECH_V_LIB = $(TECH_DIR)/diglibs/xh018/D_CELLS_RH/verilog/D_CELLS_RH.v

# CAP TABLE

export CAP_MAX = $(TECH_DIR)/backend/synthesis/library/xh018_xx43_MET4_METMID_METTHK_max.capTbl
export CAP_MIN = $(TECH_DIR)/backend/synthesis/library/xh018_xx43_MET4_METMID_METTHK_min.capTbl
export WORST_CAP_LIST = $(CAP_MAX)
export QRC_LIST =

# POWER / GROUND
export NET_ZERO = VSS
export NET_ONE  = VDD


# CTS CELLS
export BUFFERS_CTS   = BURHX1 BURHX2 BURHX4
export INVERTERS_CTS = INRHX1 INRHX2 INRHX4
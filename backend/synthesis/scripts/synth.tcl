# Last update: 2026/02/26

#-----------------------------------------------------------------------------
# General Comments
#-----------------------------------------------------------------------------
puts "  "
puts "  "
puts "  "
puts "  "

#-----------------------------------------------------------------------------
# Main Custom Variables Design Dependent (set local)
#-----------------------------------------------------------------------------
set PROJECT_DIR $env(PROJECT_DIR)
set TECH_DIR $env(TECH_DIR)
set DESIGNS $env(DESIGNS)
set HDL_NAME $env(HDL_NAME)
set INTERCONNECT_MODE ple


#-----------------------------------------------------------------------------
# MAIN Custom Variables to be used in SDC (constraints file)
#-----------------------------------------------------------------------------
set MAIN_CLOCK_NAME clk
set MAIN_RST_NAME rst_n
set BEST_LIB_OPERATING_CONDITION PVT_1P32V_0C
set WORST_LIB_OPERATING_CONDITION PVT_0P9V_125C

# Read from Makefile environment and calculate period (1000 / MHz = ns)
set freq_mhz $env(FREQ_MHZ)
set period_clk [expr {1000.0 / $freq_mhz}]; # (100 ns = 10 MHz) (10 ns = 100 MHz) (2 ns = 500 MHz) (1 ns = 1 GHz)
set clk_uncertainty 0.05 ;# ns (“a guess”)
set clk_latency 0.10 ;# ns (“a guess”)
set in_delay 0.30 ;# ns
set out_delay 0.30;#ns 
set out_load 0.045 ;#pF 
set slew "146 164 264 252" ;#minimum rise, minimum fall, maximum rise and maximum fall 
set slew_min_rise 0.146 ;# ns
set slew_min_fall 0.164 ;# ns
set slew_max_rise 0.264 ;# ns
set slew_max_fall 0.252 ;# ns
#

set WORST_LIST $env(WORST_LIST)
set BEST_LIST  $env(BEST_LIST)
set LEF_LIST   $env(LEF_LIST)
set QRC_LIST   $env(QRC_LIST)
set WORST_CAP_LIST $env(CAP_MAX)


#-----------------------------------------------------------------------------
# Load Path File
#-----------------------------------------------------------------------------
source ${PROJECT_DIR}/backend/synthesis/scripts/common/path.tcl

#-----------------------------------------------------------------------------
# Load Tech File
#-----------------------------------------------------------------------------
source ${SCRIPT_DIR}/common/tech.tcl

# Set the active library dynamically based on the Makefile parameter
set lib_type $env(LIB_TYPE)
puts "INFO: Selecting library domain for LIB_TYPE=$lib_type"



# ============================================================================
# FORCAGE INTERDICTION STRICTE : Exclusion complète de CoreSiteDouble
# ============================================================================
puts "FORCAGE : Marquage 'avoid' sur toutes les cellules CoreSiteDouble"
set double_cells [get_db lib_cells * -if {.site.name == "CoreSiteDouble"}]
if {$double_cells != ""} {
    set_db $double_cells .avoid true
    puts "--> [llength $double_cells] cellules double-hauteur ont été interdites."
} else {
    puts "--> Aucune cellule CoreSiteDouble trouvée dans les libs chargées."
}
# ============================================================================




set_db init_hdl_search_path "${DEV_DIR} ${FRONTEND_DIR}"
#set rtl_files "Util_package.vhd ${DESIGNS}.vhd"
#read_hdl -language vhdl $rtl_files 
# Read VHDL files
#read_hdl -vhdl {}

# Read SystemVerilog files
#read_hdl -sv -f $env(RTL_FILES)
set rtl_filelist $env(RTL_FILES)

set fd [open $rtl_filelist r]
set synth_files {}

while {[gets $fd line] >= 0} {
    set line [string trim $line]

    # Ignore empty lines and comments
    if {$line eq "" || [string match "#*" $line]} {
        continue
    }

    # Ignore testbench files
    if {[string match "*_tb.sv" $line]} {
        puts "INFO: Ignoring testbench: $line"
        continue
    }

    lappend synth_files $line
}

close $fd

read_hdl -sv $synth_files

#-----------------------------------------------------------------------------
# Elaborate Design
#-----------------------------------------------------------------------------
elaborate ${HDL_NAME}
set_top_module ${HDL_NAME}
check_design -unresolved ${HDL_NAME}
get_db current_design
check_library


#-----------------------------------------------------------------------------
# Constraints
#-----------------------------------------------------------------------------
read_sdc ${BACKEND_DIR}/synthesis/constraints/${HDL_NAME}.sdc

#-----------------------------------------------------------------------------
# Pos "Elaborate" Attributes (manually set)
#-----------------------------------------------------------------------------
set_db auto_ungroup none ;# (none|both) ungrouping will not be performed

#-----------------------------------------------------------------------------
# Generic optimization (technology independent)
#-----------------------------------------------------------------------------
syn_generic ${HDL_NAME} 

#-----------------------------------------------------------------------------
# Agressively optimization (area, timing, power) and mapping
#-----------------------------------------------------------------------------
syn_map ${HDL_NAME} 
get_db insts .base_cell.name -u ;# List all cell names used in the current design.

#-----------------------------------------------------------------------------
# Preparing and generating output data (reports, verilog netlist)
#-----------------------------------------------------------------------------
# Fetch runtime from environment early
set runtime $env(RUNTIME)

# Folders names (Ta no makefile)
set tech_name $env(TECH)
set RUN_DIR "${HDL_NAME}_${tech_name}_${lib_type}_${freq_mhz}_${runtime}"
set RUN_RPT_DIR "${RPT_DIR}/${RUN_DIR}"
set RUN_DEV_DIR "${DEV_DIR}/${RUN_DIR}"

report_design_rules > ${RUN_RPT_DIR}/${HDL_NAME}_drc.rpt
report_area > ${RUN_RPT_DIR}/${HDL_NAME}_area.rpt

# Normalisation conditionnelle selon la technologie
set lib_type_env $env(TECH)
report_area > ${RUN_RPT_DIR}/${HDL_NAME}_area.rpt
if {$env(TECH) == "rhbd"} {
    report_area -normalize_with_gate NARH2X1 > ${RUN_RPT_DIR}/${HDL_NAME}_normalized_area.rpt
} else {
    report_area -normalize_with_gate NAND2X1 > ${RUN_RPT_DIR}/${HDL_NAME}_normalized_area.rpt
}


report_timing > ${RUN_RPT_DIR}/${HDL_NAME}_timing.rpt
report_gates > ${RUN_RPT_DIR}/${HDL_NAME}_gates.rpt
report_qor > ${RUN_RPT_DIR}/${HDL_NAME}_qor.rpt

#source ../scripts/common/sdf_width_wa.etf

# Output SDF and HDL directly to the dynamic RUN_DEV_DIR
write_sdf -edge check_edge -setuphold split -recrem split -version 3.0 -design ${HDL_NAME} > ${RUN_DEV_DIR}/${HDL_NAME}.sdf
write_hdl ${HDL_NAME} > ${RUN_DEV_DIR}/${HDL_NAME}.v

#-----------------------------------------------------------------------------
# Lab 6: Power Analysis
#-----------------------------------------------------------------------------
# Point to the dynamically generated VCD file from the Xcelium simulation
#-----------------------------------------------------------------------------
# Lab 6: Power Analysis (Conditional Execution)
#-----------------------------------------------------------------------------
set vcd_path "${PROJECT_DIR}/frontend/VCDs/${HDL_NAME}_${lib_type}_${freq_mhz}_${runtime}.vcd"

if { [file exists $vcd_path] } {
    puts "==============================================================="
    puts "INFO: VCD file found. Executing Power Analysis."
    puts "==============================================================="
    
    # Point to the dynamically generated VCD file from the Xcelium simulation
    read_stimulus -allow_n_nets -format vcd -file $vcd_path

    # Set the power engine and generate reports into the dynamic run directory
    set_db power_engine joules
    report_sdb_annotation > ${RUN_RPT_DIR}/${HDL_NAME}_sdb_annotation.rpt
    report_power -unit uW > ${RUN_RPT_DIR}/${HDL_NAME}_power.rpt


} else {
    puts "==============================================================="
    puts "INFO: No VCD file found at $vcd_path. Skipping Power Analysis."
    puts "==============================================================="
}

#-----------------------------------------------------------------------------
# Save Database for Subsequent Power Analysis
#-----------------------------------------------------------------------------
set db_path "${RUN_DEV_DIR}/${HDL_NAME}_mapped.db"
puts "==============================================================="
puts "Saving Genus Database to: $db_path"
puts "==============================================================="
write_db -all_root $db_path

quit

quit
# tech.tcl

set TECH_NAME $env(TECH)
puts "================================================"
puts "INFO: Loading technology = $TECH_NAME"
puts "================================================"


#-----------------------------------------------------------------------------
# Create Library Domain
#-----------------------------------------------------------------------------
create_library_domain {worst best} 
get_db library_domains *

set WORST_LIST $env(WORST_LIST)
set BEST_LIST  $env(BEST_LIST)
set LEF_LIST   $env(LEF_LIST)
set QRC_LIST   $env(QRC_LIST)


set MAIN_CLOCK_NAME clk
set MAIN_RST_NAME rst_n
#set BEST_LIB_OPERATING_CONDITION PVT_1P32V_0C
#set WORST_LIB_OPERATING_CONDITION PVT_0P9V_125C


#-----------------------------------------------------------------------------
# LEF Files and Technology Library
#-----------------------------------------------------------------------------
#set_db lib_search_path "${LIB_DIR} ${LEF_DIR}"
set_db lib_search_path "$env(LIB_DIR) $env(LEF_DIR)"




puts "==== DEBUG LIBS ===="
puts "WORST_LIST=$WORST_LIST"
puts "BEST_LIST=$BEST_LIST"

puts "WORST exists=[file exists $WORST_LIST]"
puts "BEST exists=[file exists $BEST_LIST]"

if {[file exists $WORST_LIST]} {
    set fp [open $WORST_LIST r]
    puts "WORST first line=[gets $fp]"
    close $fp
} else {
    puts "ERROR: WORST_LIST not found: $WORST_LIST"
}

set fp [open $BEST_LIST r]
puts "BEST first line=[gets $fp]"
close $fp




set_db [get_db library_domains worst] .library $WORST_LIST
set_db [get_db library_domains best]  .library $BEST_LIST


#-----------------------------------------------------------------------------
# Operating conditions
#-----------------------------------------------------------------------------

if {$TECH_NAME == "rhbd"} {

    puts "INFO: RHBD flow detected -> skipping operating_conditions override"

} else {

    puts "INFO: Standard PDK flow -> applying operating_conditions"

    set BEST_LIB_OPERATING_CONDITION $env(BEST_LIB_OPERATING_CONDITION)
    set WORST_LIB_OPERATING_CONDITION $env(WORST_LIB_OPERATING_CONDITION)

    set_db [get_db library_domains worst] .operating_conditions $WORST_LIB_OPERATING_CONDITION
    set_db [get_db library_domains best]  .operating_conditions $BEST_LIB_OPERATING_CONDITION
}



#-----------------------------------------------------------------------------
# LEF, QRC and CAP Files
#-----------------------------------------------------------------------------

# Load lef files
set_db lef_library ${LEF_LIST}


if {$TECH_NAME == "rhbd" || $QRC_LIST == ""} {
    puts "INFO: RHBD flow -> skipping QRC tech file"
    set_db qrc_tech_file ""
} else {
    puts "INFO: STD flow -> using QRC"
    set_db qrc_tech_file ${QRC_LIST}
}

# Use PLE mode
get_db interconnect_mode
set_db interconnect_mode ple ;# global



#-----------------------------------------------------------------------------
# Manage Cells
#-----------------------------------------------------------------------------

# Safe exclusion of specific FF (if exists) - protected for RHBD compatibility
if {[catch {get_db base_cell:SDFFRHQX1} ff_special] == 0 && $ff_special != ""} {
    set_db $ff_special .dont_use true
}

# Exclude all SDFF flip-flops
set ff_cells [get_db base_cells -if {.name == "SDFF*"}]
if {$ff_cells != ""} {
    foreach lc $ff_cells {
        set_db $lc .dont_use true
    }
}

# Exclude all latches (if present)
set latch_cells [get_db base_cells -if {.name == "TLATS*"}]
if {$latch_cells != ""} {
    foreach lc $latch_cells {
        set_db $lc .dont_use true
    }
}



#-----------------------------------------------------------------------------
# Report important info
#-----------------------------------------------------------------------------
# To find libraries present in the library domain
get_db [get_db library_sets *worst] .libraries
get_db [get_db library_sets *best] .libraries
# To get all library cells from all the libraries present in the library domain
get_db [get_db library_sets *worst] .libraries.lib_cells
get_db [get_db library_sets *best] .libraries.lib_cells
# To get lib_cells only from a particular library in the library domain
get_db [get_db [get_db library_sets *worst] .libraries *slow_vdd1v0] .lib_cells
get_db [get_db [get_db library_sets *best] .libraries *fast_vdd1v2] .lib_cells 
# To find a particular lib_cell in the library domain 
get_db [get_db library_sets *worst] .libraries.lib_cells -regexp XOR
get_db [get_db library_sets *best] .libraries.lib_cells -regexp XOR
# To know all attributes of a particular lib_cell in a library domain in Common_UI
get_db [get_db [get_db library_sets *worst] .libraries.lib_cells -regexp CLKXOR2X1] .*
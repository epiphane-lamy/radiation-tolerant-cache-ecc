# Last update: 2026/03/08 

#----------------------------------------------------------------------------- 
# Fetch Dynamic Environment Variables from Makefile
#----------------------------------------------------------------------------- 
set TECH_NAME $env(TECH)
set design      $env(DESIGNS)
set freq        $env(FREQ_MHZ)
set lib         $env(LIB_TYPE)
set runtime     $env(RUNTIME)
set PROJECT_DIR $env(PROJECT_DIR)
set BACKEND_DIR $env(BACKEND_DIR)
set LAYOUT_DIR  $env(LAYOUT_DIR)
set_message -id IMPSP-9099 -suppress

# Define dynamic output paths
set tech  $env(TECH)
set OUT_DELIV "${LAYOUT_DIR}/deliverables/${design}_${tech}_${lib}_${freq}_${runtime}"
set OUT_RPT   "${LAYOUT_DIR}/reports/${design}_${tech}_${lib}_${freq}_${runtime}"

#----------------------------------------------------------------------------- 
# Load Path, Variables, and Tech files
#----------------------------------------------------------------------------- 
source ${PROJECT_DIR}/backend/synthesis/scripts/common/path.tcl 
source ${PROJECT_DIR}/backend/synthesis/scripts/common/variables.tcl

#----------------------------------------------------------------------------- 
# Suppressing messages (use with caution) 
#----------------------------------------------------------------------------- 
set_message -id TECHLIB-302 -suppress 
set_message -id IMPDB-6501 -suppress  
set_message -id IMPFP-3961 -suppress  
set_message -id IMPOPT-3195 -suppress 
set_message -id IMPSP-9025 -suppress  
set_message -id IMPLF-200 -suppress  
set_message -id IMPEXT-3493 -suppress  
set_message -id IMPEXT-6166 -suppress  
set_message -id IMPSP-5217 -suppress  


set_multi_cpu_usage -local_cpu 8

#----------------------------------------------------------------------------- 
# Initiates the design files (netlist, LEFs, timing libraries) 
#----------------------------------------------------------------------------- 
set_db init_power_nets $NET_ONE 
set_db init_ground_nets $NET_ZERO 

if {$TECH_NAME == "rhbd"} {
    set CAP_MIN $env(CAP_MIN)
    set CAP_MAX $env(CAP_MAX)
} else {
    # Pour stdcell, si ton .view utilise aussi des variables
    set CAP_MIN $env(CAP_MIN)
    set CAP_MAX $env(CAP_MAX)
}

set CAP_MIN $env(CAP_MIN)
set CAP_MAX $env(CAP_MAX)

# --- Loading and initialization according to the target technology ---
if {$TECH_NAME == "rhbd"} {
    puts "INFO: RHBD flow -> no cap table available, using internal RC estimation"
    read_mmmc ${LAYOUT_DIR}/scripts/${design}_rhbd.view
    read_physical -lef $LEF_LIST 
    read_netlist ../../synthesis/deliverables/${design}_${tech}_${lib}_${freq}_0/${design}.v
    init_design
    set_db design_process_node 180
} else {
    puts "INFO: STD CELL flow"
    read_mmmc ${LAYOUT_DIR}/scripts/${design}.view
    read_physical -lef $LEF_LIST 
    read_netlist ../../synthesis/deliverables/${design}_${tech}_${lib}_${freq}_0/${design}.v
    init_design
}

#----------------------------------------------------------------------------- 
# General settings 
#----------------------------------------------------------------------------- 
if {$TECH_NAME == "rhbd"} {
    set_db design_process_node 130
    set_db design_top_routing_layer 4
} else {
    set_db design_process_node 45
    set_db design_top_routing_layer 11
}

#----------------------------------------------------------------------------- 
# Net connections 
#----------------------------------------------------------------------------- 
delete_global_net_connections

if {$TECH_NAME == "rhbd"} {
    puts "INFO: Applying Power/Ground connections for RHBD (X-FAB xh018)"
    
    connect_global_net $NET_ONE  -type pg_pin -pin_base_name vdd! -inst_base_name *
    connect_global_net $NET_ZERO -type pg_pin -pin_base_name gnd! -inst_base_name *
    
    connect_global_net $NET_ONE  -type tie_hi
    connect_global_net $NET_ZERO -type tie_lo

} else {
    puts "INFO: Applying Power/Ground connections for Standard Cells (GPDK045)"
    
    connect_global_net $NET_ONE  -type pg_pin -pin_base_name $NET_ONE  -inst_base_name *
    connect_global_net $NET_ZERO -type pg_pin -pin_base_name $NET_ZERO -inst_base_name *
    
    connect_global_net $NET_ONE  -type tie_hi
    connect_global_net $NET_ZERO -type tie_lo
    
    connect_global_net $NET_ONE  -type tie_hi -pin $NET_ONE  -inst *
    connect_global_net $NET_ZERO -type tie_lo -pin $NET_ZERO -inst *
}
#----------------------------------------------------------------------------- 
# Specify floorplan and pins
#----------------------------------------------------------------------------- 
if {$TECH_NAME == "rhbd"} {
    create_floorplan \
    -site core \
    -core_margins_by die \
    -core_density_size 1 0.87 2.5 2.5 2.5 2.5 \
    -flip s
} else {
    
    create_floorplan -site CoreSite -core_margins_by die -core_density_size {1 0.25 2.5 2.5 2.5 2.5}
}

check_floorplan
set PIN_LAYER 1
if {$TECH_NAME == "rhbd"} { 
    set PIN_LAYER "MET1" 
}


if {$TECH_NAME == "rhbd"} {
    edit_pin -fixed_pin 1 -spread_direction clockwise -side Left -layer $PIN_LAYER -spread_type side -pin $LEFT_CORE_PINS 
    edit_pin -fixed_pin 1 -spread_direction clockwise -edge 1 -layer $PIN_LAYER -spread_type side -pin $TOP_CORE_PINS 
    edit_pin -fixed_pin 1 -spread_direction clockwise -edge 2 -layer $PIN_LAYER -spread_type side -pin $RIGHT_CORE_PINS 
    edit_pin -fixed_pin 1 -spread_direction clockwise -edge 3 -layer $PIN_LAYER -spread_type side -pin $BOTTOM_CORE_PINS
} else {
    edit_pin -fixed_pin 1 -unit micron -spread_direction clockwise -side Left -layer $PIN_LAYER -spread_type center -spacing 1.0 -pin $LEFT_CORE_PINS 
    edit_pin -fixed_pin 1 -unit micron -spread_direction clockwise -edge 1 -layer $PIN_LAYER -spread_type center -spacing 1.0 -pin $TOP_CORE_PINS 
    edit_pin -fixed_pin 1 -unit micron -spread_direction clockwise -edge 2 -layer $PIN_LAYER -spread_type center -spacing 1.0 -pin $RIGHT_CORE_PINS 
    edit_pin -fixed_pin 1 -unit micron -spread_direction clockwise -edge 3 -layer $PIN_LAYER -spread_type center -spacing 1.0 -pin $BOTTOM_CORE_PINS
}


#----------------------------------------------------------------------------- 
# Power planning (Rings & Stripes)
#----------------------------------------------------------------------------- 
set_db add_rings_skip_shared_inner_ring none 
set_db add_rings_avoid_short 1 
set_db add_rings_ignore_rows 0 
set_db add_rings_extend_over_row 0 

if {$TECH_NAME == "rhbd"} {
    add_rings -type core_rings -jog_distance 0.6 -threshold 0.6 -nets "$NET_ONE $NET_ZERO" \
              -follow core -layer {bottom MET4 top MET4 right MET3 left MET3} \
              -width 2.0 -spacing 0.8 -offset 0.6 
} else {
    add_rings -type core_rings -jog_distance 0.6 -threshold 0.6 -nets "$NET_ONE $NET_ZERO" \
              -follow core -layer {bottom Metal11 top Metal11 right Metal10 left Metal10} \
              -width 0.7 -spacing 0.4 -offset 0.6 

    add_stripes -nets "$NET_ONE $NET_ZERO" -layer Metal6 -direction vertical -width 0.28 -spacing 0.8 \
                -set_to_set_distance 6 -start_from left -switch_layer_over_obs false \
                -max_same_layer_jog_length 2 -pad_core_ring_top_layer_limit Metal11 \
                -pad_core_ring_bottom_layer_limit Metal1 -block_ring_top_layer_limit Metal11 \
                -block_ring_bottom_layer_limit Metal1 -use_wire_group 0 \
                -snap_wire_center_to_grid none -start_offset 1
}

#----------------------------------------------------------------------------- 
# Placement et Optimisation Pré-CTS
#----------------------------------------------------------------------------- 

place_design

foreach inst [get_db insts -if {.base_cell.name == DFFRHRSX1}] {
    set_db $inst .place_status fixed
}



if {$TECH_NAME == "rhbd"} {
    route_special -connect core_pin -layer_change_range { MET1 MET1 } \
                  -block_pin_target nearest_target -core_pin_target first_after_row_end \
                  -allow_jogging 0 -nets "$NET_ONE $NET_ZERO" -allow_layer_change 0 \
                  -target_via_layer_range { MET1 MET1 } -stripe_layer_range {1 1} 
} else {
    route_special -connect core_pin -layer_change_range { Metal1(1) Metal11(11) } \
                  -block_pin_target nearest_target -core_pin_target first_after_row_end \
                  -allow_jogging 1 -crossover_via_layer_range { Metal1(1) Metal11(11) } \
                  -nets "$NET_ONE $NET_ZERO" -allow_layer_change 1 \
                  -target_via_layer_range { Metal1(1) Metal11(11) } -stripe_layer_range {1 11} 
}



opt_design -pre_cts


set_db extract_rc_engine pre_route
extract_rc 


clock_opt_design

set_db [get_db nets -if {.is_power || .is_ground}] .skip_routing true

catch {route_design}
set_db delaycal_enable_si false
opt_design -post_route -hold
# ============================================================================
# Checks, final reports, and .rpt file generation
# ============================================================================

exec mkdir -p ${OUT_RPT}

report_gates -out_file "${OUT_RPT}/${design}_gates_layout.rpt"

report_timing -late > "${OUT_RPT}/setup_timing.rpt"

report_timing -early > "${OUT_RPT}/hold_timing.rpt"

check_drc -out_file "${OUT_RPT}/drc_layout.rpt"

set_db extract_rc_engine post_route
extract_rc
set_db power_method static
report_power > "${OUT_RPT}/${design}_power_layout.rpt"

set dest_dir "/home/epiphane/projets/cache_ECC/backend/layout/deliverables"

if {[info exists freq] && $freq != ""} {
    set freq_str "${freq}MHz"
} else {
    set freq_str "unknownFreq"
}

set db_name "cache_ECC_${TECH_NAME}_${freq_str}_routed"

set full_path "${dest_dir}/${db_name}"

write_db $full_path

exit

# Innovus command to open the layout
# read_db /home/epiphane/projets/cache_ECC/backend/layout/deliverables/cache_ECC_rhbd_100MHz_routed
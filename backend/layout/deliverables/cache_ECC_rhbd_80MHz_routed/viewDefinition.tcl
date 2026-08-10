if {![namespace exists ::IMEX]} { namespace eval ::IMEX {} }
set ::IMEX::dataVar [file dirname [file normalize [info script]]]
set ::IMEX::libVar ${::IMEX::dataVar}/libs

create_library_set -name fast\
   -timing\
    [list ${::IMEX::libVar}/mmmc/D_CELLS_RH_LPMOS_fast_1_98V_125C.lib]
create_library_set -name slow\
   -timing\
    [list ${::IMEX::libVar}/mmmc/D_CELLS_RH_LPMOS_slow_1_62V_125C.lib]
create_opcond -name oc_fast -process 1 -voltage 1.98 -temperature 125
create_opcond -name oc_slow -process 1 -voltage 1.62 -temperature 125
create_timing_condition -name slow_timing\
   -library_sets [list slow]\
   -opcond oc_slow
create_timing_condition -name fast_timing\
   -library_sets [list fast]\
   -opcond oc_fast
create_rc_corner -name rc_best\
   -cap_table ${::IMEX::libVar}/mmmc/xh018_xx43_MET4_METMID_METTHK_min.capTbl\
   -pre_route_res 1\
   -post_route_res 1\
   -pre_route_cap 1\
   -post_route_cap 1\
   -post_route_cross_cap 1\
   -pre_route_clock_res 0\
   -pre_route_clock_cap 0\
   -temperature 125
create_rc_corner -name rc_worst\
   -cap_table ${::IMEX::libVar}/mmmc/xh018_xx43_MET4_METMID_METTHK_max.capTbl\
   -pre_route_res 1\
   -post_route_res 1\
   -pre_route_cap 1\
   -post_route_cap 1\
   -post_route_cross_cap 1\
   -pre_route_clock_res 0\
   -pre_route_clock_cap 0\
   -temperature 125
create_delay_corner -name slow_max\
   -timing_condition {slow_timing}\
   -rc_corner rc_worst
create_delay_corner -name fast_min\
   -timing_condition {fast_timing}\
   -rc_corner rc_best
create_constraint_mode -name normal_genus_slow_max\
   -sdc_files\
    [list ${::IMEX::dataVar}/mmmc/modes/normal_genus_slow_max/normal_genus_slow_max.sdc]
create_analysis_view -name analysis_normal_fast_min -constraint_mode normal_genus_slow_max -delay_corner fast_min -latency_file ${::IMEX::dataVar}/mmmc/views/analysis_normal_fast_min/latency.sdc
create_analysis_view -name analysis_normal_slow_max -constraint_mode normal_genus_slow_max -delay_corner slow_max -latency_file ${::IMEX::dataVar}/mmmc/views/analysis_normal_slow_max/latency.sdc
set_analysis_view -setup [list analysis_normal_slow_max] -hold [list analysis_normal_fast_min]

set_clock_latency 0.1  [get_clocks {clk}]
set_clock_latency -source -early -min   0.1 [get_ports {clk}] -clock clk 
set_clock_latency -source -late -min   0.1 [get_ports {clk}] -clock clk 

set_clock_latency 0.1  [get_clocks {clk}]
set_clock_latency -source -early -min -rise  0.0524521 [get_ports {clk}] -clock clk 
set_clock_latency -source -early -min -fall  0.0551324 [get_ports {clk}] -clock clk 
set_clock_latency -source -late -min -rise  0.0524521 [get_ports {clk}] -clock clk 
set_clock_latency -source -late -min -fall  0.0551324 [get_ports {clk}] -clock clk 

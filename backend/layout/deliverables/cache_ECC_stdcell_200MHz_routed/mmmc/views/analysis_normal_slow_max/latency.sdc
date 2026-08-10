set_clock_latency 0.1  [get_clocks {clk}]
set_clock_latency -source -early -max   0.1 [get_ports {clk}] -clock clk 
set_clock_latency -source -late -max   0.1 [get_ports {clk}] -clock clk 

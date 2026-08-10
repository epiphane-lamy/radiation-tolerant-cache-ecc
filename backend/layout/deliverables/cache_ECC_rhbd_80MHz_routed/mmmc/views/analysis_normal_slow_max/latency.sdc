set_clock_latency 0.1  [get_clocks {clk}]
set_clock_latency -source -early -max -rise  -0.00221698 [get_ports {clk}] -clock clk 
set_clock_latency -source -early -max -fall  0.00466546 [get_ports {clk}] -clock clk 
set_clock_latency -source -late -max -rise  -0.00221698 [get_ports {clk}] -clock clk 
set_clock_latency -source -late -max -fall  0.00466546 [get_ports {clk}] -clock clk 

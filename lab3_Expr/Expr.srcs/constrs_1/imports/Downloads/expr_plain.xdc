## expr_plain.xdc
## With registered inputs (see expr_plain.v), EVERY timing path is
## register-to-register. This one line is genuinely sufficient --
## no set_input_delay/set_output_delay needed, because there is no
## port-to-register path left in the design to be unconstrained.

create_clock -period 7.500 -name sys_clk [get_ports clk]

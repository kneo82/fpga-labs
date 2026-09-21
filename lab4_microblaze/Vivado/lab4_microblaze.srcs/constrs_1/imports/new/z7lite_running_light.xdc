# ===========================================================================
# Z7-Lite (MicroPhase) - XC7Z010-1CLG400
# Lab 4, task 2: MicroBlaze + AXI GPIO + AXI Timer - running light
#
# Same external wiring and the same pins as the Zynq PS version. What
# changes is that the PS is absent, so the clock and the reset now have to
# come from the PL side and need constraints of their own.
#
#   LEDs    JP1 pins 31..34, ACTIVE HIGH
#           FPGA pin --[1K]--|>|-- GND (JP1 pin 30)
#
#   Keys    JP2 pins 31..34, ACTIVE LOW
#           FPGA pin --[100R]--o/ o-- GND (JP2 pin 30)
#           Internal weak pull-up provides the idle high level.
#
#   Switch  JP2 pin 35, ACTIVE LOW, same wiring as the keys.
#
# The AXI GPIO instances stay in the default bidirectional mode, matching
# the Zynq PS version of this lab, so the wrapper exposes inout ports with
# the _tri_io suffix and one IOBUF per bit. Direction is set at runtime by
# XGpio_SetDataDirection.
#
# GPIO mapping:
#   axi_gpio_0  4-bit output  -> led_tri_io[3:0]
#   axi_gpio_1  4-bit input   -> btn_tri_io[3:0]
#   axi_gpio_2  1-bit input   -> sw_tri_io[0]
# ===========================================================================


# ---------------------------------------------------------------------------
# Clock - on-board 50 MHz PL oscillator
# ---------------------------------------------------------------------------
# Unused in the Zynq PS version, where FCLK_CLK0 came out of the PS7 block
# and Vivado constrained it automatically. Here it is the only clock source.

set_property -dict {PACKAGE_PIN N18 IOSTANDARD LVCMOS33} [get_ports clk_50m]
create_clock -period 20.000 -name sys_clk [get_ports clk_50m]


# ---------------------------------------------------------------------------
# Reset - on-board PL key K3, active low
# ---------------------------------------------------------------------------
# Matches the Active Low setting of ext_reset_in on Processor System Reset.
# Using the on-board key keeps all four breadboard buttons free for the
# running light itself.

set_property -dict {PACKAGE_PIN P16 IOSTANDARD LVCMOS33 PULLUP true} [get_ports reset_n]
set_false_path -from [get_ports reset_n]


# ---------------------------------------------------------------------------
# Running-light LEDs - axi_gpio_0, all outputs
# ---------------------------------------------------------------------------
# ~1.3 mA through the 1K series resistor, so DRIVE 4 is plenty.
# SLEW SLOW keeps edges calm on long breadboard jumpers.

set_property -dict {PACKAGE_PIN V15 IOSTANDARD LVCMOS33 DRIVE 4 SLEW SLOW} [get_ports {led_tri_io[0]}]
set_property -dict {PACKAGE_PIN W15 IOSTANDARD LVCMOS33 DRIVE 4 SLEW SLOW} [get_ports {led_tri_io[1]}]
set_property -dict {PACKAGE_PIN P14 IOSTANDARD LVCMOS33 DRIVE 4 SLEW SLOW} [get_ports {led_tri_io[2]}]
set_property -dict {PACKAGE_PIN R14 IOSTANDARD LVCMOS33 DRIVE 4 SLEW SLOW} [get_ports {led_tri_io[3]}]

# Board signal names for reference:
#   V15 = GPIO1_13P (JP1-31)
#   W15 = GPIO1_13N (JP1-32)
#   P14 = GPIO1_14P (JP1-33)
#   R14 = GPIO1_14N (JP1-34)


# ---------------------------------------------------------------------------
# Buttons - axi_gpio_1, all inputs
# ---------------------------------------------------------------------------
# PULLUP is mandatory: nothing else holds these pins high when released.
# Software roles:
#   btn[0] faster, btn[1] slower, btn[2] stop/resume, btn[3] reset defaults

set_property -dict {PACKAGE_PIN L19 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {btn_tri_io[0]}]
set_property -dict {PACKAGE_PIN L20 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {btn_tri_io[1]}]
set_property -dict {PACKAGE_PIN F19 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {btn_tri_io[2]}]
set_property -dict {PACKAGE_PIN F20 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {btn_tri_io[3]}]

# Board signal names for reference:
#   L19 = GPIO2_13P (JP2-31)
#   L20 = GPIO2_13N (JP2-32)
#   F19 = GPIO2_14P (JP2-33)
#   F20 = GPIO2_14N (JP2-34)


# ---------------------------------------------------------------------------
# Direction switch - axi_gpio_2, input
# ---------------------------------------------------------------------------
# Released (open) reads 1 = forward, closed to GND reads 0 = reverse.

set_property -dict {PACKAGE_PIN M19 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {sw_tri_io[0]}]

# M19 = GPIO2_15P (JP2-35)


# ---------------------------------------------------------------------------
# Timing exceptions
# ---------------------------------------------------------------------------
# Mechanical contacts are asynchronous to sys_clk. Debouncing happens in
# software, so there is no timing path worth analysing on these inputs.

set_false_path -from [get_ports {btn_tri_io[*]}]
set_false_path -from [get_ports {sw_tri_io[*]}]


# ---------------------------------------------------------------------------
# Bitstream / configuration settings
# ---------------------------------------------------------------------------
# Without these two the bitstream generation fails a DRC check on Zynq-7000,
# even when only the PL side of the device is used.

set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]


# ---------------------------------------------------------------------------
# Sanity check after implementation (paste into the Tcl console)
# ---------------------------------------------------------------------------
# A typo in a port name makes get_ports return an empty list and
# set_property then silently does nothing. Verify the properties landed:
#
#   foreach p [get_ports -quiet {led_tri_io[*] btn_tri_io[*] sw_tri_io[*] clk_50m reset_n}] {
#       puts [format "%-16s %-6s %-9s %s" \
#           $p \
#           [get_property PACKAGE_PIN  $p] \
#           [get_property IOSTANDARD   $p] \
#           [get_property PULLTYPE     $p]]
#   }
#
# Every line must show a package pin and LVCMOS33. Inputs must show PULLUP.
# ===========================================================================

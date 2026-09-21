# ===========================================================================
# Z7-Lite (MicroPhase) - XC7Z010-1CLG400
# Lab 1: Zynq PS + AXI GPIO + AXI Timer - running light
#
# External wiring (breadboard):
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
# Port names assume the AXI GPIO interfaces were renamed in the block
# design to "leds", "btns" and "sws" before Make External. With Vivado's
# default names the ports would be gpio_rtl_0_tri_o etc. - rename the
# interfaces or adjust every get_ports below.
#
# GPIO mapping:
#   axi_gpio_0  ch1  4-bit output  -> leds_tri_o[3:0]
#   axi_gpio_1  ch1  4-bit input   -> btns_tri_i[3:0]
#   axi_gpio_1  ch2  1-bit input   -> sws_tri_i[0]
#
# No clock constraint is needed here: the whole AXI fabric is clocked from
# FCLK_CLK0 inside the PS7 block, which Vivado constrains automatically.
# The on-board 50 MHz PL oscillator (N18) is unused in this design.
# ===========================================================================


# ---------------------------------------------------------------------------
# Running-light LEDs - axi_gpio_0, channel 1, all outputs
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
# Buttons - axi_gpio_1, channel 1, all inputs
# ---------------------------------------------------------------------------
# PULLUP is mandatory: nothing else holds these pins high when released.
# Suggested software roles:
#   btns[0] speed up, btns[1] speed down, btns[2] stop/resume, btns[3] spare

set_property -dict {PACKAGE_PIN L19 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {button_tri_io[0]}]
set_property -dict {PACKAGE_PIN L20 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {button_tri_io[1]}]
set_property -dict {PACKAGE_PIN F19 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {button_tri_io[2]}]
set_property -dict {PACKAGE_PIN F20 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {button_tri_io[3]}]

# Board signal names for reference:
#   L19 = GPIO2_13P (JP2-31)
#   L20 = GPIO2_13N (JP2-32)
#   F19 = GPIO2_14P (JP2-33)
#   F20 = GPIO2_14N (JP2-34)


# ---------------------------------------------------------------------------
# Direction switch - axi_gpio_1, channel 2, input
# ---------------------------------------------------------------------------
# Released (open) reads 1 = forward, closed to GND reads 0 = reverse.

set_property -dict {PACKAGE_PIN M19 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {sw_tri_io[0]}]

# M19 = GPIO2_15P (JP2-35)


# ---------------------------------------------------------------------------
# On-board PL LED and key - optional
# ---------------------------------------------------------------------------
# D4 is wired anode-to-VCC_3V3, so it is ACTIVE LOW unlike the external ones.
# Useful as a heartbeat driven from a spare GPIO bit. Widen axi_gpio_0
# channel 1 to 5 bits and uncomment, or delete this block entirely.
#
# set_property -dict {PACKAGE_PIN P15 IOSTANDARD LVCMOS33 DRIVE 4} [get_ports {leds_tri_o[4]}]
# set_property -dict {PACKAGE_PIN P16 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {btns_tri_i[4]}]
#
#   P15 = PL_LED1 (D4)
#   P16 = PL_KEY1 (K3)


# ---------------------------------------------------------------------------
# Timing exceptions
# ---------------------------------------------------------------------------
# Mechanical contacts are asynchronous to FCLK_CLK0. Debouncing happens in
# software, so there is no timing path worth analysing on these inputs.

set_false_path -from [get_ports {button_tri_io[*]}]
set_false_path -from [get_ports {sw_tri_io[*]}]


# ---------------------------------------------------------------------------
# Bitstream / configuration settings
# ---------------------------------------------------------------------------
# Without these two the bitstream generation fails a DRC check on Zynq-7000.

set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]


# ---------------------------------------------------------------------------
# Sanity check after implementation (paste into the Tcl console)
# ---------------------------------------------------------------------------
# A typo in a port name makes get_ports return an empty list and
# set_property then silently does nothing. Verify the properties landed:
#
#   foreach p [get_ports -quiet {leds_tri_o[*] btns_tri_i[*] sws_tri_i[*]}] {
#       puts [format "%-16s %-6s %-9s %s" \
#           $p \
#           [get_property PACKAGE_PIN  $p] \
#           [get_property IOSTANDARD   $p] \
#           [get_property PULLTYPE     $p]]
#   }
#
# Every line must show a package pin and LVCMOS33. Inputs must show PULLUP.
# ===========================================================================

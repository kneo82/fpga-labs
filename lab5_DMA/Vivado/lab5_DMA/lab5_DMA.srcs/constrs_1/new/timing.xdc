# ===========================================================================
# Lab 5: MicroBlaze + frame_rx + AXI DMA + axi4_full_ram
#
# Timing constraints only. The design is verified in behavioral simulation,
# so no pin assignments are needed -- the external ports stay unplaced.
#
# Without these constraints the project synthesises and implementation
# reports "all timing constraints are met", but the claim is empty: with no
# clock defined, 30788 endpoints had nothing to be measured against and were
# simply skipped. A green summary over an unanalysed design is worse than a
# red one, because it looks like a result.
# ===========================================================================


# ---------------------------------------------------------------------------
# Clocks
# ---------------------------------------------------------------------------
# System clock: drives MicroBlaze, the AXI fabric, the DMA and the AXI side
# of frame_rx.
create_clock -period 20.000 -name sys_clk [get_ports clk_50m]

# Pixel clock: the external frame source runs on its own oscillator.
# 34 ns (~29.4 MHz) matches the testbench, where the two frequencies are
# deliberately unrelated so the clock domain crossing is actually exercised.
create_clock -period 34.000 -name pix_clk [get_ports pix_clk_0]


# ---------------------------------------------------------------------------
# Clock domain crossing
# ---------------------------------------------------------------------------
# The two domains are independent. The crossing is handled explicitly by the
# asynchronous FIFO and the xpm_cdc synchronisers inside frame_rx, so timing
# analysis between them is meaningless and would report false violations.
set_clock_groups -asynchronous \
    -group [get_clocks sys_clk] \
    -group [get_clocks pix_clk]


# ---------------------------------------------------------------------------
# Asynchronous inputs
# ---------------------------------------------------------------------------
# Frame data arrives from outside the design with no defined phase relation
# to any clock here; frame_rx samples it in the pixel domain.
set_false_path -from [get_ports {pix_data_0[*]}]
set_false_path -from [get_ports pix_valid_0]

# System reset is synchronised internally by Processor System Reset.
set_false_path -from [get_ports reset_n]

# ---------------------------------------------------------------------------
# Pin assignment
#
# The design is verified in behavioral simulation; no real frame source is
# connected. Pins are assigned so that the bitstream can be generated and the
# external interface stays physically reachable on the expansion headers.
# ---------------------------------------------------------------------------

# System clock: on-board 50 MHz PL oscillator
set_property -dict {PACKAGE_PIN N18 IOSTANDARD LVCMOS33} [get_ports clk_50m]

# System reset: on-board PL key K3, active low
set_property -dict {PACKAGE_PIN P16 IOSTANDARD LVCMOS33 PULLUP true} [get_ports reset_n]

# Frame source clock: JP1-35
set_property -dict {PACKAGE_PIN U18 IOSTANDARD LVCMOS33} [get_ports pix_clk_0]

set_property -dict {PACKAGE_PIN H20 IOSTANDARD LVCMOS33} [get_ports {pix_data_0[6]}]
set_property -dict {PACKAGE_PIN G20 IOSTANDARD LVCMOS33} [get_ports {pix_data_0[7]}]

set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
# Frame source valid: JP1-36
set_property -dict {PACKAGE_PIN T15 IOSTANDARD LVCMOS33} [get_ports pix_valid_0]

# Frame data: JP1-37, 38, and JP2-36..41
set_property -dict {PACKAGE_PIN P18 IOSTANDARD LVCMOS33} [get_ports {pix_data_0[0]}]
set_property -dict {PACKAGE_PIN R18 IOSTANDARD LVCMOS33} [get_ports {pix_data_0[1]}]
set_property -dict {PACKAGE_PIN M20 IOSTANDARD LVCMOS33} [get_ports {pix_data_0[2]}]
set_property -dict {PACKAGE_PIN K19 IOSTANDARD LVCMOS33} [get_ports {pix_data_0[3]}]
set_property -dict {PACKAGE_PIN K18 IOSTANDARD LVCMOS33} [get_ports {pix_data_0[4]}]
set_property -dict {PACKAGE_PIN J20 IOSTANDARD LVCMOS33} [get_ports {pix_data_0[5]}]

# Capture trigger: on-board PL key K4 (GPIO1_17P), active low.
# K3 (P16) is already taken by the system reset.
set_property -dict {PACKAGE_PIN T12 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {btn_tri_i[0]}]
set_false_path -from [get_ports {btn_tri_i[*]}]
#!/bin/bash
#------------------------------------------------------------------------------
# run_sim.sh
#
# Compiles and simulates the counter testbench.
#
#   ./run_sim.sh        console mode, prints the PASS/FAIL report and exits
#   ./run_sim.sh gui    opens the XSim GUI for waveform inspection
#
# The -sv flag is required: the testbench uses the SystemVerilog string type
# in the check_count task, while the files carry the .v extension.
#------------------------------------------------------------------------------

set -e

TOP=tb_counter
SNAPSHOT=tb_sim
SOURCES="counter.v tb_counter.v"

if [ "$1" = "gui" ]; then
    # -debug typical keeps signals visible in the Objects window
    xvlog -sv $SOURCES
    xelab $TOP -s $SNAPSHOT -debug typical
    xsim $SNAPSHOT -gui
else
    xvlog -sv $SOURCES
    xelab $TOP -s $SNAPSHOT
    xsim $SNAPSHOT -R
fi
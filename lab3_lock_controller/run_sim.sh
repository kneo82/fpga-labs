#!/bin/bash
# Compile and run the lock_controller testbench in console mode.
#   ./run_sim.sh        console mode with PASS/FAIL report
#   ./run_sim.sh gui    opens XSim GUI for waveform inspection

set -e

DUT=lab3_lock_controller.srcs/sources_1/new
TB=lab3_lock_controller.srcs/sim_1/new
SOURCES="$DUT/lock_controller.v $TB/tb_lock_controller.v"

if [ "$1" = "gui" ]; then
    xvlog $SOURCES
    xelab tb_lock_controller -s tb_sim -debug typical
    xsim tb_sim -gui
else
    xvlog $SOURCES
    xelab tb_lock_controller -s tb_sim
    xsim tb_sim -R
fi
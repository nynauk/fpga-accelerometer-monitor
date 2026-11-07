#!/usr/bin/env bash
# Runs the bin2BCD testbench and elaborates the full design with GHDL (open-source VHDL simulator).
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build && cd build
OPTS="--std=08 -fsynopsys"
ghdl -a $OPTS ../src/bin2BCD.vhd ../sim/bin2BCD_tb.vhd
ghdl -e $OPTS bin2BCD_tb
ghdl -r $OPTS bin2BCD_tb | tee bin2BCD_tb.log
grep -q "ALL TESTS PASSED" bin2BCD_tb.log
ghdl -a $OPTS ../src/supplied/SPI_If.vhd ../src/supplied/ADXL362Ctrl.vhd ../src/supplied/ACC_XYZ.vhd \
    ../src/clock.vhd ../src/counter.vhd ../src/mux.vhd ../src/DAnC.vhd ../src/bin2seg.vhd \
    ../src/bin2BCD.vhd ../src/display.vhd ../src/accel_monitor_top.vhd
ghdl -e $OPTS accel_monitor_top
echo "Testbench passed and accel_monitor_top elaborates."

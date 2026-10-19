#!/usr/bin/env bash
# Magic + Netgen LVS for an ihp-sg13cmos5l chip, without LibreLane.
# Same method as LibreLane: Magic extracts from DEF + LEF, Netgen compares
# in black-box mode (cells are compared by pins only).
#
# Usage: ./lvs.sh TOP DEF NETLIST [EXTRA_LEF ...]
#        ./lvs.sh --no-extract TOP LAYOUT_SPICE NETLIST
#   TOP        top cell name, e.g. chip_top
#   DEF        final DEF (ORFS: 6_final.def)
#   NETLIST    Verilog netlist WITH power pins, from OpenROAD:
#                read_db 6_final.odb
#                write_verilog -include_pwr_gnd chip_top.pnl.v
#   EXTRA_LEF  LEFs of cells not in the PDK (bondpads, macros)
#   --no-extract  skip Magic and compare an already extracted LAYOUT_SPICE
# Needs magic, netgen and PDK_ROOT (folder that contains ihp-sg13cmos5l/).
# Output goes to ./lvs_out/. Exit code 0 means LVS clean.
set -euo pipefail

extract=1
if [ "${1:-}" = --no-extract ]; then extract=0; shift; fi
top=$1; input=$(realpath "$2"); netlist=$(realpath "$3"); shift 3
extra_lefs=""
for lef in "$@"; do extra_lefs+=" $(realpath "$lef")"; done

pdk=${PDK_ROOT:?Set PDK_ROOT}/ihp-sg13cmos5l
stdcell=$pdk/libs.ref/sg13cmos5l_stdcell
io=$pdk/libs.ref/sg13cmos5l_io

mkdir -p lvs_out
cd lvs_out

# 1. Extract the layout netlist with Magic
if [ $extract = 1 ]; then
layout=$PWD/$top.spice
cat > extract.tcl <<EOF
drc off
locking disable
lef read $stdcell/lef/sg13cmos5l_tech.lef
lef read $stdcell/lef/sg13cmos5l_stdcell.lef
lef read $io/lef/sg13cmos5l_io.lef
foreach lef [list $extra_lefs] { lef read \$lef }
def read $input -noblockage
readspice $stdcell/spice/sg13cmos5l_stdcell.spice
load $top -dereference
extract do local
extract no capacitance
extract no coupling
extract no resistance
extract no adjust
extract unique notopports
extract
ext2spice lvs
ext2spice -o $top.spice $top.ext
quit -noprompt
EOF
magic -dnull -noconsole -rcfile "$pdk/libs.tech/magic/ihp-sg13cmos5l.magicrc" extract.tcl > magic.log 2>&1
else
layout=$input
fi

# 2. Compare layout and netlist with Netgen
cat > compare.lvs <<EOF
set layout [readnet spice $layout]
set schematic [readnet spice $stdcell/spice/sg13cmos5l_stdcell.spice]
readnet spice $io/spice/sg13cmos5l_io.spice \$schematic
readnet verilog $netlist \$schematic
lvs "\$layout $top" "\$schematic $top" $pdk/libs.tech/netgen/ihp-sg13cmos5l_setup.tcl lvs.rpt -blackbox
EOF
netgen -batch source compare.lvs > netgen.log 2>&1

echo "Report: $PWD/lvs.rpt"
grep 'Final result' lvs.rpt
grep -q 'Circuits match uniquely' lvs.rpt

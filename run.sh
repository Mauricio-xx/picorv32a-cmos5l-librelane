#!/usr/bin/env bash
# ./run.sh        run the full LibreLane flow
# ./run.sh sim    run the RTL simulation
set -euo pipefail
cd "$(dirname "$0")"

PDK_COMMIT=89d42ee6d2fd9b50b86a1aada6fee6673c3e6008
export PDK=ihp-sg13cmos5l
export PDK_ROOT="$PWD/pdk"
export KLAYOUT_PATH="$PDK_ROOT/$PDK/libs.tech/klayout"

if [ "${1:-}" = sim ]; then
    cmd="iverilog -g2012 -DFUNCTIONAL -s chip_top_tb -o sim/chip_top_tb.vvp \
        sim/chip_top_tb.sv src/chip_top.sv src/chip_core.sv src/picorv32a.v \
        $PDK_ROOT/$PDK/libs.ref/sg13cmos5l_io/verilog/sg13cmos5l_io.v
        vvp -n sim/chip_top_tb.vvp"
else
    cmd="librelane librelane/config.yaml --pdk $PDK --pdk-root $PDK_ROOT --manual-pdk"
fi

# The flake pins LibreLane and all tools; ciel downloads the pinned PDK.
nix develop --accept-flake-config --command bash -c "
    set -e
    ciel enable --pdk-root $PDK_ROOT --pdk-family ihp-sg13 $PDK_COMMIT
    $cmd"

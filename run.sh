#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Usage: ./run.sh [flow [LibreLane options] | sim | check [run dir]]
set -euo pipefail
design_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cd "$design_dir"
source ./versions.env
mode=${1:-flow}
if (($#)); then shift; fi

if [[ "$mode" == check ]]; then
    run=${1:-$(ls -d librelane/runs/*/ | tail -n 1)}
    run=${run%/}
    ls -d "$run"/*-netgen-lvs "$run"/*-checker-lvs >/dev/null || exit 1
    echo "Run: $run"
    grep -h 'Final result' "$run"/*-netgen-lvs/reports/lvs.netgen.rpt
    python3 -c 'import json,sys; m=json.load(open(sys.argv[1]))["metrics"]
for k in sorted(m):
    if k.startswith("design__lvs"): print(k, m[k])' "$run"/*-checker-lvs/state_out.json
    exit 0
fi

# Always use the pinned PDK under ./pdk. An exported PDK_ROOT is ignored on
# purpose, since it would otherwise point at an unpinned checkout.
export PDK_ROOT="$design_dir/pdk" PDK=ihp-sg13cmos5l
export KLAYOUT_PATH="$PDK_ROOT/$PDK/libs.tech/klayout"
unset KLAYOUT_HOME

in_nix() {
    nix develop "$design_dir" --accept-flake-config --command bash -c "$@"
}

prep='ciel enable --pdk-root "$PDK_ROOT" --pdk-family ihp-sg13 "$PDK_REV"'
export PDK_REV
case "$mode" in
    flow)
        mkdir -p librelane/runs
        in_nix "set -euo pipefail; $prep
            exec librelane librelane/config.yaml --pdk \"\$PDK\" \
                --pdk-root \"\$PDK_ROOT\" --manual-pdk \"\$@\"" bash "$@"
        ;;
    sim)
        mkdir -p runs
        in_nix "set -euo pipefail; $prep
            iverilog -g2012 -DFUNCTIONAL -s chip_top_tb -o runs/chip_top_tb.vvp \
                sim/chip_top_tb.sv src/chip_top.sv src/chip_core.sv \
                src/picorv32a.v \
                \"\$PDK_ROOT/\$PDK/libs.ref/sg13cmos5l_io/verilog/sg13cmos5l_io.v\"
            vvp -n runs/chip_top_tb.vvp"
        ;;
    *) echo "Usage: $0 [flow [LibreLane options] | sim | check [run dir]]" >&2; exit 2 ;;
esac

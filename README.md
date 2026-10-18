# PicoRV32 full chip on ihp-sg13cmos5l with LibreLane

A small full-chip example: a PicoRV32 core with pad ring, bondpads, power ring and seal ring, taken from RTL to GDS with LibreLane and checked with LVS. It follows the [IHP LibreLane template](https://github.com/IHP-GmbH/ihp-sg13-librelane-template).

## Run

You need Nix with flakes enabled.

```bash
./run.sh        # full flow, about 15 minutes
./run.sh sim    # RTL simulation (optional)
```

The first run downloads the tools and the PDK into `./pdk`. Results go to `librelane/runs/<timestamp>/`. LVS is clean when the Netgen report (`*-netgen-lvs/reports/lvs.netgen.rpt`) says `Final result: Circuits match uniquely.`.

## Files

- `src/`: RTL. `chip_top.sv` instantiates the IO pads and wraps the core in `chip_core.sv`.
- `librelane/config.yaml`: the flow configuration (the LibreLane counterpart of an ORFS `config.mk`). The pads go around the die in the order listed under `PAD_SOUTH`, `PAD_EAST`, `PAD_NORTH` and `PAD_WEST`.
- `librelane/chip_top.sdc`: timing constraints.
- `ip/`: bondpad GDS and LEF.
- `sim/`: testbench.
- `flake.nix`, `flake.lock`: pin LibreLane and all tools.

## About the LVS

LibreLane's default LVS is Magic extraction plus Netgen, and Netgen always runs in black-box mode. So the IO cells (and standard cells) are compared by their pins only, and the pass means the wiring between cells is right. It does not check inside the IO cells. A device-level LVS of the IO cells, with KLayout or with Netgen, does not pass today because the PDK's IO layouts and netlists still disagree.

DRC, antenna and density checks are turned off in `config.yaml` so the flow finishes. With them on, Magic DRC reports thousands of errors. This example says nothing about DRC.

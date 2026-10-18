# PicoRV32 full chip on ihp-sg13cmos5l with LibreLane

This is what a full-chip ihp-sg13cmos5l project looks like in LibreLane today. It follows the [IHP LibreLane template](https://github.com/IHP-GmbH/ihp-sg13-librelane-template): a PicoRV32 core with a pad ring, bondpads, core power ring and seal ring, taken through RTL to GDS and LVS with the `Chip` flow. The LVS is the LibreLane default, Magic extraction plus Netgen, and it comes out clean. Read the last section before quoting that pass.

The core is PicoRV32 (`src/picorv32a.v`, ISC license in its header) with a small fixed-program ROM. Everything else is Apache-2.0 (`LICENSE`, and `ip/LICENSE` for the bondpad).

## Layout of the project

If you come from ORFS, `librelane/config.yaml` plays the role of `config.mk`, and the flake pins every tool the way an ORFS docker image would. The IO cells are instantiated in RTL (`src/chip_top.sv`, which wraps `src/chip_core.sv`). The config only lists the pad instances per side (`PAD_SOUTH`, `PAD_EAST`, `PAD_NORTH`, `PAD_WEST`). LibreLane then builds the ring, places the bondpads (`PAD_BONDPAD_NAME`, with GDS and LEF in `ip/`) and connects the core ring to the supply pads (`PDN_CORE_RING_CONNECT_TO_PADS`). The SDC is `librelane/chip_top.sdc`, and the testbench is `sim/chip_top_tb.sv`.

## Run it

You need Nix with flakes enabled. Clone this repository and run everything from its root. The first run also fetches the tools from the FOSSi binary cache and the PDK. Then:

```bash
./run.sh            # full flow, about 15 minutes on 16 cores
./run.sh check      # print the LVS verdict of the latest run
./run.sh sim        # optional RTL simulation with the PDK IO models
```

`run.sh` enters the Nix shell defined by `flake.nix`/`flake.lock`, installs the pinned PDK into `./pdk` with `ciel`, then runs:

```bash
librelane librelane/config.yaml --pdk ihp-sg13cmos5l --pdk-root ./pdk --manual-pdk
```

An exported `PDK_ROOT` is ignored on purpose: the run always uses `./pdk`. Extra arguments go to LibreLane, for example `./run.sh flow --run-tag demo`.

## Versions

`flake.nix` and `flake.lock` are byte copies of the template at `2c7d3b39580f9d165306a008608b8fb28c616a02`. They lock LibreLane `c5b5099e` (3.1.0.dev3), Magic 8.3.677 and Netgen 1.5.323. The PDK is IHP-Open-PDK `89d42ee6d2fd9b50b86a1aada6fee6673c3e6008`, installed with ciel 3.0.0. All pins are also in `versions.env`.

## Expected output

The flow finishes without errors. `./run.sh check` prints:

```
Final result: Circuits match uniquely.
design__lvs_device_difference__count 0
design__lvs_error__count 0
design__lvs_net_difference__count 0
design__lvs_property_fail__count 0
design__lvs_unmatched_device__count 0
design__lvs_unmatched_net__count 0
design__lvs_unmatched_pin__count 0
```

The Netgen report is `librelane/runs/<tag>/*-netgen-lvs/reports/lvs.netgen.rpt`.

DRC, antenna and density signoff are switched off in `librelane/config.yaml` (`Magic.DRC`, `KLayout.DRC`, `KLayout.Antenna`, `KLayout.Density` and their checkers). On the stock template Magic DRC alone reports 9943 errors and stops `make`, so the run would never reach a usable end state. `Checker.IllegalOverlap` is off as in the template. This run says nothing about DRC.

## LVS: why Netgen in black-box mode

LibreLane runs `Magic.SpiceExtraction`, then `Netgen.LVS`, then `Checker.LVS`, and this repo keeps those defaults. LibreLane also has a `KLayout.LVS` step, and the PDK ships a KLayout LVS deck. A device-level KLayout LVS of this chip does not pass today, because the IO cell layouts and their schematic views disagree in several places. Netgen gets a clean result only because it treats the IO cells as black boxes (next section). A KLayout LVS variant of this design is being prepared and may be added here later.

## What this does NOT check

With the defaults, Magic extracts from DEF and LEF, not from GDS (`MAGIC_EXT_USE_GDS` is false), and LibreLane always calls Netgen with `-blackbox`. Every IO cell, standard cell and bondpad is therefore an empty abstract with 0 devices on the layout side. The schematic side has full IO netlists (IOPadInOut30mA has 62 devices), but Netgen compares each cell on its pins only. The pass means the chip-level wiring between cell pins matches the netlist. It says nothing about what is inside the IO cells.

We tried the device-level comparison and it does not pass today. With `MAGIC_EXT_USE_GDS: true`, every IO cell fails in chip context while all standard cells match. Comparing the 22 IO cells of the PDK GDS standalone against the shipped SPICE view gives 0 of 22 matches, with both the default and the `lvs` Magic extract style. The main reason in the LibreLane path is that the default Magic style merges every substrate tap into the substrate. vss, iovss and the substrate then become one net, so Netgen could not catch a vss/iovss swap even if the IO cells were compared. The other causes are the ones known from KLayout: a local `sub!` per cell in the SPICE view, tap area/perimeter conventions, split pins, and the `sg13g2_SecondaryProtection` reference in LevelDown. LibreLane offers no setting to change the extract style. The categorized findings are in the SUMMARY.md of the io-lvs-cmos5l-netgen study (ask the author for a copy).

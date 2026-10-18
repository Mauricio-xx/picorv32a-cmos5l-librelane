# PicoRV32 full chip, Magic + Netgen LVS (ihp-sg13cmos5l)

This is the PicoRV32 full-chip example (pad ring, bondpads, core power ring, seal ring) run through the stock LVS of the [IHP LibreLane template](https://github.com/IHP-GmbH/ihp-sg13-librelane-template): `Magic.SpiceExtraction`, then `Netgen.LVS`, then `Checker.LVS`, all with LibreLane defaults. It shows what a template user gets today on ihp-sg13cmos5l: a clean LVS where the IO cells are black boxes. Read the last section before quoting the pass.

The core is PicoRV32 (`src/picorv32a.v`, ISC license in its header) with a small fixed-program ROM. The pad wrapper, SDC, testbench and `bondpad_70x70_5L` (`ip/`, see `ip/LICENSE`) come from the picorv32a_fullchip KLayout LVS testcase in ihp-librelane-testcases. None of its KLayout LVS pieces are used here. Everything else is Apache-2.0 (`LICENSE`).

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

## What this does NOT check

With the defaults, Magic extracts from DEF and LEF, not from GDS (`MAGIC_EXT_USE_GDS` is false), and LibreLane always calls Netgen with `-blackbox`. Every IO cell, standard cell and bondpad is therefore an empty abstract with 0 devices on the layout side. The schematic side has full IO netlists (IOPadInOut30mA has 62 devices), but Netgen compares each cell on its pins only. The pass means the chip-level wiring between cell pins matches the netlist. It says nothing about what is inside the IO cells.

We tried the device-level comparison and it does not pass today. With `MAGIC_EXT_USE_GDS: true`, every IO cell fails in chip context while all standard cells match. Comparing the 22 IO cells of the PDK GDS standalone against the shipped SPICE view gives 0 of 22 matches, with both the default and the `lvs` Magic extract style. The main reason in the LibreLane path is that the default Magic style merges every substrate tap into the substrate. vss, iovss and the substrate then become one net, so Netgen could not catch a vss/iovss swap even if the IO cells were compared. The other causes are the ones known from KLayout: a local `sub!` per cell in the SPICE view, tap area/perimeter conventions, split pins, and the `sg13g2_SecondaryProtection` reference in LevelDown. LibreLane offers no setting to change the extract style. The categorized findings are in the SUMMARY.md of the io-lvs-cmos5l-netgen study (ask the author for a copy).

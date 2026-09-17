# wfde5-ecland

Global ecLand experiments driven by WFDE5, with runoff prepared for
CaMa-Flood routing.

## Status

**Repository structure and design documents only. No forcing has been
downloaded, no ecLand run has been made, and no line of code in this repo has
been executed successfully yet.** See "Current status" below and `PLAN.md`
for the honest, itemised state. Nothing here should be read as "this works" —
only as "this is the plan, informed by real findings from a related project."

## Scientific purpose

Build a reproducible global historical land-surface + river-routing modelling
chain:

```
WFDE5_CRU_GPCC hourly forcing
        |
        v
forcing acquisition / QC / unit conversion
        |
        v
ecLand 0.5-degree global
        |
        v
surface runoff + subsurface runoff
        |
        v
conservative runoff transfer
        |
        v
CaMa-Flood
        |
        v
Q / river storage / flood storage / flood diagnostics
```

See `docs/workflow.md` for the annotated version and `docs/cama_interface.md`
for the runoff-transfer step's design.

## Relation to `liaise-ecland`

[`liaise-ecland`](https://github.com/gpbalsamo/liaise-ecland) built and
validated the same ecLand-CaMa-Flood chain over a small regional domain (the
LIAISE campaign area, Ebro basin, Spain) across 37 years, three CaMa-Flood
routing resolutions, and against real river gauges. This repository is a
**global generalisation**, not a fork — regional assumptions (grid dimensions,
basin-specific dam/reservoir modelling, LIAISE campaign forcing products) are
intentionally left behind. What is carried forward is: code that was already
grid-agnostic, and hard-won correctness findings that would be expensive to
rediscover (a runoff sign-convention bug, a silently-broken restart chain, an
inherited environment variable that silently defeated multi-threading, and
several others). The full file-by-file reuse decision is in
[`docs/migration_from_liaise.md`](docs/migration_from_liaise.md).

## Role in the ecLand benchmark cascade

`wfde5-ecland` is the **global** stage of a wider, deliberately staged ecLand
validation cascade spanning several sibling repositories. Each level is
cheaper to run and to debug than the one below it, so a failure is meant to
be caught before an expensive global/decadal run is ever attempted:

```
LEVEL 0  SOFTWARE     official ecLand build + unit/ctest checks
              |
LEVEL 1  SITE          plumber2-ecland — point-scale process evaluation
              |         (energy, water, carbon, snow, soil moisture, fluxes)
LEVEL 2  REGION        liaise-ecland — regional forcing/grid consistency,
              |         surfclim/soilinit, spatial fluxes, regional CaMa-Flood
LEVEL 3  GLOBAL        wfde5-ecland (this repo) — global forcing, land water
              |         balance, snow/soil-moisture/runoff climatology
LEVEL 4  ROUTING       CaMa-Flood — global discharge, storage, flood diagnostics
              |
LEVEL 5  BENCHMARKING  GRDC / ifs-riverbench / real flood observations
```

- [`ecLand4U`](https://github.com/gpbalsamo/ecLand4U) — the gateway/build/
  learning layer (install, build, test, first-run instructions for the
  official [`ecmwf-ifs/ecland`](https://github.com/ecmwf-ifs/ecland)).
- [`plumber2-ecland`](https://github.com/gpbalsamo/plumber2-ecland) — Level 1,
  site benchmark.
- [`liaise-ecland`](https://github.com/gpbalsamo/liaise-ecland) — Level 2,
  regional benchmark (see "Relation to `liaise-ecland`" above).
- `wfde5-ecland` (this repo) — Level 3, global benchmark, plus Level 4
  (CaMa-Flood routing) wiring.

This repository does not duplicate the sibling repos' scientific code. It
exposes a small, deterministic **agent/orchestration interface** —
[`AGENTS.md`](AGENTS.md), [`docs/agent_quickstart.md`](docs/agent_quickstart.md),
[`docs/benchmark_contract.md`](docs/benchmark_contract.md), and
`scripts/benchmark.py` — so that a future cross-repo orchestrator (not built
here), or a low-footprint local coding agent (e.g. a 7B model run locally via
Ollama), can run and interpret each stage's checks without needing to read or
understand the full scientific codebase. See those documents for the current,
honestly-labelled state of that interface — most of it is scaffolding, not a
working pipeline yet (`PLAN.md`'s "Agent/cascade interface" milestone).

## WFDE5 forcing choice

The first (and, for now, only planned) forcing is **WFDE5 with CRU+GPCC
precipitation correction** (the `derived-near-surface-meteorological-variables`
CDS dataset, `cru_and_gpcc` reference for precipitation, plain `cru` for
everything else — see `config/wfde5.yaml` and `docs/forcing_variables.md` for
why these two request types cannot be merged into one). ERA5 and MSWEP
precipitation-sensitivity comparisons are a later milestone (`PLAN.md`
Milestone 7), not a near-term goal.

## Spatial-resolution philosophy

Two grids, deliberately kept distinct — see
[`docs/grid_strategy.md`](docs/grid_strategy.md):

- ecLand runs on WFDE5's **native 0.5° global grid**. Runoff generation is not
  interpolated to a finer grid, because doing so would not create additional
  meteorological information, only the appearance of it.
- CaMa-Flood may route that same runoff at a much finer resolution (down to
  3 arcmin or finer), since river-network/channel-geometry resolution is a
  separate concept from runoff-generation resolution. The reference project
  measured a real, positive effect of finer *routing* resolution on discharge
  skill using *identical* runoff input — see `liaise-ecland/PLAN.md`'s
  resolution-comparison result — which is exactly the effect this separation
  is designed to isolate cleanly.

## Reproducibility

Every experiment run through `run/run_ecland.sh` is expected to log its own
metadata: this repository's git commit, ecLand's own commit/version, the
forcing version used, an experiment ID, the date range, grid, executable
path, namelist, hostname, and start/end time (`PLAN.md` Milestone 3;
`experiments/<id>/` is where that metadata lands, without any output data
committed alongside it).

## Pilot strategy

No multi-decade global run is launched before a staged validation passes:

1. **Test A** — one day, global.
2. **Test B** — one month, global.
3. **Test C** — one full year, global, checked against a global water and
   energy budget before anything longer is attempted.

A well-observed large basin (Rhine, Mississippi, Amazon, or similar) may be
useful for fast end-to-end debugging, but does not replace the global
structural validation above. See `PLAN.md` Milestone 3 and Phase 10 of the
original migration specification for the reasoning.

## Directory structure

```
config/        wfde5.yaml, ecland.yaml, paths.example.yaml
forcing/       WFDE5 acquisition, preprocessing, validation
init_clim/     surfclim / soilinit construction on the exact ecLand grid
namelist/      ecLand + CaMa-Flood namelist templates
run/           ecLand run driver, restart chaining, water/energy budgets
cama_flood/    conservative runoff remap, CaMa-Flood routing
validation/    per-stage validation: forcing, runoff, discharge, water_balance
experiments/   one directory per experiment, metadata only
docs/          workflow, forcing-variable mapping, grid strategy, interface design
tests/         synthetic-fixture unit tests (no real WFDE5 archive needed)
```

Each directory has its own `README.md` stating its real status and what it
generalises from `liaise-ecland`, if anything.

## Requirements

- An ecLand executable, built separately — see
  [ECMWF ecLand](https://github.com/ecmwf-ifs/ecland) or the build walkthrough
  in [`ecLand4U`](https://github.com/gpbalsamo/ecLand4U). CaMa-Flood is
  compiled *into* `ecland-master-dp` for one-way coupling, so no second
  executable is needed once Milestones 4-5 land.
- ECMWF HPC modules for an actual run (not needed for anything below yet):
  `prgenv/intel`, `intel/2021.4`, `hpcx-openmpi/2.9`, `netcdf4/4.9.1`, `python3`.
- Python packages: `numpy`, `xarray`, `netCDF4`, `cdsapi`, `pyyaml` (see
  `pyproject.toml`); `pytest` for the test suite.
- A CDS API key (`~/.cdsapirc`) once forcing acquisition exists (Milestone 1)
  — for the *global* `derived-near-surface-meteorological-variables` request,
  much larger than any LIAISE-clipped pull.
- Shared ECMWF CaMa-Flood static data (`CMFDIR`) for
  `cama_flood/build_global_cmf_fixdir.sh`, once routing is exercised
  (Milestone 5).
- **No Git LFS needed yet.** Unlike `liaise-ecland`, this repo commits no
  validated ancillary/forcing/gauge data — see "Data policy" in `CLAUDE.md`.
  Real global surfclim/soilinit/forcing/CaMa-Flood inputs live outside the
  repo, referenced through `config/paths.yaml` (gitignored).

## Quick start

`liaise-ecland`'s own Quick start takes five steps from a clone to a checked
37-year run. This section mirrors that same stepwise shape for the eventual
**1988-2024 global** run — but, honestly, only step 1 is real today. The rest
are the exact commands this repo is being built toward, each labelled with
what actually exists right now; see `PLAN.md` for the itemised truth and
`CLAUDE.md`'s core rule before reading a step's presence here as "it runs."

### 1. Clone and verify

```bash
git clone git@github.com:gpbalsamo/wfde5-ecland.git
cd wfde5-ecland
python3 scripts/benchmark.py --profile fast
```

*Expect:* `RESULT: PASS`, 3/3 checks (Python syntax, Bash syntax, synthetic
tests). This is the one command in this whole Quick start that is fully
working today — see `docs/agent_quickstart.md`. No `git lfs pull` step: there
is nothing checked into LFS here (see "Requirements" above).

### 2. Configure paths and CDS access

```bash
cp config/paths.example.yaml config/paths.yaml   # edit for your machine
```

`config/wfde5.yaml` already covers `1979-2024`; a `1988-2024` experiment
(matching the period `liaise-ecland` validated regionally) is a sub-range of
that, so no config edit is needed for the date range itself — only the
machine-specific paths, and your own `~/.cdsapirc` (never committed; see
`.gitignore`). **Status: real file, but nothing downstream consumes it yet.**

### 3. Get the forcing — Milestone 1, **not yet available**

```bash
python3 forcing/download_wfde5.py --start-year 1988 --end-year 2024 --output-dir ...   # planned
python3 forcing/preprocess_wfde5.py --input-dir ... --output-dir ... \
    --start-year 1988 --end-year 2024                                                  # planned
python3 forcing/validate_wfde5.py --input-dir ...                                      # planned
```

Unlike `liaise-ecland` (IPSL mirror for 1988-2014 + CDS for 2015-2024), this
repo's global request has only one source — the CDS `cru`/`cru_and_gpcc`
split (see `docs/forcing_variables.md`) — since the IPSL mirror is a
LIAISE-domain-specific product. None of these three scripts exist yet; see
`forcing/README.md`.

### 4. Install the ancillary fields — Milestone 2, **not yet available**

```bash
init_clim/init_clim.sh                    # ported, never yet run against real global input
python3 init_clim/validate_init_grid.py   # planned, does not exist yet
```

`init_clim/init_clim.py` itself is already ported unchanged from
`liaise-ecland` (see `docs/migration_from_liaise.md`), already
grid-shape-agnostic, but has never been executed in this repository.

### 5. Choose a namelist — Milestone 2/3, **not yet available**

`namelist/templates/` holds only a `.gitkeep` until a pilot grid is chosen —
see `namelist/README.md` for the env-var-driven templating pattern this will
follow, generalised from `liaise-ecland/namelist/create_liaise_namelist.sh`.

### 6. Run ecLand — Milestone 3, **not yet available**

```bash
run/run_ecland.sh --start-date 1988-01-01 --end-date 2024-12-31 \
  --forcing-dir ... --surfclim ... --soilinit ... --ecland-exe ... --namelist ...   # planned
```

The full 1988-2024 run is not the first thing this repo attempts even once
`run_ecland.sh` exists — **the staged pilot (one day → one month → one full
year, each validated) must pass first**, see "Pilot strategy" above and
`PLAN.md` Milestone 3. This is a hard rule (`CLAUDE.md`), not a suggestion.

### 7. Check the output — Milestone 3, **not yet available**

```bash
python3 run/check_water_budget.py ...     # planned: global, area-weighted
python3 run/check_energy_budget.py ...    # planned: global, area-weighted
```

The *equation* (`Rainf+Snowf+Evap+Qs+Qsb -
DelIntercept-DelSoilMoist-DelSWE-DelAquifer ≈ 0`) is verified, carried from
`liaise-ecland`'s per-site version; the global, area-weighted aggregation is
new code that does not exist yet.

## Running coupled to CaMa-Flood

Milestone 4/5, **not yet available**:

```bash
python3 cama_flood/remap_runoff.py ...          # planned
python3 cama_flood/validate_remapping.py ...    # planned -- conservation gate, see docs/cama_interface.md
cama_flood/run_cama.sh ...                      # planned
```

`cama_flood/build_global_cmf_fixdir.sh` (+ its three vendored companion
tools) is already ported and already builds a genuinely global fix bundle at
any of `glb_15min`/`glb_06min`/`glb_03min`/`glb_01min` — but has not yet been
run in this repository. The runoff sign convention
(`total_runoff = -(Qs+Qsb)`, not `Qs-Qsb`) must be implemented from the
start, not discovered the way `liaise-ecland` did — see
`docs/cama_interface.md`.

## Current status

See [`PLAN.md`](PLAN.md) for the itemised, honestly-labelled milestone list
(DONE / IN PROGRESS / BLOCKED / NOT STARTED / NOT VERIFIED). As of this
writing: Milestone 0 (repository migration) is in progress; nothing past it
has started.

## Roadmap

Milestones 0-7 in `PLAN.md`: repository migration → WFDE5 forcing → ecLand
climatology/init → pilot ecLand run → runoff-to-CaMa interface → CaMa-Flood
routing → validation against real river gauges and global water balance →
forcing sensitivity (ERA5, MSWEP).

## License

Not yet decided; matches whatever `liaise-ecland` settles on, given the
shared codebase.

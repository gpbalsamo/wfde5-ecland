# PLAN.md

Living state tracker. Status labels are load-bearing, not decorative: **DONE**
means executed successfully and its own validation passed; **NOT VERIFIED**
means code/config exists but has not been run against real data; **NOT
STARTED** means neither exists. Nothing is marked DONE because a script was
written — see `CLAUDE.md`.

## Role in benchmark cascade

This repo is Level 3 (global) of a site→region→global→routing→benchmark
cascade — see README.md's "Role in the ecLand benchmark cascade" for the full
diagram and sibling-repo list (`ecLand4U`, `plumber2-ecland`, `liaise-ecland`).
Milestone 8 below tracks the agent/orchestration interface that makes this
repo's stages callable by a future cross-repo orchestrator or a low-footprint
local coding agent, separate from the scientific milestones (0-7).

## Milestone 0 — repository migration

- [x] Identify reusable `liaise-ecland` code — `docs/migration_from_liaise.md`,
      every named file actually read and classified A/B/C/D.
- [x] Create global directory structure.
- [x] Port Category A files unchanged (`init_clim/init_clim.py`,
      `cama_flood/build_global_cmf_fixdir.sh` + its 3 vendored companion
      tools, `cama_flood/vendor/`) — **files copied, syntax-checked
      (`py_compile`/`bash -n`), NOT YET EXECUTED against real data in this
      repo**. `cama_flood/aggregate_runoff_to_daily.py` (Category B) also
      carried over as a reference implementation, explicitly flagged
      NOT YET GENERALIZED in its own header.
- [ ] Generalise Category B files (remove LIAISE grid/domain constants, move
      to `config/`) — **NOT STARTED** except the reference copy above.
- [x] Remove regional assumptions from the *design* (grid strategy, interface
      docs) — `docs/grid_strategy.md`, `docs/cama_interface.md`.

## Milestone 1 — WFDE5 forcing

- [ ] Define required ecLand variables — **DONE for the CDS-side table**
      (`docs/forcing_variables.md`, carried from a verified source), **NOT
      VERIFIED for the ecLand-side conventions** (accumulated-vs-instantaneous,
      timestamp interpretation, longitude/latitude convention) — these are
      stated as open questions in that document, not assumed answered.
- [x] `forcing/download_wfde5.py` — **PORTED/GENERALISED** from
      `liaise-ecland/forcing/get_liaise_forcing_05_cds.py` (LIAISE bbox crop
      removed, `--months`/`--dry-run` added), syntax-checked and covered by
      `tests/test_download_wfde5.py` (synthetic fixtures, 4 tests, all
      pass). **NOT YET RUN against a real CDS request** — no WFDE5 data has
      been downloaded in this repository. Deliberately does not assert any
      global grid convention itself; see the next line.
- [ ] Obtain one month of global WFDE5 as a first real test, then one full
      year — **NOT STARTED**. Recommended invocation:
      `python3 forcing/download_wfde5.py --start-year 1988 --end-year 1988
      --months 01` (needs `~/.cdsapirc` and explicit approval before
      spending CDS quota — see `AGENTS.md`).
- [ ] Validate coordinates/timestamps/units against real downloaded data —
      **NOT STARTED** (`forcing/validate_wfde5.py` does not exist yet; this
      is where longitude convention, latitude ordering, and timestamp
      semantics actually get checked, not in `download_wfde5.py`).
- [ ] Create ecLand-ready files — **NOT STARTED** (`forcing/preprocess_wfde5.py`,
      near-unchanged port of `prepare_liaise_forcing_ecland.py`, not yet
      written).
- [ ] Verify global coverage — **NOT STARTED**.

## Milestone 2 — ecLand climatology + initialization

- [ ] Construct `surfclim` on the exact model grid — **NOT STARTED**.
- [ ] Construct `soilinit` on the exact model grid — **NOT STARTED**.
- [ ] Validate shape/coordinates/mask — **NOT STARTED**
      (`init_clim/validate_init_grid.py` does not exist yet; see
      `docs/grid_strategy.md` for exactly what it must check).
- [ ] No accidental flattening/reordering — **NOT VERIFIABLE** until the
      above exists.

## Milestone 3 — pilot ecLand run

- [ ] One day, global — **NOT STARTED**.
- [ ] One month, global — **NOT STARTED**.
- [ ] One complete year, global — **NOT STARTED**.
- [ ] Verify energy budget — **NOT STARTED** (equation carried from
      `liaise-ecland`'s verified convention, see `docs/forcing_variables.md`;
      the *global, area-weighted* aggregation code does not exist yet).
- [ ] Verify water budget — **NOT STARTED**, same caveat.
- [ ] Quantify global runoff totals — **NOT STARTED**.

## Milestone 4 — runoff-to-CaMa interface

- [x] Define Qs + Qsb convention — **DONE as a design decision**,
      `total_runoff = -(Qs + Qsb)`, verified in the reference project against
      real Fortran discharge (0.2-3% agreement) — see
      `docs/forcing_variables.md`. **NOT YET IMPLEMENTED OR RE-VERIFIED** in
      this repo's own code.
- [ ] Temporal aggregation — **NOT STARTED** (`aggregate_runoff_to_daily.py`
      not yet ported).
- [ ] Area conversion — **NOT STARTED**.
- [ ] Derive conservative mapping weights — **NOT STARTED**
      (`derive_cmf_weights.sh`'s remap core not yet ported/generalised).
- [ ] Prove global water conservation before routing — **NOT STARTED**
      (`cama_flood/validate_remapping.py` does not exist yet).

## Milestone 5 — CaMa-Flood

- [ ] Pilot basin first if useful — **NOT STARTED**.
- [ ] Global routing — **NOT STARTED**.
- [ ] Output Q, river storage, flood storage, flood fraction — **NOT STARTED**.

## Milestone 6 — validation

- [ ] GRDC / existing river benchmark framework — **NOT STARTED** (the
      *formulas* — KGE/NSE/PBIAS — are verified in `liaise-ecland` against the
      official CaMa-Flood package's own reference script and are safe to
      reuse verbatim once there is discharge to score).
- [ ] Selected large basins — **NOT STARTED**.
- [ ] Global water balance — **NOT STARTED**.
- [ ] Seasonal hydrographs — **NOT STARTED**.
- [ ] KGE / NSE / correlation / bias / RMSE — **NOT STARTED**. Note from the
      reference project, worth carrying forward: a mean-flow prediction scores
      NSE = 0 but KGE = 1 − √2 ≈ −0.41 (Knoben, Freer & Woods 2019) — do not
      use KGE > 0 as if it were the same "beats climatology" bar as NSE > 0.

## Milestone 7 — forcing sensitivity

- [ ] WFDE5_CRU_GPCC baseline — **NOT STARTED** (depends on Milestones 1-6).
- [ ] ERA5 comparison — **NOT STARTED**.
- [ ] MSWEP precipitation sensitivity — **NOT STARTED**.

## Milestone 8 — agent/cascade interface

Not a scientific milestone: makes this repo's checks callable by a future
cross-repo orchestrator (e.g. a not-yet-built `ecland-cascade`) or a
low-footprint local coding agent (e.g. `qwen2.5-coder:7b` via Ollama), without
requiring it to read the full scientific codebase or parse prose logs.

- [x] `AGENTS.md` — short operating contract (safe/approval-needed/forbidden
      commands, fast entrypoint, escalation rule).
- [x] `docs/agent_quickstart.md` — under ~1500 words, what/status/first
      command/where results land.
- [x] `docs/benchmark_contract.md` — Gate 0-5 definitions, JSON result
      schema, failure-code vocabulary.
- [x] Benchmark profiles (`benchmark.yaml`: fast/smoke/intermediate/
      reference/production).
- [x] JSON result schema (`benchmark_result.json`, one per experiment run).
- [x] `scripts/benchmark.py` — deterministic CLI, `--profile {...}`, writes
      the JSON result, compact per-check progress lines, exit code 0/1/2.
- [x] Synthetic tests for the interface itself (`tests/test_benchmark.py`) —
      no WFDE5 archive or ecLand executable required.

**Honest current scope**: only Gate 0 (repository: Python/Bash syntax) is a
real, executable check right now. `--profile fast` also runs `pytest tests/`
(all synthetic). `--profile smoke/intermediate/reference/production` exit
with status `NOT_IMPLEMENTED` (exit code 2) — Gates 1-5 depend on Milestones
1-5 above, which are themselves NOT STARTED. Do not read "the CLI exists" as
"the pipeline works" — see `CLAUDE.md`'s single most important rule.

## Open blockers

- No global WFDE5 data has been downloaded yet — Milestone 1's CDS request
  structure is designed (`config/wfde5.yaml`) but untested against a real
  global (not LIAISE-cropped) pull.
- The ecLand executable, its exact global-run namelist requirements, and the
  target CaMa-Flood map-package resolution have not been chosen.
- `liaise-ecland`'s own reservoir/dam-module investigation (CaMa-Flood v4.20
  `LDAMOUT`) found a real, only partially understood numerical instability at
  fine time/space scales for run-of-river-type reservoirs — irrelevant to a
  first global naturalised (no-dam) pilot, but worth knowing before this repo
  ever turns dams on.

## Immediate next step

`forcing/download_wfde5.py` is now ported/generalised (see Milestone 1) but,
like `init_clim/init_clim.py` and `cama_flood/build_global_cmf_fixdir.sh`
(Milestone 0), **not executed against anything real**. Next: get explicit
approval to spend CDS quota, then actually run
`python3 forcing/download_wfde5.py --start-year 1988 --end-year 1988
--months 01` — one real month, not a full year — to get the first real
downloaded WFDE5 file this repository has ever had. That file is the
prerequisite for writing `forcing/validate_wfde5.py` (which answers the open
grid/timestamp questions in `docs/forcing_variables.md` against real data)
and for exercising `init_clim.py`/the fixdir builder meaningfully, since none
of the ported code has been run against real data in this repository yet.

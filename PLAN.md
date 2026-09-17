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
- [x] Obtain one month of global WFDE5 as a first real test — **DONE**
      2026-09-17: `forcing/WFDE5_CRU_GPCC/WFDE5_CRU_GPCC_1988_01-01.nc`
      (1.2 GB, 744 hourly steps, 360x720 global 0.5 deg), downloaded with
      `python3 forcing/download_wfde5.py --start-year 1988 --end-year 1988
      --months 01`. Values are physically sane (Tair 210-322 K, Rainf/Snowf
      non-negative). One full year, then 1988-2024, is still **NOT
      STARTED** — do this incrementally, not in one multi-year batch (see
      the script's own memory-estimate warning).
- [ ] Validate coordinates/timestamps/units against real downloaded data —
      **PARTIALLY ANSWERED, ad hoc, not yet a real check**: longitude
      convention (`-180..180`) and latitude ordering (ascending) are now
      confirmed against the real file above and recorded in
      `docs/forcing_variables.md`. `forcing/validate_wfde5.py` itself still
      **does not exist** — units/timestamp-semantics/fill-value checks are
      not yet automated, and nothing here should be trusted as a real gate
      until that script exists and is run.
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

**Investigation findings, 2026-09-17 (paused here, no MARS spend yet —
read this before re-investigating from scratch)**:

- `init_clim/init_clim.py`'s own import, `from osm_pyutils import
  grid_gaussian as gg`, **does not resolve against the current
  `/perm/pad/ecland` checkout** — `grid_gaussian.py` does not exist
  anywhere in that tree's `tools/create_forcing/scripts/osm_pyutils/`
  (checked directly: `ls` + `find`, not just an import error). This was
  valid against whatever ecland snapshot `liaise-ecland` was built against
  at the time; the currently-maintained ecland tree has moved past it.
  `docs/migration_from_liaise.md`'s Category A classification of
  `init_clim.py` ("port unchanged, adjust only import paths") is **no
  longer accurate as stated** — the import itself needs more than a path
  fix, or a different tool entirely.
- A plausible successor exists — `iniclim_forcing_LL.py`/`interp_ll.py` in
  the same `osm_pyutils` package — but **not verified as a drop-in
  replacement** for whatever `get_grib_grid()` provided.
- Separately, and better news: this machine already has a **full working
  ecLand build**, `/perm/pad/ecland/build/bin/ecland-master-dp` (+
  `ecland-master-cmflood-dp` for coupled runs) — a real unblock for
  Milestone 3 once surfclim/soilinit/namelist exist.
- ecland's own tree also has an **actively-maintained**, config-driven
  alternative: `tools/create_forcing/ecland_create_forcing.py`
  (MARS-or-CDS, ERA5-based climatology/init, `1D` site or `2D`
  bounding-box region). It has no explicit "global" mode, but its internal
  grid-sizing formula (`nlat=int((180-dx)/dx+1)`, `nlon=int((360-dx)/dx+1)`)
  is resolution-only, so a full-globe bounding box is plausible —
  **untested at that extent**.
- Confirmed `climate.v021` (the static climatology archive both tools
  ultimately read from, e.g. `/home/rdx/data/climate/climate.v021/399_4/`)
  is genuinely **global already** (`grib_ls`: -89.83..89.83 coverage) — the
  LIAISE crop in both `liaise-ecland`'s `init_clim.sh` and ecland's own 2D
  tool happens only at the interpolation step, not the source data. Even
  the LIAISE-flagged irrigation input turns out to be a global product at
  the same native resolution.
- Confirmed the exact MARS grid/area parameterization needed to land on
  WFDE5's grid convention if generalising `init_clim.sh` directly:
  `area=89.75/-179.75/-89.75/179.75` (cell-center corners, matching WFDE5's
  `±89.75`/`±179.75`), **not** `90/-180/-90/180` (grid-line corners) — the
  wrong choice here silently produces a half-cell-offset grid, exactly the
  kind of mismatch `docs/grid_strategy.md` warns about.
- **Decision paused, not made**: patch `init_clim.py`'s broken import
  (faithful to the original migration plan, but reverse-engineering a
  compatibility shim) vs. switch to `ecland_create_forcing.py`'s 2D
  pipeline with a global box (built on currently-maintained code, but
  untested at that scale) — pick this up in a future session before
  writing any new driver code.
- Independent of that choice: `namelist/templates/` is still empty and
  `run/run_ecland.sh` does not exist — "run ecLand" needs both regardless
  of how surfclim/soilinit get built.

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

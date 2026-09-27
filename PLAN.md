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
- [x] Create ecLand-ready files — **DONE** 2026-09-20: `forcing/preprocess_wfde5.py`
      converts WFDE5 to ecLand `met_2DHT` format and has produced the real
      files driving every run below. Rewritten to stream in 168-hour blocks
      after the whole-period load was measured at ~82 GB peak for one year
      (unrunnable); peak RSS is now 546 MB and the output was verified
      **bit-identical** to the pre-rewrite file on the one-day case.
- [x] Verify global coverage — **DONE** 2026-09-22 for the assembled year
      files, by inspection not by script: 8784 records for 1988 (leap) /
      8760 otherwise, grid 360x720, lat -89.75..89.75 **ascending**, lon
      -179.75..179.75, strictly hourly with no gaps, units K / kg kg-1 / Pa /
      W m-2 / kg m-2 s-1 / m s-1, and an identical 64.2% ocean mask across
      all eight variables. `forcing/validate_wfde5.py` **still does not
      exist**, so this is a manual check that is not reproducible or
      version-controlled — writing that script remains open.

## Milestone 2 — ecLand climatology + initialization

- [x] Construct `surfclim` on the exact model grid — **DONE** 2026-09-19:
      `init_clim/build_global_surfclim_soilinit.sh` runs ecland's own
      `tools/create_forcing/ecland_create_forcing.py` (2D pipeline, global
      bounding box) and produces `surfclim_GLOBAL_1988-2024.nc` (8.8 MB,
      360x720). Real MARS retrieval: 26 ERA5 fields, 27.2 MB, 4 seconds
      (`class=ea, type=an, date=19880101`); the static climatology
      (`climate.v015/639l_2`) is a direct file copy, no retrieval.
- [x] Construct `soilinit` on the exact model grid — **DONE** 2026-09-19,
      same run: `surfinit_GLOBAL_1988-2024.nc` (4.9 MB, 360x720).
- [x] Validate shape/coordinates/mask — **DONE, real check, real bug
      found and fixed**: `init_clim/validate_init_grid.py` compares
      forcing/surfclim/soilinit pairwise. First real run caught a genuine
      grid mismatch — the tool writes latitude in native MARS/GRIB order
      (descending, north-to-south); WFDE5 is ascending. Fixed by
      `init_clim/flip_latitude_to_ascending.py` (now wired into the build
      script automatically, not a manual step). After the fix:
      `validate_init_grid.py` reports **PASS** — 360x720 lat/lon identical
      across all three files (lat -89.75..89.75, lon -179.75..179.75).
      Land-mask agreement (WFDE5 coverage vs. surfclim's ERA5-derived
      `landsea`) is 98.0% — reported as informational, not a hard
      pass/fail, since the two masks are independently derived (see the
      script's own docstring).
- [x] No accidental flattening/reordering — **VERIFIED**: output is a
      proper `(lat, lon)` gridded NetCDF (not the flattened `x`-point
      representation `init_clim.py`'s `gen_file` would have produced),
      confirmed by `validate_init_grid.py` reading `lat`/`lon` directly.
      Covered by 5 synthetic-fixture tests, `tests/test_init_clim_grid.py`.

**Path taken**: ecland's own `ecland_create_forcing.py` (Option B from the
2026-09-17 investigation below), not a patched `init_clim.py`. Config
template: `init_clim/config_global.yaml.tmpl` (rendered by the build script
via `envsubst`) — global box `clatn=89.75/clats=-89.75/clonw=-179.75/
clone=179.75, dx=0.5` (cell-center corners, exactly matching WFDE5's real
grid, not the naive `90/-180/-90/180` grid-line corners).

**Investigation findings, 2026-09-17 (superseded by the above — kept for
the reasoning trail)**:

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

- [x] One day, global — **DONE** 2026-09-19: `run/run_ecland.sh` ran
      `ecland-master-dp` (real executable at `/perm/pad/ecland/build/bin/`)
      for 1988-01-01 00:00 -> 1988-01-02 00:00 (48 half-hour steps), global
      0.5°, using the real downloaded WFDE5 forcing and the real
      `ecland_create_forcing.py`-built surfclim/soilinit. Completed in 106s.
      `run/check_run.py` reports **PASS**: `run.log` clean (no Fortran abort
      marker), `restartout.nc` present, zero NaN/Inf in any `o_*.nc`
      variable (excluding ecLand's own `1e20` fill value over masked/ocean
      cells). 87,798 land points; `AvgSurfT` 197.5-325.4 K, `SoilTemp`
      215.9-316.1 K on land -- physically plausible for a global January
      day, not independently validated against observations.
- [x] One month, global — **DONE** 2026-09-20: full month of January 1988,
      coupled ecLand<->CaMa-Flood over real MPI, hourly coupling
      (`TCOUPFREQ=1`). `run/check_run.py` **PASS** over ~60 GB of output.
- [x] One complete year, global — **DONE** 2026-09-23 (`Y1988_19880101-19890101`,
      job 30129241). Full leap year, 8784 hourly forcing records, 17,566
      steps, coupled, 16 ranks x 8 threads. Model integration 2505 s
      (**0.70 h/simulated year**; 0.93 h including preprocessing and ECFS
      archiving), 12 `NFORCWINDOW` refills, 7.4 GB on disk, archived to
      `ec:/pad/wfde5-ecland` and verified with `els`.
      `run/check_run.py` **PASS** — `run.log` clean, `restartout.nc`
      present, no NaN/Inf in any `o_*.nc`.
      A first attempt (job 30010675) completed all 17,566 steps then died
      with **SIGBUS on the final write** of a 424 GB hourly `o_gg.nc`. That
      is a large-file write fault, **not** disk or quota (files are sparse;
      171 GB actual against 4.2 T free). Hence the chunking rule now
      enforced in `run/run_ecland.sh`: annual chunks -> daily output,
      hourly output -> monthly chunks. The limit is bracketed between 36 GB
      (works) and 424 GB (fails) but **not characterised**.
- [x] Verify energy budget — **DONE** 2026-09-24, `validation/check_budgets.py`,
      area-weighted global land totals. On the validated 1988 year:
      residual **+2347 EJ = 0.680% of net radiation**, **PASS**.
      Terms: SWnet 660354, LWnet -315357, Qle -201593, Qh -140360 EJ.
      Fluxes are downward-positive (`SurfSgn_convention = "Mathematical"`),
      so the turbulent terms are ADDED, not subtracted — subtracting them
      doubles the imbalance, the energy-side twin of the Qs/Qsb trap.
- [x] Verify water budget — **DONE** 2026-09-24, same script. On 1988:
      residual **-525 Gt = 0.452% of precipitation**, **PASS**.
      Terms: precipitation 116090 Gt, evaporation -80302 Gt, runoff
      (Qs+Qsb) -42410 Gt, DelSoilMoist -3429 Gt — all independently
      credible against global land hydrology, which matters as much as the
      residual closing. `Del*` terms are `kg m-2`/`J m-2` (already
      integrated), NOT rates; the script scales by the units attribute, not
      the variable name.
      `run/check_run.py` remains a NaN/crash check only; these are separate.
- [x] Multi-year campaign, 1988-2001 — **DONE** 2026-09-27 for 14 of the 37
      years. Annual segments, daily output, chained restarts with continuity
      verified per segment, archived to `ec:/pad/wfde5-ecland` and confirmed
      with `els`. 2002-2024 **NOT STARTED** (see "Immediate next step").
      **A real bug in ecLand's FLake stopped this chain dead at 2001** and is
      worth recording in full, because the crash surfaced three layers away
      from its cause. Symptom: `forrtl: error (75): floating point exception`
      in `cotworestress_mod.F90:430`, reproducibly at step 8913, on different
      nodes (which should have ruled out infrastructure immediately — it did
      not, and a `--requeue` was added as a remedy for what was never a
      transient). Cause, from a core dump rather than from reasoning:
      `flakeene_mod.F90:467-470` nudges mean lake temperature toward soil
      temperature at level 1 with no validity condition, full strength at the
      0.5 m minimum depth, and a clamp that bounds only from below. At
      lake-dominated points the soil column is degenerate (`sotype=0`,
      `SoilMoist=0`) and runs hotter than any lake, so the lake follows it
      without bound: `T_MNW` reached **1.9e7 K**, dragging tile-1 skin
      temperature to **11,451 K**, and `EXP(RSHP2AMMAX*(ZTSK-T2))` overflowed
      in the carbon code. All forcing inputs at that point were normal.
      Fixed by `TMNW_NDG_TIMESCL = 1.0E30` in both namelist templates (job
      31717620: full year, 59:35, endpoint `2002-01-01T00`). Lake state after:
      `TLWML` max **307.20 K**, mean 279.348 K — against 313.53 K / 279.352 K
      for Y2000 with the nudge active. Unchanged mean, truncated warm tail.
      In Y2000 the mixed layer, mean water and bottom temperatures all peaked
      at the *same* 313.5258 K, which is a column slaved to the soil rather
      than a lake in equilibrium — **so the nudge biased the warm tail in
      every year of the archive**, and 2001 is only where it went
      superexponential. Corroborates finding 4 of the user's `ifs-lakebench`
      (368 K at Lake Chilwa), which anticipated this exact switch.
      Nine wrong hypotheses preceded the core dump; the lesson is that when a
      trap moves as you perturb rounding, stop guarding arithmetic and go read
      the state.
      2001 is fully validated: `run/check_run.py` **PASS** (no NaN/Inf in
      30 GB), water residual **-577 Gt = 0.504% of precipitation**, energy
      residual **+3242 EJ = 0.940% of net radiation**, both **PASS**; restart
      continuity from Y2000 `3.19e-06` against a cold-start distance of
      `169.2`; output ends at `2002-01-01T00` as required. Energy closure is
      looser than 1988's 0.680% but inside tolerance; not investigated.
      **Caveat on attributing the lake numbers**: the 307.2 K / 313.5 K
      comparison above is Y2001 against Y2000, which confounds the switch with
      interannual variability. The clean test is
      `run/configs/ab_flake_{on,off}.env` -- the same 90 days from the same
      restart, configs differing only in `NAMELIST_TEMPLATE` -- which is what
      any claim about the nudge's magnitude should rest on.
      **A/B result** (jobs 31737035/31737036, 2001-01-01 -> 2001-04-01,
      each verified to have used its intended `TMNW_NDG_TIMESCL`):

        lake temperature  TLWML max   304.52 K (off)  318.97 K (on)   +14.4 K
                          worst point                                 +24.7 K
                          lake pts shifted >1 K                         2.05%
                          lake pts shifted >5 K                         0.25%
                          global lake mean                            +0.035 K
        water cycle       Evap                                        -0.345%
                          Qs                                          -0.005%
                          Qsb                                         +0.004%
                          Rainf, Snowf                                 0.000%

      So the nudge is a severe *lake temperature* error -- +24.7 K in 90 days,
      diverging without bound over a year -- but its effect on the water cycle
      is 0.005% in runoff, **two orders of magnitude below the 0.45-0.50%
      budget-closure residual**, and it touches 0.044% of points at even
      0.001 kg m-2 in 90-day evaporation. Identical `Rainf`/`Snowf` confirms
      the two runs were otherwise the same run.
      **Therefore 1988-2000 do NOT need rerunning for the water cycle, runoff,
      discharge or the dam experiment**, which is what this archive exists for.
      They WOULD need rerunning for any lake-temperature or surface-energy
      analysis, where the 2000/2001 join is a real inhomogeneity. An earlier
      recommendation in this file to rerun all 37 years was based on the
      confounded year-to-year comparison and is withdrawn.
      Caveat on scope: the A/B window is January-March, while the runaway
      occurred in July, so the warm-season lake-temperature effect is likely
      LARGER than +14.4 K. The water-cycle sensitivity would have to change by
      ~100x to alter the conclusion above.
- [ ] Quantify global runoff totals — **NOT STARTED**.

**A real bug was found and fixed getting here (2026-09-19)**: WFDE5 is a
**land-only** product (masks ocean intentionally, unlike ERA5, which has no
gaps) — `forcing/preprocess_wfde5.py`'s first version filled masked
(ocean) cells with `0.0`, and ecLand's Fortran `surfexcdriver_ctl` is not
tolerant of `Tair=0 K`/`PSurf=0 Pa` at masked points: it crashed with a
floating-point invalid-operation signal on the very first timestep. Fixed
by filling masked cells with numerically-safe reference-atmosphere
constants instead (`MASKED_FILL_VALUES` in that script) — ocean-cell
*outputs* are meaningless regardless (surfclim's own land-sea mask is what
determines scientific validity), confirmed by ecLand's own output correctly
using its `1e20` fill marker over those cells rather than propagating the
placeholder values. Covered by `tests/test_preprocess_wfde5.py`.

**Path taken for the run driver**: not a hand-rolled namelist/run script.
`namelist/templates/namelist_ecland_50R1_ctl` is ecland's own official,
currently-shipped `{}`-placeholder template (ported unchanged from
`/perm/pad/ecland/namelists/`, the same one its own
`tests/2D_EU-001_20220101-20220102` test case uses), and `run/run_ecland.sh`
calls ecland's own official `share/ecland/scripts/ecland_create_namelist.py`
+ `ecland_run_model.sh` rather than reimplementing namelist patching. Direct
execution, no `sbatch`/`srun` (matches `benchmark.yaml`'s `smoke` profile,
`require_confirmation: false`).

**Environment gotcha worth remembering**: `ecland-master-dp` is MPI-linked
(`hpcx-openmpi/2.9.0`) and needs `module load prgenv/intel intel/2021.4
hpcx-openmpi/2.9.0` before it will run (`libmpi_usempif08.so.40` missing
otherwise). Loading `nco` in the same `module load` invocation as the MPI
stack silently breaks `LD_LIBRARY_PATH` again (observed directly, order
didn't matter) — load them separately. Also: piping a `module load`
command's output through anything (e.g. `| tail`) forks a subshell and the
environment changes never reach the calling shell — redirect
(`>file 2>&1`), never pipe, when you need the loaded modules to stick.

## Milestone 4 — runoff-to-CaMa interface

**Important scope correction (2026-09-20)**: this milestone was written
assuming an *offline/decoupled* hand-off (ecLand writes runoff → a separate
tool remaps it → CaMa-Flood reads it), matching `liaise-ecland`'s
CaMa-Flood-GPU bridge work. The path this repo actually took is the
**online, in-memory 1-way coupling** built into ecLand itself:
`cnt41s.F90` calls `CMF_FORCING_PUT` + `CMF_DRV_ADVANCE` directly every
`TCOUPFREQ`, with no runoff file ever written or read, and the
Qs/Qsb sign handling done inside ecLand's own Fortran. The items below are
therefore only needed if this repo later wants a decoupled chain as well.

- [x] Define Qs + Qsb convention — **DONE as a design decision**,
      `total_runoff = -(Qs + Qsb)`, verified in the reference project against
      real Fortran discharge (0.2-3% agreement) — see
      `docs/forcing_variables.md`. Not re-verified in this repo's own code,
      and **not needed for the online coupled path actually used**.
- [x] Derive conservative mapping weights — **DONE** 2026-09-20,
      `cama_flood/derive_global_cmf_weights.sh` (new; generalises
      `derive_cmf_weights.sh` by dropping its clip and mpireg-flattening
      steps entirely). Real run at `glb_15min`: `inpmat.nc` mapping this
      repo's own 360x720 ecLand grid onto the global river network,
      **0.00% area-conservation error** after correction.
- [ ] Temporal aggregation / area conversion / offline conservation check
      (`aggregate_runoff_to_daily.py`, `validate_remapping.py`) —
      **NOT STARTED, and not on the critical path** for the online coupled
      configuration (see scope correction above).

## Milestone 5 — CaMa-Flood

- [x] Global routing — **DONE** 2026-09-20: a full calendar month
      (1988-01-01 → 1988-01-31, 1486 half-hour steps) of global 0.5°
      ecLand coupled to CaMa-Flood at `glb_15min`, **hourly coupling**
      (`TCOUPFREQ=1`, matching operational configuration), real 2-rank MPI
      with a genuine 2-region `mpireg.nc` (126,192/126,191 cell split, not
      flattened). Ran via `run/run_ecland_cmf.slurm` (SLURM batch,
      `--mem=32G`, submitted only after explicit approval per `AGENTS.md`).
      743 `CMF_FORCING_PUT`/`CMF_DRV_ADVANCE` cycles — exactly hourly over
      744 h.
- [x] Output Q, river storage, flood storage, flood depth — **DONE**, same
      run: `o_totout.nc`, `o_rivsto.nc`, `o_fldsto.nc`, `o_rivdph.nc`
      (124 MB each) plus ecLand's own `o_gg.nc`/`o_wat.nc`/`o_efl.nc`.
- [ ] Pilot basin first if useful — skipped; went straight to global, which
      worked.

**Performance, measured (not estimated)**: 2901 s wall for 31 simulated
days on 2 ranks = **938.8 forecast days per day** (the model's own metric),
1.92 s per 30-min step, ~93.6 s per simulated day. CaMa coupling accounted
for ~890 s (~31%) of the 2849 s time-step loop, at ~1.1-1.7 s per hourly
coupling call. **Parallel efficiency is poor and needs attention before
scaling**: the uncoupled 1-rank one-day run (Milestone 3) reported 875.5
forecast days per day, so doubling ranks *and* adding CaMa netted only ~7%
more throughput. Extrapolated, 1988-2024 would be ~14.4 wall-clock days
continuous at this configuration.

**Output volume is the bigger practical blocker than runtime**: one
simulated month produced ~60 GB (`o_gg.nc` alone 38.5 GB), i.e. ~27 TB for
37 years. `NFRPOS`/`LWRGG` and the output-variable selection need
revisiting before any multi-year run, ahead of the forcing-memory question
in "Open blockers".

**Four real bugs were found and fixed getting here** — see
`cama_flood/README.md` for the full account: a `gen_inpmat.py` netCDF
chunking/HDF5 crash needing `liaise-ecland`'s `cdo` re-write step;
`ecland-master-cmflood-dp` being a *standalone* CaMa-only driver rather
than the coupled executable (the coupled one is plain `ecland-master-dp`);
`TCOUPFREQ` being read in **hours**, not seconds; and CaMa's `COUTDIR`
defaulting relative to an ephemeral run directory. A fifth, cosmetic, was
found by this run's own tail: `ecland_run_model.sh` hardcodes
`mv restart<YYYYMMDDHH>.nc`, so `LRESTCDF=.FALSE.` (binary restarts, the
T21 reference's default) made that last step fail after an otherwise fully
successful run — `namelist/templates/namelist_cmf_global.tmpl` now sets
`LRESTCDF=.TRUE.` (netCDF restarts), which both matches operations and
fixes the mismatch.

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
with status `NOT_IMPLEMENTED` (exit code 2). That is now a gap in the
*interface*, not in the science: Milestones 1-5 have since produced real,
validated results (14 archived annual segments, budget closure measured), so
Gates 1-5 are implementable and simply have not been wired to the checks that
already exist (`run/check_run.py`, `validation/check_budgets.py`,
`init_clim/validate_init_grid.py`, `cama_flood/validate_remapping.py`).
Do not read "the CLI exists" as "the pipeline works" — see `CLAUDE.md`'s
single most important rule.

## Open blockers

- `liaise-ecland`'s own reservoir/dam-module investigation (CaMa-Flood v4.20
  `LDAMOUT`) found a real, only partially understood numerical instability at
  fine time/space scales for run-of-river-type reservoirs — irrelevant to a
  first global naturalised (no-dam) pilot, but worth knowing before this repo
  ever turns dams on.
- ~~**ecLand's offline driver loads the ENTIRE declared forcing period into
  memory upfront, not streamed**~~ — **RESOLVED 2026-09-22** by implementing
  windowed forcing reads upstream in `/perm/pad/ecland` (user's `develop`
  branch, commits `fa34baa`..`b217d5a`). The diagnosis stands as recorded:
  `SUFCDF`, called once at init, read each variable wholesale into
  `GFOR(NPOI, JPSTPFC, 12)` sized for the FULL declared forcing length, and
  `dtforc.F90` only ever interpolated within that resident array. At 87,798
  land points a leap year of hourly forcing would have needed ~74 GB.
  The fix adds one namelist integer `NFORCWINDOW` (`NAMDIM`, **default 0 =
  disabled**, so every existing namelist keeps today's behaviour bit for
  bit): when set, `JPSTPFC = NFORCWINDOW`, `GFOR` is allocated small, and a
  guard at the top of `DTFORC` refills it through a shared read routine
  before any of that routine's dozen index formulas run — none of which were
  touched. Verified by equivalence (windowed vs. full-load output identical)
  and in production: the campaign runs `NFORCWINDOW=744`, and a full year
  does 12 refills at 0.70 h/simulated year.
  Two real bugs in the first cut of that work, both fixed before merge: an
  EOF latch that fired on "window didn't move" rather than on reaching the
  end of the record axis (out-of-bounds at small windows — there is now a
  hard refusal below `NFORCWINDOW=8`), and `RDFVAR`'s `ZTIMEN` being
  computed relative to call time, which is only correct when called once.
  `LOADIAB` and `LPREINT` are refused in combination with windowing rather
  than silently mis-handled.
- **FLake nudges mean lake temperature to soil temperature unconditionally**
  (found 2026-09-27, `flakeene_mod.F90:467-470`). Worked around in this
  repo's namelist templates with `TMNW_NDG_TIMESCL = 1.0E30`; **the code
  itself is unchanged upstream**, so any other user of that source still has
  it. The nudge has no lake/soil-validity condition, its depth weighting
  reaches full strength at the minimum lake depth (0.5 m in this archive, so
  one 1800 s step is one e-folding time), and its security clamp
  `MAX(T_MNW, RTPL_T_F)` bounds the result from below only. At lake-dominated
  points the soil column is degenerate and free to run hotter than any lake,
  so the lake is slaved to it unbounded. This stalled the campaign at 2001
  for four days; see Milestone 3 for the measured numbers. Whether a
  conditional guard belongs on `develop` in addition to the namelist switch
  is **an open decision, not done**.

## Immediate next step

**Campaign status (2026-09-27): 1988-2001 complete, validated and archived
to `ec:/pad/wfde5-ecland`; 2002-2024 not yet run.**

14 annual segments exist as real, verified output — daily-frequency
`o_gg`/`o_wat`/`o_efl` plus CaMa-Flood `rivsto`/`fldsto`/`totout`/`rivdph`,
each chained from the previous year's `restartout.nc` with continuity
verified rather than assumed (`VERIFY_RESTART`, which compares the model's
first output against the previous restart AND against climatology, and
requires the chain distance to be under 1% of the cold-start distance).

2001 is the only segment produced with `TMNW_NDG_TIMESCL = 1.0E30`, so there
is a real physics discontinuity at the 2000/2001 join. The A/B experiment
recorded under Milestone 3 **sized** it, rather than leaving it a worry:
0.005% in runoff (negligible — two orders of magnitude below the budget
residual) against up to +24.7 K in lake temperature at individual points in
only 90 days. So the archive is homogeneous for the water cycle and is NOT
homogeneous for lake temperature or surface energy. **No rerun of 1988-2000
is needed for this repo's purpose**; anyone doing lake or energy work across
the join must know. An earlier draft of this file recommended rerunning all
37 years on the strength of a Y2001-vs-Y2000 comparison that confounded the
switch with interannual variability — that recommendation is withdrawn.

Next, in order:
1. **Resubmit 2002-2024** — `run/submit_campaign.py --start-year 2002
   --end-year 2024 --mode annual --output-freq-hours 24 --restart-from
   run/output/Y2001_20010101-20020101/restartout.nc`. The 23 segments queued
   behind the failed 2001 are dead (`DependencyNeverSatisfied`) and must be
   cancelled first. ~21 wall-clock hours at the measured rate.
2. ~~Decide the 1988-2000 lake question~~ — **DONE**, settled by the A/B
   experiment above: no rerun needed for the water cycle. Document the join
   for lake/energy users instead.
3. **Quantify global runoff totals** and the remaining Milestone 6
   validation — still **NOT STARTED**.
4. **`forcing/validate_wfde5.py` still does not exist.** The grid facts in
   `docs/forcing_variables.md` came from ad hoc inspection, not an automated
   check, and every forcing verification in this campaign has been manual.
   This is the largest unautomated gap in the chain.
5. **Upstream the two ecLand fixes** (the C4 `ICTYPE` bug in
   `farquhar_mod.F90:451` and the FLake nudging) to `ecmwf-ifs/ecland`. Both
   are on the user's `develop` fork only; the C4 bug affects 6.2% of land
   points and ~44% of `Anday` at the worst point, so other users are
   silently affected. Outward-facing — needs explicit approval.

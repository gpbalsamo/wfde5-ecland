# init_clim/

ecLand `surfclim` (time-invariant surface climatology) and `soilinit` (initial
soil/snow state) construction, on the exact global ecLand grid.

Status: **not started, and blocked on an unresolved tooling decision** —
see `PLAN.md` Milestone 2's 2026-09-17 investigation note before picking
this up. Summary: `init_clim.py`'s own `osm_pyutils.grid_gaussian` import
does not resolve against the currently-maintained `/perm/pad/ecland`
checkout (the module is gone from that tree), so this is not the clean
"port unchanged" job `docs/migration_from_liaise.md` originally described.
Two live options, neither implemented yet:

- Patch `init_clim.py`'s import against `iniclim_forcing_LL.py`/
  `interp_ll.py` (plausible successors in the same `osm_pyutils` package,
  **not verified** as drop-ins) and generalise `init_clim.sh`/`clim.sh` for
  a global bounding box — the exact MARS `area`/`grid` parameterisation to
  match WFDE5's grid convention is already worked out (see `PLAN.md`).
- Switch to ecland's own actively-maintained
  `tools/create_forcing/ecland_create_forcing.py` (config-driven, MARS/CDS,
  ERA5-based init/climatology, `1D` site or `2D` bounding-box region) with a
  global box — untested at that extent.

Planned regardless of which path is chosen:

- `init_clim.py` — already ported from `liaise-ecland/init_clim/init_clim.py`,
  import issue above notwithstanding.
- `init_clim.sh`, `clim.sh` — driver scripts, generalised: domain/grid constants
  move to `config/ecland.yaml` rather than staying hardcoded.
- `validate_init_grid.py` — new. Compares the forcing grid, `surfclim` grid, and
  `soilinit` grid pairwise and returns PASS only when their coordinate arrays,
  ordering, and land mask agree exactly. This is a hard project invariant (see
  `CLAUDE.md`, "Grid invariants") — never assumed to hold, always checked.

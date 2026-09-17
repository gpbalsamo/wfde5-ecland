# init_clim/

ecLand `surfclim` (time-invariant surface climatology) and `soilinit` (initial
soil/snow state) construction, on the exact global ecLand grid.

Status: **not started**, but `init_clim.py` is the single strongest reuse
candidate from `liaise-ecland` (see `docs/migration_from_liaise.md`) — it is
already grid-shape-agnostic (handles both a flattened/reduced-Gaussian
representation and a regular lat/lon grid) and carries zero LIAISE-specific
assumptions.

Planned:

- `init_clim.py` — ported from `liaise-ecland/init_clim/init_clim.py`.
- `init_clim.sh`, `clim.sh` — driver scripts, generalised: domain/grid constants
  move to `config/ecland.yaml` rather than staying hardcoded.
- `validate_init_grid.py` — new. Compares the forcing grid, `surfclim` grid, and
  `soilinit` grid pairwise and returns PASS only when their coordinate arrays,
  ordering, and land mask agree exactly. This is a hard project invariant (see
  `CLAUDE.md`, "Grid invariants") — never assumed to hold, always checked.

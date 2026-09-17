# ecLand → CaMa-Flood runoff interface

Status: **design document, not yet implemented**. See `PLAN.md` Milestone 4.

## Pipeline

```
ecLand hourly Qs, Qsb  (kg m-2 s-1, on the 0.5 deg grid)
    |
    v
sign-correct + combine: total_runoff = -(Qs + Qsb)   <- see docs/forcing_variables.md
    |
    v
temporal aggregation (hourly -> whatever CaMa-Flood's coupling frequency needs)
    |
    v
convert rate -> volume per ecLand cell (multiply by interval seconds and cell area)
    |
    v
conservative area-weighted remap onto CaMa-Flood unit catchments
    |
    v
CaMa-Flood runoff forcing
```

## Why the sign correction is step one, not an afterthought

This is the single most consequential correctness issue found anywhere in
the `liaise-ecland` project's CaMa-Flood work. `Qsb` is a *signed*
soil-column-loss term in ecLand's own convention, not a plain positive flux
like `Qs`. The naive `Qs - Qsb` is dimensionally plausible, passes a
"discharge is non-negative" sanity check, and is *still wrong* — verified by
comparing against real Fortran-coupled discharge at multiple real gauges,
where `Qs - Qsb` matched to only ~2-3x the correct magnitude while
`-(Qs+Qsb)` matched to within 0.2-3%. See `docs/forcing_variables.md` for the
full account. `remap_runoff.py` must implement `-(Qs+Qsb)` from the start,
not discover this the way the reference project did.

## Conservation is the acceptance criterion, not a nice-to-have

`aggregate_runoff_to_daily.py` (ported from `liaise-ecland`, see
`docs/migration_from_liaise.md`) was checked there to conserve volume to
1e-9 relative error — that is the bar for any temporal-aggregation step here
too. The area-weighted remap onto CaMa-Flood catchments must clear the same
bar: `validate_remapping.py` computes, for every tested period,

```
total ecLand runoff volume
total mapped CaMa-Flood input runoff volume
absolute difference
relative difference
```

and **fails** (nonzero exit) if the relative difference exceeds a
configurable tolerance. This check must exist and pass before any routing
run is trusted, and its numbers are reported, not just its pass/fail — a
near-precision-level residual and a residual just under the tolerance are
both "PASS" but are not the same finding.

## Weight generation, reused from liaise-ecland with the domain-clip removed

`derive_cmf_weights.sh`'s conservative remap-weight generation
(`gen_inpmat.py`, from the `ecland` repo's own `tools/create_forcing/`) runs
against whatever ecLand grid it's given; the LIAISE-specific step is the
domain clip that comes *before* it (`sel_region.py`, the `CLATN`/`CLATS`/
`CLONW`/`CLONE` box). For a global run there is no clip: the full global
CaMa-Flood network is the target. See `docs/migration_from_liaise.md` for the
two `ecland`-side source patches this machinery needed in the reference
project (a real memory-safety bug in `cnt41s.F90`, and an
out-of-bounds-pixel handling fix in `cython_ext.pyx`) — check whether a
global (non-clipped) run still exercises the same code paths that needed
those patches before assuming they're unnecessary here.

## Routing resolution is a CaMa-Flood-side choice, not a runoff-side one

See `docs/grid_strategy.md`. `build_global_cmf_fixdir.sh` already supports
building the global fix bundle at multiple resolutions
(`glb_15min`/`glb_06min`/`glb_03min`/`glb_01min`); which one to route at is
an independent decision from the ecLand runoff-generation grid, made after
Milestone 4's conservation check passes, informed by the kind of
resolution-comparison result documented in `liaise-ecland/PLAN.md`.

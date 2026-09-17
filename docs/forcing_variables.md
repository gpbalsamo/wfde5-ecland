# WFDE5 → ecLand forcing variable mapping

Status: the CDS-side variable/unit table below is **verified**, carried over
from `liaise-ecland/forcing/get_liaise_forcing_05_cds.py` where it was
confirmed against real downloaded CDS files (both `cru` and `cru_and_gpcc`
request blocks). The ecLand-side conventions (accumulated-vs-instantaneous,
sign convention, timestamp interpretation) below are **NOT independently
re-verified for this repo** — they are stated here because they are known,
documented facts about the same WFDE5/ecLand pairing from the reference
project, and must be re-checked once this repo has its own downloaded data
and its own `validate_wfde5.py`, not assumed to transfer automatically.

## CDS dataset structure

Dataset: `derived-near-surface-meteorological-variables` (WFDE5).

CDS variable name | short name | units | ecLand name (assumed match) | reference_dataset
---|---|---|---|---
`near_surface_air_temperature` | Tair | K | Tair | `cru`
`near_surface_specific_humidity` | Qair | kg kg⁻¹ | Qair | `cru`
`near_surface_wind_speed` | Wind | m s⁻¹ | Wind | `cru`
`surface_air_pressure` | PSurf | Pa | PSurf | `cru`
`surface_downwelling_longwave_radiation` | LWdown | W m⁻² | LWdown | `cru`
`surface_downwelling_shortwave_radiation` | SWdown | W m⁻² | SWdown | `cru`
`rainfall_flux` | Rainf | kg m⁻² s⁻¹ | Rainf | `cru_and_gpcc`
`snowfall_flux` | Snowf | kg m⁻² s⁻¹ | Snowf | `cru_and_gpcc`

**Critical, easy to get wrong**: precipitation variables (`rainfall_flux`,
`snowfall_flux`) are the *only* ones valid under `reference_dataset` =
`cru_and_gpcc` (the CRU+GPCC gauge-corrected product). Every other variable,
including the static `grid_point_altitude`, requires `reference_dataset` =
`cru`. Requesting everything under one `reference_dataset` value silently
returns the wrong precipitation product rather than erroring — confirmed in
`liaise-ecland`, not a hypothetical risk.

Reference height for near-surface scalar variables (Tair, Qair): 2 m. This is
a fixed WFDE5 convention, not distributed as a CDS variable itself.

## Open questions this repo must verify itself

The handoff spec lists these explicitly and they have **not yet been
answered against this repo's own downloaded data** — do not assume the
liaise-ecland answers transfer without checking:

- Precipitation: WFDE5's `Rainf`/`Snowf` are fluxes (kg m⁻² s⁻¹), i.e. rates,
  not accumulated depths — consistent with the units column above, but
  `validate_wfde5.py` must confirm this against the actual downloaded file's
  own `units` attribute, not this table.
- Radiation: `SWdown`/`LWdown` units above (W m⁻²) indicate instantaneous
  flux, not accumulated energy — again, verify against the file, not this
  document.
- Calendar/time convention: `liaise-ecland` rebases to
  `hours since <start-year>-01-01 00:00:00`, `proleptic_gregorian` calendar
  (see `config/wfde5.yaml`). Whether WFDE5's *native* CDS delivery uses the
  same calendar, and whether timestamps mark interval start, centre, or end,
  must be checked directly — `liaise-ecland`'s own rebasing script
  (`prepare_liaise_forcing_ecland.py`) does not by itself answer this.
- Longitude convention (−180..180 vs 0..360) and latitude ordering (ascending
  vs descending) in the *raw* CDS delivery: not documented in the reference
  repo's own scripts in a way that's safe to copy blindly — `inspect_grid.py`
  must check this on real data before any remapping step trusts it.
- Missing-value/fill-value convention: not verified here.

## ecLand runoff output convention (verified, from real Fortran source)

Not a forcing input, but directly relevant to the runoff-to-CaMa-Flood
interface (Phase 9) and stated here because it was hard-won and easy to get
backwards:

ecLand's raw output (`o_wat.nc`) writes `Qs` (surface runoff) as a positive
outward flux, but `Qsb` (subsurface runoff) as a **signed soil-column-loss
term** in ecLand's own water-budget convention — confirmed by reading
`wrtdcdf.F90` and `cnt41s.F90` in the `ecland` source directly, and by
matching the resulting discharge to real Fortran CaMa-Flood output to within
0.2-3% at multiple gauges. The correct total runoff to hand to a router is:

```
total_runoff = -(Qs + Qsb)
```

**Not** `Qs - Qsb`, which differs from the correct total by exactly `+2*Qs`
at every grid cell and timestep — a spurious double-count of surface runoff
that was the single largest source of discharge bias found in the sibling
CaMa-Flood-GPU coupling work (see `docs/migration_from_liaise.md`).

Separately: `Rainf`/`Snowf`/`Qs`/`Qsb`/`Evap` in ecLand's own `o_wat.nc`
output are **rates** (kg m⁻² s⁻¹), not pre-accumulated depths, despite the
namelist carrying `LACCUMW`/`LRESET` flags that might suggest otherwise —
multiply by the output interval (seconds) before summing to a depth. Caught
the hard way in `liaise-ecland` when a first attempt at annual totals gave
~0 mm for every year.

## Water-balance equation (verified, from real ecLand output)

For a global, area-weighted water-balance check (Phase 8):

```
Rainf + Snowf + Evap + Qs + Qsb
  - DelIntercept - DelSoilMoist - DelSWE - DelAquifer
  ≈ 0
```

`Qs` and `Qsb` are **added**, not subtracted — subtracting them manufactures
a spurious residual of exactly twice their value. `DelAquifer` (and the
paired `Qrec`/`Qcap` recharge/capillary-rise diagnostics) should be read if
present and treated as zero otherwise, for compatibility with ecLand builds
that predate those diagnostics or run with `LEGWRECHARGE` off.

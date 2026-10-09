# validation/

Verification, not aspiration: every check here either passes against real
output or is marked NOT VERIFIED. Nothing in this directory should claim a
workflow step works because the code exists — see `CLAUDE.md`.

- `forcing/` — WFDE5 structural QC results.
- `runoff/` — conservation checks for the ecLand → CaMa-Flood transfer.
- `discharge/` — gauge-based skill scoring (KGE/NSE/correlation/PBIAS), reusing
  the formulas verified in `liaise-ecland/cama_flood/skill_benchmark_*.py`
  (checked there against the official CaMa-Flood package's own reference
  script) without reusing that repo's LIAISE-specific gauge set.
- `water_balance/` — global, area-weighted water-balance closure.

## Scripts

- `check_budgets.py` — global, area-weighted water and energy closure for one
  ecLand run. **VERIFIED** against all 37 years of campaigns v2 and v4.
- `check_dam_commissioning.py` — proves CaMa's `LDAMYBY` stages dams in at
  their `DamYear`. **VERIFIED** 2026-10-08 against the v4/dams archive pair
  (PASS, exit 0). Its docstring records three obvious tests that do *not* work;
  read it before writing a fourth.
- `river_gauges.csv` — the gauge table. Its `obs_m3s` are approximate
  literature values for catching order-of-magnitude errors, **not** a GRDC
  extraction and not to be quoted as observations.
- `extract_gauges.py` — daily series at each gauge from one `o_totout.nc`, so a
  multi-year comparison does not need 100+ GB resident. **Always pass
  `--snap-from`** when comparing experiments: if each run snaps independently
  they can select different cells, and that shows up as a peak-attenuation
  signal that is really a cell mismatch.
- `compare_discharge.py` — dams-vs-control at the gauges. Its load-bearing
  check is the **annual mean**, not the peak: a reservoir redistributes water
  and consumes none here, so a mean that moves is a conservation failure. Only
  watching peaks is how the 24x `DROFUNIT` error survived two full archives.

## Reading the dams archive: two traps

**`rivdph` is meaningless at dam cells.** CaMa holds reservoir volume as
`rivsto` in the dam's own cell, so `rivdph = rivsto/(rivlen*rivwth)` reports a
"river depth" for a reservoir filling that cell — up to 468 m against a
control maximum of 10.7 m at the same cells. Measured on the 2024 CaMa
restart, 100% of differences above 10 m (and above 50, 100, 200, 400 m) fall on
dam cells, with **zero** spread into the network. This is a diagnostic that
does not apply, not an instability, and it is easy to confuse with the
run-of-river reservoir instability recorded under PLAN.md "Open blockers".
Exclude dam cells from any flood-depth or inundation analysis.

**ecLand output is byte-identical between the dams archive and v4.** With
`LECMF1WAY` the coupling is genuinely one-way: `restartout.nc` md5s match for
1988, 2000, 2012 and 2024, and so do `o_gg.nc`/`o_wat.nc`. So v4's validated
budgets apply to the dams archive by construction, there is no reason to run
an ecLand budget sweep over it, and only `cmf/` plus `restartout_cmf.nc`
carry the experiment. A future one-way CaMa experiment should skip ecLand
output entirely rather than duplicating ~30 GiB/year.

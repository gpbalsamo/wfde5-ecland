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

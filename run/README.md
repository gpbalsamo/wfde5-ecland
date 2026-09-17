# run/

Annual ecLand run driver, restart chaining, and diagnostics.

Status: **not started**. Planned, generalising `liaise-ecland/run/run_liaise_ecland.{sh,slurm}`:

- `run_ecland.sh` / `run_ecland.slurm` — CLI-driven (`--start-date`, `--end-date`,
  `--forcing-dir`, `--surfclim`, `--soilinit`, `--output-dir`, `--ecland-exe`,
  `--namelist`, `--dry-run`), no region name or grid dimensions encoded.
  Must preserve two hard-won correctness fixes from the reference repo (see
  `docs/migration_from_liaise.md`): the restart chain must actually be verified
  to carry state across the year boundary (not just assumed because a restart
  file was staged), and the OpenMP thread count must be an explicit, logged
  decision rather than an inherited shell default.
- `postprocess_ecland.sh` — generalised from `postprocess_liaise_ecland.sh`.
- `check_water_budget.py` / `check_energy_budget.py` — the *equation and sign
  convention* from the reference repo's copies (imported there, unmodified,
  from `plumber2-ecland`) are reused; the area-weighted **global** aggregation
  is new code, since the reference versions are per-site.
- `check_run.py` — new. Minimal "did this actually run" check: exit code, NaN
  scan, restart-chain verification.

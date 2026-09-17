# forcing/

WFDE5_CRU_GPCC acquisition and preparation for ecLand.

Status: **not started**. Planned scripts (see `PLAN.md` Milestone 1):

- `download_wfde5.py` — CDS retrieval of the `derived-near-surface-meteorological-variables`
  dataset, global 0.5°, generalised from `liaise-ecland/forcing/get_liaise_forcing_05_cds.py`
  (see `docs/migration_from_liaise.md`) by removing the regional crop step.
- `preprocess_wfde5.py` — time-axis rebasing and annual endpoint handling, ported
  near-unchanged from `liaise-ecland/forcing/prepare_liaise_forcing_ecland.py`.
- `validate_wfde5.py` — structural QC (dimensions, coordinate ordering, units,
  fill values, timestamps) with a `--strict` mode. See `docs/forcing_variables.md`
  for the variable/unit table this validates against.
- `inspect_grid.py` — quick grid-shape/coordinate report for any WFDE5 file.

No forcing data is committed here. See the repository `.gitignore`.

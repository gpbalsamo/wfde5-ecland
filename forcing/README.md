# forcing/

WFDE5_CRU_GPCC acquisition and preparation for ecLand.

Status: **`download_wfde5.py` ported and generalised, syntax-checked and
covered by synthetic tests (`tests/test_download_wfde5.py`), but NOT YET RUN
against a real CDS request** — see `PLAN.md` Milestone 1. The rest is not
started:

- `download_wfde5.py` — CDS retrieval of the `derived-near-surface-meteorological-variables`
  dataset, global 0.5°, generalised from `liaise-ecland/forcing/get_liaise_forcing_05_cds.py`
  (see `docs/migration_from_liaise.md`) by removing the regional crop step.
  Supports `--months` for a cheap single-month first request and `--dry-run`
  to print the exact CDS requests/output paths without calling CDS or
  writing anything — use `--dry-run` before ever running it for real.
- `preprocess_wfde5.py` — time-axis rebasing and annual endpoint handling, ported
  near-unchanged from `liaise-ecland/forcing/prepare_liaise_forcing_ecland.py`.
  **Not started.**
- `validate_wfde5.py` — structural QC (dimensions, coordinate ordering, units,
  fill values, timestamps) with a `--strict` mode. See `docs/forcing_variables.md`
  for the variable/unit table this validates against. **Not started** — this
  is the script that must actually answer `docs/forcing_variables.md`'s open
  questions (longitude convention, latitude ordering, timestamp semantics)
  against real downloaded data; `download_wfde5.py` deliberately does not
  assert any of that itself.
- `inspect_grid.py` — quick grid-shape/coordinate report for any WFDE5 file.
  **Not started.**

No forcing data is committed here. See the repository `.gitignore`. The
recommended first real invocation, once you're ready to spend CDS quota, is
one month of one year:

```bash
python3 forcing/download_wfde5.py --start-year 1988 --end-year 1988 --months 01 \
    --output-dir forcing/WFDE5_CRU_GPCC
```

not a full year or multi-year range — see the script's own docstring for the
peak-memory reasoning (a global 0.5° field is much larger than the LIAISE
crop this logic was validated against).

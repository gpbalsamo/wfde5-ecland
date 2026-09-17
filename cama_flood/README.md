# cama_flood/

Conservative runoff transfer from the ecLand 0.5° grid to CaMa-Flood's
unit-catchment routing network, and the routing run itself.

Status: **not started**. See `docs/migration_from_liaise.md` for the full
per-file reuse assessment. Highlights:

- `derive_cmf_weights.sh`'s domain-clipping step is LIAISE-specific and is
  dropped for a global run; its conservative remap-weight generation
  (`gen_inpmat.py`) against the ecLand grid is the reusable core.
- `build_global_cmf_fixdir.sh` already builds a genuinely **global** CaMa-Flood
  fix bundle at any resolution and is reused near-unchanged.
- `aggregate_runoff_to_daily.py`'s volume-conserving hourly→daily aggregation
  is grid-agnostic and reused directly.
- Two `ecland`-side source patches the reference repo required for correct
  regional clipping/routing are documented there; check whether they are still
  needed once a global run doesn't clip at all.

Planned new files: `remap_runoff.py`, `validate_remapping.py` (Phase 9's
conservation check — must fail if the relative water-volume discrepancy
between ecLand's total runoff and CaMa-Flood's mapped input exceeds a
configurable tolerance), `run_cama.sh`.

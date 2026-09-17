# namelist/

ecLand and CaMa-Flood namelist templates for a global configuration.

Status: **not started**. `liaise-ecland`'s actual namelist files encode its own
small grid's dimensions and cannot be reused verbatim, but the *patterns* they
established are worth carrying forward as templates in `templates/`:
env-var-driven templating (see `create_liaise_namelist.sh`), the
`TCOUPFREQ`-derived `IFRQ_INP`/`DROFUNIT`/`DT` relationship for CaMa-Flood
coupling, and the `CMPIREGNC`-required-even-for-a-single-process-run gotcha.
See `docs/migration_from_liaise.md` for the full list.

`global/` will hold the actual namelists once a pilot grid is chosen.

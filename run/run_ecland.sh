#!/usr/bin/env bash
set -euo pipefail

# Run ecLand for a global window using ecland's own OFFICIAL run tooling
# (share/ecland/scripts/ecland_create_namelist.py + ecland_run_model.sh),
# not a hand-rolled driver -- see PLAN.md Milestone 3. Direct execution,
# no sbatch/srun: a one-day global run is tiny (matches benchmark.yaml's
# `smoke` profile, which require_confirmation: false).
#
# Stages surfclim/soilinit (from init_clim/build_global_surfclim_soilinit.sh)
# and a WFDE5-derived forcing slice (via forcing/preprocess_wfde5.py) into
# the exact directory layout + filenames ecland_create_namelist.py expects
# (${datadir}/clim/${group}/surfclim_${site}.nc,
#  ${datadir}/forcing/${group}/met_2DHT_${site}.nc), then lets the official
# scripts render the namelist and run the model.
#
# Usage:
#   run/run_ecland.sh
#   START_DATE=1988-01-01T00:00:00 N_HOURS=25 run/run_ecland.sh

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "${SCRIPT_DIR}/.." && pwd)

export ECLAND_ROOT=${ECLAND_ROOT:-/perm/pad/ecland}
ECLAND_EXE=${ECLAND_EXE:-${ECLAND_ROOT}/build/bin/ecland-master-dp}
GROUP=${GROUP:-wfde5-ecland}
STA=${STA:-GLOBAL_19880101-19880102}
START_DATE=${START_DATE:-1988-01-01T00:00:00}
N_HOURS=${N_HOURS:-25}

FORCING_SOURCE=${FORCING_SOURCE:-${REPO_ROOT}/forcing/WFDE5_CRU_GPCC/WFDE5_CRU_GPCC_1988_01-01.nc}
SURFCLIM_SOURCE=${SURFCLIM_SOURCE:-${REPO_ROOT}/init_clim/work/output/wfde5-ecland/surfclim_GLOBAL_1988-2024.nc}
SOILINIT_SOURCE=${SOILINIT_SOURCE:-${REPO_ROOT}/init_clim/work/output/wfde5-ecland/surfinit_GLOBAL_1988-2024.nc}
NAMELIST_TEMPLATE=${NAMELIST_TEMPLATE:-${REPO_ROOT}/namelist/templates/namelist_ecland_50R1_ctl}

WORKDIR=${WORKDIR:-${REPO_ROOT}/run/work}
OUTPUT_DIR=${OUTPUT_DIR:-${REPO_ROOT}/run/output}

for f in "$ECLAND_EXE" "$FORCING_SOURCE" "$SURFCLIM_SOURCE" "$SOILINIT_SOURCE" "$NAMELIST_TEMPLATE"; do
    [[ -f "$f" ]] || { echo "ERROR: required input not found: $f" >&2; exit 1; }
done

DATADIR="${WORKDIR}/data"
CLIM_DIR="${DATADIR}/clim/${GROUP}"
FORCING_DIR="${DATADIR}/forcing/${GROUP}"
mkdir -p "$CLIM_DIR" "$FORCING_DIR" "$WORKDIR"

echo "== Staging surfclim/soilinit =="
cp -f "$SURFCLIM_SOURCE" "${CLIM_DIR}/surfclim_${STA}.nc"
cp -f "$SOILINIT_SOURCE" "${CLIM_DIR}/surfinit_${STA}.nc"

echo "== Preparing WFDE5 forcing slice (${N_HOURS}h from ${START_DATE}) =="
python3 "${REPO_ROOT}/forcing/preprocess_wfde5.py" \
    --input "$FORCING_SOURCE" \
    --output "${FORCING_DIR}/met_2DHT_${STA}.nc" \
    --start-date "$START_DATE" --n-hours "$N_HOURS" --overwrite

echo "== Rendering namelist (ecland's own ecland_create_namelist.py) =="
python3 "${ECLAND_ROOT}/share/ecland/scripts/ecland_create_namelist.py" \
    -g "$GROUP" -n "$NAMELIST_TEMPLATE" -s "$STA" -t 2D \
    -d "$DATADIR" -w "$WORKDIR"
RENDERED_NAMELIST="${WORKDIR}/namelist_${STA}"
[[ -f "$RENDERED_NAMELIST" ]] || { echo "ERROR: namelist was not rendered: $RENDERED_NAMELIST" >&2; exit 1; }
echo "Rendered: $RENDERED_NAMELIST"
grep -E "NSTOP|NLAT|NLON|NINDAT|NDFORC" "$RENDERED_NAMELIST" || true

echo "== Running ecland-master-dp (direct execution, no sbatch/srun) =="
export LAUNCH=""
"${ECLAND_ROOT}/share/ecland/scripts/ecland_run_model.sh" \
    -s "$STA" -b "$ECLAND_EXE" \
    -w "${WORKDIR}/run" -o "$OUTPUT_DIR" \
    -f "$FORCING_DIR" -i "$CLIM_DIR" \
    -F 2D -n "$RENDERED_NAMELIST"

RUN_OUTPUT_DIR="${OUTPUT_DIR}/${STA}"
echo
echo "== Output =="
ls -lh "$RUN_OUTPUT_DIR"
echo
echo "Output dir: $RUN_OUTPUT_DIR"
echo "Log:        ${RUN_OUTPUT_DIR}/run.log"

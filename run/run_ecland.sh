#!/usr/bin/env bash
set -euo pipefail

# Run ecLand for a global window using ecland's own OFFICIAL run tooling
# (share/ecland/scripts/ecland_create_namelist.py + ecland_run_model.sh),
# not a hand-rolled driver -- see PLAN.md Milestone 3/4/5. Direct execution,
# no sbatch/srun: matches benchmark.yaml's `smoke` profile
# (require_confirmation: false) even with RUN_CMF=true, since real MPI here
# means `mpirun -np N` on this same interactive node, not a SLURM job.
#
# Stages surfclim/soilinit (from init_clim/build_global_surfclim_soilinit.sh)
# and a WFDE5-derived forcing slice (via forcing/preprocess_wfde5.py) into
# the exact directory layout + filenames ecland_create_namelist.py expects
# (${datadir}/clim/${group}/surfclim_${site}.nc,
#  ${datadir}/forcing/${group}/met_2DHT_${site}.nc), then lets the official
# scripts render the namelist and run the model.
#
# Set RUN_CMF=true to couple to CaMa-Flood with real multi-rank MPI (see
# PLAN.md Milestone 4/5): uses namelist/templates/namelist_ecland_50R1_cmf
# (LECMF1WAY=.TRUE.) and namelist_cmf_global.tmpl, and CMF_WEIGHTS_DIR
# (cama_flood/build_global_cmf_fixdir.sh + derive_global_cmf_weights.sh's
# output -- inpmat.nc/rivpar.nc/rivclim.nc/bifprm.txt/mpireg.nc/diminfo.txt,
# all at the SAME NPES as NPES here, since mpireg.nc bakes in the rank
# count). Runs `ecland-master-cmflood-dp` via `mpirun -np ${NPES}`.
#
# Usage:
#   run/run_ecland.sh
#   START_DATE=1988-01-01T00:00:00 N_HOURS=25 run/run_ecland.sh
#   RUN_CMF=true NPES=2 START_DATE=1988-01-01T00:00:00 N_HOURS=744 \
#     STA=GLOBAL_CMF_198801 run/run_ecland.sh

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "${SCRIPT_DIR}/.." && pwd)

export ECLAND_ROOT=${ECLAND_ROOT:-/perm/pad/ecland}
RUN_CMF=${RUN_CMF:-false}
GROUP=${GROUP:-wfde5-ecland}
STA=${STA:-GLOBAL_19880101-19880102}
START_DATE=${START_DATE:-1988-01-01T00:00:00}
N_HOURS=${N_HOURS:-25}
NPES=${NPES:-2}

if [[ "$RUN_CMF" == "true" ]]; then
    # NOT ecland-master-cmflood-dp -- confirmed via src/surf/cmflood.cmake
    # that binary is built from offline/cmfld1s.F90, a STANDALONE
    # CaMa-Flood-only driver (reads pre-computed runoff from plain binary
    # files, ./runoff/Roff____YYYYMMDD.one) -- unrelated to online 1-way
    # coupling. The real online-coupled executable is plain
    # ecland-master-dp itself: master1s.F90 links libecland_cmflood_dp.so
    # and its own driver chain (cnt01s->cnt41s) calls CMF_FORCING_PUT +
    # CMF_DRV_ADVANCE directly, in-memory, every LECMF1WAY coupling step --
    # no file read at all. Found and fixed 2026-09-20 after a real crash
    # trying (and failing) to open that binary file with -cmflood-dp.
    ECLAND_EXE=${ECLAND_EXE:-${ECLAND_ROOT}/build/bin/ecland-master-dp}
    NAMELIST_TEMPLATE=${NAMELIST_TEMPLATE:-${REPO_ROOT}/namelist/templates/namelist_ecland_50R1_cmf}
    NAMELIST_CMF_TEMPLATE=${NAMELIST_CMF_TEMPLATE:-${REPO_ROOT}/namelist/templates/namelist_cmf_global.tmpl}
    CMF_WEIGHTS_DIR=${CMF_WEIGHTS_DIR:-${REPO_ROOT}/cama_flood/work_global_weights/glb_15min_out}
else
    ECLAND_EXE=${ECLAND_EXE:-${ECLAND_ROOT}/build/bin/ecland-master-dp}
    NAMELIST_TEMPLATE=${NAMELIST_TEMPLATE:-${REPO_ROOT}/namelist/templates/namelist_ecland_50R1_ctl}
fi

FORCING_SOURCE=${FORCING_SOURCE:-${REPO_ROOT}/forcing/WFDE5_CRU_GPCC/WFDE5_CRU_GPCC_1988_01-01.nc}
SURFCLIM_SOURCE=${SURFCLIM_SOURCE:-${REPO_ROOT}/init_clim/work/output/wfde5-ecland/surfclim_GLOBAL_1988-2024.nc}
SOILINIT_SOURCE=${SOILINIT_SOURCE:-${REPO_ROOT}/init_clim/work/output/wfde5-ecland/surfinit_GLOBAL_1988-2024.nc}

WORKDIR=${WORKDIR:-${REPO_ROOT}/run/work}
OUTPUT_DIR=${OUTPUT_DIR:-${REPO_ROOT}/run/output}

for f in "$ECLAND_EXE" "$FORCING_SOURCE" "$SURFCLIM_SOURCE" "$SOILINIT_SOURCE" "$NAMELIST_TEMPLATE"; do
    [[ -f "$f" ]] || { echo "ERROR: required input not found: $f" >&2; exit 1; }
done
if [[ "$RUN_CMF" == "true" ]]; then
    for f in "$NAMELIST_CMF_TEMPLATE" "${CMF_WEIGHTS_DIR}/inpmat.nc" "${CMF_WEIGHTS_DIR}/rivclim.nc" \
             "${CMF_WEIGHTS_DIR}/rivpar.nc" "${CMF_WEIGHTS_DIR}/bifprm.txt" \
             "${CMF_WEIGHTS_DIR}/mpireg.nc" "${CMF_WEIGHTS_DIR}/diminfo.txt"; do
        [[ -f "$f" ]] || { echo "ERROR: required CaMa-Flood input not found: $f" >&2; exit 1; }
    done
fi

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

echo "== Rendering namelist(s) (ecland's own ecland_create_namelist.py) =="
NAMELIST_ARGS=(-g "$GROUP" -n "$NAMELIST_TEMPLATE" -s "$STA" -t 2D -d "$DATADIR" -w "$WORKDIR")
if [[ "$RUN_CMF" == "true" ]]; then
    # diminfo_${STA}.txt is the one CMF input ecland_run_model.sh's RUN_CMF
    # path unconditionally `cp`s by that exact name -- everything else
    # (inpmat/rivpar/rivclim/bifprm/mpireg) is referenced by absolute path
    # directly inside the rendered CaMa namelist below, sidestepping that
    # script's ${STA}-suffixed symlink convention entirely.
    cp -f "${CMF_WEIGHTS_DIR}/diminfo.txt" "${CLIM_DIR}/diminfo_${STA}.txt"
    NAMELIST_ARGS+=(-c "$NAMELIST_CMF_TEMPLATE")
fi
python3 "${ECLAND_ROOT}/share/ecland/scripts/ecland_create_namelist.py" "${NAMELIST_ARGS[@]}"

RENDERED_NAMELIST="${WORKDIR}/namelist_${STA}"
[[ -f "$RENDERED_NAMELIST" ]] || { echo "ERROR: namelist was not rendered: $RENDERED_NAMELIST" >&2; exit 1; }
echo "Rendered: $RENDERED_NAMELIST"
grep -E "NSTOP|NLAT|NLON|NINDAT|NDFORC|LECMF1WAY" "$RENDERED_NAMELIST" || true

RUN_MODEL_ARGS=(-s "$STA" -b "$ECLAND_EXE" -w "${WORKDIR}/run" -o "$OUTPUT_DIR"
                -f "$FORCING_DIR" -i "$CLIM_DIR" -F 2D -n "$RENDERED_NAMELIST")

if [[ "$RUN_CMF" == "true" ]]; then
    RENDERED_NAMELIST_CMF="${WORKDIR}/namelist_cmf_${STA}"
    [[ -f "$RENDERED_NAMELIST_CMF" ]] || {
        echo "ERROR: CaMa namelist was not rendered: $RENDERED_NAMELIST_CMF" >&2
        echo "(ecland_create_namelist.py only renders it if LECMF1WAY=.TRUE. in the ecLand namelist above)" >&2
        exit 1
    }
    # CaMa-Flood's own output dir must be an ABSOLUTE path that exists
    # before the run starts: the default relative "./cmf_output/" is
    # relative to ecland_run_model.sh's ephemeral, rm-rf'd-then-recreated
    # run directory, which never has that subdirectory -- Fortran reports
    # this as "Permission denied" (really "directory doesn't exist"), not a
    # real permissions problem. Found 2026-09-20. NOT under
    # ${OUTPUT_DIR}/${STA} either -- ecland_run_model.sh does its own
    # `rm -rf ${OUTPUT_DIR}/${STA}` right before running, which would wipe
    # anything pre-staged there the same way.
    CMF_OUTDIR="${WORKDIR}/cmf_output_${STA}/"
    rm -rf "$CMF_OUTDIR"
    mkdir -p "$CMF_OUTDIR"

    # Fill in the absolute CaMa-Flood weight-file paths -- see
    # namelist_cmf_global.tmpl's own header for why these are absolute
    # rather than relying on ecland_run_model.sh's ${STA}-suffixed staging.
    sed -i \
        -e "s|__CAMA_BIFPRM__|${CMF_WEIGHTS_DIR}/bifprm.txt|" \
        -e "s|__CAMA_RIVCLIM__|${CMF_WEIGHTS_DIR}/rivclim.nc|" \
        -e "s|__CAMA_RIVPAR__|${CMF_WEIGHTS_DIR}/rivpar.nc|" \
        -e "s|__CAMA_MPIREG__|${CMF_WEIGHTS_DIR}/mpireg.nc|" \
        -e "s|__CAMA_INPMAT__|${CMF_WEIGHTS_DIR}/inpmat.nc|" \
        -e "s|__CAMA_OUTDIR__|${CMF_OUTDIR}|" \
        "$RENDERED_NAMELIST_CMF"
    echo "Rendered: $RENDERED_NAMELIST_CMF"
    grep -E "SYEAR|EYEAR|DT |IFRQ_INP|CMPIREGNC" "$RENDERED_NAMELIST_CMF" || true
    RUN_MODEL_ARGS+=(-c "$RENDERED_NAMELIST_CMF")
fi

if [[ "$RUN_CMF" == "true" ]]; then
    if [[ -n "${SLURM_JOB_ID:-}" ]]; then
        # Inside an sbatch allocation: plain `mpirun -np N` does not pick up
        # SLURM's own CPU binding and fails ("A request was made to bind to
        # that would result in binding more processes than cpus", confirmed
        # 2026-09-20) -- srun is the correct launcher here, inherits
        # --ntasks/--cpus-per-task from the allocation automatically. This
        # matches ecland's own ecland-launch script's default behaviour.
        echo "== Running ${ECLAND_EXE##*/} via srun (inside SLURM job ${SLURM_JOB_ID}) =="
        export LAUNCH="srun"
    else
        echo "== Running ${ECLAND_EXE##*/} via mpirun -np ${NPES} (direct, no sbatch/srun) =="
        export LAUNCH="mpirun -np ${NPES}"
    fi
else
    echo "== Running ecland-master-dp (direct execution, no sbatch/srun) =="
    export LAUNCH=""
fi
"${ECLAND_ROOT}/share/ecland/scripts/ecland_run_model.sh" "${RUN_MODEL_ARGS[@]}"

RUN_OUTPUT_DIR="${OUTPUT_DIR}/${STA}"
echo
echo "== Output =="
ls -lh "$RUN_OUTPUT_DIR"
echo
echo "Output dir: $RUN_OUTPUT_DIR"
echo "Log:        ${RUN_OUTPUT_DIR}/run.log"
if [[ "$RUN_CMF" == "true" ]]; then
    echo "CMF output: ${CMF_OUTDIR}"
    # log_CaMa.txt-<rank> is written into ecland_run_model.sh's ephemeral
    # run directory and is NOT moved anywhere -- only recoverable if the
    # run fails (that script's own `rm -rf ${RDIR}` cleanup only runs on
    # success/after a completed loop).
fi

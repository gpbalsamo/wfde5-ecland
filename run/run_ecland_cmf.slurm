#!/usr/bin/env bash
#SBATCH --job-name=wfde5_cmf
#SBATCH --nodes=1
#SBATCH --ntasks=2
#SBATCH --cpus-per-task=1
#SBATCH --mem=32G
#SBATCH --time=01:00:00
#SBATCH --qos=nf

# Batch wrapper for run/run_ecland.sh's RUN_CMF=true path -- see PLAN.md
# Milestone 4/5. Needed because 2 MPI ranks + CaMa-Flood coupling use
# ~4.3-4.5 GiB resident EACH (confirmed 2026-09-19/20), exceeding this
# project's interactive session's fixed 8 GiB memory cgroup almost
# immediately regardless of forcing duration or coupling frequency -- not a
# memory leak, just more memory than an interactive session is allotted.
# --mem=32G here gives real headroom over the ~8.6 GiB two ranks need.
#
# Requested only after explicit user approval (2026-09-20) -- see
# AGENTS.md's "any sbatch/SLURM submission" approval gate.
#
# Usage:
#   sbatch run/run_ecland_cmf.slurm
#   STA=GLOBALCMF_19880101-19880131 N_HOURS=744 sbatch run/run_ecland_cmf.slurm

set -euo pipefail

# NOT ${BASH_SOURCE[0]}-based resolution -- SLURM copies this script to a
# spool directory (/var/spool/slurmd/job<id>/slurm_script) before running
# it, so dirname($BASH_SOURCE) is NOT the repo (confirmed 2026-09-20: "No
# such file or directory" trying to exec a path under /var/spool/slurmd/).
# $SLURM_SUBMIT_DIR is the directory `sbatch` was invoked FROM.
REPO_ROOT=${SLURM_SUBMIT_DIR:?SLURM_SUBMIT_DIR not set -- run via sbatch, not directly}

# Settings come from a file passed as $1, NOT from the submitting shell's
# environment. ECMWF's sbatch wrapper injects its own
# `--export=EC_user_time_limit=...`, which REPLACES the default
# `--export=ALL`, so exported variables do NOT reach the job -- the script
# silently falls back to every default instead. Confirmed 2026-09-20: a run
# submitted with N_HOURS=8784 in the environment logged "Preparing WFDE5
# forcing slice (744h ...)" and began re-running January. Script arguments
# are unaffected by --export, so a sourced config file is the reliable
# channel.
#
#   sbatch run/run_ecland_cmf.slurm run/configs/year_1988.env
#
if [[ $# -ge 1 ]]; then
    CONFIG_FILE="$1"
    [[ -r "$CONFIG_FILE" ]] || { echo "ERROR: config file not readable: $CONFIG_FILE" >&2; exit 1; }
    echo "== Sourcing config: ${CONFIG_FILE} =="
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
fi

module load prgenv/intel intel/2021.4 hpcx-openmpi/2.9.0

export RUN_CMF=true
export NPES=${SLURM_NTASKS:-2}
export STA=${STA:-GLOBALCMF_19880101-19880131}
export START_DATE=${START_DATE:-1988-01-01T00:00:00}
export N_HOURS=${N_HOURS:-744}

# Passed through so a longer run can bound ecLand's resident forcing array
# instead of scaling it with N_HOURS -- GFOR is NPOI*NDFORC*12*8 bytes, so a
# leap year at 0.5 deg would need ~74 GB without this. 0 = off (default).
# See run_ecland.sh's own comment for the ecLand-side requirements.
export NFORCWINDOW=${NFORCWINDOW:-0}
# Which assembled WFDE5 file to slice the run's forcing out of. The default
# in run_ecland.sh is the single-month January 1988 file; a year run must
# point at the full-year file.
[[ -n "${FORCING_SOURCE:-}" ]] && export FORCING_SOURCE

# sbatch CLI options override the #SBATCH directives above, so a long run is
#   sbatch --time=18:00:00 --mem=48G ... run/run_ecland_cmf.slurm
# rather than a second copy of this script.

"${REPO_ROOT}/run/run_ecland.sh"

#!/usr/bin/env python3
"""Submit a chained multi-year ecLand->CaMa-Flood campaign.

Each segment restarts from the previous one (RESTART_FROM -> staged as
soilinit; see run/run_ecland.sh for why that is the mechanism and why the
result is verified rather than trusted) and is archived to ECFS on success.

Segment length is tied to output frequency by a hard, measured constraint:

    hourly output, 1 month  ->  o_gg.nc  36 GB  -- completes
    hourly output, 1 year   ->  o_gg.nc 424 GB  -- SIGBUS on the final write
    daily  output, 1 year   ->  o_gg.nc  18 GB  -- completes

The 424 GB failure is a large-file write fault, NOT disk or quota (the files
are sparse; actual use was 171 GB against 4.2 T free). The limit is bracketed
but not characterised, so segments are sized to stay well inside the proven
range: annual segments for daily output, monthly segments for hourly.

Every segment must end at hour 23 of its final day -- ecland_create_namelist.py
writes EHOUR=23 into the CaMa namelist unconditionally, and ecland_run_model.sh
then moves restart<EYEAR><EMON><EDAY><EHOUR>.nc. A segment ending at any other
hour fails AFTER a successful integration. Whole months and whole years both
satisfy this.
"""
import argparse, calendar, subprocess, sys
from pathlib import Path

def segments(y0, y1, mode):
    for y in range(y0, y1 + 1):
        if mode == "annual":
            n = 366 * 24 if calendar.isleap(y) else 365 * 24
            yield f"Y{y}", f"{y}-01-01T00:00:00", n, y
        else:
            for m in range(1, 13):
                d = calendar.monthrange(y, m)[1]
                yield f"Y{y}M{m:02d}", f"{y}-{m:02d}-01T00:00:00", d * 24, y

def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--start-year", type=int, required=True)
    ap.add_argument("--end-year", type=int, required=True)
    ap.add_argument("--mode", choices=["annual", "monthly"], default="annual",
                    help="annual (pair with daily output) or monthly (required for hourly)")
    ap.add_argument("--output-freq-hours", type=int, default=24,
                    help="24 = daily (default). 1 = hourly, which REQUIRES --mode monthly.")
    ap.add_argument("--restart-from", default="",
                    help="restartout.nc seeding the first segment; omit to cold-start")
    ap.add_argument("--ecfs-dir", default="ec:/pad/wfde5-ecland")
    ap.add_argument("--no-energy-output", action="store_true",
                    help="drop o_efl.nc (4.6 GB/yr); not needed for the water cycle "
                         "or the CaMa dam comparison, but removes energy-closure capability")
    ap.add_argument("--ranks", type=int, default=16)
    ap.add_argument("--threads", type=int, default=8)
    ap.add_argument("--time", default="06:00:00")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()

    if a.output_freq_hours < 24 and a.mode != "monthly":
        sys.exit("ERROR: hourly output needs --mode monthly; a year of hourly output "
                 "(424 GB o_gg.nc) dies with SIGBUS on the final write.")

    repo = Path(__file__).resolve().parent.parent
    cfgdir = repo / "run" / "configs" / "campaign"
    cfgdir.mkdir(parents=True, exist_ok=True)

    prev_restart, dep, jobs = a.restart_from, None, []
    for tag, start, nhours, year in segments(a.start_year, a.end_year, a.mode):
        forcing = repo / "forcing" / "WFDE5_CRU_GPCC" / f"WFDE5_CRU_GPCC_{year}.nc"
        if not forcing.exists() and not a.dry_run:
            sys.exit(f"ERROR: forcing missing for {year}: {forcing}\n"
                     f"       run forcing/download_wfde5.py --start-year {year} --end-year {year}")
        sd = start[:10].replace("-", "")
        ed = f"{year+1}0101" if a.mode == "annual" else "%04d%02d01" % (
            year + (tag.endswith("M12")), 1 if tag.endswith("M12") else int(tag[-2:]) + 1)
        sta = f"{tag}_{sd}-{ed}"
        cfg = cfgdir / f"{tag}.env"
        lines = [f"START_DATE={start}", f"N_HOURS={nhours}",
                 f"NFORCWINDOW={min(744, nhours)}",
                 f"OUTPUT_FREQ_HOURS={a.output_freq_hours}",
                 f"OMP_NUM_THREADS={a.threads}", f"STA={sta}",
                 f"FORCING_SOURCE={forcing}",
                 f"CMF_WEIGHTS_DIR={repo}/cama_flood/work_global_weights/glb_15min_out_n{a.ranks}",
                 f"ECFS_DIR={a.ecfs_dir}"]
        if a.no_energy_output:
            lines.append("WRITE_EFL=false")
        if prev_restart:
            lines.append(f"RESTART_FROM={prev_restart}")
        cfg.write_text("\n".join(lines) + "\n")

        cmd = ["sbatch", "--parsable", f"--time={a.time}", "--mem=64G",
               f"--ntasks={a.ranks}", f"--cpus-per-task={a.threads}",
               f"--job-name={tag}"]
        if dep:
            cmd.append(f"--dependency=afterok:{dep}")
        cmd += ["run/run_ecland_cmf.slurm", str(cfg.relative_to(repo))]
        if a.dry_run:
            print(f"  {tag:10s} {nhours:>5}h  restart_from={'(cold)' if not prev_restart else Path(prev_restart).parent.name}")
        else:
            dep = subprocess.run(cmd, cwd=repo, capture_output=True, text=True,
                                 check=True).stdout.strip()
            jobs.append((tag, dep))
            print(f"  {tag:10s} {nhours:>5}h  job {dep}" + (f"  after {jobs[-2][1]}" if len(jobs) > 1 else "  (head)"))
        prev_restart = f"{repo}/run/output/{sta}/restartout.nc"

    if not a.dry_run:
        print(f"\nsubmitted {len(jobs)} chained segments; first={jobs[0][1]} last={jobs[-1][1]}")

if __name__ == "__main__":
    main()

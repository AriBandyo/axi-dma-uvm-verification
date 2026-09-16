#!/usr/bin/env python3
from __future__ import annotations

import argparse
import shutil
import subprocess
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser(description="Merge and export xsim coverage databases")
    parser.add_argument("--results", type=Path, default=Path("results"))
    parser.add_argument("--output", type=Path, default=Path("coverage/merged"))
    args = parser.parse_args()

    database_files = sorted(args.results.rglob("xsim.covinfo"))
    databases = [(path.parent.name, path.parents[2]) for path in database_files]
    if not databases:
        print("no xsim coverage databases found")
        return 2
    if shutil.which("export_xsim_coverage") is None:
        print("export_xsim_coverage is required")
        return 2
    args.output.mkdir(parents=True, exist_ok=True)
    command = ["export_xsim_coverage"]
    for database_name, database_directory in databases:
        command.extend(["-cov_db_name", database_name, "-cov_db_dir", str(database_directory)])
    command.extend([
        "-output_dir", str(args.output / "html"),
        "-merge_dir", str(args.output),
        "-merge_db_name", "veridma_merged",
        "-report_format", "all",
    ])
    return subprocess.call(command)


if __name__ == "__main__":
    raise SystemExit(main())

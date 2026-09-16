#!/usr/bin/env python3
from __future__ import annotations

import argparse
import concurrent.futures
import shutil
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

import yaml

from regression_lib import RunResult, bucket_failures, build_plan, extract_failure_signature, write_json


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]


def load_profile(name: str) -> dict:
    config_path = REPOSITORY_ROOT / "config" / "regression.yaml"
    config = yaml.safe_load(config_path.read_text(encoding="utf-8"))
    try:
        return config["profiles"][name]
    except KeyError as exc:
        available = ", ".join(sorted(config.get("profiles", {})))
        raise SystemExit(f"unknown profile {name!r}; available profiles: {available}") from exc


def run_one(spec, run_directory: Path, timeout_seconds: int) -> RunResult:
    log_path = run_directory / "logs" / f"{spec.index:05d}_{spec.test}_{spec.seed}.log"
    log_path.parent.mkdir(parents=True, exist_ok=True)
    command = [
        "make",
        "test",
        f"TEST={spec.test}",
        f"SEED={spec.seed}",
        f"RESULT_DIR={run_directory.relative_to(REPOSITORY_ROOT)}",
    ]
    started = time.monotonic()
    try:
        completed = subprocess.run(
            command,
            cwd=REPOSITORY_ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=timeout_seconds,
            check=False,
        )
        output = completed.stdout
        return_code = completed.returncode
    except subprocess.TimeoutExpired as exc:
        output = (exc.stdout or "") + f"\nREGRESSION_TIMEOUT after {timeout_seconds} seconds\n"
        return_code = 124
    log_path.write_text(output, encoding="utf-8")
    return RunResult(
        index=spec.index,
        test=spec.test,
        seed=spec.seed,
        return_code=return_code,
        elapsed_seconds=round(time.monotonic() - started, 3),
        log_path=str(log_path.relative_to(REPOSITORY_ROOT)),
        signature=extract_failure_signature(output),
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Run deterministic VeriDMA xsim regressions")
    parser.add_argument("--profile", default="smoke")
    parser.add_argument("--tests", type=int, help="override the number of runs in the profile")
    parser.add_argument("--jobs", type=int, default=4)
    parser.add_argument("--dry-run", action="store_true", help="write a manifest without invoking xsim")
    args = parser.parse_args()

    profile = load_profile(args.profile)
    repetitions = args.tests if args.tests is not None else int(profile["repetitions"])
    plan = build_plan(args.profile, list(profile["tests"]), repetitions)
    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%d_%H%M%SZ")
    run_directory = REPOSITORY_ROOT / "results" / f"{timestamp}_{args.profile}"
    run_directory.mkdir(parents=True, exist_ok=False)
    manifest = {
        "profile": args.profile,
        "created_utc": timestamp,
        "timeout_seconds": int(profile["timeout_seconds"]),
        "runs": [spec.__dict__ for spec in plan],
    }
    write_json(run_directory / "manifest.json", manifest)

    if args.dry_run:
        print(f"planned {len(plan)} runs in {run_directory.relative_to(REPOSITORY_ROOT)}")
        return 0

    if shutil.which("xvlog") is None or shutil.which("xsim") is None:
        print("Vivado xsim tools were not found in PATH", file=sys.stderr)
        return 2

    compile_result = subprocess.run(["make", "compile"], cwd=REPOSITORY_ROOT, check=False)
    if compile_result.returncode != 0:
        return compile_result.returncode

    with concurrent.futures.ThreadPoolExecutor(max_workers=max(1, args.jobs)) as executor:
        futures = [
            executor.submit(run_one, spec, run_directory, int(profile["timeout_seconds"]))
            for spec in plan
        ]
        results = [future.result() for future in concurrent.futures.as_completed(futures)]
    results.sort(key=lambda result: result.index)

    buckets = bucket_failures(results)
    summary = {
        "profile": args.profile,
        "total": len(results),
        "passed": sum(result.passed for result in results),
        "failed": sum(not result.passed for result in results),
        "failure_buckets": {
            signature: [{"test": item.test, "seed": item.seed} for item in members]
            for signature, members in buckets.items()
        },
        "runs": [result.to_dict() for result in results],
    }
    write_json(run_directory / "summary.json", summary)
    print(f"VeriDMA {args.profile}: {summary['passed']}/{summary['total']} passed")
    for signature, members in buckets.items():
        seeds = ", ".join(str(member.seed) for member in members)
        print(f"  [{len(members)}] {signature}: seeds {seeds}")
    return 1 if buckets else 0


if __name__ == "__main__":
    raise SystemExit(main())

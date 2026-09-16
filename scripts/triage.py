#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path

from regression_lib import RunResult, bucket_failures


def main() -> int:
    parser = argparse.ArgumentParser(description="Bucket VeriDMA regression failures by first signature")
    parser.add_argument("--run", required=True, type=Path)
    args = parser.parse_args()

    summary_path = args.run / "summary.json"
    summary = json.loads(summary_path.read_text(encoding="utf-8"))
    results = [
        RunResult(
            index=item["index"],
            test=item["test"],
            seed=item["seed"],
            return_code=item["return_code"],
            elapsed_seconds=item["elapsed_seconds"],
            log_path=item["log_path"],
            signature=item.get("signature"),
        )
        for item in summary["runs"]
    ]
    buckets = bucket_failures(results)
    print(f"VERIDMA REGRESSION — {summary['profile']}")
    print(f"Tests run: {len(results)}")
    print(f"Passed:    {sum(result.passed for result in results)}")
    print(f"Failed:    {sum(not result.passed for result in results)}")
    print("\nFailure buckets:")
    if not buckets:
        print("  none")
    for signature, members in buckets.items():
        seeds = ", ".join(str(member.seed) for member in members)
        print(f"  [{len(members)}] {signature} — seeds {seeds}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

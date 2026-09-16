#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]


def main() -> int:
    parser = argparse.ArgumentParser(description="Reproduce one VeriDMA regression seed")
    parser.add_argument("--run", required=True, type=Path)
    parser.add_argument("--seed", required=True, type=int)
    parser.add_argument("--wave", action="store_true")
    args = parser.parse_args()

    manifest = json.loads((args.run / "manifest.json").read_text(encoding="utf-8"))
    matches = [entry for entry in manifest["runs"] if entry["seed"] == args.seed]
    if len(matches) != 1:
        raise SystemExit(f"expected one run for seed {args.seed}, found {len(matches)}")
    selected = matches[0]
    target = "wave" if args.wave else "test"
    command = ["make", target, f"TEST={selected['test']}", f"SEED={selected['seed']}"]
    return subprocess.call(command, cwd=REPOSITORY_ROOT)


if __name__ == "__main__":
    raise SystemExit(main())

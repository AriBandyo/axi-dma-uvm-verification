from __future__ import annotations

import hashlib
import json
import re
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Iterable


ERROR_PATTERNS = (
    re.compile(r"UVM_(?:ERROR|FATAL)\s*(?:@\s*\d+:)?\s*([^\n]+)"),
    re.compile(r"(?:Assertion|assertion).*?(?:failed|FAIL)[^\n]*", re.IGNORECASE),
    re.compile(r"SCOREBOARD[^\n]*(?:mismatch|error)[^\n]*", re.IGNORECASE),
)


@dataclass(frozen=True)
class RunSpec:
    index: int
    test: str
    seed: int


@dataclass
class RunResult:
    index: int
    test: str
    seed: int
    return_code: int
    elapsed_seconds: float
    log_path: str
    signature: str | None

    @property
    def passed(self) -> bool:
        return self.return_code == 0 and self.signature is None

    def to_dict(self) -> dict:
        result = asdict(self)
        result["passed"] = self.passed
        return result


def deterministic_seed(profile: str, index: int) -> int:
    digest = hashlib.sha256(f"veridma:{profile}:{index}".encode()).digest()
    return int.from_bytes(digest[:4], "big") & 0x7FFFFFFF or 1


def build_plan(profile: str, tests: list[str], repetitions: int) -> list[RunSpec]:
    if not tests:
        raise ValueError(f"profile {profile!r} has no tests")
    if repetitions <= 0:
        raise ValueError("repetitions must be positive")
    return [
        RunSpec(index=index, test=tests[index % len(tests)], seed=deterministic_seed(profile, index))
        for index in range(repetitions)
    ]


def extract_failure_signature(log_text: str) -> str | None:
    for line in log_text.splitlines():
        for pattern in ERROR_PATTERNS:
            match = pattern.search(line)
            if match:
                signature = match.group(1) if match.lastindex else match.group(0)
                signature = re.sub(r"\b(?:seed|address)=?(?:0x)?[0-9a-f]+\b", "<value>", signature, flags=re.IGNORECASE)
                signature = re.sub(r"\s+", " ", signature).strip()
                return signature[:240]
    return None


def bucket_failures(results: Iterable[RunResult]) -> dict[str, list[RunResult]]:
    buckets: dict[str, list[RunResult]] = {}
    for result in results:
        if result.passed:
            continue
        signature = result.signature or f"process exited with code {result.return_code}"
        buckets.setdefault(signature, []).append(result)
    return buckets


def write_json(path: Path, payload: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")

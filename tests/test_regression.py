import sys
import unittest
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

from regression_lib import RunResult, bucket_failures, build_plan, extract_failure_signature


class RegressionLibraryTests(unittest.TestCase):
    def test_plan_is_deterministic(self):
        first = build_plan("smoke", ["a", "b"], 5)
        second = build_plan("smoke", ["a", "b"], 5)
        self.assertEqual(first, second)
        self.assertEqual([run.test for run in first], ["a", "b", "a", "b", "a"])
        self.assertEqual(len({run.seed for run in first}), 5)

    def test_error_signature_normalizes_seed_and_address(self):
        text = "UVM_ERROR @ 450: scoreboard destination mismatch address=0x1008 seed=992841"
        signature = extract_failure_signature(text)
        self.assertEqual(signature, "scoreboard destination mismatch <value> <value>")

    def test_failure_bucketing(self):
        results = [
            RunResult(0, "test_a", 1, 1, 1.0, "a.log", "same failure"),
            RunResult(1, "test_a", 2, 1, 1.0, "b.log", "same failure"),
            RunResult(2, "test_b", 3, 0, 1.0, "c.log", None),
        ]
        buckets = bucket_failures(results)
        self.assertEqual(len(buckets["same failure"]), 2)


if __name__ == "__main__":
    unittest.main()

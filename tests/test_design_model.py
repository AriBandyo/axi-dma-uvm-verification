import sys
import unittest
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

from design_model import crc32, plan_bursts, ranges_overlap, validate_descriptor


class DesignModelTests(unittest.TestCase):
    def test_crc_canonical_vector(self):
        self.assertEqual(crc32(b"123456789"), 0xCBF43926)

    def test_adjacent_ranges_are_legal(self):
        self.assertFalse(ranges_overlap(0x1000, 0x1080, 0x80))
        validate_descriptor(0x1000, 0x1080, 0x80, 16)

    def test_overlap_is_rejected(self):
        self.assertTrue(ranges_overlap(0x1000, 0x1040, 0x80))
        with self.assertRaisesRegex(ValueError, "overlapping"):
            validate_descriptor(0x1000, 0x1040, 0x80, 16)

    def test_bursts_obey_both_4kb_boundaries(self):
        bursts = plan_bursts(0x0FC0, 0x10FE0, 512, 16)
        self.assertEqual(bursts[0].beats, 4)
        self.assertEqual(sum(burst.byte_count for burst in bursts), 512)
        for burst in bursts:
            self.assertLessEqual(burst.source_address % 4096 + burst.byte_count, 4096)
            self.assertLessEqual(burst.destination_address % 4096 + burst.byte_count, 4096)

    def test_invalid_burst_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "unsupported"):
            validate_descriptor(0x1000, 0x2000, 64, 3)


if __name__ == "__main__":
    unittest.main()

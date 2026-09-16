# BUG-000: concise symptom

- Status: Open
- Found by: `<test>`
- Seed: `<seed>`
- First failing log: `<path>`
- Waveform: `<path>`
- Fix commit: `<sha>`

## Symptom

Describe the first externally visible failure and the exact mismatch or
assertion.

## Root cause

Describe the incorrect state transition, handshake, counter update, or protocol
assumption. Do not restate the symptom.

## Fix

Describe the minimal behavioral change and why it preserves neighboring cases.

## Verification hole

Record why the existing tests, coverage, or assertions did not expose the bug
earlier. Link the new checker or coverpoint.

## Reproducer

```bash
python3 scripts/rerun.py --run results/<run> --seed <seed> --wave
```

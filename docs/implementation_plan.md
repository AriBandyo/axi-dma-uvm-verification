# Implementation and execution plan

## Stage A: local static validation

- Run repository structure, Python unit, and C++ reference-model tests.
- Run Verilator lint and resolve every warning that can conceal a logic defect.
- Review every interface payload for VALID/READY stability.

Exit: all local gates pass and no generated metric is claimed.

## Stage B: xsim bring-up

- Compile `dma_register_test` first.
- Confirm config-db paths and factory override trace.
- Link DPI at compile time and run the CRC self-test.
- Run `dma_smoke_test` with a fixed seed and inspect one waveform end to end.

Exit: one clean transfer, one linked DPI model, zero UVM errors.

## Stage C: protocol and negative tests

- Run illegal, 4 KB, error, abort, reset, and ordering tests individually.
- For every failure, save the seed before changing code.
- Add a real bug record under `bugs/found/` for nontrivial defects.

Exit: every implemented row in the test plan has a deterministic passing test.

## Stage D: coverage and assertions

- Run the 1,000-seed nightly profile.
- Merge functional and code coverage.
- Review assertion cover properties for vacuity.
- Add targeted constraints or sequences only for real holes.
- Justify unreachable bins in the waiver directory.

Exit: an archived report and written closure narrative, not a guessed target.

## Stage E: mutation campaign

- Introduce one mutant at a time from `bugs/mutants/manifest.yaml`.
- Run the unchanged standard regression.
- Record detecting test, seed, assertion, and time to detection.
- Analyze escapes before adding a checker.

Exit: every original escape has a documented test or assertion that detects it.

## Stage F: multiple outstanding extension

- Replace burst-at-a-time scheduling with decoupled issue and retire queues.
- Add transaction tags even while the external AXI ID remains fixed.
- Prove counter bounds and FIFO-credit accounting before enabling depth 2 or 4.
- Only then update the README status from staged to implemented.

# Verification test plan

Status meanings:

- **Implemented, awaiting execution**: stimulus and checking exist; target-tool
  evidence has not yet been archived.
- **Closed**: test passed, coverpoint hit, assertion exercised, report archived.
- **Planned**: implementation is intentionally Phase 2.

| ID | Feature | Primary tests | Coverage and assertions | Status |
|---|---|---|---|---|
| F01 | Basic aligned transfer | `dma_smoke_test` | length, burst, `a_done_not_busy` | Implemented, awaiting execution |
| F02 | AXI-Lite register semantics | `dma_register_test` | access cross, formal `regs` | Implemented, awaiting execution |
| F03 | 4 KB split on source and destination | `dma_4kb_test` | burst × crossing, no-cross SVA | Implemented, awaiting execution |
| F04 | Random legal descriptors | `dma_random_test` | length × burst, CRC | Implemented, awaiting execution |
| F05 | Zero length rejection | `dma_illegal_test` | error status | Implemented, awaiting execution |
| F06 | Unaligned rejection | `dma_illegal_test` | alignment path | Implemented, awaiting execution |
| F07 | Overlap rejection | `dma_illegal_test` | overlap error | Implemented, awaiting execution |
| F08 | Read `SLVERR` and `DECERR` | `dma_error_test` | kind × response | Implemented, awaiting execution |
| F09 | Write `SLVERR` and `DECERR` | `dma_error_test` | kind × response | Implemented, awaiting execution |
| F10 | Read and write backpressure | `dma_random_test` | stall scenarios, stable SVA | Implemented, awaiting execution |
| F11 | Graceful abort | `dma_abort_test` | termination × state, bounded abort | Implemented, awaiting execution |
| F12 | Reset during active transfer | `dma_reset_test` | reset × state, reset checks | Implemented, awaiting execution |
| F13 | Post-reset recovery | `dma_reset_test` | completion after reset | Implemented, awaiting execution |
| F14 | Back-to-back chained descriptors | `dma_ordering_test` | gap and chain | Implemented, awaiting execution |
| F15 | Guard-region integrity | all data tests | scoreboard guard checks | Implemented, awaiting execution |
| F16 | Partial progress | abort and error tests | `BYTES_XFERRED` scoreboard | Implemented, awaiting execution |
| F17 | CRC32 | smoke and random tests | CRC enabled/disabled | Implemented, awaiting execution |
| F18 | FIFO overflow/underflow | random tests, formal `fifo` | FIFO SVA and invariants | Implemented, awaiting execution |
| F19 | Factory configuration | `dma_error_test`, `dma_4kb_test` | override log | Implemented, awaiting execution |
| F20 | Multiple outstanding requests | Phase 2 | outstanding × backpressure | Planned |
| F21 | Multiple IDs and reordering | Phase 2 | ID × response order | Planned |

## Closure gate

For each row, archive:

1. the exact test and deterministic seed,
2. the first passing log after the relevant change,
3. merged functional and code coverage evidence,
4. assertion cover evidence proving the antecedent occurred,
5. a waiver with written justification for any unreachable bin.

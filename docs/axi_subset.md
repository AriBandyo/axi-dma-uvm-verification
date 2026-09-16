# Declared AXI subset

## Supported in v1

- One AXI4 read ID and one AXI4 write ID, both tied to zero
- 64-bit address and data paths
- INCR bursts with 8-byte beats
- Aligned source address, destination address, and transfer length
- Configured burst length of 1, 2, 4, 8, or 16 beats
- Automatic splitting before either source or destination crosses 4 KB
- One outstanding read burst and one outstanding write burst
- AXI4-Lite register access with independent address and data handshakes
- Read and write `SLVERR` and `DECERR` detection

## Not supported in v1

- FIXED or WRAP bursts
- Exclusive access
- Narrow or unaligned transfers
- Multiple AXI IDs or out-of-order responses
- Scatter-gather descriptors
- Memory-overlap semantics

## Rejection behavior

The engine rejects a descriptor before issuing AXI traffic when:

- `LENGTH` is zero: `ERROR_STATUS.LEN_ZERO`
- any address or the length is not 8-byte aligned: `ERROR_STATUS.ALIGN`
- source and destination half-open ranges overlap: `ERROR_STATUS.OVERLAP`
- length exceeds 24 addressable length bits: `ERROR_STATUS.PROTOCOL`
- the burst configuration is not 1, 2, 4, 8, or 16: `ERROR_STATUS.PROTOCOL`

The ranges are defined as `[address, address + length)`, so adjacent ranges are
legal and do not count as overlap.

## Progress and termination

`BYTES_XFERRED` advances only after the write response for the corresponding
burst is `OKAY`. The backing memory model commits a write burst only when it
returns `OKAY`; this makes committed progress observable and deterministic.

`ABORT` is graceful. If a burst has already been issued, the engine completes
the read and write transaction, waits for `BRESP`, updates progress on success,
and terminates with `ERROR_STATUS.ABORTED`. It never drops `VALID` to abandon an
AXI transaction.

An asynchronous reset clears the engine immediately. The testbench then proves
recoverability by programming a fresh descriptor and requiring it to complete.

## Register additions to the original proposal

The original error field used bits 0 through 6. VeriDMA assigns:

| Bit | Name | Meaning |
|---:|---|---|
| 7 | `OVERLAP` | Source and destination ranges overlap |
| 8 | `PROTOCOL` | Unsupported config, oversized length, or malformed read response |

The `CONFIG.max_outstanding` field is retained for compatibility with the next
implementation stage. Values greater than one do not change baseline behavior
and are not claimed as implemented.

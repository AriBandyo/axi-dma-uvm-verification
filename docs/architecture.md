# Architecture

## Transaction invariant

The controller never mixes data from different bursts in the FIFO. A burst is
planned, completely read, completely written, and acknowledged before the next
burst is planned. With a maximum burst of 16 beats and a default FIFO depth of
16, this creates a simple invariant:

> FIFO contents always belong to the single burst whose write response has not
> yet retired.

This is slower than a pipelined DMA, but it makes the first verification target
precise and creates a clean baseline for adding multiple outstanding requests.

## Burst planning

The number of beats is the minimum of:

- remaining transfer beats
- configured maximum burst beats
- beats remaining before the source 4 KB boundary
- beats remaining before the destination 4 KB boundary
- FIFO depth

The controller recalculates this value after every successful write response.
Both address streams therefore obey the AXI 4 KB rule even when their page
offsets differ.

## Register shadowing

Configuration writes are allowed while a transfer is active, but the controller
uses a descriptor snapshot captured at `START`. Reprogramming cannot alter an
in-flight transfer. The new register values apply only to the next `START`.

## Error model

Read response errors stop the transfer before buffered data is written. Write
response errors terminate without incrementing committed progress. A malformed
`RLAST` is reported as a protocol error. Every error flushes the FIFO, records a
direction-specific sticky bit, and raises the interrupt when enabled.

## CRC model

CRC uses the reflected polynomial `0xEDB88320`, initial value `0xFFFFFFFF`, and
final XOR `0xFFFFFFFF`. Bytes are consumed in increasing address order within
each accepted 64-bit write beat. The C++ model uses a separate implementation
and is checked against the canonical `123456789 -> 0xCBF43926` vector.

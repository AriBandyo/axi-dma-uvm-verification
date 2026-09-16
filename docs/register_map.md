# Register map

All registers are 32 bits wide and word-aligned. AXI-Lite byte strobes apply to
ordinary writable fields. Reserved bits read zero.

| Offset | Register | Access | Fields |
|---:|---|---|---|
| `0x00` | `CONTROL` | WO | bit 0 `START` W1S, bit 1 `ABORT` W1S, bit 2 `IRQ_CLEAR` W1C |
| `0x04` | `STATUS` | RO | bit 0 `BUSY`, bit 1 `DONE`, bit 2 `ERROR`, bit 3 `IRQ_PENDING` |
| `0x08` | `SRC_ADDR_LOW` | RW | source address bits 31:0 |
| `0x0C` | `SRC_ADDR_HIGH` | RW | source address bits 63:32 |
| `0x10` | `DST_ADDR_LOW` | RW | destination address bits 31:0 |
| `0x14` | `DST_ADDR_HIGH` | RW | destination address bits 63:32 |
| `0x18` | `LENGTH` | RW | byte count, maximum `0x00FF_FFFF` |
| `0x1C` | `CONFIG` | RW | bits 4:0 burst beats, bit 8 IRQ enable, bits 10:9 requested outstanding, bit 12 CRC enable |
| `0x20` | `ERROR_STATUS` | RO | sticky error bits described below |
| `0x24` | `BYTES_XFERRED` | RO | bytes retired after successful write responses |
| `0x28` | `CRC_RESULT` | RO | final reflected CRC32 |
| `0x2C` | `IP_VERSION` | RO | `0x0001_0000` |

## Error bits

| Bit | Name | Meaning |
|---:|---|---|
| 0 | `RD_SLVERR` | read response reported slave error |
| 1 | `RD_DECERR` | read response reported decode error |
| 2 | `WR_SLVERR` | write response reported slave error |
| 3 | `WR_DECERR` | write response reported decode error |
| 4 | `ALIGN` | source, destination, or length is not 8-byte aligned |
| 5 | `LEN_ZERO` | zero-byte descriptor rejected |
| 6 | `ABORTED` | graceful abort completed |
| 7 | `OVERLAP` | overlapping source and destination rejected |
| 8 | `PROTOCOL` | unsupported config, oversized length, or malformed response |

`START` clears stale completion, error, interrupt, and progress state before the
new command is validated. Configuration values are shadow registers: writes
during `BUSY` change the next descriptor, never the active snapshot.

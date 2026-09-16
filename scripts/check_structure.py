#!/usr/bin/env python3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REQUIRED = {
    "README.md",
    "Makefile",
    "rtl/dma_top.sv",
    "rtl/dma_regs.sv",
    "rtl/dma_ctrl_fsm.sv",
    "rtl/dma_read_engine.sv",
    "rtl/dma_write_engine.sv",
    "rtl/dma_fifo.sv",
    "rtl/dma_crc32.sv",
    "tb/uvc/axil/axil_uvc_pkg.sv",
    "tb/uvc/axi_mem/axi_mem_uvc_pkg.sv",
    "tb/env/dma_scoreboard.sv",
    "tb/sva/dma_sva.sv",
    "formal/fifo.sby",
    "model/dma_ref.cpp",
    "docs/testplan.md",
    "docs/register_map.md",
}


def main() -> int:
    missing = sorted(path for path in REQUIRED if not (ROOT / path).is_file())
    if missing:
        print("missing required project files:")
        for path in missing:
            print(f"  {path}")
        return 1
    print(f"repository structure valid: {len(REQUIRED)} required artifacts present")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

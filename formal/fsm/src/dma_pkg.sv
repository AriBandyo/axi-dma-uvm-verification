package dma_pkg;
  localparam int unsigned AXI_DATA_WIDTH = 64;
  localparam int unsigned AXI_ADDR_WIDTH = 64;
  localparam int unsigned AXIL_DATA_WIDTH = 32;
  localparam int unsigned AXIL_ADDR_WIDTH = 8;
  localparam int unsigned BYTES_PER_BEAT = AXI_DATA_WIDTH / 8;
  localparam logic [2:0] AXI_SIZE_8_BYTES = 3'd3;

  localparam logic [1:0] AXI_RESP_OKAY   = 2'b00;
  localparam logic [1:0] AXI_RESP_SLVERR = 2'b10;
  localparam logic [1:0] AXI_RESP_DECERR = 2'b11;

  localparam int unsigned ERR_RD_SLVERR = 0;
  localparam int unsigned ERR_RD_DECERR = 1;
  localparam int unsigned ERR_WR_SLVERR = 2;
  localparam int unsigned ERR_WR_DECERR = 3;
  localparam int unsigned ERR_ALIGN     = 4;
  localparam int unsigned ERR_LEN_ZERO  = 5;
  localparam int unsigned ERR_ABORTED   = 6;
  localparam int unsigned ERR_OVERLAP   = 7;
  localparam int unsigned ERR_PROTOCOL  = 8;

  typedef enum logic [3:0] {
    DMA_IDLE       = 4'd0,
    DMA_VALIDATE   = 4'd1,
    DMA_PLAN       = 4'd2,
    DMA_READ_CMD   = 4'd3,
    DMA_READ_DATA  = 4'd4,
    DMA_WRITE_CMD  = 4'd5,
    DMA_WRITE_DATA = 4'd6,
    DMA_COMPLETE   = 4'd7,
    DMA_ERROR      = 4'd8,
    DMA_ABORT      = 4'd9
  } dma_state_e;

endpackage

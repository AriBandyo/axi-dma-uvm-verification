interface dma_probe_if(input logic aclk);
  logic resetn;
  logic busy;
  logic [3:0] controller_state;
  logic [4:0] fifo_occupancy;
  logic read_active;
  logic write_active;
  logic completion_event;
  logic error_event;
endinterface

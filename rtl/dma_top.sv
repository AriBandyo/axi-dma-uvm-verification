module dma_top #(
  parameter int unsigned FIFO_DEPTH = 16,
  parameter int unsigned AXI_ID_WIDTH = 4
) (
  input  logic                    aclk,
  input  logic                    aresetn,

  input  logic [7:0]              s_axil_awaddr,
  input  logic                    s_axil_awvalid,
  output logic                    s_axil_awready,
  input  logic [31:0]             s_axil_wdata,
  input  logic [3:0]              s_axil_wstrb,
  input  logic                    s_axil_wvalid,
  output logic                    s_axil_wready,
  output logic [1:0]              s_axil_bresp,
  output logic                    s_axil_bvalid,
  input  logic                    s_axil_bready,
  input  logic [7:0]              s_axil_araddr,
  input  logic                    s_axil_arvalid,
  output logic                    s_axil_arready,
  output logic [31:0]             s_axil_rdata,
  output logic [1:0]              s_axil_rresp,
  output logic                    s_axil_rvalid,
  input  logic                    s_axil_rready,

  output logic [AXI_ID_WIDTH-1:0] m_axi_awid,
  output logic [63:0]             m_axi_awaddr,
  output logic [7:0]              m_axi_awlen,
  output logic [2:0]              m_axi_awsize,
  output logic [1:0]              m_axi_awburst,
  output logic                    m_axi_awvalid,
  input  logic                    m_axi_awready,
  output logic [63:0]             m_axi_wdata,
  output logic [7:0]              m_axi_wstrb,
  output logic                    m_axi_wlast,
  output logic                    m_axi_wvalid,
  input  logic                    m_axi_wready,
  input  logic [AXI_ID_WIDTH-1:0] m_axi_bid,
  input  logic [1:0]              m_axi_bresp,
  input  logic                    m_axi_bvalid,
  output logic                    m_axi_bready,

  output logic [AXI_ID_WIDTH-1:0] m_axi_arid,
  output logic [63:0]             m_axi_araddr,
  output logic [7:0]              m_axi_arlen,
  output logic [2:0]              m_axi_arsize,
  output logic [1:0]              m_axi_arburst,
  output logic                    m_axi_arvalid,
  input  logic                    m_axi_arready,
  input  logic [AXI_ID_WIDTH-1:0] m_axi_rid,
  input  logic [63:0]             m_axi_rdata,
  input  logic [1:0]              m_axi_rresp,
  input  logic                    m_axi_rlast,
  input  logic                    m_axi_rvalid,
  output logic                    m_axi_rready,

  output logic                    irq
);
  logic [63:0] programmed_source_address;
  logic [63:0] programmed_destination_address;
  logic [31:0] programmed_length;
  logic [4:0] programmed_burst_beats;
  logic [1:0] requested_outstanding;
  logic programmed_crc_enable;
  logic start_pulse;
  logic abort_pulse;
  logic dma_busy;
  logic completion_event;
  logic error_event;
  logic [15:0] error_event_bits;
  logic [31:0] bytes_transferred;
  logic [31:0] crc_result;

  logic fifo_clear;
  logic fifo_push;
  logic fifo_pop;
  logic [63:0] fifo_write_data;
  logic [63:0] fifo_read_data;
  logic fifo_full;
  logic fifo_empty;
  logic [$clog2(FIFO_DEPTH+1)-1:0] fifo_occupancy;

  logic read_command_valid;
  logic read_command_ready;
  logic [63:0] read_command_address;
  logic [4:0] read_command_beats;
  logic read_active;
  logic read_done;
  logic [1:0] read_response_error;
  logic read_protocol_error;

  logic write_command_valid;
  logic write_command_ready;
  logic [63:0] write_command_address;
  logic [4:0] write_command_beats;
  logic write_active;
  logic write_done;
  logic [1:0] write_response_error;
  logic write_data_accepted;
  logic [63:0] accepted_write_data;

  logic crc_active;
  logic crc_initialize;
  logic [3:0] controller_state;

  assign m_axi_awid = '0;
  assign m_axi_arid = '0;

  dma_regs register_block (
    .clk(aclk),
    .resetn(aresetn),
    .s_axil_awaddr,
    .s_axil_awvalid,
    .s_axil_awready,
    .s_axil_wdata,
    .s_axil_wstrb,
    .s_axil_wvalid,
    .s_axil_wready,
    .s_axil_bresp,
    .s_axil_bvalid,
    .s_axil_bready,
    .s_axil_araddr,
    .s_axil_arvalid,
    .s_axil_arready,
    .s_axil_rdata,
    .s_axil_rresp,
    .s_axil_rvalid,
    .s_axil_rready,
    .source_address(programmed_source_address),
    .destination_address(programmed_destination_address),
    .transfer_length(programmed_length),
    .maximum_burst_beats(programmed_burst_beats),
    .requested_outstanding,
    .crc_enable(programmed_crc_enable),
    .start_pulse,
    .abort_pulse,
    .dma_busy,
    .completion_event,
    .error_event,
    .error_event_bits,
    .bytes_transferred,
    .crc_result,
    .irq
  );

  dma_ctrl_fsm #(.FIFO_DEPTH(FIFO_DEPTH)) controller (
    .clk(aclk),
    .resetn(aresetn),
    .start_pulse,
    .abort_pulse,
    .programmed_source_address,
    .programmed_destination_address,
    .programmed_length,
    .programmed_burst_beats,
    .programmed_crc_enable,
    .dma_busy,
    .completion_event,
    .error_event,
    .error_event_bits,
    .bytes_transferred,
    .crc_active,
    .crc_initialize,
    .fifo_clear,
    .read_command_valid,
    .read_command_ready,
    .read_command_address,
    .read_command_beats,
    .read_done,
    .read_response_error,
    .read_protocol_error,
    .write_command_valid,
    .write_command_ready,
    .write_command_address,
    .write_command_beats,
    .write_done,
    .write_response_error,
    .debug_state(controller_state)
  );

  dma_fifo #(
    .DATA_WIDTH(64),
    .DEPTH(FIFO_DEPTH)
  ) transfer_fifo (
    .clk(aclk),
    .resetn(aresetn),
    .clear(fifo_clear),
    .push(fifo_push),
    .write_data(fifo_write_data),
    .pop(fifo_pop),
    .read_data(fifo_read_data),
    .full(fifo_full),
    .empty(fifo_empty),
    .occupancy(fifo_occupancy)
  );

  dma_read_engine read_engine (
    .clk(aclk),
    .resetn(aresetn),
    .command_valid(read_command_valid),
    .command_ready(read_command_ready),
    .command_address(read_command_address),
    .command_beats(read_command_beats),
    .transfer_active(read_active),
    .transfer_done(read_done),
    .response_error(read_response_error),
    .protocol_error(read_protocol_error),
    .fifo_push,
    .fifo_write_data,
    .fifo_full,
    .m_axi_araddr,
    .m_axi_arlen,
    .m_axi_arsize,
    .m_axi_arburst,
    .m_axi_arvalid,
    .m_axi_arready,
    .m_axi_rdata,
    .m_axi_rresp,
    .m_axi_rlast,
    .m_axi_rvalid,
    .m_axi_rready
  );

  dma_write_engine write_engine (
    .clk(aclk),
    .resetn(aresetn),
    .command_valid(write_command_valid),
    .command_ready(write_command_ready),
    .command_address(write_command_address),
    .command_beats(write_command_beats),
    .transfer_active(write_active),
    .transfer_done(write_done),
    .response_error(write_response_error),
    .fifo_pop,
    .fifo_read_data,
    .fifo_empty,
    .data_accepted(write_data_accepted),
    .accepted_data(accepted_write_data),
    .m_axi_awaddr,
    .m_axi_awlen,
    .m_axi_awsize,
    .m_axi_awburst,
    .m_axi_awvalid,
    .m_axi_awready,
    .m_axi_wdata,
    .m_axi_wstrb,
    .m_axi_wlast,
    .m_axi_wvalid,
    .m_axi_wready,
    .m_axi_bresp,
    .m_axi_bvalid,
    .m_axi_bready
  );

  dma_crc32 crc_engine (
    .clk(aclk),
    .resetn(aresetn),
    .initialize(crc_initialize),
    .enable(crc_active && write_data_accepted),
    .data(accepted_write_data),
    .result(crc_result)
  );

  logic unused_axi_ids;
  always_comb begin
    unused_axi_ids = ^{m_axi_bid, m_axi_rid, requested_outstanding};
  end
endmodule

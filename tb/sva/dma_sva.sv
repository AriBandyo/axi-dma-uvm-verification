module dma_sva #(
  parameter int unsigned FIFO_DEPTH = 16
) (
  input logic        aclk,
  input logic        aresetn,
  input logic        dma_busy,
  input logic        completion_event,
  input logic        error_event,
  input logic        abort_pulse,
  input logic        fifo_push,
  input logic        fifo_pop,
  input logic        fifo_full,
  input logic        fifo_empty,
  input logic [63:0] m_axi_awaddr,
  input logic [7:0]  m_axi_awlen,
  input logic [2:0]  m_axi_awsize,
  input logic        m_axi_awvalid,
  input logic        m_axi_awready,
  input logic [63:0] m_axi_wdata,
  input logic [7:0]  m_axi_wstrb,
  input logic        m_axi_wlast,
  input logic        m_axi_wvalid,
  input logic        m_axi_wready,
  input logic [63:0] m_axi_araddr,
  input logic [7:0]  m_axi_arlen,
  input logic [2:0]  m_axi_arsize,
  input logic        m_axi_arvalid,
  input logic        m_axi_arready
);
  property p_aw_stable_while_stalled;
    @(posedge aclk) disable iff (!aresetn)
      (m_axi_awvalid && !m_axi_awready) |=>
      (m_axi_awvalid && $stable({m_axi_awaddr, m_axi_awlen, m_axi_awsize}));
  endproperty
  a_aw_stable_while_stalled: assert property (p_aw_stable_while_stalled);
  c_aw_stable_while_stalled: cover property (p_aw_stable_while_stalled);

  property p_ar_stable_while_stalled;
    @(posedge aclk) disable iff (!aresetn)
      (m_axi_arvalid && !m_axi_arready) |=>
      (m_axi_arvalid && $stable({m_axi_araddr, m_axi_arlen, m_axi_arsize}));
  endproperty
  a_ar_stable_while_stalled: assert property (p_ar_stable_while_stalled);
  c_ar_stable_while_stalled: cover property (p_ar_stable_while_stalled);

  property p_w_stable_while_stalled;
    @(posedge aclk) disable iff (!aresetn)
      (m_axi_wvalid && !m_axi_wready) |=>
      (m_axi_wvalid && $stable({m_axi_wdata, m_axi_wstrb, m_axi_wlast}));
  endproperty
  a_w_stable_while_stalled: assert property (p_w_stable_while_stalled);
  c_w_stable_while_stalled: cover property (p_w_stable_while_stalled);

  property p_aw_does_not_cross_4kb;
    @(posedge aclk) disable iff (!aresetn)
      (m_axi_awvalid && m_axi_awready) |->
      ((m_axi_awaddr[11:0] + ((m_axi_awlen + 1) << m_axi_awsize)) <= 4096);
  endproperty
  a_aw_does_not_cross_4kb: assert property (p_aw_does_not_cross_4kb);
  c_aw_does_not_cross_4kb: cover property (p_aw_does_not_cross_4kb);

  property p_ar_does_not_cross_4kb;
    @(posedge aclk) disable iff (!aresetn)
      (m_axi_arvalid && m_axi_arready) |->
      ((m_axi_araddr[11:0] + ((m_axi_arlen + 1) << m_axi_arsize)) <= 4096);
  endproperty
  a_ar_does_not_cross_4kb: assert property (p_ar_does_not_cross_4kb);
  c_ar_does_not_cross_4kb: cover property (p_ar_does_not_cross_4kb);

  property p_write_burst_limit;
    @(posedge aclk) disable iff (!aresetn)
      (m_axi_awvalid && m_axi_awready) |-> (m_axi_awlen < 16);
  endproperty
  a_write_burst_limit: assert property (p_write_burst_limit);
  c_write_burst_limit: cover property (p_write_burst_limit);

  property p_read_burst_limit;
    @(posedge aclk) disable iff (!aresetn)
      (m_axi_arvalid && m_axi_arready) |-> (m_axi_arlen < 16);
  endproperty
  a_read_burst_limit: assert property (p_read_burst_limit);
  c_read_burst_limit: cover property (p_read_burst_limit);

  property p_done_not_busy;
    @(posedge aclk) disable iff (!aresetn)
      completion_event |-> !dma_busy;
  endproperty
  a_done_not_busy: assert property (p_done_not_busy);
  c_done_not_busy: cover property (p_done_not_busy);

  property p_done_and_error_exclusive;
    @(posedge aclk) disable iff (!aresetn)
      !(completion_event && error_event);
  endproperty
  a_done_and_error_exclusive: assert property (p_done_and_error_exclusive);
  c_done_and_error_exclusive: cover property (p_done_and_error_exclusive);

  property p_fifo_never_overflows;
    @(posedge aclk) disable iff (!aresetn)
      fifo_full |-> !fifo_push;
  endproperty
  a_fifo_never_overflows: assert property (p_fifo_never_overflows);
  c_fifo_never_overflows: cover property (p_fifo_never_overflows);

  property p_fifo_never_underflows;
    @(posedge aclk) disable iff (!aresetn)
      fifo_empty |-> !fifo_pop;
  endproperty
  a_fifo_never_underflows: assert property (p_fifo_never_underflows);
  c_fifo_never_underflows: cover property (p_fifo_never_underflows);

  property p_abort_bounded;
    @(posedge aclk) disable iff (!aresetn)
      (abort_pulse && dma_busy) |-> ##[1:4096] !dma_busy;
  endproperty
  a_abort_bounded: assert property (p_abort_bounded);
  c_abort_bounded: cover property (p_abort_bounded);

  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      a_reset_clears_busy: assert (!dma_busy)
        else $error("DMA busy remained asserted during reset");
    end
  end
endmodule

bind dma_top dma_sva #(.FIFO_DEPTH(FIFO_DEPTH)) bound_dma_sva (
  .aclk(aclk),
  .aresetn(aresetn),
  .dma_busy(dma_busy),
  .completion_event(completion_event),
  .error_event(error_event),
  .abort_pulse(abort_pulse),
  .fifo_push(fifo_push),
  .fifo_pop(fifo_pop),
  .fifo_full(fifo_full),
  .fifo_empty(fifo_empty),
  .m_axi_awaddr(m_axi_awaddr),
  .m_axi_awlen(m_axi_awlen),
  .m_axi_awsize(m_axi_awsize),
  .m_axi_awvalid(m_axi_awvalid),
  .m_axi_awready(m_axi_awready),
  .m_axi_wdata(m_axi_wdata),
  .m_axi_wstrb(m_axi_wstrb),
  .m_axi_wlast(m_axi_wlast),
  .m_axi_wvalid(m_axi_wvalid),
  .m_axi_wready(m_axi_wready),
  .m_axi_araddr(m_axi_araddr),
  .m_axi_arlen(m_axi_arlen),
  .m_axi_arsize(m_axi_arsize),
  .m_axi_arvalid(m_axi_arvalid),
  .m_axi_arready(m_axi_arready)
);

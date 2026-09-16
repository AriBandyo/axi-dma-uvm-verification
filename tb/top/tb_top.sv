module tb_top;
  import uvm_pkg::*;
  import axil_uvc_pkg::*;
  import axi_mem_uvc_pkg::*;
  import dma_env_pkg::*;
  import dma_seq_pkg::*;
  import dma_test_pkg::*;

  logic aclk = 1'b0;
  logic power_on_resetn = 1'b0;
  wire aresetn;
  logic irq;

  always #5ns aclk = ~aclk;

  reset_ctrl_if reset_control(aclk);
  assign aresetn = power_on_resetn && !reset_control.inject_reset;
  axil_if axil_bus(aclk, aresetn);
  axi_if axi_bus(aclk, aresetn);
  dma_probe_if probe(aclk);

  dma_top dut (
    .aclk,
    .aresetn,
    .s_axil_awaddr(axil_bus.awaddr),
    .s_axil_awvalid(axil_bus.awvalid),
    .s_axil_awready(axil_bus.awready),
    .s_axil_wdata(axil_bus.wdata),
    .s_axil_wstrb(axil_bus.wstrb),
    .s_axil_wvalid(axil_bus.wvalid),
    .s_axil_wready(axil_bus.wready),
    .s_axil_bresp(axil_bus.bresp),
    .s_axil_bvalid(axil_bus.bvalid),
    .s_axil_bready(axil_bus.bready),
    .s_axil_araddr(axil_bus.araddr),
    .s_axil_arvalid(axil_bus.arvalid),
    .s_axil_arready(axil_bus.arready),
    .s_axil_rdata(axil_bus.rdata),
    .s_axil_rresp(axil_bus.rresp),
    .s_axil_rvalid(axil_bus.rvalid),
    .s_axil_rready(axil_bus.rready),
    .m_axi_awid(axi_bus.awid),
    .m_axi_awaddr(axi_bus.awaddr),
    .m_axi_awlen(axi_bus.awlen),
    .m_axi_awsize(axi_bus.awsize),
    .m_axi_awburst(axi_bus.awburst),
    .m_axi_awvalid(axi_bus.awvalid),
    .m_axi_awready(axi_bus.awready),
    .m_axi_wdata(axi_bus.wdata),
    .m_axi_wstrb(axi_bus.wstrb),
    .m_axi_wlast(axi_bus.wlast),
    .m_axi_wvalid(axi_bus.wvalid),
    .m_axi_wready(axi_bus.wready),
    .m_axi_bid(axi_bus.bid),
    .m_axi_bresp(axi_bus.bresp),
    .m_axi_bvalid(axi_bus.bvalid),
    .m_axi_bready(axi_bus.bready),
    .m_axi_arid(axi_bus.arid),
    .m_axi_araddr(axi_bus.araddr),
    .m_axi_arlen(axi_bus.arlen),
    .m_axi_arsize(axi_bus.arsize),
    .m_axi_arburst(axi_bus.arburst),
    .m_axi_arvalid(axi_bus.arvalid),
    .m_axi_arready(axi_bus.arready),
    .m_axi_rid(axi_bus.rid),
    .m_axi_rdata(axi_bus.rdata),
    .m_axi_rresp(axi_bus.rresp),
    .m_axi_rlast(axi_bus.rlast),
    .m_axi_rvalid(axi_bus.rvalid),
    .m_axi_rready(axi_bus.rready),
    .irq
  );

  assign probe.resetn = aresetn;
  assign probe.busy = dut.dma_busy;
  assign probe.controller_state = dut.controller_state;
  assign probe.fifo_occupancy = dut.fifo_occupancy;
  assign probe.read_active = dut.read_active;
  assign probe.write_active = dut.write_active;
  assign probe.completion_event = dut.completion_event;
  assign probe.error_event = dut.error_event;

  initial begin
    reset_control.inject_reset = 1'b0;
    axil_bus.drive_idle();
    repeat (5) @(posedge aclk);
    power_on_resetn = 1'b1;
  end

  initial begin
    uvm_config_db#(virtual axil_if)::set(null, "uvm_test_top", "axil_vif", axil_bus);
    uvm_config_db#(virtual axi_if)::set(null, "uvm_test_top", "axi_vif", axi_bus);
    uvm_config_db#(virtual reset_ctrl_if)::set(null, "uvm_test_top", "reset_vif", reset_control);
    uvm_config_db#(virtual dma_probe_if)::set(null, "uvm_test_top", "probe_vif", probe);
    run_test();
  end
endmodule

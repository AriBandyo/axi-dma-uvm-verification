module reuse_demo_top;
  import uvm_pkg::*;
  import axil_uvc_pkg::*;
  import reuse_demo_pkg::*;
  logic aclk = 1'b0;
  logic aresetn = 1'b0;
  always #5ns aclk = ~aclk;
  axil_if bus(aclk, aresetn);

  axil_scratchpad dut (
    .aclk, .aresetn,
    .s_axil_awaddr(bus.awaddr), .s_axil_awvalid(bus.awvalid), .s_axil_awready(bus.awready),
    .s_axil_wdata(bus.wdata), .s_axil_wstrb(bus.wstrb), .s_axil_wvalid(bus.wvalid), .s_axil_wready(bus.wready),
    .s_axil_bresp(bus.bresp), .s_axil_bvalid(bus.bvalid), .s_axil_bready(bus.bready),
    .s_axil_araddr(bus.araddr), .s_axil_arvalid(bus.arvalid), .s_axil_arready(bus.arready),
    .s_axil_rdata(bus.rdata), .s_axil_rresp(bus.rresp), .s_axil_rvalid(bus.rvalid), .s_axil_rready(bus.rready)
  );

  initial begin
    bus.drive_idle();
    repeat (5) @(posedge aclk);
    aresetn = 1'b1;
  end
  initial begin
    uvm_config_db#(virtual axil_if)::set(null, "uvm_test_top", "axil_vif", bus);
    run_test();
  end
endmodule

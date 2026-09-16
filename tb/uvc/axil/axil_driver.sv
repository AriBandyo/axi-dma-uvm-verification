class axil_driver extends uvm_driver #(axil_item);
  `uvm_component_utils(axil_driver)
  axil_agent_cfg cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(axil_agent_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal("AXIL_CFG", "axil_agent_cfg was not provided")
  endfunction

  task run_phase(uvm_phase phase);
    cfg.vif.drive_idle();
    wait (cfg.vif.aresetn === 1'b1);
    forever begin
      seq_item_port.get_next_item(req);
      if (req.operation == AXIL_WRITE)
        drive_write(req);
      else
        drive_read(req);
      seq_item_port.item_done();
    end
  endtask

  task drive_write(axil_item transaction);
    fork
      begin
        @(posedge cfg.vif.aclk);
        cfg.vif.awaddr <= transaction.address;
        cfg.vif.awvalid <= 1'b1;
        do @(posedge cfg.vif.aclk); while (!cfg.vif.awready);
        cfg.vif.awvalid <= 1'b0;
      end
      begin
        @(posedge cfg.vif.aclk);
        cfg.vif.wdata <= transaction.data;
        cfg.vif.wstrb <= transaction.strobes;
        cfg.vif.wvalid <= 1'b1;
        do @(posedge cfg.vif.aclk); while (!cfg.vif.wready);
        cfg.vif.wvalid <= 1'b0;
      end
    join

    cfg.vif.bready <= 1'b1;
    do @(posedge cfg.vif.aclk); while (!cfg.vif.bvalid);
    transaction.response = cfg.vif.bresp;
    cfg.vif.bready <= 1'b0;
  endtask

  task drive_read(axil_item transaction);
    @(posedge cfg.vif.aclk);
    cfg.vif.araddr <= transaction.address;
    cfg.vif.arvalid <= 1'b1;
    do @(posedge cfg.vif.aclk); while (!cfg.vif.arready);
    cfg.vif.arvalid <= 1'b0;
    cfg.vif.rready <= 1'b1;
    do @(posedge cfg.vif.aclk); while (!cfg.vif.rvalid);
    transaction.data = cfg.vif.rdata;
    transaction.response = cfg.vif.rresp;
    cfg.vif.rready <= 1'b0;
  endtask
endclass

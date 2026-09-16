class axi_mem_monitor extends uvm_monitor;
  `uvm_component_utils(axi_mem_monitor)
  axi_mem_cfg cfg;
  uvm_analysis_port #(axi_transaction) analysis_port;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    analysis_port = new("analysis_port", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(axi_mem_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal("AXI_MEM_CFG", "axi_mem_cfg was not provided")
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      wait (cfg.vif.aresetn === 1'b1);
      fork
        observe_reads();
        observe_writes();
        begin
          @(negedge cfg.vif.aresetn);
        end
      join_any
      disable fork;
    end
  endtask

  task observe_reads();
    forever begin
      axi_transaction transaction;
      do @(posedge cfg.vif.aclk); while (!(cfg.vif.arvalid && cfg.vif.arready));
      transaction = axi_transaction::type_id::create("observed_read");
      transaction.kind = AXI_READ_TRANSFER;
      transaction.address = cfg.vif.araddr;
      transaction.beats = cfg.vif.arlen + 1;
      do begin
        @(posedge cfg.vif.aclk);
        if (cfg.vif.rvalid && cfg.vif.rready) begin
          transaction.payload.push_back(cfg.vif.rdata);
          if (cfg.vif.rresp != 2'b00)
            transaction.response = cfg.vif.rresp;
        end
      end while (!(cfg.vif.rvalid && cfg.vif.rready && cfg.vif.rlast));
      analysis_port.write(transaction);
    end
  endtask

  task observe_writes();
    forever begin
      axi_transaction transaction;
      do @(posedge cfg.vif.aclk); while (!(cfg.vif.awvalid && cfg.vif.awready));
      transaction = axi_transaction::type_id::create("observed_write");
      transaction.kind = AXI_WRITE_TRANSFER;
      transaction.address = cfg.vif.awaddr;
      transaction.beats = cfg.vif.awlen + 1;
      while (transaction.payload.size() < transaction.beats) begin
        @(posedge cfg.vif.aclk);
        if (cfg.vif.wvalid && cfg.vif.wready)
          transaction.payload.push_back(cfg.vif.wdata);
      end
      do @(posedge cfg.vif.aclk); while (!(cfg.vif.bvalid && cfg.vif.bready));
      transaction.response = cfg.vif.bresp;
      analysis_port.write(transaction);
    end
  endtask
endclass

class axil_monitor extends uvm_monitor;
  `uvm_component_utils(axil_monitor)
  axil_agent_cfg cfg;
  uvm_analysis_port #(axil_item) analysis_port;
  bit [7:0] pending_write_address;
  bit [31:0] pending_write_data;
  bit [3:0] pending_write_strobes;
  bit have_write_address;
  bit have_write_data;
  bit [7:0] pending_read_address;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    analysis_port = new("analysis_port", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(axil_agent_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal("AXIL_CFG", "axil_agent_cfg was not provided")
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      @(posedge cfg.vif.aclk);
      if (!cfg.vif.aresetn) begin
        have_write_address = 1'b0;
        have_write_data = 1'b0;
      end else begin
        if (cfg.vif.awvalid && cfg.vif.awready) begin
          pending_write_address = cfg.vif.awaddr;
          have_write_address = 1'b1;
        end
        if (cfg.vif.wvalid && cfg.vif.wready) begin
          pending_write_data = cfg.vif.wdata;
          pending_write_strobes = cfg.vif.wstrb;
          have_write_data = 1'b1;
        end
        if (cfg.vif.arvalid && cfg.vif.arready)
          pending_read_address = cfg.vif.araddr;
        if (cfg.vif.bvalid && cfg.vif.bready && have_write_address && have_write_data) begin
          axil_item observed_write = axil_item::type_id::create("observed_write");
          observed_write.operation = AXIL_WRITE;
          observed_write.address = pending_write_address;
          observed_write.data = pending_write_data;
          observed_write.strobes = pending_write_strobes;
          observed_write.response = cfg.vif.bresp;
          analysis_port.write(observed_write);
          have_write_address = 1'b0;
          have_write_data = 1'b0;
        end
        if (cfg.vif.rvalid && cfg.vif.rready) begin
          axil_item observed_read = axil_item::type_id::create("observed_read");
          observed_read.operation = AXIL_READ;
          observed_read.address = pending_read_address;
          observed_read.data = cfg.vif.rdata;
          observed_read.response = cfg.vif.rresp;
          analysis_port.write(observed_read);
        end
      end
    end
  endtask
endclass

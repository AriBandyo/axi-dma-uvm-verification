class axil_agent extends uvm_agent;
  `uvm_component_utils(axil_agent)
  axil_agent_cfg cfg;
  axil_sequencer sequencer;
  axil_driver driver;
  axil_monitor monitor;
  axil_coverage coverage;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(axil_agent_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal("AXIL_CFG", "axil_agent_cfg was not provided")

    uvm_config_db#(axil_agent_cfg)::set(this, "*", "cfg", cfg);
    monitor = axil_monitor::type_id::create("monitor", this);
    if (cfg.coverage_enable)
      coverage = axil_coverage::type_id::create("coverage", this);
    if (cfg.is_active == UVM_ACTIVE) begin
      sequencer = axil_sequencer::type_id::create("sequencer", this);
      driver = axil_driver::type_id::create("driver", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (cfg.is_active == UVM_ACTIVE)
      driver.seq_item_port.connect(sequencer.seq_item_export);
    if (cfg.coverage_enable)
      monitor.analysis_port.connect(coverage.analysis_export);
  endfunction
endclass

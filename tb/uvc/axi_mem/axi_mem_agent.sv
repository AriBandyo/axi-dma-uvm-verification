class axi_mem_agent extends uvm_agent;
  `uvm_component_utils(axi_mem_agent)
  axi_mem_cfg cfg;
  axi_mem_driver driver;
  axi_mem_monitor monitor;
  axi_mem_coverage coverage;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(axi_mem_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal("AXI_MEM_CFG", "axi_mem_cfg was not provided")
    uvm_config_db#(axi_mem_cfg)::set(this, "*", "cfg", cfg);
    monitor = axi_mem_monitor::type_id::create("monitor", this);
    if (cfg.coverage_enable)
      coverage = axi_mem_coverage::type_id::create("coverage", this);
    if (cfg.is_active == UVM_ACTIVE)
      driver = axi_mem_driver::type_id::create("driver", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (cfg.coverage_enable)
      monitor.analysis_port.connect(coverage.analysis_export);
  endfunction
endclass

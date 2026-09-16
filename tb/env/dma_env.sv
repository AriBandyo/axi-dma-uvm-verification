class dma_env extends uvm_env;
  `uvm_component_utils(dma_env)
  dma_env_cfg cfg;
  axil_agent axil_agent_h;
  axi_mem_agent memory_agent_h;
  dma_scoreboard scoreboard;
  dma_coverage coverage;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(dma_env_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal("DMA_ENV_CFG", "dma_env_cfg was not provided")

    uvm_config_db#(axil_agent_cfg)::set(this, "axil_agent_h", "cfg", cfg.axil_cfg);
    uvm_config_db#(axi_mem_cfg)::set(this, "memory_agent_h", "cfg", cfg.memory_cfg);
    uvm_config_db#(dma_env_cfg)::set(this, "scoreboard", "cfg", cfg);
    uvm_config_db#(dma_env_cfg)::set(this, "coverage", "cfg", cfg);
    axil_agent_h = axil_agent::type_id::create("axil_agent_h", this);
    memory_agent_h = axi_mem_agent::type_id::create("memory_agent_h", this);
    if (cfg.scoreboard_enable)
      scoreboard = dma_scoreboard::type_id::create("scoreboard", this);
    if (cfg.coverage_enable)
      coverage = dma_coverage::type_id::create("coverage", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (cfg.scoreboard_enable) begin
      axil_agent_h.monitor.analysis_port.connect(scoreboard.axil_export);
      memory_agent_h.monitor.analysis_port.connect(scoreboard.axi_export);
    end
    if (cfg.coverage_enable)
      axil_agent_h.monitor.analysis_port.connect(coverage.analysis_export);
  endfunction
endclass

class dma_env_cfg extends uvm_object;
  axil_agent_cfg axil_cfg;
  axi_mem_cfg memory_cfg;
  virtual reset_ctrl_if reset_vif;
  virtual dma_probe_if probe_vif;
  bit scoreboard_enable = 1'b1;
  bit coverage_enable = 1'b1;

  `uvm_object_utils_begin(dma_env_cfg)
    `uvm_field_object(axil_cfg, UVM_REFERENCE)
    `uvm_field_object(memory_cfg, UVM_REFERENCE)
    `uvm_field_int(scoreboard_enable, UVM_DEFAULT)
    `uvm_field_int(coverage_enable, UVM_DEFAULT)
  `uvm_object_utils_end

  function new(string name = "dma_env_cfg");
    super.new(name);
  endfunction
endclass

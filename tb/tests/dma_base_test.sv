class dma_base_test extends uvm_test;
  `uvm_component_utils(dma_base_test)
  dma_env env;
  dma_env_cfg env_cfg;
  axil_agent_cfg axil_cfg;
  axi_mem_cfg memory_cfg;
  virtual axil_if axil_vif;
  virtual axi_if axi_vif;
  virtual reset_ctrl_if reset_vif;
  virtual dma_probe_if probe_vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual axil_if)::get(this, "", "axil_vif", axil_vif))
      `uvm_fatal("VIF", "AXI-Lite virtual interface was not provided")
    if (!uvm_config_db#(virtual axi_if)::get(this, "", "axi_vif", axi_vif))
      `uvm_fatal("VIF", "AXI virtual interface was not provided")
    if (!uvm_config_db#(virtual reset_ctrl_if)::get(this, "", "reset_vif", reset_vif))
      `uvm_fatal("VIF", "reset control interface was not provided")
    if (!uvm_config_db#(virtual dma_probe_if)::get(this, "", "probe_vif", probe_vif))
      `uvm_fatal("VIF", "DMA probe interface was not provided")

    axil_cfg = axil_agent_cfg::type_id::create("axil_cfg");
    axil_cfg.vif = axil_vif;
    memory_cfg = axi_mem_cfg::type_id::create("memory_cfg");
    memory_cfg.vif = axi_vif;
    env_cfg = dma_env_cfg::type_id::create("env_cfg");
    env_cfg.axil_cfg = axil_cfg;
    env_cfg.memory_cfg = memory_cfg;
    env_cfg.reset_vif = reset_vif;
    env_cfg.probe_vif = probe_vif;
    configure_environment();
    uvm_config_db#(dma_env_cfg)::set(this, "env", "cfg", env_cfg);
    env = dma_env::type_id::create("env", this);
  endfunction

  virtual function void configure_environment();
  endfunction

  function dma_descriptor make_descriptor(
    bit [63:0] source_address,
    bit [63:0] destination_address,
    int unsigned length_bytes,
    int unsigned burst_beats = 16,
    bit crc_enable = 1'b1
  );
    dma_descriptor descriptor = dma_descriptor::type_id::create("descriptor");
    descriptor.source_address = source_address;
    descriptor.destination_address = destination_address;
    descriptor.length_bytes = length_bytes;
    descriptor.burst_beats = burst_beats;
    descriptor.maximum_outstanding = 1;
    descriptor.crc_enable = crc_enable;
    return descriptor;
  endfunction

  task run_descriptor(
    dma_descriptor descriptor,
    bit expect_error = 1'b0,
    bit initialize_source = 1'b1
  );
    dma_program_sequence sequence_h = dma_program_sequence::type_id::create("program_sequence");
    if (initialize_source)
      memory_cfg.load_incrementing(descriptor.source_address, descriptor.length_bytes, 8'h31);
    sequence_h.descriptor = descriptor;
    sequence_h.start(env.axil_agent_h.sequencer);
    if (expect_error && !sequence_h.final_status[2])
      `uvm_error("EXPECTED_ERROR", "descriptor completed without the expected error")
    if (!expect_error && !sequence_h.final_status[1])
      `uvm_error("EXPECTED_DONE", $sformatf("descriptor failed status=0x%08x error=0x%08x", sequence_h.final_status, sequence_h.final_error_status))
  endtask
endclass

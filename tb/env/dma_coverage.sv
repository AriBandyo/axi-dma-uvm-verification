class dma_coverage extends uvm_subscriber #(axil_item);
  `uvm_component_utils(dma_coverage)
  dma_env_cfg cfg;
  bit [31:0] sampled_length;
  bit [4:0] sampled_burst_beats;
  bit sampled_crc_enable;
  bit [2:0] sampled_termination;
  bit sampled_alignment_error;
  bit [3:0] sampled_fsm_state;

  covergroup descriptor_coverage;
    option.per_instance = 1;
    cp_length: coverpoint sampled_length {
      bins length_tiny = {[8:64]};
      bins length_small = {[65:256]};
      bins length_medium = {[257:1024]};
      bins length_page = {[1025:4096]};
      bins length_large = {[4097:16384]};
      bins length_very_large = {[16385:16777215]};
    }
    cp_burst: coverpoint sampled_burst_beats { bins legal[] = {1, 2, 4, 8, 16}; }
    cp_crc: coverpoint sampled_crc_enable;
    length_by_burst: cross cp_length, cp_burst;
  endgroup

  covergroup termination_coverage;
    option.per_instance = 1;
    cp_termination: coverpoint sampled_termination {
      bins done = {1}; bins error = {2}; bins abort = {3}; bins reset = {4};
    }
    cp_state: coverpoint sampled_fsm_state { bins states[] = {[0:9]}; }
    termination_by_state: cross cp_termination, cp_state;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    descriptor_coverage = new();
    termination_coverage = new();
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(dma_env_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal("DMA_ENV_CFG", "dma_env_cfg was not provided")
  endfunction

  function void write(axil_item transaction);
    static bit [31:0] observed_length;
    static bit [31:0] observed_config = 32'h0000_0110;
    if (transaction.operation == AXIL_WRITE) begin
      if (transaction.address == 8'h18)
        observed_length = transaction.data;
      if (transaction.address == 8'h1C)
        observed_config = transaction.data;
      if (transaction.address == 8'h00 && transaction.data[0]) begin
        sampled_length = observed_length;
        sampled_burst_beats = observed_config[4:0];
        sampled_crc_enable = observed_config[12];
        descriptor_coverage.sample();
      end
      if (transaction.address == 8'h00 && transaction.data[1]) begin
        sampled_termination = 3;
        sampled_fsm_state = cfg.probe_vif.controller_state;
        termination_coverage.sample();
      end
    end else if (transaction.address == 8'h04) begin
      if (transaction.data[1]) sampled_termination = 1;
      else if (transaction.data[2]) sampled_termination = 2;
      else return;
      sampled_fsm_state = cfg.probe_vif.controller_state;
      termination_coverage.sample();
    end
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      @(negedge cfg.probe_vif.resetn);
      sampled_termination = 4;
      sampled_fsm_state = cfg.probe_vif.controller_state;
      termination_coverage.sample();
    end
  endtask
endclass

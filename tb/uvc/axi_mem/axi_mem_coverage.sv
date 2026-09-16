class axi_mem_coverage extends uvm_subscriber #(axi_transaction);
  `uvm_component_utils(axi_mem_coverage)
  axi_mem_cfg cfg;
  int unsigned sampled_beats;
  bit sampled_crossing;
  bit [1:0] sampled_response;
  axi_transfer_kind_e sampled_kind;

  covergroup transfer_coverage;
    option.per_instance = 1;
    cp_beats: coverpoint sampled_beats { bins legal[] = {1, 2, 4, 8, 16}; }
    cp_crossing: coverpoint sampled_crossing;
    cp_response: coverpoint sampled_response { bins okay = {0}; bins slverr = {2}; bins decerr = {3}; }
    cp_kind: coverpoint sampled_kind;
    kind_by_response: cross cp_kind, cp_response;
    burst_by_crossing: cross cp_beats, cp_crossing;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    transfer_coverage = new();
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(axi_mem_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal("AXI_MEM_CFG", "axi_mem_cfg was not provided")
  endfunction

  function void write(axi_transaction transaction);
    if (cfg.coverage_enable) begin
      sampled_beats = transaction.beats;
      sampled_crossing = ((transaction.address[11:0] + transaction.beats*8) > 4096);
      sampled_response = transaction.response;
      sampled_kind = transaction.kind;
      transfer_coverage.sample();
    end
  endfunction
endclass

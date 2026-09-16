class axil_coverage extends uvm_subscriber #(axil_item);
  `uvm_component_utils(axil_coverage)
  axil_agent_cfg cfg;
  bit [7:0] sampled_address;
  axil_operation_e sampled_operation;

  covergroup access_coverage;
    option.per_instance = 1;
    cp_operation: coverpoint sampled_operation;
    cp_address: coverpoint sampled_address {
      bins implemented_registers[] = {8'h00, 8'h04, 8'h08, 8'h0C, 8'h10, 8'h14,
                                      8'h18, 8'h1C, 8'h20, 8'h24, 8'h28, 8'h2C};
      bins unmapped = default;
    }
    operation_by_address: cross cp_operation, cp_address;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    access_coverage = new();
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(axil_agent_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal("AXIL_CFG", "axil_agent_cfg was not provided")
  endfunction

  function void write(axil_item transaction);
    if (cfg.coverage_enable) begin
      sampled_address = transaction.address;
      sampled_operation = transaction.operation;
      access_coverage.sample();
    end
  endfunction
endclass

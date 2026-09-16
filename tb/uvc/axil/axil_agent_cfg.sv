class axil_agent_cfg extends uvm_object;
  virtual axil_if vif;
  uvm_active_passive_enum is_active = UVM_ACTIVE;
  bit coverage_enable = 1'b1;
  int unsigned address_width = 8;
  int unsigned data_width = 32;

  `uvm_object_utils_begin(axil_agent_cfg)
    `uvm_field_enum(uvm_active_passive_enum, is_active, UVM_DEFAULT)
    `uvm_field_int(coverage_enable, UVM_DEFAULT)
    `uvm_field_int(address_width, UVM_DEC)
    `uvm_field_int(data_width, UVM_DEC)
  `uvm_object_utils_end

  function new(string name = "axil_agent_cfg");
    super.new(name);
  endfunction
endclass

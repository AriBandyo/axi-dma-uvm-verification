class axi_mem_cfg extends uvm_object;
  virtual axi_if vif;
  uvm_active_passive_enum is_active = UVM_ACTIVE;
  bit coverage_enable = 1'b1;
  int unsigned minimum_latency = 0;
  int unsigned maximum_latency = 3;
  int unsigned ready_gap_percent = 0;
  int unsigned slverr_percent = 0;
  int unsigned decerr_percent = 0;
  byte unsigned memory[longint unsigned];

  `uvm_object_utils_begin(axi_mem_cfg)
    `uvm_field_enum(uvm_active_passive_enum, is_active, UVM_DEFAULT)
    `uvm_field_int(coverage_enable, UVM_DEFAULT)
    `uvm_field_int(minimum_latency, UVM_DEC)
    `uvm_field_int(maximum_latency, UVM_DEC)
    `uvm_field_int(ready_gap_percent, UVM_DEC)
    `uvm_field_int(slverr_percent, UVM_DEC)
    `uvm_field_int(decerr_percent, UVM_DEC)
  `uvm_object_utils_end

  function new(string name = "axi_mem_cfg");
    super.new(name);
  endfunction

  function byte unsigned read_byte(longint unsigned address);
    if (memory.exists(address))
      return memory[address];
    return 8'h00;
  endfunction

  function void write_byte(longint unsigned address, byte unsigned value);
    memory[address] = value;
  endfunction

  function void load_incrementing(longint unsigned address, int unsigned length, byte unsigned seed_value);
    for (int unsigned index = 0; index < length; index++)
      memory[address + index] = seed_value + index;
  endfunction
endclass

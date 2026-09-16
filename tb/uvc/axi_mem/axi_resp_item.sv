class axi_resp_item extends uvm_object;
  `uvm_object_utils(axi_resp_item)

  function new(string name = "axi_resp_item");
    super.new(name);
  endfunction

  virtual function bit [1:0] select_response(axi_mem_cfg cfg);
    int unsigned selection = $urandom_range(99, 0);
    if (selection < cfg.decerr_percent)
      return 2'b11;
    if (selection < cfg.decerr_percent + cfg.slverr_percent)
      return 2'b10;
    return 2'b00;
  endfunction
endclass

class axi_err_resp_item extends axi_resp_item;
  `uvm_object_utils(axi_err_resp_item)

  function new(string name = "axi_err_resp_item");
    super.new(name);
  endfunction

  virtual function bit [1:0] select_response(axi_mem_cfg cfg);
    return ($urandom_range(1, 0) == 0) ? 2'b10 : 2'b11;
  endfunction
endclass

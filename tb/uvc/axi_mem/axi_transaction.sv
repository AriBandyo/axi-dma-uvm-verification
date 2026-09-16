typedef enum logic {AXI_READ_TRANSFER, AXI_WRITE_TRANSFER} axi_transfer_kind_e;

class axi_transaction extends uvm_sequence_item;
  axi_transfer_kind_e kind;
  bit [63:0] address;
  int unsigned beats;
  bit [1:0] response;
  bit [63:0] payload[$];

  `uvm_object_utils_begin(axi_transaction)
    `uvm_field_enum(axi_transfer_kind_e, kind, UVM_DEFAULT)
    `uvm_field_int(address, UVM_HEX)
    `uvm_field_int(beats, UVM_DEC)
    `uvm_field_int(response, UVM_HEX)
    `uvm_field_queue_int(payload, UVM_HEX)
  `uvm_object_utils_end

  function new(string name = "axi_transaction");
    super.new(name);
  endfunction
endclass

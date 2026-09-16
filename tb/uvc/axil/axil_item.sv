typedef enum logic {AXIL_READ, AXIL_WRITE} axil_operation_e;

class axil_item extends uvm_sequence_item;
  rand axil_operation_e operation;
  rand bit [7:0] address;
  rand bit [31:0] data;
  rand bit [3:0] strobes;
  bit [1:0] response;

  constraint legal_alignment { address[1:0] == 2'b00; }

  `uvm_object_utils_begin(axil_item)
    `uvm_field_enum(axil_operation_e, operation, UVM_DEFAULT)
    `uvm_field_int(address, UVM_HEX)
    `uvm_field_int(data, UVM_HEX)
    `uvm_field_int(strobes, UVM_HEX)
    `uvm_field_int(response, UVM_HEX | UVM_NOCOMPARE)
  `uvm_object_utils_end

  function new(string name = "axil_item");
    super.new(name);
    strobes = 4'hF;
  endfunction
endclass

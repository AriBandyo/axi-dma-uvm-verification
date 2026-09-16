class axil_base_sequence extends uvm_sequence #(axil_item);
  `uvm_object_utils(axil_base_sequence)

  function new(string name = "axil_base_sequence");
    super.new(name);
  endfunction

  task automatic write_register(bit [7:0] address, bit [31:0] data, bit [3:0] strobes = 4'hF);
    axil_item transaction = axil_item::type_id::create("write_transaction");
    start_item(transaction);
    transaction.operation = AXIL_WRITE;
    transaction.address = address;
    transaction.data = data;
    transaction.strobes = strobes;
    finish_item(transaction);
    if (transaction.response != 2'b00)
      `uvm_error("AXIL_WRITE", $sformatf("write failed address=0x%02x response=0x%x", address, transaction.response))
  endtask

  task automatic read_register(bit [7:0] address, output bit [31:0] data);
    axil_item transaction = axil_item::type_id::create("read_transaction");
    start_item(transaction);
    transaction.operation = AXIL_READ;
    transaction.address = address;
    transaction.data = '0;
    transaction.strobes = '0;
    finish_item(transaction);
    data = transaction.data;
    if (transaction.response != 2'b00)
      `uvm_error("AXIL_READ", $sformatf("read failed address=0x%02x response=0x%x", address, transaction.response))
  endtask
endclass

class axil_register_smoke_sequence extends axil_base_sequence;
  `uvm_object_utils(axil_register_smoke_sequence)
  bit [31:0] source_low_readback;
  bit [31:0] version_readback;

  function new(string name = "axil_register_smoke_sequence");
    super.new(name);
  endfunction

  task body();
    write_register(8'h08, 32'h89AB_CDEF);
    read_register(8'h08, source_low_readback);
    read_register(8'h2C, version_readback);
  endtask
endclass

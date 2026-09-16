class dma_descriptor extends uvm_sequence_item;
  rand bit [63:0] source_address;
  rand bit [63:0] destination_address;
  rand int unsigned length_bytes;
  rand int unsigned burst_beats;
  rand int unsigned maximum_outstanding;
  rand bit crc_enable;

  constraint legal_descriptor {
    source_address inside {[64'h0000_0000_0000_1000:64'h0000_0000_0007_FFF8]};
    destination_address inside {[64'h0000_0000_0010_0000:64'h0000_0000_0017_FFF8]};
    source_address[2:0] == 0;
    destination_address[2:0] == 0;
    length_bytes inside {[8:65536]};
    length_bytes % 8 == 0;
    burst_beats inside {1, 2, 4, 8, 16};
    maximum_outstanding == 1;
  }

  constraint length_bias {
    length_bytes dist {
      [8:64] :/ 20,
      [72:4096] :/ 40,
      [4104:65536] :/ 40
    };
  }

  `uvm_object_utils_begin(dma_descriptor)
    `uvm_field_int(source_address, UVM_HEX)
    `uvm_field_int(destination_address, UVM_HEX)
    `uvm_field_int(length_bytes, UVM_DEC)
    `uvm_field_int(burst_beats, UVM_DEC)
    `uvm_field_int(maximum_outstanding, UVM_DEC)
    `uvm_field_int(crc_enable, UVM_DEFAULT)
  `uvm_object_utils_end

  function new(string name = "dma_descriptor");
    super.new(name);
  endfunction
endclass

class dma_corner_descriptor extends dma_descriptor;
  `uvm_object_utils(dma_corner_descriptor)

  constraint boundary_bias {
    source_address[11:0] inside {[12'hF80:12'hFF8]};
    destination_address[11:0] inside {[12'hF80:12'hFF8]};
    length_bytes inside {[128:8192]};
  }

  function new(string name = "dma_corner_descriptor");
    super.new(name);
  endfunction
endclass

class dma_program_sequence extends axil_base_sequence;
  `uvm_object_utils(dma_program_sequence)
  dma_descriptor descriptor;
  bit allow_quiet_termination;
  bit [31:0] final_status;
  bit [31:0] final_error_status;
  bit [31:0] final_bytes_transferred;
  bit [31:0] final_crc;

  function new(string name = "dma_program_sequence");
    super.new(name);
  endfunction

  function automatic bit [1:0] outstanding_encoding(int unsigned outstanding);
    case (outstanding)
      2: return 2'd1;
      4: return 2'd2;
      default: return 2'd0;
    endcase
  endfunction

  task body();
    bit [31:0] configuration;
    bit saw_busy;
    if (descriptor == null) begin
      descriptor = dma_descriptor::type_id::create("descriptor");
      if (!descriptor.randomize())
        `uvm_fatal("RANDOMIZE", "failed to randomize DMA descriptor")
    end

    configuration = descriptor.burst_beats[4:0];
    configuration[8] = 1'b1;
    configuration[10:9] = outstanding_encoding(descriptor.maximum_outstanding);
    configuration[12] = descriptor.crc_enable;

    write_register(8'h08, descriptor.source_address[31:0]);
    write_register(8'h0C, descriptor.source_address[63:32]);
    write_register(8'h10, descriptor.destination_address[31:0]);
    write_register(8'h14, descriptor.destination_address[63:32]);
    write_register(8'h18, descriptor.length_bytes);
    write_register(8'h1C, configuration);
    write_register(8'h00, 32'h0000_0001);

    for (int unsigned poll = 0; poll < 100000; poll++) begin
      read_register(8'h04, final_status);
      saw_busy |= final_status[0];
      if (final_status[1] || final_status[2])
        break;
      if (allow_quiet_termination && saw_busy && !final_status[0])
        break;
      if (poll == 99999)
        `uvm_fatal("DMA_TIMEOUT", "DMA did not terminate within the polling budget")
    end

    read_register(8'h20, final_error_status);
    read_register(8'h24, final_bytes_transferred);
    if (final_status[1] && descriptor.crc_enable)
      read_register(8'h28, final_crc);
  endtask
endclass

class dma_start_sequence extends axil_base_sequence;
  `uvm_object_utils(dma_start_sequence)
  dma_descriptor descriptor;

  function new(string name = "dma_start_sequence");
    super.new(name);
  endfunction

  function automatic bit [1:0] outstanding_encoding(int unsigned outstanding);
    case (outstanding)
      2: return 2'd1;
      4: return 2'd2;
      default: return 2'd0;
    endcase
  endfunction

  task body();
    bit [31:0] configuration;
    if (descriptor == null)
      `uvm_fatal("DESCRIPTOR", "dma_start_sequence requires a descriptor")
    configuration = descriptor.burst_beats[4:0];
    configuration[8] = 1'b1;
    configuration[10:9] = outstanding_encoding(descriptor.maximum_outstanding);
    configuration[12] = descriptor.crc_enable;
    write_register(8'h08, descriptor.source_address[31:0]);
    write_register(8'h0C, descriptor.source_address[63:32]);
    write_register(8'h10, descriptor.destination_address[31:0]);
    write_register(8'h14, descriptor.destination_address[63:32]);
    write_register(8'h18, descriptor.length_bytes);
    write_register(8'h1C, configuration);
    write_register(8'h00, 32'h0000_0001);
  endtask
endclass

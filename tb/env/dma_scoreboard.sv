`uvm_analysis_imp_decl(_axil)
`uvm_analysis_imp_decl(_axi)

class dma_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(dma_scoreboard)
  dma_env_cfg cfg;
  uvm_analysis_imp_axil #(axil_item, dma_scoreboard) axil_export;
  uvm_analysis_imp_axi #(axi_transaction, dma_scoreboard) axi_export;

  bit [63:0] programmed_source_address;
  bit [63:0] programmed_destination_address;
  bit [31:0] programmed_length;
  bit [31:0] programmed_config = 32'h0000_0110;
  byte unsigned expected_destination[];
  byte unsigned guard_before[16];
  byte unsigned guard_after[16];
  int unsigned expected_crc;
  int unsigned observed_write_bursts;
  int unsigned current_seed;
  bit expectation_valid;
  bit crc_check_pending;
  bit transfer_terminated_with_error;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    axil_export = new("axil_export", this);
    axi_export = new("axi_export", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(dma_env_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal("DMA_ENV_CFG", "dma_env_cfg was not provided")
    void'($value$plusargs("VERIDMA_SEED=%d", current_seed));
  endfunction

  function automatic bit [31:0] apply_strobes(
    input bit [31:0] previous_value,
    input bit [31:0] write_value,
    input bit [3:0] strobes
  );
    bit [31:0] result = previous_value;
    for (int lane = 0; lane < 4; lane++)
      if (strobes[lane])
        result[lane*8 +: 8] = write_value[lane*8 +: 8];
    return result;
  endfunction

  function void write_axil(axil_item transaction);
    if (transaction.operation == AXIL_WRITE) begin
      unique case (transaction.address)
        8'h08: programmed_source_address[31:0] = apply_strobes(programmed_source_address[31:0], transaction.data, transaction.strobes);
        8'h0C: programmed_source_address[63:32] = apply_strobes(programmed_source_address[63:32], transaction.data, transaction.strobes);
        8'h10: programmed_destination_address[31:0] = apply_strobes(programmed_destination_address[31:0], transaction.data, transaction.strobes);
        8'h14: programmed_destination_address[63:32] = apply_strobes(programmed_destination_address[63:32], transaction.data, transaction.strobes);
        8'h18: programmed_length = apply_strobes(programmed_length, transaction.data, transaction.strobes);
        8'h1C: programmed_config = apply_strobes(programmed_config, transaction.data, transaction.strobes);
        8'h00: if (transaction.data[0]) build_expectation();
        default: begin end
      endcase
    end else if (transaction.address == 8'h04) begin
      if (transaction.data[1])
        compare_completed_transfer();
      if (transaction.data[2])
        transfer_terminated_with_error = 1'b1;
    end else if (transaction.address == 8'h24 && transfer_terminated_with_error) begin
      compare_partial_transfer(transaction.data);
      transfer_terminated_with_error = 1'b0;
    end else if (transaction.address == 8'h28 && crc_check_pending) begin
      if (transaction.data !== expected_crc)
        `uvm_error("SCOREBOARD_CRC", $sformatf("CRC mismatch expected=0x%08x actual=0x%08x seed=%0d", expected_crc, transaction.data, current_seed))
      crc_check_pending = 1'b0;
    end
  endfunction

  function void write_axi(axi_transaction transaction);
    if (transaction.kind == AXI_WRITE_TRANSFER && transaction.response == 2'b00)
      observed_write_bursts++;
  endfunction

  function void build_expectation();
    byte unsigned source_snapshot[];
    longint unsigned source_base = programmed_source_address;
    longint unsigned destination_base = programmed_destination_address;

    expectation_valid = 1'b0;
    crc_check_pending = 1'b0;
    observed_write_bursts = 0;
    transfer_terminated_with_error = 1'b0;
    if (programmed_length == 0 || programmed_length[2:0] != 0 ||
        programmed_source_address[2:0] != 0 || programmed_destination_address[2:0] != 0)
      return;
    if ((programmed_source_address < programmed_destination_address + programmed_length) &&
        (programmed_destination_address < programmed_source_address + programmed_length))
      return;

    source_snapshot = new[programmed_length];
    expected_destination = new[programmed_length];
    for (int unsigned index = 0; index < programmed_length; index++)
      source_snapshot[index] = cfg.memory_cfg.read_byte(source_base + index);
    for (int unsigned index = 0; index < 16; index++) begin
      guard_before[index] = cfg.memory_cfg.read_byte(destination_base - 16 + index);
      guard_after[index] = cfg.memory_cfg.read_byte(destination_base + programmed_length + index);
    end
    dma_ref_pkg::dma_ref_transfer(source_snapshot, expected_destination,
                                  programmed_length, programmed_config[12], expected_crc);
    expectation_valid = 1'b1;
    crc_check_pending = programmed_config[12];
  endfunction

  function void compare_completed_transfer();
    if (!expectation_valid)
      return;
    compare_bytes(programmed_length);
    compare_guards();
    expectation_valid = 1'b0;
  endfunction

  function void compare_partial_transfer(int unsigned committed_bytes);
    if (!expectation_valid)
      return;
    if (committed_bytes > programmed_length) begin
      `uvm_error("SCOREBOARD_PROGRESS", $sformatf("BYTES_XFERRED=%0d exceeds LENGTH=%0d seed=%0d", committed_bytes, programmed_length, current_seed))
      return;
    end
    compare_bytes(committed_bytes);
    compare_guards();
    expectation_valid = 1'b0;
  endfunction

  function void compare_bytes(int unsigned byte_count);
    for (int unsigned index = 0; index < byte_count; index++) begin
      byte unsigned actual = cfg.memory_cfg.read_byte(programmed_destination_address + index);
      if (actual !== expected_destination[index]) begin
        `uvm_error("SCOREBOARD_DATA", $sformatf(
          "destination mismatch address=0x%016x expected=0x%02x actual=0x%02x src=0x%016x dst=0x%016x length=%0d seed=%0d",
          programmed_destination_address + index, expected_destination[index], actual,
          programmed_source_address, programmed_destination_address, programmed_length, current_seed))
        return;
      end
    end
  endfunction

  function void compare_guards();
    for (int unsigned index = 0; index < 16; index++) begin
      if (cfg.memory_cfg.read_byte(programmed_destination_address - 16 + index) !== guard_before[index])
        `uvm_error("SCOREBOARD_GUARD", $sformatf("write before destination window at offset %0d seed=%0d", index, current_seed))
      if (cfg.memory_cfg.read_byte(programmed_destination_address + programmed_length + index) !== guard_after[index])
        `uvm_error("SCOREBOARD_GUARD", $sformatf("write after destination window at offset %0d seed=%0d", index, current_seed))
    end
  endfunction
endclass

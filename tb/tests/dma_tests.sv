class dma_smoke_test extends dma_base_test;
  `uvm_component_utils(dma_smoke_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    run_descriptor(make_descriptor(64'h0000_1000, 64'h0010_0000, 4096, 16, 1'b1));
    phase.drop_objection(this);
  endtask
endclass

class dma_register_test extends dma_base_test;
  `uvm_component_utils(dma_register_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  task run_phase(uvm_phase phase);
    axil_register_smoke_sequence sequence_h = axil_register_smoke_sequence::type_id::create("register_sequence");
    phase.raise_objection(this);
    sequence_h.start(env.axil_agent_h.sequencer);
    if (sequence_h.source_low_readback !== 32'h89AB_CDEF) `uvm_error("REGISTER", "source low register readback mismatch")
    if (sequence_h.version_readback !== 32'h0001_0000) `uvm_error("REGISTER", "IP_VERSION mismatch")
    phase.drop_objection(this);
  endtask
endclass

class dma_random_test extends dma_base_test;
  `uvm_component_utils(dma_random_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  task run_phase(uvm_phase phase);
    int unsigned iterations = 20;
    void'($value$plusargs("ITERATIONS=%d", iterations));
    phase.raise_objection(this);
    repeat (iterations) begin
      dma_descriptor descriptor = dma_descriptor::type_id::create("random_descriptor");
      if (!descriptor.randomize()) `uvm_fatal("RANDOMIZE", "descriptor randomization failed")
      run_descriptor(descriptor);
    end
    phase.drop_objection(this);
  endtask
endclass

class dma_4kb_test extends dma_random_test;
  `uvm_component_utils(dma_4kb_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void build_phase(uvm_phase phase);
    dma_descriptor::type_id::set_type_override(dma_corner_descriptor::get_type());
    super.build_phase(phase);
  endfunction
endclass

class dma_illegal_test extends dma_base_test;
  `uvm_component_utils(dma_illegal_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    run_descriptor(make_descriptor(64'h1000, 64'h100000, 0), 1'b1);
    run_descriptor(make_descriptor(64'h1004, 64'h100000, 64), 1'b1);
    run_descriptor(make_descriptor(64'h1000, 64'h1010, 128), 1'b1);
    phase.drop_objection(this);
  endtask
endclass

class dma_error_test extends dma_base_test;
  `uvm_component_utils(dma_error_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void build_phase(uvm_phase phase);
    axi_mem_driver::type_id::set_type_override(axi_err_mem_driver::get_type());
    axi_resp_item::type_id::set_inst_override(axi_err_resp_item::get_type(), "*.memory_agent_h.driver.*");
    super.build_phase(phase);
  endfunction
  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    run_descriptor(make_descriptor(64'h2000, 64'h110000, 1024), 1'b1);
    phase.drop_objection(this);
  endtask
endclass

class dma_abort_test extends dma_base_test;
  `uvm_component_utils(dma_abort_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  task run_phase(uvm_phase phase);
    dma_program_sequence program_sequence = dma_program_sequence::type_id::create("program_sequence");
    dma_abort_sequence abort_sequence = dma_abort_sequence::type_id::create("abort_sequence");
    dma_descriptor descriptor = make_descriptor(64'h3000, 64'h120000, 65536, 1, 1'b0);
    phase.raise_objection(this);
    memory_cfg.load_incrementing(descriptor.source_address, descriptor.length_bytes, 8'h42);
    program_sequence.descriptor = descriptor;
    abort_sequence.probe_vif = probe_vif;
    fork
      program_sequence.start(env.axil_agent_h.sequencer);
      abort_sequence.start(env.axil_agent_h.sequencer);
    join
    if (!program_sequence.final_error_status[6])
      `uvm_error("ABORT", "ABORTED status bit was not set")
    phase.drop_objection(this);
  endtask
endclass

class dma_reset_test extends dma_base_test;
  `uvm_component_utils(dma_reset_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  task run_phase(uvm_phase phase);
    dma_start_sequence start_sequence = dma_start_sequence::type_id::create("start_sequence");
    dma_reset_sequence reset_sequence = dma_reset_sequence::type_id::create("reset_sequence");
    dma_descriptor descriptor = make_descriptor(64'h4000, 64'h130000, 65536, 1, 1'b0);
    phase.raise_objection(this);
    memory_cfg.load_incrementing(descriptor.source_address, descriptor.length_bytes, 8'h53);
    start_sequence.descriptor = descriptor;
    start_sequence.start(env.axil_agent_h.sequencer);
    wait (probe_vif.busy);
    reset_sequence.reset_vif = reset_vif;
    if (!reset_sequence.randomize()) `uvm_fatal("RANDOMIZE", "reset timing randomization failed")
    reset_sequence.start(null);
    repeat (4) @(posedge probe_vif.aclk);
    if (probe_vif.busy || probe_vif.fifo_occupancy != 0 ||
        axi_vif.awvalid || axi_vif.arvalid || axi_vif.wvalid)
      `uvm_error("RESET_RECOVERY", "DMA did not return to a clean idle state after reset")
    run_descriptor(make_descriptor(64'h8000, 64'h140000, 512, 8, 1'b1));
    phase.drop_objection(this);
  endtask
endclass

class dma_ordering_test extends dma_base_test;
  `uvm_component_utils(dma_ordering_test)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  task run_phase(uvm_phase phase);
    dma_descriptor first = make_descriptor(64'h5000, 64'h150000, 2048, 8, 1'b0);
    dma_descriptor second = make_descriptor(64'h150000, 64'h160000, 2048, 8, 1'b0);
    phase.raise_objection(this);
    run_descriptor(first);
    run_descriptor(second, 1'b0, 1'b0);
    phase.drop_objection(this);
  endtask
endclass

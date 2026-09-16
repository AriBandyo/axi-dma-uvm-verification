class dma_abort_sequence extends axil_base_sequence;
  `uvm_object_utils(dma_abort_sequence)
  int unsigned delay_cycles = 20;
  virtual dma_probe_if probe_vif;

  function new(string name = "dma_abort_sequence");
    super.new(name);
  endfunction

  task body();
    repeat (delay_cycles) @(posedge probe_vif.aclk);
    write_register(8'h00, 32'h0000_0002);
  endtask
endclass

class dma_reset_sequence extends uvm_sequence #(uvm_sequence_item);
  `uvm_object_utils(dma_reset_sequence)
  rand int unsigned reset_delay_cycles;
  rand int unsigned reset_width_cycles;
  virtual reset_ctrl_if reset_vif;

  constraint reset_timing {
    reset_delay_cycles inside {[5:100]};
    reset_width_cycles inside {[1:8]};
  }

  function new(string name = "dma_reset_sequence");
    super.new(name);
  endfunction

  task body();
    repeat (reset_delay_cycles) @(posedge reset_vif.aclk);
    reset_vif.assert_for_cycles(reset_width_cycles);
  endtask
endclass

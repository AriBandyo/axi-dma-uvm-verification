package reuse_demo_pkg;
  import uvm_pkg::*;
  import axil_uvc_pkg::*;
  `include "uvm_macros.svh"

  class scratchpad_sequence extends uvm_sequence #(axil_item);
    `uvm_object_utils(scratchpad_sequence)
    function new(string name = "scratchpad_sequence"); super.new(name); endfunction
    task body();
      for (int unsigned index = 0; index < 4; index++) begin
        axil_item write_item = axil_item::type_id::create($sformatf("write_%0d", index));
        start_item(write_item);
        write_item.operation = AXIL_WRITE; write_item.address = index * 4;
        write_item.data = 32'hA5A5_0000 + index; write_item.strobes = 4'hF;
        finish_item(write_item);
      end
      for (int unsigned index = 0; index < 4; index++) begin
        axil_item read_item = axil_item::type_id::create($sformatf("read_%0d", index));
        start_item(read_item);
        read_item.operation = AXIL_READ; read_item.address = index * 4;
        finish_item(read_item);
        if (read_item.data !== (32'hA5A5_0000 + index))
          `uvm_error("REUSE", $sformatf("scratchpad register %0d mismatch", index))
      end
    endtask
  endclass

  class axil_reuse_test extends uvm_test;
    `uvm_component_utils(axil_reuse_test)
    axil_agent agent;
    axil_agent_cfg cfg;
    virtual axil_if vif;
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual axil_if)::get(this, "", "axil_vif", vif))
        `uvm_fatal("VIF", "AXI-Lite interface missing")
      cfg = axil_agent_cfg::type_id::create("cfg");
      cfg.vif = vif;
      uvm_config_db#(axil_agent_cfg)::set(this, "agent", "cfg", cfg);
      agent = axil_agent::type_id::create("agent", this);
    endfunction
    task run_phase(uvm_phase phase);
      scratchpad_sequence sequence_h = scratchpad_sequence::type_id::create("sequence_h");
      phase.raise_objection(this);
      sequence_h.start(agent.sequencer);
      phase.drop_objection(this);
    endtask
  endclass
endpackage

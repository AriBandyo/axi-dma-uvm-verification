class axi_mem_driver extends uvm_component;
  `uvm_component_utils(axi_mem_driver)
  axi_mem_cfg cfg;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(axi_mem_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal("AXI_MEM_CFG", "axi_mem_cfg was not provided")
  endfunction

  task run_phase(uvm_phase phase);
    drive_idle();
    forever begin
      wait (cfg.vif.aresetn === 1'b1);
      fork
        serve_reads();
        serve_writes();
        begin
          @(negedge cfg.vif.aresetn);
        end
      join_any
      disable fork;
      drive_idle();
    end
  endtask

  task drive_idle();
    cfg.vif.arready <= 1'b0;
    cfg.vif.rid <= '0;
    cfg.vif.rdata <= '0;
    cfg.vif.rresp <= 2'b00;
    cfg.vif.rlast <= 1'b0;
    cfg.vif.rvalid <= 1'b0;
    cfg.vif.awready <= 1'b0;
    cfg.vif.wready <= 1'b0;
    cfg.vif.bid <= '0;
    cfg.vif.bresp <= 2'b00;
    cfg.vif.bvalid <= 1'b0;
  endtask

  task automatic randomized_delay();
    int unsigned delay_cycles;
    delay_cycles = $urandom_range(cfg.maximum_latency, cfg.minimum_latency);
    repeat (delay_cycles) @(posedge cfg.vif.aclk);
  endtask

  function automatic bit [63:0] read_beat(longint unsigned address);
    bit [63:0] beat;
    for (int unsigned lane = 0; lane < 8; lane++)
      beat[lane*8 +: 8] = cfg.read_byte(address + lane);
    return beat;
  endfunction

  task serve_reads();
    forever begin
      bit [63:0] address;
      bit [7:0] burst_length;
      bit [3:0] transaction_id;
      axi_resp_item response_item;
      bit [1:0] selected_response;
      int unsigned error_beat;

      do begin
        @(posedge cfg.vif.aclk);
        cfg.vif.arready <= ($urandom_range(99, 0) >= cfg.ready_gap_percent);
      end while (!(cfg.vif.arvalid && cfg.vif.arready));

      address = cfg.vif.araddr;
      burst_length = cfg.vif.arlen;
      transaction_id = cfg.vif.arid;
      cfg.vif.arready <= 1'b0;
      response_item = axi_resp_item::type_id::create("read_response_item", this);
      selected_response = response_item.select_response(cfg);
      error_beat = $urandom_range(burst_length, 0);

      for (int unsigned beat_index = 0; beat_index <= burst_length; beat_index++) begin
        randomized_delay();
        cfg.vif.rid <= transaction_id;
        cfg.vif.rdata <= read_beat(address + beat_index * 8);
        cfg.vif.rresp <= (beat_index == error_beat) ? selected_response : 2'b00;
        cfg.vif.rlast <= (beat_index == burst_length);
        cfg.vif.rvalid <= 1'b1;
        do @(posedge cfg.vif.aclk); while (!cfg.vif.rready);
        cfg.vif.rvalid <= 1'b0;
        cfg.vif.rlast <= 1'b0;
        cfg.vif.rresp <= 2'b00;
      end
    end
  endtask

  task serve_writes();
    forever begin
      bit [63:0] address;
      bit [7:0] burst_length;
      bit [3:0] transaction_id;
      bit [63:0] captured_data[$];
      bit [7:0] captured_strobes[$];
      axi_resp_item response_item;
      bit [1:0] selected_response;

      do begin
        @(posedge cfg.vif.aclk);
        cfg.vif.awready <= ($urandom_range(99, 0) >= cfg.ready_gap_percent);
      end while (!(cfg.vif.awvalid && cfg.vif.awready));

      address = cfg.vif.awaddr;
      burst_length = cfg.vif.awlen;
      transaction_id = cfg.vif.awid;
      cfg.vif.awready <= 1'b0;

      for (int unsigned beat_index = 0; beat_index <= burst_length; beat_index++) begin
        do begin
          @(posedge cfg.vif.aclk);
          cfg.vif.wready <= ($urandom_range(99, 0) >= cfg.ready_gap_percent);
        end while (!(cfg.vif.wvalid && cfg.vif.wready));
        captured_data.push_back(cfg.vif.wdata);
        captured_strobes.push_back(cfg.vif.wstrb);
        if ((beat_index == burst_length) != cfg.vif.wlast)
          `uvm_error("AXI_WLAST", $sformatf("WLAST mismatch on beat %0d of %0d", beat_index, burst_length))
      end
      cfg.vif.wready <= 1'b0;

      response_item = axi_resp_item::type_id::create("write_response_item", this);
      selected_response = response_item.select_response(cfg);
      if (selected_response == 2'b00) begin
        foreach (captured_data[beat_index]) begin
          for (int unsigned lane = 0; lane < 8; lane++) begin
            if (captured_strobes[beat_index][lane])
              cfg.write_byte(address + beat_index*8 + lane, captured_data[beat_index][lane*8 +: 8]);
          end
        end
      end

      randomized_delay();
      cfg.vif.bid <= transaction_id;
      cfg.vif.bresp <= selected_response;
      cfg.vif.bvalid <= 1'b1;
      do @(posedge cfg.vif.aclk); while (!cfg.vif.bready);
      cfg.vif.bvalid <= 1'b0;
      cfg.vif.bresp <= 2'b00;
    end
  endtask
endclass

class axi_err_mem_driver extends axi_mem_driver;
  `uvm_component_utils(axi_err_mem_driver)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass

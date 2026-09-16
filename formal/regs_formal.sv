module regs_formal (
  input logic clk
);
  logic resetn = 1'b0;
  (* anyseq *) logic [7:0] araddr;
  (* anyseq *) logic arvalid;
  (* anyseq *) logic rready;
  logic arready;
  logic [31:0] rdata;
  logic [1:0] rresp;
  logic rvalid;
  logic [63:0] source_address;
  logic [63:0] destination_address;
  logic [31:0] transfer_length;
  logic [4:0] maximum_burst_beats;
  logic [1:0] requested_outstanding;
  logic crc_enable;
  logic start_pulse;
  logic abort_pulse;
  logic irq;
  logic past_valid = 1'b0;
  logic [7:0] accepted_read_address;

  dma_regs dut (
    .clk,
    .resetn,
    .s_axil_awaddr('0),
    .s_axil_awvalid(1'b0),
    .s_axil_awready(),
    .s_axil_wdata('0),
    .s_axil_wstrb('0),
    .s_axil_wvalid(1'b0),
    .s_axil_wready(),
    .s_axil_bresp(),
    .s_axil_bvalid(),
    .s_axil_bready(1'b1),
    .s_axil_araddr(araddr),
    .s_axil_arvalid(arvalid),
    .s_axil_arready(arready),
    .s_axil_rdata(rdata),
    .s_axil_rresp(rresp),
    .s_axil_rvalid(rvalid),
    .s_axil_rready(rready),
    .source_address,
    .destination_address,
    .transfer_length,
    .maximum_burst_beats,
    .requested_outstanding,
    .crc_enable,
    .start_pulse,
    .abort_pulse,
    .dma_busy(1'b0),
    .completion_event(1'b0),
    .error_event(1'b0),
    .error_event_bits('0),
    .bytes_transferred('0),
    .crc_result('0),
    .irq
  );

  always_ff @(posedge clk) begin
    past_valid <= 1'b1;
    resetn <= 1'b1;
    if (arvalid && arready)
      accepted_read_address <= araddr;
    if (past_valid && rvalid) begin
      assert (rresp == 2'b00);
      if (accepted_read_address == 8'h2C)
        assert (rdata == 32'h0001_0000);
      if (accepted_read_address > 8'h2C)
        assert (rdata == 32'h0000_0000);
    end
    assert (!start_pulse);
    assert (!abort_pulse);
  end
endmodule

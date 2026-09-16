module fifo_formal (
  input logic clk
);
  localparam int DEPTH = 4;
  logic resetn = 1'b0;
  (* anyseq *) logic push_request;
  (* anyseq *) logic pop_request;
  (* anyseq *) logic [7:0] write_data;
  logic [7:0] read_data;
  logic full;
  logic empty;
  logic [$clog2(DEPTH+1)-1:0] occupancy;
  logic past_valid = 1'b0;

  dma_fifo #(.DATA_WIDTH(8), .DEPTH(DEPTH)) dut (
    .clk,
    .resetn,
    .clear(1'b0),
    .push(push_request),
    .write_data,
    .pop(pop_request),
    .read_data,
    .full,
    .empty,
    .occupancy
  );

  always_ff @(posedge clk) begin
    past_valid <= 1'b1;
    resetn <= 1'b1;
    assert (occupancy <= DEPTH);
    assert (full == (occupancy == DEPTH));
    assert (empty == (occupancy == 0));

    if (past_valid && $past(resetn)) begin
      if ($past(push_request && !full && !(pop_request && !empty)))
        assert (occupancy == $past(occupancy) + 1);
      if ($past(pop_request && !empty && !(push_request && !full)))
        assert (occupancy + 1 == $past(occupancy));
      if ($past((push_request && !full) == (pop_request && !empty)))
        assert (occupancy == $past(occupancy));
    end
  end
endmodule

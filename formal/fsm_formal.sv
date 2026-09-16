import dma_pkg::*;

module fsm_formal (
  input logic clk
);
  logic resetn = 1'b0;
  (* anyseq *) logic start_pulse;
  (* anyseq *) logic abort_pulse;
  (* anyseq *) logic read_done;
  (* anyseq *) logic write_done;
  logic busy;
  logic completion_event;
  logic error_event;
  logic [15:0] error_bits;
  logic [31:0] bytes_transferred;
  logic [3:0] debug_state;
  logic read_command_valid;
  logic write_command_valid;
  logic [7:0] abort_request_history = '0;
  logic [7:0] idle_history = '0;

  dma_ctrl_fsm #(.FIFO_DEPTH(16)) dut (
    .clk,
    .resetn,
    .start_pulse,
    .abort_pulse,
    .programmed_source_address(64'h1000),
    .programmed_destination_address(64'h2000),
    .programmed_length(32'd128),
    .programmed_burst_beats(5'd4),
    .programmed_crc_enable(1'b0),
    .dma_busy(busy),
    .completion_event,
    .error_event,
    .error_event_bits(error_bits),
    .bytes_transferred,
    .crc_active(),
    .crc_initialize(),
    .fifo_clear(),
    .read_command_valid,
    .read_command_ready(1'b1),
    .read_command_address(),
    .read_command_beats(),
    .read_done,
    .read_response_error(2'b00),
    .read_protocol_error(1'b0),
    .write_command_valid,
    .write_command_ready(1'b1),
    .write_command_address(),
    .write_command_beats(),
    .write_done,
    .write_response_error(2'b00),
    .debug_state
  );

  always_ff @(posedge clk) begin
    resetn <= 1'b1;
    assume (read_done == (debug_state == DMA_READ_DATA));
    assume (write_done == (debug_state == DMA_WRITE_DATA));

    abort_request_history <= {abort_request_history[6:0], abort_pulse && busy};
    idle_history <= {idle_history[6:0], !busy};

    assert (debug_state <= 4'd9);
    assert (!(completion_event && error_event));
    if (completion_event)
      assert (!busy);

    if (abort_request_history[7])
      assert (|idle_history);
  end
endmodule

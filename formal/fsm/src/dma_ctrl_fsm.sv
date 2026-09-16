import dma_pkg::*;

module dma_ctrl_fsm #(
  parameter int unsigned FIFO_DEPTH = 16
) (
  input  logic        clk,
  input  logic        resetn,
  input  logic        start_pulse,
  input  logic        abort_pulse,
  input  logic [63:0] programmed_source_address,
  input  logic [63:0] programmed_destination_address,
  input  logic [31:0] programmed_length,
  input  logic [4:0]  programmed_burst_beats,
  input  logic        programmed_crc_enable,
  output logic        dma_busy,
  output logic        completion_event,
  output logic        error_event,
  output logic [15:0] error_event_bits,
  output logic [31:0] bytes_transferred,
  output logic        crc_active,
  output logic        crc_initialize,
  output logic        fifo_clear,
  output logic        read_command_valid,
  input  logic        read_command_ready,
  output logic [63:0] read_command_address,
  output logic [4:0]  read_command_beats,
  input  logic        read_done,
  input  logic [1:0]  read_response_error,
  input  logic        read_protocol_error,
  output logic        write_command_valid,
  input  logic        write_command_ready,
  output logic [63:0] write_command_address,
  output logic [4:0]  write_command_beats,
  input  logic        write_done,
  input  logic [1:0]  write_response_error,
  output logic [3:0]  debug_state
);

  logic [3:0] state;
  logic [63:0] active_source_address;
  logic [63:0] active_destination_address;
  logic [31:0] remaining_bytes;
  logic [4:0] active_maximum_burst;
  logic [4:0] current_burst_beats;
  logic abort_pending;
  logic [15:0] pending_error_bits;
  logic [9:0] source_boundary_beats;
  logic [9:0] destination_boundary_beats;
  logic [28:0] remaining_beats;
  logic [9:0] selected_beats;
  logic [64:0] source_end;
  logic [64:0] destination_end;
  logic regions_overlap;

  function automatic logic burst_length_supported(input logic [4:0] beats);
    begin
      burst_length_supported = (beats == 5'd1) || (beats == 5'd2) ||
                               (beats == 5'd4) || (beats == 5'd8) ||
                               (beats == 5'd16);
    end
  endfunction

  function automatic logic [9:0] beats_to_4kb(input logic [63:0] address);
    logic [12:0] bytes_left;
    begin
      bytes_left = 13'd4096 - {1'b0, address[11:0]};
      beats_to_4kb = bytes_left[12:3];
    end
  endfunction

  assign debug_state = state;
  assign read_command_valid = (state == DMA_READ_CMD);
  assign read_command_address = active_source_address;
  assign read_command_beats = current_burst_beats;
  assign write_command_valid = (state == DMA_WRITE_CMD);
  assign write_command_address = active_destination_address;
  assign write_command_beats = current_burst_beats;

  always_comb begin
    source_boundary_beats = beats_to_4kb(active_source_address);
    destination_boundary_beats = beats_to_4kb(active_destination_address);
    remaining_beats = remaining_bytes >> 3;

    selected_beats = active_maximum_burst;
    if (remaining_beats < selected_beats)
      selected_beats = remaining_beats[9:0];
    if (source_boundary_beats < selected_beats)
      selected_beats = source_boundary_beats;
    if (destination_boundary_beats < selected_beats)
      selected_beats = destination_boundary_beats;
    if (FIFO_DEPTH < selected_beats)
      selected_beats = FIFO_DEPTH;

    source_end = {1'b0, active_source_address} + remaining_bytes;
    destination_end = {1'b0, active_destination_address} + remaining_bytes;
    regions_overlap = ({1'b0, active_source_address} < destination_end) &&
                      ({1'b0, active_destination_address} < source_end);
  end

  always_ff @(posedge clk or negedge resetn) begin
    if (!resetn) begin
      state <= DMA_IDLE;
      active_source_address <= '0;
      active_destination_address <= '0;
      remaining_bytes <= '0;
      active_maximum_burst <= 5'd1;
      current_burst_beats <= 5'd1;
      abort_pending <= 1'b0;
      pending_error_bits <= '0;
      dma_busy <= 1'b0;
      completion_event <= 1'b0;
      error_event <= 1'b0;
      error_event_bits <= '0;
      bytes_transferred <= '0;
      crc_active <= 1'b0;
      crc_initialize <= 1'b0;
      fifo_clear <= 1'b0;
    end else begin
      completion_event <= 1'b0;
      error_event <= 1'b0;
      crc_initialize <= 1'b0;
      fifo_clear <= 1'b0;

      if (abort_pulse && dma_busy)
        abort_pending <= 1'b1;

      unique case (state)
        DMA_IDLE: begin
          dma_busy <= 1'b0;
          abort_pending <= 1'b0;
          crc_active <= 1'b0;
          if (start_pulse) begin
            active_source_address <= programmed_source_address;
            active_destination_address <= programmed_destination_address;
            remaining_bytes <= programmed_length;
            active_maximum_burst <= programmed_burst_beats;
            crc_active <= programmed_crc_enable;
            bytes_transferred <= '0;
            pending_error_bits <= '0;
            error_event_bits <= '0;
            fifo_clear <= 1'b1;
            crc_initialize <= 1'b1;
            dma_busy <= 1'b1;
            state <= DMA_VALIDATE;
          end
        end

        DMA_VALIDATE: begin
          pending_error_bits <= '0;
          if (remaining_bytes == 0) begin
            pending_error_bits[ERR_LEN_ZERO] <= 1'b1;
            state <= DMA_ERROR;
          end else if (remaining_bytes[2:0] != 0 ||
                       active_source_address[2:0] != 0 ||
                       active_destination_address[2:0] != 0) begin
            pending_error_bits[ERR_ALIGN] <= 1'b1;
            state <= DMA_ERROR;
          end else if (remaining_bytes[31:24] != 0) begin
            pending_error_bits[ERR_PROTOCOL] <= 1'b1;
            state <= DMA_ERROR;
          end else if (regions_overlap) begin
            pending_error_bits[ERR_OVERLAP] <= 1'b1;
            state <= DMA_ERROR;
          end else if (!burst_length_supported(active_maximum_burst)) begin
            pending_error_bits[ERR_PROTOCOL] <= 1'b1;
            state <= DMA_ERROR;
          end else begin
            state <= DMA_PLAN;
          end
        end

        DMA_PLAN: begin
          current_burst_beats <= selected_beats[4:0];
          state <= DMA_READ_CMD;
        end

        DMA_READ_CMD: begin
          if (read_command_ready) begin
            state <= DMA_READ_DATA;
          end
        end

        DMA_READ_DATA: begin
          if (read_done) begin
            if (read_protocol_error) begin
              pending_error_bits[ERR_PROTOCOL] <= 1'b1;
              fifo_clear <= 1'b1;
              state <= DMA_ERROR;
            end else if (read_response_error != AXI_RESP_OKAY) begin
              if (read_response_error == AXI_RESP_SLVERR)
                pending_error_bits[ERR_RD_SLVERR] <= 1'b1;
              else
                pending_error_bits[ERR_RD_DECERR] <= 1'b1;
              fifo_clear <= 1'b1;
              state <= DMA_ERROR;
            end else begin
              state <= DMA_WRITE_CMD;
            end
          end
        end

        DMA_WRITE_CMD: begin
          if (write_command_ready) begin
            state <= DMA_WRITE_DATA;
          end
        end

        DMA_WRITE_DATA: begin
          if (write_done) begin
            if (write_response_error != AXI_RESP_OKAY) begin
              if (write_response_error == AXI_RESP_SLVERR)
                pending_error_bits[ERR_WR_SLVERR] <= 1'b1;
              else
                pending_error_bits[ERR_WR_DECERR] <= 1'b1;
              fifo_clear <= 1'b1;
              state <= DMA_ERROR;
            end else begin
              bytes_transferred <= bytes_transferred + (current_burst_beats << 3);
              active_source_address <= active_source_address + (current_burst_beats << 3);
              active_destination_address <= active_destination_address + (current_burst_beats << 3);
              remaining_bytes <= remaining_bytes - (current_burst_beats << 3);

              if (abort_pending || abort_pulse) begin
                pending_error_bits[ERR_ABORTED] <= 1'b1;
                state <= DMA_ABORT;
              end else if (remaining_bytes == (current_burst_beats << 3)) begin
                state <= DMA_COMPLETE;
              end else begin
                state <= DMA_PLAN;
              end
            end
          end
        end

        DMA_COMPLETE: begin
          dma_busy <= 1'b0;
          completion_event <= 1'b1;
          state <= DMA_IDLE;
        end

        DMA_ERROR: begin
          dma_busy <= 1'b0;
          error_event <= 1'b1;
          error_event_bits <= pending_error_bits;
          fifo_clear <= 1'b1;
          state <= DMA_IDLE;
        end

        DMA_ABORT: begin
          dma_busy <= 1'b0;
          error_event <= 1'b1;
          error_event_bits <= pending_error_bits;
          fifo_clear <= 1'b1;
          state <= DMA_IDLE;
        end

        default: begin
          pending_error_bits[ERR_PROTOCOL] <= 1'b1;
          state <= DMA_ERROR;
        end
      endcase
    end
  end
endmodule

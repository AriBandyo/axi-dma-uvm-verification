module dma_fifo #(
  parameter int unsigned DATA_WIDTH = 64,
  parameter int unsigned DEPTH = 16
) (
  input  logic                  clk,
  input  logic                  resetn,
  input  logic                  clear,
  input  logic                  push,
  input  logic [DATA_WIDTH-1:0] write_data,
  input  logic                  pop,
  output logic [DATA_WIDTH-1:0] read_data,
  output logic                  full,
  output logic                  empty,
  output logic [$clog2(DEPTH+1)-1:0] occupancy
);
  localparam int unsigned PTR_WIDTH = (DEPTH <= 2) ? 1 : $clog2(DEPTH);

  logic [DATA_WIDTH-1:0] storage [0:DEPTH-1];
  logic [PTR_WIDTH-1:0] write_pointer;
  logic [PTR_WIDTH-1:0] read_pointer;

  assign full = (occupancy == DEPTH);
  assign empty = (occupancy == 0);
  assign read_data = storage[read_pointer];

  always_ff @(posedge clk or negedge resetn) begin
    if (!resetn) begin
      write_pointer <= '0;
      read_pointer <= '0;
      occupancy <= '0;
    end else if (clear) begin
      write_pointer <= '0;
      read_pointer <= '0;
      occupancy <= '0;
    end else begin
      unique case ({push && !full, pop && !empty})
        2'b10: begin
          storage[write_pointer] <= write_data;
          write_pointer <= (write_pointer == DEPTH-1) ? '0 : write_pointer + 1'b1;
          occupancy <= occupancy + 1'b1;
        end
        2'b01: begin
          read_pointer <= (read_pointer == DEPTH-1) ? '0 : read_pointer + 1'b1;
          occupancy <= occupancy - 1'b1;
        end
        2'b11: begin
          storage[write_pointer] <= write_data;
          write_pointer <= (write_pointer == DEPTH-1) ? '0 : write_pointer + 1'b1;
          read_pointer <= (read_pointer == DEPTH-1) ? '0 : read_pointer + 1'b1;
        end
        default: begin
        end
      endcase
    end
  end
endmodule

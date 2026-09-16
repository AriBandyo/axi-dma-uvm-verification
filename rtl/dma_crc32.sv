module dma_crc32 (
  input  logic        clk,
  input  logic        resetn,
  input  logic        initialize,
  input  logic        enable,
  input  logic [63:0] data,
  output logic [31:0] result
);
  logic [31:0] crc_state;

  function automatic logic [31:0] update_byte(
    input logic [31:0] current_crc,
    input logic [7:0]  next_byte
  );
    logic [31:0] value;
    integer bit_index;
    begin
      value = current_crc ^ next_byte;
      for (bit_index = 0; bit_index < 8; bit_index++) begin
        value = value[0] ? ((value >> 1) ^ 32'hEDB8_8320) : (value >> 1);
      end
      return value;
    end
  endfunction

  function automatic logic [31:0] update_beat(
    input logic [31:0] current_crc,
    input logic [63:0] beat_data
  );
    logic [31:0] value;
    integer byte_index;
    begin
      value = current_crc;
      for (byte_index = 0; byte_index < 8; byte_index++) begin
        value = update_byte(value, beat_data[byte_index*8 +: 8]);
      end
      return value;
    end
  endfunction

  assign result = ~crc_state;

  always_ff @(posedge clk or negedge resetn) begin
    if (!resetn) begin
      crc_state <= 32'hFFFF_FFFF;
    end else if (initialize) begin
      crc_state <= 32'hFFFF_FFFF;
    end else if (enable) begin
      crc_state <= update_beat(crc_state, data);
    end
  end
endmodule

module dma_read_engine (
  input  logic        clk,
  input  logic        resetn,
  input  logic        command_valid,
  output logic        command_ready,
  input  logic [63:0] command_address,
  input  logic [4:0]  command_beats,
  output logic        transfer_active,
  output logic        transfer_done,
  output logic [1:0]  response_error,
  output logic        protocol_error,
  output logic        fifo_push,
  output logic [63:0] fifo_write_data,
  input  logic        fifo_full,
  output logic [63:0] m_axi_araddr,
  output logic [7:0]  m_axi_arlen,
  output logic [2:0]  m_axi_arsize,
  output logic [1:0]  m_axi_arburst,
  output logic        m_axi_arvalid,
  input  logic        m_axi_arready,
  input  logic [63:0] m_axi_rdata,
  input  logic [1:0]  m_axi_rresp,
  input  logic        m_axi_rlast,
  input  logic        m_axi_rvalid,
  output logic        m_axi_rready
);
  typedef enum logic [1:0] {READ_IDLE, READ_ADDRESS, READ_PAYLOAD} read_state_e;
  read_state_e state;
  logic [4:0] beats_remaining;

  assign command_ready = (state == READ_IDLE);
  assign transfer_active = (state != READ_IDLE);
  assign m_axi_arvalid = (state == READ_ADDRESS);
  assign m_axi_rready = (state == READ_PAYLOAD) && !fifo_full;
  assign fifo_push = m_axi_rvalid && m_axi_rready;
  assign fifo_write_data = m_axi_rdata;

  always_ff @(posedge clk or negedge resetn) begin
    if (!resetn) begin
      state <= READ_IDLE;
      beats_remaining <= '0;
      m_axi_araddr <= '0;
      m_axi_arlen <= '0;
      m_axi_arsize <= 3'd3;
      m_axi_arburst <= 2'b01;
      transfer_done <= 1'b0;
      response_error <= 2'b00;
      protocol_error <= 1'b0;
    end else begin
      transfer_done <= 1'b0;

      unique case (state)
        READ_IDLE: begin
          response_error <= 2'b00;
          protocol_error <= 1'b0;
          if (command_valid) begin
            m_axi_araddr <= command_address;
            m_axi_arlen <= command_beats - 1'b1;
            m_axi_arsize <= 3'd3;
            m_axi_arburst <= 2'b01;
            beats_remaining <= command_beats;
            state <= READ_ADDRESS;
          end
        end

        READ_ADDRESS: begin
          if (m_axi_arvalid && m_axi_arready) begin
            state <= READ_PAYLOAD;
          end
        end

        READ_PAYLOAD: begin
          if (m_axi_rvalid && m_axi_rready) begin
            if (m_axi_rresp != 2'b00 && response_error == 2'b00) begin
              response_error <= m_axi_rresp;
            end

            if ((beats_remaining == 1'b1) != m_axi_rlast) begin
              protocol_error <= 1'b1;
            end

            if ((beats_remaining == 1'b1) || m_axi_rlast) begin
              beats_remaining <= '0;
              transfer_done <= 1'b1;
              state <= READ_IDLE;
            end else begin
              beats_remaining <= beats_remaining - 1'b1;
            end
          end
        end

        default: state <= READ_IDLE;
      endcase
    end
  end
endmodule

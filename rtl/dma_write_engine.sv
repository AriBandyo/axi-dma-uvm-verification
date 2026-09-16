module dma_write_engine (
  input  logic        clk,
  input  logic        resetn,
  input  logic        command_valid,
  output logic        command_ready,
  input  logic [63:0] command_address,
  input  logic [4:0]  command_beats,
  output logic        transfer_active,
  output logic        transfer_done,
  output logic [1:0]  response_error,
  output logic        fifo_pop,
  input  logic [63:0] fifo_read_data,
  input  logic        fifo_empty,
  output logic        data_accepted,
  output logic [63:0] accepted_data,
  output logic [63:0] m_axi_awaddr,
  output logic [7:0]  m_axi_awlen,
  output logic [2:0]  m_axi_awsize,
  output logic [1:0]  m_axi_awburst,
  output logic        m_axi_awvalid,
  input  logic        m_axi_awready,
  output logic [63:0] m_axi_wdata,
  output logic [7:0]  m_axi_wstrb,
  output logic        m_axi_wlast,
  output logic        m_axi_wvalid,
  input  logic        m_axi_wready,
  input  logic [1:0]  m_axi_bresp,
  input  logic        m_axi_bvalid,
  output logic        m_axi_bready
);
  typedef enum logic [1:0] {WRITE_IDLE, WRITE_ADDRESS, WRITE_PAYLOAD, WRITE_RESPONSE} write_state_e;
  write_state_e state;
  logic [4:0] beats_remaining;

  assign command_ready = (state == WRITE_IDLE);
  assign transfer_active = (state != WRITE_IDLE);
  assign m_axi_awvalid = (state == WRITE_ADDRESS);
  assign m_axi_wvalid = (state == WRITE_PAYLOAD) && !fifo_empty;
  assign m_axi_wdata = fifo_read_data;
  assign m_axi_wstrb = 8'hFF;
  assign m_axi_wlast = (beats_remaining == 1'b1);
  assign fifo_pop = m_axi_wvalid && m_axi_wready;
  assign data_accepted = fifo_pop;
  assign accepted_data = fifo_read_data;
  assign m_axi_bready = (state == WRITE_RESPONSE);

  always_ff @(posedge clk or negedge resetn) begin
    if (!resetn) begin
      state <= WRITE_IDLE;
      beats_remaining <= '0;
      m_axi_awaddr <= '0;
      m_axi_awlen <= '0;
      m_axi_awsize <= 3'd3;
      m_axi_awburst <= 2'b01;
      transfer_done <= 1'b0;
      response_error <= 2'b00;
    end else begin
      transfer_done <= 1'b0;

      unique case (state)
        WRITE_IDLE: begin
          response_error <= 2'b00;
          if (command_valid) begin
            m_axi_awaddr <= command_address;
            m_axi_awlen <= command_beats - 1'b1;
            m_axi_awsize <= 3'd3;
            m_axi_awburst <= 2'b01;
            beats_remaining <= command_beats;
            state <= WRITE_ADDRESS;
          end
        end

        WRITE_ADDRESS: begin
          if (m_axi_awvalid && m_axi_awready) begin
            state <= WRITE_PAYLOAD;
          end
        end

        WRITE_PAYLOAD: begin
          if (m_axi_wvalid && m_axi_wready) begin
            if (beats_remaining == 1'b1) begin
              beats_remaining <= '0;
              state <= WRITE_RESPONSE;
            end else begin
              beats_remaining <= beats_remaining - 1'b1;
            end
          end
        end

        WRITE_RESPONSE: begin
          if (m_axi_bvalid && m_axi_bready) begin
            response_error <= m_axi_bresp;
            transfer_done <= 1'b1;
            state <= WRITE_IDLE;
          end
        end

        default: state <= WRITE_IDLE;
      endcase
    end
  end
endmodule

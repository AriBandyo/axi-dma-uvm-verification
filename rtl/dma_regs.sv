module dma_regs (
  input  logic        clk,
  input  logic        resetn,

  input  logic [7:0]  s_axil_awaddr,
  input  logic        s_axil_awvalid,
  output logic        s_axil_awready,
  input  logic [31:0] s_axil_wdata,
  input  logic [3:0]  s_axil_wstrb,
  input  logic        s_axil_wvalid,
  output logic        s_axil_wready,
  output logic [1:0]  s_axil_bresp,
  output logic        s_axil_bvalid,
  input  logic        s_axil_bready,
  input  logic [7:0]  s_axil_araddr,
  input  logic        s_axil_arvalid,
  output logic        s_axil_arready,
  output logic [31:0] s_axil_rdata,
  output logic [1:0]  s_axil_rresp,
  output logic        s_axil_rvalid,
  input  logic        s_axil_rready,

  output logic [63:0] source_address,
  output logic [63:0] destination_address,
  output logic [31:0] transfer_length,
  output logic [4:0]  maximum_burst_beats,
  output logic [1:0]  requested_outstanding,
  output logic        crc_enable,
  output logic        start_pulse,
  output logic        abort_pulse,
  input  logic        dma_busy,
  input  logic        completion_event,
  input  logic        error_event,
  input  logic [15:0] error_event_bits,
  input  logic [31:0] bytes_transferred,
  input  logic [31:0] crc_result,
  output logic        irq
);
  localparam logic [7:0] REG_CONTROL       = 8'h00;
  localparam logic [7:0] REG_STATUS        = 8'h04;
  localparam logic [7:0] REG_SRC_ADDR_LOW  = 8'h08;
  localparam logic [7:0] REG_SRC_ADDR_HIGH = 8'h0C;
  localparam logic [7:0] REG_DST_ADDR_LOW  = 8'h10;
  localparam logic [7:0] REG_DST_ADDR_HIGH = 8'h14;
  localparam logic [7:0] REG_LENGTH        = 8'h18;
  localparam logic [7:0] REG_CONFIG        = 8'h1C;
  localparam logic [7:0] REG_ERROR_STATUS  = 8'h20;
  localparam logic [7:0] REG_BYTES_XFERRED = 8'h24;
  localparam logic [7:0] REG_CRC_RESULT    = 8'h28;
  localparam logic [7:0] REG_IP_VERSION    = 8'h2C;

  logic [7:0] captured_write_address;
  logic [31:0] captured_write_data;
  logic [3:0] captured_write_strobes;
  logic write_address_pending;
  logic write_data_pending;
  logic [31:0] configuration_register;
  logic status_done;
  logic status_error;
  logic irq_pending;
  logic [15:0] error_status;
  integer byte_lane;

  assign s_axil_awready = resetn && !write_address_pending && !s_axil_bvalid;
  assign s_axil_wready = resetn && !write_data_pending && !s_axil_bvalid;
  assign s_axil_arready = resetn && !s_axil_rvalid;
  assign s_axil_bresp = 2'b00;
  assign s_axil_rresp = 2'b00;
  assign maximum_burst_beats = configuration_register[4:0];
  assign irq = irq_pending;
  assign requested_outstanding = configuration_register[10:9];
  assign crc_enable = configuration_register[12];

  always_ff @(posedge clk or negedge resetn) begin
    if (!resetn) begin
      captured_write_address <= '0;
      captured_write_data <= '0;
      captured_write_strobes <= '0;
      write_address_pending <= 1'b0;
      write_data_pending <= 1'b0;
      s_axil_bvalid <= 1'b0;
      s_axil_rvalid <= 1'b0;
      s_axil_rdata <= '0;
      source_address <= '0;
      destination_address <= '0;
      transfer_length <= '0;
      configuration_register <= 32'h0000_0110;
      status_done <= 1'b0;
      status_error <= 1'b0;
      irq_pending <= 1'b0;
      error_status <= '0;
      start_pulse <= 1'b0;
      abort_pulse <= 1'b0;
    end else begin
      start_pulse <= 1'b0;
      abort_pulse <= 1'b0;

      if (s_axil_awready && s_axil_awvalid) begin
        captured_write_address <= s_axil_awaddr;
        write_address_pending <= 1'b1;
      end

      if (s_axil_wready && s_axil_wvalid) begin
        captured_write_data <= s_axil_wdata;
        captured_write_strobes <= s_axil_wstrb;
        write_data_pending <= 1'b1;
      end

      if (write_address_pending && write_data_pending && !s_axil_bvalid) begin
        unique case (captured_write_address)
          REG_CONTROL: begin
            if (captured_write_strobes[0]) begin
              if (captured_write_data[0]) begin
                start_pulse <= 1'b1;
                status_done <= 1'b0;
                status_error <= 1'b0;
                error_status <= '0;
                irq_pending <= 1'b0;
              end
              if (captured_write_data[1]) begin
                abort_pulse <= 1'b1;
              end
              if (captured_write_data[2]) begin
                irq_pending <= 1'b0;
              end
            end
          end

          REG_SRC_ADDR_LOW:
            for (byte_lane = 0; byte_lane < 4; byte_lane++)
              if (captured_write_strobes[byte_lane])
                source_address[byte_lane*8 +: 8] <= captured_write_data[byte_lane*8 +: 8];

          REG_SRC_ADDR_HIGH:
            for (byte_lane = 0; byte_lane < 4; byte_lane++)
              if (captured_write_strobes[byte_lane])
                source_address[32 + byte_lane*8 +: 8] <= captured_write_data[byte_lane*8 +: 8];

          REG_DST_ADDR_LOW:
            for (byte_lane = 0; byte_lane < 4; byte_lane++)
              if (captured_write_strobes[byte_lane])
                destination_address[byte_lane*8 +: 8] <= captured_write_data[byte_lane*8 +: 8];

          REG_DST_ADDR_HIGH:
            for (byte_lane = 0; byte_lane < 4; byte_lane++)
              if (captured_write_strobes[byte_lane])
                destination_address[32 + byte_lane*8 +: 8] <= captured_write_data[byte_lane*8 +: 8];

          REG_LENGTH:
            for (byte_lane = 0; byte_lane < 4; byte_lane++)
              if (captured_write_strobes[byte_lane])
                transfer_length[byte_lane*8 +: 8] <= captured_write_data[byte_lane*8 +: 8];

          REG_CONFIG:
            for (byte_lane = 0; byte_lane < 4; byte_lane++)
              if (captured_write_strobes[byte_lane])
                configuration_register[byte_lane*8 +: 8] <= captured_write_data[byte_lane*8 +: 8];

          default: begin
          end
        endcase

        write_address_pending <= 1'b0;
        write_data_pending <= 1'b0;
        s_axil_bvalid <= 1'b1;
      end

      if (s_axil_bvalid && s_axil_bready) begin
        s_axil_bvalid <= 1'b0;
      end

      if (s_axil_arready && s_axil_arvalid) begin
        unique case (s_axil_araddr)
          REG_CONTROL:       s_axil_rdata <= 32'h0000_0000;
          REG_STATUS:        s_axil_rdata <= {28'h0, irq_pending, status_error, status_done, dma_busy};
          REG_SRC_ADDR_LOW:  s_axil_rdata <= source_address[31:0];
          REG_SRC_ADDR_HIGH: s_axil_rdata <= source_address[63:32];
          REG_DST_ADDR_LOW:  s_axil_rdata <= destination_address[31:0];
          REG_DST_ADDR_HIGH: s_axil_rdata <= destination_address[63:32];
          REG_LENGTH:        s_axil_rdata <= transfer_length;
          REG_CONFIG:        s_axil_rdata <= configuration_register & 32'h0000_171F;
          REG_ERROR_STATUS:  s_axil_rdata <= {16'h0, error_status};
          REG_BYTES_XFERRED: s_axil_rdata <= bytes_transferred;
          REG_CRC_RESULT:    s_axil_rdata <= crc_result;
          REG_IP_VERSION:    s_axil_rdata <= 32'h0001_0000;
          default:           s_axil_rdata <= 32'h0000_0000;
        endcase
        s_axil_rvalid <= 1'b1;
      end

      if (s_axil_rvalid && s_axil_rready) begin
        s_axil_rvalid <= 1'b0;
      end

      if (completion_event) begin
        status_done <= 1'b1;
        status_error <= 1'b0;
        if (configuration_register[8]) begin
          irq_pending <= 1'b1;
        end
      end

      if (error_event) begin
        status_done <= 1'b0;
        status_error <= 1'b1;
        error_status <= error_status | error_event_bits;
        if (configuration_register[8]) begin
          irq_pending <= 1'b1;
        end
      end
    end
  end
endmodule

`timescale 1ns/1ps

module dma_smoke_tb;
  localparam int MEMORY_BYTES = 131072;
  logic aclk = 1'b0;
  logic aresetn = 1'b0;
  logic [7:0] s_axil_awaddr;
  logic s_axil_awvalid, s_axil_awready;
  logic [31:0] s_axil_wdata;
  logic [3:0] s_axil_wstrb;
  logic s_axil_wvalid, s_axil_wready;
  logic [1:0] s_axil_bresp;
  logic s_axil_bvalid, s_axil_bready;
  logic [7:0] s_axil_araddr;
  logic s_axil_arvalid, s_axil_arready;
  logic [31:0] s_axil_rdata;
  logic [1:0] s_axil_rresp;
  logic s_axil_rvalid, s_axil_rready;
  logic [3:0] m_axi_awid, m_axi_bid, m_axi_arid, m_axi_rid;
  logic [63:0] m_axi_awaddr, m_axi_wdata, m_axi_araddr, m_axi_rdata;
  logic [7:0] m_axi_awlen, m_axi_wstrb, m_axi_arlen;
  logic [2:0] m_axi_awsize, m_axi_arsize;
  logic [1:0] m_axi_awburst, m_axi_bresp, m_axi_arburst, m_axi_rresp;
  logic m_axi_awvalid, m_axi_awready, m_axi_wlast, m_axi_wvalid, m_axi_wready;
  logic m_axi_bvalid, m_axi_bready, m_axi_arvalid, m_axi_arready;
  logic m_axi_rlast, m_axi_rvalid, m_axi_rready;
  logic irq;
  logic [7:0] memory [0:MEMORY_BYTES-1];
  logic read_active, write_active;
  logic [63:0] read_address, write_address;
  integer read_beat, read_beats, write_beat, write_beats;

  always #5 aclk = ~aclk;

  dma_top dut (.*);

  assign m_axi_rid = '0;
  assign m_axi_bid = '0;

  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      m_axi_arready <= 1'b0;
      m_axi_rvalid <= 1'b0;
      m_axi_rlast <= 1'b0;
      m_axi_rresp <= 2'b00;
      m_axi_rdata <= '0;
      read_active <= 1'b0;
      read_address <= '0;
      read_beat <= 0;
      read_beats <= 0;
    end else begin
      m_axi_arready <= !read_active && !m_axi_rvalid;
      if (m_axi_arvalid && m_axi_arready) begin
        if (m_axi_araddr[11:0] + ((m_axi_arlen + 1) << m_axi_arsize) > 4096)
          $fatal(1, "read burst crossed 4KB boundary");
        read_active <= 1'b1;
        read_address <= m_axi_araddr;
        read_beat <= 0;
        read_beats <= m_axi_arlen + 1;
        m_axi_arready <= 1'b0;
      end
      if (read_active && !m_axi_rvalid) begin
        for (integer lane = 0; lane < 8; lane++)
          m_axi_rdata[lane*8 +: 8] <= memory[read_address + read_beat*8 + lane];
        m_axi_rlast <= (read_beat == read_beats - 1);
        m_axi_rvalid <= 1'b1;
      end else if (m_axi_rvalid && m_axi_rready) begin
        m_axi_rvalid <= 1'b0;
        m_axi_rlast <= 1'b0;
        if (read_beat == read_beats - 1)
          read_active <= 1'b0;
        else
          read_beat <= read_beat + 1;
      end
    end
  end

  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      m_axi_awready <= 1'b0;
      m_axi_wready <= 1'b0;
      m_axi_bvalid <= 1'b0;
      m_axi_bresp <= 2'b00;
      write_active <= 1'b0;
      write_address <= '0;
      write_beat <= 0;
      write_beats <= 0;
    end else begin
      m_axi_awready <= !write_active && !m_axi_bvalid;
      m_axi_wready <= write_active && !m_axi_bvalid;
      if (m_axi_awvalid && m_axi_awready) begin
        if (m_axi_awaddr[11:0] + ((m_axi_awlen + 1) << m_axi_awsize) > 4096)
          $fatal(1, "write burst crossed 4KB boundary");
        write_active <= 1'b1;
        write_address <= m_axi_awaddr;
        write_beat <= 0;
        write_beats <= m_axi_awlen + 1;
        m_axi_awready <= 1'b0;
      end
      if (m_axi_wvalid && m_axi_wready) begin
        if (m_axi_wlast != (write_beat == write_beats - 1))
          $fatal(1, "WLAST position mismatch");
        for (integer lane = 0; lane < 8; lane++)
          if (m_axi_wstrb[lane])
            memory[write_address + write_beat*8 + lane] <= m_axi_wdata[lane*8 +: 8];
        if (m_axi_wlast) begin
          write_active <= 1'b0;
          m_axi_wready <= 1'b0;
          m_axi_bvalid <= 1'b1;
        end else begin
          write_beat <= write_beat + 1;
        end
      end
      if (m_axi_bvalid && m_axi_bready)
        m_axi_bvalid <= 1'b0;
    end
  end

  task automatic axil_write(input logic [7:0] address, input logic [31:0] data);
    fork
      begin
        @(negedge aclk); s_axil_awaddr = address; s_axil_awvalid = 1'b1;
        do @(posedge aclk); while (!s_axil_awready);
        @(negedge aclk); s_axil_awvalid = 1'b0;
      end
      begin
        @(negedge aclk); s_axil_wdata = data; s_axil_wstrb = 4'hF; s_axil_wvalid = 1'b1;
        do @(posedge aclk); while (!s_axil_wready);
        @(negedge aclk); s_axil_wvalid = 1'b0;
      end
    join
    @(negedge aclk); s_axil_bready = 1'b1;
    do @(posedge aclk); while (!s_axil_bvalid);
    if (s_axil_bresp != 2'b00) $fatal(1, "AXI-Lite write response failed");
    @(negedge aclk); s_axil_bready = 1'b0;
  endtask

  task automatic axil_read(input logic [7:0] address, output logic [31:0] data);
    @(negedge aclk); s_axil_araddr = address; s_axil_arvalid = 1'b1;
    do @(posedge aclk); while (!s_axil_arready);
    @(negedge aclk); s_axil_arvalid = 1'b0; s_axil_rready = 1'b1;
    do @(posedge aclk); while (!s_axil_rvalid);
    data = s_axil_rdata;
    if (s_axil_rresp != 2'b00) $fatal(1, "AXI-Lite read response failed");
    @(negedge aclk); s_axil_rready = 1'b0;
  endtask

  initial begin
    logic [31:0] status;
    logic [31:0] transferred;
    localparam int SOURCE = 32'h0000_0FC0;
    localparam int DESTINATION = 32'h0001_0FE0;
    localparam int LENGTH = 512;
    s_axil_awaddr = '0; s_axil_awvalid = 1'b0; s_axil_wdata = '0;
    s_axil_wstrb = '0; s_axil_wvalid = 1'b0; s_axil_bready = 1'b0;
    s_axil_araddr = '0; s_axil_arvalid = 1'b0; s_axil_rready = 1'b0;
    for (integer index = 0; index < MEMORY_BYTES; index++) memory[index] = 8'h00;
    for (integer index = 0; index < LENGTH; index++) memory[SOURCE + index] = index[7:0] ^ 8'h5A;
    repeat (5) @(posedge aclk);
    aresetn = 1'b1;
    axil_write(8'h08, SOURCE);
    axil_write(8'h0C, 0);
    axil_write(8'h10, DESTINATION);
    axil_write(8'h14, 0);
    axil_write(8'h18, LENGTH);
    axil_write(8'h1C, 32'h0000_0110);
    axil_write(8'h00, 1);
    status = 0;
    for (integer poll = 0; poll < 10000 && !status[1] && !status[2]; poll++)
      axil_read(8'h04, status);
    if (!status[1] || status[2]) $fatal(1, "DMA did not complete successfully: status=0x%08x", status);
    axil_read(8'h24, transferred);
    if (transferred != LENGTH) $fatal(1, "BYTES_XFERRED mismatch: %0d", transferred);
    for (integer index = 0; index < LENGTH; index++)
      if (memory[DESTINATION + index] !== memory[SOURCE + index])
        $fatal(1, "copy mismatch at byte %0d", index);
    $display("VERIDMA RTL SMOKE PASSED: %0d bytes copied", LENGTH);
    $finish;
  end
endmodule

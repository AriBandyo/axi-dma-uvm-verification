module axil_scratchpad (
  input logic aclk, input logic aresetn,
  input logic [7:0] s_axil_awaddr, input logic s_axil_awvalid, output logic s_axil_awready,
  input logic [31:0] s_axil_wdata, input logic [3:0] s_axil_wstrb,
  input logic s_axil_wvalid, output logic s_axil_wready,
  output logic [1:0] s_axil_bresp, output logic s_axil_bvalid, input logic s_axil_bready,
  input logic [7:0] s_axil_araddr, input logic s_axil_arvalid, output logic s_axil_arready,
  output logic [31:0] s_axil_rdata, output logic [1:0] s_axil_rresp,
  output logic s_axil_rvalid, input logic s_axil_rready
);
  logic [31:0] registers [0:3];
  logic [7:0] write_address;
  logic [31:0] write_data;
  logic [3:0] write_strobes;
  logic address_pending;
  logic data_pending;
  integer lane;

  assign s_axil_awready = aresetn && !address_pending && !s_axil_bvalid;
  assign s_axil_wready = aresetn && !data_pending && !s_axil_bvalid;
  assign s_axil_arready = aresetn && !s_axil_rvalid;
  assign s_axil_bresp = 2'b00;
  assign s_axil_rresp = 2'b00;

  always_ff @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      registers[0] <= '0; registers[1] <= '0; registers[2] <= '0; registers[3] <= '0;
      address_pending <= 1'b0; data_pending <= 1'b0;
      s_axil_bvalid <= 1'b0; s_axil_rvalid <= 1'b0; s_axil_rdata <= '0;
    end else begin
      if (s_axil_awvalid && s_axil_awready) begin
        write_address <= s_axil_awaddr;
        address_pending <= 1'b1;
      end
      if (s_axil_wvalid && s_axil_wready) begin
        write_data <= s_axil_wdata;
        write_strobes <= s_axil_wstrb;
        data_pending <= 1'b1;
      end
      if (address_pending && data_pending && !s_axil_bvalid) begin
        if (write_address[7:4] == 0)
          for (lane = 0; lane < 4; lane++)
            if (write_strobes[lane])
              registers[write_address[3:2]][lane*8 +: 8] <= write_data[lane*8 +: 8];
        address_pending <= 1'b0;
        data_pending <= 1'b0;
        s_axil_bvalid <= 1'b1;
      end
      if (s_axil_bvalid && s_axil_bready)
        s_axil_bvalid <= 1'b0;
      if (s_axil_arvalid && s_axil_arready) begin
        s_axil_rdata <= (s_axil_araddr[7:4] == 0) ? registers[s_axil_araddr[3:2]] : 32'h0;
        s_axil_rvalid <= 1'b1;
      end
      if (s_axil_rvalid && s_axil_rready)
        s_axil_rvalid <= 1'b0;
    end
  end
endmodule

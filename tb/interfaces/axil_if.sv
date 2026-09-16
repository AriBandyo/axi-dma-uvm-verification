interface axil_if #(parameter int ADDR_WIDTH = 8, DATA_WIDTH = 32) (
  input logic aclk,
  input logic aresetn
);
  logic [ADDR_WIDTH-1:0] awaddr;
  logic awvalid;
  logic awready;
  logic [DATA_WIDTH-1:0] wdata;
  logic [DATA_WIDTH/8-1:0] wstrb;
  logic wvalid;
  logic wready;
  logic [1:0] bresp;
  logic bvalid;
  logic bready;
  logic [ADDR_WIDTH-1:0] araddr;
  logic arvalid;
  logic arready;
  logic [DATA_WIDTH-1:0] rdata;
  logic [1:0] rresp;
  logic rvalid;
  logic rready;

  task automatic drive_idle();
    awaddr <= '0;
    awvalid <= 1'b0;
    wdata <= '0;
    wstrb <= '0;
    wvalid <= 1'b0;
    bready <= 1'b0;
    araddr <= '0;
    arvalid <= 1'b0;
    rready <= 1'b0;
  endtask
endinterface

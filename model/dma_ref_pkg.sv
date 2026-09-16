package dma_ref_pkg;
  import "DPI-C" function void dma_ref_transfer(
    input  byte unsigned source_data[],
    output byte unsigned destination_data[],
    input  int unsigned length,
    input  bit crc_enable,
    output int unsigned crc_result
  );
endpackage

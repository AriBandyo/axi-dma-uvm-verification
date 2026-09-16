interface reset_ctrl_if(input logic aclk);
  logic inject_reset;

  task automatic assert_for_cycles(input int unsigned cycle_count);
    inject_reset <= 1'b1;
    repeat (cycle_count) @(posedge aclk);
    inject_reset <= 1'b0;
  endtask
endinterface

//############################################################################
//   2025 ICLAB Spring Course
//   MOS
//############################################################################

`timescale 1ns/10ps

`include "PATTERN.vp"
`ifdef RTL
  `include "MOS.v"
`endif
`ifdef GATE
  `include "MOS_SYN.v"
`endif
            
module TESTBED;

// Signal
wire        rst_n, clk, matrix_size,in_valid;
wire signed[15:0] in_data;
wire        out_valid;
wire signed[39:0]  out_data;



initial begin
  `ifdef RTL
    $fsdbDumpfile("MOS.fsdb");
    $fsdbDumpvars(0,"+mda");
    $fsdbDumpvars();
  `endif
  `ifdef GATE
    $sdf_annotate("MOS_SYN.sdf", u_MOS);
    // $fsdbDumpfile("MOS_SYN.fsdb");
    // $fsdbDumpvars();    
  `endif
end


MOS u_MOS(
  .clk(clk),
  .rst_n(rst_n),
  .in_valid(in_valid),
  .matrix_size(matrix_size),
  .in_data(in_data),
  .out_valid(out_valid),
  .out_data(out_data)
);




PATTERN u_PATTERN(
  .clk(clk),
  .rst_n(rst_n),
  .in_valid(in_valid),
  .matrix_size(matrix_size),
  .in_data(in_data),
  .out_valid(out_valid),
  .out_data(out_data)
);


endmodule

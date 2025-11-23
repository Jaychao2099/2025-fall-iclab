`timescale 1ns/1ps

`include "Usertype.sv"
`include "INF.sv"
`include "PATTERN.sv"
`include "../00_TESTBED/pseudo_DRAM.sv"

`ifdef RTL
  `include "RPG.sv"
  `define CYCLE_TIME 4.44
`endif

`ifdef GATE
  `include "RPG_SYN.v"
  `include "RPG_Wrapper.sv"
  `define CYCLE_TIME 4.44
`endif

module TESTBED;
  
parameter simulation_cycle = `CYCLE_TIME;
  reg  SystemClock;

  INF             inf();
  PATTERN         test_p(.clk(SystemClock), .inf(inf.PATTERN));
  pseudo_DRAM     dram_r(.clk(SystemClock), .inf(inf.DRAM)); 

  `ifdef RTL
	RPG      dut_p(.clk(SystemClock), .inf(inf.RPG_inf) );
  `endif
  
  `ifdef GATE
	RPG_svsim     dut_p(.clk(SystemClock), .inf(inf.RPG_inf) );
  `endif  
 //------ Generate Clock ------------
  initial begin
    SystemClock = 0;
	#10
    forever begin
      #(simulation_cycle/2.0)
        SystemClock = ~SystemClock;
    end
  end

//------ Dump FSDB File ------------  
initial begin
  `ifdef RTL
    $fsdbDumpfile("RPG.fsdb");
    $fsdbDumpvars(0,"+all");
    $fsdbDumpSVA;
  `elsif GATE
    // $fsdbDumpfile("RPG_SYN.fsdb");  
    $sdf_annotate("RPG_SYN.sdf",dut_p.RPG);      
    // $fsdbDumpvars(0,"+all");
  `endif
end

endmodule
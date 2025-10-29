/**************************************************************************
 * Copyright (c) 2025, OASIS Lab
 * MODULE: PATTERN
 * FILE NAME: PATTERN.v
 * VERSRION: 1.0
 * DATE: Oct 29, 2025
 * AUTHOR: Chao-En Kuo, NYCU IAIS
 * DESCRIPTION: ICLAB2025FALL / LAB7 / PATTERN
 * MODIFICATION HISTORY:
 * Date                 Description
 * 
 *************************************************************************/
`ifdef RTL
	`define CYCLE_TIME_clk1 14.1
	`define CYCLE_TIME_clk2 10.1
	`define CYCLE_TIME_clk3 20.7
`endif
`ifdef GATE
	`define CYCLE_TIME_clk1 14.1
	`define CYCLE_TIME_clk2 10.1
	`define CYCLE_TIME_clk3 20.7
`endif

module PATTERN(
	clk1,
	clk2,
	clk3,
	rst_n,
	in_valid,
	in_data,
	out_valid,
	out_data
);

//---------------------------------------------------------------------
//   PORT DECLARATION          
//---------------------------------------------------------------------
output reg        clk1, clk2, clk3;
output reg        rst_n;
output reg        in_valid;
output reg [31:0] in_data;

input             out_valid;
input      [15:0] out_data;


//---------------------------------------------------------------------
//   PARAMETER & INTEGER
//---------------------------------------------------------------------
real	CYCLE_clk1 = `CYCLE_TIME_clk1;
real	CYCLE_clk2 = `CYCLE_TIME_clk2;
real	CYCLE_clk3 = `CYCLE_TIME_clk3;
integer total_latency;

//---------------------------------------------------------------------
//   REG & WIRE
//---------------------------------------------------------------------


//---------------------------------------------------------------------
//  CLOCK
//---------------------------------------------------------------------


//---------------------------------------------------------------------
//  INITIAL
//---------------------------------------------------------------------


//---------------------------------------------------------------------
//  TASK
//---------------------------------------------------------------------


task YOU_PASS_task; begin
    $display("*************************************************************************");
    $display("*                         Congratulations!                              *");
    $display("*                Your execution cycles = %5d cycles          *", total_latency);
    $display("*                Your clock period = %.1f ns          *", CYCLE_clk3);
    $display("*                Total Latency = %.1f ns          *", total_latency*CYCLE_clk3);
    $display("*************************************************************************");
    $finish;
end endtask


endmodule

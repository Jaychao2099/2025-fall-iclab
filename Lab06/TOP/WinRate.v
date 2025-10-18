//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//    (C) Copyright System Integration and Silicon Implementation Laboratory
//    All Right Reserved
//		Date		: 2025/10
//		Version		: v1.0
//   	File Name   : WinRate.v
//   	Module Name : WinRate
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

`include "Poker.v"

module WinRate (
    // Input signals
    clk,
	  rst_n,
	  in_valid,
    in_hole_num,
    in_hole_suit,
    in_pub_num,
    in_pub_suit,
    out_valid,
    out_win_rate
);
// ===============================================================
// Input & Output
// ===============================================================
input clk;
input rst_n;
input in_valid;
input [71:0] in_hole_num;
input [35:0] in_hole_suit;
input [11:0] in_pub_num;
input [5:0] in_pub_suit;

output reg out_valid;
output reg [62:0] out_win_rate;
// ===============================================================
// Reg & Wire
// ===============================================================

// ===============================================================
// Design
// ===============================================================



endmodule
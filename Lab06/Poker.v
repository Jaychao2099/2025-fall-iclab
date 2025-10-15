//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//    (C) Copyright System Integration and Silicon Implementation Laboratory
//    All Right Reserved
//		Date		: 2025/10
//		Version		: v1.0
//   	File Name   : Poker.v
//   	Module Name : Poker
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################
module Poker #(parameter IP_WIDTH = 9) (
    // Input signals
    IN_HOLE_CARD_NUM, IN_HOLE_CARD_SUIT, IN_PUB_CARD_NUM, IN_PUB_CARD_SUIT,
    // Output signals
    OUT_WINNER
);

// ===============================================================
// Input & Output
// ===============================================================
input [IP_WIDTH*8-1:0]  IN_HOLE_CARD_NUM;
input [IP_WIDTH*4-1:0]  IN_HOLE_CARD_SUIT;
input [19:0]  IN_PUB_CARD_NUM;
input [9:0]  IN_PUB_CARD_SUIT;

output [IP_WIDTH-1:0]  OUT_WINNER;

// ===============================================================
// Reg & Wire
// ===============================================================

// ===============================================================
// Design
// ===============================================================



endmodule






//###############################################################################################
//***********************************************************************************************
//    File Name   : Division_IP_demo.v
//    Module Name : Division_IP_demo
//***********************************************************************************************
//###############################################################################################


 
`include "Poker.v"


module Poker_demo #(parameter IP_WIDTH = 9)(
	// Input signals
    IN_HOLE_CARD_NUM, IN_HOLE_CARD_SUIT, IN_PUB_CARD_NUM, IN_PUB_CARD_SUIT,
    // Output signals
    OUT_WINNER
);

// ======================================================
// Input & Output Declaration
// ======================================================
input [IP_WIDTH*8-1:0]  IN_HOLE_CARD_NUM;
input [IP_WIDTH*4-1:0]  IN_HOLE_CARD_SUIT;
input [19:0]  IN_PUB_CARD_NUM;
input [9:0]  IN_PUB_CARD_SUIT;

output [IP_WIDTH-1:0]  OUT_WINNER;

// ======================================================
// Soft IP
// ====================================================== 

Poker #(.IP_WIDTH(IP_WIDTH)) I_Poker_IP (
    	.IN_HOLE_CARD_NUM(IN_HOLE_CARD_NUM),
		.IN_HOLE_CARD_SUIT(IN_HOLE_CARD_SUIT),
		.IN_PUB_CARD_NUM(IN_PUB_CARD_NUM),
		.IN_PUB_CARD_SUIT(IN_PUB_CARD_SUIT),
    	.OUT_WINNER(OUT_WINNER)
	);

endmodule
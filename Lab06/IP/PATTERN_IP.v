`ifdef RTL
    `define CYCLE_TIME 20.0
`endif
`ifdef GATE
    `define CYCLE_TIME 20.0
`endif

module PATTERN #(parameter IP_WIDTH = 9)(
    // input signals
    OUT_WINNER,
	// Output signals
    IN_HOLE_CARD_NUM, IN_HOLE_CARD_SUIT, IN_PUB_CARD_NUM, IN_PUB_CARD_SUIT
);
// ========================================
// Input & Output
// ========================================
output reg [IP_WIDTH*8-1:0]  IN_HOLE_CARD_NUM;
output reg [IP_WIDTH*4-1:0]  IN_HOLE_CARD_SUIT;
output reg [19:0]  IN_PUB_CARD_NUM;
output reg [9:0]  IN_PUB_CARD_SUIT;

input [IP_WIDTH-1:0]  OUT_WINNER;

// ========================================
// Parameter
// ========================================

//================================================================
// clock
//================================================================






endmodule
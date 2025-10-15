`ifdef RTL
    `define CYCLE_TIME 40.0
`endif
`ifdef GATE
    `define CYCLE_TIME 40.0
`endif

module PATTERN(
    // Output signals
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

// ========================================
// Input & Output
// ========================================
output reg clk;
output reg rst_n;
output reg in_valid;
output reg [71:0] in_hole_num;
output reg [35:0] in_hole_suit;
output reg [11:0] in_pub_num;
output reg [6:0] in_pub_suit;

input out_valid;
input [62:0] out_win_rate;

// ========================================
// Parameter
// ========================================

//================================================================
// clock
//================================================================

endmodule
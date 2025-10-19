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
input [11:0] in_pub_num;    // 4-bit * 3
input [5:0] in_pub_suit;    // 2-bit * 3

output reg out_valid;
output reg [62:0] out_win_rate;

// ===============================================================
// Parameter
// ===============================================================

genvar j;

parameter S_IDLE   = 2'd0;
parameter S_INPUT  = 2'd1;
parameter S_CAL    = 2'd2;
parameter S_OUTPUT = 2'd3;

// ===============================================================
// Reg & Wire
// ===============================================================

// ---------------- FSM ----------------
reg [1:0] current_state, next_state;
reg [8:0] cal_cnt;

// ---------------- calulate rate ----------------
reg [51:0] init_possible_card_1;
reg [51:0] possible_card_1, possible_card_1_reg;    // (0~3) * (2~14)
reg [51:0] possible_card_2, possible_card_2_reg;    // (0~3) * (2~14)
// wire need_next_card_1;
wire [5:0] card_exist_idx [0:20];   // 21 card exist    // 0 ~ 51

reg [3:0] current_card_1_num, current_card_2_num;
reg [1:0] current_card_1_suit, current_card_2_suit;

wire [19:0] current_pub_card_num;
wire [9:0]  current_pub_card_suit;
wire [8:0] current_winner_mask;

wire [3:0] current_winners;
reg [20:0] numerator;   // max sum = 1171800, 21-bit, 100011110000101011000
reg [20:0] player_win_numerator [0:8];

// ===============================================================
// Design
// ===============================================================

// ---------------- FSM ----------------

// parameter S_IDLE   = 2'd0;
// parameter S_CAL    = 2'd1;
// parameter S_OUTPUT = 2'd2;

// reg [1:0] current_state;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) current_state <= S_IDLE;
    else        current_state <= next_state;
end

// reg [1:0] next_state;
always @(*) begin
    next_state = current_state;
    case (current_state)
        S_IDLE: begin
            if (in_valid) next_state = S_INPUT;
            else next_state = S_IDLE;
        end
        S_INPUT: begin
            next_state = S_CAL;
        end
        S_CAL: begin
            if (cal_cnt == 9'd464) next_state = S_OUTPUT;
            else next_state = S_CAL;
        end
        S_OUTPUT: begin
            next_state = S_IDLE;
        end
    endcase
end

// reg [8:0] cal_cnt;
// always @(posedge clk or negedge rst_n) begin
always @(posedge clk) begin
    // if (!rst_n) cal_cnt <= 9'd0;
    // else begin
        case (current_state)
            S_IDLE:  cal_cnt <= 9'd0;
            S_CAL:   cal_cnt <= cal_cnt + 9'd1;
            default: cal_cnt <= cal_cnt;
        endcase
    // end
end


// ---------------- calulate rate ----------------


function [51:0] set_smallest_one_to_zero;
    input [51:0] mask;
    set_smallest_one_to_zero = mask & (mask - 52'd1);
endfunction

// input [71:0] in_hole_num;    // 4-bit * (9 * 2)
// input [35:0] in_hole_suit;   // 2-bit * (9 * 2)
// input [11:0] in_pub_num;    // 4-bit * 3
// input [5:0] in_pub_suit;    // 2-bit * 3

reg [71:0] in_hole_num_reg;    // 4-bit * (9 * 2)
reg [35:0] in_hole_suit_reg;   // 2-bit * (9 * 2)
reg [11:0] in_pub_num_reg;    // 4-bit * 3
reg [5:0] in_pub_suit_reg;    // 2-bit * 3

always @(posedge clk) begin
    if (in_valid) begin
        in_hole_num_reg <= in_hole_num;
        in_hole_suit_reg <= in_hole_suit;
        in_pub_num_reg <= in_pub_num;
        in_pub_suit_reg <= in_pub_suit;
    end
    else begin
        in_hole_num_reg <= in_hole_num_reg;
        in_hole_suit_reg <= in_hole_suit_reg;
        in_pub_num_reg <= in_pub_num_reg;
        in_pub_suit_reg <= in_pub_suit_reg;
    end
end


// wire [5:0] card_exist_idx [0:20];   // 21 card exist    // 0 ~ 51
generate
    for (j = 0; j < 18; j = j + 1) begin: card_exist_idx_gen_1
        wire [5:0] in_hole_suit_tmp;
        MULT_13 m_13 (.a(in_hole_suit_reg[2*j+1:2*j]), .z(in_hole_suit_tmp));
        assign card_exist_idx[j] = in_hole_suit_tmp + in_hole_num_reg[4*j+3:4*j] - 6'd2;
        // assign card_exist_idx[j] = in_hole_suit_reg[2*j+1:2*j]*6'd13 + in_hole_num_reg[4*j+3:4*j] - 6'd2;
    end
    for (j = 0; j < 3; j = j + 1) begin: card_exist_idx_gen_2
        wire [5:0] in_pub_suit_tmp;
        MULT_13 m_13 (.a(in_pub_suit_reg[2*j+1:2*j]), .z(in_pub_suit_tmp));
        assign card_exist_idx[j+18] = in_pub_suit_tmp + in_pub_num_reg[4*j+3:4*j] - 6'd2;
        // assign card_exist_idx[j+18] = in_pub_suit_reg[2*j+1:2*j]*6'd13 + in_pub_num_reg[4*j+3:4*j] - 6'd2;
    end
endgenerate

// reg [51:0] init_possible_card_1;    // (0~3) * (2~14)
always @(*) begin
    integer  i;
    init_possible_card_1 = 52'hFFFFFFFFFFFFF;
    for (i = 0; i < 21; i = i + 1) begin
        init_possible_card_1[card_exist_idx[i]] = 1'b0;
    end
end

reg need_next_card_1;
// wire need_next_card_1;

reg [5:0] inner_cnt, inner_cnt_sub;

always @(posedge clk) begin
    if      (current_state == S_IDLE)                     inner_cnt_sub <= 6'd1;
    else if (current_state == S_CAL && inner_cnt == 6'd1) inner_cnt_sub <= inner_cnt_sub + 6'd1;
    else                                                  inner_cnt_sub <= inner_cnt_sub;
end

always @(posedge clk) begin
    case (current_state)
        S_IDLE: inner_cnt <= 6'd30;
        S_CAL:  begin
            if (inner_cnt == 6'd0) inner_cnt <= 6'd30 - inner_cnt_sub;
            else  inner_cnt <= inner_cnt - 6'd1;
        end
        default: inner_cnt <= inner_cnt;
    endcase
end

// reg need_next_card_1;
always @(*) begin
    if (inner_cnt == 6'd0) need_next_card_1 = 1'b1;
    else need_next_card_1 = 1'b0;
end

// reg [51:0] possible_card_1_reg;    // (0~3) * (2~14)
always @(posedge clk) begin
    possible_card_1_reg <= possible_card_1;
end

// reg [51:0] possible_card_1;    // (0~3) * (2~14)
always @(*) begin
    if      (current_state == S_INPUT)                   possible_card_1 = init_possible_card_1;
    else if (current_state == S_CAL && need_next_card_1) possible_card_1 = set_smallest_one_to_zero(possible_card_1_reg);
    else                                                 possible_card_1 = possible_card_1_reg;
end

// reg [51:0] possible_card_2_reg;    // (0~3) * (2~14)
always @(posedge clk) begin
    possible_card_2_reg <= possible_card_2;
end

// reg [51:0] possible_card_2;    // (0~3) * (2~14)
always @(*) begin
    if      (current_state == S_CAL && cal_cnt == 9'd0) possible_card_2 = set_smallest_one_to_zero(possible_card_1);
    else if (need_next_card_1)                          possible_card_2 = set_smallest_one_to_zero(set_smallest_one_to_zero(possible_card_1_reg));
    else                                                possible_card_2 = set_smallest_one_to_zero(possible_card_2_reg);
end

// reg [3:0] current_card_1_num;
always @(*) begin
    casex (possible_card_1)
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx1, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx10000000000000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxx100000000000000000000000000,
        52'bxxxxxxxxxxxx1000000000000000000000000000000000000000: current_card_1_num = 4'd2;

        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx10, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx100000000000000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxx1000000000000000000000000000,
        52'bxxxxxxxxxxx10000000000000000000000000000000000000000: current_card_1_num = 4'd3;

        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx100, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx1000000000000000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxx10000000000000000000000000000,
        52'bxxxxxxxxxx100000000000000000000000000000000000000000: current_card_1_num = 4'd4;

        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx1000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx10000000000000000, 
        52'bxxxxxxxxxxxxxxxxxxxxxx100000000000000000000000000000,
        52'bxxxxxxxxx1000000000000000000000000000000000000000000: current_card_1_num = 4'd5;

        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx10000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx100000000000000000, 
        52'bxxxxxxxxxxxxxxxxxxxxx1000000000000000000000000000000,
        52'bxxxxxxxx10000000000000000000000000000000000000000000: current_card_1_num = 4'd6;

        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx100000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx1000000000000000000, 
        52'bxxxxxxxxxxxxxxxxxxxx10000000000000000000000000000000,
        52'bxxxxxxx100000000000000000000000000000000000000000000: current_card_1_num = 4'd7;

        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx1000000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx10000000000000000000, 
        52'bxxxxxxxxxxxxxxxxxxx100000000000000000000000000000000,
        52'bxxxxxx1000000000000000000000000000000000000000000000: current_card_1_num = 4'd8;

        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx10000000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx100000000000000000000, 
        52'bxxxxxxxxxxxxxxxxxx1000000000000000000000000000000000,
        52'bxxxxx10000000000000000000000000000000000000000000000: current_card_1_num = 4'd9;

        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx100000000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx1000000000000000000000, 
        52'bxxxxxxxxxxxxxxxxx10000000000000000000000000000000000,
        52'bxxxx100000000000000000000000000000000000000000000000: current_card_1_num = 4'd10;

        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx1000000000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxx10000000000000000000000, 
        52'bxxxxxxxxxxxxxxxx100000000000000000000000000000000000,
        52'bxxx1000000000000000000000000000000000000000000000000: current_card_1_num = 4'd11;

        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx10000000000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxx100000000000000000000000, 
        52'bxxxxxxxxxxxxxxx1000000000000000000000000000000000000,
        52'bxx10000000000000000000000000000000000000000000000000: current_card_1_num = 4'd12;

        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx100000000000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxx1000000000000000000000000, 
        52'bxxxxxxxxxxxxxx10000000000000000000000000000000000000,
        52'bx100000000000000000000000000000000000000000000000000: current_card_1_num = 4'd13;

        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx1000000000000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxx10000000000000000000000000, 
        52'bxxxxxxxxxxxxx100000000000000000000000000000000000000,
        52'b1000000000000000000000000000000000000000000000000000: current_card_1_num = 4'd14;
        default: current_card_1_num = 4'd0;
    endcase
end

// reg [3:0] current_card_2_num;
always @(*) begin
    casex (possible_card_2)
        // 52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx1, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx10000000000000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxx100000000000000000000000000,
        52'bxxxxxxxxxxxx1000000000000000000000000000000000000000: current_card_2_num = 4'd2;

        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx10, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx100000000000000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxx1000000000000000000000000000,
        52'bxxxxxxxxxxx10000000000000000000000000000000000000000: current_card_2_num = 4'd3;

        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx100, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx1000000000000000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxx10000000000000000000000000000,
        52'bxxxxxxxxxx100000000000000000000000000000000000000000: current_card_2_num = 4'd4;

        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx1000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx10000000000000000, 
        52'bxxxxxxxxxxxxxxxxxxxxxx100000000000000000000000000000,
        52'bxxxxxxxxx1000000000000000000000000000000000000000000: current_card_2_num = 4'd5;

        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx10000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx100000000000000000, 
        52'bxxxxxxxxxxxxxxxxxxxxx1000000000000000000000000000000,
        52'bxxxxxxxx10000000000000000000000000000000000000000000: current_card_2_num = 4'd6;

        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx100000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx1000000000000000000, 
        52'bxxxxxxxxxxxxxxxxxxxx10000000000000000000000000000000,
        52'bxxxxxxx100000000000000000000000000000000000000000000: current_card_2_num = 4'd7;

        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx1000000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx10000000000000000000, 
        52'bxxxxxxxxxxxxxxxxxxx100000000000000000000000000000000,
        52'bxxxxxx1000000000000000000000000000000000000000000000: current_card_2_num = 4'd8;

        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx10000000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx100000000000000000000, 
        52'bxxxxxxxxxxxxxxxxxx1000000000000000000000000000000000,
        52'bxxxxx10000000000000000000000000000000000000000000000: current_card_2_num = 4'd9;

        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx100000000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx1000000000000000000000, 
        52'bxxxxxxxxxxxxxxxxx10000000000000000000000000000000000,
        52'bxxxx100000000000000000000000000000000000000000000000: current_card_2_num = 4'd10;

        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx1000000000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxx10000000000000000000000, 
        52'bxxxxxxxxxxxxxxxx100000000000000000000000000000000000,
        52'bxxx1000000000000000000000000000000000000000000000000: current_card_2_num = 4'd11;

        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx10000000000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxx100000000000000000000000, 
        52'bxxxxxxxxxxxxxxx1000000000000000000000000000000000000,
        52'bxx10000000000000000000000000000000000000000000000000: current_card_2_num = 4'd12;

        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx100000000000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxx1000000000000000000000000, 
        52'bxxxxxxxxxxxxxx10000000000000000000000000000000000000,
        52'bx100000000000000000000000000000000000000000000000000: current_card_2_num = 4'd13;

        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx1000000000000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxx10000000000000000000000000, 
        52'bxxxxxxxxxxxxx100000000000000000000000000000000000000,
        52'b1000000000000000000000000000000000000000000000000000: current_card_2_num = 4'd14;
        default: current_card_2_num = 4'd0;
    endcase
end

// reg [1:0] current_card_1_suit;
always @(*) begin
    casex (possible_card_1)
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx1, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx10, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx100, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx1000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx10000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx100000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx1000000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx10000000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx100000000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx1000000000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx10000000000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx100000000000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx1000000000000: current_card_1_suit = 2'd0;

        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx10000000000000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx100000000000000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx1000000000000000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx10000000000000000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx100000000000000000,
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx1000000000000000000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx10000000000000000000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx100000000000000000000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx1000000000000000000000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxx10000000000000000000000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxx100000000000000000000000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxx1000000000000000000000000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxx10000000000000000000000000: current_card_1_suit = 2'd1;

        52'bxxxxxxxxxxxxxxxxxxxxxxxxx100000000000000000000000000,
        52'bxxxxxxxxxxxxxxxxxxxxxxxx1000000000000000000000000000,
        52'bxxxxxxxxxxxxxxxxxxxxxxx10000000000000000000000000000,
        52'bxxxxxxxxxxxxxxxxxxxxxx100000000000000000000000000000,
        52'bxxxxxxxxxxxxxxxxxxxxx1000000000000000000000000000000,
        52'bxxxxxxxxxxxxxxxxxxxx10000000000000000000000000000000,
        52'bxxxxxxxxxxxxxxxxxxx100000000000000000000000000000000,
        52'bxxxxxxxxxxxxxxxxxx1000000000000000000000000000000000,
        52'bxxxxxxxxxxxxxxxxx10000000000000000000000000000000000,
        52'bxxxxxxxxxxxxxxxx100000000000000000000000000000000000,
        52'bxxxxxxxxxxxxxxx1000000000000000000000000000000000000,
        52'bxxxxxxxxxxxxxx10000000000000000000000000000000000000,
        52'bxxxxxxxxxxxxx100000000000000000000000000000000000000: current_card_1_suit = 2'd2;

        52'bxxxxxxxxxxxx1000000000000000000000000000000000000000,
        52'bxxxxxxxxxxx10000000000000000000000000000000000000000,
        52'bxxxxxxxxxx100000000000000000000000000000000000000000,
        52'bxxxxxxxxx1000000000000000000000000000000000000000000,
        52'bxxxxxxxx10000000000000000000000000000000000000000000,
        52'bxxxxxxx100000000000000000000000000000000000000000000,
        52'bxxxxxx1000000000000000000000000000000000000000000000,
        52'bxxxxx10000000000000000000000000000000000000000000000,
        52'bxxxx100000000000000000000000000000000000000000000000,
        52'bxxx1000000000000000000000000000000000000000000000000,
        52'bxx10000000000000000000000000000000000000000000000000,
        52'bx100000000000000000000000000000000000000000000000000,
        52'b1000000000000000000000000000000000000000000000000000: current_card_1_suit = 2'd3;
        default: current_card_1_suit = 2'd0;
    endcase
end

// reg [1:0] current_card_2_suit;
always @(*) begin
    casex (possible_card_2)
        // 52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx1, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx10, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx100, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx1000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx10000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx100000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx1000000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx10000000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx100000000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx1000000000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx10000000000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx100000000000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx1000000000000: current_card_2_suit = 2'd0;

        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx10000000000000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx100000000000000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx1000000000000000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx10000000000000000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx100000000000000000,
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx1000000000000000000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx10000000000000000000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx100000000000000000000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx1000000000000000000000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxx10000000000000000000000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxxx100000000000000000000000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxxx1000000000000000000000000, 
        52'bxxxxxxxxxxxxxxxxxxxxxxxxxx10000000000000000000000000: current_card_2_suit = 2'd1;

        52'bxxxxxxxxxxxxxxxxxxxxxxxxx100000000000000000000000000,
        52'bxxxxxxxxxxxxxxxxxxxxxxxx1000000000000000000000000000,
        52'bxxxxxxxxxxxxxxxxxxxxxxx10000000000000000000000000000,
        52'bxxxxxxxxxxxxxxxxxxxxxx100000000000000000000000000000,
        52'bxxxxxxxxxxxxxxxxxxxxx1000000000000000000000000000000,
        52'bxxxxxxxxxxxxxxxxxxxx10000000000000000000000000000000,
        52'bxxxxxxxxxxxxxxxxxxx100000000000000000000000000000000,
        52'bxxxxxxxxxxxxxxxxxx1000000000000000000000000000000000,
        52'bxxxxxxxxxxxxxxxxx10000000000000000000000000000000000,
        52'bxxxxxxxxxxxxxxxx100000000000000000000000000000000000,
        52'bxxxxxxxxxxxxxxx1000000000000000000000000000000000000,
        52'bxxxxxxxxxxxxxx10000000000000000000000000000000000000,
        52'bxxxxxxxxxxxxx100000000000000000000000000000000000000: current_card_2_suit = 2'd2;

        52'bxxxxxxxxxxxx1000000000000000000000000000000000000000,
        52'bxxxxxxxxxxx10000000000000000000000000000000000000000,
        52'bxxxxxxxxxx100000000000000000000000000000000000000000,
        52'bxxxxxxxxx1000000000000000000000000000000000000000000,
        52'bxxxxxxxx10000000000000000000000000000000000000000000,
        52'bxxxxxxx100000000000000000000000000000000000000000000,
        52'bxxxxxx1000000000000000000000000000000000000000000000,
        52'bxxxxx10000000000000000000000000000000000000000000000,
        52'bxxxx100000000000000000000000000000000000000000000000,
        52'bxxx1000000000000000000000000000000000000000000000000,
        52'bxx10000000000000000000000000000000000000000000000000,
        52'bx100000000000000000000000000000000000000000000000000,
        52'b1000000000000000000000000000000000000000000000000000: current_card_2_suit = 2'd3;
        default: current_card_2_suit = 2'd0;
    endcase
end

// wire [19:0] current_pub_card_num;
// wire [9:0]  current_pub_card_suit;
assign current_pub_card_num  = {in_pub_num_reg, current_card_1_num, current_card_2_num};
assign current_pub_card_suit = {in_pub_suit_reg, current_card_1_suit, current_card_2_suit};

// wire [8:0] current_winner_mask;
Poker #(9) poker (.IN_HOLE_CARD_NUM(in_hole_num_reg), .IN_HOLE_CARD_SUIT(in_hole_suit_reg),
                  .IN_PUB_CARD_NUM(current_pub_card_num), .IN_PUB_CARD_SUIT(current_pub_card_suit), 
                  .OUT_WINNER(current_winner_mask));

// 1     2    3    4    5    6    7    8    9
// 2520 1260  840  630  504  420  360  315  280

// wire [3:0] current_winners;
POPCOUNT_9bits_LUT popcount (.data_in(current_winner_mask), .popcount(current_winners));

// reg [20:0] numerator;   // max sum = 1171800, 21-bit, 100011110000101011000
always @(*) begin
    case (current_winners)
        4'd1: numerator = 21'd2520;
        4'd2: numerator = 21'd1260;
        4'd3: numerator = 21'd840;
        4'd4: numerator = 21'd630;
        4'd5: numerator = 21'd504;
        4'd6: numerator = 21'd420;
        4'd7: numerator = 21'd360;
        4'd8: numerator = 21'd315;
        4'd9: numerator = 21'd280;
        default: numerator = 21'd0;
    endcase
end

reg [20:0] player_win_numerator_reg [0:8];

// reg [20:0] player_win_numerator_reg [0:8];
always @(posedge clk) begin
    player_win_numerator_reg <= player_win_numerator;
end

// reg [20:0] player_win_numerator [0:8];
always @(*) begin
    integer i;
    if (current_state == S_IDLE) begin
        for (i = 0; i < 9; i = i + 1) player_win_numerator[i] = 21'd0;
    end
    else if (current_state == S_CAL) begin
        for (i = 0; i < 9; i = i + 1) begin
            player_win_numerator[i] = (current_winner_mask[i]) ? (player_win_numerator_reg[i] + numerator) : player_win_numerator_reg[i];
        end
    end
    else player_win_numerator = player_win_numerator_reg;
end

reg [20:0] player_win_rate [0:8];

// reg [20:0] player_win_rate [0:8];
always @(posedge clk) begin
    integer i;
    for (i = 0; i < 9; i = i + 1) begin
        player_win_rate[i] <= player_win_numerator[i] / 21'd11718;      // 465*2520/100
    end
end


// ---------------- output ----------------

// output reg [62:0] out_win_rate;
always @(posedge clk or negedge rst_n) begin
    integer i;
    if (!rst_n) out_win_rate <= 63'd0;
    else if (current_state == S_OUTPUT) begin
        out_win_rate <= {
            player_win_rate[8][6:0],
            player_win_rate[7][6:0],
            player_win_rate[6][6:0],
            player_win_rate[5][6:0],
            player_win_rate[4][6:0],
            player_win_rate[3][6:0],
            player_win_rate[2][6:0],
            player_win_rate[1][6:0],
            player_win_rate[0][6:0]};
    end
    else out_win_rate <= 63'd0;
end

// output reg out_valid;
always @(posedge clk or negedge rst_n) begin
    if      (!rst_n)                    out_valid <= 1'b0;
    else if (current_state == S_OUTPUT) out_valid <= 1'b1;
    else                                out_valid <= 1'b0;
end


endmodule

module MULT_13 (
    input [1:0] a,
    output reg [5:0] z
);

always @(*) begin
    case (a)
        2'd0: z = 6'd0;
        2'd1: z = 6'd13;
        2'd2: z = 6'd26;
        2'd3: z = 6'd39;
        default: z = 6'd0;
    endcase
end

endmodule



module POPCOUNT_9bits_LUT (
    input  [8:0] data_in,
    output reg [3:0] popcount
);

// always @(*) begin
//     popcount = data_in[0] + data_in[1] + data_in[2] + data_in[3] + data_in[4] + data_in[5] + data_in[6] + data_in[7] + data_in[8];
// end

always @(*) begin
    case (data_in)
        // Popcount = 0 (C(9,0) = 1)
        9'h000: popcount = 4'd0;

        // Popcount = 1 (C(9,1) = 9)
        9'h001, 9'h002, 9'h004, 9'h008, 9'h010, 9'h020, 9'h040, 9'h080, 9'h100: popcount = 4'd1;

        // Popcount = 2 (C(9,2) = 36)
        9'h003, 9'h005, 9'h006, 9'h009, 9'h00A, 9'h00C, 9'h011, 9'h012, 9'h014, 9'h018, 
        9'h021, 9'h022, 9'h024, 9'h028, 9'h030, 9'h041, 9'h042, 9'h044, 9'h048, 9'h050, 
        9'h060, 9'h081, 9'h082, 9'h084, 9'h088, 9'h090, 9'h0A0, 9'h0C0, 9'h101, 9'h102, 
        9'h104, 9'h108, 9'h110, 9'h120, 9'h140, 9'h180: popcount = 4'd2;

        // Popcount = 3 (C(9,3) = 84)
        9'h007, 9'h00B, 9'h00D, 9'h00E, 9'h013, 9'h015, 9'h016, 9'h019, 9'h01A, 9'h01C, 
        9'h023, 9'h025, 9'h026, 9'h029, 9'h02A, 9'h02C, 9'h031, 9'h032, 9'h034, 9'h038, 
        9'h043, 9'h045, 9'h046, 9'h049, 9'h04A, 9'h04C, 9'h051, 9'h052, 9'h054, 9'h058, 
        9'h061, 9'h062, 9'h064, 9'h068, 9'h070, 9'h083, 9'h085, 9'h086, 9'h089, 9'h08A, 
        9'h08C, 9'h091, 9'h092, 9'h094, 9'h098, 9'h0A1, 9'h0A2, 9'h0A4, 9'h0A8, 9'h0B0, 
        9'h0C1, 9'h0C2, 9'h0C4, 9'h0C8, 9'h0D0, 9'h0E0, 9'h103, 9'h105, 9'h106, 9'h109, 
        9'h10A, 9'h10C, 9'h111, 9'h112, 9'h114, 9'h118, 9'h121, 9'h122, 9'h124, 9'h128, 
        9'h130, 9'h141, 9'h142, 9'h144, 9'h148, 9'h150, 9'h160, 9'h181, 9'h182, 9'h184, 
        9'h188, 9'h190, 9'h1A0, 9'h1C0: popcount = 4'd3;

        // Popcount = 4 (C(9,4) = 126)
        9'h00F, 9'h017, 9'h01B, 9'h01D, 9'h01E, 9'h027, 9'h02B, 9'h02D, 9'h02E, 9'h033, 
        9'h035, 9'h036, 9'h039, 9'h03A, 9'h03C, 9'h047, 9'h04B, 9'h04D, 9'h04E, 9'h053, 
        9'h055, 9'h056, 9'h059, 9'h05A, 9'h05C, 9'h063, 9'h065, 9'h066, 9'h069, 9'h06A, 
        9'h06C, 9'h071, 9'h072, 9'h074, 9'h078, 9'h087, 9'h08B, 9'h08D, 9'h08E, 9'h093, 
        9'h095, 9'h096, 9'h099, 9'h09A, 9'h09C, 9'h0A3, 9'h0A5, 9'h0A6, 9'h0A9, 9'h0AA, 
        9'h0AC, 9'h0B1, 9'h0B2, 9'h0B4, 9'h0B8, 9'h0C3, 9'h0C5, 9'h0C6, 9'h0C9, 9'h0CA, 
        9'h0CC, 9'h0D1, 9'h0D2, 9'h0D4, 9'h0D8, 9'h0E1, 9'h0E2, 9'h0E4, 9'h0E8, 9'h0F0, 
        9'h107, 9'h10B, 9'h10D, 9'h10E, 9'h113, 9'h115, 9'h116, 9'h119, 9'h11A, 9'h11C, 
        9'h123, 9'h125, 9'h126, 9'h129, 9'h12A, 9'h12C, 9'h131, 9'h132, 9'h134, 9'h138, 
        9'h143, 9'h145, 9'h146, 9'h149, 9'h14A, 9'h14C, 9'h151, 9'h152, 9'h154, 9'h158, 
        9'h161, 9'h162, 9'h164, 9'h168, 9'h170, 9'h183, 9'h185, 9'h186, 9'h189, 9'h18A, 
        9'h18C, 9'h191, 9'h192, 9'h194, 9'h198, 9'h1A1, 9'h1A2, 9'h1A4, 9'h1A8, 9'h1B0, 
        9'h1C1, 9'h1C2, 9'h1C4, 9'h1C8, 9'h1D0, 9'h1E0: popcount = 4'd4;
        
        // Popcount = 5 (C(9,5) = 126)
        9'h01F, 9'h02F, 9'h037, 9'h03B, 9'h03D, 9'h03E, 9'h04F, 9'h057, 9'h05B, 9'h05D, 
        9'h05E, 9'h067, 9'h06B, 9'h06D, 9'h06E, 9'h073, 9'h075, 9'h076, 9'h079, 9'h07A, 
        9'h07C, 9'h08F, 9'h097, 9'h09B, 9'h09D, 9'h09E, 9'h0A7, 9'h0AB, 9'h0AD, 9'h0AE, 
        9'h0B3, 9'h0B5, 9'h0B6, 9'h0B9, 9'h0BA, 9'h0BC, 9'h0C7, 9'h0CB, 9'h0CD, 9'h0CE, 
        9'h0D3, 9'h0D5, 9'h0D6, 9'h0D9, 9'h0DA, 9'h0DC, 9'h0E3, 9'h0E5, 9'h0E6, 9'h0E9, 
        9'h0EA, 9'h0EC, 9'h0F1, 9'h0F2, 9'h0F4, 9'h0F8, 9'h10F, 9'h117, 9'h11B, 9'h11D, 
        9'h11E, 9'h127, 9'h12B, 9'h12D, 9'h12E, 9'h133, 9'h135, 9'h136, 9'h139, 9'h13A, 
        9'h13C, 9'h147, 9'h14B, 9'h14D, 9'h14E, 9'h153, 9'h155, 9'h156, 9'h159, 9'h15A, 
        9'h15C, 9'h163, 9'h165, 9'h166, 9'h169, 9'h16A, 9'h16C, 9'h171, 9'h172, 9'h174, 
        9'h178, 9'h187, 9'h18B, 9'h18D, 9'h18E, 9'h193, 9'h195, 9'h196, 9'h199, 9'h19A, 
        9'h19C, 9'h1A3, 9'h1A5, 9'h1A6, 9'h1A9, 9'h1AA, 9'h1AC, 9'h1B1, 9'h1B2, 9'h1B4, 
        9'h1B8, 9'h1C3, 9'h1C5, 9'h1C6, 9'h1C9, 9'h1CA, 9'h1CC, 9'h1D1, 9'h1D2, 9'h1D4, 
        9'h1D8, 9'h1E1, 9'h1E2, 9'h1E4, 9'h1E8, 9'h1F0: popcount = 4'd5;
        
        // Popcount = 6 (C(9,6) = 84)
        9'h03F, 9'h05F, 9'h06F, 9'h077, 9'h07B, 9'h07D, 9'h07E, 9'h09F, 9'h0AF, 9'h0B7, 
        9'h0BB, 9'h0BD, 9'h0BE, 9'h0CF, 9'h0D7, 9'h0DB, 9'h0DD, 9'h0DE, 9'h0E7, 9'h0EB, 
        9'h0ED, 9'h0EE, 9'h0F3, 9'h0F5, 9'h0F6, 9'h0F9, 9'h0FA, 9'h0FC, 9'h11F, 9'h12F, 
        9'h137, 9'h13B, 9'h13D, 9'h13E, 9'h14F, 9'h157, 9'h15B, 9'h15D, 9'h15E, 9'h167, 
        9'h16B, 9'h16D, 9'h16E, 9'h173, 9'h175, 9'h176, 9'h179, 9'h17A, 9'h17C, 9'h18F, 
        9'h197, 9'h19B, 9'h19D, 9'h19E, 9'h1A7, 9'h1AB, 9'h1AD, 9'h1AE, 9'h1B3, 9'h1B5, 
        9'h1B6, 9'h1B9, 9'h1BA, 9'h1BC, 9'h1C7, 9'h1CB, 9'h1CD, 9'h1CE, 9'h1D3, 9'h1D5, 
        9'h1D6, 9'h1D9, 9'h1DA, 9'h1DC, 9'h1E3, 9'h1E5, 9'h1E6, 9'h1E9, 9'h1EA, 9'h1EC, 
        9'h1F1, 9'h1F2, 9'h1F4, 9'h1F8: popcount = 4'd6;
        
        // Popcount = 7 (C(9,7) = 36)
        9'h07F, 9'h0BF, 9'h0DF, 9'h0EF, 9'h0F7, 9'h0FB, 9'h0FD, 9'h0FE, 9'h13F, 9'h15F, 
        9'h16F, 9'h177, 9'h17B, 9'h17D, 9'h17E, 9'h19F, 9'h1AF, 9'h1B7, 9'h1BB, 9'h1BD, 
        9'h1BE, 9'h1CF, 9'h1D7, 9'h1DB, 9'h1DD, 9'h1DE, 9'h1E7, 9'h1EB, 9'h1ED, 9'h1EE, 
        9'h1F3, 9'h1F5, 9'h1F6, 9'h1F9, 9'h1FA, 9'h1FC: popcount = 4'd7;

        // Popcount = 8 (C(9,8) = 9)
        9'h0FF, 9'h17F, 9'h1BF, 9'h1DF, 9'h1EF, 9'h1F7, 9'h1FB, 9'h1FD, 9'h1FE: popcount = 4'd8;
        
        // Popcount = 9 (C(9,9) = 1)
        9'h1FF: popcount = 4'd9;

        default: popcount = 4'd10;
        
    endcase
end

endmodule
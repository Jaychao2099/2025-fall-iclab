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
// in player's hand
input [IP_WIDTH*8-1:0]  IN_HOLE_CARD_NUM;  // {card-1 num(4-bit), card-2 num(4-bit)}_8, {...}_7, ..., {...}_0     2  3  4  5  6  7  8  9  10  J  Q  K  A  (2 ~ 14)
input [IP_WIDTH*4-1:0]  IN_HOLE_CARD_SUIT; // {card-1 suit(2-bit), card-2 suit(2-bit)}_8, {...}_7, ..., {...}_0   Clubs  Diamonds  Hearts  Spades         (0 ~ 3)
// on table
input [19:0]  IN_PUB_CARD_NUM;      // 4-bit * 5
input [9:0]  IN_PUB_CARD_SUIT;      // 2-bit * 5

output [IP_WIDTH-1:0]  OUT_WINNER;  // winner = 1, loser = 0

// ===============================================================
// Reg & Wire
// ===============================================================

genvar i;

wire [27:0] cards_num  [0:IP_WIDTH-1];    // 7*4 = 28
wire [13:0] cards_suit [0:IP_WIDTH-1];    // 7*2 = 14
wire [23:0] player_strength [0:IP_WIDTH-1];

// ===============================================================
// Design
// ===============================================================

// wire [27:0] cards_num  [0:IP_WIDTH-1];
// wire [13:0] cards_suit [0:IP_WIDTH-1];
generate
    for (i = 0; i < IP_WIDTH; i = i + 1) begin: cards_unpack
        assign cards_num[i]  = {IN_PUB_CARD_NUM, IN_HOLE_CARD_NUM[8*i+7:8*i]};
        assign cards_suit[i] = {IN_PUB_CARD_SUIT, IN_HOLE_CARD_SUIT[4*i+3:4*i]};
    end
endgenerate

// wire [23:0] player_strength [0:IP_WIDTH-1];
generate
    for (i = 0; i < IP_WIDTH; i = i + 1) begin: strength_gen
        CAL_STRENGTH strength (.cards_num(cards_num[i]), .cards_suit(cards_suit[i]), .cards_strength(player_strength[i]));
    end
endgenerate


generate
    if (IP_WIDTH == 9) begin
        PLAYERS_CMP_9 cmp9 (.player_strength(player_strength), .winner_mask(OUT_WINNER));
    end
    else if (IP_WIDTH == 8) begin
        PLAYERS_CMP_8 cmp8 (.player_strength(player_strength), .winner_mask(OUT_WINNER));
    end
    else if (IP_WIDTH == 7) begin
        PLAYERS_CMP_7 cmp7 (.player_strength(player_strength), .winner_mask(OUT_WINNER));
    end
    else if (IP_WIDTH == 6) begin
        PLAYERS_CMP_6 cmp6 (.player_strength(player_strength), .winner_mask(OUT_WINNER));
    end
    else if (IP_WIDTH == 5) begin
        PLAYERS_CMP_5 cmp5 (.player_strength(player_strength), .winner_mask(OUT_WINNER));
    end
    else if (IP_WIDTH == 4) begin
        PLAYERS_CMP_4 cmp4 (.player_strength(player_strength), .winner_mask(OUT_WINNER));
    end
    else if (IP_WIDTH == 3) begin
        PLAYERS_CMP_3 cmp3 (.player_strength(player_strength), .winner_mask(OUT_WINNER));
    end
    else if (IP_WIDTH == 2) begin
        PLAYERS_CMP_2 cmp2 (.player_strength(player_strength), .winner_mask(OUT_WINNER));
    end
endgenerate


endmodule


module CAL_STRENGTH (
    input [27:0] cards_num,      // 5 hand cards + 2 table cards = 7, each 4-bit
    input [13:0] cards_suit,

    output reg [23:0] cards_strength
);

// ===============================================================
// Reg & Wire & Parameter
// ===============================================================
genvar i, j;

reg  is_straight_flush;
wire is_four;
wire is_full_house;
reg  is_flush;
wire is_straight;
wire is_three;
wire is_two_pair;
wire is_one_pair;

reg  [3:0] straight_flush_key;
wire [3:0] four_key;
wire [3:0] full_house_key1, full_house_key2;
reg  [3:0] flush_key1, flush_key2, flush_key3, flush_key4, flush_key5;
wire [3:0] straight_key;
wire [3:0] three_key;
wire [3:0] two_pair_key1, two_pair_key2;
wire [3:0] one_pair_key;

wire [3:0] cards_num_sorted [0:6];

wire [3:0] four_kicker;
reg  [3:0] three_kicker1, three_kicker2;
wire [3:0] two_pair_kicker;
reg  [3:0] one_pair_kicker1, one_pair_kicker2, one_pair_kicker3;

// ===============================================================
// Design
// ===============================================================

// TODO: decode to 7 cards first
wire [3:0] cards_num_each  [0:6];
wire [1:0] cards_suit_each [0:6];

wire [5:0] cards_suit_num_each [0:6];      // 2+4 bits
wire [5:0] cards_suit_num_sorted [0:6];

generate
    for (j = 0; j < 7; j = j + 1) begin: decode_each_card
        assign cards_num_each[j]  = cards_num[4*j+3:4*j];
        assign cards_suit_each[j] = cards_suit[2*j+1:2*j];
        assign cards_suit_num_each[j] = {cards_suit_each[j], cards_num_each[j]};
    end
endgenerate

// wire [5:0] cards_suit_num_sorted [0:6];
// output [output_bits-1:0] sorted_card [0:6]   // small idx == big num
SORT_CARD #(6, 6) sort_by_suit (.cards_num(cards_suit_num_each), .sorted_card(cards_suit_num_sorted));

wire [1:0] sorted_siut [0:6];
wire [3:0] sorted_num  [0:6];

generate
    for (j = 0; j < 7; j = j + 1) begin: decode_suit_num
        assign sorted_siut[j] = cards_suit_num_sorted[j][5:4];
        assign sorted_num[j]  = cards_suit_num_sorted[j][3:0];
    end
endgenerate

// reg [3:0] flush_key1, flush_key2, flush_key3, flush_key4, flush_key5;
// reg  is_flush;
// wire [3:0] cards_suit_num_sorted [0:6];
always @(*) begin
    if (sorted_siut[0] == sorted_siut[4]) begin
        flush_key1 = sorted_num[0];
        flush_key2 = sorted_num[1];
        flush_key3 = sorted_num[2];
        flush_key4 = sorted_num[3];
        flush_key5 = sorted_num[4];
        is_flush = 1'b1;
    end
    else if (sorted_siut[1] == sorted_siut[5]) begin
        flush_key1 = sorted_num[1];
        flush_key2 = sorted_num[2];
        flush_key3 = sorted_num[3];
        flush_key4 = sorted_num[4];
        flush_key5 = sorted_num[5];
        is_flush = 1'b1;
    end
    else if (sorted_siut[2] == sorted_siut[6]) begin
        flush_key1 = sorted_num[2];
        flush_key2 = sorted_num[3];
        flush_key3 = sorted_num[4];
        flush_key4 = sorted_num[5];
        flush_key5 = sorted_num[6];
        is_flush = 1'b1;
    end
    else begin
        flush_key1 = 4'd0;
        flush_key2 = 4'd0;
        flush_key3 = 4'd0;
        flush_key4 = 4'd0;
        flush_key5 = 4'd0;
        is_flush = 1'b0;
    end
end

wire special_straight_flush_1, special_straight_flush_2, special_straight_flush_3, has_special_straight_flush;

assign special_straight_flush_1 = (sorted_siut[3] == sorted_siut[6] && sorted_num[3] == 4'd5 &&
                                  (sorted_siut[2] == sorted_siut[3] && sorted_num[2] == 4'd14 || 
                                   sorted_siut[1] == sorted_siut[3] && sorted_num[1] == 4'd14 || 
                                   sorted_siut[0] == sorted_siut[3] && sorted_num[0] == 4'd14));

assign special_straight_flush_2 = (sorted_siut[2] == sorted_siut[5] && sorted_num[2] == 4'd5 &&
                                  (sorted_siut[1] == sorted_siut[2] && sorted_num[1] == 4'd14 || 
                                   sorted_siut[0] == sorted_siut[2] && sorted_num[0] == 4'd14));

assign special_straight_flush_3 = (sorted_siut[1] == sorted_siut[4] && sorted_num[1] == 4'd5 &&
                                  (sorted_siut[0] == sorted_siut[1] && sorted_num[0] == 4'd14));

assign has_special_straight_flush = special_straight_flush_1 || special_straight_flush_2 || special_straight_flush_3;

// reg  is_straight_flush;
// reg [3:0] straight_flush_key;
always @(*) begin
    if      (sorted_siut[0] == sorted_siut[4] && (sorted_num[0] == sorted_num[4] + 4'd4)) begin
        is_straight_flush = 1'b1;
        straight_flush_key = sorted_num[0];
    end
    else if (sorted_siut[1] == sorted_siut[5] && (sorted_num[1] == sorted_num[5] + 4'd4)) begin
        is_straight_flush = 1'b1;
        straight_flush_key = sorted_num[1];
    end
    else if (sorted_siut[2] == sorted_siut[6] && (sorted_num[2] == sorted_num[6] + 4'd4)) begin
        is_straight_flush = 1'b1;
        straight_flush_key = sorted_num[2];
    end
    else if (has_special_straight_flush) begin
        is_straight_flush = 1'b1;
        straight_flush_key = 4'd5;
    end
    else begin
        is_straight_flush = 1'b0;
        straight_flush_key = 4'd0;
    end
end

NUMBER_COUNT player_num_situation (.cards_num(cards_num_each), 
                                   // ---------- SAME_NUM ----------
                                   .Four_of_a_Kind(is_four), .Full_House(is_full_house), .Three_of_a_Kind(is_three), 
                                   .Two_Pair(is_two_pair), .One_Pair(is_one_pair),
                                   
                                   .Four_of_a_Kind_key(four_key),
                                   .Full_House_key1(full_house_key1), .Full_House_key2(full_house_key2),
                                   .Three_of_a_Kind_key(three_key),
                                   .Two_Pair_key1(two_pair_key1), .Two_Pair_key2(two_pair_key2),
                                   .One_Pair_key(one_pair_key),
                                   // ---------- STRAIGHT ----------
                                   .has_straight(is_straight), .straight_key(straight_key));

// assign is_straight_flush = is_straight & is_flush;

// wire [3:0] cards_num_sorted [0:6];
// output [3:0] sorted_card [0:6]   // small idx == big num
SORT_CARD #(4, 4) sort_by_num (.cards_num(cards_num_each), .sorted_card(cards_num_sorted));

// wire [3:0] four_kicker;
assign four_kicker = (four_key != cards_num_sorted[0]) ? cards_num_sorted[0] :
                     (four_key != cards_num_sorted[1]) ? cards_num_sorted[1] :
                     (four_key != cards_num_sorted[2]) ? cards_num_sorted[2] :
                     (four_key != cards_num_sorted[3]) ? cards_num_sorted[3] : cards_num_sorted[4];

wire [6:0] three_match_key;
generate
    for (j = 0; j < 7; j = j + 1) begin: three_match_key_gen
        assign three_match_key[j] = (three_key == cards_num_sorted[j]);
    end
endgenerate

// reg  [3:0] three_kicker1, three_kicker2
always @(*) begin
    casex (three_match_key)
        7'bxxxx111: begin
            three_kicker1 = cards_num_sorted[3];
            three_kicker2 = cards_num_sorted[4];
        end
        7'bxxx1110: begin
            three_kicker1 = cards_num_sorted[0];
            three_kicker2 = cards_num_sorted[4];
        end
        default: begin
            three_kicker1 = cards_num_sorted[0];
            three_kicker2 = cards_num_sorted[1];
        end
    endcase
end

// wire [3:0] two_pair_kicker;
assign two_pair_kicker = (two_pair_key1 != cards_num_sorted[0] && two_pair_key2 != cards_num_sorted[0]) ? cards_num_sorted[0] :
                         (two_pair_key1 != cards_num_sorted[1] && two_pair_key2 != cards_num_sorted[1]) ? cards_num_sorted[1] :
                         (two_pair_key1 != cards_num_sorted[2] && two_pair_key2 != cards_num_sorted[2]) ? cards_num_sorted[2] :
                         (two_pair_key1 != cards_num_sorted[3] && two_pair_key2 != cards_num_sorted[3]) ? cards_num_sorted[3] : cards_num_sorted[4];

wire [6:0] one_pair_match_key;
generate
    for (j = 0; j < 7; j = j + 1) begin: one_pair_match_key_gen
        assign one_pair_match_key[j] = (one_pair_key == cards_num_sorted[j]);
    end
endgenerate

// reg  [3:0] one_pair_kicker1, one_pair_kicker2, one_pair_kicker3;
always @(*) begin
    casex (one_pair_match_key)
        7'bxxxxx11: begin
            one_pair_kicker1 = cards_num_sorted[2];
            one_pair_kicker2 = cards_num_sorted[3];
            one_pair_kicker3 = cards_num_sorted[4];
        end
        7'bxxxx110: begin
            one_pair_kicker1 = cards_num_sorted[0];
            one_pair_kicker2 = cards_num_sorted[3];
            one_pair_kicker3 = cards_num_sorted[4];
        end
        7'bxxx1100: begin
            one_pair_kicker1 = cards_num_sorted[0];
            one_pair_kicker2 = cards_num_sorted[1];
            one_pair_kicker3 = cards_num_sorted[4];
        end
        default: begin
            one_pair_kicker1 = cards_num_sorted[0];
            one_pair_kicker2 = cards_num_sorted[1];
            one_pair_kicker3 = cards_num_sorted[2];
        end
    endcase
end

// reg [3:0] rank , key1 , key2 , key3 , key4 , key5;

always @(*) begin
    if (is_straight_flush)  cards_strength = {4'd8, straight_flush_key,  4'd0,                4'd0,                4'd0,                4'd0};
    else if (is_four)       cards_strength = {4'd7, four_key,            four_kicker,         4'd0,                4'd0,                4'd0};
    else if (is_full_house) cards_strength = {4'd6, full_house_key1,     full_house_key2,     4'd0,                4'd0,                4'd0};
    else if (is_flush)      cards_strength = {4'd5, flush_key1,          flush_key2,          flush_key3,          flush_key4,          flush_key5};
    else if (is_straight)   cards_strength = {4'd4, straight_key,        4'd0,                4'd0,                4'd0,                4'd0};
    else if (is_three)      cards_strength = {4'd3, three_key,           three_kicker1,       three_kicker2,       4'd0,                4'd0};
    else if (is_two_pair)   cards_strength = {4'd2, two_pair_key1,       two_pair_key2,       two_pair_kicker,     4'd0,                4'd0};
    else if (is_one_pair)   cards_strength = {4'd1, one_pair_key,        one_pair_kicker1,    one_pair_kicker2,    one_pair_kicker3,    4'd0};
    else                    cards_strength = {4'd0, cards_num_sorted[0], cards_num_sorted[1], cards_num_sorted[2], cards_num_sorted[3], cards_num_sorted[4]};
end

endmodule


module SORT_CARD #(
    parameter input_bits = 4,
    parameter output_bits = 4
) (
    input [input_bits-1:0] cards_num [0:6],      // 5 hand cards + 2 table cards = 7, each 4-bit
    output [output_bits-1:0] sorted_card [0:6]    // small idx == big num
);

reg [input_bits-1:0] layer0_0,           layer0_2, layer0_3, layer0_4, layer0_5, layer0_6; // layer0_1
reg [input_bits-1:0] layer1_0, layer1_1, layer1_2, layer1_3, layer1_4,           layer1_6; // layer1_5
reg [input_bits-1:0] layer2_0, layer2_1, layer2_2, layer2_3, layer2_4, layer2_5          ; // layer2_6
reg [input_bits-1:0]           layer3_1, layer3_2,           layer3_4,           layer3_6; // layer3_0, layer3_3, layer3_5
reg [input_bits-1:0]                     layer4_2, layer4_3, layer4_4, layer4_5          ; // layer4_0, layer4_1, layer4_6
reg [input_bits-1:0]           layer5_1, layer5_2, layer5_3, layer5_4, layer5_5, layer5_6; // layer5_0

// output [27:0] sorted_card    // small idx == big num
assign sorted_card[0] = layer2_0[input_bits-1:input_bits-output_bits];
assign sorted_card[1] = layer5_1[input_bits-1:input_bits-output_bits];
assign sorted_card[2] = layer5_2[input_bits-1:input_bits-output_bits];
assign sorted_card[3] = layer5_3[input_bits-1:input_bits-output_bits];
assign sorted_card[4] = layer5_4[input_bits-1:input_bits-output_bits];
assign sorted_card[5] = layer5_5[input_bits-1:input_bits-output_bits];
assign sorted_card[6] = layer5_6[input_bits-1:input_bits-output_bits];


// [(0,6),(2,3),(4,5)]
// [(0,2),(1,4),(3,6)]
// [(0,1),(2,5),(3,4)]
// [(1,2),(4,6)]
// [(2,3),(4,5)]
// [(1,2),(3,4),(5,6)]
always @(*) begin
    // Layer 0: [(0,6),(2,3),(4,5)]
    
    // (0,6)
    if (cards_num[0] < cards_num[6]) begin      // smaller ---> swap
        layer0_0 = cards_num[6];
        layer0_6 = cards_num[0];
    end
    else begin
        layer0_0 = cards_num[0];
        layer0_6 = cards_num[6];
    end
    
    // (2,3)
    if (cards_num[2] < cards_num[3]) begin
        layer0_2 = cards_num[3];
        layer0_3 = cards_num[2];
    end
    else begin
        layer0_2 = cards_num[2];
        layer0_3 = cards_num[3];
    end
    
    // (4,5)
    if (cards_num[4] < cards_num[5]) begin
        layer0_4 = cards_num[5];
        layer0_5 = cards_num[4];
    end
    else begin
        layer0_4 = cards_num[4];
        layer0_5 = cards_num[5];
    end

    // Layer 1: [(0,2),(1,4),(3,6)]
    
    // (0,2)
    if (layer0_0 < layer0_2) begin
        layer1_0 = layer0_2;
        layer1_2 = layer0_0;
    end
    else begin
        layer1_0 = layer0_0;
        layer1_2 = layer0_2;
    end
    
    // (1,4)
    if (cards_num[1] < layer0_4) begin
        layer1_1 = layer0_4;
        layer1_4 = cards_num[1];
    end
    else begin
        layer1_1 = cards_num[1];
        layer1_4 = layer0_4;
    end
    
    // (3,6)
    if (layer0_3 < layer0_6) begin
        layer1_3 = layer0_6;
        layer1_6 = layer0_3;
    end
    else begin
        layer1_3 = layer0_3;
        layer1_6 = layer0_6;
    end

    // Layer 2: [(0,1),(2,5),(3,4)]
    
    // (0,1)
    if (layer1_0 < layer1_1) begin
        layer2_0 = layer1_1;
        layer2_1 = layer1_0;
    end
    else begin
        layer2_0 = layer1_0;
        layer2_1 = layer1_1;
    end
    
    // (2,5)
    if (layer1_2 < layer0_5) begin
        layer2_2 = layer0_5;
        layer2_5 = layer1_2;
    end
    else begin
        layer2_2 = layer1_2;
        layer2_5 = layer0_5;
    end
    
    // (3,4)
    if (layer1_3 < layer1_4) begin
        layer2_3 = layer1_4;
        layer2_4 = layer1_3;
    end
    else begin
        layer2_3 = layer1_3;
        layer2_4 = layer1_4;
    end

    // Layer 3: [(1,2),(4,6)]
    
    // (1,2)
    if (layer2_1 < layer2_2) begin
        layer3_1 = layer2_2;
        layer3_2 = layer2_1;
    end
    else begin
        layer3_1 = layer2_1;
        layer3_2 = layer2_2;
    end
    
    // (4,6)
    if (layer2_4 < layer1_6) begin
        layer3_4 = layer1_6;
        layer3_6 = layer2_4;
    end
    else begin
        layer3_4 = layer2_4;
        layer3_6 = layer1_6;
    end

    // Layer 4: [(2,3),(4,5)]
    
    // (2,3)
    if (layer3_2 < layer2_3) begin
        layer4_2 = layer2_3;
        layer4_3 = layer3_2;
    end
    else begin
        layer4_2 = layer3_2;
        layer4_3 = layer2_3;
    end
    
    // (4,5)
    if (layer3_4 < layer2_5) begin
        layer4_4 = layer2_5;
        layer4_5 = layer3_4;
    end
    else begin
        layer4_4 = layer3_4;
        layer4_5 = layer2_5;
    end

    // Layer 5: [(1,2),(3,4),(5,6)]
    
    // (1,2)
    if (layer3_1 < layer4_2) begin
        layer5_1 = layer4_2;
        layer5_2 = layer3_1;
    end
    else begin
        layer5_1 = layer3_1;
        layer5_2 = layer4_2;
    end
    
    // (3,4)
    if (layer4_3 < layer4_4) begin
        layer5_3 = layer4_4;
        layer5_4 = layer4_3;
    end
    else begin
        layer5_3 = layer4_3;
        layer5_4 = layer4_4;
    end
    
    // (5,6)
    if (layer4_5 < layer3_6) begin
        layer5_5 = layer3_6;
        layer5_6 = layer4_5;
    end
    else begin
        layer5_5 = layer4_5;
        layer5_6 = layer3_6;
    end
end

endmodule




module NUMBER_COUNT (
    input [3:0] cards_num [0:6],      // 5 hand cards + 2 table cards = 7, each 4-bit
    // ---------- SAME_NUM ----------
    output Four_of_a_Kind,
    output Full_House,
    output Three_of_a_Kind,
    output Two_Pair,
    output One_Pair,

    // output reg [3:0] same_num_key1,
    // output reg [3:0] same_num_key2,
    // can I delete some??????
    output reg [3:0] Four_of_a_Kind_key,
    output reg [3:0] Full_House_key1, Full_House_key2,
    output reg [3:0] Three_of_a_Kind_key,
    output reg [3:0] Two_Pair_key1, Two_Pair_key2,
    output reg [3:0] One_Pair_key,
    // ---------- STRAIGHT ----------
    output reg has_straight,
    output reg [3:0]straight_key
);

wire [6:0] numbers_mask [2:14];
wire [2:0] numbers_num [2:14];      // 0 ~ 4
wire [12:0] is_four_mask, reverse_is_three_mask, reverse_is_two_mask;
wire [12:0] second_three_mask;
wire [12:0] second_big_pair_mask;

reg [3:0] second_three_key;

genvar i, j;

// wire [6:0] numbers_mask [2:14];
generate
    for (i = 0; i < 7; i = i + 1) begin: card_unpack_num
        for (j = 0; j < 13; j = j + 1) begin
            assign numbers_mask[j+2][i] = (cards_num[i] == j+2);
        end
    end
endgenerate

// ---------- STRAIGHT start ----------

wire [12:0] straight_mask;

// wire [12:0] straight_mask;
assign straight_mask = {(|numbers_mask[2]),  (|numbers_mask[3]),  (|numbers_mask[4]),  (|numbers_mask[5]), 
                        (|numbers_mask[6]),  (|numbers_mask[7]),  (|numbers_mask[8]),  (|numbers_mask[9]), 
                        (|numbers_mask[10]), (|numbers_mask[11]), (|numbers_mask[12]), (|numbers_mask[13]), 
                        (|numbers_mask[14])};

// output reg has_straight,
always @(*) begin
    casex (straight_mask)
        13'bxxxxxxxx11111,
        13'bxxxxxxx11111x, 
        13'bxxxxxx11111xx, 
        13'bxxxxx11111xxx, 
        13'bxxxx11111xxxx, 
        13'bxxx11111xxxxx, 
        13'bxx11111xxxxxx, 
        13'bx11111xxxxxxx, 
        13'b11111xxxxxxxx,
        13'b1111xxxxxxxx1: has_straight = 1'b1;
        default: has_straight = 1'b0;
    endcase
end

// output reg [3:0]straight_key
always @(*) begin
    casex (straight_mask)
        13'bxxxxxxxx11111: straight_key = 4'd14;
        13'bxxxxxxx111110: straight_key = 4'd13;
        13'bxxxxxx111110x: straight_key = 4'd12;
        13'bxxxxx111110xx: straight_key = 4'd11;
        13'bxxxx111110xxx: straight_key = 4'd10;
        13'bxxx111110xxxx: straight_key = 4'd9;
        13'bxx111110xxxxx: straight_key = 4'd8;
        13'bx111110xxxxxx: straight_key = 4'd7;
        13'b111110xxxxxxx: straight_key = 4'd6;
        13'b11110xxxxxxx1: straight_key = 4'd5;
        default: straight_key = 4'd0;
    endcase
end

// ---------- STRAIGHT end ----------

// wire [2:0] numbers_num [2:14];      // 0 ~ 14
generate
    for (i = 0; i < 13; i = i + 1) begin: numbers_num_popcount
        POPCOUNT_7bits_LUT popcount (.data_in(numbers_mask[i+2]), .popcount(numbers_num[i+2]));
    end
endgenerate

// wire [12:0] is_four_mask, reverse_is_three_mask, reverse_is_two_mask;
generate
    for (i = 0; i < 13; i = i + 1) begin: numbers_num_same_num
        assign is_four_mask[i]             = numbers_num[i+2] == 3'd4;
        assign reverse_is_three_mask[12-i] = numbers_num[i+2] == 3'd3;
        assign reverse_is_two_mask[12-i]   = numbers_num[i+2] == 3'd2;
    end
endgenerate

// n & n - 1, set smallest 1 to 0
// wire [12:0] second_big_pair_mask;
assign second_big_pair_mask = reverse_is_two_mask & (reverse_is_two_mask - 13'd1);

// wire [12:0] second_three_mask;
assign second_three_mask = reverse_is_three_mask & (reverse_is_three_mask - 13'd1);

// output Four_of_a_Kind,
// output Full_House,
// output Three_of_a_Kind,
// output Two_Pair,
// output One_Pair,
assign Four_of_a_Kind  = (|is_four_mask);
assign Full_House      = (|reverse_is_three_mask) & (|reverse_is_two_mask) | (|second_three_mask);
assign Three_of_a_Kind = (|reverse_is_three_mask);
assign Two_Pair        = (|second_big_pair_mask);
assign One_Pair        = (|reverse_is_two_mask);

// output reg [3:0] Four_of_a_Kind_key,
always @(*) begin
    case (is_four_mask)
        13'h1000: Four_of_a_Kind_key = 4'd14;  // A
        13'h800:  Four_of_a_Kind_key = 4'd13;  // K
        13'h400:  Four_of_a_Kind_key = 4'd12;  // Q
        13'h200:  Four_of_a_Kind_key = 4'd11;  // J
        13'h100:  Four_of_a_Kind_key = 4'd10;  // 10
        13'h80:   Four_of_a_Kind_key = 4'd9;   // 9
        13'h40:   Four_of_a_Kind_key = 4'd8;   // 8
        13'h20:   Four_of_a_Kind_key = 4'd7;   // 7
        13'h10:   Four_of_a_Kind_key = 4'd6;   // 6
        13'h8:    Four_of_a_Kind_key = 4'd5;   // 5
        13'h4:    Four_of_a_Kind_key = 4'd4;   // 4
        13'h2:    Four_of_a_Kind_key = 4'd3;   // 3
        13'h1:    Four_of_a_Kind_key = 4'd2;   // 2
        default: Four_of_a_Kind_key = 4'd0;
    endcase
end

// reg [3:0] second_three_key;
always @(*) begin
    case (second_three_mask)
        // 13'bxxxxxxxxxxxx1: second_three_key = 4'd14;
        13'b0000000000010: second_three_key = 4'd13;
        13'b0000000000100: second_three_key = 4'd12;
        13'b0000000001000: second_three_key = 4'd11;
        13'b0000000010000: second_three_key = 4'd10;
        13'b0000000100000: second_three_key = 4'd9;
        13'b0000001000000: second_three_key = 4'd8;
        13'b0000010000000: second_three_key = 4'd7;
        13'b0000100000000: second_three_key = 4'd6;
        13'b0001000000000: second_three_key = 4'd5;
        13'b0010000000000: second_three_key = 4'd4;
        13'b0100000000000: second_three_key = 4'd3;
        13'b1000000000000: second_three_key = 4'd2;
        default: second_three_key = 4'd0;
    endcase
end

// output reg [3:0] Full_House_key1, Full_House_key2,
always @(*) begin
    Full_House_key1 = Three_of_a_Kind_key;
    if (|second_three_mask) Full_House_key2 = second_three_key;     // 3 + 3
    else                    Full_House_key2 = One_Pair_key;         // 3 + 2
end

// output reg [3:0] Three_of_a_Kind_key,
always @(*) begin
    casex (reverse_is_three_mask)
        13'bxxxxxxxxxxxx1: Three_of_a_Kind_key = 4'd14;
        13'bxxxxxxxxxxx10: Three_of_a_Kind_key = 4'd13;
        13'bxxxxxxxxxx100: Three_of_a_Kind_key = 4'd12;
        13'bxxxxxxxxx1000: Three_of_a_Kind_key = 4'd11;
        13'bxxxxxxxx10000: Three_of_a_Kind_key = 4'd10;
        13'bxxxxxxx100000: Three_of_a_Kind_key = 4'd9;
        13'bxxxxxx1000000: Three_of_a_Kind_key = 4'd8;
        13'bxxxxx10000000: Three_of_a_Kind_key = 4'd7;
        13'bxxxx100000000: Three_of_a_Kind_key = 4'd6;
        13'bxxx1000000000: Three_of_a_Kind_key = 4'd5;
        13'bxx10000000000: Three_of_a_Kind_key = 4'd4;
        13'bx100000000000: Three_of_a_Kind_key = 4'd3;
        13'b1000000000000: Three_of_a_Kind_key = 4'd2;
        default: Three_of_a_Kind_key = 4'd0;
    endcase
end

// assign second_big_pair_mask = reverse_is_two_mask & (reverse_is_two_mask - 13'd1);

// output reg [3:0] Two_Pair_key1, Two_Pair_key2,
always @(*) begin
    Two_Pair_key1 = One_Pair_key;
    casex (second_big_pair_mask)    // bits in reverse order
        // 13'bxxxxxxxxxxxx1: Two_Pair_key2 = 4'd14;
        13'bxxxxxxxxxxx10: Two_Pair_key2 = 4'd13;
        13'bxxxxxxxxxx100: Two_Pair_key2 = 4'd12;
        13'bxxxxxxxxx1000: Two_Pair_key2 = 4'd11;
        13'bxxxxxxxx10000: Two_Pair_key2 = 4'd10;
        13'bxxxxxxx100000: Two_Pair_key2 = 4'd9;
        13'bxxxxxx1000000: Two_Pair_key2 = 4'd8;
        13'bxxxxx10000000: Two_Pair_key2 = 4'd7;
        13'bxxxx100000000: Two_Pair_key2 = 4'd6;
        13'bxxx1000000000: Two_Pair_key2 = 4'd5;
        13'bxx10000000000: Two_Pair_key2 = 4'd4;
        13'bx100000000000: Two_Pair_key2 = 4'd3;
        13'b1000000000000: Two_Pair_key2 = 4'd2;
        default: Two_Pair_key2 = 4'd0;
    endcase
end

// output reg [3:0] One_Pair_key
always @(*) begin
    casex (reverse_is_two_mask)     // get smallest 1 ----> bigest num
        13'bxxxxxxxxxxxx1: One_Pair_key = 4'd14;
        13'bxxxxxxxxxxx10: One_Pair_key = 4'd13;
        13'bxxxxxxxxxx100: One_Pair_key = 4'd12;
        13'bxxxxxxxxx1000: One_Pair_key = 4'd11;
        13'bxxxxxxxx10000: One_Pair_key = 4'd10;
        13'bxxxxxxx100000: One_Pair_key = 4'd9;
        13'bxxxxxx1000000: One_Pair_key = 4'd8;
        13'bxxxxx10000000: One_Pair_key = 4'd7;
        13'bxxxx100000000: One_Pair_key = 4'd6;
        13'bxxx1000000000: One_Pair_key = 4'd5;
        13'bxx10000000000: One_Pair_key = 4'd4;
        13'bx100000000000: One_Pair_key = 4'd3;
        13'b1000000000000: One_Pair_key = 4'd2;
        default: One_Pair_key = 4'd0;
    endcase
end

endmodule

// -------------------------------------------

module POPCOUNT_7bits_LUT (
    input  [6:0] data_in,
    output reg [2:0] popcount
);

// always @(*) begin
//     popcount = data_in[0] + data_in[1] + data_in[2] + data_in[3] + data_in[4] + data_in[5] + data_in[6];
// end

always @(*) begin
    case (data_in)
        // Popcount = 0 (C(7,0) = 1)
        7'h00: popcount = 3'd0;

        // Popcount = 1 (C(7,1) = 7)
        7'h01, 7'h02, 7'h04, 7'h08, 7'h10, 7'h20, 7'h40: popcount = 3'd1;

        // Popcount = 2 (C(7,2) = 21)
        7'h03, 7'h05, 7'h06, 7'h09, 7'h0A, 7'h0C, 7'h11, 7'h12,
        7'h14, 7'h18, 7'h21, 7'h22, 7'h24, 7'h28, 7'h30, 7'h41,
        7'h42, 7'h44, 7'h48, 7'h50, 7'h60: popcount = 3'd2;

        // Popcount = 3 (C(7,3) = 35)
        7'h07, 7'h0B, 7'h0D, 7'h0E, 7'h13, 7'h15, 7'h16, 7'h19,
        7'h1A, 7'h1C, 7'h23, 7'h25, 7'h26, 7'h29, 7'h2A, 7'h2C,
        7'h31, 7'h32, 7'h34, 7'h38, 7'h43, 7'h45, 7'h46, 7'h49,
        7'h4A, 7'h4C, 7'h51, 7'h52, 7'h54, 7'h58, 7'h61, 7'h62,
        7'h64, 7'h68, 7'h70: popcount = 3'd3;

        // Popcount = 4 (C(7,4) = 35)
        7'h0F, 7'h17, 7'h1B, 7'h1D, 7'h1E, 7'h27, 7'h2B, 7'h2D,
        7'h2E, 7'h33, 7'h35, 7'h36, 7'h39, 7'h3A, 7'h3C, 7'h47,
        7'h4B, 7'h4D, 7'h4E, 7'h53, 7'h55, 7'h56, 7'h59, 7'h5A,
        7'h5C, 7'h63, 7'h65, 7'h66, 7'h69, 7'h6A, 7'h6C, 7'h71,
        7'h72, 7'h74, 7'h78: popcount = 3'd4;

        // Popcount = 5 (C(7,5) = 21)
        7'h1F, 7'h2F, 7'h37, 7'h3B, 7'h3D, 7'h3E, 7'h4F, 7'h57,
        7'h5B, 7'h5D, 7'h5E, 7'h67, 7'h6B, 7'h6D, 7'h6E, 7'h73,
        7'h75, 7'h76, 7'h79, 7'h7A, 7'h7C: popcount = 3'd5;

        // Popcount = 6 (C(7,6) = 7)
        7'h3F, 7'h5F, 7'h6F, 7'h77, 7'h7B, 7'h7D, 7'h7E: popcount = 3'd6;

        // Popcount = 7 (C(7,7) = 1)
        7'h7F: popcount = 3'd7;

        default: popcount = 3'd0;
    endcase
end

endmodule



module PLAYERS_CMP_9 (
    input [23:0] player_strength [0:8],
    output reg [8:0] winner_mask
);

reg [23:0] layer0_0, layer0_1, layer0_2, layer0_3;
reg [23:0] layer1_0, layer1_1;
reg [23:0] layer2_0;

reg [8:0] mask0_0, mask0_1, mask0_2, mask0_3;
reg [8:0] mask1_0, mask1_1;
reg [8:0] mask2_0;

always @(*) begin
    // layer0
    // layer0_0
    // mask0_0
    if (player_strength[0] > player_strength[1]) begin
        layer0_0 = player_strength[0];
        mask0_0 = 9'b000000001;
    end
    else if (player_strength[0] == player_strength[1]) begin
        layer0_0 = player_strength[0];
        mask0_0 = 9'b000000011;
    end
    else begin
        layer0_0 = player_strength[1];
        mask0_0 = 9'b000000010;
    end

    // layer0_1
    // mask0_1
    if (player_strength[2] > player_strength[3]) begin
        layer0_1 = player_strength[2];
        mask0_1 = 9'b000000100;
    end
    else if (player_strength[2] == player_strength[3]) begin
        layer0_1 = player_strength[2];
        mask0_1 = 9'b000001100;
    end
    else begin
        layer0_1 = player_strength[3];
        mask0_1 = 9'b000001000;
    end

    // layer0_2
    // mask0_2
    if (player_strength[4] > player_strength[5]) begin
        layer0_2 = player_strength[4];
        mask0_2 = 9'b000010000;
    end
    else if (player_strength[4] == player_strength[5]) begin
        layer0_2 = player_strength[4];
        mask0_2 = 9'b000110000;
    end
    else begin
        layer0_2 = player_strength[5];
        mask0_2 = 9'b000100000;
    end

    // layer0_3
    // mask0_3
    if (player_strength[6] > player_strength[7]) begin
        layer0_3 = player_strength[6];
        mask0_3 = 9'b001000000;
    end
    else if (player_strength[6] == player_strength[7]) begin
        layer0_3 = player_strength[6];
        mask0_3 = 9'b011000000;
    end
    else begin
        layer0_3 = player_strength[7];
        mask0_3 = 9'b010000000;
    end

    // layer1
    // layer1_0
    // mask1_0
    if (layer0_0 > layer0_1) begin
        layer1_0 = layer0_0;
        mask1_0 = mask0_0;
    end
    else if (layer0_0 == layer0_1) begin
        layer1_0 = layer0_0;
        mask1_0 = mask0_0 | mask0_1;
    end
    else begin
        layer1_0 = layer0_1;
        mask1_0 = mask0_1;
    end

    // layer1_1
    // mask1_1
    if (layer0_2 > layer0_3) begin
        layer1_1 = layer0_2;
        mask1_1 = mask0_2;
    end
    else if (layer0_2 == layer0_3) begin
        layer1_1 = layer0_2;
        mask1_1 = mask0_2 | mask0_3;
    end
    else begin
        layer1_1 = layer0_3;
        mask1_1 = mask0_3;
    end

    // layer2
    // layer2_0
    // mask2_0
    if (layer1_0 > layer1_1) begin
        layer2_0 = layer1_0;
        mask2_0 = mask1_0;
    end
    else if (layer1_0 == layer1_1) begin
        layer2_0 = layer1_0;
        mask2_0 = mask1_0 | mask1_1;
    end
    else begin
        layer2_0 = layer1_1;
        mask2_0 = mask1_1;
    end

    // winner_mask
    if (layer2_0 > player_strength[8]) begin
        winner_mask = mask2_0;
    end
    else if (layer2_0 == player_strength[8]) begin
        winner_mask = mask2_0 | 9'b100000000;
    end
    else begin
        winner_mask = 9'b100000000;
    end
end

endmodule


module PLAYERS_CMP_8 (
    input [23:0] player_strength [0:7],
    output reg [7:0] winner_mask
);

reg [23:0] layer0_0, layer0_1, layer0_2, layer0_3;
reg [23:0] layer1_0, layer1_1;

reg [7:0] mask0_0, mask0_1, mask0_2, mask0_3;
reg [7:0] mask1_0, mask1_1;

always @(*) begin
    // layer0
    // layer0_0
    // mask0_0
    if (player_strength[0] > player_strength[1]) begin
        layer0_0 = player_strength[0];
        mask0_0 = 8'b00000001;
    end
    else if (player_strength[0] == player_strength[1]) begin
        layer0_0 = player_strength[0];
        mask0_0 = 8'b00000011;
    end
    else begin
        layer0_0 = player_strength[1];
        mask0_0 = 8'b00000010;
    end

    // layer0_1
    // mask0_1
    if (player_strength[2] > player_strength[3]) begin
        layer0_1 = player_strength[2];
        mask0_1 = 8'b00000100;
    end
    else if (player_strength[2] == player_strength[3]) begin
        layer0_1 = player_strength[2];
        mask0_1 = 8'b00001100;
    end
    else begin
        layer0_1 = player_strength[3];
        mask0_1 = 8'b00001000;
    end

    // layer0_2
    // mask0_2
    if (player_strength[4] > player_strength[5]) begin
        layer0_2 = player_strength[4];
        mask0_2 = 8'b00010000;
    end
    else if (player_strength[4] == player_strength[5]) begin
        layer0_2 = player_strength[4];
        mask0_2 = 8'b00110000;
    end
    else begin
        layer0_2 = player_strength[5];
        mask0_2 = 8'b00100000;
    end

    // layer0_3
    // mask0_3
    if (player_strength[6] > player_strength[7]) begin
        layer0_3 = player_strength[6];
        mask0_3 = 8'b01000000;
    end
    else if (player_strength[6] == player_strength[7]) begin
        layer0_3 = player_strength[6];
        mask0_3 = 8'b11000000;
    end
    else begin
        layer0_3 = player_strength[7];
        mask0_3 = 8'b10000000;
    end

    // layer1
    // layer1_0
    // mask1_0
    if (layer0_0 > layer0_1) begin
        layer1_0 = layer0_0;
        mask1_0 = mask0_0;
    end
    else if (layer0_0 == layer0_1) begin
        layer1_0 = layer0_0;
        mask1_0 = mask0_0 | mask0_1;
    end
    else begin
        layer1_0 = layer0_1;
        mask1_0 = mask0_1;
    end

    // layer1_1
    // mask1_1
    if (layer0_2 > layer0_3) begin
        layer1_1 = layer0_2;
        mask1_1 = mask0_2;
    end
    else if (layer0_2 == layer0_3) begin
        layer1_1 = layer0_2;
        mask1_1 = mask0_2 | mask0_3;
    end
    else begin
        layer1_1 = layer0_3;
        mask1_1 = mask0_3;
    end

    // winner_mask
    if (layer1_0 > layer1_1) begin
        winner_mask = mask1_0;
    end
    else if (layer1_0 == layer1_1) begin
        winner_mask = mask1_0 | mask1_1;
    end
    else begin
        winner_mask = mask1_1;
    end
end

endmodule

module PLAYERS_CMP_7 (
    input [23:0] player_strength [0:6],
    output reg [6:0] winner_mask
);

reg [23:0] layer0_0, layer0_1, layer0_2;
reg [23:0] layer1_0, layer1_1;

reg [6:0] mask0_0, mask0_1, mask0_2;
reg [6:0] mask1_0, mask1_1;

always @(*) begin
    // layer0
    // layer0_0
    // mask0_0
    if (player_strength[0] > player_strength[1]) begin
        layer0_0 = player_strength[0];
        mask0_0 = 7'b0000001;
    end
    else if (player_strength[0] == player_strength[1]) begin
        layer0_0 = player_strength[0];
        mask0_0 = 7'b0000011;
    end
    else begin
        layer0_0 = player_strength[1];
        mask0_0 = 7'b0000010;
    end

    // layer0_1
    // mask0_1
    if (player_strength[2] > player_strength[3]) begin
        layer0_1 = player_strength[2];
        mask0_1 = 7'b0000100;
    end
    else if (player_strength[2] == player_strength[3]) begin
        layer0_1 = player_strength[2];
        mask0_1 = 7'b0001100;
    end
    else begin
        layer0_1 = player_strength[3];
        mask0_1 = 7'b0001000;
    end

    // layer0_2
    // mask0_2
    if (player_strength[4] > player_strength[5]) begin
        layer0_2 = player_strength[4];
        mask0_2 = 7'b0010000;
    end
    else if (player_strength[4] == player_strength[5]) begin
        layer0_2 = player_strength[4];
        mask0_2 = 7'b0110000;
    end
    else begin
        layer0_2 = player_strength[5];
        mask0_2 = 7'b0100000;
    end

    // layer1
    // layer1_0
    // mask1_0
    if (layer0_0 > layer0_1) begin
        layer1_0 = layer0_0;
        mask1_0 = mask0_0;
    end
    else if (layer0_0 == layer0_1) begin
        layer1_0 = layer0_0;
        mask1_0 = mask0_0 | mask0_1;
    end
    else begin
        layer1_0 = layer0_1;
        mask1_0 = mask0_1;
    end

    // layer1_1
    // mask1_1
    if (layer0_2 > player_strength[6]) begin
        layer1_1 = layer0_2;
        mask1_1 = mask0_2;
    end
    else if (layer0_2 == player_strength[6]) begin
        layer1_1 = layer0_2;
        mask1_1 = mask0_2 | 7'b1000000;
    end
    else begin
        layer1_1 = player_strength[6];
        mask1_1 = 7'b1000000;
    end

    // winner_mask
    if (layer1_0 > layer1_1) begin
        winner_mask = mask1_0;
    end
    else if (layer1_0 == layer1_1) begin
        winner_mask = mask1_0 | mask1_1;
    end
    else begin
        winner_mask = mask1_1;
    end
end

endmodule


module PLAYERS_CMP_6 (
    input [23:0] player_strength [0:5],
    output reg [5:0] winner_mask
);

reg [23:0] layer0_0, layer0_1, layer0_2;
reg [23:0] layer1_0;

reg [5:0] mask0_0, mask0_1, mask0_2;
reg [5:0] mask1_0;

always @(*) begin
    // layer0
    // layer0_0
    // mask0_0
    if (player_strength[0] > player_strength[1]) begin
        layer0_0 = player_strength[0];
        mask0_0 = 6'b000001;
    end
    else if (player_strength[0] == player_strength[1]) begin
        layer0_0 = player_strength[0];
        mask0_0 = 6'b000011;
    end
    else begin
        layer0_0 = player_strength[1];
        mask0_0 = 6'b000010;
    end

    // layer0_1
    // mask0_1
    if (player_strength[2] > player_strength[3]) begin
        layer0_1 = player_strength[2];
        mask0_1 = 6'b000100;
    end
    else if (player_strength[2] == player_strength[3]) begin
        layer0_1 = player_strength[2];
        mask0_1 = 6'b001100;
    end
    else begin
        layer0_1 = player_strength[3];
        mask0_1 = 6'b001000;
    end

    // layer0_2
    // mask0_2
    if (player_strength[4] > player_strength[5]) begin
        layer0_2 = player_strength[4];
        mask0_2 = 6'b010000;
    end
    else if (player_strength[4] == player_strength[5]) begin
        layer0_2 = player_strength[4];
        mask0_2 = 6'b110000;
    end
    else begin
        layer0_2 = player_strength[5];
        mask0_2 = 6'b100000;
    end

    // layer1
    // layer1_0
    // mask1_0
    if (layer0_0 > layer0_1) begin
        layer1_0 = layer0_0;
        mask1_0 = mask0_0;
    end
    else if (layer0_0 == layer0_1) begin
        layer1_0 = layer0_0;
        mask1_0 = mask0_0 | mask0_1;
    end
    else begin
        layer1_0 = layer0_1;
        mask1_0 = mask0_1;
    end

    // winner_mask
    if (layer1_0 > layer0_2) begin
        winner_mask = mask1_0;
    end
    else if (layer1_0 == layer0_2) begin
        winner_mask = mask1_0 | mask0_2;
    end
    else begin
        winner_mask = mask0_2;
    end
end

endmodule


module PLAYERS_CMP_5 (
    input [23:0] player_strength [0:4],
    output reg [4:0] winner_mask
);

reg [23:0] layer0_0, layer0_1;
reg [23:0] layer1_0;

reg [4:0] mask0_0, mask0_1;
reg [4:0] mask1_0;

always @(*) begin
    // layer0
    // layer0_0
    // mask0_0
    if (player_strength[0] > player_strength[1]) begin
        layer0_0 = player_strength[0];
        mask0_0 = 5'b00001;
    end
    else if (player_strength[0] == player_strength[1]) begin
        layer0_0 = player_strength[0];
        mask0_0 = 5'b00011;
    end
    else begin
        layer0_0 = player_strength[1];
        mask0_0 = 5'b00010;
    end

    // layer0_1
    // mask0_1
    if (player_strength[2] > player_strength[3]) begin
        layer0_1 = player_strength[2];
        mask0_1 = 5'b00100;
    end
    else if (player_strength[2] == player_strength[3]) begin
        layer0_1 = player_strength[2];
        mask0_1 = 5'b01100;
    end
    else begin
        layer0_1 = player_strength[3];
        mask0_1 = 5'b01000;
    end

    // layer1
    // layer1_0
    // mask1_0
    if (layer0_0 > layer0_1) begin
        layer1_0 = layer0_0;
        mask1_0 = mask0_0;
    end
    else if (layer0_0 == layer0_1) begin
        layer1_0 = layer0_0;
        mask1_0 = mask0_0 | mask0_1;
    end
    else begin
        layer1_0 = layer0_1;
        mask1_0 = mask0_1;
    end

    // winner_mask
    if (layer1_0 > player_strength[4]) begin
        winner_mask = mask1_0;
    end
    else if (layer1_0 == player_strength[4]) begin
        winner_mask = mask1_0 | 5'b10000;
    end
    else begin
        winner_mask = 5'b10000;
    end
end

endmodule


module PLAYERS_CMP_4 (
    input [23:0] player_strength [0:3],
    output reg [3:0] winner_mask
);

reg [23:0] layer0_0, layer0_1;
reg [23:0] layer1_0;

reg [3:0] mask0_0, mask0_1;
reg [3:0] mask1_0;

always @(*) begin
    // layer0
    // layer0_0
    // mask0_0
    if (player_strength[0] > player_strength[1]) begin
        layer0_0 = player_strength[0];
        mask0_0 = 4'b0001;
    end
    else if (player_strength[0] == player_strength[1]) begin
        layer0_0 = player_strength[0];
        mask0_0 = 4'b0011;
    end
    else begin
        layer0_0 = player_strength[1];
        mask0_0 = 4'b0010;
    end

    // layer0_1
    // mask0_1
    if (player_strength[2] > player_strength[3]) begin
        layer0_1 = player_strength[2];
        mask0_1 = 4'b0100;
    end
    else if (player_strength[2] == player_strength[3]) begin
        layer0_1 = player_strength[2];
        mask0_1 = 4'b1100;
    end
    else begin
        layer0_1 = player_strength[3];
        mask0_1 = 4'b1000;
    end

    // winner_mask
    if (layer0_0 > layer0_1) begin
        winner_mask = mask0_0;
    end
    else if (layer0_0 == layer0_1) begin
        winner_mask = mask0_0 | mask0_1;
    end
    else begin
        winner_mask = mask0_1;
    end
end

endmodule


module PLAYERS_CMP_3 (
    input [23:0] player_strength [0:2],
    output reg [2:0] winner_mask
);

reg [23:0] layer0_0;

reg [2:0] mask0_0;

always @(*) begin
    // layer0
    // layer0_0
    // mask0_0
    if (player_strength[0] > player_strength[1]) begin
        layer0_0 = player_strength[0];
        mask0_0 = 3'b001;
    end
    else if (player_strength[0] == player_strength[1]) begin
        layer0_0 = player_strength[0];
        mask0_0 = 3'b011;
    end
    else begin
        layer0_0 = player_strength[1];
        mask0_0 = 3'b010;
    end

    // winner_mask
    if (layer0_0 > player_strength[2]) begin
        winner_mask = mask0_0;
    end
    else if (layer0_0 == player_strength[2]) begin
        winner_mask = mask0_0 | 3'b100;
    end
    else begin
        winner_mask = 3'b100;
    end
end

endmodule


module PLAYERS_CMP_2 (
    input [23:0] player_strength [0:1],
    output reg [1:0] winner_mask
);

always @(*) begin
    // winner_mask
    if (player_strength[0] > player_strength[1]) begin
        winner_mask = 2'b01;
    end
    else if (player_strength[0] == player_strength[1]) begin
        winner_mask = 2'b11;
    end
    else begin
        winner_mask = 2'b10;
    end
end

endmodule
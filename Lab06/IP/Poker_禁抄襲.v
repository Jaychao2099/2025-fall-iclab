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
wire [23:0] player_rank [IP_WIDTH-1:0];
wire rank_comparator[IP_WIDTH-1:0][IP_WIDTH-1:0];
wire rank_equal[IP_WIDTH-1:0][IP_WIDTH-1:0];
wire player_result [IP_WIDTH-1:0][IP_WIDTH-2:0];
genvar i;
genvar j;
// ===============================================================
// Design
// ===============================================================

generate
    for(i=0; i<IP_WIDTH; i=i+1) begin : loop_Poker_sort
        Poker_sort  PLAYER_CARD_RANK (.IN_CARD_NUM({IN_PUB_CARD_NUM, IN_HOLE_CARD_NUM[8*i+7:8*i]}), .IN_CARD_SUIT({IN_PUB_CARD_SUIT, IN_HOLE_CARD_SUIT[4*i+3:4*i]}), .OUT_RANK(player_rank[i]));
    end
endgenerate

//rank_sort
generate
    for(i=0; i<IP_WIDTH; i=i+1) begin : loop_rank_sort
        for(j=0; j<IP_WIDTH; j=j+1) begin
            if(i<j) begin
                assign rank_comparator[i][j] = player_rank[i] > player_rank[j];
                assign rank_equal[i][j] = player_rank[i] == player_rank[j];
                assign player_result[i][j-1] = rank_comparator[i][j] || rank_equal[i][j];
            end
            else if (i>j) begin
                assign player_result[i][j] = !rank_comparator[j][i];
            end     
        end
    end
endgenerate

generate
    for(i=0; i<IP_WIDTH; i=i+1) begin
        case (IP_WIDTH)
            2: begin
                assign OUT_WINNER[i] = player_result[i][0];
            end
            3: begin
                assign OUT_WINNER[i] = player_result[i][0] && player_result[i][1];
            end
            4: begin
                assign OUT_WINNER[i] = player_result[i][0] && player_result[i][1] && player_result[i][2];
            end
            5: begin
                assign OUT_WINNER[i] = player_result[i][0] && player_result[i][1] && player_result[i][2] && player_result[i][3];
            end
            6: begin
                assign OUT_WINNER[i] = player_result[i][0] && player_result[i][1] && player_result[i][2] && player_result[i][3] && player_result[i][4];
            end
            7: begin
                assign OUT_WINNER[i] = player_result[i][0] && player_result[i][1] && player_result[i][2] && player_result[i][3] && player_result[i][4] && player_result[i][5];
            end
            8: begin
                assign OUT_WINNER[i] = player_result[i][0] && player_result[i][1] && player_result[i][2] && player_result[i][3] && player_result[i][4] && player_result[i][5] && player_result[i][6];
            end
            9: begin
                assign OUT_WINNER[i] = player_result[i][0] && player_result[i][1] && player_result[i][2] && player_result[i][3] && player_result[i][4] && player_result[i][5] && player_result[i][6] && player_result[i][7];
            end
        endcase
    end
endgenerate


endmodule

module Poker_sort  (
    // Input signals
    IN_CARD_NUM, IN_CARD_SUIT, 
    // Output signals
    OUT_RANK
);

// ===============================================================
// Input & Output
// ===============================================================
input [27:0]  IN_CARD_NUM;
input [13:0]  IN_CARD_SUIT;
output [23:0]  OUT_RANK;
// ===============================================================
// Reg & Wire
// ===============================================================
wire [5:0] Q0, Q1, Q2, Q3, Q4, Q5, Q6;
wire [3:0] num[6:0];
wire [1:0] suit[6:0];
wire [5:0] Q0_s, Q1_s, Q2_s, Q3_s, Q4_s, Q5_s, Q6_s;
wire [3:0] num_s[6:0];
wire [1:0] suit_s[6:0];

reg [3:0] best_card[4:0];
reg [3:0] rank_type;

wire [3:0] card_num[6:0];
wire [1:0] card_suit[6:0];

//straight_flush
wire [3:0] dif_s[5:0];
wire dif_equal_one_s[5:0];
wire find_ace_s, straight_flush_two_to_five_0_3, straight_flush_two_to_five_1_4, straight_flush_two_to_five_2_5;
reg have_straight_flush;
reg [3:0]straight_flush_head;

//four_of_a_kind
wire same_num [5:0];
wire [2:0] same_num_sum;
wire [3:0]four_of_a_kind_head[1:0];
wire have_four_of_a_kind;

//full_house
wire have_full_house;
reg [3:0] full_house_head[1:0];

//flush
wire [1:0] max_suit;
wire have_flush;
wire flush_2_6, flush_1_5, flush_0_4;
reg [3:0] flush_head [4:0];

//straight
wire [3:0] dif[5:0];
wire dif_type[5:0];
wire dif_equal_one[5:0];
wire [2:0] dif_type_sum, dif_equal_one_sum;
wire find_three, find_four, find_five;
reg have_straight;
reg [3:0]straight_head;

// three_of_a_Kind
wire have_three_of_a_kind;
reg [3:0]three_of_a_kind_head[2:0];

// two_pair
wire have_two_pair;
reg [3:0]two_pair_head[2:0];

// one_pair
wire have_one_pair;
reg [3:0]one_pair_head[3:0];


parameter HIGH_CARD = 'd0;
parameter ONE_PAIR = 'd1;
parameter TWO_PAIR = 'd2;
parameter THREE_OF_A_KIND = 'd3;
parameter STRAIGHT = 'd4;
parameter FLUSH = 'd5;
parameter FULL_HOUSE = 'd6;
parameter FOUR_OF_A_KIND = 'd7;
parameter STRAIGHT_FLUSH = 'd8;

parameter A = 'd14;
parameter J = 'd11;
parameter Q = 'd12;
parameter K = 'd13;

parameter CLUB = 'd0;
parameter DIAMOND = 'd1;
parameter HEART = 'd2;
parameter SPADE = 'd3;

genvar i;
// ===============================================================
// Design
// ===============================================================

generate
    for(i=0; i<7; i=i+1) begin : loop_card
        assign card_num[i] = IN_CARD_NUM[i*4+3:i*4];
        assign card_suit[i] = IN_CARD_SUIT[i*2+1:i*2];
    end 
endgenerate

//sort
SORT SORT_Queue (.A({card_num[0], card_suit[0]}), .B({card_num[1], card_suit[1]}), .C({card_num[2], card_suit[2]}),
.D({card_num[3], card_suit[3]}), .E({card_num[4], card_suit[4]}), .F({card_num[5], card_suit[5]}), .G({card_num[6], card_suit[6]}),
.Q0(Q0), .Q1(Q1), .Q2(Q2), .Q3(Q3), .Q4(Q4), .Q5(Q5), .Q6(Q6));

SORT SORT_SUIT_Queue (.A({card_suit[0], card_num[0]}), .B({card_suit[1], card_num[1]}), .C({card_suit[2], card_num[2]}),
.D({card_suit[3], card_num[3]}), .E({card_suit[4], card_num[4]}), .F({card_suit[5], card_num[5]}), .G({card_suit[6], card_num[6]}),
.Q0(Q0_s), .Q1(Q1_s), .Q2(Q2_s), .Q3(Q3_s), .Q4(Q4_s), .Q5(Q5_s), .Q6(Q6_s));

assign num[0] = Q0[5:2];
assign suit[0] = Q0[1:0];
assign num[1] = Q1[5:2];
assign suit[1] = Q1[1:0];
assign num[2] = Q2[5:2];
assign suit[2] = Q2[1:0];
assign num[3] = Q3[5:2];
assign suit[3] = Q3[1:0];
assign num[4] = Q4[5:2];
assign suit[4] = Q4[1:0];
assign num[5] = Q5[5:2];
assign suit[5] = Q5[1:0];
assign num[6] = Q6[5:2];
assign suit[6] = Q6[1:0];


assign num_s[0] = Q0_s[3:0];
assign suit_s[0] = Q0_s[5:4];
assign num_s[1] = Q1_s[3:0];
assign suit_s[1] = Q1_s[5:4];
assign num_s[2] = Q2_s[3:0];
assign suit_s[2] = Q2_s[5:4];
assign num_s[3] = Q3_s[3:0];
assign suit_s[3] = Q3_s[5:4];
assign num_s[4] = Q4_s[3:0];
assign suit_s[4] = Q4_s[5:4];
assign num_s[5] = Q5_s[3:0];
assign suit_s[5] = Q5_s[5:4];
assign num_s[6] = Q6_s[3:0];
assign suit_s[6] = Q6_s[5:4];

assign OUT_RANK = {rank_type, best_card[4], best_card[3], best_card[2], best_card[1], best_card[0]};

always @(*) begin
    if(have_straight_flush) begin
        rank_type = STRAIGHT_FLUSH;
        best_card[4] = straight_flush_head;
        best_card[3] = 0;
        best_card[2] = 0;
        best_card[1] = 0;
        best_card[0] = 0;
    end
    else if(have_four_of_a_kind) begin
        rank_type = FOUR_OF_A_KIND;
        best_card[4] = four_of_a_kind_head[1];
        best_card[3] = four_of_a_kind_head[0];
        best_card[2] = 0;
        best_card[1] = 0;
        best_card[0] = 0;
    end
    else if(have_full_house) begin
        rank_type = FULL_HOUSE;
        best_card[4] = full_house_head[1];
        best_card[3] = full_house_head[0];
        best_card[2] = 0;
        best_card[1] = 0;
        best_card[0] = 0;
    end
    else if(have_flush) begin
        rank_type = FLUSH;
        best_card[4] = flush_head[4];
        best_card[3] = flush_head[3];
        best_card[2] = flush_head[2];
        best_card[1] = flush_head[1];
        best_card[0] = flush_head[0];
    end
    else if(have_straight) begin
        rank_type = STRAIGHT;
        best_card[4] = straight_head;
        best_card[3] = 0;
        best_card[2] = 0;
        best_card[1] = 0;
        best_card[0] = 0;
    end
    else if(have_three_of_a_kind) begin
        rank_type = THREE_OF_A_KIND;
        best_card[4] = three_of_a_kind_head[2];
        best_card[3] = three_of_a_kind_head[1];
        best_card[2] = three_of_a_kind_head[0];
        best_card[1] = 0;
        best_card[0] = 0;
    end
    else if(have_two_pair) begin
        rank_type = TWO_PAIR;
        best_card[4] = two_pair_head[2];
        best_card[3] = two_pair_head[1];
        best_card[2] = two_pair_head[0];
        best_card[1] = 0;
        best_card[0] = 0;
    end
    else if(have_one_pair) begin
        rank_type = ONE_PAIR;
        best_card[4] = one_pair_head[3];
        best_card[3] = one_pair_head[2];
        best_card[2] = one_pair_head[1];
        best_card[1] = one_pair_head[0];
        best_card[0] = 0;
    end
    else begin
        rank_type = HIGH_CARD;
        best_card[4] = num[6];
        best_card[3] = num[5];
        best_card[2] = num[4];
        best_card[1] = num[3];
        best_card[0] = num[2];
    end
end


//straight_flush
assign flush_2_6 = suit_s[2] == suit_s[6];
assign flush_1_5 = suit_s[1] == suit_s[5];
assign flush_0_4 = suit_s[0] == suit_s[4];

assign max_suit = suit_s[3];
assign find_ace_s = ((num_s[4] == A) && (suit_s[4] == max_suit)) || ((num_s[5] == A) && (suit_s[5] == max_suit)) || ((num_s[6] == A) && (suit_s[6] == max_suit));
assign straight_flush_two_to_five_0_3 = (num_s[0] == 2) && (num_s[3] == 5) && (suit_s[0] == suit_s[3]);
assign straight_flush_two_to_five_1_4 = (num_s[1] == 2) && (num_s[4] == 5) && (suit_s[1] == suit_s[4]);
assign straight_flush_two_to_five_2_5 = (num_s[2] == 2) && (num_s[5] == 5) && (suit_s[2] == suit_s[5]);
/*
generate
    for(i=0; i<=5; i=i+1) begin : loop_dif_s
        assign dif_s[i] = num_s[i+1] - num_s[i];
        assign dif_equal_one_s[i] = (dif[i]==1) && (suit_s[i+1] == suit_s[i]) ;
    end 
endgenerate
*/
always @(*) begin
    if(flush_2_6 && (num_s[2] + 4 == num_s[6])) begin
        have_straight_flush = 1;
        straight_flush_head = num_s[6];
    end
    else if(flush_1_5 && (num_s[1] + 4 == num_s[5])) begin
        have_straight_flush = 1;
        straight_flush_head = num_s[5];
    end
    else if(flush_0_4 && (num_s[0] + 4 == num_s[4])) begin
        have_straight_flush = 1;
        straight_flush_head = num_s[4];
    end
    else if(find_ace_s && (straight_flush_two_to_five_0_3 || straight_flush_two_to_five_1_4 || straight_flush_two_to_five_2_5)) begin
        have_straight_flush = 1;
        straight_flush_head = 5;
    end
    else begin
        have_straight_flush = 0;
        straight_flush_head = 0;
    end
end
 
//four_of_a_kind
generate 
    for(i=0; i<6; i=i+1) begin : loop_same_num
        assign same_num[i] = num[i+1] == num[i];
    end 
endgenerate

assign four_of_a_kind_head[1] = num[3];
assign four_of_a_kind_head[0] = (num[3] == num[6])? num[2] : num[6];
assign have_four_of_a_kind = ((same_num[0] || same_num[3]) && same_num[1] && same_num[2]) || ((same_num[2] || same_num[5]) && same_num[3] && same_num[4]);

//full_house
assign same_num_sum = (same_num[0] + same_num[1]) + (same_num[2] + same_num[3]) + (same_num[4] + same_num[5]) ;
assign have_full_house = (same_num_sum > 2) && have_three_of_a_kind;

/*
012 345 6
0123 456
01 234 56
0 123 456
012 3456
*/

always @(*) begin
    if(same_num[4] && (same_num[3] || same_num[5])) begin
        full_house_head[1] = num[4];
        if(same_num[2]) full_house_head[0] = num[2];
        else full_house_head[0] = num[1];
    end    
    else begin
        full_house_head[1] = num[2];
        if(same_num[4] || same_num[5]) full_house_head[0] = num[5];
        else if (!same_num[2] && same_num[3]) full_house_head[0] = num[3];
        else full_house_head[0] = num[1];
    end    
end

//flush
assign have_flush = flush_2_6 || flush_1_5 || flush_0_4;

always @(*) begin
    if(flush_2_6) begin
        flush_head[4] = num_s[6];
        flush_head[3] = num_s[5];
        flush_head[2] = num_s[4];
        flush_head[1] = num_s[3];
        flush_head[0] = num_s[2];
    end
    else if(flush_1_5) begin
        flush_head[4] = num_s[5];
        flush_head[3] = num_s[4];
        flush_head[2] = num_s[3];
        flush_head[1] = num_s[2];
        flush_head[0] = num_s[1];
    end
    else begin
        flush_head[4] = num_s[4];
        flush_head[3] = num_s[3];
        flush_head[2] = num_s[2];
        flush_head[1] = num_s[1];
        flush_head[0] = num_s[0];
    end
end

//straight
generate
    for(i=0; i<=5; i=i+1) begin : loop_dif
        assign dif[i] = num[i+1] - num[i];
        assign dif_type[i] = (dif[i]<2) ;
        assign dif_equal_one[i] = (dif[i]==1) ;
    end 
endgenerate

assign dif_equal_one_sum = ((dif_equal_one[0] + dif_equal_one[1]) + ((dif_equal_one[2]) + (dif_equal_one[3]))) + ((dif_equal_one[4]) + (dif_equal_one[5]));
//assign dif_type_sum = ((dif_type[0] + dif_type[1]) + ((dif_type[2]) + (dif_type[3]))) + ((dif_type[4]) + (dif_type[5]));
assign find_three = (num[1] == 3) || (num[2] == 3) || (num[3] == 3);
assign find_four =  (num[2] == 4) || (num[3] == 4) || (num[4] == 4);
assign find_five = (num[3] == 5) || (num[4] == 5) || (num[5] == 5);

always @(*) begin
    if(dif_equal_one_sum>3) begin
        case ({dif_type[0], dif_type[1], dif_type[2], dif_type[3], dif_type[4], dif_type[5]})
            'b111111: begin //2345678 2334567 2333456
                have_straight = 1;
                straight_head = num[6];
            end
            'b011111: begin //2455678 2456789
                have_straight = 1;
                straight_head = num[6];
            end
            'b111110: begin //2345568 2345679
                have_straight = 1;
                straight_head = num[5];
            end
            'b101111: begin
                if(dif_equal_one[2] & dif_equal_one[3] & dif_equal_one[4] & dif_equal_one[5]) begin //2356789
                    have_straight = 1;
                    straight_head = num[6];
                end
                else begin //2356778
                    have_straight = 0;
                    straight_head = 0;
                end
            end
            'b001111: begin //246789T
                have_straight = 1;
                straight_head = num[6];
            end
            'b011110: begin //245678T
                have_straight = 1;
                straight_head = num[5];
            end
            'b111100: begin //234568T
                have_straight = 1;
                straight_head = num[4];
            end
            'b111101: begin
                if(dif_equal_one[0] & dif_equal_one[1] & dif_equal_one[2] & dif_equal_one[3]) begin //2345678
                    have_straight = 1;
                    straight_head = num[4];
                end
                else if(num[6]==A && num[0]==2) begin // 23445KA
                    have_straight = 1;
                    straight_head = 'd5;
                end
                else begin // 23445
                    have_straight = 0;
                    straight_head = 0;
                end
            end
            default: begin
                if(num[6]==A && num[0]==2 && find_three && find_four && find_five) begin // 234578A
                    have_straight = 1;
                    straight_head = 'd5;
                end
                else begin
                    have_straight = 0;
                    straight_head = 0;
                end
            end
        endcase
    end
    else begin
        if(num[6]==A && num[0]==2 && find_three && find_four && find_five) begin // A234579
            have_straight = 1;
            straight_head = 'd5;
        end
        else begin
            have_straight = 0;
            straight_head = 0;
        end
    end
end

// Three_of_a_Kind
assign have_three_of_a_kind = ((same_num[0] || same_num[2]) && same_num[1]) || ((same_num[2] || same_num[4]) && same_num[3]) || (same_num[4]  && same_num[5]); 

always @(*) begin
    if(same_num[3] || same_num[4] || same_num[5]) three_of_a_kind_head[2] = num[4];
    else three_of_a_kind_head[2] = num[2];
end

always @(*) begin
    if(same_num[5]) begin
        three_of_a_kind_head[1] = num[3];
        three_of_a_kind_head[0] = num[2];
    end
    else if(same_num[4]) begin
        three_of_a_kind_head[1] = num[6];
        three_of_a_kind_head[0] = num[2];
    end
    else begin
        three_of_a_kind_head[1] = num[6];
        three_of_a_kind_head[0] = num[5];
    end
end

// two_pair
assign have_two_pair = same_num_sum > 1 ;
always @(*) begin
    if(same_num[4] || same_num[5]) begin
        two_pair_head[2] = num[5];
        if(same_num[2] || same_num[3]) two_pair_head[1] = num[3];
        else two_pair_head[1] = num[1];
    end
    else begin
        two_pair_head[2] = num[3];
        two_pair_head[1] = num[1];
    end
end

always @(*) begin
    if(same_num[5]) begin
        if(same_num[3]) two_pair_head[0] = num[2];
        else two_pair_head[0] = num[4];
    end    
    else two_pair_head[0] = num[6];
end

// one_pair
assign have_one_pair = (same_num_sum == 1) ;

always @(*) begin
    if(same_num[5] || same_num[4]) one_pair_head[3] = num[5]; //45 56
    else if(same_num[3] || same_num[2]) one_pair_head[3] = num[3]; //23 34
    else one_pair_head[3] = num[1];// 01 12
end

always @(*) begin
    if(same_num[5]) one_pair_head[2] = num[4];
    else one_pair_head[2] = num[6];
end

always @(*) begin 
    if(same_num[5] || same_num[4]) one_pair_head[1] = num[3]; 
    else one_pair_head[1] = num[5];
end

always @(*) begin
    if(same_num[5] || same_num[4] || same_num[3]) one_pair_head[0] = num[2];
    else one_pair_head[0] = num[4];
end

endmodule

module SORT(
    input [5:0] A,
	input [5:0] B,
	input [5:0] C,
	input [5:0] D,
	input [5:0] E,
    input [5:0] F,
    input [5:0] G,
    output reg[5:0] Q0,
	output reg[5:0] Q1,
	output reg[5:0] Q2,
	output reg[5:0] Q3,
	output reg[5:0] Q4,
    output reg[5:0] Q5,
    output reg[5:0] Q6
);
	wire AB, AC, AD, AE, AF, AG,
    BA, BC, BD, BE, BF, BG,
    CA, CB, CD, CE, CF, CG,
    DA, DB, DC, DE, DF, DG,
    EA, EB, EC, ED, EF, EG, 
    FA, FB, FC, FD, FE, FG,
    GA, GB, GC, GD, GE, GF;

    wire [2:0] QA;
	wire [2:0] QB;
	wire [2:0] QC;
	wire [2:0] QD;
	wire [2:0] QE;
    wire [2:0] QF;
    wire [2:0] QG;

	assign AB =A>B;
	assign AC =A>C;
	assign AD =A>D;
	assign AE =A>E;
    assign AF =A>F;
    assign AG =A>G;

	assign BA =!AB;
	assign BC =B>C;
	assign BD =B>D;
	assign BE =B>E;
    assign BF =B>F;
    assign BG =B>G;

	assign CA =!AC;
	assign CB =!BC;
	assign CD =C>D;
	assign CE =C>E;
    assign CF =C>F;
	assign CG =C>G;

	assign DA =!AD;
	assign DB =!BD;
	assign DC =!CD;
	assign DE =D>E;
    assign DF =D>F;
	assign DG =D>G;

	assign EA =!AE;
	assign EB =!BE;
	assign EC =!CE;
	assign ED =!DE;
    assign EF =E>F;
	assign EG =E>G;

    assign FA =!AF;
	assign FB =!BF;
	assign FC =!CF;
	assign FD =!DF;
    assign FE =!EF;
	assign FG =F>G;

    assign GA =!AG;
	assign GB =!BG;
	assign GC =!CG;
	assign GD =!DG;
    assign GE =!EG;
	assign GF =!FG;

	assign QA = (AB + AC) + (AD + AE) + (AF + AG);
	assign QB = (BA + BC) + (BD + BE) + (BF + BG);
	assign QC = (CA + CB) + (CD + CE) + (CF + CG);
	assign QD = (DA + DB) + (DC + DE) + (DF + DG);
	assign QE = (EA + EB) + (EC + ED) + (EF + EG);
    assign QF = (FA + FB) + (FC + FD) + (FE + FG);
    assign QG = (GA + GB) + (GC + GD) + (GE + GF);
	
	always @(*) begin
		if(QA==0) Q0 = A; 
		else if(QB==0) Q0 = B;
		else if(QC==0) Q0 = C;
		else if(QD==0) Q0 = D;
        else if(QE==0) Q0 = E;
        else if(QF==0) Q0 = F;
		else Q0 = G;
	end
	
	always @(*) begin
		if(QA==1) Q1 = A; 
		else if(QB==1) Q1 = B;
		else if(QC==1) Q1 = C;
		else if(QD==1) Q1 = D;
		else if(QE==1) Q1 = E;
        else if(QF==1) Q1 = F;
		else Q1 = G;
	end
	
	always @(*) begin
		if(QA==2) Q2 = A; 
		else if(QB==2) Q2 = B;
		else if(QC==2) Q2 = C;
		else if(QD==2) Q2 = D;
		else if(QE==2) Q2 = E;
        else if(QF==2) Q2 = F;
		else Q2 = G;
	end
	
	always @(*) begin
		if(QA==3) Q3 = A; 
		else if(QB==3) Q3 = B;
		else if(QC==3) Q3 = C;
		else if(QD==3) Q3 = D;
        else if(QE==3) Q3 = E;
        else if(QF==3) Q3 = F;
		else Q3 = G;
	end
		
	always @(*) begin
		if(QA==4) Q4 = A; 
		else if(QB==4) Q4 = B;
		else if(QC==4) Q4 = C;
		else if(QD==4) Q4 = D;
        else if(QE==4) Q4 = E;
        else if(QF==4) Q4 = F;
		else Q4 = G;
	end

    always @(*) begin
		if(QA==5) Q5 = A; 
		else if(QB==5) Q5 = B;
		else if(QC==5) Q5 = C;
		else if(QD==5) Q5 = D;
        else if(QE==5) Q5 = E;
        else if(QF==5) Q5 = F;
		else Q5 = G;
	end

     always @(*) begin
		if(QA==6) Q6 = A; 
		else if(QB==6) Q6 = B;
		else if(QC==6) Q6 = C;
		else if(QD==6) Q6 = D;
        else if(QE==6) Q6 = E;
        else if(QF==6) Q6 = F;
		else Q6 = G;
	end
	
endmodule


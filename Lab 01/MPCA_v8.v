module MPCA(
    // Input signals
    input [127:0] packets,
    input  [11:0] channel_load,
    input   [8:0] channel_capacity,
    input  [63:0] KEY,
    // Output signals
    output reg [15:0] grant_channel
);

//================================================================
//    Wire & Registers 
//================================================================

genvar r;

// ------------ decrypt ------------

wire [3:0] ch_load [0:2];        // 4 bit * 3
wire [2:0] ch_cap [0:2];         // 3 bit * 3
reg [15:0] k [0:3];     // 16 bit * 4
wire [15:0] packet_y [0:3], packet_x [0:3];
wire [15:0] de_packet_y[0:3], de_packet_x[0:3];

// ------------ decode ------------

reg req_valid [0:7];
reg [1:0] qos [0:7];
reg [3:0] pkt_len [0:7];
reg [1:0] congestion [0:7];
reg [1:0] prefer_ch [0:7];
reg [2:0] src_hint [0:7];
reg mode [0:7];

// ------------ Calculate Priority Scores ------------

wire signed [6:0] qos_signed [0:7];
wire signed [6:0] pkt_len_signed [0:7];
wire signed [6:0] congestion_signed [0:7];
wire signed [6:0] src_hint_signed [0:7];

reg signed [6:0] priority_score [0:7];   // 7 bit * 8 unsigned(-32 ~ 26) signed(-22 ~ 36)
wire [6:0] congestion_signed_m3 [0:7];

// ------------ sorted as the rule ------------

wire [2:0] rank_idx [0:7];     // rank_idx[0] = max priority_score's packet's index

// ------------ Packet Arbitration and Allocation ------------

reg [1:0] alloc_channel [0:7];      // 0 ~ 2, 3 = not allocate

wire [2:0] ch_cap_final [0:2];

reg [2:0] cap0_stages [0:8];    // [stage_index]
reg [2:0] cap1_stages [0:8];
reg [2:0] cap2_stages [0:8];

reg [1:0] pivot_stages [0:8];   // trace pivot changes

reg [1:0] alloc_channel_tmp [0:7];

reg [2:0] current_cap [0:2];
reg [1:0] current_pivot [0:7];
reg [1:0] current_search_ch1 [0:7], current_search_ch2 [0:7], current_search_ch3 [0:7];

// ------------ Mask ------------

wire [3:0] mask_score [0:7];    // 0 ~ 9
reg [4:0] mask [0:7];      // not yet % 10       = 0 ~ 23

reg [3:0] threshold [0:7];  // 7 ~ 12
wire [2:0] div_3_result [0:2]; // 0 ~ 5
reg failed [0:7];

// ------------ Global Rebalance ------------

reg [4:0] ch_load_new [0:2];        // (0 ~ 15) + (0 ~ 8) = (0 ~ 23)
wire [1:0] max_ch;  // 0, 1, 2
reg have_rebalance_packet [0:8];
reg [2:0] rebalance_packet [0:8];    // 0 ~ 7
reg signed [6:0] prev_prio [0:8];     // -32 ~ 36
wire [6:0] total_load;    // ((0 ~ 15) + (0 ~ 8))) * 3 = 69

//================================================================
//    DESIGN
//================================================================

// ------------ decrypt ------------

// wire [3:0] ch_load [0:2];        // 4 bit * 3
assign ch_load[0] = channel_load[3:0];
assign ch_load[1] = channel_load[7:4];
assign ch_load[2] = channel_load[11:8];

// wire [2:0] ch_cap [0:2];         // 3 bit * 3
assign ch_cap[0] = channel_capacity[2:0];
assign ch_cap[1] = channel_capacity[5:3];
assign ch_cap[2] = channel_capacity[8:6];

// reg [15:0] k [0:3];     // 16 bit * 4
always @(*) begin
    k[0] = KEY[15:0];
    k[1] = ({k[0][6:0], k[0][15:7]} + KEY[31:16]) ^ 16'd0;
    k[2] = ({k[1][6:0], k[1][15:7]} + KEY[47:32]) ^ 16'd1;
    k[3] = ({k[2][6:0], k[2][15:7]} + KEY[63:48]) ^ 16'd2;
end

// wire [15:0] packet_y [0:3], packet_x [0:3];
assign packet_x[0] = packets[15:0];
assign packet_y[0] = packets[31:16];
assign packet_x[1] = packets[47:32];
assign packet_y[1] = packets[63:48];
assign packet_x[2] = packets[79:64];
assign packet_y[2] = packets[95:80];
assign packet_x[3] = packets[111:96];
assign packet_y[3] = packets[127:112];

// wire [15:0] de_packet_y[0:3], de_packet_x[0:3];
generate
    for (r = 0; r < 4; r = r + 1) begin : de_packet_xy_gen
        wire [15:0] tmp_x_0, tmp_x_1, tmp_x_2;
        wire [15:0] tmp_y_0, tmp_y_1, tmp_y_2;
        wire [15:0] pre_ROR_y_0, pre_ROR_y_1, pre_ROR_y_2, pre_ROR_y_3;
        wire [15:0] pre_ROL_x_0, pre_ROL_x_1, pre_ROL_x_2, pre_ROL_x_3;

        assign pre_ROR_y_0 = packet_y[r] ^ packet_x[r];         assign tmp_y_0 = {pre_ROR_y_0[1:0], pre_ROR_y_0[15:2]};
        assign pre_ROL_x_0 = (packet_x[r] ^ k[3]) - tmp_y_0;    assign tmp_x_0 = {pre_ROL_x_0[8:0], pre_ROL_x_0[15:9]};

        assign pre_ROR_y_1 = tmp_y_0 ^ tmp_x_0;                 assign tmp_y_1 = {pre_ROR_y_1[1:0], pre_ROR_y_1[15:2]};
        assign pre_ROL_x_1 = (tmp_x_0 ^ k[2]) - tmp_y_1;        assign tmp_x_1 = {pre_ROL_x_1[8:0], pre_ROL_x_1[15:9]};

        assign pre_ROR_y_2 = tmp_y_1 ^ tmp_x_1;                 assign tmp_y_2 = {pre_ROR_y_2[1:0], pre_ROR_y_2[15:2]};
        assign pre_ROL_x_2 = (tmp_x_1 ^ k[1]) - tmp_y_2;        assign tmp_x_2 = {pre_ROL_x_2[8:0], pre_ROL_x_2[15:9]};

        assign pre_ROR_y_3 = tmp_y_2 ^ tmp_x_2;                 assign de_packet_y[r] = {pre_ROR_y_3[1:0], pre_ROR_y_3[15:2]};
        assign pre_ROL_x_3 = (tmp_x_2 ^ k[0]) - de_packet_y[r]; assign de_packet_x[r] = {pre_ROL_x_3[8:0], pre_ROL_x_3[15:9]};
    end
endgenerate

// ------------ decode ------------

// reg req_valid [0:7];
always @(*) begin
    integer i;
    for (i = 0; i < 4; i = i + 1) begin
        req_valid[2*i]   = de_packet_x[i][15];
        req_valid[2*i+1] = de_packet_y[i][15];
    end
end

// reg [1:0] qos [0:7];
always @(*) begin
    integer i;
    for (i = 0; i < 4; i = i + 1) begin
        qos[2*i]   = de_packet_x[i][14:13];
        qos[2*i+1] = de_packet_y[i][14:13];
    end
end

// reg [3:0] pkt_len [0:7];
always @(*) begin
    integer i;
    for (i = 0; i < 4; i = i + 1) begin
        pkt_len[2*i]   = de_packet_x[i][12:9];
        pkt_len[2*i+1] = de_packet_y[i][12:9];
    end
end

// reg [1:0] congestion [0:7];
always @(*) begin
    integer i;
    for (i = 0; i < 4; i = i + 1) begin
        congestion[2*i]   = de_packet_x[i][8:7];
        congestion[2*i+1] = de_packet_y[i][8:7];
    end
end

// reg [1:0] prefer_ch [0:7];
always @(*) begin
    integer i;
    for (i = 0; i < 4; i = i + 1) begin
        prefer_ch[2*i]   = de_packet_x[i][6:5];
        prefer_ch[2*i+1] = de_packet_y[i][6:5];
    end
end

// reg [2:0] src_hint [0:7];
always @(*) begin
    integer i;
    for (i = 0; i < 4; i = i + 1) begin
        src_hint[2*i]   = de_packet_x[i][4:2];
        src_hint[2*i+1] = de_packet_y[i][4:2];
    end
end

// reg mode [0:7];
always @(*) begin
    integer i;
    for (i = 0; i < 4; i = i + 1) begin
        mode[2*i]   = de_packet_x[i][1];
        mode[2*i+1] = de_packet_y[i][1];
    end
end

// ------------ Calculate Priority Scores ------------

// reg [1:0] qos [0:7];
// reg [3:0] pkt_len [0:7];
// reg [1:0] congestion [0:7];
// reg [2:0] src_hint [0:7];

// wire signed [6:0] qos_signed [0:7];
// wire signed [6:0] pkt_len_signed [0:7];
// wire signed [6:0] congestion_signed [0:7];
// wire signed [6:0] src_hint_signed [0:7];

generate
    for (r = 0; r < 8; r = r + 1) begin : unsigned_structure
        assign qos_signed[r]        = mode[r] ? {{5{qos[r][1]}}       , qos[r]        }: {5'b0, qos[r]};
        assign pkt_len_signed[r]    = mode[r] ? {{3{pkt_len[r][3]}}   , pkt_len[r]    }: {3'b0, pkt_len[r]};
        assign congestion_signed[r] = mode[r] ? {{5{congestion[r][1]}}, congestion[r] }: {5'b0, congestion[r]};
        assign src_hint_signed[r]   = mode[r] ? {{4{src_hint[r][2]}}  , src_hint[r]   }: {4'b0, src_hint[r]};
    end
endgenerate

// wire [6:0] congestion_signed_m3 [0:7];
MUL_SIGNED_3_TABLE m3_1 (.operand(congestion_signed), .result(congestion_signed_m3));

// reg signed [6:0] priority_score [0:7];   // 7 bit * 8 unsigned(-32 ~ 26) signed(-22 ~ 36)
always @(*) begin
    integer i;
    for (i = 0; i < 8; i = i + 1) begin
        priority_score[i] = (qos_signed[i] <<< 2) - (pkt_len_signed[i] <<< 1) - congestion_signed_m3[i] + src_hint_signed[i] + 7;
    end
end

// ------------ sorted as the rule ------------ 13.58

// wire [2:0] rank_idx [0:7];     // rank_idx[0] = max priority_score's packet's index
// SORT s1 (.req_valid(req_valid), .priority_score(priority_score), .rank_idx(rank_idx));
SORT_OPTIMIZED s1 (.req_valid(req_valid), .priority_score(priority_score), .rank_idx(rank_idx));

// ------------ Packet Arbitration and Allocation ------------ 25.32

// reg [2:0] cap0_stages [0:8];    // [stage_index]
// reg [2:0] cap1_stages [0:8];
// reg [2:0] cap2_stages [0:8];

// reg [1:0] pivot_stages [0:8];   // trace pivot changes
// reg fallback_flag_stages [0:8]; // trace fallback happened or not

// reg [1:0] alloc_channel_tmp [0:7];

// reg [2:0] current_cap [0:2];
// reg [1:0] current_pivot [0:7];
// reg [1:0] current_search_ch1 [0:7], current_search_ch2 [0:7], current_search_ch3 [0:7];

// reg [1:0] current_channel [0:7];    // current rank i's final allocate channel
reg [1:0] current_channel;    // current rank i's final allocate channel

function [1:0] add1_mod3;     // ignore operand == 3
    input [1:0] operand;
    add1_mod3 = {operand[0], (~operand[1] & ~operand[0])};      // Karnaugh map
endfunction

function [1:0] add2_mod3;     // ignore operand == 3
    input [1:0] operand;
    add2_mod3 = {(~operand[1] & ~operand[0]), operand[1]};      // Karnaugh map
endfunction

always @(*) begin
    integer i;
    // intinal
    cap0_stages[0] = ch_cap[0];
    cap1_stages[0] = ch_cap[1];
    cap2_stages[0] = ch_cap[2];
    pivot_stages[0] = 2'd3; // initial num not importent

    // avoid latch
    for (i = 0; i < 8; i = i + 1) alloc_channel_tmp[i] = 2'b11;

    for (i = 0; i < 8; i = i + 1) begin
        current_cap[0] = cap0_stages[i];
        current_cap[1] = cap1_stages[i];
        current_cap[2] = cap2_stages[i];

        if (req_valid[rank_idx[i]]) begin
            if (current_cap[prefer_ch[rank_idx[i]]] > 0) begin
                current_channel   = prefer_ch[rank_idx[i]];
                pivot_stages[i+1] = pivot_stages[i];
            end
            else begin
                // Fallback
                // 1st fallback, initial the pivot
                current_pivot[i] = (pivot_stages[i] == 2'd3) ? prefer_ch[rank_idx[i]] : pivot_stages[i];

                // round robin
                current_search_ch1[i] = current_pivot[i];
                current_search_ch2[i] = add1_mod3(current_pivot[i]);
                current_search_ch3[i] = add2_mod3(current_pivot[i]);

                // current_channel
                if      (current_cap[current_search_ch1[i]] > 0) current_channel = current_search_ch1[i];
                else if (current_cap[current_search_ch2[i]] > 0) current_channel = current_search_ch2[i];
                else if (current_cap[current_search_ch3[i]] > 0) current_channel = current_search_ch3[i];
                else                                             current_channel = 2'd3;

                // update pivot by fallback result (fallback success or not?)
                if (current_cap[current_search_ch1[i]] > 0 || current_cap[current_search_ch2[i]] > 0 || current_cap[current_search_ch3[i]] > 0)
                     pivot_stages[i+1] = add1_mod3(current_pivot[i]);   // (x+1)%3
                else pivot_stages[i+1] = add2_mod3(current_pivot[i]);   // (x+2)%3
            end
        end
        else begin
            current_channel   = 2'b11;
            pivot_stages[i+1] = pivot_stages[i];
        end

        // allocate to current_channel (0 ~ 3)
        alloc_channel_tmp[rank_idx[i]] = current_channel;
        // update capacity
        case(current_channel)
            2'd0:    begin cap0_stages[i+1] = current_cap[0] - 1; cap1_stages[i+1] = current_cap[1]    ; cap2_stages[i+1] = current_cap[2]    ; end
            2'd1:    begin cap0_stages[i+1] = current_cap[0]    ; cap1_stages[i+1] = current_cap[1] - 1; cap2_stages[i+1] = current_cap[2]    ; end
            2'd2:    begin cap0_stages[i+1] = current_cap[0]    ; cap1_stages[i+1] = current_cap[1]    ; cap2_stages[i+1] = current_cap[2] - 1; end
            default: begin cap0_stages[i+1] = current_cap[0]    ; cap1_stages[i+1] = current_cap[1]    ; cap2_stages[i+1] = current_cap[2]    ; end     // 2'd3
        endcase
    end
end

// wire [2:0] ch_cap_final [0:2];
assign ch_cap_final[0] = cap0_stages[8];
assign ch_cap_final[1] = cap1_stages[8];
assign ch_cap_final[2] = cap2_stages[8];

// ------------ Mask ------------

// reg [4:0] mask [0:7];      // not yet % 10       = 0 ~ 30
always @(*) begin
    integer i;
    for (i = 0; i < 8; i = i + 1) begin
        // mask[i] = (alloc_channel_tmp[i] == 2'b11) ? 5'b0 : (
                                                    // ({priority_score[i][2:1], 1'b0} + prefer_ch[i]) +
                                                    // // ((priority_score[i][2:0] & 3'b110) + prefer_ch[i]) +
                                                    // ((src_hint[i] ^ 3'd3) + ch_load[alloc_channel_tmp[i]]));
        mask[i] = ({priority_score[i][2:1], 1'b0} + prefer_ch[i]) + ((src_hint[i] ^ 3'd3) + ch_load[alloc_channel_tmp[i]]);
    end
end

// wire [3:0] mask_score [0:7];    // 0 ~ 9
MOD_10_TABLE m10_1 (.operand(mask), .result(mask_score));

// wire [2:0] div_3_result [0:2]; // 0 ~ 5
DIV_3_TABLE d3_1 (.operand(ch_load), .result(div_3_result));

// reg [3:0] threshold [0:7];  // 7 ~ 12
always @(*) begin
    integer i;
    for (i = 0; i < 8; i = i + 1) begin
        // threshold[i] = (alloc_channel_tmp[i] == 2'b11) ? 4'b0 : (7 + div_3_result[alloc_channel_tmp[i]]);
        threshold[i] = div_3_result[alloc_channel_tmp[i]] + 4'd7;
    end
end

// reg failed [0:7];
always @(*) begin
    integer i;
    for (i = 0; i < 8; i = i + 1) begin
        // failed[i] = (alloc_channel_tmp[i] == 2'b11 || mask_score[i] >= threshold[i]) ? 1'b1 : 1'b0;
        failed[i] = (mask_score[i] >= threshold[i]) ? 1'b1 : 1'b0;
    end
end

// ------------ Global Rebalance ------------

// reg [4:0] ch_load_new [0:2];        // (0 ~ 15) + (0 ~ 8) = (0 ~ 23)
always @(*) begin
    integer i;
    for (i = 0; i < 3; i = i + 1) begin     // 0, 1, 2
        ch_load_new[i] = ch_load[i] +
                         (alloc_channel_tmp[0] == i) +
                         (alloc_channel_tmp[1] == i) +
                         (alloc_channel_tmp[2] == i) +
                         (alloc_channel_tmp[3] == i) +
                         (alloc_channel_tmp[4] == i) +
                         (alloc_channel_tmp[5] == i) +
                         (alloc_channel_tmp[6] == i) +
                         (alloc_channel_tmp[7] == i);
    end
end

// wire [1:0] max_ch;  // 0, 1, 2
wire tmp_ch;    // 0, 1
assign tmp_ch = ch_load_new[1] > ch_load_new[0];
assign max_ch = (ch_load_new[2] > ch_load_new[tmp_ch]) ? 2'd2 : tmp_ch;

// reg have_rebalance_packet [0:8];
// reg [2:0] rebalance_packet [0:8];    // 0 ~ 7
always @(*) begin
    integer i;
    have_rebalance_packet[0] = 1'b0;
    rebalance_packet[0] = 3'd0;
    for (i = 0; i < 8; i = i + 1) begin
        if (~have_rebalance_packet[i] && ~failed[rank_idx[7-i]] && alloc_channel_tmp[rank_idx[7-i]] == max_ch) begin
            have_rebalance_packet[i+1] = 1'b1;
            rebalance_packet[i+1]      = rank_idx[7-i];
        end
        else begin
            have_rebalance_packet[i+1] = have_rebalance_packet[i];
            rebalance_packet[i+1]      = rebalance_packet[i];
        end
    end
end

// wire [6:0] total_load;    // ((0 ~ 15) + (0 ~ 8))) * 3 = 69
assign total_load = ch_load_new[0] + ch_load_new[1] + ch_load_new[2];

wire [1:0] max_add1_ch, max_add2_ch;

assign max_add1_ch = add1_mod3(max_ch);
assign max_add2_ch = add2_mod3(max_ch);

// reg [1:0] alloc_channel [0:7]      // 0 ~ 2, 3 = not allocate
always @(*) begin
    alloc_channel = alloc_channel_tmp;
    // if (have_rebalance_packet[8] && (ch_load_new[max_ch] > ((total_load - ch_load_new[max_ch]) >> 1))) begin
    if (have_rebalance_packet[8] && (ch_load_new[max_ch] != ch_load_new[max_add1_ch] || ch_load_new[max_ch] != ch_load_new[max_add2_ch])) begin
        if      (ch_cap_final[max_add1_ch] > 0 && ch_load_new[max_add1_ch] < 15) alloc_channel[rebalance_packet[8]] = max_add1_ch;
        else if (ch_cap_final[max_add2_ch] > 0 && ch_load_new[max_add2_ch] < 15) alloc_channel[rebalance_packet[8]] = max_add2_ch;
        else                                                                     alloc_channel[rebalance_packet[8]] = 2'd3;
    end
end

// ------------ output ------------

// output reg [15:0] grant_channel
always @(*) begin
    grant_channel = {alloc_channel[7], alloc_channel[6], alloc_channel[5], alloc_channel[4],
                     alloc_channel[3], alloc_channel[2], alloc_channel[1], alloc_channel[0]};
end

// 36.97

endmodule

// module SORT(
//     input req_valid [0:7],
//     input signed [6:0] priority_score [0:7],
//     output [2:0] rank_idx [0:7]
// );

// reg [2:0] layer0_0, layer0_1, layer0_2, layer0_3, layer0_4, layer0_5, layer0_6, layer0_7;
// reg [2:0] layer1_0, layer1_1, layer1_2, layer1_3, layer1_4, layer1_5, layer1_6, layer1_7;
// reg [2:0] layer2_0, layer2_1, layer2_2, layer2_3, layer2_4, layer2_5, layer2_6, layer2_7;
// reg [2:0]                     layer3_2, layer3_3, layer3_4, layer3_5                    ;
// reg [2:0]           layer4_1,           layer4_3, layer4_4,           layer4_6          ;
// reg [2:0]           layer5_1, layer5_2, layer5_3, layer5_4, layer5_5, layer5_6          ;

// function should_swap;
//     input [2:0] idx_a, idx_b;
//     input req_valid [0:7];
//     input signed [6:0] priority_score [0:7];
//     begin
//         if (req_valid[idx_b] && (~req_valid[idx_a] ||
//                                  (priority_score[idx_a] <  priority_score[idx_b]) ||
//                                  (priority_score[idx_a] == priority_score[idx_b] && idx_a > idx_b)
//                                 )) should_swap = 1;
//         else should_swap = 0;

//         // if      ((~req_valid[idx_a] &&  req_valid[idx_b]) ||
//         //          ( req_valid[idx_a] ==  req_valid[idx_b] && priority_score[idx_a] < priority_score[idx_b])) should_swap = 1;
//         // else if (( req_valid[idx_a] && ~req_valid[idx_b]) ||
//         //          ( req_valid[idx_a] ==  req_valid[idx_b] && priority_score[idx_a] > priority_score[idx_b])) should_swap = 0;
//         // else                                                                                                should_swap = (idx_a > idx_b);
//     end
// endfunction

// always @(*) begin
//     // Layer 0: [(0,2),(1,3),(4,6),(5,7)]
    
//     // (0,2)
//     if (should_swap(3'd0, 3'd2, req_valid, priority_score)) begin
//         layer0_0 = 3'd2;
//         layer0_2 = 3'd0;
//     end
//     else begin
//         layer0_0 = 3'd0;
//         layer0_2 = 3'd2;
//     end
    
//     // (1,3)
//     if (should_swap(3'd1, 3'd3, req_valid, priority_score)) begin
//         layer0_1 = 3'd3;
//         layer0_3 = 3'd1;
//     end
//     else begin
//         layer0_1 = 3'd1;
//         layer0_3 = 3'd3;
//     end
    
//     // (4,6)
//     if (should_swap(3'd4, 3'd6, req_valid, priority_score)) begin
//         layer0_4 = 3'd6;
//         layer0_6 = 3'd4;
//     end
//     else begin
//         layer0_4 = 3'd4;
//         layer0_6 = 3'd6;
//     end
    
//     // (5,7)
//     if (should_swap(3'd5, 3'd7, req_valid, priority_score)) begin
//         layer0_5 = 3'd7;
//         layer0_7 = 3'd5;
//     end
//     else begin
//         layer0_5 = 3'd5;
//         layer0_7 = 3'd7;
//     end

//     // Layer 1: [(0,4),(1,5),(2,6),(3,7)]
    
//     // (0,4)
//     if (should_swap(layer0_0, layer0_4, req_valid, priority_score)) begin
//         layer1_0 = layer0_4;
//         layer1_4 = layer0_0;
//     end
//     else begin
//         layer1_0 = layer0_0;
//         layer1_4 = layer0_4;
//     end
    
//     // (1,5)
//     if (should_swap(layer0_1, layer0_5, req_valid, priority_score)) begin
//         layer1_1 = layer0_5;
//         layer1_5 = layer0_1;
//     end
//     else begin
//         layer1_1 = layer0_1;
//         layer1_5 = layer0_5;
//     end
    
//     // (2,6)
//     if (should_swap(layer0_2, layer0_6, req_valid, priority_score)) begin
//         layer1_2 = layer0_6;
//         layer1_6 = layer0_2;
//     end
//     else begin
//         layer1_2 = layer0_2;
//         layer1_6 = layer0_6;
//     end
    
//     // (3,7)
//     if (should_swap(layer0_3, layer0_7, req_valid, priority_score)) begin
//         layer1_3 = layer0_7;
//         layer1_7 = layer0_3;
//     end
//     else begin
//         layer1_3 = layer0_3;
//         layer1_7 = layer0_7;
//     end

//     // Layer 2: [(0,1),(2,3),(4,5),(6,7)]
    
//     // (0,1)
//     if (should_swap(layer1_0, layer1_1, req_valid, priority_score)) begin
//         layer2_0 = layer1_1;
//         layer2_1 = layer1_0;
//     end
//     else begin
//         layer2_0 = layer1_0;
//         layer2_1 = layer1_1;
//     end
    
//     // (2,3)
//     if (should_swap(layer1_2, layer1_3, req_valid, priority_score)) begin
//         layer2_2 = layer1_3;
//         layer2_3 = layer1_2;
//     end
//     else begin
//         layer2_2 = layer1_2;
//         layer2_3 = layer1_3;
//     end
    
//     // (4,5)
//     if (should_swap(layer1_4, layer1_5, req_valid, priority_score)) begin
//         layer2_4 = layer1_5;
//         layer2_5 = layer1_4;
//     end
//     else begin
//         layer2_4 = layer1_4;
//         layer2_5 = layer1_5;
//     end
    
//     // (6,7)
//     if (should_swap(layer1_6, layer1_7, req_valid, priority_score)) begin
//         layer2_6 = layer1_7;
//         layer2_7 = layer1_6;
//     end
//     else begin
//         layer2_6 = layer1_6;
//         layer2_7 = layer1_7;
//     end

//     // Layer 3: [(2,4),(3,5)]
    
//     // (2,4)
//     if (should_swap(layer2_2, layer2_4, req_valid, priority_score)) begin
//         layer3_2 = layer2_4;
//         layer3_4 = layer2_2;
//     end
//     else begin
//         layer3_2 = layer2_2;
//         layer3_4 = layer2_4;
//     end
    
//     // (3,5)
//     if (should_swap(layer2_3, layer2_5, req_valid, priority_score)) begin
//         layer3_3 = layer2_5;
//         layer3_5 = layer2_3;
//     end
//     else begin
//         layer3_3 = layer2_3;
//         layer3_5 = layer2_5;
//     end

//     // Layer 4: [(1,4),(3,6)]
    
//     // (1,4)
//     if (should_swap(layer2_1, layer3_4, req_valid, priority_score)) begin
//         layer4_1 = layer3_4;
//         layer4_4 = layer2_1;
//     end
//     else begin
//         layer4_1 = layer2_1;
//         layer4_4 = layer3_4;
//     end
    
//     // (3,6)
//     if (should_swap(layer3_3, layer2_6, req_valid, priority_score)) begin
//         layer4_3 = layer2_6;
//         layer4_6 = layer3_3;
//     end
//     else begin
//         layer4_3 = layer3_3;
//         layer4_6 = layer2_6;
//     end

//     // Layer 5: [(1,2),(3,4),(5,6)]
    
//     // (1,2)
//     if (should_swap(layer4_1, layer3_2, req_valid, priority_score)) begin
//         layer5_1 = layer3_2;
//         layer5_2 = layer4_1;
//     end
//     else begin
//         layer5_1 = layer4_1;
//         layer5_2 = layer3_2;
//     end
    
//     // (3,4)
//     if (should_swap(layer4_3, layer4_4, req_valid, priority_score)) begin
//         layer5_3 = layer4_4;
//         layer5_4 = layer4_3;
//     end
//     else begin
//         layer5_3 = layer4_3;
//         layer5_4 = layer4_4;
//     end
    
//     // (5,6)
//     if (should_swap(layer3_5, layer4_6, req_valid, priority_score)) begin
//         layer5_5 = layer4_6;
//         layer5_6 = layer3_5;
//     end
//     else begin
//         layer5_5 = layer3_5;
//         layer5_6 = layer4_6;
//     end
// end

// assign rank_idx[0] = layer2_0;     // highest
// assign rank_idx[1] = layer5_1;
// assign rank_idx[2] = layer5_2;
// assign rank_idx[3] = layer5_3;
// assign rank_idx[4] = layer5_4;
// assign rank_idx[5] = layer5_5;
// assign rank_idx[6] = layer5_6;
// assign rank_idx[7] = layer2_7;     // lowest

// endmodule

module SORT_OPTIMIZED(
    input req_valid [0:7],
    input signed [6:0] priority_score [0:7],
    output [2:0] rank_idx [0:7]
);

// pack format: {req_valid[1], priority_score[7], original_index[3]} = 11 bit
reg [10:0] layer0_0, layer0_1, layer0_2, layer0_3, layer0_4, layer0_5, layer0_6, layer0_7;
reg [10:0] layer1_0, layer1_1, layer1_2, layer1_3, layer1_4, layer1_5, layer1_6, layer1_7;
reg [10:0] layer2_0, layer2_1, layer2_2, layer2_3, layer2_4, layer2_5, layer2_6, layer2_7;
reg [10:0]                     layer3_2, layer3_3, layer3_4, layer3_5                    ;
reg [10:0]           layer4_1,           layer4_3, layer4_4,           layer4_6          ;
reg [10:0]           layer5_1, layer5_2, layer5_3, layer5_4, layer5_5, layer5_6          ;

// create pack
wire [10:0] input_pack [0:7];
assign input_pack[0] = {req_valid[0], priority_score[0], 3'd0};
assign input_pack[1] = {req_valid[1], priority_score[1], 3'd1};
assign input_pack[2] = {req_valid[2], priority_score[2], 3'd2};
assign input_pack[3] = {req_valid[3], priority_score[3], 3'd3};
assign input_pack[4] = {req_valid[4], priority_score[4], 3'd4};
assign input_pack[5] = {req_valid[5], priority_score[5], 3'd5};
assign input_pack[6] = {req_valid[6], priority_score[6], 3'd6};
assign input_pack[7] = {req_valid[7], priority_score[7], 3'd7};

function should_swap_packed;
    input [10:0] pack_a, pack_b;
    reg req_a, req_b;
    reg signed [6:0] score_a, score_b;
    reg [2:0] idx_a, idx_b;
    begin       // unpack
        req_a = pack_a[10];
        req_b = pack_b[10];
        score_a = pack_a[9:3];
        score_b = pack_b[9:3];
        idx_a = pack_a[2:0];
        idx_b = pack_b[2:0];
        
        if (req_b && (~req_a || 
                     (score_a < score_b) || 
                     (score_a == score_b && idx_a > idx_b))) should_swap_packed = 1;
        else should_swap_packed = 0;
    end
endfunction

always @(*) begin
    // Layer 0: [(0,2),(1,3),(4,6),(5,7)]
    
    // (0,2)
    if (should_swap_packed(input_pack[0], input_pack[2])) begin
        layer0_0 = input_pack[2];
        layer0_2 = input_pack[0];
    end
    else begin
        layer0_0 = input_pack[0];
        layer0_2 = input_pack[2];
    end
    
    // (1,3)
    if (should_swap_packed(input_pack[1], input_pack[3])) begin
        layer0_1 = input_pack[3];
        layer0_3 = input_pack[1];
    end
    else begin
        layer0_1 = input_pack[1];
        layer0_3 = input_pack[3];
    end
    
    // (4,6)
    if (should_swap_packed(input_pack[4], input_pack[6])) begin
        layer0_4 = input_pack[6];
        layer0_6 = input_pack[4];
    end
    else begin
        layer0_4 = input_pack[4];
        layer0_6 = input_pack[6];
    end
    
    // (5,7)
    if (should_swap_packed(input_pack[5], input_pack[7])) begin
        layer0_5 = input_pack[7];
        layer0_7 = input_pack[5];
    end
    else begin
        layer0_5 = input_pack[5];
        layer0_7 = input_pack[7];
    end

    // Layer 1: [(0,4),(1,5),(2,6),(3,7)]
    
    // (0,4)
    if (should_swap_packed(layer0_0, layer0_4)) begin
        layer1_0 = layer0_4;
        layer1_4 = layer0_0;
    end
    else begin
        layer1_0 = layer0_0;
        layer1_4 = layer0_4;
    end
    
    // (1,5)
    if (should_swap_packed(layer0_1, layer0_5)) begin
        layer1_1 = layer0_5;
        layer1_5 = layer0_1;
    end
    else begin
        layer1_1 = layer0_1;
        layer1_5 = layer0_5;
    end
    
    // (2,6)
    if (should_swap_packed(layer0_2, layer0_6)) begin
        layer1_2 = layer0_6;
        layer1_6 = layer0_2;
    end
    else begin
        layer1_2 = layer0_2;
        layer1_6 = layer0_6;
    end
    
    // (3,7)
    if (should_swap_packed(layer0_3, layer0_7)) begin
        layer1_3 = layer0_7;
        layer1_7 = layer0_3;
    end
    else begin
        layer1_3 = layer0_3;
        layer1_7 = layer0_7;
    end

    // Layer 2: [(0,1),(2,3),(4,5),(6,7)]
    
    // (0,1)
    if (should_swap_packed(layer1_0, layer1_1)) begin
        layer2_0 = layer1_1;
        layer2_1 = layer1_0;
    end
    else begin
        layer2_0 = layer1_0;
        layer2_1 = layer1_1;
    end
    
    // (2,3)
    if (should_swap_packed(layer1_2, layer1_3)) begin
        layer2_2 = layer1_3;
        layer2_3 = layer1_2;
    end
    else begin
        layer2_2 = layer1_2;
        layer2_3 = layer1_3;
    end
    
    // (4,5)
    if (should_swap_packed(layer1_4, layer1_5)) begin
        layer2_4 = layer1_5;
        layer2_5 = layer1_4;
    end
    else begin
        layer2_4 = layer1_4;
        layer2_5 = layer1_5;
    end
    
    // (6,7)
    if (should_swap_packed(layer1_6, layer1_7)) begin
        layer2_6 = layer1_7;
        layer2_7 = layer1_6;
    end
    else begin
        layer2_6 = layer1_6;
        layer2_7 = layer1_7;
    end

    // Layer 3: [(2,4),(3,5)]
    
    // (2,4)
    if (should_swap_packed(layer2_2, layer2_4)) begin
        layer3_2 = layer2_4;
        layer3_4 = layer2_2;
    end
    else begin
        layer3_2 = layer2_2;
        layer3_4 = layer2_4;
    end
    
    // (3,5)
    if (should_swap_packed(layer2_3, layer2_5)) begin
        layer3_3 = layer2_5;
        layer3_5 = layer2_3;
    end
    else begin
        layer3_3 = layer2_3;
        layer3_5 = layer2_5;
    end

    // Layer 4: [(1,4),(3,6)]
    
    // (1,4)
    if (should_swap_packed(layer2_1, layer3_4)) begin
        layer4_1 = layer3_4;
        layer4_4 = layer2_1;
    end
    else begin
        layer4_1 = layer2_1;
        layer4_4 = layer3_4;
    end
    
    // (3,6)
    if (should_swap_packed(layer3_3, layer2_6)) begin
        layer4_3 = layer2_6;
        layer4_6 = layer3_3;
    end
    else begin
        layer4_3 = layer3_3;
        layer4_6 = layer2_6;
    end

    // Layer 5: [(1,2),(3,4),(5,6)]
    
    // (1,2)
    if (should_swap_packed(layer4_1, layer3_2)) begin
        layer5_1 = layer3_2;
        layer5_2 = layer4_1;
    end
    else begin
        layer5_1 = layer4_1;
        layer5_2 = layer3_2;
    end
    
    // (3,4)
    if (should_swap_packed(layer4_3, layer4_4)) begin
        layer5_3 = layer4_4;
        layer5_4 = layer4_3;
    end
    else begin
        layer5_3 = layer4_3;
        layer5_4 = layer4_4;
    end
    
    // (5,6)
    if (should_swap_packed(layer3_5, layer4_6)) begin
        layer5_5 = layer4_6;
        layer5_6 = layer3_5;
    end
    else begin
        layer5_5 = layer3_5;
        layer5_6 = layer4_6;
    end
end

assign rank_idx[0] = layer2_0[2:0];     // highest
assign rank_idx[1] = layer5_1[2:0];
assign rank_idx[2] = layer5_2[2:0];
assign rank_idx[3] = layer5_3[2:0];
assign rank_idx[4] = layer5_4[2:0];
assign rank_idx[5] = layer5_5[2:0];
assign rank_idx[6] = layer5_6[2:0];
assign rank_idx[7] = layer2_7[2:0];     // lowest

endmodule


module MUL_SIGNED_3_TABLE(
    input signed [6:0] operand [0:7],       // 6-bit input, range -2 ~ 3 (-2 ~ 1, 0 ~ 3)
    output reg [6:0] result [0:7]    // 6-bit output
);

genvar r;
generate
    for (r = 0; r < 8; r = r + 1) begin : MUL_SIGNED_3_TABLE_gen
        always @(*) begin
            case (operand[r])
                -2: result[r] = 7'b1111010;
                -1: result[r] = 7'b1111101;
                0:  result[r] = 7'b0000000;
                1:  result[r] = 7'b0000011;
                2:  result[r] = 7'b0000110;
                3:  result[r] = 7'b0001001;
                default: result[r] = 7'b1111111;
            endcase
        end
    end
endgenerate

endmodule

module MOD_10_TABLE(
    input [4:0] operand [0:7],      // 0 ~ 30
    output reg [3:0] result [0:7]   // 0 ~ 9
);

genvar r;
generate
    for (r = 0; r < 8; r = r + 1) begin : MOD_10_TABLE_gen
        always @(*) begin
            case (operand[r])
                0, 10, 20, 30: result[r] = 4'd0;
                1, 11, 21    : result[r] = 4'd1;
                2, 12, 22    : result[r] = 4'd2;
                3, 13, 23    : result[r] = 4'd3;
                4, 14, 24    : result[r] = 4'd4;
                5, 15, 25    : result[r] = 4'd5;
                6, 16, 26    : result[r] = 4'd6;
                7, 17, 27    : result[r] = 4'd7;
                8, 18, 28    : result[r] = 4'd8;
                9, 19, 29    : result[r] = 4'd9;
                default: result[r] = 4'b1111;
            endcase
        end
    end
endgenerate

endmodule

module DIV_3_TABLE(
	input [3:0] operand [0:2],      // 0 ~ 15
	output reg [2:0] result [0:2]   // 0 ~ 5
);

genvar r;
generate
    for (r = 0; r < 3; r = r + 1) begin
        always @(*) begin
            case(operand[r])
                0, 1, 2:    result[r] = 3'd0;
                3, 4, 5:    result[r] = 3'd1;
                6, 7, 8:    result[r] = 3'd2;
                9, 10, 11:  result[r] = 3'd3;
                12, 13, 14: result[r] = 3'd4;
                15:         result[r] = 3'd5;
                default: result[r] = 3'b111;
            endcase
        end
    end
endgenerate

endmodule
// done:
//      FSM
//      input ---> mem
//      mem   ---> concat_32
//      concat_32 ---> L0_15x16
//      interpolation

// TODO:
//      make pipeline

module MVDM(
    // input signals
    clk,
    rst_n,
    in_valid, 
    in_valid2,
    in_data,
    // output signals
    out_valid,
    out_sad
    );

input clk;
input rst_n;
input in_valid;
input in_valid2;
input [8:0] in_data;

output reg out_valid;
output reg out_sad;

//=======================================================
//                   Reg/Wire
//=======================================================

genvar k;

parameter S_IDLE        = 0;
parameter S_W_SRAM      = 1;
parameter S_MV          = 2;
parameter S_P1_READ_L0  = 3;
parameter S_P1_READ_L1  = 4;
parameter S_P1_CAL      = 5;
parameter S_P2_READ_L0  = 6;
parameter S_P2_READ_L1  = 7;
parameter S_P2_CAL      = 8;
parameter S_OUTPUT      = 9;

// --------------------------- FSM ---------------------------
reg [3:0] current_state, next_state;

// --------------------------- input ---------------------------
reg [15:0] input_cnt;
reg [3:0]  input2_cnt;

// --------------------------- matrix for calculate ---------------------------
reg [4:0] read_cnt;     // 0~29
reg [4:0] read_cnt_d1, read_cnt_d2;

reg [7:0] L0_15x16 [0:239];
reg [7:0] L1_15x16 [0:239];

reg [3:0] current_state_d1, current_state_d2;

reg [7:0] concat_32 [0:31], concat_32_reg [0:31];

reg [6:0] now_L0_x, now_L0_x_sub2;
reg [6:0] now_L1_x, now_L1_x_sub2;

// --------------------------- calculate pipeline ---------------------------
// ----------- stage 1 -----------
reg [3:0] L0_search_point;    // 0~8
reg [3:0] L1_search_point;    // 8~0

reg [5:0] L0_search_point_offset;       // 0,1,2, 16,17,18, 32,33,34
reg [5:0] L1_search_point_offset;       // 0,1,2, 16,17,18, 32,33,34
reg [7:0] L0_array_idx;
reg [7:0] L1_array_idx;

reg [3:0] cal_cnt;

reg now_L0_frac_x;
reg now_L0_frac_y;
reg now_L1_frac_x;
reg now_L1_frac_y;

reg [7:0] L0_ip_result [0:3], L1_ip_result [0:3];      // 0~255
reg signed [8:0] residual [0:3];

// ----------- stage 2 -----------
reg [1:0] stage_2_cnt; // 0~3
// -1020 ~ 1020
// 10000000100
// 01111111100
reg signed [10:0] tmp_4x4 [0:15];    // 11-bit

// ----------- stage 3 -----------
wire cal_done;
reg [1:0] stage_2_cnt_d1; // 0~3
reg [3:0] stage_3_cnt; // 0~8

reg signed [12:0] hadamard [0:15], hadamard_abs [0:15];
reg [23:0] SATD;     // 0 ~ ?
reg [23:0] SATD_p1_final, SATD_p2_final;     // 0 ~ ?
reg [3:0] search_point_final_p1, search_point_final_p2;  // 0 ~ 8

// --------------------------- output ---------------------------
reg [5:0] out_cnt;    // 0~55

// --------------------------- memory ---------------------------
reg current_img;
reg [6:0] current_row;
reg [2:0] current_block;

parameter READ  = 1'b1;
parameter WRITE = 1'b0;

reg web;
reg [7:0] mem_din [0:15], mem_dout [0:15];

//=======================================================
//                   Design
//=======================================================

// --------------------------- FSM ---------------------------

// reg [3:0] current_state
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) current_state <= S_IDLE;
    else current_state <= next_state;
end

// reg [3:0] next_state
always @(*) begin
    case (current_state)
        S_IDLE: begin
            if      (in_valid)  next_state = S_W_SRAM;
            else if (in_valid2) next_state = S_MV;
            else                next_state = S_IDLE;
        end
        S_W_SRAM: begin
            if (input_cnt == 16'd32767) next_state = S_IDLE;    // 15'd32767 ??
            else                        next_state = S_W_SRAM;
        end
        S_MV: begin
            if (input2_cnt == 4'd7) next_state = S_P1_READ_L1;  // 3'd7?
            else                    next_state = S_MV;
        end
        // P1
        S_P1_READ_L0: begin
            if (read_cnt == 5'd29) next_state = S_P1_CAL;       // 16 pixel in 1 read
            else                   next_state = S_P1_READ_L0;
        end
        S_P1_READ_L1: begin
            if (read_cnt == 5'd29) next_state = S_P1_READ_L0;
            else                   next_state = S_P1_READ_L1;
        end
        S_P1_CAL: begin
            if (cal_done) next_state = S_P2_READ_L1;
            else          next_state = S_P1_CAL;
        end
        // P2
        S_P2_READ_L0: begin
            if (read_cnt == 5'd29) next_state = S_P2_CAL;       // 16 pixel in 1 read
            else                   next_state = S_P2_READ_L0;
        end
        S_P2_READ_L1: begin
            if (read_cnt == 5'd29) next_state = S_P2_READ_L0;
            else                   next_state = S_P2_READ_L1;
        end
        S_P2_CAL: begin
            if (cal_done) next_state = S_OUTPUT;
            else          next_state = S_P2_CAL;
        end
        S_OUTPUT: begin
            if (out_cnt == 6'd55) next_state = S_IDLE;
            else                  next_state = S_OUTPUT;
        end
        default: next_state = current_state;
    endcase
end

// --------------------------- input ---------------------------

// reg [15:0] input_cnt;
always @(posedge clk or negedge rst_n) begin
    if      (!rst_n)                input_cnt <= 16'd0;
    else if (current_state == S_MV) input_cnt <= 16'd0;
    else if (in_valid)              input_cnt <= input_cnt + 16'd1;
end

// reg [3:0]  input2_cnt;
always @(posedge clk or negedge rst_n) begin
    if      (!rst_n)                        input2_cnt <= 4'd0;
    else if (current_state == S_P1_READ_L0) input2_cnt <= 4'd0;
    else if (in_valid2)                     input2_cnt <= input2_cnt + 4'd1;
end

reg [6:0] p1_L0_x, p1_L0_y;
reg [6:0] p1_L1_x, p1_L1_y;

reg [6:0] p2_L0_x, p2_L0_y;
reg [6:0] p2_L1_x, p2_L1_y;


reg p1_L0_frac_x, p1_L0_frac_y;
reg p1_L1_frac_x, p1_L1_frac_y;

reg p2_L0_frac_x, p2_L0_frac_y;
reg p2_L1_frac_x, p2_L1_frac_y;

// reg p1_L0_frac_x, p1_L0_frac_y;
// reg p1_L1_frac_x, p1_L1_frac_y;

// reg p2_L0_frac_x, p2_L0_frac_y;
// reg p2_L1_frac_x, p2_L1_frac_y;
always @(posedge clk) begin
    if (in_valid2) begin
        case (input2_cnt)
            0:       begin p1_L0_x <= in_data[7:1]; p1_L0_frac_x <= in_data[0]; end
            1:       begin p1_L0_y <= in_data[7:1]; p1_L0_frac_y <= in_data[0]; end
            2:       begin p1_L1_x <= in_data[7:1]; p1_L1_frac_x <= in_data[0]; end
            3:       begin p1_L1_y <= in_data[7:1]; p1_L1_frac_y <= in_data[0]; end

            4:       begin p2_L0_x <= in_data[7:1]; p2_L0_frac_x <= in_data[0]; end
            5:       begin p2_L0_y <= in_data[7:1]; p2_L0_frac_y <= in_data[0]; end
            6:       begin p2_L1_x <= in_data[7:1]; p2_L1_frac_x <= in_data[0]; end
            default: begin p2_L1_y <= in_data[7:1]; p2_L1_frac_y <= in_data[0]; end
        endcase
    end
end


reg [6:0] p1_L0_x_sub2, p1_L0_y_sub2;
reg [6:0] p1_L1_x_sub2, p1_L1_y_sub2;
reg [6:0] p2_L0_x_sub2, p2_L0_y_sub2;
reg [6:0] p2_L1_x_sub2, p2_L1_y_sub2;

always @(*) begin
    p1_L0_x_sub2 = (p1_L0_x > 7'd2) ? (p1_L0_x - 7'd2) : (7'd0);
    p1_L0_y_sub2 = (p1_L0_y > 7'd2) ? (p1_L0_y - 7'd2) : (7'd0);
    p1_L1_x_sub2 = (p1_L1_x > 7'd2) ? (p1_L1_x - 7'd2) : (7'd0);
    p1_L1_y_sub2 = (p1_L1_y > 7'd2) ? (p1_L1_y - 7'd2) : (7'd0);
    p2_L0_x_sub2 = (p2_L0_x > 7'd2) ? (p2_L0_x - 7'd2) : (7'd0);
    p2_L0_y_sub2 = (p2_L0_y > 7'd2) ? (p2_L0_y - 7'd2) : (7'd0);
    p2_L1_x_sub2 = (p2_L1_x > 7'd2) ? (p2_L1_x - 7'd2) : (7'd0);
    p2_L1_y_sub2 = (p2_L1_y > 7'd2) ? (p2_L1_y - 7'd2) : (7'd0);
end

// --------------------------- matrix for calculate ---------------------------

// reg [4:0] read_cnt;     // 0~29
always @(posedge clk or negedge rst_n) begin
    if      (!rst_n)            read_cnt <= 5'd0;
    else if (read_cnt == 5'd29) read_cnt <= 5'd0;
    else begin
        case (current_state)
            S_P1_READ_L0, S_P1_READ_L1, S_P2_READ_L0, S_P2_READ_L1: read_cnt <= read_cnt + 5'd1;
        endcase
    end
end

// reg [4:0] read_cnt_d1;
always @(posedge clk) begin
    read_cnt_d1 <= read_cnt;
    read_cnt_d2 <= read_cnt_d1;
end

// reg [3:0] current_state_d1;
always @(posedge clk) begin
    current_state_d1 <= current_state;
    current_state_d2 <= current_state_d1;
end


// reg [7:0] concat_32_reg [0:31];
always @(posedge clk) begin
    concat_32_reg <= concat_32;
end

// reg [7:0] concat_32 [0:31];
always @(*) begin
    integer i;
    concat_32 = concat_32_reg;
    case (current_state_d2)
        S_P1_READ_L0, S_P1_READ_L1, S_P2_READ_L0, S_P2_READ_L1: begin
            for (i = 0; i < 16; i = i + 1) concat_32[{read_cnt_d2[0], i[3:0]}] = mem_dout[i];
        end
    endcase
end

// reg [6:0] now_L0_x, now_L0_x_sub2;
always @(*) begin
    case (current_state_d2)
        S_P1_READ_L0: begin
            now_L0_x      = p1_L0_x;
            now_L0_x_sub2 = p1_L0_x_sub2;
        end
        default: begin
            now_L0_x      = p2_L0_x;
            now_L0_x_sub2 = p2_L0_x_sub2;
        end
    endcase
end

// reg [6:0] now_L1_x, now_L1_x_sub2;
always @(*) begin
    case (current_state_d2)
        S_P1_READ_L1: begin
            now_L1_x      = p1_L1_x;
            now_L1_x_sub2 = p1_L1_x_sub2;
        end
        default: begin
            now_L1_x      = p2_L1_x;
            now_L1_x_sub2 = p2_L1_x_sub2;
        end
    endcase
end

// reg [7:0] L0_15x16 [0:239];
// reg [7:0] L1_15x16 [0:239];
always @(posedge clk) begin
    if (read_cnt_d2[0]) begin
        case (current_state_d2)
            S_P1_READ_L0, S_P2_READ_L0: begin
                case (now_L0_x)
                    0: begin
                        L0_15x16[{read_cnt_d2[4:1],4'd0}]       <= concat_32[0];
                        L0_15x16[{read_cnt_d2[4:1],4'd1}]       <= concat_32[0];
                        L0_15x16[{read_cnt_d2[4:1],4'd2} +: 13] <= concat_32[0:12];
                    end
                    1: begin
                        L0_15x16[{read_cnt_d2[4:1],4'd0}]       <= concat_32[0];
                        L0_15x16[{read_cnt_d2[4:1],4'd1} +: 14] <= concat_32[0:13];
                    end
                    116: begin
                        L0_15x16[{read_cnt_d2[4:1],4'd0} +: 14] <= concat_32[2:15];
                        L0_15x16[{read_cnt_d2[4:1],4'd14}]      <= concat_32[15];
                    end
                    default: begin
                        L0_15x16[{read_cnt_d2[4:1],4'd0} +: 15] <= concat_32[now_L0_x_sub2[3:0] +: 15];     // [(read_cnt_d2/2 * 16) +: 15]
                    end
                endcase
            end
            S_P1_READ_L1, S_P2_READ_L1: begin
                case (now_L1_x)
                    0: begin
                        L1_15x16[{read_cnt_d2[4:1],4'd0}]       <= concat_32[0];
                        L1_15x16[{read_cnt_d2[4:1],4'd1}]       <= concat_32[0];
                        L1_15x16[{read_cnt_d2[4:1],4'd2} +: 13] <= concat_32[0:12];
                    end
                    1: begin
                        L1_15x16[{read_cnt_d2[4:1],4'd0}]       <= concat_32[0];
                        L1_15x16[{read_cnt_d2[4:1],4'd1} +: 14] <= concat_32[0:13];
                    end
                    116: begin
                        L1_15x16[{read_cnt_d2[4:1],4'd0} +: 14] <= concat_32[2:15];
                        L1_15x16[{read_cnt_d2[4:1],4'd14}]      <= concat_32[15];
                    end
                    default: begin
                        L1_15x16[{read_cnt_d2[4:1],4'd0} +: 15] <= concat_32[now_L1_x_sub2[3:0] +: 15];     // [(read_cnt_d2/2 * 16) +: 15]
                    end
                endcase
            end
        endcase
    end
end

// --------------------------- calculate pipeline ---------------------------

// ----------- stage 1 -----------
// L0 buffer  ---(4 interpolation)---> 4 pixel
// L1 buffer  ---(4 interpolation)---> 4 pixel

// reg [3:0] cal_cnt;       // 0~15
always @(posedge clk) begin
    case (current_state)
        S_IDLE:             cal_cnt <= 4'd0;
        S_P1_CAL, S_P2_CAL: cal_cnt <= cal_cnt + 4'd1;
    endcase
end

// reg [3:0] L0_search_point;    // 0~8
always @(posedge clk) begin
    case (current_state)
        S_IDLE:             L0_search_point <= 4'd0;
        S_P1_CAL, S_P2_CAL: if (cal_cnt == 4'd15) L0_search_point <= L0_search_point + 4'd1;
    endcase
end

// reg [3:0] L1_search_point;    // 8~0
always @(posedge clk) begin
    case (current_state)
        S_IDLE:             L1_search_point <= 4'd8;
        S_P1_CAL, S_P2_CAL: if (cal_cnt == 4'd15) L1_search_point <= L1_search_point - 4'd1;
    endcase
end

// reg [5:0] L0_search_point_offset;       // 0,1,2, 16,17,18, 32,33,34
always @(*) begin
    case (L0_search_point)  // 0~8
        0: L0_search_point_offset = 0;
        1: L0_search_point_offset = 1;
        2: L0_search_point_offset = 2;
        
        3: L0_search_point_offset = 16;
        4: L0_search_point_offset = 17;
        5: L0_search_point_offset = 18;
        
        6: L0_search_point_offset = 32;
        7: L0_search_point_offset = 33;
        default: L0_search_point_offset = 34;
    endcase
end

// reg [5:0] L1_search_point_offset;       // 0,1,2, 16,17,18, 32,33,34
always @(*) begin
    case (L1_search_point)  // 8~0
        0: L1_search_point_offset = 0;
        1: L1_search_point_offset = 1;
        2: L1_search_point_offset = 2;
        
        3: L1_search_point_offset = 16;
        4: L1_search_point_offset = 17;
        5: L1_search_point_offset = 18;
        
        6: L1_search_point_offset = 32;
        7: L1_search_point_offset = 33;
        default: L1_search_point_offset = 34;
    endcase
end

// reg [7:0] L0_array_idx;
always @(*) begin
    case (cal_cnt)
        0: L0_array_idx = 0  + L0_search_point_offset;
        1: L0_array_idx = 16 + L0_search_point_offset;
        2: L0_array_idx = 32 + L0_search_point_offset;
        3: L0_array_idx = 48 + L0_search_point_offset;

        4: L0_array_idx = 4  + L0_search_point_offset;
        5: L0_array_idx = 20 + L0_search_point_offset;
        6: L0_array_idx = 36 + L0_search_point_offset;
        7: L0_array_idx = 52 + L0_search_point_offset;

        8: L0_array_idx  = 64 + L0_search_point_offset;
        9: L0_array_idx  = 80 + L0_search_point_offset;
        10: L0_array_idx = 96 + L0_search_point_offset;
        11: L0_array_idx = 112 + L0_search_point_offset;

        12: L0_array_idx = 68 + L0_search_point_offset;
        13: L0_array_idx = 84 + L0_search_point_offset;
        14: L0_array_idx = 100 + L0_search_point_offset;
        default: L0_array_idx = 116 + L0_search_point_offset;
    endcase
end

// reg [7:0] L1_array_idx;
always @(*) begin
    case (cal_cnt)
        0: L1_array_idx = 0  + L1_search_point_offset;
        1: L1_array_idx = 16 + L1_search_point_offset;
        2: L1_array_idx = 32 + L1_search_point_offset;
        3: L1_array_idx = 48 + L1_search_point_offset;

        4: L1_array_idx = 4  + L1_search_point_offset;
        5: L1_array_idx = 20 + L1_search_point_offset;
        6: L1_array_idx = 36 + L1_search_point_offset;
        7: L1_array_idx = 52 + L1_search_point_offset;

        8: L1_array_idx  = 64 + L1_search_point_offset;
        9: L1_array_idx  = 80 + L1_search_point_offset;
        10: L1_array_idx = 96 + L1_search_point_offset;
        11: L1_array_idx = 112 + L1_search_point_offset;

        12: L1_array_idx = 68 + L1_search_point_offset;
        13: L1_array_idx = 84 + L1_search_point_offset;
        14: L1_array_idx = 100 + L1_search_point_offset;
        default: L1_array_idx = 116 + L1_search_point_offset;
    endcase
end

// reg now_L0_frac_x;
// reg now_L0_frac_y;
// reg now_L1_frac_x;
// reg now_L1_frac_y;
always @(*) begin
    if (current_state == S_P1_CAL) begin
        now_L0_frac_x = p1_L0_frac_x;
        now_L0_frac_y = p1_L0_frac_y;
        now_L1_frac_x = p1_L1_frac_x;
        now_L1_frac_y = p1_L1_frac_y;
    end
    else begin
        now_L0_frac_x = p2_L0_frac_x;
        now_L0_frac_y = p2_L0_frac_y;
        now_L1_frac_x = p2_L1_frac_x;
        now_L1_frac_y = p2_L1_frac_y;
    end
end

// reg [7:0] L0_ip_result [0:3], L1_ip_result [0:3];      // 0~255
generate
    for (k = 0; k < 4; k = k + 1) begin : interpolation_gen_4
        CLIP_INTERPOLATION L0_clip_ip (
            .array_0(L0_15x16[(     k + L0_array_idx) +: 6]),
            .array_1(L0_15x16[(16 + k + L0_array_idx) +: 6]),
            .array_2(L0_15x16[(32 + k + L0_array_idx) +: 6]),
            .array_3(L0_15x16[(48 + k + L0_array_idx) +: 6]),
            .array_4(L0_15x16[(64 + k + L0_array_idx) +: 6]),
            .array_5(L0_15x16[(80 + k + L0_array_idx) +: 6]),
            .frac_x(now_L0_frac_x), .frac_y(now_L0_frac_y),
            
            .result(L0_ip_result[k])
        );

        CLIP_INTERPOLATION L1_clip_ip (
            .array_0(L1_15x16[(     k + L1_array_idx) +: 6]),
            .array_1(L1_15x16[(16 + k + L1_array_idx) +: 6]),
            .array_2(L1_15x16[(32 + k + L1_array_idx) +: 6]),
            .array_3(L1_15x16[(48 + k + L1_array_idx) +: 6]),
            .array_4(L1_15x16[(64 + k + L1_array_idx) +: 6]),
            .array_5(L1_15x16[(80 + k + L1_array_idx) +: 6]),
            .frac_x(now_L1_frac_x), .frac_y(now_L1_frac_y),
            
            .result(L1_ip_result[k])
        );
    end
endgenerate

// L0 - L1
// -255 ~ 255
// 100000001 ~ 011111111
// reg signed [8:0] residual [0:3];
always @(posedge clk) begin
    integer i;
    for (i = 0; i < 4; i = i + 1) residual[i] <= $signed({1'b0, L0_ip_result[i]}) - $signed({1'b0, L1_ip_result[i]});
end

// ----------- stage 2 -----------

// reg [1:0] stage_2_cnt; // 0~3
always @(posedge clk) begin
    stage_2_cnt <= cal_cnt[1:0];
end

// -1020 ~ 1020
// 10000000100
// 01111111100
// reg signed [10:0] tmp_4x4 [0:15];    // 11-bit
always @(posedge clk) begin
    tmp_4x4[{stage_2_cnt, 2'd0}] <= residual[0] + residual[1] + residual[2] + residual[3];
    tmp_4x4[{stage_2_cnt, 2'd1}] <= residual[0] - residual[1] + residual[2] - residual[3];
    tmp_4x4[{stage_2_cnt, 2'd2}] <= residual[0] + residual[1] - residual[2] - residual[3];
    tmp_4x4[{stage_2_cnt, 2'd3}] <= residual[0] - residual[1] - residual[2] + residual[3];
end

// ----------- stage 3 -----------

// reg [1:0] stage_2_cnt_d1; // 0~3
always @(posedge clk) begin
    stage_2_cnt_d1 <= stage_2_cnt;
end

// reg [3:0] stage_3_cnt; // 0~8
always @(posedge clk or negedge rst_n) begin
    if      (!rst_n)                 stage_3_cnt <= 4'd0;
    else if (cal_done)               stage_3_cnt <= 4'd0;
    else if (stage_2_cnt_d1 == 2'd3) stage_3_cnt <= stage_3_cnt + 4'd1;
end

function signed [12:0] abs;
    input signed [12:0] a;  // 13-bit
    reg signed [12:0] sign;
    reg [12:0] a_extend;
    begin
        sign = {13{a[12]}};
        abs = (a ^ sign) - sign;
        // abs = a[12] ? -a : a;
    end
endfunction

// reg signed [12:0] hadamard [0:15];
always @(*) begin
    hadamard[0] = tmp_4x4[0] + tmp_4x4[4] + tmp_4x4[8] + tmp_4x4[12];
    hadamard[1] = tmp_4x4[1] + tmp_4x4[5] + tmp_4x4[9] + tmp_4x4[13];
    hadamard[2] = tmp_4x4[2] + tmp_4x4[6] + tmp_4x4[10] + tmp_4x4[14];
    hadamard[3] = tmp_4x4[3] + tmp_4x4[7] + tmp_4x4[11] + tmp_4x4[15];
    hadamard[4] = tmp_4x4[0] - tmp_4x4[4] + tmp_4x4[8] - tmp_4x4[12];
    hadamard[5] = tmp_4x4[1] - tmp_4x4[5] + tmp_4x4[9] - tmp_4x4[13];
    hadamard[6] = tmp_4x4[2] - tmp_4x4[6] + tmp_4x4[10] - tmp_4x4[14];
    hadamard[7] = tmp_4x4[3] - tmp_4x4[7] + tmp_4x4[11] - tmp_4x4[15];
    hadamard[8] = tmp_4x4[0] + tmp_4x4[4] - tmp_4x4[8] - tmp_4x4[12];
    hadamard[9] = tmp_4x4[1] + tmp_4x4[5] - tmp_4x4[9] - tmp_4x4[13];
    hadamard[10] = tmp_4x4[2] + tmp_4x4[6] - tmp_4x4[10] - tmp_4x4[14];
    hadamard[11] = tmp_4x4[3] + tmp_4x4[7] - tmp_4x4[11] - tmp_4x4[15];
    hadamard[12] = tmp_4x4[0] - tmp_4x4[4] - tmp_4x4[8] + tmp_4x4[12];
    hadamard[13] = tmp_4x4[1] - tmp_4x4[5] - tmp_4x4[9] + tmp_4x4[13];
    hadamard[14] = tmp_4x4[2] - tmp_4x4[6] - tmp_4x4[10] + tmp_4x4[14];
    hadamard[15] = tmp_4x4[3] - tmp_4x4[7] - tmp_4x4[11] + tmp_4x4[15];
end

// reg signed [12:0] hadamard_abs [0:15];
always @(*) begin
    integer i;
    for (i = 0; i < 16; i = i + 1) hadamard_abs[i] = abs(hadamard[i]);
end

// reg [23:0] SATD;     // 0 ~ ?
always @(*) begin
    SATD = hadamard_abs[0]  + hadamard_abs[1]  + hadamard_abs[2]  + hadamard_abs[3] + 
           hadamard_abs[4]  + hadamard_abs[5]  + hadamard_abs[6]  + hadamard_abs[7] + 
           hadamard_abs[8]  + hadamard_abs[9]  + hadamard_abs[10] + hadamard_abs[11] + 
           hadamard_abs[12] + hadamard_abs[13] + hadamard_abs[14] + hadamard_abs[15];
end

// reg [23:0] SATD_p1_final;     // 0 ~ ?
// reg [3:0] search_point_final_p1;  // 0 ~ 8
always @(posedge clk) begin
    if (current_state == S_IDLE) begin
        SATD_p1_final <= 24'd0;
        search_point_final_p1 <= 4'd0;
    end
    else if (current_state == S_P1_CAL && SATD_p1_final < SATD && stage_2_cnt_d1 == 2'd3) begin
        SATD_p1_final <= SATD;
        search_point_final_p1 <= stage_3_cnt;
    end
end

// reg [23:0] SATD_p2_final;     // 0 ~ ?
// reg [3:0] search_point_final_p2;  // 0 ~ 8
always @(posedge clk) begin
    if (current_state == S_IDLE) begin
        SATD_p2_final <= 24'd0;
        search_point_final_p2 <= 4'd0;
    end
    else if (current_state == S_P2_CAL && SATD_p2_final < SATD && stage_2_cnt_d1 == 2'd3) begin
        SATD_p2_final <= SATD;
        search_point_final_p2 <= stage_3_cnt;
    end
end

// wire cal_done;
assign cal_done = (stage_3_cnt == 4'd8);

// --------------------------- output ---------------------------

wire [55:0] output_string = {search_point_final_p2, SATD_p2_final, search_point_final_p1, SATD_p1_final};

// reg [5:0] out_cnt;    // 0~55
always @(posedge clk) begin
    if (current_state == S_OUTPUT) out_cnt <= out_cnt + 6'd1;
    else out_cnt <= 6'd0;
end

// output reg out_valid;
always @(posedge clk or negedge rst_n) begin
    if      (!rst_n)                   out_valid <= 1'b0;
    else if (out_cnt == 6'd55)         out_valid <= 1'b0;
    else if (current_state == S_OUTPUT) out_valid <= 1'b1;
end

// output reg out_sad;
always @(posedge clk or negedge rst_n) begin
    if      (!rst_n)                    out_sad <= 1'b0;
    else if (out_cnt == 6'd55)          out_sad <= 1'b0;
    else if (current_state == S_OUTPUT) out_sad <= output_string[out_cnt];
end

//=======================================================
//                   MEM
//=======================================================

// Address = row * 8 + (col / 16)
// Address = row * 8 + block

// reg current_img;
// reg [6:0] current_row;
// reg [2:0] current_block;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        {current_img, current_row, current_block} <= 11'd0;
    end
    else if (in_valid) begin
        // current_img   <= input_cnt[14];
        // current_row   <= input_cnt[13:7];
        // current_block <= input_cnt[6:4];
        {current_img, current_row, current_block} <= input_cnt[14:4];
    end
    else begin     // TODO: combine p1, p2 using now_...
        case (current_state)
            S_P1_READ_L0: begin
                current_img   <= 1'b0;
                current_row   <= p1_L0_y_sub2      + {3'd0, read_cnt[4:1] & {4{((p1_L0_y + read_cnt) > 1)}}};
                current_block <= p1_L0_x_sub2[6:4] + {2'b0, read_cnt[0]};
            end
            S_P1_READ_L1: begin
                current_img   <= 1'b1;
                current_row   <= p1_L1_y_sub2      + {3'd0, read_cnt[4:1] & {4{((p1_L1_y + read_cnt) > 1)}}};
                current_block <= p1_L1_x_sub2[6:4] + {2'b0, read_cnt[0]};
            end
            S_P2_READ_L0: begin
                current_img   <= 1'b0;
                current_row   <= p2_L0_y_sub2      + {3'd0, read_cnt[4:1] & {4{((p2_L0_y + read_cnt) > 1)}}};
                current_block <= p2_L0_x_sub2[6:4] + {2'b0, read_cnt[0]};
            end
            S_P2_READ_L1: begin
                current_img   <= 1'b1;
                current_row   <= p2_L1_y_sub2      + {3'd0, read_cnt[4:1] & {4{((p2_L1_y + read_cnt) > 1)}}};
                current_block <= p2_L1_x_sub2[6:4] + {2'b0, read_cnt[0]};
            end
        endcase
    end
end

// reg web;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) web <= READ;
    else if (current_state == S_W_SRAM && (&input_cnt[3:0])) web <= WRITE;
    else web <= READ;
end

// reg [7:0] mem_din [0:15]
always @(posedge clk) begin
    mem_din[input_cnt[3:0]] <= in_data[8:1];
end

// reg [7:0] mem_dout [0:15]
MEM_INTERFACE sram_1 (.image(current_img), .row(current_row), .block(current_block), .Dout(mem_dout), .Din(mem_din), .clk(clk), .WEB(web));

endmodule

module MEM_INTERFACE (
    input       image,
    input [6:0] row,    // 0~127
    input [2:0] block,  // 0~7
    output [7:0] Dout [0:15],
    input  [7:0] Din  [0:15],
    input clk,
    input WEB
);

SRAM_16_PIXEL_2048 sram (
    .A0(block[0]),.A1(block[1]),.A2(block[2]),
    .A3(row[0]),.A4(row[1]),.A5(row[2]),.A6(row[3]),.A7(row[4]),.A8(row[5]),.A9(row[6]),
    .A10(image),
    
    .DO0(Dout[0][0]),.DO1(Dout[0][1]),.DO2(Dout[0][2]),.DO3(Dout[0][3]),.DO4(Dout[0][4]),.DO5(Dout[0][5]),.DO6(Dout[0][6]),.DO7(Dout[0][7]),
    .DO8(Dout[1][0]),.DO9(Dout[1][1]),.DO10(Dout[1][2]),.DO11(Dout[1][3]),.DO12(Dout[1][4]),.DO13(Dout[1][5]),.DO14(Dout[1][6]),.DO15(Dout[1][7]),
    .DO16(Dout[2][0]),.DO17(Dout[2][1]),.DO18(Dout[2][2]),.DO19(Dout[2][3]),.DO20(Dout[2][4]),.DO21(Dout[2][5]),.DO22(Dout[2][6]),.DO23(Dout[2][7]),
    .DO24(Dout[3][0]),.DO25(Dout[3][1]),.DO26(Dout[3][2]),.DO27(Dout[3][3]),.DO28(Dout[3][4]),.DO29(Dout[3][5]),.DO30(Dout[3][6]),.DO31(Dout[3][7]),
    .DO32(Dout[4][0]),.DO33(Dout[4][1]),.DO34(Dout[4][2]),.DO35(Dout[4][3]),.DO36(Dout[4][4]),.DO37(Dout[4][5]),.DO38(Dout[4][6]),.DO39(Dout[4][7]),
    .DO40(Dout[5][0]),.DO41(Dout[5][1]),.DO42(Dout[5][2]),.DO43(Dout[5][3]),.DO44(Dout[5][4]),.DO45(Dout[5][5]),.DO46(Dout[5][6]),.DO47(Dout[5][7]),
    .DO48(Dout[6][0]),.DO49(Dout[6][1]),.DO50(Dout[6][2]),.DO51(Dout[6][3]),.DO52(Dout[6][4]),.DO53(Dout[6][5]),.DO54(Dout[6][6]),.DO55(Dout[6][7]),
    .DO56(Dout[7][0]),.DO57(Dout[7][1]),.DO58(Dout[7][2]),.DO59(Dout[7][3]),.DO60(Dout[7][4]),.DO61(Dout[7][5]),.DO62(Dout[7][6]),.DO63(Dout[7][7]),
    .DO64(Dout[8][0]),.DO65(Dout[8][1]),.DO66(Dout[8][2]),.DO67(Dout[8][3]),.DO68(Dout[8][4]),.DO69(Dout[8][5]),.DO70(Dout[8][6]),.DO71(Dout[8][7]),
    .DO72(Dout[9][0]),.DO73(Dout[9][1]),.DO74(Dout[9][2]),.DO75(Dout[9][3]),.DO76(Dout[9][4]),.DO77(Dout[9][5]),.DO78(Dout[9][6]),.DO79(Dout[9][7]),
    .DO80(Dout[10][0]),.DO81(Dout[10][1]),.DO82(Dout[10][2]),.DO83(Dout[10][3]),.DO84(Dout[10][4]),.DO85(Dout[10][5]),.DO86(Dout[10][6]),.DO87(Dout[10][7]),
    .DO88(Dout[11][0]),.DO89(Dout[11][1]),.DO90(Dout[11][2]),.DO91(Dout[11][3]),.DO92(Dout[11][4]),.DO93(Dout[11][5]),.DO94(Dout[11][6]),.DO95(Dout[11][7]),
    .DO96(Dout[12][0]),.DO97(Dout[12][1]),.DO98(Dout[12][2]),.DO99(Dout[12][3]),.DO100(Dout[12][4]),.DO101(Dout[12][5]),.DO102(Dout[12][6]),.DO103(Dout[12][7]),
    .DO104(Dout[13][0]),.DO105(Dout[13][1]),.DO106(Dout[13][2]),.DO107(Dout[13][3]),.DO108(Dout[13][4]),.DO109(Dout[13][5]),.DO110(Dout[13][6]),.DO111(Dout[13][7]),
    .DO112(Dout[14][0]),.DO113(Dout[14][1]),.DO114(Dout[14][2]),.DO115(Dout[14][3]),.DO116(Dout[14][4]),.DO117(Dout[14][5]),.DO118(Dout[14][6]),.DO119(Dout[14][7]),
    .DO120(Dout[15][0]),.DO121(Dout[15][1]),.DO122(Dout[15][2]),.DO123(Dout[15][3]),.DO124(Dout[15][4]),.DO125(Dout[15][5]),.DO126(Dout[15][6]),.DO127(Dout[15][7]),

    
    .DI0(Din[0][0]),.DI1(Din[0][1]),.DI2(Din[0][2]),.DI3(Din[0][3]),.DI4(Din[0][4]),.DI5(Din[0][5]),.DI6(Din[0][6]),.DI7(Din[0][7]),
    .DI8(Din[1][0]),.DI9(Din[1][1]),.DI10(Din[1][2]),.DI11(Din[1][3]),.DI12(Din[1][4]),.DI13(Din[1][5]),.DI14(Din[1][6]),.DI15(Din[1][7]),
    .DI16(Din[2][0]),.DI17(Din[2][1]),.DI18(Din[2][2]),.DI19(Din[2][3]),.DI20(Din[2][4]),.DI21(Din[2][5]),.DI22(Din[2][6]),.DI23(Din[2][7]),
    .DI24(Din[3][0]),.DI25(Din[3][1]),.DI26(Din[3][2]),.DI27(Din[3][3]),.DI28(Din[3][4]),.DI29(Din[3][5]),.DI30(Din[3][6]),.DI31(Din[3][7]),
    .DI32(Din[4][0]),.DI33(Din[4][1]),.DI34(Din[4][2]),.DI35(Din[4][3]),.DI36(Din[4][4]),.DI37(Din[4][5]),.DI38(Din[4][6]),.DI39(Din[4][7]),
    .DI40(Din[5][0]),.DI41(Din[5][1]),.DI42(Din[5][2]),.DI43(Din[5][3]),.DI44(Din[5][4]),.DI45(Din[5][5]),.DI46(Din[5][6]),.DI47(Din[5][7]),
    .DI48(Din[6][0]),.DI49(Din[6][1]),.DI50(Din[6][2]),.DI51(Din[6][3]),.DI52(Din[6][4]),.DI53(Din[6][5]),.DI54(Din[6][6]),.DI55(Din[6][7]),
    .DI56(Din[7][0]),.DI57(Din[7][1]),.DI58(Din[7][2]),.DI59(Din[7][3]),.DI60(Din[7][4]),.DI61(Din[7][5]),.DI62(Din[7][6]),.DI63(Din[7][7]),
    .DI64(Din[8][0]),.DI65(Din[8][1]),.DI66(Din[8][2]),.DI67(Din[8][3]),.DI68(Din[8][4]),.DI69(Din[8][5]),.DI70(Din[8][6]),.DI71(Din[8][7]),
    .DI72(Din[9][0]),.DI73(Din[9][1]),.DI74(Din[9][2]),.DI75(Din[9][3]),.DI76(Din[9][4]),.DI77(Din[9][5]),.DI78(Din[9][6]),.DI79(Din[9][7]),
    .DI80(Din[10][0]),.DI81(Din[10][1]),.DI82(Din[10][2]),.DI83(Din[10][3]),.DI84(Din[10][4]),.DI85(Din[10][5]),.DI86(Din[10][6]),.DI87(Din[10][7]),
    .DI88(Din[11][0]),.DI89(Din[11][1]),.DI90(Din[11][2]),.DI91(Din[11][3]),.DI92(Din[11][4]),.DI93(Din[11][5]),.DI94(Din[11][6]),.DI95(Din[11][7]),
    .DI96(Din[12][0]),.DI97(Din[12][1]),.DI98(Din[12][2]),.DI99(Din[12][3]),.DI100(Din[12][4]),.DI101(Din[12][5]),.DI102(Din[12][6]),.DI103(Din[12][7]),
    .DI104(Din[13][0]),.DI105(Din[13][1]),.DI106(Din[13][2]),.DI107(Din[13][3]),.DI108(Din[13][4]),.DI109(Din[13][5]),.DI110(Din[13][6]),.DI111(Din[13][7]),
    .DI112(Din[14][0]),.DI113(Din[14][1]),.DI114(Din[14][2]),.DI115(Din[14][3]),.DI116(Din[14][4]),.DI117(Din[14][5]),.DI118(Din[14][6]),.DI119(Din[14][7]),
    .DI120(Din[15][0]),.DI121(Din[15][1]),.DI122(Din[15][2]),.DI123(Din[15][3]),.DI124(Din[15][4]),.DI125(Din[15][5]),.DI126(Din[15][6]),.DI127(Din[15][7]),
    
    .CK(clk),.WEB(WEB),.OE(1'b1),.CS(1'b1));

endmodule

module CLIP_INTERPOLATION (
    input  [7:0] array_0 [0:5],
    input  [7:0] array_1 [0:5],
    input  [7:0] array_2 [0:5],     // MV point == array_2[2]
    input  [7:0] array_3 [0:5],
    input  [7:0] array_4 [0:5],
    input  [7:0] array_5 [0:5],
    input frac_x,
    input frac_y,
    output reg [7:0] result
);

// 1, -5, 20, 20, -5, 1

// input:  0 ~ 255
// output: -2550 ~ 10710
// 111011000001010 ~ 010100111010110
function signed [14:0] interpolation;
    input [7:0] array [0:5];
    reg [7:0] p_m2, p_m1, p_0, p_1, p_2, p_3;
    reg [8:0] sum_01;
    reg [8:0] sum_m12;
    reg [8:0] sum_m23;
    reg signed [11:0] core;
    reg signed [14:0] val_mult_5;
    begin
        p_m2 = array[0];
        p_m1 = array[1];
        p_0 = array[2];
        p_1 = array[3];
        p_2 = array[4];
        p_3 = array[5];
        sum_01 = p_0 + p_1;
        sum_m12 = p_m1 + p_2;
        sum_m23 = p_m2 + p_3;

        core = $signed({1'b0, sum_01, 2'd0}) - $signed({3'b0, sum_m12});
        val_mult_5 = (core <<< 2) + core;
        interpolation = val_mult_5 + $signed({6'd0, sum_m23});
    end
endfunction

// input:  -2550 ~ 10710
// output: -214200 ~ 475320
// 11001011101101001000 ~ 01110100000010111000
function signed [9:0] clip_interpolation_signed;
    input signed [14:0] p_m2, p_m1, p_0, p_1, p_2, p_3;
    reg signed [15:0] sum_01;
    reg signed [15:0] sum_m12;
    reg signed [15:0] sum_m23;
    reg signed [17:0] core;
    reg signed [19:0] val_mult_5, tmp_result;
    begin
        // 21420
        // 0101001110101100
        // -5100
        // 1111110000010100
        // 16-bit
        sum_01 = p_0 + p_1;
        sum_m12 = p_m1 + p_2;
        sum_m23 = p_m2 + p_3;
        // 90780
        // 010110001010011100
        // -41820
        // 110101110010100100
        // 18-bit
        core = (sum_01 <<< 2) - sum_m12;
        // 453900
        // 01101110110100001100
        // -209110
        // 11001100111100110100
        // 20-bit
        val_mult_5 = (core <<< 2) + core;
        tmp_result = val_mult_5 + sum_m23 + 20'd512;

        clip_interpolation_signed = tmp_result[19:10];
    end
endfunction

wire signed [14:0] ip_0 = interpolation(array_0);
wire signed [14:0] ip_1 = interpolation(array_1);
wire signed [14:0] ip_2 = interpolation(array_2);
wire signed [14:0] ip_3 = interpolation(array_3);
wire signed [14:0] ip_4 = interpolation(array_4);
wire signed [14:0] ip_5 = interpolation(array_5);

wire [7:0] vertical_array [0:5];
assign vertical_array[0] = array_0[2];
assign vertical_array[1] = array_1[2];
assign vertical_array[2] = array_2[2];
assign vertical_array[3] = array_3[2];
assign vertical_array[4] = array_4[2];
assign vertical_array[5] = array_5[2];

wire signed [14:0] vertical_ip = interpolation(vertical_array);

wire signed [9:0] clip_hori = (ip_2        + 16) >>> 5;
wire signed [9:0] clip_vert = (vertical_ip + 16) >>> 5;
wire signed [9:0] clip_2D_ip = clip_interpolation_signed(ip_0, ip_1, ip_2, ip_3, ip_4, ip_5);


always @(*) begin
    case ({frac_x, frac_y})
        2'b00: begin        // no interpolation
            result = array_2[2];
        end
        2'b01: begin        // Horizontal
            if      (clip_hori < 0)   result = 8'd0;
            else if (clip_hori > 255) result = 8'd255;
            else                      result = clip_hori;
        end
        2'b10: begin        // Vertical
            if      (clip_vert < 0)   result = 8'd0;
            else if (clip_vert > 255) result = 8'd255;
            else                      result = clip_vert;
        end
        default: begin      // 2D
            if      (clip_2D_ip < 0)   result = 8'd0;
            else if (clip_2D_ip > 255) result = 8'd255;
            else                       result = clip_2D_ip;
        end
    endcase
end

endmodule
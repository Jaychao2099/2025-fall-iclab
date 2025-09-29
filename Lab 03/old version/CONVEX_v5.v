/**************************************************************************/
// Copyright (c) 2025, OASIS Lab
// MODULE: CONVEX
// FILE NAME: CONVEX.v
// VERSRION: 1.0
// DATE: August 15, 2025
// AUTHOR: Chao-En Kuo, NYCU IAIS
// DESCRIPTION: ICLAB2025FALL / LAB3 / CONVEX
// MODIFICATION HISTORY:
// Date                 Description
// 
/**************************************************************************/
module CONVEX (
	// Input
	rst_n,
	clk,
	in_valid,
	pt_num,
	in_x,
	in_y,
	// Output
	out_valid,
	out_x,
	out_y,
	drop_num
);

//---------------------------------------------------------------------
//   PORT DECLARATION          
//---------------------------------------------------------------------
input				rst_n;
input				clk;

input				in_valid;
input		[8:0]	pt_num;     // 4 ~ 500
input		[9:0]	in_x;
input		[9:0]	in_y;

output reg			out_valid;
output reg	[9:0]	out_x;
output reg 	[9:0]	out_y;
output reg	[6:0]	drop_num;

//---------------------------------------------------------------------
//   PARAMETER & INTEGER DECLARATION
//---------------------------------------------------------------------
parameter S_IDLE    = 0;
parameter S_SOLVING = 1;
parameter S_OUTPUT  = 2;

genvar g;

//---------------------------------------------------------------------
//   REG & WIRE DECLARATION
//---------------------------------------------------------------------

reg [8:0] pt_num_reg;     // 4 ~ 500
reg [9:0]	in_x_reg;
reg [9:0]	in_y_reg;

reg [1:0] current_state, next_state;
reg [8:0] pt_cnt;

reg [9:0] hull_array_x [0:127], hull_array_y [0:127];
reg [9:0] hull_array_x_reg [0:127], hull_array_y_reg [0:127];
reg [8:0] hull_size;

reg [9:0] drop_array_x [0:127], drop_array_y [0:127];
reg [6:0] drop_num_reg;
reg	[6:0] prev_drop_num_reg;
reg [6:0] drop_cnt;

reg [8:0] end_drop_idx, start_drop_idx;
wire new_is_out;

reg signed [1:0] cross_product_result [0:127];
reg [6:0] zero_cnt;
reg [6:0] neg_cnt;


//---------------------------------------------------------------------
//   DESIGN
//---------------------------------------------------------------------

// ------------------------ function ------------------------

// 1 = v_a -> v_b is counter clockwise
// 0 = v_a -> v_b is clockwise or Collinear

// function cross_product;
function signed [1:0] cross_product;
    input [9:0] new_x, new_y;
    input [9:0] a_x, a_y;
    input [9:0] b_x, b_y;

    reg signed [10:0] va_x, va_y;
    reg signed [10:0] vb_x, vb_y;
    reg signed [31:0] val;
    begin
        va_x = {1'b0, a_x} - {1'b0, new_x};
        va_y = {1'b0, a_y} - {1'b0, new_y};

        vb_x = {1'b0, b_x} - {1'b0, new_x};
        vb_y = {1'b0, b_y} - {1'b0, new_y};

        val = va_x * vb_y - vb_x * va_y;
        if      (val > 0) cross_product = 1;
        else if (val < 0) cross_product = -1;
        else              cross_product = 0;
        // cross_product = (val > 0) ? 1'b1 : 1'b0;
    end
endfunction


// ------------------------ input buffer ------------------------

// input [8:0] pt_num_reg;     // 4 ~ 500
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) pt_num_reg <= 9'd0;
    else if (in_valid && pt_num > 0) pt_num_reg <= pt_num;
    else pt_num_reg <= pt_num_reg;
end

// input [9:0]	in_x_reg;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) in_x_reg <= 10'd0;
    else if (in_valid) in_x_reg <= in_x;
    else in_x_reg <= in_x_reg;
end

// input [9:0]	in_y_reg;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) in_y_reg <= 10'd0;
    else if (in_valid) in_y_reg <= in_y;
    else in_y_reg <= in_y_reg;
end

// reg [1:0] current_state;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) current_state <= S_IDLE;
    else        current_state <= next_state;
end

// ------------------------ FSM ------------------------

// reg [1:0] next_state;
always @(*) begin
    case (current_state)
        S_IDLE: begin
            if (in_valid) next_state = S_SOLVING;
            else          next_state = S_IDLE;
        end
        S_SOLVING: begin
            next_state = S_OUTPUT;
        end
        S_OUTPUT: begin
            if (drop_cnt + 1 == drop_num_reg || drop_num_reg == 0 || pt_cnt <= 3) next_state = S_IDLE;
            else next_state = S_OUTPUT;   // drop_num_reg > 1
        end
        default: next_state = current_state;
    endcase
end

// reg [8:0] pt_cnt;
always @(posedge clk or negedge rst_n) begin
    if      (!rst_n)                                          pt_cnt <= 9'd0;
    else if (current_state == S_SOLVING)                      pt_cnt <= pt_cnt + 9'd1;
    else if (current_state == S_IDLE && pt_cnt == pt_num_reg) pt_cnt <= 9'd0;
    else                                                      pt_cnt <= pt_cnt;
end

// ------------------------ data structure ------------------------

// reg [9:0] hull_array_x_reg [0:127], hull_array_y_reg [0:127];
always @(posedge clk or negedge rst_n) begin
    integer i;
    if (!rst_n) begin
        for (i = 0; i < 128; i = i + 1) begin
            hull_array_x_reg[i] <= 10'd0;
            hull_array_y_reg[i] <= 10'd0;
        end
    end
    else begin
        hull_array_x_reg <= hull_array_x;
        hull_array_y_reg <= hull_array_y;
    end
end

// reg [9:0] hull_array_x_reg [0:127], hull_array_y_reg [0:127];
always @(*) begin
    integer i;
    hull_array_x = hull_array_x_reg;
    hull_array_y = hull_array_y_reg;
    if (pt_cnt == pt_num_reg) begin
        for (i = 0; i < 128; i = i + 1) begin
            hull_array_x[i] = 10'd0;
            hull_array_y[i] = 10'd0;
        end
    end
    else if (current_state == S_SOLVING && pt_cnt < 3) begin
        if (pt_cnt == 2 && cross_product(hull_array_x[1], hull_array_y[1],
                                         in_x_reg       , in_y_reg,
                                         hull_array_x[0], hull_array_y[0]) < 0) begin  // if 0 -> 1 -> 2 == clockwise
            hull_array_x[1] = in_x_reg;            hull_array_y[1] = in_y_reg;
            hull_array_x[2] = hull_array_x_reg[1]; hull_array_y[2] = hull_array_y_reg[1];
        end
        else begin
            hull_array_x[hull_size] = in_x_reg; hull_array_y[hull_size] = in_y_reg;
        end
    end
    else if (current_state == S_SOLVING) begin
        if (new_is_out == 1) begin      // drop 0 ~ n old dots
            if (zero_cnt != 1 || neg_cnt != 0) begin
                if (start_drop_idx < end_drop_idx) begin
                    for (i = 0; i < 128; i = i + 1) begin
                        if (i <= start_drop_idx) begin
                            hull_array_x[i] = hull_array_x_reg[i];
                            hull_array_y[i] = hull_array_y_reg[i];
                        end
                        else if (i == start_drop_idx + 1) begin
                            hull_array_x[i] = in_x_reg;
                            hull_array_y[i] = in_y_reg;
                        end
                        else if (i > start_drop_idx + 1 && (i + end_drop_idx - start_drop_idx - 2) < hull_size) begin
                            hull_array_x[i] = hull_array_x_reg[i + end_drop_idx - start_drop_idx - 2];
                            hull_array_y[i] = hull_array_y_reg[i + end_drop_idx - start_drop_idx - 2];
                        end
                        else begin
                            hull_array_x[i] = 9'd0;
                            hull_array_y[i] = 9'd0;
                        end
                    end
                end
                else begin  // end_drop_idx < start_drop_idx
                    for (i = 0; i < 128; i = i + 1) begin
                        if (end_drop_idx + i <= start_drop_idx) begin
                            hull_array_x[i] = hull_array_x_reg[end_drop_idx + i];
                            hull_array_y[i] = hull_array_y_reg[end_drop_idx + i];
                        end
                        else if (end_drop_idx + i == start_drop_idx + 1) begin
                            hull_array_x[i] = in_x_reg;
                            hull_array_y[i] = in_y_reg;
                        end
                        else begin
                            hull_array_x[i] = 9'd0;
                            hull_array_y[i] = 9'd0;
                        end
                    end
                end
            end
        end
        // else begin      // drop new dots
        //     ;// hull do nothing
        // end
    end
end

// reg [8:0] hull_size;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) hull_size <= 9'd0;
    else if (pt_cnt == pt_num_reg) hull_size <= 9'd0;
    else if (current_state == S_SOLVING && pt_cnt < 3) hull_size <= hull_size + 9'd1;
    else if (current_state == S_SOLVING) hull_size <= hull_size + 1 - drop_num_reg;
    else hull_size <= hull_size;
end

// reg [9:0] drop_array_x [0:127], drop_array_y [0:127];
always @(posedge clk or negedge rst_n) begin
    integer i;
    if (!rst_n) begin
        for (i = 0; i < 128; i = i + 1) begin
            drop_array_x[i] <= 10'd0;
            drop_array_y[i] <= 10'd0;
        end
    end
    else if (current_state == S_IDLE) begin
        for (i = 0; i < 128; i = i + 1) begin
            drop_array_x[i] <= 10'd0;
            drop_array_y[i] <= 10'd0;
        end
    end
    else if (current_state == S_SOLVING) begin
        if (new_is_out) begin      // drop 0 ~ n old dots
            if (zero_cnt == 1 && neg_cnt == 0) begin
                for (i = 0; i < 128; i = i + 1) begin
                    if (i == 0) begin
                        drop_array_x[i] <= in_x_reg;
                        drop_array_y[i] <= in_y_reg;
                    end
                    else begin
                        drop_array_x[i] <= 10'd0;
                        drop_array_y[i] <= 10'd0;
                    end
                end
            end
            else if (start_drop_idx < end_drop_idx) begin
                for (i = 0; i < 128; i = i + 1) begin
                    if (start_drop_idx + i + 1 < end_drop_idx) begin
                        drop_array_x[i] <= hull_array_x_reg[start_drop_idx + i + 1];
                        drop_array_y[i] <= hull_array_y_reg[start_drop_idx + i + 1];
                    end
                    else begin
                        drop_array_x[i] <= drop_array_x[i];
                        drop_array_y[i] <= drop_array_y[i];
                    end
                end
            end
            else begin  // end_drop_idx < start_drop_idx
                for (i = 0; i < 128; i = i + 1) begin
                    if (i < end_drop_idx) begin
                        drop_array_x[i] <= hull_array_x_reg[i];
                        drop_array_y[i] <= hull_array_y_reg[i];
                    end
                    else if (i < hull_size - end_drop_idx + start_drop_idx - 1) begin
                        drop_array_x[i] <= hull_array_x_reg[i + start_drop_idx - end_drop_idx + 1];
                        drop_array_y[i] <= hull_array_y_reg[i + start_drop_idx - end_drop_idx + 1];
                    end
                    else begin
                        drop_array_x[i] <= drop_array_x[i];
                        drop_array_y[i] <= drop_array_y[i];
                    end
                end
            end
        end
        else begin      // drop new dots
            for (i = 0; i < 128; i = i + 1) begin
                drop_array_x[i] <= (i == 0) ? in_x_reg : drop_array_x[i];
                drop_array_y[i] <= (i == 0) ? in_y_reg : drop_array_y[i];
            end
        end
    end
    else begin
        drop_array_x <= drop_array_x;
        drop_array_y <= drop_array_y;
    end
end

// reg	[6:0] prev_drop_num_reg;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) prev_drop_num_reg <= 7'd0;
    else prev_drop_num_reg <= drop_num_reg;
end

// reg	[6:0] drop_num_reg;
always @(*) begin
    drop_num_reg = 7'd0;
    if (current_state == S_SOLVING && new_is_out == 1'b1) begin      // drop 0 ~ n old dots
        if (zero_cnt == 1 && neg_cnt == 0) drop_num_reg = 1;
        else if (start_drop_idx > end_drop_idx)  drop_num_reg = (hull_size - start_drop_idx) + (end_drop_idx) - 1;
        else if (start_drop_idx != end_drop_idx) drop_num_reg = end_drop_idx - start_drop_idx - 1;
    end
    else if (current_state == S_SOLVING) drop_num_reg = 7'd1;       // drop new dots
    else if (current_state == S_OUTPUT && pt_cnt > 3) drop_num_reg = prev_drop_num_reg;
end


// reg [6:0] drop_cnt;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) drop_cnt <= 7'd0;
    else if (current_state == S_OUTPUT && drop_cnt < drop_num_reg) drop_cnt <= drop_cnt + 1;
    else drop_cnt <= 7'd0;
end

// ------------------------ output ------------------------

// output reg			out_valid;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) out_valid <= 1'b0;
    else if (current_state == S_OUTPUT && (drop_cnt < drop_num_reg || drop_num_reg == 0)) out_valid <= 1'b1;
    else out_valid <= 1'b0;
end

// output reg	[9:0]	out_x;
// output reg 	[9:0]	out_y;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        out_x <= 10'd0;
        out_y <= 10'd0;
    end
    else if (current_state == S_IDLE) begin
        out_x <= 10'd0;
        out_y <= 10'd0;
    end
    else if (current_state == S_OUTPUT && drop_cnt < drop_num_reg) begin
        if (pt_cnt <= 3) begin
            out_x <= 10'd0;
            out_y <= 10'd0;
        end
        else begin
            out_x <= drop_array_x[drop_cnt];
            out_y <= drop_array_y[drop_cnt];
        end
    end
    else begin
        out_x <= 10'd0;
        out_y <= 10'd0;
    end
end

// output reg	[6:0]	drop_num;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) drop_num <= 7'd0;
    else if (current_state == S_OUTPUT && drop_cnt < drop_num_reg) begin
        if (pt_cnt <= 3) drop_num <= 7'd0;
        else             drop_num <= drop_num_reg;
    end
    else drop_num <= 7'd0;
end

// ------------------------ input check ------------------------

// reg [8:0] end_drop_idx, start_drop_idx;
always @(*) begin
    integer i;
    end_drop_idx = 9'd0;
    start_drop_idx = 9'd0;
    if (pt_cnt > 2) begin
        for (i = 0; i < 128; i = i + 1) begin
            if (i < hull_size && new_is_out != 0) begin
                if      (cross_product_result[(i+hull_size-1)%hull_size] <= 0 && cross_product_result[i] == 1) end_drop_idx = i;
                else if (cross_product_result[(i+hull_size-1)%hull_size] == 1 && cross_product_result[i] <= 0) start_drop_idx = i;
            end
        end
    end
end

// wire new_is_out
assign new_is_out = (zero_cnt > 0 || neg_cnt > 0);

// reg signed [1:0] cross_product_result [0:127];
always @(*) begin
    integer i;
    if (pt_cnt > 2) begin
        for (i = 0; i < 128; i = i + 1) begin
            cross_product_result[i] = cross_product(in_x_reg                         , in_y_reg,
                                                    hull_array_x_reg[i]              , hull_array_y_reg[i],
                                                    hull_array_x_reg[(i+1)%hull_size], hull_array_y_reg[(i+1)%hull_size]);
        end
    end
    else for (i = 0; i < 128; i = i + 1) cross_product_result[i] = 0;
end

// reg [6:0] zero_cnt;
always @(*) begin
    zero_cnt =  (cross_product_result[0] == 0 && 0 < hull_size ? 1 : 0) +
                (cross_product_result[1] == 0 && 1 < hull_size ? 1 : 0) +
                (cross_product_result[2] == 0 && 2 < hull_size ? 1 : 0) +
                (cross_product_result[3] == 0 && 3 < hull_size ? 1 : 0) +
                (cross_product_result[4] == 0 && 4 < hull_size ? 1 : 0) +
                (cross_product_result[5] == 0 && 5 < hull_size ? 1 : 0) +
                (cross_product_result[6] == 0 && 6 < hull_size ? 1 : 0) +
                (cross_product_result[7] == 0 && 7 < hull_size ? 1 : 0) +
                (cross_product_result[8] == 0 && 8 < hull_size ? 1 : 0) +
                (cross_product_result[9] == 0 && 9 < hull_size ? 1 : 0) +
                (cross_product_result[10] == 0 && 10 < hull_size ? 1 : 0) +
                (cross_product_result[11] == 0 && 11 < hull_size ? 1 : 0) +
                (cross_product_result[12] == 0 && 12 < hull_size ? 1 : 0) +
                (cross_product_result[13] == 0 && 13 < hull_size ? 1 : 0) +
                (cross_product_result[14] == 0 && 14 < hull_size ? 1 : 0) +
                (cross_product_result[15] == 0 && 15 < hull_size ? 1 : 0) +
                (cross_product_result[16] == 0 && 16 < hull_size ? 1 : 0) +
                (cross_product_result[17] == 0 && 17 < hull_size ? 1 : 0) +
                (cross_product_result[18] == 0 && 18 < hull_size ? 1 : 0) +
                (cross_product_result[19] == 0 && 19 < hull_size ? 1 : 0) +
                (cross_product_result[20] == 0 && 20 < hull_size ? 1 : 0) +
                (cross_product_result[21] == 0 && 21 < hull_size ? 1 : 0) +
                (cross_product_result[22] == 0 && 22 < hull_size ? 1 : 0) +
                (cross_product_result[23] == 0 && 23 < hull_size ? 1 : 0) +
                (cross_product_result[24] == 0 && 24 < hull_size ? 1 : 0) +
                (cross_product_result[25] == 0 && 25 < hull_size ? 1 : 0) +
                (cross_product_result[26] == 0 && 26 < hull_size ? 1 : 0) +
                (cross_product_result[27] == 0 && 27 < hull_size ? 1 : 0) +
                (cross_product_result[28] == 0 && 28 < hull_size ? 1 : 0) +
                (cross_product_result[29] == 0 && 29 < hull_size ? 1 : 0) +
                (cross_product_result[30] == 0 && 30 < hull_size ? 1 : 0) +
                (cross_product_result[31] == 0 && 31 < hull_size ? 1 : 0) +
                (cross_product_result[32] == 0 && 32 < hull_size ? 1 : 0) +
                (cross_product_result[33] == 0 && 33 < hull_size ? 1 : 0) +
                (cross_product_result[34] == 0 && 34 < hull_size ? 1 : 0) +
                (cross_product_result[35] == 0 && 35 < hull_size ? 1 : 0) +
                (cross_product_result[36] == 0 && 36 < hull_size ? 1 : 0) +
                (cross_product_result[37] == 0 && 37 < hull_size ? 1 : 0) +
                (cross_product_result[38] == 0 && 38 < hull_size ? 1 : 0) +
                (cross_product_result[39] == 0 && 39 < hull_size ? 1 : 0) +
                (cross_product_result[40] == 0 && 40 < hull_size ? 1 : 0) +
                (cross_product_result[41] == 0 && 41 < hull_size ? 1 : 0) +
                (cross_product_result[42] == 0 && 42 < hull_size ? 1 : 0) +
                (cross_product_result[43] == 0 && 43 < hull_size ? 1 : 0) +
                (cross_product_result[44] == 0 && 44 < hull_size ? 1 : 0) +
                (cross_product_result[45] == 0 && 45 < hull_size ? 1 : 0) +
                (cross_product_result[46] == 0 && 46 < hull_size ? 1 : 0) +
                (cross_product_result[47] == 0 && 47 < hull_size ? 1 : 0) +
                (cross_product_result[48] == 0 && 48 < hull_size ? 1 : 0) +
                (cross_product_result[49] == 0 && 49 < hull_size ? 1 : 0) +
                (cross_product_result[50] == 0 && 50 < hull_size ? 1 : 0) +
                (cross_product_result[51] == 0 && 51 < hull_size ? 1 : 0) +
                (cross_product_result[52] == 0 && 52 < hull_size ? 1 : 0) +
                (cross_product_result[53] == 0 && 53 < hull_size ? 1 : 0) +
                (cross_product_result[54] == 0 && 54 < hull_size ? 1 : 0) +
                (cross_product_result[55] == 0 && 55 < hull_size ? 1 : 0) +
                (cross_product_result[56] == 0 && 56 < hull_size ? 1 : 0) +
                (cross_product_result[57] == 0 && 57 < hull_size ? 1 : 0) +
                (cross_product_result[58] == 0 && 58 < hull_size ? 1 : 0) +
                (cross_product_result[59] == 0 && 59 < hull_size ? 1 : 0) +
                (cross_product_result[60] == 0 && 60 < hull_size ? 1 : 0) +
                (cross_product_result[61] == 0 && 61 < hull_size ? 1 : 0) +
                (cross_product_result[62] == 0 && 62 < hull_size ? 1 : 0) +
                (cross_product_result[63] == 0 && 63 < hull_size ? 1 : 0) +
                (cross_product_result[64] == 0 && 64 < hull_size ? 1 : 0) +
                (cross_product_result[65] == 0 && 65 < hull_size ? 1 : 0) +
                (cross_product_result[66] == 0 && 66 < hull_size ? 1 : 0) +
                (cross_product_result[67] == 0 && 67 < hull_size ? 1 : 0) +
                (cross_product_result[68] == 0 && 68 < hull_size ? 1 : 0) +
                (cross_product_result[69] == 0 && 69 < hull_size ? 1 : 0) +
                (cross_product_result[70] == 0 && 70 < hull_size ? 1 : 0) +
                (cross_product_result[71] == 0 && 71 < hull_size ? 1 : 0) +
                (cross_product_result[72] == 0 && 72 < hull_size ? 1 : 0) +
                (cross_product_result[73] == 0 && 73 < hull_size ? 1 : 0) +
                (cross_product_result[74] == 0 && 74 < hull_size ? 1 : 0) +
                (cross_product_result[75] == 0 && 75 < hull_size ? 1 : 0) +
                (cross_product_result[76] == 0 && 76 < hull_size ? 1 : 0) +
                (cross_product_result[77] == 0 && 77 < hull_size ? 1 : 0) +
                (cross_product_result[78] == 0 && 78 < hull_size ? 1 : 0) +
                (cross_product_result[79] == 0 && 79 < hull_size ? 1 : 0) +
                (cross_product_result[80] == 0 && 80 < hull_size ? 1 : 0) +
                (cross_product_result[81] == 0 && 81 < hull_size ? 1 : 0) +
                (cross_product_result[82] == 0 && 82 < hull_size ? 1 : 0) +
                (cross_product_result[83] == 0 && 83 < hull_size ? 1 : 0) +
                (cross_product_result[84] == 0 && 84 < hull_size ? 1 : 0) +
                (cross_product_result[85] == 0 && 85 < hull_size ? 1 : 0) +
                (cross_product_result[86] == 0 && 86 < hull_size ? 1 : 0) +
                (cross_product_result[87] == 0 && 87 < hull_size ? 1 : 0) +
                (cross_product_result[88] == 0 && 88 < hull_size ? 1 : 0) +
                (cross_product_result[89] == 0 && 89 < hull_size ? 1 : 0) +
                (cross_product_result[90] == 0 && 90 < hull_size ? 1 : 0) +
                (cross_product_result[91] == 0 && 91 < hull_size ? 1 : 0) +
                (cross_product_result[92] == 0 && 92 < hull_size ? 1 : 0) +
                (cross_product_result[93] == 0 && 93 < hull_size ? 1 : 0) +
                (cross_product_result[94] == 0 && 94 < hull_size ? 1 : 0) +
                (cross_product_result[95] == 0 && 95 < hull_size ? 1 : 0) +
                (cross_product_result[96] == 0 && 96 < hull_size ? 1 : 0) +
                (cross_product_result[97] == 0 && 97 < hull_size ? 1 : 0) +
                (cross_product_result[98] == 0 && 98 < hull_size ? 1 : 0) +
                (cross_product_result[99] == 0 && 99 < hull_size ? 1 : 0) +
                (cross_product_result[100] == 0 && 100 < hull_size ? 1 : 0) +
                (cross_product_result[101] == 0 && 101 < hull_size ? 1 : 0) +
                (cross_product_result[102] == 0 && 102 < hull_size ? 1 : 0) +
                (cross_product_result[103] == 0 && 103 < hull_size ? 1 : 0) +
                (cross_product_result[104] == 0 && 104 < hull_size ? 1 : 0) +
                (cross_product_result[105] == 0 && 105 < hull_size ? 1 : 0) +
                (cross_product_result[106] == 0 && 106 < hull_size ? 1 : 0) +
                (cross_product_result[107] == 0 && 107 < hull_size ? 1 : 0) +
                (cross_product_result[108] == 0 && 108 < hull_size ? 1 : 0) +
                (cross_product_result[109] == 0 && 109 < hull_size ? 1 : 0) +
                (cross_product_result[110] == 0 && 110 < hull_size ? 1 : 0) +
                (cross_product_result[111] == 0 && 111 < hull_size ? 1 : 0) +
                (cross_product_result[112] == 0 && 112 < hull_size ? 1 : 0) +
                (cross_product_result[113] == 0 && 113 < hull_size ? 1 : 0) +
                (cross_product_result[114] == 0 && 114 < hull_size ? 1 : 0) +
                (cross_product_result[115] == 0 && 115 < hull_size ? 1 : 0) +
                (cross_product_result[116] == 0 && 116 < hull_size ? 1 : 0) +
                (cross_product_result[117] == 0 && 117 < hull_size ? 1 : 0) +
                (cross_product_result[118] == 0 && 118 < hull_size ? 1 : 0) +
                (cross_product_result[119] == 0 && 119 < hull_size ? 1 : 0) +
                (cross_product_result[120] == 0 && 120 < hull_size ? 1 : 0) +
                (cross_product_result[121] == 0 && 121 < hull_size ? 1 : 0) +
                (cross_product_result[122] == 0 && 122 < hull_size ? 1 : 0) +
                (cross_product_result[123] == 0 && 123 < hull_size ? 1 : 0) +
                (cross_product_result[124] == 0 && 124 < hull_size ? 1 : 0) +
                (cross_product_result[125] == 0 && 125 < hull_size ? 1 : 0) +
                (cross_product_result[126] == 0 && 126 < hull_size ? 1 : 0) +
                (cross_product_result[127] == 0 && 127 < hull_size ? 1 : 0);
end

// reg [6:0] neg_cnt;
always @(*) begin
    neg_cnt =   (cross_product_result[0] == -1 && 0 < hull_size ? 1 : 0) +
                (cross_product_result[1] == -1 && 1 < hull_size ? 1 : 0) +
                (cross_product_result[2] == -1 && 2 < hull_size ? 1 : 0) +
                (cross_product_result[3] == -1 && 3 < hull_size ? 1 : 0) +
                (cross_product_result[4] == -1 && 4 < hull_size ? 1 : 0) +
                (cross_product_result[5] == -1 && 5 < hull_size ? 1 : 0) +
                (cross_product_result[6] == -1 && 6 < hull_size ? 1 : 0) +
                (cross_product_result[7] == -1 && 7 < hull_size ? 1 : 0) +
                (cross_product_result[8] == -1 && 8 < hull_size ? 1 : 0) +
                (cross_product_result[9] == -1 && 9 < hull_size ? 1 : 0) +
                (cross_product_result[10] == -1 && 10 < hull_size ? 1 : 0) +
                (cross_product_result[11] == -1 && 11 < hull_size ? 1 : 0) +
                (cross_product_result[12] == -1 && 12 < hull_size ? 1 : 0) +
                (cross_product_result[13] == -1 && 13 < hull_size ? 1 : 0) +
                (cross_product_result[14] == -1 && 14 < hull_size ? 1 : 0) +
                (cross_product_result[15] == -1 && 15 < hull_size ? 1 : 0) +
                (cross_product_result[16] == -1 && 16 < hull_size ? 1 : 0) +
                (cross_product_result[17] == -1 && 17 < hull_size ? 1 : 0) +
                (cross_product_result[18] == -1 && 18 < hull_size ? 1 : 0) +
                (cross_product_result[19] == -1 && 19 < hull_size ? 1 : 0) +
                (cross_product_result[20] == -1 && 20 < hull_size ? 1 : 0) +
                (cross_product_result[21] == -1 && 21 < hull_size ? 1 : 0) +
                (cross_product_result[22] == -1 && 22 < hull_size ? 1 : 0) +
                (cross_product_result[23] == -1 && 23 < hull_size ? 1 : 0) +
                (cross_product_result[24] == -1 && 24 < hull_size ? 1 : 0) +
                (cross_product_result[25] == -1 && 25 < hull_size ? 1 : 0) +
                (cross_product_result[26] == -1 && 26 < hull_size ? 1 : 0) +
                (cross_product_result[27] == -1 && 27 < hull_size ? 1 : 0) +
                (cross_product_result[28] == -1 && 28 < hull_size ? 1 : 0) +
                (cross_product_result[29] == -1 && 29 < hull_size ? 1 : 0) +
                (cross_product_result[30] == -1 && 30 < hull_size ? 1 : 0) +
                (cross_product_result[31] == -1 && 31 < hull_size ? 1 : 0) +
                (cross_product_result[32] == -1 && 32 < hull_size ? 1 : 0) +
                (cross_product_result[33] == -1 && 33 < hull_size ? 1 : 0) +
                (cross_product_result[34] == -1 && 34 < hull_size ? 1 : 0) +
                (cross_product_result[35] == -1 && 35 < hull_size ? 1 : 0) +
                (cross_product_result[36] == -1 && 36 < hull_size ? 1 : 0) +
                (cross_product_result[37] == -1 && 37 < hull_size ? 1 : 0) +
                (cross_product_result[38] == -1 && 38 < hull_size ? 1 : 0) +
                (cross_product_result[39] == -1 && 39 < hull_size ? 1 : 0) +
                (cross_product_result[40] == -1 && 40 < hull_size ? 1 : 0) +
                (cross_product_result[41] == -1 && 41 < hull_size ? 1 : 0) +
                (cross_product_result[42] == -1 && 42 < hull_size ? 1 : 0) +
                (cross_product_result[43] == -1 && 43 < hull_size ? 1 : 0) +
                (cross_product_result[44] == -1 && 44 < hull_size ? 1 : 0) +
                (cross_product_result[45] == -1 && 45 < hull_size ? 1 : 0) +
                (cross_product_result[46] == -1 && 46 < hull_size ? 1 : 0) +
                (cross_product_result[47] == -1 && 47 < hull_size ? 1 : 0) +
                (cross_product_result[48] == -1 && 48 < hull_size ? 1 : 0) +
                (cross_product_result[49] == -1 && 49 < hull_size ? 1 : 0) +
                (cross_product_result[50] == -1 && 50 < hull_size ? 1 : 0) +
                (cross_product_result[51] == -1 && 51 < hull_size ? 1 : 0) +
                (cross_product_result[52] == -1 && 52 < hull_size ? 1 : 0) +
                (cross_product_result[53] == -1 && 53 < hull_size ? 1 : 0) +
                (cross_product_result[54] == -1 && 54 < hull_size ? 1 : 0) +
                (cross_product_result[55] == -1 && 55 < hull_size ? 1 : 0) +
                (cross_product_result[56] == -1 && 56 < hull_size ? 1 : 0) +
                (cross_product_result[57] == -1 && 57 < hull_size ? 1 : 0) +
                (cross_product_result[58] == -1 && 58 < hull_size ? 1 : 0) +
                (cross_product_result[59] == -1 && 59 < hull_size ? 1 : 0) +
                (cross_product_result[60] == -1 && 60 < hull_size ? 1 : 0) +
                (cross_product_result[61] == -1 && 61 < hull_size ? 1 : 0) +
                (cross_product_result[62] == -1 && 62 < hull_size ? 1 : 0) +
                (cross_product_result[63] == -1 && 63 < hull_size ? 1 : 0) +
                (cross_product_result[64] == -1 && 64 < hull_size ? 1 : 0) +
                (cross_product_result[65] == -1 && 65 < hull_size ? 1 : 0) +
                (cross_product_result[66] == -1 && 66 < hull_size ? 1 : 0) +
                (cross_product_result[67] == -1 && 67 < hull_size ? 1 : 0) +
                (cross_product_result[68] == -1 && 68 < hull_size ? 1 : 0) +
                (cross_product_result[69] == -1 && 69 < hull_size ? 1 : 0) +
                (cross_product_result[70] == -1 && 70 < hull_size ? 1 : 0) +
                (cross_product_result[71] == -1 && 71 < hull_size ? 1 : 0) +
                (cross_product_result[72] == -1 && 72 < hull_size ? 1 : 0) +
                (cross_product_result[73] == -1 && 73 < hull_size ? 1 : 0) +
                (cross_product_result[74] == -1 && 74 < hull_size ? 1 : 0) +
                (cross_product_result[75] == -1 && 75 < hull_size ? 1 : 0) +
                (cross_product_result[76] == -1 && 76 < hull_size ? 1 : 0) +
                (cross_product_result[77] == -1 && 77 < hull_size ? 1 : 0) +
                (cross_product_result[78] == -1 && 78 < hull_size ? 1 : 0) +
                (cross_product_result[79] == -1 && 79 < hull_size ? 1 : 0) +
                (cross_product_result[80] == -1 && 80 < hull_size ? 1 : 0) +
                (cross_product_result[81] == -1 && 81 < hull_size ? 1 : 0) +
                (cross_product_result[82] == -1 && 82 < hull_size ? 1 : 0) +
                (cross_product_result[83] == -1 && 83 < hull_size ? 1 : 0) +
                (cross_product_result[84] == -1 && 84 < hull_size ? 1 : 0) +
                (cross_product_result[85] == -1 && 85 < hull_size ? 1 : 0) +
                (cross_product_result[86] == -1 && 86 < hull_size ? 1 : 0) +
                (cross_product_result[87] == -1 && 87 < hull_size ? 1 : 0) +
                (cross_product_result[88] == -1 && 88 < hull_size ? 1 : 0) +
                (cross_product_result[89] == -1 && 89 < hull_size ? 1 : 0) +
                (cross_product_result[90] == -1 && 90 < hull_size ? 1 : 0) +
                (cross_product_result[91] == -1 && 91 < hull_size ? 1 : 0) +
                (cross_product_result[92] == -1 && 92 < hull_size ? 1 : 0) +
                (cross_product_result[93] == -1 && 93 < hull_size ? 1 : 0) +
                (cross_product_result[94] == -1 && 94 < hull_size ? 1 : 0) +
                (cross_product_result[95] == -1 && 95 < hull_size ? 1 : 0) +
                (cross_product_result[96] == -1 && 96 < hull_size ? 1 : 0) +
                (cross_product_result[97] == -1 && 97 < hull_size ? 1 : 0) +
                (cross_product_result[98] == -1 && 98 < hull_size ? 1 : 0) +
                (cross_product_result[99] == -1 && 99 < hull_size ? 1 : 0) +
                (cross_product_result[100] == -1 && 100 < hull_size ? 1 : 0) +
                (cross_product_result[101] == -1 && 101 < hull_size ? 1 : 0) +
                (cross_product_result[102] == -1 && 102 < hull_size ? 1 : 0) +
                (cross_product_result[103] == -1 && 103 < hull_size ? 1 : 0) +
                (cross_product_result[104] == -1 && 104 < hull_size ? 1 : 0) +
                (cross_product_result[105] == -1 && 105 < hull_size ? 1 : 0) +
                (cross_product_result[106] == -1 && 106 < hull_size ? 1 : 0) +
                (cross_product_result[107] == -1 && 107 < hull_size ? 1 : 0) +
                (cross_product_result[108] == -1 && 108 < hull_size ? 1 : 0) +
                (cross_product_result[109] == -1 && 109 < hull_size ? 1 : 0) +
                (cross_product_result[110] == -1 && 110 < hull_size ? 1 : 0) +
                (cross_product_result[111] == -1 && 111 < hull_size ? 1 : 0) +
                (cross_product_result[112] == -1 && 112 < hull_size ? 1 : 0) +
                (cross_product_result[113] == -1 && 113 < hull_size ? 1 : 0) +
                (cross_product_result[114] == -1 && 114 < hull_size ? 1 : 0) +
                (cross_product_result[115] == -1 && 115 < hull_size ? 1 : 0) +
                (cross_product_result[116] == -1 && 116 < hull_size ? 1 : 0) +
                (cross_product_result[117] == -1 && 117 < hull_size ? 1 : 0) +
                (cross_product_result[118] == -1 && 118 < hull_size ? 1 : 0) +
                (cross_product_result[119] == -1 && 119 < hull_size ? 1 : 0) +
                (cross_product_result[120] == -1 && 120 < hull_size ? 1 : 0) +
                (cross_product_result[121] == -1 && 121 < hull_size ? 1 : 0) +
                (cross_product_result[122] == -1 && 122 < hull_size ? 1 : 0) +
                (cross_product_result[123] == -1 && 123 < hull_size ? 1 : 0) +
                (cross_product_result[124] == -1 && 124 < hull_size ? 1 : 0) +
                (cross_product_result[125] == -1 && 125 < hull_size ? 1 : 0) +
                (cross_product_result[126] == -1 && 126 < hull_size ? 1 : 0) +
                (cross_product_result[127] == -1 && 127 < hull_size ? 1 : 0);
end

endmodule
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
parameter S_CP      = 1;
parameter S_SOLVING = 2;
parameter S_OUTPUT  = 3;

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
reg [6:0] hull_size;

reg [9:0] drop_array_x [0:127], drop_array_y [0:127];
reg [6:0] drop_num_reg;
reg	[6:0] prev_drop_num_reg;
reg [6:0] drop_cnt;

reg [6:0] end_drop_idx, start_drop_idx;
wire new_is_out;

reg signed [1:0] cross_product_result [0:127];
wire signed [1:0] current_cp_result;
reg [6:0] cal_cnt;
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
            if (in_valid) next_state = S_CP;
            else          next_state = S_IDLE;
        end
        S_CP: begin
            if (cal_cnt == hull_size || pt_cnt < 3) next_state = S_SOLVING;
            else                                    next_state = S_CP;       // calculate cross-product 128 cycle
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
                            hull_array_x[i] = 10'd0;
                            hull_array_y[i] = 10'd0;
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
                            hull_array_x[i] = 10'd0;
                            hull_array_y[i] = 10'd0;
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

// reg [6:0] hull_size;
always @(posedge clk or negedge rst_n) begin
    if      (!rst_n)                                   hull_size <= 7'd0;
    else if (pt_cnt == pt_num_reg)                     hull_size <= 7'd0;
    else if (current_state == S_SOLVING && pt_cnt < 3) hull_size <= hull_size + 7'd1;
    else if (current_state == S_SOLVING)               hull_size <= hull_size + 1 - drop_num_reg;
    else                                               hull_size <= hull_size;
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
        if (new_is_out && (zero_cnt != 1 || neg_cnt != 0)) begin      // drop 0 ~ n old dots
            if (start_drop_idx < end_drop_idx) begin
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
    // if (!rst_n) drop_num_reg <= 7'd0;
    if (current_state == S_SOLVING && new_is_out == 1'b1) begin      // drop 0 ~ n old dots
        if (zero_cnt == 1 && neg_cnt == 0)       drop_num_reg <= 1;
        else if (start_drop_idx > end_drop_idx)  drop_num_reg <= (hull_size - start_drop_idx) + (end_drop_idx) - 1;
        else if (start_drop_idx != end_drop_idx) drop_num_reg <= end_drop_idx - start_drop_idx - 1;
        else drop_num_reg <= 7'd0;
    end
    else if (current_state == S_SOLVING)              drop_num_reg <= 7'd1;       // drop new dots
    else if (current_state == S_OUTPUT && pt_cnt > 3) drop_num_reg <= prev_drop_num_reg;
    else drop_num_reg <= 7'd0;
end


// reg [6:0] drop_cnt;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)                                                    drop_cnt <= 7'd0;
    else if (current_state == S_OUTPUT && drop_cnt < drop_num_reg) drop_cnt <= drop_cnt + 1;
    else                                                           drop_cnt <= 7'd0;
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
    else if (current_state == S_OUTPUT && drop_cnt < drop_num_reg && pt_cnt > 3) begin
        out_x <= drop_array_x[drop_cnt];
        out_y <= drop_array_y[drop_cnt];
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

// reg [6:0] end_drop_idx, start_drop_idx;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        end_drop_idx <= 7'd0;
        start_drop_idx <= 7'd0;
    end
    else if (current_state == S_IDLE) begin
        end_drop_idx <= 7'd0;
        start_drop_idx <= 7'd0;
    end
    else if (current_state == S_CP && pt_cnt > 2 && cal_cnt > 0) begin
        if      (cal_cnt == hull_size && cross_product_result[hull_size - 1] <= 0 && cross_product_result[0] == 1) begin
            end_drop_idx <= 7'd0;
            start_drop_idx <= start_drop_idx;
        end
        else if (cal_cnt == hull_size && cross_product_result[hull_size - 1] == 1 && cross_product_result[0] <= 0) begin
            end_drop_idx <= end_drop_idx;
            start_drop_idx <= 7'd0;
        end
        else if (cal_cnt < hull_size && cross_product_result[cal_cnt - 1] <= 0 && current_cp_result == 1) begin
            end_drop_idx <= cal_cnt;
            start_drop_idx <= start_drop_idx;
        end
        else if (cal_cnt < hull_size && cross_product_result[cal_cnt - 1] == 1 && current_cp_result <= 0) begin
            end_drop_idx <= end_drop_idx;
            start_drop_idx <= cal_cnt;
        end
    end
    else begin
        end_drop_idx <= end_drop_idx;
        start_drop_idx <= start_drop_idx;
    end
end

// reg [127:0] end_mask, start_mask;

// always @(*) begin
//     integer i;
//     for (i = 0; i < 128; i = i + 1) begin 
//         end_mask[i]   = (cross_product_result[(i+hull_size-1)%hull_size] <= 0) && (cross_product_result[i] == 1);
//         start_mask[i] = (cross_product_result[(i+hull_size-1)%hull_size] == )1 && (cross_product_result[i] <= 0);
//     end
// end

// wire new_is_out
assign new_is_out = (zero_cnt > 0 || neg_cnt > 0);

assign current_cp_result = cross_product(in_x_reg                               , in_y_reg,
                                         hull_array_x_reg[cal_cnt]              , hull_array_y_reg[cal_cnt],
                                         hull_array_x_reg[(cal_cnt+1)%hull_size], hull_array_y_reg[(cal_cnt+1)%hull_size]);

// reg signed [1:0] cross_product_result [0:127];
// reg [6:0] cal_cnt;
always @(posedge clk or negedge rst_n) begin
    integer i;
    if (!rst_n) begin
        for (i = 0; i < 128; i = i + 1) cross_product_result[i] <= 0;
        cal_cnt <= 7'd0;
        zero_cnt <= 7'd0;
        neg_cnt <= 7'd0;
    end
    else if (current_state == S_IDLE) begin
        for (i = 0; i < 128; i = i + 1) cross_product_result[i] <= 0;
        cal_cnt <= 7'd0;
        zero_cnt <= 7'd0;
        neg_cnt <= 7'd0;
    end
    else if (current_state == S_CP && pt_cnt > 2 && cal_cnt < hull_size) begin
        cross_product_result[cal_cnt] <= current_cp_result;
        cal_cnt <= cal_cnt + 7'd1;
        zero_cnt <= (current_cp_result == 0) ? zero_cnt + 7'd1 : zero_cnt;
        neg_cnt <= (current_cp_result == -1) ? neg_cnt + 7'd1 : neg_cnt;
    end
    else begin
        cross_product_result <= cross_product_result;
        cal_cnt <= cal_cnt;
        zero_cnt <= zero_cnt;
        neg_cnt <= neg_cnt;
    end
end

endmodule
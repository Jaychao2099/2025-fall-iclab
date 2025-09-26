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

input [8:0] pt_num_reg;     // 4 ~ 500
input [9:0]	in_x_reg;
input [9:0]	in_y_reg;

reg [1:0] current_state, next_state;
reg [8:0] pt_cnt;

reg [9:0] hull_array_x [0:127], hull_array_y [0:127];
reg [9:0] hull_array_x_reg [0:127], hull_array_y_reg [0:127];
reg [8:0] hull_size;

reg [9:0] drop_array_x [0:127], drop_array_y [0:127];
reg [6:0] drop_num_reg;
reg [6:0] drop_cnt;

reg [8:0] end_drop_idx, start_drop_idx;
reg [8:0] end_drop_idx_reg, start_drop_idx_reg;
reg new_is_out;
reg new_is_out_reg;


//---------------------------------------------------------------------
//   DESIGN
//---------------------------------------------------------------------

// ------------------------ function ------------------------

// 1 = v_a -> v_b is counter clockwise
// 0 = v_a -> v_b is clockwise or Collinear

function cross_product;
// function signed [1:0] cross_product;
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
        // if      (val > 0) cross_product = 1;
        // else if (val < 0) cross_product = -1;
        // else              cross_product = 0;
        cross_product = (val > 0) ? 1'b1 : 1'b0;
    end
endfunction


// ------------------------ input buffer ------------------------

// input [8:0] pt_num_reg;     // 4 ~ 500
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) pt_num_reg <= 9'd0;
    else if (in_valid) pt_num_reg <= pt_num;
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
            if      (in_valid && pt_cnt < 9'd3) next_state = S_OUTPUT;   // input 只有 1 cycle
            else if (in_valid)                  next_state = S_SOLVING;
            else                                next_state = S_IDLE;
        end
        S_SOLVING: begin
            next_state <= S_OUTPUT;
        end
        S_OUTPUT: begin
            if (drop_cnt == drop_num_reg) next_state = S_IDLE;
            else                      next_state = S_OUTPUT;   // drop_num_reg > 1
        end
        default: next_state = current_state;
    endcase
end

// reg [8:0] pt_cnt;
always @(posedge clk or negedge rst_n) begin
    if      (!rst_n)               pt_cnt <= 9'd0;
    else if (in_valid)             pt_cnt <= pt_cnt + 9'd1;
    else if (pt_cnt == pt_num_reg) pt_cnt <= 9'd0;
    else                           pt_cnt <= pt_cnt;
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
always @(*) begin       // 要改 posedge clk or negedge rst_n ?????
    integer i;
    hull_array_x = hull_array_x_reg;
    hull_array_y = hull_array_y_reg;
    if (in_valid && pt_cnt < 3) begin
        hull_array_x[hull_size] = in_x;
        hull_array_y[hull_size] = in_y;
        if (pt_cnt == 2 && cross_product(hull_array_x[0], hull_array_y[0],
                                         hull_array_x[1], hull_array_y[1],
                                         hull_array_x[2], hull_array_y[2]) == 1'd0) begin  // if 0 -> 1 -> 2 == clockwise
            hull_array_x[1] = in_x;                hull_array_y[1] = in_y;
            hull_array_x[2] = hull_array_x_reg[1]; hull_array_y[2] = hull_array_y_reg[1];
        end
    end
    else if (current_state == S_SOLVING) begin
        if (new_is_out_reg == 1) begin      // drop 0 ~ n old dots
            if (start_drop_idx_reg < end_drop_idx_reg) begin
                for (i = 0; i < 128; i = i + 1) begin
                    if (i <= start_drop_idx_reg) begin
                        hull_array_x[i] = hull_array_x_reg[i];
                        hull_array_y[i] = hull_array_y_reg[i];
                    end
                    else if (i == start_drop_idx_reg + 1) begin
                        hull_array_x[i] = in_x_reg;
                        hull_array_y[i] = in_y_reg;
                    end
                    else if (i > start_drop_idx_reg + 1 && (i + end_drop_idx_reg - start_drop_idx_reg - 2) < hull_size) begin
                        hull_array_x[i] = hull_array_x_reg[i + end_drop_idx_reg - start_drop_idx_reg - 2];
                        hull_array_y[i] = hull_array_y_reg[i + end_drop_idx_reg - start_drop_idx_reg - 2];
                    end
                    else begin
                        hull_array_x[i] = 9'd0;
                        hull_array_y[i] = 9'd0;
                    end
                end
            end
            else begin  // end_drop_idx_reg < start_drop_idx_reg
                for (i = 0; i < 128; i = i + 1) begin
                    if (end_drop_idx_reg + i <= start_drop_idx_reg) begin
                        hull_array_x[i] = hull_array_x_reg[end_drop_idx_reg + i];
                        hull_array_y[i] = hull_array_y_reg[end_drop_idx_reg + i];
                    end
                    else if (end_drop_idx_reg + i == start_drop_idx_reg + 1) begin
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
        // else begin      // drop new dots
        //     ;// hull do nothing
        // end
    end
end

// reg [8:0] hull_size;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) hull_size <= 9'd0;
    else if (in_valid && pt_cnt < 3) hull_size <= hull_size + 9'd1;
    else if (pt_cnt == pt_num_reg && current_state == S_IDLE) hull_size <= 9'd0;
    else ;
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
        if (new_is_out_reg == 1) begin      // drop 0 ~ n old dots
            if (start_drop_idx_reg < end_drop_idx_reg) begin
                for (i = 0; i < 128; i = i + 1) begin
                    if (i < start_drop_idx_reg - end_drop_idx_reg) begin
                        drop_array_x[i] <= hull_array_x_reg[start_drop_idx_reg + i + 1];
                        drop_array_y[i] <= hull_array_y_reg[start_drop_idx_reg + i + 1];
                    end
                    else begin
                        drop_array_x[i] <= drop_array_x[i];
                        drop_array_y[i] <= drop_array_y[i];
                    end
                end
            end
            else begin  // end_drop_idx_reg < start_drop_idx_reg
                for (i = 0; i < 128; i = i + 1) begin
                    if (i < end_drop_idx_reg) begin
                        drop_array_x[i] <= hull_array_x_reg[i];
                        drop_array_y[i] <= hull_array_y_reg[i];
                    end
                    else if (i < hull_size - end_drop_idx_reg + start_drop_idx_reg - 1) begin
                        drop_array_x[i] <= hull_array_x_reg[i + start_drop_idx_reg - end_drop_idx_reg + 1];
                        drop_array_y[i] <= hull_array_y_reg[i + start_drop_idx_reg - end_drop_idx_reg + 1];
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
                drop_array_x[i] <= (i == 1) ? in_x_reg : drop_array_x[i];
                drop_array_y[i] <= (i == 1) ? in_y_reg : drop_array_y[i];
            end
        end
    end
    else begin
        drop_array_x <= drop_array_x;
        drop_array_y <= drop_array_y;
    end
end

// reg	[6:0] drop_num_reg;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) drop_num_reg <= 7'd0;
    else if (current_state == S_SOLVING) begin
        if (new_is_out_reg == 1'b1) begin      // drop 0 ~ n old dots
            if (start_drop_idx_reg < end_drop_idx_reg) drop_num_reg <= (hull_size - end_drop_idx_reg) + (start_drop_idx_reg) - 1;
            else                                       drop_num_reg <= start_drop_idx_reg - end_drop_idx_reg - 1;
        end
        else begin      // drop new dots
            drop_num_reg <= 7'd1;
        end
    end
    else drop_num_reg <= drop_num_reg;
end


// reg [6:0] drop_cnt;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) drop_cnt <= 7'd0;
    else if (current_state == S_OUTPUT) drop_cnt <= drop_cnt + 1;
    else drop_cnt <= 7'd0;
end

// ------------------------ output ------------------------

// output reg			out_valid;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) out_valid <= 1'b0;
    else if (current_state == S_OUTPUT) out_valid <= 1'b1;
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
    else if (current_state == S_OUTPUT) begin
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
        out_x <= out_x;
        out_y <= out_y;
    end
end

// output reg	[6:0]	drop_num;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) drop_num <= 7'd0;
    else if (current_state == S_OUTPUT) begin
        if (pt_cnt <= 3) drop_num <= 7'd0;
        else             drop_num <= drop_num_reg;
    end
    else drop_num <= 7'd0;
end

// ------------------------ input check ------------------------

// reg [8:0] end_drop_idx_reg, start_drop_idx_reg;
// reg new_is_out_reg;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        end_drop_idx_reg <= 9'd0;
        start_drop_idx_reg <= 9'd0;
        new_is_out_reg <= 1'b0;
    end
    else begin
        end_drop_idx_reg <= end_drop_idx;
        start_drop_idx_reg <= start_drop_idx;
        new_is_out_reg <= new_is_out;
    end
end

// reg [8:0] end_drop_idx, start_drop_idx;
// reg new_is_out;
always @(*) begin
    if (in_valid && pt_cnt > 2) begin
        end_drop_idx = 9'd0;
        start_drop_idx = 9'd0;
        for (i = 0; i < 128; i = i + 1) begin
            if (i < hull_size && new_is_out != 0) begin
                if      (cross_product_result[(i+hull_size-1)%hull_size] == 1'b0 && cross_product_result[i] == 1'b1) end_drop_idx = i;
                else if (cross_product_result[(i+hull_size-1)%hull_size] == 1'b1 && cross_product_result[i] == 1'b0) start_drop_idx = i;
            end
        end
    end
    else begin
        end_drop_idx = end_drop_idx_reg;
        start_drop_idx = start_drop_idx_reg;
    end
end

always @(*) begin
    new_is_out = new_is_out_reg;
    if (in_valid && pt_cnt > 2) begin
        new_is_out = |(cross_product_result);
    end
end

reg [127:0] cross_product_result;

// reg [127:0] cross_product_result;
always @(*) begin
    integer i;
    cross_product_result = 128'd0;
    if (in_valid && pt_cnt > 2) begin
        for (i = 0; i < 128; i = i + 1) begin
            cross_product_result[i] = cross_product(in_x                             , in_y,
                                                    hull_array_x_reg[i]              , hull_array_y_reg[i],
                                                    hull_array_x_reg[(i+1)%hull_size], hull_array_y_reg[(i+1)%hull_size]);
        end
    end
end

















endmodule
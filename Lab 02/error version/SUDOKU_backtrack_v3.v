module SUDOKU(
    //Input Port
    clk,
    rst_n,
	in_valid,
	in,

    //Output Port
    out_valid,
    out
    );

//==============================
//   INPUT/OUTPUT DECLARATION
//==============================
input clk;
input rst_n;
input in_valid;
input [3:0] in;

output reg out_valid;
output reg [3:0] out;
    
//==============================
//   PARAMETER DECLARATION
//==============================

// parameter S_IDLE      = 0;
// parameter S_INPUT     = 1;
// parameter S_SOLVING   = 2;
// parameter S_OUTPUT    = 3;

parameter S_IDLE      = 3'd0;
parameter S_INPUT     = 3'd1;
parameter S_SOLVING   = 3'd2;
parameter S_BACKTRACK = 3'd3;
parameter S_OUTPUT    = 3'd4;

//==============================
//   LOGIC DECLARATION                                                 
//==============================

reg [2:0] current_state, next_state;
wire done;
reg [80:0] not_zero;
reg [6:0] out_cnt;  // 0 ~ 81

reg [3:0] map [0:80];
reg [3:0] next_map [0:80];

reg [8:0] row  [0:8];   // row[x][i] == 1 ---> in row[x], i is used
reg [8:0] col  [0:8];   // col[x][i] == 1 ---> in col[x], i is used
reg [8:0] grid [0:8];   // grid[x][i] == 1 ---> in grid[x], i is used

reg [8:0] candidate [0:80];

wire [8:0] untested_mask;

// for each layer:
// 1. current index (0 ~ 80, 7 bit)
// 2. numbers already tried (for current index) (9-bit mask)
parameter IDX_WIDTH = 7;
parameter MASK_WIDTH = 9;
reg [IDX_WIDTH + MASK_WIDTH - 1 : 0] stack [0:80];  // {7-bit current_index, 9-bit mask}
reg [6:0]     top;   // Stack Pointer

wire [6:0] stack_top_idx;
wire [8:0] stack_top_tried_mask;

wire [3:0] next_top_val;

reg [6:0] first_empty_idx;
wire [8:0] candidates_of_first_empty;

reg do_forward_move;
reg do_backward_move;

wire [3:0] val_to_try;

//==============================
//   Design                                                            
//==============================

function [3:0] index_to_row;    // 0 ~ 8
    input [6:0] idx;    // 0 ~ 80
    index_to_row = idx / 9;
endfunction

function [3:0] index_to_col;
    input [6:0] idx;
    index_to_col = idx % 9;
endfunction

function [3:0] index_to_grid;
    input [6:0] idx;
    index_to_grid = (idx / 27) * 3 + (idx % 9) / 3;
endfunction

// reg [2:0] current_state
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) current_state <= S_IDLE;
    else current_state <= next_state;
end

// reg [2:0] next_state
always @(*) begin
    case (current_state)
        S_IDLE: begin
            if (in_valid) next_state = S_INPUT;
            else          next_state = S_IDLE;
        end
        S_INPUT: begin
            if (in_valid) next_state = S_INPUT;
            else          next_state = S_SOLVING;
        end
        S_SOLVING: begin
            if (done)                 next_state = S_OUTPUT;
            else if (do_forward_move) next_state = S_SOLVING;
            else                      next_state = S_BACKTRACK;
        end
        S_BACKTRACK: begin
            if (next_top_val > 0) next_state = S_SOLVING;   // try next number in same stack entry
            else if (top > 0)     next_state = S_BACKTRACK; // pop next stack entry
            else                  next_state = S_IDLE;      // stack is empty (should not happen)
        end
        S_OUTPUT: begin
            if (out_cnt == 80) next_state = S_IDLE;
            else               next_state = S_OUTPUT;
        end
        default: next_state = current_state;
    endcase
end

// reg [6:0] out_cnt;  // 0 ~ 80
always @(posedge clk) begin
    if (current_state == S_OUTPUT && out_cnt < 80) out_cnt <= out_cnt + 1;
    else out_cnt <= 7'd0;
end

// output reg out_valid;
always @(posedge clk or negedge rst_n) begin
    if      (!rst_n)                    out_valid <= 1'd0;
    else if (current_state == S_OUTPUT) out_valid <= 1'b1;
    else                                out_valid <= 1'b0;
end

// output reg [3:0] out;
always @(posedge clk or negedge rst_n) begin
    if      (!rst_n)                    out <= 4'd0;
    else if (current_state == S_OUTPUT) out <= map[out_cnt];
    else                                out <= 4'd0;
end

// candidate have only 1 bit == 1
function is_single;
    input [8:0] m;
    is_single = (m != 9'b0) && ((m & (m - 1)) == 9'b0);
endfunction

function [3:0] find_next_val;
    input [8:0] mask;
    reg [3:0] val;
    integer i;
    begin
        if      (mask[0]) val = 1;
        else if (mask[1]) val = 2;
        else if (mask[2]) val = 3;
        else if (mask[3]) val = 4;
        else if (mask[4]) val = 5;
        else if (mask[5]) val = 6;
        else if (mask[6]) val = 7;
        else if (mask[7]) val = 8;
        else if (mask[8]) val = 9;
        else val = 0;       // not found
        find_next_val = val;
    end
endfunction

// for is_single == 1 used
function [3:0] find_first_value;
    input [8:0] mask;
    find_first_value = find_next_val(mask);
endfunction

// wire [6:0] stack_top_idx;
// wire [8:0] stack_top_tried_mask;
assign stack_top_idx        = stack[top-1][15:9];
assign stack_top_tried_mask = stack[top-1][8:0];

// wire [3:0] next_top_val;
assign next_top_val = find_next_val(~stack_top_tried_mask);

// reg [6:0] first_empty_idx;
always @(*) begin
    integer i;
    first_empty_idx = 81;
    for (i = 80; i >= 0; i = i - 1) begin
        if (map[i] == 0) first_empty_idx = i;
    end
end

assign candidates_of_first_empty = (first_empty_idx < 81) ? candidate[first_empty_idx] : 9'b0;

always @(*) begin
    if (first_empty_idx == 81) begin // no '0' (done == 1)
        do_forward_move  = 1'b0;
        do_backward_move = 1'b0;
    end
    else if (candidates_of_first_empty != 0) begin   // has path
        do_forward_move  = 1'b1;
        do_backward_move = 1'b0;
    end
    else begin                      // no path (contradiction)
        do_forward_move  = 1'b0;
        do_backward_move = 1'b1;
    end
end

// wire [3:0] val_to_try;
assign val_to_try = find_first_value(candidates_of_first_empty);

// wire done;
assign done = (&(not_zero)) ? 1'b1 : 1'b0;

// reg [80:0] not_zero;
always @(*) begin
    integer i;
    for (i = 0; i < 81; i = i + 1) begin
        not_zero[i] = |(map[i]);
    end
end

// reg [3:0] map [0:80];
always @(posedge clk) begin
    integer i;
    if (in_valid) begin
        map[80] <= in;
        for (i = 1; i < 81; i = i + 1) begin
            map[i - 1] <= map[i];
        end
    end
    else map <= next_map;
end

// reg [3:0] next_map [0:80];
always @(*) begin
    integer i;
    next_map = map;
    case (current_state)
        // S_IDLE: begin
        //     for (i = 0; i < 81; i = i + 1) next_map[i] = 4'b0;
        // end
        S_SOLVING: begin
            if (!done && do_forward_move) next_map[first_empty_idx] = val_to_try;
        end
        S_BACKTRACK: begin
            if (next_top_val > 0) next_map[stack_top_idx] = next_top_val;
            else                  next_map[stack_top_idx] = 4'b0;
        end
    endcase
end

// reg [6:0]     top;   // Stack Pointer, top == 0 -----> stack empty
always @(posedge clk) begin
    case (current_state)
        S_IDLE: top <= 7'b0;
        S_SOLVING: begin
            if (!done && do_forward_move) top <= top + 1;
            else top <= top;
        end
        S_BACKTRACK: begin
            if (next_top_val == 0 && top > 0) top <= top - 1;
            else top <= top;
        end
        default: top <= top;
    endcase
end

reg [7 + 9 - 1 : 0] next_stack [0:80];  // {7-bit current_index, 9-bit mas

// reg [7 + 9 - 1 : 0] stack [0:80];  // {7-bit current_index, 9-bit mask}
always @(posedge clk) begin
    stack <= next_stack;
end

// reg [7 + 9 - 1 : 0] next_stack [0:80];  // {7-bit current_index, 9-bit mask}
always @(*) begin
    integer i;
    next_stack = stack;
    if (current_state == S_IDLE) begin
        for (i = 0; i < 81; i = i + 1) next_stack[i] = {(IDX_WIDTH + MASK_WIDTH){1'b0}};
    end
    else if (!done) begin
        case (current_state)
            S_SOLVING: begin
                if (do_forward_move) begin
                    next_stack[top] = {first_empty_idx, (9'b1 << (val_to_try - 1))};
                    // next_stack[top] = {first_empty_idx, candidate[i] | (9'b1 << (val_to_try - 1))};
                end
            end
            S_BACKTRACK: begin
                if (next_top_val > 0) begin
                    next_stack[top-1] = {stack_top_idx, stack_top_tried_mask | (9'b1 << (next_top_val - 1))};
                end
            end
        endcase
    end
end

// reg [8:0] row  [0:8];   // row[x][i] == 1 ---> in row[x], i is used
always @(*) begin
    integer i, j;
    for (i = 0; i < 9; i = i + 1) begin     // row index
        // row[i] = 9'b0;
        for (j = 1; j <= 9; j = j + 1) begin     // number
            row[i][j-1] = (map[i*9]   == j) || (map[i*9+1] == j) || (map[i*9+2] == j) ||
                          (map[i*9+3] == j) || (map[i*9+4] == j) || (map[i*9+5] == j) ||
                          (map[i*9+6] == j) || (map[i*9+7] == j) || (map[i*9+8] == j);
        end
    end
end

// reg [8:0] col  [0:8];   // col[x][i] == 1 ---> in col[x], i is used
always @(*) begin
    integer i, j;
    for (i = 0; i < 9; i = i + 1) begin     // col index
        // col[i] = 9'b0;
        for (j = 1; j <= 9; j = j + 1) begin     // number
            col[i][j-1] = (map[i]    == j) || (map[i+9]  == j) || (map[i+18] == j) ||
                          (map[i+27] == j) || (map[i+36] == j) || (map[i+45] == j) ||
                          (map[i+54] == j) || (map[i+63] == j) || (map[i+72] == j);
        end
    end
end

// reg [8:0] grid [0:8];   // grid[x][i] == 1 ---> in grid[x], i is used
always @(*) begin
    integer i, j;
    for (i = 0; i < 9; i = i + 1) begin      // grid index
        // grid[i] = 9'b0;
        for (j = 1; j <= 9; j = j + 1) begin     // number
            grid[i][j-1] = (map[i*3 + (i/3)*18]      == j) || (map[i*3 + (i/3)*18 + 1]  == j) || (map[i*3 + (i/3)*18 + 2]  == j) ||
                           (map[i*3 + (i/3)*18 + 9]  == j) || (map[i*3 + (i/3)*18 + 10] == j) || (map[i*3 + (i/3)*18 + 11] == j) ||
                           (map[i*3 + (i/3)*18 + 18] == j) || (map[i*3 + (i/3)*18 + 19] == j) || (map[i*3 + (i/3)*18 + 20] == j);
        end
    end
end

// reg [8:0] candidate [0:80];  // candidate[x][i] == 1 ---> in map[x], i is candidate
always @(*) begin
    integer i;
    for (i = 0; i < 81; i = i + 1) begin
        if (map[i] == 4'd0) begin
            candidate[i] = ~( row[index_to_row(i)] | col[index_to_col(i)] | grid[index_to_grid(i)] );
        end
        else candidate[i] = 9'b0;
    end
end

endmodule
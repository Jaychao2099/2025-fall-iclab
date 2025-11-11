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

parameter S_IDLE        = 0;
parameter S_INPUT       = 1;
parameter S_SINGLE      = 2;
parameter S_TRY         = 3;
parameter S_BACKTRACK   = 4;
parameter S_OUTPUT      = 5;

genvar k;

//==============================
//   LOGIC DECLARATION                                                 
//==============================

reg [2:0] current_state, next_state;

wire done;
reg [80:0] not_zero;

reg [8:0] single_mask_to_update_result [0:80];
reg [80:0] single_update_flags;
wire progress_made;

reg [6:0] out_cnt;  // 0 ~ 80

reg [3:0] map [0:80];
reg [3:0] next_map [0:80];

reg [8:0] row  [0:8];   // row[x][i] == 1 ---> in row[x], i is used
reg [8:0] col  [0:8];   // col[x][i] == 1 ---> in col[x], i is used
reg [8:0] grid [0:8];   // grid[x][i] == 1 ---> in grid[x], i is used

reg [8:0] candidate [0:80];
// wire contradiction;
reg contradiction;

// -------------- PROPAGATE / SELECT --------------

// wire single_success;          // flag, map changed?

// -------------- Minimum Remaining Values --------------

reg [3:0] mrv_min_count;          // min count of candidate of all block
reg [6:0] mrv_best_idx;           // the block index who has min count of candidate

// -------------- stack --------------

parameter STACK_DEPTH        = 81;

parameter IDX_WIDTH          = 7;
parameter MASK_WIDTH         = 9;
parameter MAP_SNAPSHOT_WIDTH = 324; // 4 bits/cell * 81 cells

parameter STACK_ENTRY_WIDTH  = IDX_WIDTH + MASK_WIDTH + MAP_SNAPSHOT_WIDTH; // {index, tried_mask, map_snapshot}

reg [STACK_ENTRY_WIDTH - 1 : 0] stack [0:STACK_DEPTH-1], next_stack [0:STACK_DEPTH-1];
reg [6:0] top;   // Stack Pointer, points to the next empty slot

wire [IDX_WIDTH - 1 : 0] stack_top_idx;
wire [MASK_WIDTH - 1 : 0] stack_top_tried_mask;
// wire [MAP_SNAPSHOT_WIDTH - 1 : 0] stack_top_flat_map;

reg [MAP_SNAPSHOT_WIDTH - 1 : 0] flat_map;

wire [3:0] next_top_val;

// -------------------------------------

reg [8:0] single_posiable_row  [0:8];
reg [8:0] single_posiable_col  [0:8];
reg [8:0] single_posiable_grid [0:8];

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

// candidate have only 1 bit == 1
function is_single;
    input [8:0] m;
    is_single = (m != 9'b0) && ((m & (m - 1)) == 9'b0);
endfunction

function [3:0] find_first_val;
    input [8:0] mask;
    begin
        if      (mask[0]) find_first_val = 1;
        else if (mask[1]) find_first_val = 2;
        else if (mask[2]) find_first_val = 3;
        else if (mask[3]) find_first_val = 4;
        else if (mask[4]) find_first_val = 5;
        else if (mask[5]) find_first_val = 6;
        else if (mask[6]) find_first_val = 7;
        else if (mask[7]) find_first_val = 8;
        else if (mask[8]) find_first_val = 9;
        else find_first_val = 0;       // not found
    end
endfunction

function [8:0] single_mask_to_update;
    input [8:0] candidate_ori;
    input [8:0] candidate_row;
    input [8:0] candidate_col;
    input [8:0] candidate_grid;
    begin
        if      (is_single(candidate_ori)) single_mask_to_update = candidate_ori;
        else if (is_single(candidate_row)) single_mask_to_update = candidate_row;
        else if (is_single(candidate_col)) single_mask_to_update = candidate_col;
        else if (is_single(candidate_grid)) single_mask_to_update = candidate_grid;
        else single_mask_to_update = 9'd0;
    end
endfunction

// reg [2:0] current_state
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) current_state <= S_IDLE;
    else current_state <= next_state;
end

// reg [2:0] next_state
always @(*) begin
    next_state = current_state;
    case (current_state)
        S_IDLE: begin
            if (in_valid) next_state = S_INPUT;
            else          next_state = S_IDLE;
        end
        S_INPUT: begin
            if (in_valid) next_state = S_INPUT; 
            else          next_state = S_SINGLE;
        end
        S_SINGLE: begin
            if (done)                next_state = S_OUTPUT;
            else if (progress_made)  next_state = S_SINGLE;      // (naked single) update map, push stack
            else if (contradiction)  next_state = S_BACKTRACK;   // have candidate count is 0 but not done yet (contradiction)
            else                     next_state = S_TRY;         // no changed & not done yet (need trying)
        end
        S_TRY: begin
            next_state = S_SINGLE;
            // if (stack_pointer < STACK_DEPTH) next_state = S_SINGLE;
            // else                             next_state = S_IDLE; // Stack overflow **(should not happen)**
        end
        S_BACKTRACK: begin
            if (top > 0 && next_top_val != 0) next_state = S_TRY;       // current stack[top-1] has other number to try
            else if (top > 0)                 next_state = S_BACKTRACK; // keep backtracking
            else                              next_state = S_IDLE;      // stack empty, no solution **(should not happen)**
        end
        S_OUTPUT: begin
            if (out_cnt == 80) next_state = S_IDLE;
            else               next_state = S_OUTPUT;
        end
    endcase
end

// wire done;
assign done = &(not_zero);

// reg [80:0] not_zero;
always @(*) begin
    integer i;
    for (i = 0; i < 81; i = i + 1) begin
        not_zero[i] = |(map[i]);
    end
end

// reg [8:0] single_mask_to_update_result [0:80];
always @(*) begin
    integer i;
    for(i = 0; i < 81; i = i + 1) begin
        single_mask_to_update_result[i] = single_mask_to_update(
                candidate[i],
                candidate[i] & single_posiable_row[index_to_row(i)],
                candidate[i] & single_posiable_col[index_to_col(i)],
                candidate[i] & single_posiable_grid[index_to_grid(i)]
            );
    end
end

// reg [80:0] single_update_flags;
always @(*) begin
    integer i;
    for(i = 0; i < 81; i = i + 1) begin
        single_update_flags[i] = (map[i] == 4'd0 && single_mask_to_update_result[i] != 9'd0);
    end
end

// wire progress_made;
assign progress_made = |single_update_flags;


// reg contradiction;
always @(*) begin   // map has '0' but no candidate?
    integer i;
    contradiction = 1'b0;
    for (i = 0; i < 81; i = i + 1) begin
        if (map[i] == 4'd0 && candidate[i] == 9'b0) begin
            contradiction = 1'b1;
        end
    end
end

// ---------------------- output ----------------------

// reg [6:0] out_cnt;  // 0 ~ 80
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)                                         out_cnt <= 7'd0;
    else if (current_state == S_OUTPUT && out_cnt < 80) out_cnt <= out_cnt + 1;
    else                                                out_cnt <= 7'd0;
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

// -------------------------------------

wire [3:0] popcounts [0:80];

generate
    for (k = 0; k < 81; k = k + 1) begin : popcount_insts
        POPCOUNT_9bits_LUT u_popcount (.data_in(candidate[k]), .popcount(popcounts[k]));
    end
endgenerate

// reg [3:0] mrv_min_count;          // min count of candidate of all block
// reg [6:0] mrv_best_idx;           // the block index who has min count of candidate
always @(*) begin
    integer i;
    mrv_min_count = 4'd10;
    mrv_best_idx  = 7'd81;
    for (i = 0; i < 81; i = i + 1) begin
        if (popcounts[i] > 0 && popcounts[i] < mrv_min_count && map[i] == 4'd0) begin
             mrv_min_count = popcounts[i];
             mrv_best_idx = i;
        end
    end
end

// parameter STACK_DEPTH        = 81;
// parameter IDX_WIDTH          = 7;
// parameter MASK_WIDTH         = 9;
// parameter MAP_SNAPSHOT_WIDTH = 324; // 4 bits/cell * 81 cells
// parameter STACK_ENTRY_WIDTH  = IDX_WIDTH + MASK_WIDTH + MAP_SNAPSHOT_WIDTH; // {index, tried_mask, map_snapshot}

// wire [IDX_WIDTH - 1 : 0] stack_top_idx;
// wire [MASK_WIDTH - 1 : 0] stack_top_tried_mask;
// wire [MAP_SNAPSHOT_WIDTH - 1 : 0] stack_top_flat_map;
// assign stack_top_idx        = (top > 0) ? stack[top-1][STACK_ENTRY_WIDTH             - 1 -: IDX_WIDTH ] : {(IDX_WIDTH){1'b0}};
assign stack_top_idx        = stack[top][STACK_ENTRY_WIDTH - 1 -: IDX_WIDTH];
assign stack_top_tried_mask = (top > 0) ? stack[top-1][STACK_ENTRY_WIDTH - IDX_WIDTH - 1 -: MASK_WIDTH] : {(MASK_WIDTH){1'b0}};

// wire [3:0] next_top_val;
// assign next_top_val = (top > 0) ? find_first_val(candidate[stack_top_idx] & (~stack_top_tried_mask)) : 4'd0;
assign next_top_val = find_first_val(candidate[stack_top_idx] & (~stack_top_tried_mask));

// reg [6:0]     top;   // Stack Pointer, top == 0 -----> stack empty
always @(posedge clk) begin
    case (current_state)
        S_IDLE:      top <= 7'd0;
        S_SINGLE:    if (!progress_made) top <= top + 1; // push stack
        S_BACKTRACK: top <= (top > 0 && next_top_val == 0) ? top - 1 : top; // keep backtracking
        default:     top <= top;
    endcase
end

// reg [STACK_ENTRY_WIDTH - 1 : 0] stack [0:STACK_DEPTH-1];
always @(posedge clk or negedge rst_n) begin
    integer i;
    if (!rst_n) begin
        for (i = 0; i < STACK_DEPTH; i = i + 1) stack[i] = {(STACK_ENTRY_WIDTH){1'b0}};
    end
    else stack <= next_stack;
end

// reg [STACK_ENTRY_WIDTH - 1 : 0] next_stack [0:STACK_DEPTH-1];
always @(*) begin
    integer i;
    next_stack = stack;
    if (current_state == S_IDLE) begin
        for (i = 0; i < STACK_DEPTH; i = i + 1) next_stack[i] = {(STACK_ENTRY_WIDTH){1'b0}};
    end
    else begin
        case (current_state)
            S_SINGLE: begin
                if (!progress_made) begin
                    next_stack[top][MAP_SNAPSHOT_WIDTH - 1 : 0] = flat_map;
                    next_stack[top][STACK_ENTRY_WIDTH - 1 -: IDX_WIDTH ] = mrv_best_idx;
                end
            end
            S_TRY: begin
                next_stack[top-1][STACK_ENTRY_WIDTH - IDX_WIDTH - 1 -: MASK_WIDTH] = (stack_top_tried_mask | (9'b1 << (next_top_val - 1)));
            end
        endcase
    end
end

// reg [MAP_SNAPSHOT_WIDTH - 1 : 0] flat_map;
always @(*) begin
    integer i;
    for (i = 0; i < 81; i = i + 1) begin
        flat_map[4*i+3 -: 4] = map[i];
    end
end


// reg [3:0] map [0:80];
always @(posedge clk or negedge rst_n) begin
    integer i;
    if (!rst_n) begin
        for (i = 0; i < 81; i = i + 1) map[i] <= 4'b0;
    end
    else if (in_valid) begin
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
        S_IDLE: begin
            for (i = 0; i < 81; i = i + 1) next_map[i] = 4'b0;
        end
        S_SINGLE: begin
            if (progress_made) begin        // keep S_SINGLE
                for (i = 0; i < 81; i = i + 1) begin
                    // if (!not_zero[i]) begin      // no warning
                    if (map[i] == 4'd0) begin       // SDF Warning: Negative delay is ignored and replaced by 0. Please use -negdelay to support it.
                        case (single_mask_to_update_result[i])
                            9'b000000001: next_map[i] = 4'd1;
                            9'b000000010: next_map[i] = 4'd2;
                            9'b000000100: next_map[i] = 4'd3;
                            9'b000001000: next_map[i] = 4'd4;
                            9'b000010000: next_map[i] = 4'd5;
                            9'b000100000: next_map[i] = 4'd6;
                            9'b001000000: next_map[i] = 4'd7;
                            9'b010000000: next_map[i] = 4'd8;
                            9'b100000000: next_map[i] = 4'd9;
                        endcase
                    end
                end
            end
        end
        S_TRY: begin
            next_map[stack_top_idx] = next_top_val;
        end
        S_BACKTRACK: begin
            for (i = 0; i < 81; i = i + 1) begin
                next_map[i] = stack[top-1][4*i+3 -: 4];
            end
        end
    endcase
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

// --------------------------------------------------------------------------------------------------

// /*
// reg [8:0] row  [0:8];   // row[x][i] == 1 ---> in row[x], i is used
always @(*) begin
    integer i, j;
    for (i = 0; i < 9; i = i + 1) begin     // row index
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
    for (i = 0; i < 9; i = i + 1) begin     // grid index
        for (j = 1; j <= 9; j = j + 1) begin     // number
            grid[i][j-1] = (map[i*3 + (i/3)*18]      == j) || (map[i*3 + (i/3)*18 + 1]  == j) || (map[i*3 + (i/3)*18 + 2]  == j) ||
                           (map[i*3 + (i/3)*18 + 9]  == j) || (map[i*3 + (i/3)*18 + 10] == j) || (map[i*3 + (i/3)*18 + 11] == j) ||
                           (map[i*3 + (i/3)*18 + 18] == j) || (map[i*3 + (i/3)*18 + 19] == j) || (map[i*3 + (i/3)*18 + 20] == j);
        end
    end
end
// */

// --------------------------------------------------------------------------------------------------

// reg [8:0] single_posiable_row  [0:8];
// reg [8:0] single_posiable_col  [0:8];
// reg [8:0] single_posiable_grid [0:8];

generate
    for (k = 0; k < 9; k = k + 1) begin : row_unique_bit_detector
        unique_bit_detector9 u_row (.a0(candidate[k*9  ]),
                                    .a1(candidate[k*9+1]),
                                    .a2(candidate[k*9+2]),
                                    .a3(candidate[k*9+3]), 
                                    .a4(candidate[k*9+4]), 
                                    .a5(candidate[k*9+5]), 
                                    .a6(candidate[k*9+6]), 
                                    .a7(candidate[k*9+7]), 
                                    .a8(candidate[k*9+8]), 
                                    .unique_mask(single_posiable_row[k]));
    end
endgenerate

generate
    for (k = 0; k < 9; k = k + 1) begin : col_unique_bit_detector
        unique_bit_detector9 u_col (.a0(candidate[k   ]),
                                    .a1(candidate[k+9 ]),
                                    .a2(candidate[k+18]),
                                    .a3(candidate[k+27]), 
                                    .a4(candidate[k+36]), 
                                    .a5(candidate[k+45]), 
                                    .a6(candidate[k+54]), 
                                    .a7(candidate[k+63]), 
                                    .a8(candidate[k+72]), 
                                    .unique_mask(single_posiable_col[k]));
    end
endgenerate

generate
    for (k = 0; k < 9; k = k + 1) begin : grid_unique_bit_detector
        unique_bit_detector9 u_col (
            .a0(candidate[k*3 + (k/3)*18     ]), .a1(candidate[k*3 + (k/3)*18 + 1 ]), .a2(candidate[k*3 + (k/3)*18 + 2 ]),
            .a3(candidate[k*3 + (k/3)*18 + 9 ]), .a4(candidate[k*3 + (k/3)*18 + 10]), .a5(candidate[k*3 + (k/3)*18 + 11]), 
            .a6(candidate[k*3 + (k/3)*18 + 18]), .a7(candidate[k*3 + (k/3)*18 + 19]), .a8(candidate[k*3 + (k/3)*18 + 20]), 
            .unique_mask(single_posiable_grid[k]));
    end
endgenerate


endmodule

module unique_bit_detector9(
    input  [8:0] a0,
    input  [8:0] a1,
    input  [8:0] a2,
    input  [8:0] a3,
    input  [8:0] a4,
    input  [8:0] a5,
    input  [8:0] a6,
    input  [8:0] a7,
    input  [8:0] a8,

    output [8:0] unique_mask
);

genvar k;
generate
    for (k = 0; k < 9; k = k + 1) begin : BIT_LOOP
        wire [3:0] cnt;
        assign cnt = a0[k] + a1[k] + a2[k] + a3[k] + a4[k] + a5[k] + a6[k] + a7[k] + a8[k];
        assign unique_mask[k] = (cnt == 4'd1);
    end
endgenerate

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
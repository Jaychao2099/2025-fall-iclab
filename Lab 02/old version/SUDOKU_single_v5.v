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

parameter S_IDLE    = 2'd0;
parameter S_INPUT   = 2'd1;
parameter S_SOLVING = 2'd2;
parameter S_OUTPUT  = 2'd3;

//==============================
//   LOGIC DECLARATION                                                 
//==============================

reg [1:0] current_state, next_state;
wire done;
reg [80:0] not_zero;
reg [6:0] out_cnt;  // 0 ~ 81

reg [3:0] map [0:80];

reg [8:0] row  [0:8];   // row[x][i] == 1 ---> in row[x], i is used
reg [8:0] col  [0:8];   // col[x][i] == 1 ---> in col[x], i is used
reg [8:0] grid [0:8];   // grid[x][i] == 1 ---> in grid[x], i is used

reg [8:0] candidate [0:80];

//==============================
//   Design                                                            
//==============================

function [3:0] index_to_row;    // 0 ~ 8
    input [6:0] idx;
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

// reg [1:0] current_state
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) current_state <= S_IDLE;
    else current_state <= next_state;
end

// reg [1:0] next_state
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
            if (done) next_state = S_OUTPUT;
            else      next_state = S_SOLVING;
        end
        S_OUTPUT: begin
            if (out_cnt == 80) next_state = S_IDLE;
            else               next_state = S_OUTPUT;
        end
        default: next_state = current_state;
    endcase
end

// wire done;
assign done = (&(not_zero)) ? 1'b1 : 1'b0;

// reg [80:0] not_zero;
always @(*) begin
    integer i;
    for (i = 0; i < 81; i = i + 1) begin
        not_zero[i] = |(map[i]);
    end
end

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

reg [8:0] single_posiable_row  [0:8];
reg [8:0] single_posiable_col  [0:8];
reg [8:0] single_posiable_grid [0:8];

genvar k;
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
        unique_bit_detector9 u_grid (
            .a0(candidate[k*3 + (k/3)*18     ]), .a1(candidate[k*3 + (k/3)*18 + 1 ]), .a2(candidate[k*3 + (k/3)*18 + 2 ]),
            .a3(candidate[k*3 + (k/3)*18 + 9 ]), .a4(candidate[k*3 + (k/3)*18 + 10]), .a5(candidate[k*3 + (k/3)*18 + 11]), 
            .a6(candidate[k*3 + (k/3)*18 + 18]), .a7(candidate[k*3 + (k/3)*18 + 19]), .a8(candidate[k*3 + (k/3)*18 + 20]), 
            .unique_mask(single_posiable_grid[k]));
    end
endgenerate

function is_single;
    input [8:0] m;
    is_single = (m != 9'b0) && ((m & (m - 1)) == 9'b0);
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

reg [6:0] solve_idx;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        solve_idx <= 7'd0;
    end
    else if (current_state == S_SOLVING) begin
        if (solve_idx == 80) solve_idx <= 7'd0;
        else solve_idx <= solve_idx + 1;
    end
    else solve_idx <= 7'd0;
end

// reg [3:0] map [0:80];
always @(posedge clk or negedge rst_n) begin
    integer i;
    if (!rst_n) for (i = 0; i < 81; i = i + 1) map[i] <= 4'b0;
    else if (in_valid) begin
        map[80] <= in;
        for (i = 1; i < 81; i = i + 1) begin
            map[i - 1] <= map[i];
        end
    end
    else begin
        case (current_state)
            S_IDLE: begin
                for (i = 0; i < 81; i = i + 1) map[i] <= 4'b0;
            end
            S_SOLVING: begin
                // if (!not_zero[i]) begin      // no warning?
                if (map[solve_idx] == 4'd0) begin
                    case (single_mask_to_update(
                            candidate[solve_idx],
                            candidate[solve_idx] & single_posiable_row[index_to_row(solve_idx)],
                            candidate[solve_idx] & single_posiable_col[index_to_col(solve_idx)],
                            candidate[solve_idx] & single_posiable_grid[index_to_grid(solve_idx)]
                            ))
                        9'b000000001: map[solve_idx] <= 4'd1;
                        9'b000000010: map[solve_idx] <= 4'd2;
                        9'b000000100: map[solve_idx] <= 4'd3;
                        9'b000001000: map[solve_idx] <= 4'd4;
                        9'b000010000: map[solve_idx] <= 4'd5;
                        9'b000100000: map[solve_idx] <= 4'd6;
                        9'b001000000: map[solve_idx] <= 4'd7;
                        9'b010000000: map[solve_idx] <= 4'd8;
                        9'b100000000: map[solve_idx] <= 4'd9;
                        default: map[solve_idx] <= map[solve_idx];
                    endcase
                end
                else map[solve_idx] <= map[solve_idx];
            end
            default: map <= map;
        endcase
    end
end

wire [8:0] map_onehot [0:80];
genvar i;
generate
    for (i = 0; i < 81; i = i + 1) begin
        assign map_onehot[i] = (map[i] == 4'd0) ? 9'b0 : (9'b1 << (map[i] - 1));
    end
endgenerate

always @(*) begin
    integer i;
    for (i = 0; i < 9; i = i + 1) begin
        row[i] = map_onehot[i*9  ] | map_onehot[i*9+1] | map_onehot[i*9+2] |
                 map_onehot[i*9+3] | map_onehot[i*9+4] | map_onehot[i*9+5] |
                 map_onehot[i*9+6] | map_onehot[i*9+7] | map_onehot[i*9+8];
    end
end

// reg [8:0] col  [0:8];   // col[x][i] == 1 ---> in col[x], i is used
always @(*) begin
    integer i, j;
    for (i = 0; i < 9; i = i + 1) begin
        col[i] = map_onehot[i]    | map_onehot[i+9]  | map_onehot[i+18] |
                 map_onehot[i+27] | map_onehot[i+36] | map_onehot[i+45] |
                 map_onehot[i+54] | map_onehot[i+63] | map_onehot[i+72];
    end
end

// reg [8:0] grid [0:8];   // grid[x][i] == 1 ---> in grid[x], i is used
always @(*) begin
    integer i, j;
    for (i = 0; i < 9; i = i + 1) begin     // grid index
        grid[i] = map_onehot[i*3 + (i/3)*18]      | map_onehot[i*3 + (i/3)*18 + 1]  | map_onehot[i*3 + (i/3)*18 + 2]  |
                  map_onehot[i*3 + (i/3)*18 + 9]  | map_onehot[i*3 + (i/3)*18 + 10] | map_onehot[i*3 + (i/3)*18 + 11] |
                  map_onehot[i*3 + (i/3)*18 + 18] | map_onehot[i*3 + (i/3)*18 + 19] | map_onehot[i*3 + (i/3)*18 + 20];
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

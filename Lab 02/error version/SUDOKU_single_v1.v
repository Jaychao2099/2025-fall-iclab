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

// reg [3:0] map [0:80];
always @(posedge clk) begin
    integer i;
    if (in_valid) begin
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
                for (i = 0; i < 81; i = i + 1) begin
                    if (!not_zero[i]) begin
                        case (candidate[i])
                            9'b000000001: map[i] <= 4'd1;
                            9'b000000010: map[i] <= 4'd2;
                            9'b000000100: map[i] <= 4'd3;
                            9'b000001000: map[i] <= 4'd4;
                            9'b000010000: map[i] <= 4'd5;
                            9'b000100000: map[i] <= 4'd6;
                            9'b001000000: map[i] <= 4'd7;
                            9'b010000000: map[i] <= 4'd8;
                            9'b100000000: map[i] <= 4'd9;
                            default: map[i] <= map[i];
                        endcase
                    end
                    else map[i] <= map[i];
                end
            end
            default: map <= map;
        endcase
    end
end

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
module HLPTE(
    // input signals
    clk,
    rst_n,
    in_valid_data,
    in_valid_param,
    
    data,
	index,
	mode,
    QP,
	
    // output signals
    out_valid,
    out_value
);

input                     clk;
input                     rst_n;
input                     in_valid_data;
input                     in_valid_param;

input              [7:0]  data;
input              [3:0]  index;
input                     mode;
input              [4:0]  QP;

output reg                out_valid;
output reg signed [31:0]  out_value;

//==================================================================
// parameter & integer
//==================================================================


//==================================================================
// reg & wire
//==================================================================


//==================================================================
// design
//==================================================================

// ----------------- input (memory) -----------------

reg [3:0] mem_frame_num;
reg [4:0] mem_row_num;
reg [4:0] mem_col_num;
reg [7:0] mem_input_data;
reg [7:0] mem_output_data, mem_output_data_reg;
wire mem_web;

MEM_INTERFACE m1 (.frame(mem_frame_num), .row(mem_row_num), .col(mem_col_num), .Dout(mem_output_data), .Din(mem_input_data), .clk(clk), .WEB(mem_web));

reg [13:0] input_cnt;

// reg [13:0] input_cnt;
always @(posedge clk negedge rst_n) begin
    if (!rst_n) input_cnt <= 14'b0;
    else if (in_valid_data) input_cnt <= input_cnt + 14'd1;
    else input_cnt <= 14'd0;
end

// reg [3:0] mem_frame_num;
// reg [4:0] mem_row_num;
// reg [4:0] mem_col_num;
always @(posedge clk) begin
    if (in_valid_data) begin
        mem_frame_num <= input_cnt[13:10];
        mem_row_num <= input_cnt[9:5];
        mem_col_num <= input_cnt[4:0];
    end
    else begin
        mem_frame_num <= 4'd0;
        mem_row_num <= 5'd0;
        mem_col_num <= 5'd0;
    end
end

// wire mem_web;
assign mem_web = ~in_valid_data;

// reg [7:0] mem_input_data;
always @(posedge clk) begin
    if (in_valid_data) mem_input_data <= data;
    else mem_input_data <= 8'd0;
end

// reg [7:0] mem_output_data, mem_output_data_reg;
always @(posedge clk) begin
    if (mem_web) mem_output_data_reg <= mem_output_data;
    else mem_output_data_reg <= 8'd0;
end

// ----------------- input (param) -----------------

reg [3:0] set_cnt;
reg [1:0] param_cnt;
reg [3:0] index_reg;
reg [3:0] mode_reg;
reg [4:0] QP_reg;

// reg [3:0] set_cnt;
always @(posedge clk) begin
    if (in_valid_data) set_cnt <= 4'd0;
    else if (in_valid_param && param_cnt == 2'd0) set_cnt <= set_cnt + 4'd1;
    else set_cnt <= set_cnt;
end

// reg [1:0] param_cnt;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) param_cnt <= 2'b0;
    else if (in_valid_param) param_cnt <= param_cnt + 2'd1;
    else param_cnt <= 2'b0;
end

// reg [3:0]  index_reg;
always @(posedge clk) begin
    if (in_valid_param && param_cnt == 2'd0) index_reg <= index;
    else index_reg <= index_reg;
end

// reg [3:0] mode_reg;
always @(posedge clk) begin
    if (in_valid_param) begin
        QP_reg[3] <= mode;
        QP_reg[2] <= QP_reg[3];
        QP_reg[1] <= QP_reg[2];
        QP_reg[0] <= QP_reg[1];
    end
    else QP_reg <= QP_reg;
end

// reg [4:0]  QP_reg;
always @(posedge clk) begin
    if (in_valid_param && param_cnt == 2'd0) QP_reg <= QP;
    else QP_reg <= QP_reg;
end

// ----------------- FSM -----------------

parameter S_IDLE        = 0;
parameter S_INPUT_DATA  = 1;
parameter S_INPUT_PARAM = 3;
parameter S_PROCESS_MB  = 4;
parameter S_OUTPUT      = 5;

reg [2:0] current_state;
reg [2:0] next_state;

// reg [2:0] current_state;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) current_state <= S_IDLE;
    else        current_state <= next_state;
end

// reg [2:0] next_state;
always @(*) begin
    case (current_state)
        S_IDLE: begin
            if      (in_valid_data)  next_state = S_INPUT_DATA;
            else if (in_valid_param) next_state = S_INPUT_PARAM;
            else                     next_state = S_IDLE;
        end
        S_INPUT_DATA: begin
            if (input_cnt == 14'd16383) next_state = S_IDLE;
            else                        next_state = S_INPUT_DATA;
        end
        S_INPUT_PARAM: begin
            if (param_cnt == 2'd3) next_state = S_PROCESS_MB;
            else                   next_state = S_INPUT_PARAM;
        end
        S_PROCESS_MB: begin
            if (set_cnt == 15 && quant_done) next_state = S_OUTPUT;       // all 16 sets are done
            else                             next_state = S_PROCESS_MB;
        end
        S_OUTPUT: begin     // for last set's output
            if (output_done) next_state = S_IDLE;
            else             next_state = S_OUTPUT;
        end
        default: next_state = current_state;
    endcase
end

// ----------------- referance -----------------





// ----------------- predict -----------------

reg [7:0] in_data    [0:15],   // 0~255
reg [7:0] prediction [0:15],   // 0~255
reg signed [8:0] residual [0:15],   // input - prediction, -255~255
reg [11:0] out_sad       // sum of ABS(input - prediction)





SAD s1 (.in_data(in_data), .prediction(prediction), .clk(clk), .residual(residual), .out_sad(out_sad));


// ----------------- int transform -----------------

function signed [31:0] expend_to_32;
    input x;
    
endfunction




// ----------------- output -----------------

// output reg signed [31:0] out_value;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) out_value <= 32'b0;
    else out_value <= 32'b0;
end

// output reg out_valid;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) out_valid <= 1'b0;
    else out_valid <= 1'b0;
end



endmodule


module SAD (
    input [7:0] in_data    [0:15],   // 0~255
    input [7:0] prediction [0:15],   // 0~255

    output signed [8:0] residual [0:15],   // input - prediction, -255~255
    output [11:0] out_sad       // sum of ABS(input - prediction)
);

genvar i;
wire [11:0] residual_abs [0:15];

// output signed [8:0] residual [0:15],   // input - prediction, -255~255
generate
    for (i = 0. i < 16; i = i + 1) begin
        assign residual[i] = {1'b0, in_data[i]} - {1'b0, prediction[i]};
    end
endgenerate

// wire [11:0] residual_abs [0:15];     // 0~255, 12-bit align to out_sad
MATRIX_ABS #(9, 12) a1 (.a(residual), .result(residual_abs));

// output [11:0] out_sad        // sum of ABS(input - prediction)
assign out_sad = residual_abs[0]  + residual_abs[1]  + residual_abs[2]  + residual_abs[3]  + 
                 residual_abs[4]  + residual_abs[5]  + residual_abs[6]  + residual_abs[7]  + 
                 residual_abs[8]  + residual_abs[9]  + residual_abs[10] + residual_abs[11] + 
                 residual_abs[12] + residual_abs[13] + residual_abs[14] + residual_abs[15];

endmodule


// Cf * A * Cf
module INT_TRANSFORM (
    input signed [31:0] A [0:15],        // 21-bit
    input inverse,
    input [4:0] QP,
    input [3:0] cnt,
    output reg signed [31:0] result   // 25-bit or 26-bit ?
);

reg [2:0] shift_bits;     // 2~6

// reg [2:0] shift_bits;     // 2~6
always @(*) begin
    case (QP)
        0, 1, 2, 3, 4, 5      : shift_bits = (3'd6 & {3{inverse}});
        6, 7, 8, 9, 10, 11    : shift_bits = (3'd5 & {3{inverse}});
        12, 13, 14, 15, 16, 17: shift_bits = (3'd4 & {3{inverse}});
        18, 19, 20, 21, 22, 23: shift_bits = (3'd3 & {3{inverse}});
        default               : shift_bits = (3'd2 & {3{inverse}});
    endcase
end

// output reg signed [31:0] result   // 25-bit or 26-bit ?
always @(*) begin
    case (cnt)
        0:  result = (A[0] + A[1] + A[2] + A[3] + A[4] + A[5] + A[6] + A[7] + A[8] + A[9] + A[10] + A[11] + A[12] + A[13] + A[14] + A[15]) >>> shift_bits;
        1:  result = (A[0] + A[1] - A[2] - A[3] + A[4] + A[5] - A[6] - A[7] + A[8] + A[9] - A[10] - A[11] + A[12] + A[13] - A[14] - A[15]) >>> shift_bits;
        2:  result = (A[0] - A[1] - A[2] + A[3] + A[4] - A[5] - A[6] + A[7] + A[8] - A[9] - A[10] + A[11] + A[12] - A[13] - A[14] + A[15]) >>> shift_bits;
        3:  result = (A[0] - A[1] - A[2] + A[3] + A[4] - A[5] - A[6] + A[7] + A[8] - A[9] - A[10] + A[11] + A[12] - A[13] - A[14] + A[15]) >>> shift_bits;
        4:  result = (A[0] + A[1] + A[2] + A[3] + A[4] + A[5] + A[6] + A[7] - A[8] - A[9] - A[10] - A[11] - A[12] - A[13] - A[14] - A[15]) >>> shift_bits;
        5:  result = (A[0] + A[1] - A[2] - A[3] + A[4] + A[5] - A[6] - A[7] - A[8] - A[9] + A[10] + A[11] - A[12] - A[13] + A[14] + A[15]) >>> shift_bits;
        6:  result = (A[0] - A[1] - A[2] + A[3] + A[4] - A[5] - A[6] + A[7] - A[8] + A[9] + A[10] - A[11] - A[12] + A[13] + A[14] - A[15]) >>> shift_bits;
        7:  result = (A[0] - A[1] + A[2] - A[3] + A[4] - A[5] + A[6] - A[7] - A[8] + A[9] - A[10] + A[11] - A[12] + A[13] - A[14] + A[15]) >>> shift_bits;
        8:  result = (A[0] + A[1] + A[2] + A[3] - A[4] - A[5] - A[6] - A[7] - A[8] - A[9] - A[10] - A[11] + A[12] + A[13] + A[14] + A[15]) >>> shift_bits;
        9:  result = (A[0] + A[1] - A[2] - A[3] - A[4] - A[5] + A[6] + A[7] - A[8] - A[9] + A[10] + A[11] + A[12] + A[13] - A[14] - A[15]) >>> shift_bits;
        10: result = (A[0] - A[1] - A[2] + A[3] - A[4] + A[5] + A[6] - A[7] - A[8] + A[9] + A[10] - A[11] + A[12] - A[13] - A[14] + A[15]) >>> shift_bits;
        11: result = (A[0] - A[1] + A[2] - A[3] - A[4] + A[5] - A[6] + A[7] - A[8] + A[9] - A[10] + A[11] + A[12] - A[13] + A[14] - A[15]) >>> shift_bits;
        12: result = (A[0] + A[1] + A[2] + A[3] - A[4] - A[5] - A[6] - A[7] + A[8] + A[9] + A[10] + A[11] - A[12] - A[13] - A[14] - A[15]) >>> shift_bits;
        13: result = (A[0] + A[1] - A[2] - A[3] - A[4] - A[5] + A[6] + A[7] + A[8] + A[9] - A[10] - A[11] - A[12] - A[13] + A[14] + A[15]) >>> shift_bits;
        14: result = (A[0] - A[1] - A[2] + A[3] - A[4] + A[5] + A[6] - A[7] + A[8] - A[9] - A[10] + A[11] - A[12] + A[13] + A[14] - A[15]) >>> shift_bits;
        15: result = (A[0] - A[1] + A[2] - A[3] - A[4] + A[5] - A[6] + A[7] + A[8] - A[9] + A[10] - A[11] - A[12] + A[13] - A[14] + A[15]) >>> shift_bits;
        default: result = 32'd0;
    endcase
end

// // output signed [31:0] result [0:15]   // 25-bit or 26-bit ?
// assign result[0] = (A[0] + A[1] + A[2] + A[3] + A[4] + A[5] + A[6] + A[7] + A[8] + A[9] + A[10] + A[11] + A[12] + A[13] + A[14] + A[15]) >>> shift_bits;
// assign result[1] = (A[0] + A[1] - A[2] - A[3] + A[4] + A[5] - A[6] - A[7] + A[8] + A[9] - A[10] - A[11] + A[12] + A[13] - A[14] - A[15]) >>> shift_bits;
// assign result[2] = (A[0] - A[1] - A[2] + A[3] + A[4] - A[5] - A[6] + A[7] + A[8] - A[9] - A[10] + A[11] + A[12] - A[13] - A[14] + A[15]) >>> shift_bits;
// assign result[3] = (A[0] - A[1] - A[2] + A[3] + A[4] - A[5] - A[6] + A[7] + A[8] - A[9] - A[10] + A[11] + A[12] - A[13] - A[14] + A[15]) >>> shift_bits;
// assign result[4] = (A[0] + A[1] + A[2] + A[3] + A[4] + A[5] + A[6] + A[7] - A[8] - A[9] - A[10] - A[11] - A[12] - A[13] - A[14] - A[15]) >>> shift_bits;
// assign result[5] = (A[0] + A[1] - A[2] - A[3] + A[4] + A[5] - A[6] - A[7] - A[8] - A[9] + A[10] + A[11] - A[12] - A[13] + A[14] + A[15]) >>> shift_bits;
// assign result[6] = (A[0] - A[1] - A[2] + A[3] + A[4] - A[5] - A[6] + A[7] - A[8] + A[9] + A[10] - A[11] - A[12] + A[13] + A[14] - A[15]) >>> shift_bits;
// assign result[7] = (A[0] - A[1] + A[2] - A[3] + A[4] - A[5] + A[6] - A[7] - A[8] + A[9] - A[10] + A[11] - A[12] + A[13] - A[14] + A[15]) >>> shift_bits;
// assign result[8] = (A[0] + A[1] + A[2] + A[3] - A[4] - A[5] - A[6] - A[7] - A[8] - A[9] - A[10] - A[11] + A[12] + A[13] + A[14] + A[15]) >>> shift_bits;
// assign result[9] = (A[0] + A[1] - A[2] - A[3] - A[4] - A[5] + A[6] + A[7] - A[8] - A[9] + A[10] + A[11] + A[12] + A[13] - A[14] - A[15]) >>> shift_bits;
// assign result[10] = (A[0] - A[1] - A[2] + A[3] - A[4] + A[5] + A[6] - A[7] - A[8] + A[9] + A[10] - A[11] + A[12] - A[13] - A[14] + A[15]) >>> shift_bits;
// assign result[11] = (A[0] - A[1] + A[2] - A[3] - A[4] + A[5] - A[6] + A[7] - A[8] + A[9] - A[10] + A[11] + A[12] - A[13] + A[14] - A[15]) >>> shift_bits;
// assign result[12] = (A[0] + A[1] + A[2] + A[3] - A[4] - A[5] - A[6] - A[7] + A[8] + A[9] + A[10] + A[11] - A[12] - A[13] - A[14] - A[15]) >>> shift_bits;
// assign result[13] = (A[0] + A[1] - A[2] - A[3] - A[4] - A[5] + A[6] + A[7] + A[8] + A[9] - A[10] - A[11] - A[12] - A[13] + A[14] + A[15]) >>> shift_bits;
// assign result[14] = (A[0] - A[1] - A[2] + A[3] - A[4] + A[5] + A[6] - A[7] + A[8] - A[9] - A[10] + A[11] - A[12] + A[13] + A[14] - A[15]) >>> shift_bits;
// assign result[15] = (A[0] - A[1] + A[2] - A[3] - A[4] + A[5] - A[6] + A[7] + A[8] - A[9] + A[10] - A[11] - A[12] + A[13] - A[14] + A[15]) >>> shift_bits;


endmodule



module QUANTIZATION (
    input signed [31:0] in [0:15],
    input [4:0] QP,
    input de_q,     // De-Quantization
    input [3:0] cnt,
    output signed [31:0] out
);

genvar i;

wire signed [31:0] in_abs [0:15];
reg signed [31:0] mf_a, mf_b, mf_c;
wire signed [31:0] MF;       // ==> De-Quantization's V
wire signed [31:0] dot_in;
wire signed [31:0] q_tmp;
reg signed [31:0] f;
reg signed [4:0] qbits;
reg signed [31:0] z_abs;

// wire signed [31:0] in_abs [0:15];
MATRIX_ABS #(32, 32) abs_1 (.a(in[cnt]), .result(in_abs));

// wire signed [31:0] MF [0:15];


// reg signed [31:0] mf_a
always @(*) begin
    case (QP)
        0, 6,  12, 18, 24: mf_a = de_q ? 31'd10 : 31'd13107;
        1, 7,  13, 19, 25: mf_a = de_q ? 31'd11 : 31'd11916;
        2, 8,  14, 20, 26: mf_a = de_q ? 31'd13 : 31'd10082;
        3, 9,  15, 21, 27: mf_a = de_q ? 31'd14 : 31'd9362;
        4, 10, 16, 22, 28: mf_a = de_q ? 31'd16 : 31'd8192;
        default          : mf_a = de_q ? 31'd18 : 31'd7282;
    endcase
end

// reg signed [31:0] mf_b
always @(*) begin
    case (QP)
        0, 6,  12, 18, 24: mf_b = de_q ? 31'd16 : 31'd5243;
        1, 7,  13, 19, 25: mf_b = de_q ? 31'd18 : 31'd4660;
        2, 8,  14, 20, 26: mf_b = de_q ? 31'd20 : 31'd4194;
        3, 9,  15, 21, 27: mf_b = de_q ? 31'd23 : 31'd3647;
        4, 10, 16, 22, 28: mf_b = de_q ? 31'd25 : 31'd3355;
        default          : mf_b = de_q ? 31'd29 : 31'd2893;
    endcase
end

// reg signed [31:0] mf_c;
always @(*) begin
    case (QP)
        0, 6,  12, 18, 24: mf_c = de_q ? 31'd13 : 31'd8066;
        1, 7,  13, 19, 25: mf_c = de_q ? 31'd14 : 31'd7490;
        2, 8,  14, 20, 26: mf_c = de_q ? 31'd16 : 31'd6554;
        3, 9,  15, 21, 27: mf_c = de_q ? 31'd18 : 31'd5825;
        4, 10, 16, 22, 28: mf_c = de_q ? 31'd20 : 31'd5243;
        default          : mf_c = de_q ? 31'd23 : 31'd4559;
    endcase
end

always @(*) begin
    case (cnt)
        0, 2, 8, 10:               MF = mf_a;
        5, 7, 13, 15:              MF = mf_b;
        // 1, 3, 4, 6, 9, 11, 12, 14: MF = mf_c;
        default: MF = mf_c;
        // default:                   MF = 31'd0;
    endcase
end

// wire signed [31:0] dot_in [0:15];
assign dot_in = de_q ? in[cnt] : in_abs;

// wire signed [31:0] q_tmp [0:15];
assign q_tmp = dot_in * MF;

// reg signed [31:0] f;
always @(*) begin
    case (QP)
        0, 1, 2, 3, 4, 5      : f = 32'd10922;
        6, 7, 8, 9, 10, 11    : f = 32'd21845;
        12, 13, 14, 15, 16, 17: f = 32'd43690;
        18, 19, 20, 21, 22, 23: f = 32'd87381;
        default               : f = 32'd174762;
    endcase
end

// reg signed [4:0] qbits;
always @(*) begin
    case (QP)
        0, 1, 2, 3, 4, 5      : qbits = 5'd15;
        6, 7, 8, 9, 10, 11    : qbits = 5'd16;
        12, 13, 14, 15, 16, 17: qbits = 5'd17;
        18, 19, 20, 21, 22, 23: qbits = 5'd18;
        default               : qbits = 5'd19;
    endcase
end

assign z_abs = (q_tmp + f) >> qbits;

assign out = de_q ? q_tmp : ((z_abs ^ {32{in[cnt][12]}}) + {31'd0, in[cnt][12]});

// generate
//     for (i = 0; i < 16; i = i + 1) assign z_abs[i] = (q_tmp[i] + f) >> qbits;   // >>> ?
// endgenerate

// // add sign bit
// generate
//     for (i = 0; i < 16; i = i + 1) assign out[i] = de_q ? q_tmp[i] : (z_abs[i] ^ {32{in[i][12]}}) + {31'd0, in[i][12]};
// endgenerate


endmodule


// ABS(x) = (x ^ sign) - sign;
module MATRIX_ABS #(
    a_bit_num, 
    result_bit_num
) (
    input signed [bit_num-1:0] a,
    output signed [result_bit_num-1:0] result
);

wire [result_bit_num-1:0] a_extend;
wire [result_bit_num-1:0] sign;

assign sign = {result_bit_num{a[bit_num-1]}};
assign a_extend = {{(result_bit_num - bit_num){a[bit_num-1]}}, a};
assign result = (a_extend ^ sign) - sign;

endmodule

module MEM_INTERFACE (
    input [3:0] frame,
    input [4:0] row,
    input [4:0] col,
    output [7:0] Dout,
    input [7:0] Din,
    input clk,
    input WEB
);

// wire [13:0] address;
// assign address = {frame, row, col};

SRAM_16384 sram_1 (.A0(col[0]), .A1(col[1]), .A2(col[2]), .A3(col[3]), .A4(col[4]), 
                   .A5(row[0]), .A6(row[1]), .A7(row[2]), .A8(row[3]), .A9(row[4]), 
                   .A10(frame[0]), .A11(frame[1]), .A12(frame[2]), .A13(frame[3]),
                   .DO0(Dout[0]),.DO1(Dout[1]),.DO2(Dout[2]),.DO3(Dout[3]),.DO4(Dout[4]),.DO5(Dout[5]),.DO6(Dout[6]),.DO7(Dout[7]),
                   .DI0(Din[0]),.DI1(Din[1]),.DI2(Din[2]),.DI3(Din[3]),.DI4(Din[4]),.DI5(Din[5]),.DI6(Din[6]),.DI7(Din[7]),
                   .CK(clk),.WEB(WEB),.OE(1'b1),.CS(1'b1));

endmodule

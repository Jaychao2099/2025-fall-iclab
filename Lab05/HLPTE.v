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

wire [13:0] address;

assign address = {frame, row, col};

SRAM_16384 s1 (.A0(address[0]),  .A1(address[1]),  .A2(address[2]), .A3(address[3]), .A4(address[4]), 
               .A5(address[5]),  .A6(address[6]),  .A7(address[7]), .A8(address[8]), .A9(address[9]), 
               .A10(address[10]), .A11(address[11]), .A12(address[12]), .A13(address[13]),
               .DO0(Dout[0]),.DO1(Dout[1]),.DO2(Dout[2]),.DO3(Dout[3]),.DO4(Dout[4]),.DO5(Dout[5]),.DO6(Dout[6]),.DO7(Dout[7]),
               .DI0(Din[0]),.DI1(Din[1]),.DI2(Din[2]),.DI3(Din[3]),.DI4(Din[4]),.DI5(Din[5]),.DI6(Din[6]),.DI7(Din[7]),
               .CK(clk),.WEB(WEB),.OE(1'b1),.CS(1'b1));

endmodule


// Cf * A * Cf
module INT_TRANSFORM (
    input signed [31:0] A [0:15],        // 21-bit
    input inverse,
    input [4:0] QP,
    output signed [31:0] result [0:15]   // 25-bit or 26-bit ?
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

// output signed [31:0] result [0:15]   // 25-bit or 26-bit ?
assign result[0] = (A[0] + A[1] + A[2] + A[3] + A[4] + A[5] + A[6] + A[7] + A[8] + A[9] + A[10] + A[11] + A[12] + A[13] + A[14] + A[15]) >> shift_bits;
assign result[1] = (A[0] + A[1] - A[2] - A[3] + A[4] + A[5] - A[6] - A[7] + A[8] + A[9] - A[10] - A[11] + A[12] + A[13] - A[14] - A[15]) >> shift_bits;
assign result[2] = (A[0] - A[1] - A[2] + A[3] + A[4] - A[5] - A[6] + A[7] + A[8] - A[9] - A[10] + A[11] + A[12] - A[13] - A[14] + A[15]) >> shift_bits;
assign result[3] = (A[0] - A[1] + A[2] - A[3] + A[4] - A[5] + A[6] - A[7] + A[8] - A[9] + A[10] - A[11] + A[12] - A[13] + A[14] - A[15]) >> shift_bits;

assign result[4] = (A[0] + A[1] + A[2] + A[3] + A[4] + A[5] + A[6] + A[7] - A[8] - A[9] - A[10] - A[11] - A[12] - A[13] - A[14] - A[15]) >> shift_bits;
assign result[5] = (A[0] + A[1] - A[2] - A[3] + A[4] + A[5] - A[6] - A[7] - A[8] - A[9] + A[10] + A[11] - A[12] - A[13] + A[14] + A[15]) >> shift_bits;
assign result[6] = (A[0] - A[1] - A[2] + A[3] + A[4] - A[5] - A[6] + A[7] - A[8] + A[9] + A[10] - A[11] - A[12] + A[13] + A[14] - A[15]) >> shift_bits;
assign result[7] = (A[0] - A[1] + A[2] - A[3] + A[4] - A[5] + A[6] - A[7] - A[8] + A[9] - A[10] + A[11] - A[12] + A[13] - A[14] + A[15]) >> shift_bits;

assign result[8] = (A[0] + A[1] + A[2] + A[3] - A[4] - A[5] - A[6] - A[7] - A[8] - A[9] - A[10] - A[11] + A[12] + A[13] + A[14] + A[15]) >> shift_bits;
assign result[9] = (A[0] + A[1] - A[2] - A[3] - A[4] - A[5] + A[6] + A[7] - A[8] - A[9] + A[10] + A[11] + A[12] + A[13] - A[14] - A[15]) >> shift_bits;
assign result[10] = (A[0] - A[1] - A[2] + A[3] - A[4] + A[5] + A[6] - A[7] - A[8] + A[9] + A[10] - A[11] + A[12] - A[13] - A[14] + A[15]) >> shift_bits;
assign result[11] = (A[0] - A[1] + A[2] - A[3] - A[4] + A[5] - A[6] + A[7] - A[8] + A[9] - A[10] + A[11] + A[12] - A[13] + A[14] - A[15]) >> shift_bits;

assign result[12] = (A[0] + A[1] + A[2] + A[3] - A[4] - A[5] - A[6] - A[7] + A[8] + A[9] + A[10] + A[11] - A[12] - A[13] - A[14] - A[15]) >> shift_bits;
assign result[13] = (A[0] + A[1] - A[2] - A[3] - A[4] - A[5] + A[6] + A[7] + A[8] + A[9] - A[10] - A[11] - A[12] - A[13] + A[14] + A[15]) >> shift_bits;
assign result[14] = (A[0] - A[1] - A[2] + A[3] - A[4] + A[5] + A[6] - A[7] + A[8] - A[9] - A[10] + A[11] - A[12] + A[13] + A[14] - A[15]) >> shift_bits;
assign result[15] = (A[0] - A[1] + A[2] - A[3] - A[4] + A[5] - A[6] + A[7] + A[8] - A[9] + A[10] - A[11] - A[12] + A[13] - A[14] + A[15]) >> shift_bits;


endmodule



module QUANTIZATION (
    input signed [31:0] in [0:15],
    input [4:0] QP,
    input de_q,
    output signed [31:0] out [0:15]
);

genvar i;

wire signed [31:0] in_abs [0:15];
reg signed [31:0] mf_a, mf_b, mf_c;
wire signed [31:0] MF [0:15];       // ==> De-Quantization's V
wire signed [31:0] dot_in [0:15];
wire signed [31:0] q_tmp [0:15];
reg signed [31:0] f;
reg signed [4:0] qbits;
reg signed [31:0] z_abs;

// wire signed [31:0] in_abs [0:15];
MATRIX_ABS #(32) abs_1 (.a(in), .result(in_abs));

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

assign MF[0] = mf_a;
assign MF[1] = mf_c;
assign MF[2] = mf_a;
assign MF[3] = mf_c;
assign MF[4] = mf_c;
assign MF[5] = mf_b;
assign MF[6] = mf_c;
assign MF[7] = mf_b;
assign MF[8] = mf_a;
assign MF[9] = mf_c;
assign MF[10] = mf_a;
assign MF[11] = mf_c;
assign MF[12] = mf_c;
assign MF[13] = mf_b;
assign MF[14] = mf_c;
assign MF[15] = mf_b;

// wire signed [31:0] dot_in [0:15];
assign dot_in = de_q ? in : in_abs;

// wire signed [31:0] q_tmp [0:15];
DOT d_1 (.a(dot_in), .b(MF), .result(q_tmp));

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

generate
    for (i = 0; i < 16; i = i + 1) assign z_abs[i] = (q_tmp[i] + f) >> qbits;   // >>> ?
endgenerate

// add sign bit
generate
    for (i = 0; i < 16; i = i + 1) assign out[i] = de_q ? q_tmp[i] : (z_abs[i] ^ {32{w[i][12]}}) + {31'd0, w[i][12]};
endgenerate


endmodule




module DOT (
    input signed [31:0] a [0:15],
    input signed [31:0] b [0:15],
    output signed [31:0] result [0:15]
);
genvar i;
generate
    for (i = 0; i < 16; i = i + 1) assign result[i] = a[i] * b[i];
endgenerate

endmodule




// ABS(x) = (x ^ sign) - sign;
module MATRIX_ABS #(
    bit_num
) (
    input signed [bit_num-1:0] a [0:15],
    output signed [31:0] result [0:15]
);

wire [31:0] a_32 [0:15];
wire [31:0] sign [0:15];

genvar i;
generate
    for (i = 0; i < 16; i = i + 1) begin
        assign sign[i] = {32{a[i][bit_num-1]}};
        assign a_32[i] = {(32 - bit_num){a[i][bit_num-1]}, a[i]};
        assign result[i] = (a_32[i] ^ sign[i]) - sign[i];
    end
endgenerate

endmodule
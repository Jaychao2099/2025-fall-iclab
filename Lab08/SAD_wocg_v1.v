//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   (C) Copyright Laboratory System Integration and Silicon Implementation
//   All Right Reserved
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   2025 ICLAB FALL Course
//   Lab08       : SAD
//   Author      : Ying-Yu (Inyi) Wang
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   File Name   : SAD_wocg.v
//   Module Name : SAD
//   Release version : v1.0
//   Note : Design w/o CG
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

module SAD(
    //Input signals
    clk,
    rst_n,
    in_valid,
	in_data1,
    T,
    in_data2,
    w_Q,
    w_K,
    w_V,

    //Output signals
    out_valid,
    out_data
    );

input clk;
input rst_n;
input in_valid;
input signed [5:0] in_data1;
input [3:0] T;
input signed [7:0] in_data2;
input signed [7:0] w_Q;
input signed [7:0] w_K;
input signed [7:0] w_V;

output reg out_valid;
output reg signed [91:0] out_data;

//==============================================//
//       parameter & integer declaration        //
//==============================================//
parameter d_model = 'd8;


genvar k;

//==============================================//
//           reg & wire declaration             //
//==============================================//

reg [8:0] cnt_clk, next_cnt_clk;  // 0 ~ 314 (9 bits)

// ----------------- input buffer -----------------
wire in_data1_valid, in_data2_valid, Q_valid, K_valid, V_valid;

reg signed [5:0] in_data1_reg [0:15];
reg [3:0] T_reg;
reg signed [7:0] in_data2_reg [0:63];
reg signed [7:0] w_Q_reg [0:63];
reg signed [7:0] w_K_reg [0:63];
reg signed [7:0] w_V_reg [0:63];

// ----------------- det -----------------
reg [3:0] det_cnt;    // 0 ~ 11
wire is_det;
reg  is_det_d1, is_det_d2;
reg signed [24:0] det_result;


// ----------------- mult -----------------
reg signed [7:0]  mult_s_a [0:7];
reg signed [7:0]  mult_s_b [0:7];
reg signed [15:0] mult_s_z [0:7];

reg signed [15:0] mult_b_a [0:7];
reg signed [27:0] mult_b_b [0:7];
reg signed [41:0] mult_b_z [0:7];

reg signed [24:0] mult_f_a;
reg signed [41:0] mult_f_b;
reg signed [91:0] mult_f_z;

//==============================================//
//                  design                      //
//==============================================//

// reg [8:0] cnt_clk;  // 0 ~ 314 (9 bits)
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) cnt_clk <= 7'b0;
	else cnt_clk <= next_cnt_clk;
end

// reg [8:0] next_cnt_clk;  // 0 ~ 314 (9 bits)
always @(*) begin
    next_cnt_clk = cnt_clk;
    if      (cnt_clk == 9'd314) next_cnt_clk = 9'b0;
    else if (cnt_clk > 9'b0 || in_valid) next_cnt_clk = cnt_clk + 9'd1;
end

// ----------------- input -----------------

// wire in_data1_valid, in_data2_valid;
assign in_data1_valid = in_valid && cnt_clk < 9'd16;
assign in_data2_valid = in_valid && cnt_clk < ({3'd0, T_reg} << 3);
assign Q_valid = in_valid &&                     cnt_clk < 9'd64;
assign K_valid = in_valid && cnt_clk > 9'd63  && cnt_clk < 9'd128;
assign V_valid = in_valid && cnt_clk > 9'd127 && cnt_clk < 9'd192;

// reg [3:0] T_reg;
always @(posedge clk or negedge rst_n) begin
    if      (!rst_n)                      T_reg <= 4'd0;
    else if (in_valid && cnt_clk == 9'd0) T_reg <= T;
end

// reg signed [5:0] in_data1_reg [0:15];
always @(posedge clk or negedge rst_n) begin
    integer i;
    if (!rst_n) for (i = 0; i < 16; i  = i + 1) in_data1_reg[i] <= 6'd0;
    // ----------------- input -----------------
    else if (in_data1_valid) in_data1_reg[cnt_clk] <= in_data1;
    // -------------- determinent --------------
    else if (is_det) begin
        in_data1_reg[0] <= in_data1_reg[1];
        in_data1_reg[1] <= in_data1_reg[2];
        in_data1_reg[2] <= in_data1_reg[3];
        in_data1_reg[3] <= in_data1_reg[0];

        in_data1_reg[4] <= in_data1_reg[5];
        in_data1_reg[5] <= in_data1_reg[6];
        in_data1_reg[6] <= in_data1_reg[7];
        in_data1_reg[7] <= in_data1_reg[4];
        
        in_data1_reg[8] <= in_data1_reg[9];
        in_data1_reg[9] <= in_data1_reg[10];
        in_data1_reg[10] <= in_data1_reg[11];
        in_data1_reg[11] <= in_data1_reg[8];

        in_data1_reg[12] <= in_data1_reg[13];
        in_data1_reg[13] <= in_data1_reg[14];
        in_data1_reg[14] <= in_data1_reg[15];
        in_data1_reg[15] <= in_data1_reg[12];
    end
end

// reg signed [7:0] in_data2_reg [0:63];
always @(posedge clk or negedge rst_n) begin
    integer i;
    if      (!rst_n)            for (i = 0; i < 64; i  = i + 1) in_data2_reg[i] <= 8'd0;
    else if (in_data2_valid)    in_data2_reg[cnt_clk] <= in_data2;
    else if (cnt_clk == 9'd314) for (i = 8; i < 64; i  = i + 1) in_data2_reg[i] <= 8'd0;
end

// reg signed [7:0] w_Q_reg [0:63];
always @(posedge clk or negedge rst_n) begin
    integer i;
    if      (!rst_n)  for (i = 0; i < 64; i = i + 1) w_Q_reg[i] <= 8'd0;
    else if (Q_valid) w_Q_reg[cnt_clk[5:0]] <= w_Q;
end
// reg signed [7:0] w_K_reg [0:63];
always @(posedge clk or negedge rst_n) begin
    integer i;
    if      (!rst_n)  for (i = 0; i < 64; i = i + 1) w_K_reg[i] <= 8'd0;
    else if (K_valid) w_K_reg[cnt_clk[5:0]] <= w_K;
end
// reg signed [7:0] w_V_reg [0:63];
always @(posedge clk or negedge rst_n) begin
    integer i;
    if      (!rst_n)  for (i = 0; i < 64; i = i + 1) w_V_reg[i] <= 8'd0;
    else if (V_valid) w_V_reg[cnt_clk[5:0]] <= w_V;
end

// -------------- determinent --------------

// reg [3:0] det_cnt;    // 0 ~ 11
always @(posedge clk or negedge rst_n) begin
    if      (!rst_n) det_cnt <= 4'd0;
    else if (is_det) det_cnt <= det_cnt + 4'd1;
    else             det_cnt <= 4'd0;
end

// wire is_det;
assign is_det = (cnt_clk >= 9'd16 && cnt_clk <= 9'd27);

// reg is_det_d1, is_det_d2;
always @(posedge clk or negedge rst_n) begin
    is_det_d1 <= (!rst_n) ? 1'b0 : is_det;
    is_det_d2 <= (!rst_n) ? 1'b0 : is_det_d1;
end

// reg signed [7:0] mult_s_a[0~3], mult_s_b[0~3]
always @(posedge clk or negedge rst_n) begin
    integer i;
    if (!rst_n) begin
        for (i = 0; i < 4; i = i + 1) begin
            mult_s_a[i] <= 8'd0;
            mult_s_b[i] <= 8'd0;
        end
    end
    else if (is_det) begin
        case (det_cnt[1:0])
            2'd0: begin
                // +
                mult_s_a[0] <= {2'd0, in_data1_reg[0]};
                mult_s_b[0] <= {2'd0, in_data1_reg[5]};
                mult_s_a[1] <= {2'd0, in_data1_reg[10]};
                mult_s_b[1] <= {2'd0, in_data1_reg[15]};
                // -
                mult_s_a[2] <= {2'd0, in_data1_reg[0]};
                mult_s_b[2] <= {2'd0, in_data1_reg[7]};
                mult_s_a[3] <= {2'd0, in_data1_reg[10]};
                mult_s_b[3] <= {2'd0, in_data1_reg[13]};
            end
            2'd1: begin
                // -
                mult_s_a[0] <= {2'd0, in_data1_reg[0]};
                mult_s_b[0] <= {2'd0, in_data1_reg[6]};
                mult_s_a[1] <= {2'd0, in_data1_reg[11]};
                mult_s_b[1] <= {2'd0, in_data1_reg[13]};
                // +
                mult_s_a[2] <= {2'd0, in_data1_reg[0]};
                mult_s_b[2] <= {2'd0, in_data1_reg[5]};
                mult_s_a[3] <= {2'd0, in_data1_reg[11]};
                mult_s_b[3] <= {2'd0, in_data1_reg[14]};
            end
            2'd2: begin
                // +
                mult_s_a[0] <= {2'd0, in_data1_reg[0]};
                mult_s_b[0] <= {2'd0, in_data1_reg[7]};
                mult_s_a[1] <= {2'd0, in_data1_reg[9]};
                mult_s_b[1] <= {2'd0, in_data1_reg[14]};
                // -
                mult_s_a[2] <= {2'd0, in_data1_reg[0]};
                mult_s_b[2] <= {2'd0, in_data1_reg[6]};
                mult_s_a[3] <= {2'd0, in_data1_reg[9]};
                mult_s_b[3] <= {2'd0, in_data1_reg[15]};
            end
            default: begin
                // -
                mult_s_a[0] <= {2'd0, in_data1_reg[0]};
                mult_s_b[0] <= {2'd0, in_data1_reg[5]};
                mult_s_a[1] <= {2'd0, in_data1_reg[10]};
                mult_s_b[1] <= {2'd0, in_data1_reg[15]};
                // +
                mult_s_a[2] <= {2'd0, in_data1_reg[0]};
                mult_s_b[2] <= {2'd0, in_data1_reg[7]};
                mult_s_a[3] <= {2'd0, in_data1_reg[10]};
                mult_s_b[3] <= {2'd0, in_data1_reg[13]};
            end
        endcase
    end
end

// reg signed [15:0] mult_b_a[0~1]
// reg signed [27:0] mult_b_b[0~1]
always @(posedge clk or negedge rst_n) begin
    integer i;
    if (!rst_n) begin
        for (i = 0; i < 2; i = i + 1) begin
            mult_b_a[i] <= 16'd0;
            mult_b_b[i] <= 28'd0;
        end
    end
    else if (is_det_d1) begin
        mult_b_a[0] <=         mult_s_z[0];
        mult_b_b[0] <= {12'd0, mult_s_z[1]};
        mult_b_a[1] <=         mult_s_z[2];
        mult_b_b[1] <= {12'd0, mult_s_z[3]};
    end
    else if (cnt_clk == 9'd314) begin
        for (i = 0; i < 2; i = i + 1) begin
            mult_b_a[i] <= 16'd0;
            mult_b_b[i] <= 28'd0;
        end
    end
end

// reg signed [24:0] det_result;
always @(posedge clk or negedge rst_n) begin
    if      (!rst_n)     det_result <= 25'd0;
    else if (is_det_d2) begin
        if (~cnt_clk[0]) det_result <= det_result + (mult_b_z[0] - mult_b_z[1]);
        else             det_result <= det_result + (mult_b_z[1] - mult_b_z[0]);
    end
    else if (cnt_clk == 9'd314) det_result <= 25'd0;
    else                        det_result <= det_result;
end

// + a0 a5 a10 a15  0
// - a1 a6 a11 a12  3
// + a2 a7 a8  a13  6
// - a3 a4 a9  a14  9

// + a0 a6 a11 a13  10
// - a1 a7 a8  a14  1
// + a2 a4 a9  a15  4
// - a3 a5 a10 a12  7

// + a0 a7 a9  a14  8
// - a1 a4 a10 a15  11
// + a2 a5 a11 a12  2
// - a3 a6 a8  a13  5

//--------------------

// - a0 a7 a10 a13
// + a1 a4 a11 a14 
// - a2 a5 a8  a15
// + a3 a6 a9  a12

// - a0 a5 a11 a14
// + a1 a6 a8  a15 
// - a2 a7 a9  a12
// + a3 a4 a10 a13 

// - a0 a6 a9  a15
// + a1 a7 a10 a12
// - a2 a4 a11 a13 
// + a3 a5 a8  a14


// -------------- output --------------


// output reg out_valid;
// output reg signed [91:0] out_data;


always @(posedge clk or negedge rst_n) begin
    if      (!rst_n)                                 out_valid <= 1'b0;
    else if (cnt_clk >= 9'd251 && cnt_clk <= 9'd314) out_valid <= 1'b1;
    else out_valid <= 1'b0;
end

always @(posedge clk or negedge rst_n) begin
    if      (!rst_n)                                 out_data <= 92'd0;
    else if (cnt_clk >= 9'd251 && cnt_clk <= 9'd314) out_data <= 92'd6969;
    else                                             out_data <= 92'd0;
end




// -------------- mult IP --------------

// reg signed [7:0]  mult_s_a [0:7];
// reg signed [7:0]  mult_s_b [0:7];
// reg signed [15:0] mult_s_z [0:7];

// reg signed [15:0] mult_b_a [0:7];
// reg signed [27:0] mult_b_b [0:7];
// reg signed [41:0] mult_b_z [0:7];
generate
    for (k = 0; k < 8; k = k + 1) begin: mult_gen
        MULT #(8, 8, 16) mult_small (.a(mult_s_a[k]), .b(mult_s_b[k]), .z(mult_s_z[k]));
        MULT #(16, 28, 42) mult_big (.a(mult_b_a[k]), .b(mult_b_b[k]), .z(mult_b_z[k]));
    end
endgenerate

// reg signed [24:0] mult_f_a;
// reg signed [41:0] mult_f_b;
// reg signed [91:0] mult_f_z;
MULT #(25, 42, 92) mult_final (.a(mult_f_a), .b(mult_f_b), .z(mult_f_z));


endmodule


module MULT #(
    parameter a_bits = 8,
    parameter b_bits = 8,
    parameter z_bits = 16
) (
    input signed [a_bits-1:0] a,
    input signed [b_bits-1:0] b,
    output signed [z_bits-1:0] z
);
assign z = a * b;
endmodule

// module DIV_3 #(
//     parameter 
// ) (
//     ports
// );
    
// endmodule
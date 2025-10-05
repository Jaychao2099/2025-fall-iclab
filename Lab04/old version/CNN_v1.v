//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   (C) Copyright Laboratory System Integration and Silicon Implementation
//   All Right Reserved
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   ICLAB 2025 Fall
//   Lab04 Exercise		: Convolution Neural Network 
//   Author     		: Chung-Shuo Lee
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   File Name   : CNN.v
//   Module Name : CNN
//   Release version : V 1.0
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

module CNN(
    // Input Port
    clk,
    rst_n,
    in_valid,
    Image,
    Kernel_ch1,
    Kernel_ch2,
	Weight_Bias,
    task_number,
    mode,
    capacity_cost,
    // Output Port
    out_valid,
    out
    );

//---------------------------------------------------------------------
//   PARAMETER
//---------------------------------------------------------------------

// IEEE floating point parameter (You can't modify these parameters)
parameter inst_sig_width = 23;
parameter inst_exp_width = 8;
parameter inst_ieee_compliance = 0;
parameter inst_arch_type = 0;
parameter inst_arch = 0;
parameter inst_faithful_round = 0;

input           clk, rst_n, in_valid;
input   [31:0]  Image;
input   [31:0]  Kernel_ch1;
input   [31:0]  Kernel_ch2;
input   [31:0]  Weight_Bias;
input           task_number;
input   [1:0]   mode;
input   [3:0]   capacity_cost;
output  reg         out_valid;
output  reg [31:0]  out;

genvar k;

parameter IEEE_ONE     = 32'h3F800000;  // 00111111100000000000000000000000     //  1.0
parameter IEEE_NEG_ONE = 32'hBF800000;  // 10111111100000000000000000000000     // -1.0
parameter IEEE_0_01    = 32'h3C23D70A;  // 00111100001000111101011100001010     //  0.01
parameter IEEE_neg_5   = 32'hC0A00000;  // 11000000101000000000000000000000     // -5       // for max pooling

//---------------------------------------------------------------------
//   Reg & Wires
//---------------------------------------------------------------------

// ------------ pipeline ------------
reg [6:0] cnt_clk;  // 0 ~ 102 (7 bits)
reg [6:0] next_cnt_clk;  // 0 ~ 102 (7 bits)

// ------------ input buffer ------------
reg [inst_sig_width+inst_exp_width:0] big_Image [0:71];
reg [inst_sig_width+inst_exp_width:0] big_Image_reg [0:71];
wire [inst_sig_width+inst_exp_width:0] Image_padding_0 [0:63], Image_padding_1 [0:63];

reg [inst_sig_width+inst_exp_width:0] ch1 [0:17], ch2 [0:17];
reg [inst_sig_width+inst_exp_width:0] ch1_reg [0:17], ch2_reg [0:17];

reg [inst_sig_width+inst_exp_width:0] big_weight [0:56];
reg [inst_sig_width+inst_exp_width:0] big_weight_reg [0:56];
reg [inst_sig_width+inst_exp_width:0] weight_1_row_0 [0:4], 
                                      weight_1_row_1 [0:4], 
                                      weight_1_row_2 [0:4], 
                                      weight_1_row_3 [0:4], 
                                      weight_1_row_4 [0:4], 
                                      weight_1_row_5 [0:4], 
                                      weight_1_row_6 [0:4], 
                                      weight_1_row_7 [0:4];
reg [inst_sig_width+inst_exp_width:0] weight_2_1 [0:4], weight_2_2 [0:4], weight_2_3 [0:4];
wire [inst_sig_width+inst_exp_width:0] bias_1, bias_2;

reg task_reg;

reg [1:0] mode_reg;

reg [3:0] cap [0:4];
reg [3:0] cap_reg [0:4];

// ------------ IPs params ------------
// mult * 18
reg [inst_sig_width+inst_exp_width:0] mult_a[0:17], mult_b[0:17], mult_z[0:17];

// sum3 * 8
reg [inst_sig_width+inst_exp_width:0] sum3_a[0:7], sum3_b[0:7], sum3_c[0:7], sum3_z[0:7];

// add * 2
reg [inst_sig_width+inst_exp_width:0] add_a[0:1], add_b[0:1], add_z[0:1];

// cmp * 2
reg [inst_sig_width+inst_exp_width:0] cmp_a[0:1], cmp_b[0:1];
reg cmp_agtb[0:1];

// exp
reg [inst_sig_width+inst_exp_width:0] exp_a, exp_z;

// div
reg [inst_sig_width+inst_exp_width:0] div_a, div_b, div_z;

// ------------ other reg ------------

reg [2:0] mult_state, next_mult_state;

reg [inst_sig_width+inst_exp_width:0] mult_result [0:17];

reg [inst_sig_width+inst_exp_width:0] out_1 [0:35], out_2 [0:35];
reg [inst_sig_width+inst_exp_width:0] out_1_reg [0:35], out_2_reg [0:35];

reg [inst_sig_width+inst_exp_width:0] block_sum_tmp [0:1];

reg [2:0] cmp_idx_0, cmp_idx_1;
reg [2:0] next_cmp_idx_0, next_cmp_idx_1;

reg [inst_sig_width+inst_exp_width:0] max [0:7];
reg [inst_sig_width+inst_exp_width:0] max_reg [0:7];

reg [inst_sig_width+inst_exp_width:0] e_max [0:7];
reg [inst_sig_width+inst_exp_width:0] e_max_reg [0:7];

reg [2:0] prev_act_idx;
reg [2:0] act_idx;
reg [2:0] next_act_idx;

reg [inst_sig_width+inst_exp_width:0] act_1 [0:7];
reg [inst_sig_width+inst_exp_width:0] act_1_reg [0:7];

reg [inst_sig_width+inst_exp_width:0] act_2 [0:4];
reg [inst_sig_width+inst_exp_width:0] act_2_reg [0:4];

reg [inst_sig_width+inst_exp_width:0] ewact2_1, ewact2_2, ewact2_3;

reg [inst_sig_width+inst_exp_width:0] conv_sum_a, conv_sum_b, conv_sum_c, conv_sum_d;

// ----------------- task 1 -----------------

reg [3:0] current_select_mask;
// wire [3:0] select_test_case [1:15];
reg [inst_sig_width+inst_exp_width:0] select_sum;
reg [inst_sig_width+inst_exp_width:0] max_select_sum;
reg [3:0] select_case;

reg prev_is_in_cap;
wire is_in_cap;

//---------------------------------------------------------------------
// IPs
//---------------------------------------------------------------------

// mult * 18
generate
    for (k = 0; k < 18; k = k + 1) begin: mult_instances
        DW_fp_mult #(inst_sig_width, inst_exp_width, inst_ieee_compliance, inst_arch_type) 
            mult (.a(mult_a[k]), .b(mult_b[k]), .z(mult_z[k]), .rnd(3'b0), .status() );
    end
endgenerate

// sum3 * 8
generate
    for (k = 0; k < 8; k = k + 1) begin: sum3_instances
        DW_fp_sum3 #(inst_sig_width, inst_exp_width, inst_ieee_compliance, inst_arch_type) 
            sum3 (.a(sum3_a[k]), .b(sum3_b[k]), .c(sum3_c[k]), .rnd(3'b0), .z(sum3_z[k]), .status() );
    end
endgenerate

// add * 2
generate
    for (k = 0; k < 2; k = k + 1) begin: add_instances
        DW_fp_add #(inst_sig_width, inst_exp_width, inst_ieee_compliance) 
            add (.a(add_a[k]), .b(add_b[k]), .rnd(3'b0), .z(add_z[k]), .status() );
    end
endgenerate

// Todo: 比較誰比較好
// cmp * 2
generate
    for (k = 0; k < 2; k = k + 1) begin: cmp_instances
        DW_fp_cmp #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
            cmp (.a(cmp_a[k]), .b(cmp_b[k]), .agtb(cmp_agtb[k]) );
    end
endgenerate
// generate
//     for (k = 0; k < 2; k = k + 1) begin: cmp_instances
//         DW_fp_cmp #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
//             cmp (.a(cmp_a[k]), .b(cmp_b[k]), .zctr(1'b1), .z0(cmp_max[k]) );    // When zctr is 1, z0 = Max(a,b)
//     end
// endgenerate

// exp
DW_fp_exp #(inst_sig_width, inst_exp_width, inst_ieee_compliance, inst_arch)
    exp ( .a(exp_a), .z(exp_z), .status() );

// div
DW_fp_div #(inst_sig_width, inst_exp_width, inst_ieee_compliance, inst_faithful_round, 0)
    div ( .a(div_a), .b(div_b), .rnd(3'b0), .z(div_z), .status() );

//---------------------------------------------------------------------
// Design
//---------------------------------------------------------------------

// reg [6:0] cnt_clk;  // 0 ~ 92 (7 bits)
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) cnt_clk <= 7'b0;
	else cnt_clk <= next_cnt_clk;
end

// reg [6:0] next_cnt_clk;  // 0 ~ 92 (7 bits)
always @(*) begin
    next_cnt_clk = cnt_clk;
    if      (cnt_clk == 7'd102) next_cnt_clk = 7'b0;
    else if (cnt_clk > 7'b0 || in_valid) next_cnt_clk = cnt_clk + 1;
end

// ----------------- input -----------------

// input   [31:0]  Image;

// reg [inst_sig_width+inst_exp_width:0] big_Image_reg [0:71];
always @(posedge clk) begin
    big_Image_reg <= big_Image;
end

// reg [inst_sig_width+inst_exp_width:0] big_Image [0:71];
always @(*) begin
    big_Image = big_Image_reg;
    if (in_valid) begin
        big_Image[cnt_clk] = Image;
        if (cnt_clk == 0 && task_number || task_reg) big_Image[cnt_clk + 36] = Image;
    end
end

// wire [inst_sig_width+inst_exp_width:0] Image_padding_0 [0:63];
assign Image_padding_0[0] = mode_reg[1] ? big_Image_reg[7] : big_Image_reg[0];
assign Image_padding_0[1] = mode_reg[1] ? big_Image_reg[6] : big_Image_reg[0];
assign Image_padding_0[2] = mode_reg[1] ? big_Image_reg[7] : big_Image_reg[1];
assign Image_padding_0[3] = mode_reg[1] ? big_Image_reg[8] : big_Image_reg[2];
assign Image_padding_0[4] = mode_reg[1] ? big_Image_reg[9] : big_Image_reg[3];
assign Image_padding_0[5] = mode_reg[1] ? big_Image_reg[10] : big_Image_reg[4];
assign Image_padding_0[6] = mode_reg[1] ? big_Image_reg[11] : big_Image_reg[5];
assign Image_padding_0[7] = mode_reg[1] ? big_Image_reg[10] : big_Image_reg[5];
assign Image_padding_0[8] = mode_reg[1] ? big_Image_reg[1] : big_Image_reg[0];
assign Image_padding_0[9] = big_Image_reg[0];
assign Image_padding_0[10] = big_Image_reg[1];
assign Image_padding_0[11] = big_Image_reg[2];
assign Image_padding_0[12] = big_Image_reg[3];
assign Image_padding_0[13] = big_Image_reg[4];
assign Image_padding_0[14] = big_Image_reg[5];
assign Image_padding_0[15] = mode_reg[1] ? big_Image_reg[4] : big_Image_reg[5];
assign Image_padding_0[16] = mode_reg[1] ? big_Image_reg[7] : big_Image_reg[6];
assign Image_padding_0[17] = big_Image_reg[6];
assign Image_padding_0[18] = big_Image_reg[7];
assign Image_padding_0[19] = big_Image_reg[8];
assign Image_padding_0[20] = big_Image_reg[9];
assign Image_padding_0[21] = big_Image_reg[10];
assign Image_padding_0[22] = big_Image_reg[11];
assign Image_padding_0[23] = mode_reg[1] ? big_Image_reg[10] : big_Image_reg[11];
assign Image_padding_0[24] = mode_reg[1] ? big_Image_reg[13] : big_Image_reg[12];
assign Image_padding_0[25] = big_Image_reg[12];
assign Image_padding_0[26] = big_Image_reg[13];
assign Image_padding_0[27] = big_Image_reg[14];
assign Image_padding_0[28] = big_Image_reg[15];
assign Image_padding_0[29] = big_Image_reg[16];
assign Image_padding_0[30] = big_Image_reg[17];
assign Image_padding_0[31] = mode_reg[1] ? big_Image_reg[16] : big_Image_reg[17];
assign Image_padding_0[32] = mode_reg[1] ? big_Image_reg[19] : big_Image_reg[18];
assign Image_padding_0[33] = big_Image_reg[18];
assign Image_padding_0[34] = big_Image_reg[19];
assign Image_padding_0[35] = big_Image_reg[20];
assign Image_padding_0[36] = big_Image_reg[21];
assign Image_padding_0[37] = big_Image_reg[22];
assign Image_padding_0[38] = big_Image_reg[23];
assign Image_padding_0[39] = mode_reg[1] ? big_Image_reg[22] : big_Image_reg[23];
assign Image_padding_0[40] = mode_reg[1] ? big_Image_reg[25] : big_Image_reg[24];
assign Image_padding_0[41] = big_Image_reg[24];
assign Image_padding_0[42] = big_Image_reg[25];
assign Image_padding_0[43] = big_Image_reg[26];
assign Image_padding_0[44] = big_Image_reg[27];
assign Image_padding_0[45] = big_Image_reg[28];
assign Image_padding_0[46] = big_Image_reg[29];
assign Image_padding_0[47] = mode_reg[1] ? big_Image_reg[28] : big_Image_reg[29];
assign Image_padding_0[48] = mode_reg[1] ? big_Image_reg[31] : big_Image_reg[30];
assign Image_padding_0[49] = big_Image_reg[30];
assign Image_padding_0[50] = big_Image_reg[31];
assign Image_padding_0[51] = big_Image_reg[32];
assign Image_padding_0[52] = big_Image_reg[33];
assign Image_padding_0[53] = big_Image_reg[34];
assign Image_padding_0[54] = big_Image_reg[35];
assign Image_padding_0[55] = mode_reg[1] ? big_Image_reg[34] : big_Image_reg[35];
assign Image_padding_0[56] = mode_reg[1] ? big_Image_reg[25] : big_Image_reg[30];
assign Image_padding_0[57] = mode_reg[1] ? big_Image_reg[24] : big_Image_reg[30];
assign Image_padding_0[58] = mode_reg[1] ? big_Image_reg[25] : big_Image_reg[31];
assign Image_padding_0[59] = mode_reg[1] ? big_Image_reg[26] : big_Image_reg[32];
assign Image_padding_0[60] = mode_reg[1] ? big_Image_reg[27] : big_Image_reg[33];
assign Image_padding_0[61] = mode_reg[1] ? big_Image_reg[28] : big_Image_reg[34];
assign Image_padding_0[62] = mode_reg[1] ? big_Image_reg[29] : big_Image_reg[35];
assign Image_padding_0[63] = mode_reg[1] ? big_Image_reg[28] : big_Image_reg[35];

// wire [inst_sig_width+inst_exp_width:0] Image_padding_1 [0:63];
assign Image_padding_1[0] = mode_reg[1] ? big_Image_reg[43] : big_Image_reg[36];
assign Image_padding_1[1] = mode_reg[1] ? big_Image_reg[42] : big_Image_reg[36];
assign Image_padding_1[2] = mode_reg[1] ? big_Image_reg[43] : big_Image_reg[37];
assign Image_padding_1[3] = mode_reg[1] ? big_Image_reg[44] : big_Image_reg[38];
assign Image_padding_1[4] = mode_reg[1] ? big_Image_reg[45] : big_Image_reg[39];
assign Image_padding_1[5] = mode_reg[1] ? big_Image_reg[46] : big_Image_reg[40];
assign Image_padding_1[6] = mode_reg[1] ? big_Image_reg[47] : big_Image_reg[41];
assign Image_padding_1[7] = mode_reg[1] ? big_Image_reg[46] : big_Image_reg[41];
assign Image_padding_1[8] = mode_reg[1] ? big_Image_reg[37] : big_Image_reg[36];
assign Image_padding_1[9] = big_Image_reg[36];
assign Image_padding_1[10] = big_Image_reg[37];
assign Image_padding_1[11] = big_Image_reg[38];
assign Image_padding_1[12] = big_Image_reg[39];
assign Image_padding_1[13] = big_Image_reg[40];
assign Image_padding_1[14] = big_Image_reg[41];
assign Image_padding_1[15] = mode_reg[1] ? big_Image_reg[40] : big_Image_reg[41];
assign Image_padding_1[16] = mode_reg[1] ? big_Image_reg[43] : big_Image_reg[42];
assign Image_padding_1[17] = big_Image_reg[42];
assign Image_padding_1[18] = big_Image_reg[43];
assign Image_padding_1[19] = big_Image_reg[44];
assign Image_padding_1[20] = big_Image_reg[45];
assign Image_padding_1[21] = big_Image_reg[46];
assign Image_padding_1[22] = big_Image_reg[47];
assign Image_padding_1[23] = mode_reg[1] ? big_Image_reg[46] : big_Image_reg[47];
assign Image_padding_1[24] = mode_reg[1] ? big_Image_reg[49] : big_Image_reg[48];
assign Image_padding_1[25] = big_Image_reg[48];
assign Image_padding_1[26] = big_Image_reg[49];
assign Image_padding_1[27] = big_Image_reg[50];
assign Image_padding_1[28] = big_Image_reg[51];
assign Image_padding_1[29] = big_Image_reg[52];
assign Image_padding_1[30] = big_Image_reg[53];
assign Image_padding_1[31] = mode_reg[1] ? big_Image_reg[52] : big_Image_reg[53];
assign Image_padding_1[32] = mode_reg[1] ? big_Image_reg[55] : big_Image_reg[54];
assign Image_padding_1[33] = big_Image_reg[54];
assign Image_padding_1[34] = big_Image_reg[55];
assign Image_padding_1[35] = big_Image_reg[56];
assign Image_padding_1[36] = big_Image_reg[57];
assign Image_padding_1[37] = big_Image_reg[58];
assign Image_padding_1[38] = big_Image_reg[59];
assign Image_padding_1[39] = mode_reg[1] ? big_Image_reg[58] : big_Image_reg[59];
assign Image_padding_1[40] = mode_reg[1] ? big_Image_reg[61] : big_Image_reg[60];
assign Image_padding_1[41] = big_Image_reg[60];
assign Image_padding_1[42] = big_Image_reg[61];
assign Image_padding_1[43] = big_Image_reg[62];
assign Image_padding_1[44] = big_Image_reg[63];
assign Image_padding_1[45] = big_Image_reg[64];
assign Image_padding_1[46] = big_Image_reg[65];
assign Image_padding_1[47] = mode_reg[1] ? big_Image_reg[64] : big_Image_reg[65];
assign Image_padding_1[48] = mode_reg[1] ? big_Image_reg[67] : big_Image_reg[66];
assign Image_padding_1[49] = big_Image_reg[66];
assign Image_padding_1[50] = big_Image_reg[67];
assign Image_padding_1[51] = big_Image_reg[68];
assign Image_padding_1[52] = big_Image_reg[69];
assign Image_padding_1[53] = big_Image_reg[70];
assign Image_padding_1[54] = big_Image_reg[71];
assign Image_padding_1[55] = mode_reg[1] ? big_Image_reg[70] : big_Image_reg[71];
assign Image_padding_1[56] = mode_reg[1] ? big_Image_reg[61] : big_Image_reg[66];
assign Image_padding_1[57] = mode_reg[1] ? big_Image_reg[60] : big_Image_reg[66];
assign Image_padding_1[58] = mode_reg[1] ? big_Image_reg[61] : big_Image_reg[67];
assign Image_padding_1[59] = mode_reg[1] ? big_Image_reg[62] : big_Image_reg[68];
assign Image_padding_1[60] = mode_reg[1] ? big_Image_reg[63] : big_Image_reg[69];
assign Image_padding_1[61] = mode_reg[1] ? big_Image_reg[64] : big_Image_reg[70];
assign Image_padding_1[62] = mode_reg[1] ? big_Image_reg[65] : big_Image_reg[71];
assign Image_padding_1[63] = mode_reg[1] ? big_Image_reg[64] : big_Image_reg[71];

// input   [31:0]  Kernel_ch1;
// input   [31:0]  Kernel_ch2;

// reg [inst_sig_width+inst_exp_width:0] ch1 [0:17], ch2 [0:17];            // 0~8, 9~17
always @(posedge clk) begin
    ch1_reg <= ch1;
    ch2_reg <= ch2;
end

// reg [inst_sig_width+inst_exp_width:0] ch1_reg [0:17], ch2_reg [0:17];
always @(*) begin
    ch1 = ch1_reg;
    ch2 = ch2_reg;
    if (in_valid) ch1[cnt_clk] = Kernel_ch1;
    if (in_valid) ch2[cnt_clk] = Kernel_ch2;
end

// input   [31:0]  Weight_Bias;

// reg [inst_sig_width+inst_exp_width:0] big_weight_reg [0:56];
always @(posedge clk) begin
    big_weight_reg <= big_weight;
end

// reg [inst_sig_width+inst_exp_width:0] big_weight [0:56];
always @(*) begin
    big_weight = big_weight_reg;
    if (in_valid) big_weight[cnt_clk] = Weight_Bias;
end

// 0~7, 8~15, 16~23, 24~31, 32~39
// reg [inst_sig_width+inst_exp_width:0] weight_1_row_0 [0:4], 
//                                       weight_1_row_1 [0:4], 
//                                       weight_1_row_2 [0:4], 
//                                       weight_1_row_3 [0:4], 
//                                       weight_1_row_4 [0:4], 
//                                       weight_1_row_5 [0:4], 
//                                       weight_1_row_6 [0:4], 
//                                       weight_1_row_7 [0:4];
always @(*) begin
    integer i;
    for (i = 0; i < 5; i = i + 1) begin
        weight_1_row_0[i] = big_weight_reg[i*8    ];
        weight_1_row_1[i] = big_weight_reg[i*8 + 1];
        weight_1_row_2[i] = big_weight_reg[i*8 + 2];
        weight_1_row_3[i] = big_weight_reg[i*8 + 3];
        weight_1_row_4[i] = big_weight_reg[i*8 + 4];
        weight_1_row_5[i] = big_weight_reg[i*8 + 5];
        weight_1_row_6[i] = big_weight_reg[i*8 + 6];
        weight_1_row_7[i] = big_weight_reg[i*8 + 7];
    end
end

// 41~45, 46~50, 51~55
// reg [inst_sig_width+inst_exp_width:0] weight_2_1 [0:4], weight_2_2 [0:4], weight_2_3 [0:4];
always @(*) begin
    integer i;
    for (i = 0; i < 5; i = i + 1) begin
        weight_2_1[i] = big_weight_reg[i+41];
        weight_2_2[i] = big_weight_reg[i+46];
        weight_2_3[i] = big_weight_reg[i+51];
    end
end

// wire [inst_sig_width+inst_exp_width:0] bias_1, bias_2;
assign bias_1 = big_weight_reg[40];
assign bias_2 = big_weight_reg[56];

// input task_number;

// reg task_reg;
always @(posedge clk) begin
    if (in_valid && cnt_clk == 7'd0) task_reg <= task_number;
    else task_reg <= task_reg;
end

// input [1:0] mode;

// reg [1:0] mode_reg;
always @(posedge clk) begin
    if (in_valid && cnt_clk == 7'd0) mode_reg <= mode;
    else mode_reg <= mode_reg;
end

// input [3:0] capacity_cost;

// reg [3:0] cap_reg [0:4];
always @(posedge clk) begin
    cap_reg <= cap;
end

// reg [3:0] cap [0:4];
always @(*) begin
    cap = cap_reg;
    if (in_valid) cap[cnt_clk] = capacity_cost;
end

// ----------------- convolution -----------------

// // mult * 18
// generate
//     for (k = 0; k < 18; k = k + 1) begin: mult_instances
//         DW_fp_mult #(inst_sig_width, inst_exp_width, inst_ieee_compliance, inst_arch_type) 
//             mult (.a(mult_a[k]), .b(mult_b[k]), .z(mult_z[k]), .rnd(3'b0), .status() );
//     end
// endgenerate

// reg [inst_sig_width+inst_exp_width:0] mult_a[0:17], mult_b[0:17], mult_z[0:17];

parameter S_MULT_IDLE  = 0;
parameter S_MULT_img0  = 1;
parameter S_MULT_img1  = 2;
parameter S_MULT_FC1   = 3;
parameter S_MULT_LEAKY = 4;
parameter S_MULT_FC2   = 5;

// reg [2:0] mult_state
always @(posedge clk) begin
    mult_state <= next_mult_state;
end

// reg [2:0] next_mult_state;
always @(*) begin
    next_mult_state = mult_state;
    case (cnt_clk + 1)
        9: next_mult_state = S_MULT_img0;
        45: next_mult_state = S_MULT_img1;
        81: next_mult_state = S_MULT_IDLE;

        83: next_mult_state = S_MULT_FC1;
        91: next_mult_state = S_MULT_IDLE;

        92: next_mult_state = S_MULT_LEAKY;

        93: next_mult_state = S_MULT_FC2;
        96: next_mult_state = S_MULT_IDLE;
    endcase
end

// mult_a
always @(*) begin
    integer i;
    for (i = 0; i < 18; i = i + 1) mult_a[i] = 32'b0;   // avoid latch
    case (mult_state)
        S_MULT_img0: begin
            for (i = 0; i < 9; i = i + 1) begin
                mult_a[i]   = ch1_reg[i];
                mult_a[i+9] = ch2_reg[i];
            end
        end
        S_MULT_img1: begin
            for (i = 0; i < 9; i = i + 1) begin
                mult_a[i]   = ch1_reg[i+9];
                mult_a[i+9] = ch2_reg[i+9];
            end
        end
        // ----------------- Fully connect 1 -----------------
        S_MULT_FC1: begin
            for (i = 0; i < 5; i = i + 1) begin
                mult_a[i] = act_1_reg[prev_act_idx];
            end
        end
        // ----------------- Leaky ReLU -----------------
        S_MULT_LEAKY: begin
            for (i = 0; i < 5; i = i + 1) begin
                mult_a[i] = IEEE_0_01;
            end
        end
        // ----------------- Fully connect 2 -----------------
        S_MULT_FC2: begin
            for (i = 0; i < 5; i = i + 1) begin
                mult_a[i] = act_2_reg[i];
            end
        end
        // default: begin
        //     case (cnt_clk)
        //         // ----------------- Fully connect 1 -----------------
        //         83: begin for (i = 0; i < 5; i = i + 1) mult_a[i] = act_1_reg[0]; end
        //         84: begin for (i = 0; i < 5; i = i + 1) mult_a[i] = act_1_reg[4] end
        //         85: begin for (i = 0; i < 5; i = i + 1) mult_a[i] = act_1_reg[1] end
        //         86: begin for (i = 0; i < 5; i = i + 1) mult_a[i] = act_1_reg[5] end
        //         87: begin for (i = 0; i < 5; i = i + 1) mult_a[i] = act_1_reg[2] end
        //         88: begin for (i = 0; i < 5; i = i + 1) mult_a[i] = act_1_reg[6] end
        //         89: begin for (i = 0; i < 5; i = i + 1) mult_a[i] = act_1_reg[3] end
        //         90: begin for (i = 0; i < 5; i = i + 1) mult_a[i] = act_1_reg[7] end
        //         // ----------------- Leaky ReLU -----------------
        //         92: begin for (i = 0; i < 5; i = i + 1) mult_a[i] = IEEE_0_01; end
        //     endcase
        // end
    endcase
end

// mult_b
always @(*) begin
    integer i;
    for (i = 0; i < 18; i = i + 1) mult_b[i] = 32'b0;   // avoid latch
    case (cnt_clk)
        // ----------------- convolution -----------------
        9: begin mult_b[0] = Image_padding_0[0]; mult_b[1] = Image_padding_0[1]; mult_b[2] = Image_padding_0[2]; mult_b[3] = Image_padding_0[8]; mult_b[4] = Image_padding_0[9]; mult_b[5] = Image_padding_0[10]; mult_b[6] = Image_padding_0[16]; mult_b[7] = Image_padding_0[17]; mult_b[8] = Image_padding_0[18]; end
        10: begin mult_b[0] = Image_padding_0[1]; mult_b[1] = Image_padding_0[2]; mult_b[2] = Image_padding_0[3]; mult_b[3] = Image_padding_0[9]; mult_b[4] = Image_padding_0[10]; mult_b[5] = Image_padding_0[11]; mult_b[6] = Image_padding_0[17]; mult_b[7] = Image_padding_0[18]; mult_b[8] = Image_padding_0[19]; end
        11: begin mult_b[0] = Image_padding_0[2]; mult_b[1] = Image_padding_0[3]; mult_b[2] = Image_padding_0[4]; mult_b[3] = Image_padding_0[10]; mult_b[4] = Image_padding_0[11]; mult_b[5] = Image_padding_0[12]; mult_b[6] = Image_padding_0[18]; mult_b[7] = Image_padding_0[19]; mult_b[8] = Image_padding_0[20]; end
        12: begin mult_b[0] = Image_padding_0[3]; mult_b[1] = Image_padding_0[4]; mult_b[2] = Image_padding_0[5]; mult_b[3] = Image_padding_0[11]; mult_b[4] = Image_padding_0[12]; mult_b[5] = Image_padding_0[13]; mult_b[6] = Image_padding_0[19]; mult_b[7] = Image_padding_0[20]; mult_b[8] = Image_padding_0[21]; end
        13: begin mult_b[0] = Image_padding_0[4]; mult_b[1] = Image_padding_0[5]; mult_b[2] = Image_padding_0[6]; mult_b[3] = Image_padding_0[12]; mult_b[4] = Image_padding_0[13]; mult_b[5] = Image_padding_0[14]; mult_b[6] = Image_padding_0[20]; mult_b[7] = Image_padding_0[21]; mult_b[8] = Image_padding_0[22]; end
        14: begin mult_b[0] = Image_padding_0[5]; mult_b[1] = Image_padding_0[6]; mult_b[2] = Image_padding_0[7]; mult_b[3] = Image_padding_0[13]; mult_b[4] = Image_padding_0[14]; mult_b[5] = Image_padding_0[15]; mult_b[6] = Image_padding_0[21]; mult_b[7] = Image_padding_0[22]; mult_b[8] = Image_padding_0[23]; end
        15: begin mult_b[0] = Image_padding_0[8]; mult_b[1] = Image_padding_0[9]; mult_b[2] = Image_padding_0[10]; mult_b[3] = Image_padding_0[16]; mult_b[4] = Image_padding_0[17]; mult_b[5] = Image_padding_0[18]; mult_b[6] = Image_padding_0[24]; mult_b[7] = Image_padding_0[25]; mult_b[8] = Image_padding_0[26]; end
        16: begin mult_b[0] = Image_padding_0[9]; mult_b[1] = Image_padding_0[10]; mult_b[2] = Image_padding_0[11]; mult_b[3] = Image_padding_0[17]; mult_b[4] = Image_padding_0[18]; mult_b[5] = Image_padding_0[19]; mult_b[6] = Image_padding_0[25]; mult_b[7] = Image_padding_0[26]; mult_b[8] = Image_padding_0[27]; end
        17: begin mult_b[0] = Image_padding_0[10]; mult_b[1] = Image_padding_0[11]; mult_b[2] = Image_padding_0[12]; mult_b[3] = Image_padding_0[18]; mult_b[4] = Image_padding_0[19]; mult_b[5] = Image_padding_0[20]; mult_b[6] = Image_padding_0[26]; mult_b[7] = Image_padding_0[27]; mult_b[8] = Image_padding_0[28]; end
        18: begin mult_b[0] = Image_padding_0[11]; mult_b[1] = Image_padding_0[12]; mult_b[2] = Image_padding_0[13]; mult_b[3] = Image_padding_0[19]; mult_b[4] = Image_padding_0[20]; mult_b[5] = Image_padding_0[21]; mult_b[6] = Image_padding_0[27]; mult_b[7] = Image_padding_0[28]; mult_b[8] = Image_padding_0[29]; end
        19: begin mult_b[0] = Image_padding_0[12]; mult_b[1] = Image_padding_0[13]; mult_b[2] = Image_padding_0[14]; mult_b[3] = Image_padding_0[20]; mult_b[4] = Image_padding_0[21]; mult_b[5] = Image_padding_0[22]; mult_b[6] = Image_padding_0[28]; mult_b[7] = Image_padding_0[29]; mult_b[8] = Image_padding_0[30]; end
        20: begin mult_b[0] = Image_padding_0[13]; mult_b[1] = Image_padding_0[14]; mult_b[2] = Image_padding_0[15]; mult_b[3] = Image_padding_0[21]; mult_b[4] = Image_padding_0[22]; mult_b[5] = Image_padding_0[23]; mult_b[6] = Image_padding_0[29]; mult_b[7] = Image_padding_0[30]; mult_b[8] = Image_padding_0[31]; end
        21: begin mult_b[0] = Image_padding_0[16]; mult_b[1] = Image_padding_0[17]; mult_b[2] = Image_padding_0[18]; mult_b[3] = Image_padding_0[24]; mult_b[4] = Image_padding_0[25]; mult_b[5] = Image_padding_0[26]; mult_b[6] = Image_padding_0[32]; mult_b[7] = Image_padding_0[33]; mult_b[8] = Image_padding_0[34]; end
        22: begin mult_b[0] = Image_padding_0[17]; mult_b[1] = Image_padding_0[18]; mult_b[2] = Image_padding_0[19]; mult_b[3] = Image_padding_0[25]; mult_b[4] = Image_padding_0[26]; mult_b[5] = Image_padding_0[27]; mult_b[6] = Image_padding_0[33]; mult_b[7] = Image_padding_0[34]; mult_b[8] = Image_padding_0[35]; end
        23: begin mult_b[0] = Image_padding_0[18]; mult_b[1] = Image_padding_0[19]; mult_b[2] = Image_padding_0[20]; mult_b[3] = Image_padding_0[26]; mult_b[4] = Image_padding_0[27]; mult_b[5] = Image_padding_0[28]; mult_b[6] = Image_padding_0[34]; mult_b[7] = Image_padding_0[35]; mult_b[8] = Image_padding_0[36]; end
        24: begin mult_b[0] = Image_padding_0[19]; mult_b[1] = Image_padding_0[20]; mult_b[2] = Image_padding_0[21]; mult_b[3] = Image_padding_0[27]; mult_b[4] = Image_padding_0[28]; mult_b[5] = Image_padding_0[29]; mult_b[6] = Image_padding_0[35]; mult_b[7] = Image_padding_0[36]; mult_b[8] = Image_padding_0[37]; end
        25: begin mult_b[0] = Image_padding_0[20]; mult_b[1] = Image_padding_0[21]; mult_b[2] = Image_padding_0[22]; mult_b[3] = Image_padding_0[28]; mult_b[4] = Image_padding_0[29]; mult_b[5] = Image_padding_0[30]; mult_b[6] = Image_padding_0[36]; mult_b[7] = Image_padding_0[37]; mult_b[8] = Image_padding_0[38]; end
        26: begin mult_b[0] = Image_padding_0[21]; mult_b[1] = Image_padding_0[22]; mult_b[2] = Image_padding_0[23]; mult_b[3] = Image_padding_0[29]; mult_b[4] = Image_padding_0[30]; mult_b[5] = Image_padding_0[31]; mult_b[6] = Image_padding_0[37]; mult_b[7] = Image_padding_0[38]; mult_b[8] = Image_padding_0[39]; end
        27: begin mult_b[0] = Image_padding_0[24]; mult_b[1] = Image_padding_0[25]; mult_b[2] = Image_padding_0[26]; mult_b[3] = Image_padding_0[32]; mult_b[4] = Image_padding_0[33]; mult_b[5] = Image_padding_0[34]; mult_b[6] = Image_padding_0[40]; mult_b[7] = Image_padding_0[41]; mult_b[8] = Image_padding_0[42]; end
        28: begin mult_b[0] = Image_padding_0[25]; mult_b[1] = Image_padding_0[26]; mult_b[2] = Image_padding_0[27]; mult_b[3] = Image_padding_0[33]; mult_b[4] = Image_padding_0[34]; mult_b[5] = Image_padding_0[35]; mult_b[6] = Image_padding_0[41]; mult_b[7] = Image_padding_0[42]; mult_b[8] = Image_padding_0[43]; end
        29: begin mult_b[0] = Image_padding_0[26]; mult_b[1] = Image_padding_0[27]; mult_b[2] = Image_padding_0[28]; mult_b[3] = Image_padding_0[34]; mult_b[4] = Image_padding_0[35]; mult_b[5] = Image_padding_0[36]; mult_b[6] = Image_padding_0[42]; mult_b[7] = Image_padding_0[43]; mult_b[8] = Image_padding_0[44]; end
        30: begin mult_b[0] = Image_padding_0[27]; mult_b[1] = Image_padding_0[28]; mult_b[2] = Image_padding_0[29]; mult_b[3] = Image_padding_0[35]; mult_b[4] = Image_padding_0[36]; mult_b[5] = Image_padding_0[37]; mult_b[6] = Image_padding_0[43]; mult_b[7] = Image_padding_0[44]; mult_b[8] = Image_padding_0[45]; end
        31: begin mult_b[0] = Image_padding_0[28]; mult_b[1] = Image_padding_0[29]; mult_b[2] = Image_padding_0[30]; mult_b[3] = Image_padding_0[36]; mult_b[4] = Image_padding_0[37]; mult_b[5] = Image_padding_0[38]; mult_b[6] = Image_padding_0[44]; mult_b[7] = Image_padding_0[45]; mult_b[8] = Image_padding_0[46]; end
        32: begin mult_b[0] = Image_padding_0[29]; mult_b[1] = Image_padding_0[30]; mult_b[2] = Image_padding_0[31]; mult_b[3] = Image_padding_0[37]; mult_b[4] = Image_padding_0[38]; mult_b[5] = Image_padding_0[39]; mult_b[6] = Image_padding_0[45]; mult_b[7] = Image_padding_0[46]; mult_b[8] = Image_padding_0[47]; end
        33: begin mult_b[0] = Image_padding_0[32]; mult_b[1] = Image_padding_0[33]; mult_b[2] = Image_padding_0[34]; mult_b[3] = Image_padding_0[40]; mult_b[4] = Image_padding_0[41]; mult_b[5] = Image_padding_0[42]; mult_b[6] = Image_padding_0[48]; mult_b[7] = Image_padding_0[49]; mult_b[8] = Image_padding_0[50]; end
        34: begin mult_b[0] = Image_padding_0[33]; mult_b[1] = Image_padding_0[34]; mult_b[2] = Image_padding_0[35]; mult_b[3] = Image_padding_0[41]; mult_b[4] = Image_padding_0[42]; mult_b[5] = Image_padding_0[43]; mult_b[6] = Image_padding_0[49]; mult_b[7] = Image_padding_0[50]; mult_b[8] = Image_padding_0[51]; end
        35: begin mult_b[0] = Image_padding_0[34]; mult_b[1] = Image_padding_0[35]; mult_b[2] = Image_padding_0[36]; mult_b[3] = Image_padding_0[42]; mult_b[4] = Image_padding_0[43]; mult_b[5] = Image_padding_0[44]; mult_b[6] = Image_padding_0[50]; mult_b[7] = Image_padding_0[51]; mult_b[8] = Image_padding_0[52]; end
        36: begin mult_b[0] = Image_padding_0[35]; mult_b[1] = Image_padding_0[36]; mult_b[2] = Image_padding_0[37]; mult_b[3] = Image_padding_0[43]; mult_b[4] = Image_padding_0[44]; mult_b[5] = Image_padding_0[45]; mult_b[6] = Image_padding_0[51]; mult_b[7] = Image_padding_0[52]; mult_b[8] = Image_padding_0[53]; end
        37: begin mult_b[0] = Image_padding_0[36]; mult_b[1] = Image_padding_0[37]; mult_b[2] = Image_padding_0[38]; mult_b[3] = Image_padding_0[44]; mult_b[4] = Image_padding_0[45]; mult_b[5] = Image_padding_0[46]; mult_b[6] = Image_padding_0[52]; mult_b[7] = Image_padding_0[53]; mult_b[8] = Image_padding_0[54]; end
        38: begin mult_b[0] = Image_padding_0[37]; mult_b[1] = Image_padding_0[38]; mult_b[2] = Image_padding_0[39]; mult_b[3] = Image_padding_0[45]; mult_b[4] = Image_padding_0[46]; mult_b[5] = Image_padding_0[47]; mult_b[6] = Image_padding_0[53]; mult_b[7] = Image_padding_0[54]; mult_b[8] = Image_padding_0[55]; end
        39: begin mult_b[0] = Image_padding_0[40]; mult_b[1] = Image_padding_0[41]; mult_b[2] = Image_padding_0[42]; mult_b[3] = Image_padding_0[48]; mult_b[4] = Image_padding_0[49]; mult_b[5] = Image_padding_0[50]; mult_b[6] = Image_padding_0[56]; mult_b[7] = Image_padding_0[57]; mult_b[8] = Image_padding_0[58]; end
        40: begin mult_b[0] = Image_padding_0[41]; mult_b[1] = Image_padding_0[42]; mult_b[2] = Image_padding_0[43]; mult_b[3] = Image_padding_0[49]; mult_b[4] = Image_padding_0[50]; mult_b[5] = Image_padding_0[51]; mult_b[6] = Image_padding_0[57]; mult_b[7] = Image_padding_0[58]; mult_b[8] = Image_padding_0[59]; end
        41: begin mult_b[0] = Image_padding_0[42]; mult_b[1] = Image_padding_0[43]; mult_b[2] = Image_padding_0[44]; mult_b[3] = Image_padding_0[50]; mult_b[4] = Image_padding_0[51]; mult_b[5] = Image_padding_0[52]; mult_b[6] = Image_padding_0[58]; mult_b[7] = Image_padding_0[59]; mult_b[8] = Image_padding_0[60]; end
        42: begin mult_b[0] = Image_padding_0[43]; mult_b[1] = Image_padding_0[44]; mult_b[2] = Image_padding_0[45]; mult_b[3] = Image_padding_0[51]; mult_b[4] = Image_padding_0[52]; mult_b[5] = Image_padding_0[53]; mult_b[6] = Image_padding_0[59]; mult_b[7] = Image_padding_0[60]; mult_b[8] = Image_padding_0[61]; end
        43: begin mult_b[0] = Image_padding_0[44]; mult_b[1] = Image_padding_0[45]; mult_b[2] = Image_padding_0[46]; mult_b[3] = Image_padding_0[52]; mult_b[4] = Image_padding_0[53]; mult_b[5] = Image_padding_0[54]; mult_b[6] = Image_padding_0[60]; mult_b[7] = Image_padding_0[61]; mult_b[8] = Image_padding_0[62]; end
        44: begin mult_b[0] = Image_padding_0[45]; mult_b[1] = Image_padding_0[46]; mult_b[2] = Image_padding_0[47]; mult_b[3] = Image_padding_0[53]; mult_b[4] = Image_padding_0[54]; mult_b[5] = Image_padding_0[55]; mult_b[6] = Image_padding_0[61]; mult_b[7] = Image_padding_0[62]; mult_b[8] = Image_padding_0[63]; end
        45: begin mult_b[0] = Image_padding_1[0]; mult_b[1] = Image_padding_1[1]; mult_b[2] = Image_padding_1[2]; mult_b[3] = Image_padding_1[8]; mult_b[4] = Image_padding_1[9]; mult_b[5] = Image_padding_1[10]; mult_b[6] = Image_padding_1[16]; mult_b[7] = Image_padding_1[17]; mult_b[8] = Image_padding_1[18]; end
        46: begin mult_b[0] = Image_padding_1[1]; mult_b[1] = Image_padding_1[2]; mult_b[2] = Image_padding_1[3]; mult_b[3] = Image_padding_1[9]; mult_b[4] = Image_padding_1[10]; mult_b[5] = Image_padding_1[11]; mult_b[6] = Image_padding_1[17]; mult_b[7] = Image_padding_1[18]; mult_b[8] = Image_padding_1[19]; end
        47: begin mult_b[0] = Image_padding_1[2]; mult_b[1] = Image_padding_1[3]; mult_b[2] = Image_padding_1[4]; mult_b[3] = Image_padding_1[10]; mult_b[4] = Image_padding_1[11]; mult_b[5] = Image_padding_1[12]; mult_b[6] = Image_padding_1[18]; mult_b[7] = Image_padding_1[19]; mult_b[8] = Image_padding_1[20]; end
        48: begin mult_b[0] = Image_padding_1[3]; mult_b[1] = Image_padding_1[4]; mult_b[2] = Image_padding_1[5]; mult_b[3] = Image_padding_1[11]; mult_b[4] = Image_padding_1[12]; mult_b[5] = Image_padding_1[13]; mult_b[6] = Image_padding_1[19]; mult_b[7] = Image_padding_1[20]; mult_b[8] = Image_padding_1[21]; end
        49: begin mult_b[0] = Image_padding_1[4]; mult_b[1] = Image_padding_1[5]; mult_b[2] = Image_padding_1[6]; mult_b[3] = Image_padding_1[12]; mult_b[4] = Image_padding_1[13]; mult_b[5] = Image_padding_1[14]; mult_b[6] = Image_padding_1[20]; mult_b[7] = Image_padding_1[21]; mult_b[8] = Image_padding_1[22]; end
        50: begin mult_b[0] = Image_padding_1[5]; mult_b[1] = Image_padding_1[6]; mult_b[2] = Image_padding_1[7]; mult_b[3] = Image_padding_1[13]; mult_b[4] = Image_padding_1[14]; mult_b[5] = Image_padding_1[15]; mult_b[6] = Image_padding_1[21]; mult_b[7] = Image_padding_1[22]; mult_b[8] = Image_padding_1[23]; end
        51: begin mult_b[0] = Image_padding_1[8]; mult_b[1] = Image_padding_1[9]; mult_b[2] = Image_padding_1[10]; mult_b[3] = Image_padding_1[16]; mult_b[4] = Image_padding_1[17]; mult_b[5] = Image_padding_1[18]; mult_b[6] = Image_padding_1[24]; mult_b[7] = Image_padding_1[25]; mult_b[8] = Image_padding_1[26]; end
        52: begin mult_b[0] = Image_padding_1[9]; mult_b[1] = Image_padding_1[10]; mult_b[2] = Image_padding_1[11]; mult_b[3] = Image_padding_1[17]; mult_b[4] = Image_padding_1[18]; mult_b[5] = Image_padding_1[19]; mult_b[6] = Image_padding_1[25]; mult_b[7] = Image_padding_1[26]; mult_b[8] = Image_padding_1[27]; end
        53: begin mult_b[0] = Image_padding_1[10]; mult_b[1] = Image_padding_1[11]; mult_b[2] = Image_padding_1[12]; mult_b[3] = Image_padding_1[18]; mult_b[4] = Image_padding_1[19]; mult_b[5] = Image_padding_1[20]; mult_b[6] = Image_padding_1[26]; mult_b[7] = Image_padding_1[27]; mult_b[8] = Image_padding_1[28]; end
        54: begin mult_b[0] = Image_padding_1[11]; mult_b[1] = Image_padding_1[12]; mult_b[2] = Image_padding_1[13]; mult_b[3] = Image_padding_1[19]; mult_b[4] = Image_padding_1[20]; mult_b[5] = Image_padding_1[21]; mult_b[6] = Image_padding_1[27]; mult_b[7] = Image_padding_1[28]; mult_b[8] = Image_padding_1[29]; end
        55: begin mult_b[0] = Image_padding_1[12]; mult_b[1] = Image_padding_1[13]; mult_b[2] = Image_padding_1[14]; mult_b[3] = Image_padding_1[20]; mult_b[4] = Image_padding_1[21]; mult_b[5] = Image_padding_1[22]; mult_b[6] = Image_padding_1[28]; mult_b[7] = Image_padding_1[29]; mult_b[8] = Image_padding_1[30]; end
        56: begin mult_b[0] = Image_padding_1[13]; mult_b[1] = Image_padding_1[14]; mult_b[2] = Image_padding_1[15]; mult_b[3] = Image_padding_1[21]; mult_b[4] = Image_padding_1[22]; mult_b[5] = Image_padding_1[23]; mult_b[6] = Image_padding_1[29]; mult_b[7] = Image_padding_1[30]; mult_b[8] = Image_padding_1[31]; end
        57: begin mult_b[0] = Image_padding_1[16]; mult_b[1] = Image_padding_1[17]; mult_b[2] = Image_padding_1[18]; mult_b[3] = Image_padding_1[24]; mult_b[4] = Image_padding_1[25]; mult_b[5] = Image_padding_1[26]; mult_b[6] = Image_padding_1[32]; mult_b[7] = Image_padding_1[33]; mult_b[8] = Image_padding_1[34]; end
        58: begin mult_b[0] = Image_padding_1[17]; mult_b[1] = Image_padding_1[18]; mult_b[2] = Image_padding_1[19]; mult_b[3] = Image_padding_1[25]; mult_b[4] = Image_padding_1[26]; mult_b[5] = Image_padding_1[27]; mult_b[6] = Image_padding_1[33]; mult_b[7] = Image_padding_1[34]; mult_b[8] = Image_padding_1[35]; end
        59: begin mult_b[0] = Image_padding_1[18]; mult_b[1] = Image_padding_1[19]; mult_b[2] = Image_padding_1[20]; mult_b[3] = Image_padding_1[26]; mult_b[4] = Image_padding_1[27]; mult_b[5] = Image_padding_1[28]; mult_b[6] = Image_padding_1[34]; mult_b[7] = Image_padding_1[35]; mult_b[8] = Image_padding_1[36]; end
        60: begin mult_b[0] = Image_padding_1[19]; mult_b[1] = Image_padding_1[20]; mult_b[2] = Image_padding_1[21]; mult_b[3] = Image_padding_1[27]; mult_b[4] = Image_padding_1[28]; mult_b[5] = Image_padding_1[29]; mult_b[6] = Image_padding_1[35]; mult_b[7] = Image_padding_1[36]; mult_b[8] = Image_padding_1[37]; end
        61: begin mult_b[0] = Image_padding_1[20]; mult_b[1] = Image_padding_1[21]; mult_b[2] = Image_padding_1[22]; mult_b[3] = Image_padding_1[28]; mult_b[4] = Image_padding_1[29]; mult_b[5] = Image_padding_1[30]; mult_b[6] = Image_padding_1[36]; mult_b[7] = Image_padding_1[37]; mult_b[8] = Image_padding_1[38]; end
        62: begin mult_b[0] = Image_padding_1[21]; mult_b[1] = Image_padding_1[22]; mult_b[2] = Image_padding_1[23]; mult_b[3] = Image_padding_1[29]; mult_b[4] = Image_padding_1[30]; mult_b[5] = Image_padding_1[31]; mult_b[6] = Image_padding_1[37]; mult_b[7] = Image_padding_1[38]; mult_b[8] = Image_padding_1[39]; end
        63: begin mult_b[0] = Image_padding_1[24]; mult_b[1] = Image_padding_1[25]; mult_b[2] = Image_padding_1[26]; mult_b[3] = Image_padding_1[32]; mult_b[4] = Image_padding_1[33]; mult_b[5] = Image_padding_1[34]; mult_b[6] = Image_padding_1[40]; mult_b[7] = Image_padding_1[41]; mult_b[8] = Image_padding_1[42]; end
        64: begin mult_b[0] = Image_padding_1[25]; mult_b[1] = Image_padding_1[26]; mult_b[2] = Image_padding_1[27]; mult_b[3] = Image_padding_1[33]; mult_b[4] = Image_padding_1[34]; mult_b[5] = Image_padding_1[35]; mult_b[6] = Image_padding_1[41]; mult_b[7] = Image_padding_1[42]; mult_b[8] = Image_padding_1[43]; end
        65: begin mult_b[0] = Image_padding_1[26]; mult_b[1] = Image_padding_1[27]; mult_b[2] = Image_padding_1[28]; mult_b[3] = Image_padding_1[34]; mult_b[4] = Image_padding_1[35]; mult_b[5] = Image_padding_1[36]; mult_b[6] = Image_padding_1[42]; mult_b[7] = Image_padding_1[43]; mult_b[8] = Image_padding_1[44]; end
        66: begin mult_b[0] = Image_padding_1[27]; mult_b[1] = Image_padding_1[28]; mult_b[2] = Image_padding_1[29]; mult_b[3] = Image_padding_1[35]; mult_b[4] = Image_padding_1[36]; mult_b[5] = Image_padding_1[37]; mult_b[6] = Image_padding_1[43]; mult_b[7] = Image_padding_1[44]; mult_b[8] = Image_padding_1[45]; end
        67: begin mult_b[0] = Image_padding_1[28]; mult_b[1] = Image_padding_1[29]; mult_b[2] = Image_padding_1[30]; mult_b[3] = Image_padding_1[36]; mult_b[4] = Image_padding_1[37]; mult_b[5] = Image_padding_1[38]; mult_b[6] = Image_padding_1[44]; mult_b[7] = Image_padding_1[45]; mult_b[8] = Image_padding_1[46]; end
        68: begin mult_b[0] = Image_padding_1[29]; mult_b[1] = Image_padding_1[30]; mult_b[2] = Image_padding_1[31]; mult_b[3] = Image_padding_1[37]; mult_b[4] = Image_padding_1[38]; mult_b[5] = Image_padding_1[39]; mult_b[6] = Image_padding_1[45]; mult_b[7] = Image_padding_1[46]; mult_b[8] = Image_padding_1[47]; end
        69: begin mult_b[0] = Image_padding_1[32]; mult_b[1] = Image_padding_1[33]; mult_b[2] = Image_padding_1[34]; mult_b[3] = Image_padding_1[40]; mult_b[4] = Image_padding_1[41]; mult_b[5] = Image_padding_1[42]; mult_b[6] = Image_padding_1[48]; mult_b[7] = Image_padding_1[49]; mult_b[8] = Image_padding_1[50]; end
        70: begin mult_b[0] = Image_padding_1[33]; mult_b[1] = Image_padding_1[34]; mult_b[2] = Image_padding_1[35]; mult_b[3] = Image_padding_1[41]; mult_b[4] = Image_padding_1[42]; mult_b[5] = Image_padding_1[43]; mult_b[6] = Image_padding_1[49]; mult_b[7] = Image_padding_1[50]; mult_b[8] = Image_padding_1[51]; end
        71: begin mult_b[0] = Image_padding_1[34]; mult_b[1] = Image_padding_1[35]; mult_b[2] = Image_padding_1[36]; mult_b[3] = Image_padding_1[42]; mult_b[4] = Image_padding_1[43]; mult_b[5] = Image_padding_1[44]; mult_b[6] = Image_padding_1[50]; mult_b[7] = Image_padding_1[51]; mult_b[8] = Image_padding_1[52]; end
        72: begin mult_b[0] = Image_padding_1[35]; mult_b[1] = Image_padding_1[36]; mult_b[2] = Image_padding_1[37]; mult_b[3] = Image_padding_1[43]; mult_b[4] = Image_padding_1[44]; mult_b[5] = Image_padding_1[45]; mult_b[6] = Image_padding_1[51]; mult_b[7] = Image_padding_1[52]; mult_b[8] = Image_padding_1[53]; end
        73: begin mult_b[0] = Image_padding_1[36]; mult_b[1] = Image_padding_1[37]; mult_b[2] = Image_padding_1[38]; mult_b[3] = Image_padding_1[44]; mult_b[4] = Image_padding_1[45]; mult_b[5] = Image_padding_1[46]; mult_b[6] = Image_padding_1[52]; mult_b[7] = Image_padding_1[53]; mult_b[8] = Image_padding_1[54]; end
        74: begin mult_b[0] = Image_padding_1[37]; mult_b[1] = Image_padding_1[38]; mult_b[2] = Image_padding_1[39]; mult_b[3] = Image_padding_1[45]; mult_b[4] = Image_padding_1[46]; mult_b[5] = Image_padding_1[47]; mult_b[6] = Image_padding_1[53]; mult_b[7] = Image_padding_1[54]; mult_b[8] = Image_padding_1[55]; end
        75: begin mult_b[0] = Image_padding_1[40]; mult_b[1] = Image_padding_1[41]; mult_b[2] = Image_padding_1[42]; mult_b[3] = Image_padding_1[48]; mult_b[4] = Image_padding_1[49]; mult_b[5] = Image_padding_1[50]; mult_b[6] = Image_padding_1[56]; mult_b[7] = Image_padding_1[57]; mult_b[8] = Image_padding_1[58]; end
        76: begin mult_b[0] = Image_padding_1[41]; mult_b[1] = Image_padding_1[42]; mult_b[2] = Image_padding_1[43]; mult_b[3] = Image_padding_1[49]; mult_b[4] = Image_padding_1[50]; mult_b[5] = Image_padding_1[51]; mult_b[6] = Image_padding_1[57]; mult_b[7] = Image_padding_1[58]; mult_b[8] = Image_padding_1[59]; end
        77: begin mult_b[0] = Image_padding_1[42]; mult_b[1] = Image_padding_1[43]; mult_b[2] = Image_padding_1[44]; mult_b[3] = Image_padding_1[50]; mult_b[4] = Image_padding_1[51]; mult_b[5] = Image_padding_1[52]; mult_b[6] = Image_padding_1[58]; mult_b[7] = Image_padding_1[59]; mult_b[8] = Image_padding_1[60]; end
        78: begin mult_b[0] = Image_padding_1[43]; mult_b[1] = Image_padding_1[44]; mult_b[2] = Image_padding_1[45]; mult_b[3] = Image_padding_1[51]; mult_b[4] = Image_padding_1[52]; mult_b[5] = Image_padding_1[53]; mult_b[6] = Image_padding_1[59]; mult_b[7] = Image_padding_1[60]; mult_b[8] = Image_padding_1[61]; end
        79: begin mult_b[0] = Image_padding_1[44]; mult_b[1] = Image_padding_1[45]; mult_b[2] = Image_padding_1[46]; mult_b[3] = Image_padding_1[52]; mult_b[4] = Image_padding_1[53]; mult_b[5] = Image_padding_1[54]; mult_b[6] = Image_padding_1[60]; mult_b[7] = Image_padding_1[61]; mult_b[8] = Image_padding_1[62]; end
        80: begin mult_b[0] = Image_padding_1[45]; mult_b[1] = Image_padding_1[46]; mult_b[2] = Image_padding_1[47]; mult_b[3] = Image_padding_1[53]; mult_b[4] = Image_padding_1[54]; mult_b[5] = Image_padding_1[55]; mult_b[6] = Image_padding_1[61]; mult_b[7] = Image_padding_1[62]; mult_b[8] = Image_padding_1[63]; end
// ----------------- Fully connect 1 -----------------
// reg [inst_sig_width+inst_exp_width:0] weight_1_row_0 [0:5], 
//                                       weight_1_row_1 [0:5], 
//                                       weight_1_row_2 [0:5], 
//                                       weight_1_row_3 [0:5], 
//                                       weight_1_row_4 [0:5], 
//                                       weight_1_row_5 [0:5], 
//                                       weight_1_row_6 [0:5], 
//                                       weight_1_row_7 [0:5];
        83: begin for (i = 0; i < 5; i = i + 1) mult_b[i] = weight_1_row_0[i]; end
        84: begin for (i = 0; i < 5; i = i + 1) mult_b[i] = weight_1_row_4[i]; end
        85: begin for (i = 0; i < 5; i = i + 1) mult_b[i] = weight_1_row_1[i]; end
        86: begin for (i = 0; i < 5; i = i + 1) mult_b[i] = weight_1_row_5[i]; end
        87: begin for (i = 0; i < 5; i = i + 1) mult_b[i] = weight_1_row_2[i]; end
        88: begin for (i = 0; i < 5; i = i + 1) mult_b[i] = weight_1_row_6[i]; end
        89: begin for (i = 0; i < 5; i = i + 1) mult_b[i] = weight_1_row_3[i]; end
        90: begin for (i = 0; i < 5; i = i + 1) mult_b[i] = weight_1_row_7[i]; end
// ----------------- Leaky ReLU -----------------
        92: begin for (i = 0; i < 5; i = i + 1) mult_b[i] = act_2_reg[i]; end
// ----------------- Fully connect 2 -----------------
        93: begin for (i = 0; i < 5; i = i + 1) mult_b[i] = weight_2_1[i]; end
        94: begin for (i = 0; i < 5; i = i + 1) mult_b[i] = weight_2_2[i]; end
        95: begin for (i = 0; i < 5; i = i + 1) mult_b[i] = weight_2_3[i]; end
    endcase
    if (cnt_clk >= 9 && cnt_clk <= 80) mult_b[9:17] = mult_b[0:8];
end

// reg [inst_sig_width+inst_exp_width:0] mult_result [0:17];
always @(posedge clk) begin
    integer i;
    for (i = 0; i < 18; i = i + 1) begin
        mult_result[i] <= mult_z[i];
    end
end

// generate
//     for (k = 0; k < 8; k = k + 1) begin: sum3_instances
//         DW_fp_sum3 #(inst_sig_width, inst_exp_width, inst_ieee_compliance, inst_arch_type) 
//             sum3 (.a(sum3_a[k]), .b(sum3_b[k]), .c(sum3_c[k]), .rnd(3'b0), .z(sum3_z[k]), .status() );
//     end
// endgenerate

// reg [inst_sig_width+inst_exp_width:0] sum3_a[0:7], sum3_b[0:7], sum3_c[0:7], sum3_z[0:7];
always @(*) begin
    integer i;
    for (i = 0; i < 8; i = i + 1) begin
        sum3_a[i] = 32'b0;
        sum3_b[i] = 32'b0;
        sum3_c[i] = 32'b0;
    end
    // ----------------- convolution -----------------
    if (cnt_clk >= 10 && cnt_clk <= 81) begin
        sum3_a[0] = mult_result[0]; sum3_b[0] = mult_result[1]; sum3_c[0] = mult_result[2];
        sum3_a[1] = mult_result[3]; sum3_b[1] = mult_result[4]; sum3_c[1] = mult_result[5];
        sum3_a[2] = mult_result[6]; sum3_b[2] = mult_result[7]; sum3_c[2] = mult_result[8];

        // ch1 block result
        sum3_a[3] = sum3_z[0];
        sum3_b[3] = sum3_z[1];
        sum3_c[3] = sum3_z[2];

        sum3_a[4] = mult_result[9];  sum3_b[4] = mult_result[10]; sum3_c[4] = mult_result[11];
        sum3_a[5] = mult_result[12]; sum3_b[5] = mult_result[13]; sum3_c[5] = mult_result[14];
        sum3_a[6] = mult_result[15]; sum3_b[6] = mult_result[16]; sum3_c[6] = mult_result[17];
        
        // ch2 block result
        sum3_a[7] = sum3_z[4];
        sum3_b[7] = sum3_z[5];
        sum3_c[7] = sum3_z[6];
    end
    // task 0
    if (!task_reg) begin
        // ----------------- Fully connect 2 -----------------
        if (cnt_clk >= 94 && cnt_clk <= 96) begin
            sum3_a[3] = mult_result[0];
            sum3_b[3] = mult_result[1];
            sum3_c[3] = mult_result[2];
            sum3_a[7] = mult_result[3];
            sum3_b[7] = mult_result[4];
            sum3_c[7] = bias_2;
        end
        // ----------------- softmax -----------------
        else if (cnt_clk >= 98 && cnt_clk <= 100) begin
            sum3_a[3] = ewact2_1;
            sum3_b[3] = ewact2_2;
            sum3_c[3] = ewact2_3;
        end
        else begin
            // ----------------- Activation function -----------------
            if (cnt_clk >= 82 && cnt_clk <= 89) begin
                sum3_a[0] = e_max_reg[act_idx];
                sum3_b[0] = IEEE_NEG_ONE;

                sum3_a[1] = e_max_reg[act_idx];
                sum3_b[1] = IEEE_ONE;
            end
            // ----------------- Fully connect 1 -----------------
            if (cnt_clk >= 84 && cnt_clk <= 91) begin
                sum3_a[2] = act_2_reg[0];
                sum3_b[2] = mult_result[0];
                
                sum3_a[3] = act_2_reg[1];
                sum3_b[3] = mult_result[1];
                
                sum3_a[4] = act_2_reg[2];
                sum3_b[4] = mult_result[2];
                
                sum3_a[5] = act_2_reg[3];
                sum3_b[5] = mult_result[3];
                
                sum3_a[6] = act_2_reg[4];
                sum3_b[6] = mult_result[4];
            end
        end
    end
    // task 1
    // ----------------- select -----------------
    else if (cnt_clk >= 83 && cnt_clk <= 97) begin
        sum3_a[3] = add_z[0];
        sum3_b[3] = add_z[1];
    end
end

// reg [inst_sig_width+inst_exp_width:0] out_1_reg [0:35], out_2_reg [0:35];
always @(posedge clk) begin
    out_1_reg <= out_1;
    out_2_reg <= out_2;
end

// reg [inst_sig_width+inst_exp_width:0] out_1 [0:35], out_2 [0:35];
always @(*) begin
    out_1 = out_1_reg;
    out_2 = out_2_reg;
    // if (cnt_clk >= 10 && cnt_clk <= 45) begin
    if (cnt_clk >= 10 && cnt_clk <= 81) begin
        out_1[cnt_clk-10] = sum3_z[3];
        out_2[cnt_clk-10] = sum3_z[7];
    end
end

// reg [inst_sig_width+inst_exp_width:0] block_sum_tmp [0:1];      // for adding to origenal out_1 & out_2 & some other work
always @(posedge clk) begin
    block_sum_tmp[0] <= sum3_z[3];
    block_sum_tmp[1] <= sum3_z[7];
end

// // add * 2
// generate
//     for (k = 0; k < 2; k = k + 1) begin: add_instances
//         DW_fp_add #(inst_sig_width, inst_exp_width, inst_ieee_compliance) 
//             add (.a(add_a[k]), .b(add_b[k]), .rnd(3'b0), .z(add_z[k]), .status() );
//     end
// endgenerate

// reg [inst_sig_width+inst_exp_width:0] add_a[0:1]
always @(*) begin
    add_a[0] = 32'b0;
    add_a[1] = 32'b0;
    // task 0
    if (!task_reg) begin
        if (cnt_clk >= 47 && cnt_clk <= 82) begin
            add_a[0] = out_1_reg[cnt_clk-47];
            add_a[1] = out_2_reg[cnt_clk-47];
        end
        else if (cnt_clk >= 95 && cnt_clk <= 97) begin
            add_a[0] = block_sum_tmp[0];
        end
    end
    // task 1
    else begin
        // ----------------- sum -----------------
        if (cnt_clk >= 11 && cnt_clk <= 46) begin
            add_a[0] = conv_sum_a;
            add_a[1] = conv_sum_c;
        end
        else if (cnt_clk >= 47 && cnt_clk <= 82) begin
            add_a[0] = conv_sum_b;
            add_a[1] = conv_sum_d;
        end
        // ----------------- select -----------------
        else if (cnt_clk >= 83 && cnt_clk <= 97) begin
            if (current_select_mask[3]) add_a[0] = conv_sum_a;
            if (current_select_mask[2]) add_a[1] = conv_sum_b;
        end
    end
end

// reg [inst_sig_width+inst_exp_width:0] add_b[0:1]
always @(*) begin
    add_b[0] = 32'b0;
    add_b[1] = 32'b0;
    // task 0
    if (!task_reg) begin
        if (cnt_clk >= 47 && cnt_clk <= 82) begin
            add_b[0] = block_sum_tmp[0];
            add_b[1] = block_sum_tmp[1];
        end
        else if (cnt_clk >= 95 && cnt_clk <= 97) begin
            add_b[0] = block_sum_tmp[1];
        end
    end
    // task 1
    else begin
        // ----------------- sum -----------------
        if (cnt_clk >= 11 && cnt_clk <= 82) begin
            add_b[0] = block_sum_tmp[0];
            add_b[1] = block_sum_tmp[1];
        end
        // ----------------- select -----------------
        else if (cnt_clk >= 83 && cnt_clk <= 97) begin
            if (current_select_mask[1]) add_b[0] = conv_sum_c;
            if (current_select_mask[0]) add_b[1] = conv_sum_d;
        end
    end
end

reg [3:0] prev_select_mask;

// reg [3:0] prev_select_mask;
always @(posedge clk) begin
    prev_select_mask <= current_select_mask;
end

// reg [3:0] current_select_mask;
always @(posedge clk) begin
    if (cnt_clk == 1) current_select_mask <= 4'd15;
    else if (cnt_clk >= 83 && cnt_clk <= 97) current_select_mask <= current_select_mask - 4'd1;
    else current_select_mask <= current_select_mask;
end

// ----------------- task 1 sum -----------------

// reg [inst_sig_width+inst_exp_width:0] conv_sum_a, conv_sum_c
always @(posedge clk) begin
    integer i;
    if (cnt_clk == 1) begin
        conv_sum_a <= 32'b0;
        conv_sum_c <= 32'b0;
    end
    else if (cnt_clk >= 11 && cnt_clk <= 46) begin
        conv_sum_a <= add_z[0];
        conv_sum_c <= add_z[1];
    end
    else begin
        conv_sum_a <= conv_sum_a;
        conv_sum_c <= conv_sum_c;
    end
end

// reg [inst_sig_width+inst_exp_width:0] conv_sum_b, conv_sum_d;
always @(posedge clk) begin
    integer i;
    if (cnt_clk == 1) begin
        conv_sum_b <= 32'b0;
        conv_sum_d <= 32'b0;
    end
    else if (cnt_clk >= 47 && cnt_clk <= 82) begin
        conv_sum_b <= add_z[0];
        conv_sum_d <= add_z[1];
    end
    else begin
        conv_sum_b <= conv_sum_b;
        conv_sum_d <= conv_sum_d;
    end
end

// ----------------- task 1 select -----------------

// wire [3:0] select_test_case [1:15];
// assign select_test_case[15] = 4'b1111;

// assign select_test_case[14] = 4'b1110;
// assign select_test_case[13] = 4'b1101;
// assign select_test_case[12] = 4'b1011;
// assign select_test_case[11] = 4'b0111;

// assign select_test_case[10] = 4'b1100;
// assign select_test_case[9]  = 4'b1010;
// assign select_test_case[8]  = 4'b0110;
// assign select_test_case[7]  = 4'b1001;
// assign select_test_case[6]  = 4'b0101;
// assign select_test_case[5]  = 4'b0011;

// assign select_test_case[4] = 4'b1000;
// assign select_test_case[3] = 4'b0100;
// assign select_test_case[2] = 4'b0010;
// assign select_test_case[1] = 4'b0001;

// reg [inst_sig_width+inst_exp_width:0] select_sum;
// always @(posedge clk) begin
//     select_sum <= sum3_z[0];
// end
always @(*) begin
    select_sum = block_sum_tmp[0];
end

// reg [inst_sig_width+inst_exp_width:0] max_select_sum;
always @(posedge clk) begin
    // if (cnt_clk == 1) max_select_sum <= 32'h80000002;   // min abs value in neg
    if (cnt_clk == 1) max_select_sum <= 32'd0;
    else if (cnt_clk >= 84 && cnt_clk <= 97 && cmp_agtb[0] && prev_is_in_cap) max_select_sum <= select_sum;   // 98 ---> output
    else max_select_sum <= max_select_sum;
end

// reg [3:0] select_case;
always @(posedge clk) begin
    if (cnt_clk == 1) select_case <= 4'b0;
    else if (cnt_clk >= 84 && cnt_clk <= 97 && cmp_agtb[0] && prev_is_in_cap) select_case <= prev_select_mask;   // 98 ---> output
    else select_case <= select_case;
end

// wire [3:0] cost_is_zero;

// assign cost_is_zero[3] = cap_reg[1] == 4'd0;    // a
// assign cost_is_zero[2] = cap_reg[2] == 4'd0;    // b
// assign cost_is_zero[1] = cap_reg[3] == 4'd0;    // c
// assign cost_is_zero[0] = cap_reg[4] == 4'd0;    // d

wire [3:0] a_or_not, b_or_not, c_or_not, d_or_not;

wire [5:0] cost_sum;

assign a_or_not = current_select_mask[3] ? cap_reg[1] : 0;
assign b_or_not = current_select_mask[2] ? cap_reg[2] : 0;
assign c_or_not = current_select_mask[1] ? cap_reg[3] : 0;
assign d_or_not = current_select_mask[0] ? cap_reg[4] : 0;

assign cost_sum = (a_or_not + b_or_not) + (c_or_not + d_or_not);

// reg prev_is_in_cap;
always @(posedge clk) begin
    prev_is_in_cap <= is_in_cap;
end

// wire is_in_cap;
assign is_in_cap = (cap_reg[0] >= cost_sum);

// assign is_in_cap = ({2'b0, cap_reg[0]} >= ((select_test_case[current_select_mask][3] ? {2'b0, cap_reg[1]} : 6'd0) +   // a
//                                            (select_test_case[current_select_mask][2] ? {2'b0, cap_reg[2]} : 6'd0) +   // b
//                                            (select_test_case[current_select_mask][1] ? {2'b0, cap_reg[3]} : 6'd0) +   // c
//                                            (select_test_case[current_select_mask][0] ? {2'b0, cap_reg[4]} : 6'd0)));  // d

// ----------------- Max pooling -----------------

// generate
//     for (k = 0; k < 2; k = k + 1) begin: cmp_instances
//         DW_fp_cmp #(inst_sig_width, inst_exp_width, inst_ieee_compliance)
//             cmp (.a(cmp_a[k]), .b(cmp_b[k]), .agtb(cmp_agtb[k]) );
//     end
// endgenerate

// reg [2:0] cmp_idx_0, cmp_idx_1;
always @(posedge clk) begin
    cmp_idx_0 <= next_cmp_idx_0;
    cmp_idx_1 <= next_cmp_idx_1;
end

// reg [2:0] next_cmp_idx_0, next_cmp_idx_1;
always @(*) begin
    next_cmp_idx_0 = cmp_idx_0;
    next_cmp_idx_1 = cmp_idx_1;
    case (cnt_clk + 1)
        47, 48, 49, 53, 54, 55, 59, 60, 61: begin next_cmp_idx_0 = 3'd0; next_cmp_idx_1 = 3'd4;end
        50, 51, 52, 56, 57, 58, 62, 63, 64: begin next_cmp_idx_0 = 3'd1; next_cmp_idx_1 = 3'd5;end
        65, 66, 67, 71, 72, 73, 77, 78, 79: begin next_cmp_idx_0 = 3'd2; next_cmp_idx_1 = 3'd6;end
        68, 69, 70, 74, 75, 76, 80, 81, 82: begin next_cmp_idx_0 = 3'd3; next_cmp_idx_1 = 3'd7;end
    endcase
end

// reg cmp_agtb[0:1];

// reg [inst_sig_width+inst_exp_width:0] cmp_a[0:1];        // original max[i]
always @(*) begin
    cmp_a[0] = 32'b0;
    cmp_a[1] = 32'b0;
    if (!task_reg) begin
        cmp_a[0] = add_z[0];
        cmp_a[1] = add_z[1];
    end
    else begin
        cmp_a[0] = select_sum;
    end
end

// reg [inst_sig_width+inst_exp_width:0] cmp_b[0:1];
always @(*) begin
    cmp_b[0] = 32'b0;
    cmp_b[1] = 32'b0;
    if (!task_reg) begin
        cmp_b[0] = max_reg[cmp_idx_0];
        cmp_b[1] = max_reg[cmp_idx_1];
    end
    else begin
        cmp_b[0] = max_select_sum;
    end
end

// reg [inst_sig_width+inst_exp_width:0] max_reg [0:7];
always @(posedge clk) begin
    max_reg <= max;
end

// reg [inst_sig_width+inst_exp_width:0] max [0:7];
always @(*) begin
    integer i;
    max = max_reg;
    if (cnt_clk == 1) begin
        for (i = 0; i < 8; i = i + 1) max[i] = IEEE_neg_5;
    end
    else if (cnt_clk >= 47 && cnt_clk <= 82) begin
        if (cmp_agtb[0]) max[cmp_idx_0] = cmp_a[0];
        if (cmp_agtb[1]) max[cmp_idx_1] = cmp_a[1];
    end
end

// ----------------- Activation function -----------------

wire [inst_sig_width+inst_exp_width:0] real_max [0:7];      // for activation function

// 1 = - max, 0 = 2 * max
// wire [inst_sig_width+inst_exp_width:0] real_max [0:7];      // for activation function
generate
    for (k = 0; k < 8; k = k + 1) begin : real_max_select
        assign real_max[k] = mode_reg[0] ? {~max_reg[k][31], max_reg[k][30:0]} : {max_reg[k][31], max_reg[k][30:23] + 8'd1, max_reg[k][22:0]};
    end
endgenerate


// // exp
// DW_fp_exp #(inst_sig_width, inst_exp_width, inst_ieee_compliance, inst_arch)
//     exp ( .a(exp_a), .z(exp_z), .status() );

// reg [inst_sig_width+inst_exp_width:0] exp_a, exp_z;

always @(*) begin
    exp_a = 32'b0;
    case (cnt_clk)
        // ----------------- Activation function -----------------
        77: exp_a = real_max[0];
        78: exp_a = real_max[4];
        79: exp_a = real_max[1];
        80: exp_a = real_max[5];
        81: exp_a = real_max[2];
        82: exp_a = real_max[6];
        83: exp_a = real_max[3];
        84: exp_a = real_max[7];
        // ----------------- softmax -----------------
        95: exp_a = add_z[0];
        96: exp_a = add_z[0];
        97: exp_a = add_z[0];
    endcase
end

// reg [inst_sig_width+inst_exp_width:0] e_max_reg [0:7];
always @(posedge clk) begin
    e_max_reg <= e_max;
end

// reg [inst_sig_width+inst_exp_width:0] e_max [0:7];
always @(*) begin
    e_max = e_max_reg;
    case (cnt_clk)
        77: e_max[0] = exp_z;
        78: e_max[4] = exp_z;
        79: e_max[1] = exp_z;
        80: e_max[5] = exp_z;
        81: e_max[2] = exp_z;
        82: e_max[6] = exp_z;
        83: e_max[3] = exp_z;
        84: e_max[7] = exp_z;
    endcase
end

// // div
// DW_fp_div #(inst_sig_width, inst_exp_width, inst_ieee_compliance, inst_faithful_round, 0)
//     div ( .a(div_a), .b(div_b), .rnd(3'b0), .z(div_z), .status() );

// reg [inst_sig_width+inst_exp_width:0] div_a;
always @(*) begin
    div_a = 32'b0;
    // ----------------- Activation function -----------------
    if (cnt_clk >= 82 && cnt_clk <= 89) begin
        div_a = mode_reg[0] ? max_reg[act_idx] : sum3_z[0];
    end
    // ----------------- softmax -----------------
    else begin
        case (cnt_clk)
            99:  div_a = ewact2_1;
            100: div_a = ewact2_2;
            101: div_a = ewact2_3;
        endcase
    end
end

// reg [inst_sig_width+inst_exp_width:0] div_b;
always @(*) begin
    div_b = 32'b0;
    // ----------------- Activation function -----------------
    if (cnt_clk >= 82 && cnt_clk <= 89) begin
        div_b = sum3_z[1];
    end
    // ----------------- softmax -----------------
    else if (cnt_clk >= 99 && cnt_clk <= 101) begin
        div_b = block_sum_tmp[0];
    end
end

// reg [2:0] prev_act_idx;      // for FC 1
always @(posedge clk) begin
    prev_act_idx <= act_idx;
end

// reg [2:0] act_idx;           // for activation function
always @(posedge clk) begin
    act_idx <= next_act_idx;
end

// reg [2:0] next_act_idx;
always @(*) begin
    next_act_idx = act_idx;
    case (cnt_clk + 1)
        82: next_act_idx = 3'd0;
        83: next_act_idx = 3'd4;
        84: next_act_idx = 3'd1;
        85: next_act_idx = 3'd5;
        86: next_act_idx = 3'd2;
        87: next_act_idx = 3'd6;
        88: next_act_idx = 3'd3;
        89: next_act_idx = 3'd7;
    endcase
end

// ----------------- Fully connect 1 -----------------

// reg [inst_sig_width+inst_exp_width:0] act_1_reg [0:7];
always @(posedge clk) begin
    act_1_reg <= act_1;
end

// reg [inst_sig_width+inst_exp_width:0] act_1 [0:7];
always @(*) begin
    act_1 = act_1_reg;
    if (cnt_clk >= 82 && cnt_clk <= 89) act_1[act_idx] = div_z;
end

// reg [inst_sig_width+inst_exp_width:0] act_2_reg [0:4];
always @(posedge clk) begin
    act_2_reg <= act_2;
end

// reg [inst_sig_width+inst_exp_width:0] act_2 [0:4];
always @(*) begin
    integer i;
    act_2 = act_2_reg;
    if (cnt_clk == 41) begin
        for (i = 0; i < 5; i = i + 1) act_2[i] = bias_1;
    end
    // ----------------- Fully connect 1 -----------------
    else if (cnt_clk >= 84 && cnt_clk <= 91) begin
        act_2[0] = sum3_z[2];
        act_2[1] = sum3_z[3];
        act_2[2] = sum3_z[4];
        act_2[3] = sum3_z[5];
        act_2[4] = sum3_z[6];
    end
    // ----------------- Leaky ReLU -----------------
    else if (cnt_clk == 92) begin
        if (act_2_reg[0][31]) act_2[0] = mult_z[0];
        if (act_2_reg[1][31]) act_2[1] = mult_z[1];
        if (act_2_reg[2][31]) act_2[2] = mult_z[2];
        if (act_2_reg[3][31]) act_2[3] = mult_z[3];
        if (act_2_reg[4][31]) act_2[4] = mult_z[4];
    end
end

// ----------------- softmax -----------------

// reg [inst_sig_width+inst_exp_width:0] ewact2_1, ewact2_2, ewact2_3;
always @(posedge clk) begin
    ewact2_1 <= (cnt_clk == 95) ? exp_z : ewact2_1;
    ewact2_2 <= (cnt_clk == 96) ? exp_z : ewact2_2;
    ewact2_3 <= (cnt_clk == 97) ? exp_z : ewact2_3;
end

// ----------------- output -----------------

// output  reg [31:0]  out;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) out <= 32'b0;
    else if (!task_reg && cnt_clk >= 99 && cnt_clk <= 101) out <= div_z;
    else if (task_reg && cnt_clk == 98) out <= (cmp_agtb[0] && prev_is_in_cap) ? 
                                        // {28'b0, current_select_mask} : 
                                        32'b1 : 
                                        {28'b0, select_case};
                                        // {28'b0, (select_case | cost_is_zero)};
    else out <= 32'b0;
end

// output  reg         out_valid;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) out_valid <= 1'b0;
    else if (!task_reg && cnt_clk >= 99 && cnt_clk <= 101) out_valid <= 1'b1;
    else if (task_reg && cnt_clk == 98) out_valid <= 1'b1;
    else out_valid <= 1'b0;
end

endmodule

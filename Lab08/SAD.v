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
//   File Name   : SAD.v
//   Module Name : SAD
//   Release version : v1.0
//   Note : Design w/ CG
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

// synopsys translate_off
`ifdef RTL
	`include "GATED_OR.v"
`else
	`include "Netlist/GATED_OR_SYN.v"
`endif
// synopsys translate_on

module SAD(
    //Input signals
    clk,
    rst_n,
    cg_en,
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
input cg_en;
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


reg [8:0] cnt_clk, next_cnt_clk;  // 0 ~ 307 (9 bits)
reg [6:0] handle_cycles_t8;   // 1*8 or 4*8 or 8*8 = 8 ~ 64
reg [6:0] handle_cycles_tt;   // 1*1 or 4*4 or 8*8 = 1 ~ 64
reg [8:0] QK_start_cycle;
reg [8:0] SV_start_cycle;
reg [8:0] out_start_cycle;
reg [8:0] end_cycle;     // max = 307 ??

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
reg  is_det_d1, is_det_d2, is_det_d3;

reg signed [20:0] det_tmp;   // 21-bit
reg signed [24:0] det_result;

// ----------------- matrix multiply -----------------
reg [7:0] mult_cnt_small;   // 0~191
reg [7:0] mult_cnt_small_d1;
wire is_multiplying;
wire Q_mult, K_mult, V_mult;
reg  Q_mult_d1, K_mult_d1, V_mult_d1;

wire signed [7:0] w_Q_transpose [0:63];
wire signed [7:0] w_K_transpose [0:63];
wire signed [7:0] w_V_transpose [0:63];

wire is_QK;
reg [5:0] mult_cnt_QK, mult_cnt_QK_d1, mult_cnt_QK_d2, mult_cnt_QK_d3;

reg signed [37:0] A_tmp;     // 38-bit
wire signed [36:0] A_pos;     // 37-bit

reg [36:0] div_a;   // 37-bit, all positive, unsigned
reg [35:0] div_z;   // 36-bit

reg signed [36:0] S_reg [0:63];

wire is_SV;
reg is_SV_d1;
reg [7:0] mult_cnt_SV, mult_cnt_SV_d1;   // 0~191

reg signed [18:0] V_transpose [0:63];

// ----------------- mult -----------------
reg signed [7:0]  mult_s_a [0:7];
reg signed [7:0]  mult_s_b [0:7];
reg signed [15:0] mult_s_z [0:7];

reg signed [18:0] mult_b_a [0:7];
reg signed [36:0] mult_b_b [0:7];
reg signed [53:0] mult_b_z [0:7];

reg signed [24:0] mult_f_a;
reg signed [53:0] mult_f_b;
// reg signed [91:0] mult_f_z;
reg signed [77:0] mult_f_z;

reg signed [18:0] Q_reg [0:63], K_reg [0:63], V_reg [0:63];     // 19-bit

//==============================================//
//                 GATED_OR                     //
//==============================================//



//==============================================//
//                  design                      //
//==============================================//


// reg [8:0] cnt_clk;  // 0 ~ 307 (9 bits)
always @(posedge clk or negedge rst_n) begin
	if (!rst_n) cnt_clk <= 7'b0;
	else cnt_clk <= next_cnt_clk;
end

// reg [8:0] next_cnt_clk;  // 0 ~ 307 (9 bits)
always @(*) begin
    next_cnt_clk = cnt_clk;
    if      (cnt_clk == end_cycle)       next_cnt_clk = 9'b0;
    else if (cnt_clk > 9'b0 || in_valid) next_cnt_clk = cnt_clk + 9'd1;
end

// ----------------- input -----------------

// wire in_data1_valid, in_data2_valid, Q_valid, K_valid, V_valid;
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

// reg [6:0] handle_cycles_t8;   // 1*8 or 4*8 or 8*8 = 8 ~ 64
always @(*) begin
    case (T_reg)
        1:       handle_cycles_t8 = 7'd8;
        4:       handle_cycles_t8 = 7'd32;
        default: handle_cycles_t8 = 7'd64;
    endcase
end
// reg [6:0] handle_cycles_tt;   // 1*1 or 4*4 or 8*8 = 1 ~ 64
always @(*) begin
    case (T_reg)
        1:       handle_cycles_tt = 7'd1;
        4:       handle_cycles_tt = 7'd32;
        default: handle_cycles_tt = 7'd64;
    endcase
end

// reg [8:0] QK_start_cycle;
always @(*) begin
    case (T_reg)
        1:       QK_start_cycle = 9'd190;
        4:       QK_start_cycle = 9'd179;
        default: QK_start_cycle = 9'd179;
    endcase
end

// reg [8:0] SV_start_cycle;
always @(*) begin
    case (T_reg)
        1:       SV_start_cycle = 9'd194;
        4:       SV_start_cycle = 9'd211;
        default: SV_start_cycle = 9'd243;
    endcase
end

// reg [8:0] out_start_cycle;
always @(*) begin
    case (T_reg)
        1:       out_start_cycle = 9'd196;
        4:       out_start_cycle = 9'd213;
        default: out_start_cycle = 9'd245;
    endcase
end

// reg [8:0] end_cycle;     // max = 307 ??
always @(*) begin
    case (T_reg)
        1:       end_cycle = 9'd204;
        4:       end_cycle = 9'd245;
        default: end_cycle = 9'd309;
    endcase
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
    if      (!rst_n)               for (i = 0; i < 64; i  = i + 1) in_data2_reg[i] <= 8'd0;
    else if (in_data2_valid)       in_data2_reg[cnt_clk] <= in_data2;
    else if (cnt_clk == end_cycle) for (i = 8; i < 64; i  = i + 1) in_data2_reg[i] <= 8'd0;
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

// reg is_det_d1, is_det_d2, is_det_d3;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        is_det_d1 <= 1'b0;
        is_det_d2 <= 1'b0;
        is_det_d3 <= 1'b0;
    end
    else begin
        is_det_d1 <= is_det;
        is_det_d2 <= is_det_d1;
        is_det_d3 <= is_det_d2;
    end
end


// + a0 a5 a10 a15
// - a1 a6 a11 a12
// + a2 a7 a8  a13
// - a3 a4 a9  a14

// + a0 a6 a11 a13
// - a1 a7 a8  a14
// + a2 a4 a9  a15
// - a3 a5 a10 a12

// + a0 a7 a9  a14
// - a1 a4 a10 a15
// + a2 a5 a11 a12
// - a3 a6 a8  a13

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


// reg signed [7:0] mult_s_a[0:7], mult_s_b[0:7]
always @(posedge clk or negedge rst_n) begin
    integer i;
    if (!rst_n) begin
        for (i = 0; i < 8; i = i + 1) begin
            mult_s_a[i] <= 8'd0;
            mult_s_b[i] <= 8'd0;
        end
    end
    else if (is_det) begin
        case (det_cnt[3:2])
            // 2'd0: begin
            //     // +
            //     mult_s_a[0] <= {{2{in_data1_reg[0][5]}},  in_data1_reg[0]};
            //     mult_s_b[0] <= {{2{in_data1_reg[5][5]}},  in_data1_reg[5]};
            //     mult_s_a[1] <= {{2{in_data1_reg[10][5]}}, in_data1_reg[10]};
            //     mult_s_b[1] <= {{2{in_data1_reg[15][5]}}, in_data1_reg[15]};
            //     // -
            //     mult_s_a[2] <= {{2{in_data1_reg[0][5]}},  in_data1_reg[0]};
            //     mult_s_b[2] <= {{2{in_data1_reg[7][5]}},  in_data1_reg[7]};
            //     mult_s_a[3] <= {{2{in_data1_reg[10][5]}}, in_data1_reg[10]};
            //     mult_s_b[3] <= {{2{in_data1_reg[13][5]}}, in_data1_reg[13]};
            // end
            2'd1: begin
                // -
                mult_s_a[0] <= {{2{in_data1_reg[0][5]}},  in_data1_reg[0]};
                mult_s_b[0] <= {{2{in_data1_reg[6][5]}},  in_data1_reg[6]};
                mult_s_a[1] <= {{2{in_data1_reg[11][5]}}, in_data1_reg[11]};
                mult_s_b[1] <= {{2{in_data1_reg[13][5]}}, in_data1_reg[13]};
                // +
                
                mult_s_a[2] <= {{2{in_data1_reg[0][5]}},  in_data1_reg[0]};
                mult_s_b[2] <= {{2{in_data1_reg[5][5]}},  in_data1_reg[5]};
                mult_s_a[3] <= {{2{in_data1_reg[11][5]}}, in_data1_reg[11]};
                mult_s_b[3] <= {{2{in_data1_reg[14][5]}}, in_data1_reg[14]};
            end
            2'd2: begin
                // +
                mult_s_a[0] <= {{2{in_data1_reg[0][5]}},  in_data1_reg[0]};
                mult_s_b[0] <= {{2{in_data1_reg[7][5]}},  in_data1_reg[7]};
                mult_s_a[1] <= {{2{in_data1_reg[9][5]}},  in_data1_reg[9]};
                mult_s_b[1] <= {{2{in_data1_reg[14][5]}}, in_data1_reg[14]};
                // -
                mult_s_a[2] <= {{2{in_data1_reg[0][5]}},  in_data1_reg[0]};
                mult_s_b[2] <= {{2{in_data1_reg[6][5]}},  in_data1_reg[6]};
                mult_s_a[3] <= {{2{in_data1_reg[9][5]}},  in_data1_reg[9]};
                mult_s_b[3] <= {{2{in_data1_reg[15][5]}}, in_data1_reg[15]};
            end
            default: begin
                // -
                mult_s_a[0] <= {{2{in_data1_reg[0][5]}},  in_data1_reg[0]};
                mult_s_b[0] <= {{2{in_data1_reg[5][5]}},  in_data1_reg[5]};
                mult_s_a[1] <= {{2{in_data1_reg[10][5]}}, in_data1_reg[10]};
                mult_s_b[1] <= {{2{in_data1_reg[15][5]}}, in_data1_reg[15]};
                // +
                mult_s_a[2] <= {{2{in_data1_reg[0][5]}},  in_data1_reg[0]};
                mult_s_b[2] <= {{2{in_data1_reg[7][5]}},  in_data1_reg[7]};
                mult_s_a[3] <= {{2{in_data1_reg[10][5]}}, in_data1_reg[10]};
                mult_s_b[3] <= {{2{in_data1_reg[13][5]}}, in_data1_reg[13]};
            end
        endcase
    end
    else if (Q_mult) begin
        mult_s_a[0] <= in_data2_reg[{mult_cnt_small[5:3], 3'd0}];
        mult_s_a[1] <= in_data2_reg[{mult_cnt_small[5:3], 3'd1}];
        mult_s_a[2] <= in_data2_reg[{mult_cnt_small[5:3], 3'd2}];
        mult_s_a[3] <= in_data2_reg[{mult_cnt_small[5:3], 3'd3}];
        mult_s_a[4] <= in_data2_reg[{mult_cnt_small[5:3], 3'd4}];
        mult_s_a[5] <= in_data2_reg[{mult_cnt_small[5:3], 3'd5}];
        mult_s_a[6] <= in_data2_reg[{mult_cnt_small[5:3], 3'd6}];
        mult_s_a[7] <= in_data2_reg[{mult_cnt_small[5:3], 3'd7}];

        mult_s_b[0] <= w_Q_transpose[{mult_cnt_small[2:0], 3'd0}];
        mult_s_b[1] <= w_Q_transpose[{mult_cnt_small[2:0], 3'd1}];
        mult_s_b[2] <= w_Q_transpose[{mult_cnt_small[2:0], 3'd2}];
        mult_s_b[3] <= w_Q_transpose[{mult_cnt_small[2:0], 3'd3}];
        mult_s_b[4] <= w_Q_transpose[{mult_cnt_small[2:0], 3'd4}];
        mult_s_b[5] <= w_Q_transpose[{mult_cnt_small[2:0], 3'd5}];
        mult_s_b[6] <= w_Q_transpose[{mult_cnt_small[2:0], 3'd6}];
        mult_s_b[7] <= w_Q_transpose[{mult_cnt_small[2:0], 3'd7}];
    end
    else if (K_mult) begin
        mult_s_a[0] <= in_data2_reg[{mult_cnt_small[5:3], 3'd0}];
        mult_s_a[1] <= in_data2_reg[{mult_cnt_small[5:3], 3'd1}];
        mult_s_a[2] <= in_data2_reg[{mult_cnt_small[5:3], 3'd2}];
        mult_s_a[3] <= in_data2_reg[{mult_cnt_small[5:3], 3'd3}];
        mult_s_a[4] <= in_data2_reg[{mult_cnt_small[5:3], 3'd4}];
        mult_s_a[5] <= in_data2_reg[{mult_cnt_small[5:3], 3'd5}];
        mult_s_a[6] <= in_data2_reg[{mult_cnt_small[5:3], 3'd6}];
        mult_s_a[7] <= in_data2_reg[{mult_cnt_small[5:3], 3'd7}];

        mult_s_b[0] <= w_K_transpose[{mult_cnt_small[2:0], 3'd0}];
        mult_s_b[1] <= w_K_transpose[{mult_cnt_small[2:0], 3'd1}];
        mult_s_b[2] <= w_K_transpose[{mult_cnt_small[2:0], 3'd2}];
        mult_s_b[3] <= w_K_transpose[{mult_cnt_small[2:0], 3'd3}];
        mult_s_b[4] <= w_K_transpose[{mult_cnt_small[2:0], 3'd4}];
        mult_s_b[5] <= w_K_transpose[{mult_cnt_small[2:0], 3'd5}];
        mult_s_b[6] <= w_K_transpose[{mult_cnt_small[2:0], 3'd6}];
        mult_s_b[7] <= w_K_transpose[{mult_cnt_small[2:0], 3'd7}];
    end
    else if (V_mult) begin
        mult_s_a[0] <= in_data2_reg[{mult_cnt_small[5:3], 3'd0}];
        mult_s_a[1] <= in_data2_reg[{mult_cnt_small[5:3], 3'd1}];
        mult_s_a[2] <= in_data2_reg[{mult_cnt_small[5:3], 3'd2}];
        mult_s_a[3] <= in_data2_reg[{mult_cnt_small[5:3], 3'd3}];
        mult_s_a[4] <= in_data2_reg[{mult_cnt_small[5:3], 3'd4}];
        mult_s_a[5] <= in_data2_reg[{mult_cnt_small[5:3], 3'd5}];
        mult_s_a[6] <= in_data2_reg[{mult_cnt_small[5:3], 3'd6}];
        mult_s_a[7] <= in_data2_reg[{mult_cnt_small[5:3], 3'd7}];

        mult_s_b[0] <= w_V_transpose[{mult_cnt_small[2:0], 3'd0}];
        mult_s_b[1] <= w_V_transpose[{mult_cnt_small[2:0], 3'd1}];
        mult_s_b[2] <= w_V_transpose[{mult_cnt_small[2:0], 3'd2}];
        mult_s_b[3] <= w_V_transpose[{mult_cnt_small[2:0], 3'd3}];
        mult_s_b[4] <= w_V_transpose[{mult_cnt_small[2:0], 3'd4}];
        mult_s_b[5] <= w_V_transpose[{mult_cnt_small[2:0], 3'd5}];
        mult_s_b[6] <= w_V_transpose[{mult_cnt_small[2:0], 3'd6}];
        mult_s_b[7] <= w_V_transpose[{mult_cnt_small[2:0], 3'd7}];
    end
    else if (cnt_clk == end_cycle) begin
        for (i = 0; i < 8; i = i + 1) begin
            mult_s_a[i] <= 8'd0;
            mult_s_b[i] <= 8'd0;
        end
    end
end

// reg signed [18:0] mult_b_a[0:7]
// reg signed [36:0] mult_b_b[0:7]
always @(posedge clk or negedge rst_n) begin
    integer i;
    if (!rst_n) begin
        for (i = 0; i < 8; i = i + 1) begin
            mult_b_a[i] <= 19'd0;
            mult_b_b[i] <= 37'd0;
        end
    end
    else if (is_det_d1) begin
        mult_b_a[0] <= {{ 3{mult_s_z[0][15]}}, mult_s_z[0]};
        mult_b_b[0] <= {{21{mult_s_z[1][15]}}, mult_s_z[1]};
        mult_b_a[1] <= {{ 3{mult_s_z[2][15]}}, mult_s_z[2]};
        mult_b_b[1] <= {{21{mult_s_z[3][15]}}, mult_s_z[3]};
    end
    else if (is_QK) begin
        mult_b_a[0] <= Q_reg[{mult_cnt_QK[5:3], 3'd0}];
        mult_b_a[1] <= Q_reg[{mult_cnt_QK[5:3], 3'd1}];
        mult_b_a[2] <= Q_reg[{mult_cnt_QK[5:3], 3'd2}];
        mult_b_a[3] <= Q_reg[{mult_cnt_QK[5:3], 3'd3}];
        mult_b_a[4] <= Q_reg[{mult_cnt_QK[5:3], 3'd4}];
        mult_b_a[5] <= Q_reg[{mult_cnt_QK[5:3], 3'd5}];
        mult_b_a[6] <= Q_reg[{mult_cnt_QK[5:3], 3'd6}];
        mult_b_a[7] <= Q_reg[{mult_cnt_QK[5:3], 3'd7}];

        mult_b_b[0] <= {{18{K_reg[{mult_cnt_QK[2:0], 3'd0}][18]}}, K_reg[{mult_cnt_QK[2:0], 3'd0}]};
        mult_b_b[1] <= {{18{K_reg[{mult_cnt_QK[2:0], 3'd1}][18]}}, K_reg[{mult_cnt_QK[2:0], 3'd1}]};
        mult_b_b[2] <= {{18{K_reg[{mult_cnt_QK[2:0], 3'd2}][18]}}, K_reg[{mult_cnt_QK[2:0], 3'd2}]};
        mult_b_b[3] <= {{18{K_reg[{mult_cnt_QK[2:0], 3'd3}][18]}}, K_reg[{mult_cnt_QK[2:0], 3'd3}]};
        mult_b_b[4] <= {{18{K_reg[{mult_cnt_QK[2:0], 3'd4}][18]}}, K_reg[{mult_cnt_QK[2:0], 3'd4}]};
        mult_b_b[5] <= {{18{K_reg[{mult_cnt_QK[2:0], 3'd5}][18]}}, K_reg[{mult_cnt_QK[2:0], 3'd5}]};
        mult_b_b[6] <= {{18{K_reg[{mult_cnt_QK[2:0], 3'd6}][18]}}, K_reg[{mult_cnt_QK[2:0], 3'd6}]};
        mult_b_b[7] <= {{18{K_reg[{mult_cnt_QK[2:0], 3'd7}][18]}}, K_reg[{mult_cnt_QK[2:0], 3'd7}]};
    end
    else if (is_SV) begin
        mult_b_a[0] <= V_transpose[{mult_cnt_SV[2:0], 3'd0}];  // 19-bit
        mult_b_a[1] <= V_transpose[{mult_cnt_SV[2:0], 3'd1}];
        mult_b_a[2] <= V_transpose[{mult_cnt_SV[2:0], 3'd2}];
        mult_b_a[3] <= V_transpose[{mult_cnt_SV[2:0], 3'd3}];
        mult_b_a[4] <= V_transpose[{mult_cnt_SV[2:0], 3'd4}];
        mult_b_a[5] <= V_transpose[{mult_cnt_SV[2:0], 3'd5}];
        mult_b_a[6] <= V_transpose[{mult_cnt_SV[2:0], 3'd6}];
        mult_b_a[7] <= V_transpose[{mult_cnt_SV[2:0], 3'd7}];

        mult_b_b[0] <= S_reg[{mult_cnt_SV[5:3], 3'd0}];        // 37-bit
        mult_b_b[1] <= S_reg[{mult_cnt_SV[5:3], 3'd1}];
        mult_b_b[2] <= S_reg[{mult_cnt_SV[5:3], 3'd2}];
        mult_b_b[3] <= S_reg[{mult_cnt_SV[5:3], 3'd3}];
        mult_b_b[4] <= S_reg[{mult_cnt_SV[5:3], 3'd4}];
        mult_b_b[5] <= S_reg[{mult_cnt_SV[5:3], 3'd5}];
        mult_b_b[6] <= S_reg[{mult_cnt_SV[5:3], 3'd6}];
        mult_b_b[7] <= S_reg[{mult_cnt_SV[5:3], 3'd7}];
    end
    else if (cnt_clk == end_cycle) begin
        for (i = 0; i < 8; i = i + 1) begin
            mult_b_a[i] <= 19'd0;
            mult_b_b[i] <= 37'd0;
        end
    end
end

// reg signed [20:0] det_tmp;   // 21-bit
always @(posedge clk or negedge rst_n) begin
    if      (!rst_n)     det_tmp <= 25'd0;
    else if (is_det_d2) begin
        if (~cnt_clk[0]) det_tmp <= mult_b_z[0] - mult_b_z[1];
        else             det_tmp <= mult_b_z[1] - mult_b_z[0];
    end
end

// reg signed [24:0] det_result;
always @(posedge clk or negedge rst_n) begin
    if      (!rst_n)               det_result <= 25'd0;
    else if (is_det_d3)            det_result <= det_result + det_tmp;
    else if (cnt_clk == end_cycle) det_result <= 25'd0;
end

// -------------- attention --------------

assign Q_mult = cnt_clk >= 9'd57  && cnt_clk <= 9'd120;
assign K_mult = cnt_clk >= 9'd121 && cnt_clk <= 9'd184;
assign V_mult = cnt_clk >= 9'd185 && cnt_clk < 9'd185 + handle_cycles_t8;

// reg Q_mult_d1, K_mult_d1, V_mult_d1;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        Q_mult_d1 <= 1'b0;
        K_mult_d1 <= 1'b0;
        V_mult_d1 <= 1'b0;
    end
    else begin
        Q_mult_d1 <= Q_mult;
        K_mult_d1 <= K_mult;
        V_mult_d1 <= V_mult;
    end
end

// wire is_multiplying;
assign is_multiplying = (Q_mult || K_mult || V_mult);

// reg [7:0] mult_cnt_small;   // 0~191
always @(posedge clk or negedge rst_n) begin
    if      (!rst_n)               mult_cnt_small <= 8'd0;
    else if (is_multiplying)       mult_cnt_small <= mult_cnt_small + 8'd1;
    else if (cnt_clk == end_cycle) mult_cnt_small <= 8'd0;
end

// reg [7:0] mult_cnt_small_d1;   // 0~191
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) mult_cnt_small_d1 <= 8'd0;
    else        mult_cnt_small_d1 <= mult_cnt_small;
end

// wire signed [7:0] w_Q_transpose [0:63];
// wire signed [7:0] w_K_transpose [0:63];
// wire signed [7:0] w_V_transpose [0:63];
generate
    for (k = 0; k < 64; k = k + 1) begin: transpose_weight
        assign w_Q_transpose[k] = w_Q_reg[k/8 + 8*(k%8)];
        assign w_K_transpose[k] = w_K_reg[k/8 + 8*(k%8)];
        assign w_V_transpose[k] = w_V_reg[k/8 + 8*(k%8)];
    end
endgenerate

// reg signed [18:0] Q_reg [0:63], K_reg [0:63], V_reg [0:63];     // 19-bit
always @(posedge clk or negedge rst_n) begin
    integer i;
    if (!rst_n) begin
        for (i = 0; i < 64; i = i + 1) Q_reg[i] <= 19'd0;
    end
    else if (Q_mult_d1) begin
        Q_reg[mult_cnt_small_d1[5:0]] <= mult_s_z[0] + mult_s_z[1] + mult_s_z[2] + mult_s_z[3] + mult_s_z[4] + mult_s_z[5] + mult_s_z[6] + mult_s_z[7];
    end
    else if (cnt_clk == end_cycle) begin
        for (i = 0; i < 64; i = i + 1) Q_reg[i] <= 19'd0;
    end
end
always @(posedge clk or negedge rst_n) begin
    integer i;
    if (!rst_n) begin
        for (i = 0; i < 64; i = i + 1) K_reg[i] <= 19'd0;
    end
    else if (K_mult_d1) begin
        K_reg[mult_cnt_small_d1[5:0]] <= mult_s_z[0] + mult_s_z[1] + mult_s_z[2] + mult_s_z[3] + mult_s_z[4] + mult_s_z[5] + mult_s_z[6] + mult_s_z[7];
    end
    else if (cnt_clk == end_cycle) begin
        for (i = 0; i < 64; i = i + 1) K_reg[i] <= 19'd0;
    end
end
always @(posedge clk or negedge rst_n) begin
    integer i;
    if (!rst_n) begin
        for (i = 0; i < 64; i = i + 1) V_reg[i] <= 19'd0;
    end
    else if (V_mult_d1) begin
        V_reg[mult_cnt_small_d1[5:0]] <= mult_s_z[0] + mult_s_z[1] + mult_s_z[2] + mult_s_z[3] + mult_s_z[4] + mult_s_z[5] + mult_s_z[6] + mult_s_z[7];
    end
    else if (cnt_clk == end_cycle) begin
        for (i = 0; i < 64; i = i + 1) V_reg[i] <= 19'd0;
    end
end

// -------------- QK^T --------------

// reg [7:0] mult_cnt_QK;   // 0~191
always @(posedge clk or negedge rst_n) begin
    if      (!rst_n) mult_cnt_QK <= 8'd0;
    else if (is_QK)  mult_cnt_QK <= mult_cnt_QK + 8'd1;
    else             mult_cnt_QK <= 8'd0;
end

// wire is_QK;
assign is_QK = (cnt_clk >= QK_start_cycle) && (cnt_clk < QK_start_cycle + handle_cycles_tt);

reg is_QK_d1, is_QK_d2, is_QK_d3;
// reg is_QK_d1, is_QK_d2, is_QK_d3;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        is_QK_d1 <= 8'd0;
        is_QK_d2 <= 8'd0;
        is_QK_d3 <= 8'd0;
    end
    else begin
        is_QK_d1 <= is_QK;
        is_QK_d2 <= is_QK_d1;
        is_QK_d3 <= is_QK_d2;
    end
end

// reg [7:0] mult_cnt_QK_d1, mult_cnt_QK_d2, mult_cnt_QK_d3;   // 0~191
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        mult_cnt_QK_d1 <= 8'd0;
        mult_cnt_QK_d2 <= 8'd0;
        mult_cnt_QK_d3 <= 8'd0;
    end
    else begin
        mult_cnt_QK_d1 <= mult_cnt_QK;
        mult_cnt_QK_d2 <= mult_cnt_QK_d1;
        mult_cnt_QK_d3 <= mult_cnt_QK_d2;
    end
end

// reg signed [37:0] A_tmp;     // 38-bit
always @(posedge clk or negedge rst_n) begin
    integer i;
    if (!rst_n) begin
        for (i = 0; i < 64; i = i + 1) A_tmp[i] <= 38'd0;
    end
    else if (is_QK_d1) begin
        A_tmp <= mult_b_z[0] + mult_b_z[1] + mult_b_z[2] + mult_b_z[3] + mult_b_z[4] + mult_b_z[5] + mult_b_z[6] + mult_b_z[7];
    end
    else if (cnt_clk == end_cycle) begin
        for (i = 0; i < 64; i = i + 1) A_tmp[i] <= 38'd0;
    end
end

// wire signed [36:0] A_pos;     // 37-bit
assign A_pos = ({37{~A_tmp[37]}} & A_tmp[36:0]);

// reg [36:0] div_a;   // 37-bit, all positive, unsigned
always @(posedge clk or negedge rst_n) begin
    if      (!rst_n)   div_a <= 37'd0;
    else if (is_QK_d2) div_a <= A_pos;
end

// reg [35:0] div_z;   // 36-bit
DIV_3 #(37, 36) div_3(.a(div_a), .z(div_z));

// reg signed [36:0] S_reg [0:63];
always @(posedge clk or negedge rst_n) begin
    integer i;
    if (!rst_n) begin
        for (i = 0; i < 64; i = i + 1) S_reg[i] <= 37'd0;
    end
    else if (is_QK_d3) begin
        S_reg[mult_cnt_QK_d3] <= {1'b0, div_z};
    end
    else if (cnt_clk == end_cycle) begin
        for (i = 0; i < 64; i = i + 1) S_reg[i] <= 37'd0;
    end
end

// -------------- SV --------------

// wire is_SV;
assign is_SV = (cnt_clk >= SV_start_cycle) && (cnt_clk < SV_start_cycle + handle_cycles_t8);

// reg is_SV_d1, is_SV_d2, is_SV_d3, is_SV_d4;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        is_SV_d1 <= 1'b0;
    end
    else begin
        is_SV_d1 <= is_SV;
    end
end

// reg [7:0] mult_cnt_SV;   // 0~191
always @(posedge clk or negedge rst_n) begin
    if      (!rst_n) mult_cnt_SV <= 8'd0;
    else if (is_SV)  mult_cnt_SV <= mult_cnt_SV + 8'd1;
    else             mult_cnt_SV <= 8'd0;
end

// reg [7:0] mult_cnt_SV_d1;   // 0~191
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        mult_cnt_SV_d1 <= 8'd0;
    end
    else begin
        mult_cnt_SV_d1 <= mult_cnt_SV;
    end
end

// reg signed [18:0] V_transpose [0:63];
generate
    for (k = 0; k < 64; k = k + 1) begin: transpose_V
        assign V_transpose[k] = V_reg[k/8 + 8*(k%8)];
    end
endgenerate

// reg signed [24:0] mult_f_a;
// reg signed [53:0] mult_f_b;
// reg signed [91:0] mult_f_z;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        mult_f_a <= 25'd0;
        mult_f_b <= 54'd0;
    end
    else if (is_SV_d1) begin
        mult_f_a <= det_result;
        mult_f_b <= mult_b_z[0] + mult_b_z[1] + mult_b_z[2] + mult_b_z[3] + mult_b_z[4] + mult_b_z[5] + mult_b_z[6] + mult_b_z[7];
    end
end

// -------------- mult IP --------------

// reg signed [7:0]  mult_s_a [0:7];
// reg signed [7:0]  mult_s_b [0:7];
// reg signed [15:0] mult_s_z [0:7];

// reg signed [18:0] mult_b_a [0:7];
// reg signed [36:0] mult_b_b [0:7];
// reg signed [53:0] mult_b_z [0:7];
generate
    for (k = 0; k < 8; k = k + 1) begin: mult_gen
        MULT #(8, 8, 16) mult_small (.a(mult_s_a[k]), .b(mult_s_b[k]), .z(mult_s_z[k]));
        MULT #(19, 37, 54) mult_big (.a(mult_b_a[k]), .b(mult_b_b[k]), .z(mult_b_z[k]));
    end
endgenerate

// reg signed [24:0] mult_f_a;
// reg signed [53:0] mult_f_b;
// reg signed [91:0] mult_f_z;
// MULT #(25, 54, 92) mult_final (.a(mult_f_a), .b(mult_f_b), .z(mult_f_z));
MULT #(25, 54, 78) mult_final (.a(mult_f_a), .b(mult_f_b), .z(mult_f_z));


// -------------- output --------------

// output reg out_valid;
// output reg signed [91:0] out_data;

always @(posedge clk or negedge rst_n) begin
    if      (!rst_n)                                            out_valid <= 1'b0;
    else if (cnt_clk >= out_start_cycle && cnt_clk < end_cycle) out_valid <= 1'b1;
    else                                                        out_valid <= 1'b0;
end

always @(posedge clk or negedge rst_n) begin
    if      (!rst_n)                                            out_data <= 92'd0;
    else if (cnt_clk >= out_start_cycle && cnt_clk < end_cycle) out_data <= {{14{mult_f_z[77]}}, mult_f_z};
    else                                                        out_data <= 92'd0;
end

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

module DIV_3 #(
    parameter a_bits = 37,
    parameter z_bits = 36
) (
    input  [a_bits-1:0] a,
    output [z_bits-1:0] z
);
assign z = a / 3;
endmodule
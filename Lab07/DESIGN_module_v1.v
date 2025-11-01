/**************************************************************************
 * Copyright (c) 2025, OASIS Lab
 * MODULE: CLK_1_MODULE, CLK_2_MODULE, CLK_3_MODULE
 * FILE NAME: DESIGN_module.v
 * VERSRION: 1.0
 * DATE: Oct 29, 2025
 * AUTHOR: Chao-En Kuo, NYCU IAIS
 * DESCRIPTION: ICLAB2025FALL / LAB7 / DESIGN_module
 * MODIFICATION HISTORY:
 * Date                 Description
 * 
 *************************************************************************/
module CLK_1_MODULE (
    clk,
    rst_n,
    in_valid,
    in_data,
    out_idle,
    out_valid,
    out_data,

    flag_handshake_to_clk1,
    flag_clk1_to_handshake
);

//---------------------------------------------------------------------
//   PORT DECLARATION          
//---------------------------------------------------------------------
input             clk;
input             rst_n;
input             in_valid;
input      [31:0] in_data;
input             out_idle;

output reg        out_valid;
output reg [31:0] out_data;

// You can use the the custom flag ports for your design
input  flag_handshake_to_clk1;

output flag_clk1_to_handshake;      // tell hankshake it's last data packet

//---------------------------------------------------------------------
//   Reg / Wire / Parameters DECLARATION          
//---------------------------------------------------------------------

reg [31:0] input_buffer [0:15];
reg [3:0] input_cnt;
reg [4:0] output_cnt;

//---------------------------------------------------------------------
//   Calculation         
//---------------------------------------------------------------------

// reg [3:0] input_cnt;
always @(posedge clk or negedge rst_n) begin
    if      (!rst_n)   input_cnt <= 4'd0;
    else if (output_cnt == 5'd16) input_cnt <= 4'd0;
    else if (input_cnt == 4'd15) input_cnt <= input_cnt;
    else if (in_valid) input_cnt <= input_cnt + 4'd1;
end

// reg [31:0] input_buffer [0:16];
always @(posedge clk) begin
    if (in_valid) input_buffer[input_cnt] <= in_data;
end

// reg [4:0] output_cnt;
always @(posedge clk or negedge rst_n) begin
    if      (!rst_n)                                     output_cnt <= 5'd0;
    else if (out_idle && input_cnt > 4'd0 && !out_valid) output_cnt <= output_cnt + 5'd1;
    else                                                 output_cnt <= output_cnt;
end

// output reg        out_valid;
// output reg [31:0] out_data;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        out_valid <= 1'b0;
        out_data  <= 32'b0;
    end
    else if (out_idle && input_cnt > 4'd0 && !out_valid && output_cnt < 5'd16) begin     // Handshake idle
        out_valid <= 1'b1;
        out_data  <= input_buffer[output_cnt];
    end
    else begin
        out_valid <= 1'b0;
        out_data  <= 32'd0;
    end
end




endmodule

module CLK_2_MODULE (
    clk,
    rst_n,
    in_valid,
    in_data,
    fifo_full,
    out_valid,
    out_data,
    busy,
    
    flag_handshake_to_clk2,
    flag_clk2_to_handshake,

    flag_fifo_to_clk2,
    flag_clk2_to_fifo
);

//---------------------------------------------------------------------
//   PORT DECLARATION          
//---------------------------------------------------------------------
input             clk;      // clk 2
input             rst_n;
input             in_valid;
input             fifo_full;
input      [31:0] in_data;

output reg        out_valid;
output reg [15:0] out_data;
output            busy;

// You can use the the custom flag ports for your design
input  flag_handshake_to_clk2;
output flag_clk2_to_handshake;

input  flag_fifo_to_clk2;
output flag_clk2_to_fifo;

//---------------------------------------------------------------------
//   Reg / Wire / Parameters DECLARATION          
//---------------------------------------------------------------------

genvar k;

parameter S_IDLE   = 2'd0;
parameter S_INPUT  = 2'd1;
parameter S_NTT    = 2'd2;

reg in_valid_reg_1, in_valid_reg_2, in_valid_reg_3;
reg [31:0] in_data_reg_1, in_data_reg_2;

reg [4:0] input_cnt;    // 0~16
reg [5:0] ntt_cnt;      // 0~56
reg [6:0] out_cnt;      // 0~127

reg [1:0] current_state;
reg [1:0] next_state;

reg [15:0] ntt_reg [0:127];

reg [15:0] a [0:7], b [0:7];
reg [13:0] gmb [0:7];
wire [15:0] result_a [0:7], result_b [0:7];

// localparam GMb_0 = 4091;
localparam GMb_1 = 7888,
           GMb_2 = 11060,
           GMb_3 = 11208,
           GMb_4 = 6960,
           GMb_5 = 4342,
           GMb_6 = 6275,
           GMb_7 = 9759,
           GMb_8 = 1591,
           GMb_9 = 6399,
           GMb_10 = 9477,
           GMb_11 = 5266,
           GMb_12 = 586,
           GMb_13 = 5825,
           GMb_14 = 7538,
           GMb_15 = 9710,
           GMb_16 = 1134,
           GMb_17 = 6407,
           GMb_18 = 1711,
           GMb_19 = 965,
           GMb_20 = 7099,
           GMb_21 = 7674,
           GMb_22 = 3743,
           GMb_23 = 6442,
           GMb_24 = 10414,
           GMb_25 = 8100,
           GMb_26 = 1885,
           GMb_27 = 1688,
           GMb_28 = 1364,
           GMb_29 = 10329,
           GMb_30 = 10164,
           GMb_31 = 9180,
           GMb_32 = 12210,
           GMb_33 = 6240,
           GMb_34 = 997,
           GMb_35 = 117,
           GMb_36 = 4783,
           GMb_37 = 4407,
           GMb_38 = 1549,
           GMb_39 = 7072,
           GMb_40 = 2829,
           GMb_41 = 6458,
           GMb_42 = 4431,
           GMb_43 = 8877,
           GMb_44 = 7144,
           GMb_45 = 2564,
           GMb_46 = 5664,
           GMb_47 = 4042,
           GMb_48 = 12189,
           GMb_49 = 432,
           GMb_50 = 10751,
           GMb_51 = 1237,
           GMb_52 = 7610,
           GMb_53 = 1534,
           GMb_54 = 3983,
           GMb_55 = 7863,
           GMb_56 = 2181,
           GMb_57 = 6308,
           GMb_58 = 8720,
           GMb_59 = 6570,
           GMb_60 = 4843,
           GMb_61 = 1690,
           GMb_62 = 14,
           GMb_63 = 3872,
           GMb_64 = 5569,
           GMb_65 = 9368,
           GMb_66 = 12163,
           GMb_67 = 2019,
           GMb_68 = 7543,
           GMb_69 = 2315,
           GMb_70 = 4673,
           GMb_71 = 7340,
           GMb_72 = 1553,
           GMb_73 = 1156,
           GMb_74 = 8401,
           GMb_75 = 11389,
           GMb_76 = 1020,
           GMb_77 = 2967,
           GMb_78 = 10772,
           GMb_79 = 7045,
           GMb_80 = 3316,
           GMb_81 = 11236,
           GMb_82 = 5285,
           GMb_83 = 11578,
           GMb_84 = 10637,
           GMb_85 = 10086,
           GMb_86 = 9493,
           GMb_87 = 6180,
           GMb_88 = 9277,
           GMb_89 = 6130,
           GMb_90 = 3323,
           GMb_91 = 883,
           GMb_92 = 10469,
           GMb_93 = 489,
           GMb_94 = 1502,
           GMb_95 = 2851,
           GMb_96 = 11061,
           GMb_97 = 9729,
           GMb_98 = 2742,
           GMb_99 = 12241,
           GMb_100 = 4970,
           GMb_101 = 10481,
           GMb_102 = 10078,
           GMb_103 = 1195,
           GMb_104 = 730,
           GMb_105 = 1762,
           GMb_106 = 3854,
           GMb_107 = 2030,
           GMb_108 = 5892,
           GMb_109 = 10922,
           GMb_110 = 9020,
           GMb_111 = 5274,
           GMb_112 = 9179,
           GMb_113 = 3604,
           GMb_114 = 3782,
           GMb_115 = 10206,
           GMb_116 = 3180,
           GMb_117 = 3467,
           GMb_118 = 4668,
           GMb_119 = 2446,
           GMb_120 = 7613,
           GMb_121 = 9386,
           GMb_122 = 834,
           GMb_123 = 7703,
           GMb_124 = 6836,
           GMb_125 = 3403,
           GMb_126 = 5351,
           GMb_127 = 12276;

//---------------------------------------------------------------------
//   Design      
//---------------------------------------------------------------------

// -------------------- FSM --------------------

// reg [1:0] current_state;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) current_state <= S_IDLE;
    else        current_state <= next_state;
end

// reg [1:0] next_state;
always @(*) begin
    case (current_state)
        S_IDLE: begin
            if (in_valid_reg_2) next_state = S_INPUT;
            else          next_state = S_IDLE;
        end
        S_INPUT: begin
            if (input_cnt == 5'd16) next_state = S_NTT;
            else                    next_state = S_INPUT;
        end
        S_NTT: begin
            if (out_cnt == 7'd127) next_state = S_IDLE;
            else                   next_state = S_NTT;
        end
        default: next_state = current_state;
    endcase
end

// -------------------- input --------------------

// reg in_valid_reg_1, in_valid_reg_2, in_valid_reg_3;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        in_valid_reg_1 <= 1'b0;
        in_valid_reg_2 <= 1'b0;
        in_valid_reg_3 <= 1'b0;
    end
    else begin
        in_valid_reg_1 <= in_valid;
        in_valid_reg_2 <= in_valid_reg_1;
        in_valid_reg_3 <= in_valid_reg_2;
    end
end

// reg [31:0] in_data_reg_1, in_data_reg_2;
always @(posedge clk) begin
    in_data_reg_1 <= in_data;
    in_data_reg_2 <= in_data_reg_1;
end

wire true_in_valid;

// wire true_in_valid;
assign true_in_valid = in_valid_reg_2 & ~in_valid_reg_3;

// reg [4:0] input_cnt;    // 0~16
always @(posedge clk or negedge rst_n) begin
    if      (!rst_n)        input_cnt <= 5'd0;
    else if (true_in_valid) input_cnt <= input_cnt + 5'd1;
    else                    input_cnt <= input_cnt;
end

// reg [15:0] ntt_reg [0:127];
always @(posedge clk) begin
    integer i;
    // -------------------- input --------------------
    if (true_in_valid) begin     // shift reg
        for (i = 0; i < 8; i = i + 1) begin
            ntt_reg[0*8 + i] <= ntt_reg[1*8 + i];
            ntt_reg[1*8 + i] <= ntt_reg[2*8 + i];
            ntt_reg[2*8 + i] <= ntt_reg[3*8 + i];
            ntt_reg[3*8 + i] <= ntt_reg[4*8 + i];
            ntt_reg[4*8 + i] <= ntt_reg[5*8 + i];
            ntt_reg[5*8 + i] <= ntt_reg[6*8 + i];
            ntt_reg[6*8 + i] <= ntt_reg[7*8 + i];
            ntt_reg[7*8 + i] <= ntt_reg[8*8 + i];
            ntt_reg[8*8 + i] <= ntt_reg[9*8 + i];
            ntt_reg[9*8 + i] <= ntt_reg[10*8 + i];
            ntt_reg[10*8 + i] <= ntt_reg[11*8 + i];
            ntt_reg[11*8 + i] <= ntt_reg[12*8 + i];
            ntt_reg[12*8 + i] <= ntt_reg[13*8 + i];
            ntt_reg[13*8 + i] <= ntt_reg[14*8 + i];
            ntt_reg[14*8 + i] <= ntt_reg[15*8 + i];
            ntt_reg[15*8 + i] <= {12'd0, in_data_reg_2[i*4 +: 4]};      // <----- input
        end
    end
    // -------------------- NTT --------------------
    else if (current_state == S_NTT) begin
        case (ntt_cnt)
            0: for (i = 0; i < 8; i = i + 1) begin ntt_reg[8*0+i] <= result_a[i]; ntt_reg[8*(8+0)+i] <= result_b[i]; end
            1: for (i = 0; i < 8; i = i + 1) begin ntt_reg[8*1+i] <= result_a[i]; ntt_reg[8*(8+1)+i] <= result_b[i]; end
            2: for (i = 0; i < 8; i = i + 1) begin ntt_reg[8*2+i] <= result_a[i]; ntt_reg[8*(8+2)+i] <= result_b[i]; end
            3: for (i = 0; i < 8; i = i + 1) begin ntt_reg[8*3+i] <= result_a[i]; ntt_reg[8*(8+3)+i] <= result_b[i]; end
            4: for (i = 0; i < 8; i = i + 1) begin ntt_reg[8*4+i] <= result_a[i]; ntt_reg[8*(8+4)+i] <= result_b[i]; end
            5: for (i = 0; i < 8; i = i + 1) begin ntt_reg[8*5+i] <= result_a[i]; ntt_reg[8*(8+5)+i] <= result_b[i]; end
            6: for (i = 0; i < 8; i = i + 1) begin ntt_reg[8*6+i] <= result_a[i]; ntt_reg[8*(8+6)+i] <= result_b[i]; end
            7: for (i = 0; i < 8; i = i + 1) begin ntt_reg[8*7+i] <= result_a[i]; ntt_reg[8*(8+7)+i] <= result_b[i]; end

            8:  for (i = 0; i < 8; i = i + 1) begin ntt_reg[8*0+i] <= result_a[i]; ntt_reg[8*(4+0)+i] <= result_b[i]; end
            9:  for (i = 0; i < 8; i = i + 1) begin ntt_reg[8*1+i] <= result_a[i]; ntt_reg[8*(4+1)+i] <= result_b[i]; end
            10: for (i = 0; i < 8; i = i + 1) begin ntt_reg[8*2+i] <= result_a[i]; ntt_reg[8*(4+2)+i] <= result_b[i]; end
            11: for (i = 0; i < 8; i = i + 1) begin ntt_reg[8*3+i] <= result_a[i]; ntt_reg[8*(4+3)+i] <= result_b[i]; end
            12: for (i = 0; i < 8; i = i + 1) begin ntt_reg[8*0+i+64] <= result_a[i]; ntt_reg[8*(4+0)+i+64] <= result_b[i]; end
            13: for (i = 0; i < 8; i = i + 1) begin ntt_reg[8*1+i+64] <= result_a[i]; ntt_reg[8*(4+1)+i+64] <= result_b[i]; end
            14: for (i = 0; i < 8; i = i + 1) begin ntt_reg[8*2+i+64] <= result_a[i]; ntt_reg[8*(4+2)+i+64] <= result_b[i]; end
            15: for (i = 0; i < 8; i = i + 1) begin ntt_reg[8*3+i+64] <= result_a[i]; ntt_reg[8*(4+3)+i+64] <= result_b[i]; end

            16: for (i = 0; i < 8; i = i + 1) begin ntt_reg[8*0+i] <= result_a[i]; ntt_reg[8*(2+0)+i] <= result_b[i]; end
            17: for (i = 0; i < 8; i = i + 1) begin ntt_reg[8*1+i] <= result_a[i]; ntt_reg[8*(2+1)+i] <= result_b[i]; end
            18: for (i = 0; i < 8; i = i + 1) begin ntt_reg[8*0+i+32] <= result_a[i]; ntt_reg[8*(2+0)+i+32] <= result_b[i]; end
            19: for (i = 0; i < 8; i = i + 1) begin ntt_reg[8*1+i+32] <= result_a[i]; ntt_reg[8*(2+1)+i+32] <= result_b[i]; end
            20: for (i = 0; i < 8; i = i + 1) begin ntt_reg[8*0+i+64] <= result_a[i]; ntt_reg[8*(2+0)+i+64] <= result_b[i]; end
            21: for (i = 0; i < 8; i = i + 1) begin ntt_reg[8*1+i+64] <= result_a[i]; ntt_reg[8*(2+1)+i+64] <= result_b[i]; end
            22: for (i = 0; i < 8; i = i + 1) begin ntt_reg[8*0+i+96] <= result_a[i]; ntt_reg[8*(2+0)+i+96] <= result_b[i]; end
            23: for (i = 0; i < 8; i = i + 1) begin ntt_reg[8*1+i+96] <= result_a[i]; ntt_reg[8*(2+1)+i+96] <= result_b[i]; end
            
            24: for (i = 0; i < 8; i = i + 1) begin ntt_reg[i+16*0] <= result_a[i]; ntt_reg[8+i+16*0] <= result_b[i]; end
            25: for (i = 0; i < 8; i = i + 1) begin ntt_reg[i+16*1] <= result_a[i]; ntt_reg[8+i+16*1] <= result_b[i]; end
            26: for (i = 0; i < 8; i = i + 1) begin ntt_reg[i+16*2] <= result_a[i]; ntt_reg[8+i+16*2] <= result_b[i]; end
            27: for (i = 0; i < 8; i = i + 1) begin ntt_reg[i+16*3] <= result_a[i]; ntt_reg[8+i+16*3] <= result_b[i]; end
            28: for (i = 0; i < 8; i = i + 1) begin ntt_reg[i+16*4] <= result_a[i]; ntt_reg[8+i+16*4] <= result_b[i]; end
            29: for (i = 0; i < 8; i = i + 1) begin ntt_reg[i+16*5] <= result_a[i]; ntt_reg[8+i+16*5] <= result_b[i]; end
            30: for (i = 0; i < 8; i = i + 1) begin ntt_reg[i+16*6] <= result_a[i]; ntt_reg[8+i+16*6] <= result_b[i]; end
            31: for (i = 0; i < 8; i = i + 1) begin ntt_reg[i+16*7] <= result_a[i]; ntt_reg[8+i+16*7] <= result_b[i]; end

            32: for (i = 0; i < 8; i = i + 1) begin ntt_reg[0+i*8] <= result_a[i]; ntt_reg[4+i*8] <= result_b[i]; end
            33: for (i = 0; i < 8; i = i + 1) begin ntt_reg[1+i*8] <= result_a[i]; ntt_reg[5+i*8] <= result_b[i]; end
            34: for (i = 0; i < 8; i = i + 1) begin ntt_reg[2+i*8] <= result_a[i]; ntt_reg[6+i*8] <= result_b[i]; end
            35: for (i = 0; i < 8; i = i + 1) begin ntt_reg[3+i*8] <= result_a[i]; ntt_reg[7+i*8] <= result_b[i]; end
            36: for (i = 0; i < 8; i = i + 1) begin ntt_reg[0+i*8+64] <= result_a[i]; ntt_reg[4+i*8+64] <= result_b[i]; end
            37: for (i = 0; i < 8; i = i + 1) begin ntt_reg[1+i*8+64] <= result_a[i]; ntt_reg[5+i*8+64] <= result_b[i]; end
            38: for (i = 0; i < 8; i = i + 1) begin ntt_reg[2+i*8+64] <= result_a[i]; ntt_reg[6+i*8+64] <= result_b[i]; end
            39: for (i = 0; i < 8; i = i + 1) begin ntt_reg[3+i*8+64] <= result_a[i]; ntt_reg[7+i*8+64] <= result_b[i]; end

            40: for (i = 0; i < 8; i = i + 1) begin ntt_reg[0+i*8] <= result_a[i]; ntt_reg[2+i*8] <= result_b[i]; end
            41: for (i = 0; i < 8; i = i + 1) begin ntt_reg[1+i*8] <= result_a[i]; ntt_reg[3+i*8] <= result_b[i]; end
            42: for (i = 0; i < 8; i = i + 1) begin ntt_reg[4+i*8] <= result_a[i]; ntt_reg[6+i*8] <= result_b[i]; end
            43: for (i = 0; i < 8; i = i + 1) begin ntt_reg[5+i*8] <= result_a[i]; ntt_reg[7+i*8] <= result_b[i]; end
            44: for (i = 0; i < 8; i = i + 1) begin ntt_reg[0+i*8+64] <= result_a[i]; ntt_reg[2+i*8+64] <= result_b[i]; end
            45: for (i = 0; i < 8; i = i + 1) begin ntt_reg[1+i*8+64] <= result_a[i]; ntt_reg[3+i*8+64] <= result_b[i]; end
            46: for (i = 0; i < 8; i = i + 1) begin ntt_reg[4+i*8+64] <= result_a[i]; ntt_reg[6+i*8+64] <= result_b[i]; end
            47: for (i = 0; i < 8; i = i + 1) begin ntt_reg[6+i*8+64] <= result_a[i]; ntt_reg[7+i*8+64] <= result_b[i]; end

            48: for (i = 0; i < 8; i = i + 1) begin ntt_reg[0+i*8] <= result_a[i]; ntt_reg[1+i*8] <= result_b[i]; end
            49: for (i = 0; i < 8; i = i + 1) begin ntt_reg[2+i*8] <= result_a[i]; ntt_reg[3+i*8] <= result_b[i]; end
            50: for (i = 0; i < 8; i = i + 1) begin ntt_reg[4+i*8] <= result_a[i]; ntt_reg[5+i*8] <= result_b[i]; end
            51: for (i = 0; i < 8; i = i + 1) begin ntt_reg[6+i*8] <= result_a[i]; ntt_reg[7+i*8] <= result_b[i]; end
            52: for (i = 0; i < 8; i = i + 1) begin ntt_reg[0+i*8+64] <= result_a[i]; ntt_reg[1+i*8+64] <= result_b[i]; end
            53: for (i = 0; i < 8; i = i + 1) begin ntt_reg[2+i*8+64] <= result_a[i]; ntt_reg[3+i*8+64] <= result_b[i]; end
            54: for (i = 0; i < 8; i = i + 1) begin ntt_reg[4+i*8+64] <= result_a[i]; ntt_reg[5+i*8+64] <= result_b[i]; end
            55: for (i = 0; i < 8; i = i + 1) begin ntt_reg[6+i*8+64] <= result_a[i]; ntt_reg[7+i*8+64] <= result_b[i]; end
        endcase
    end
    // else ntt_reg <= ntt_reg;
end

// -------------------- NTT --------------------

// reg [5:0] ntt_cnt;
always @(posedge clk) begin
    if (current_state == S_NTT) ntt_cnt <= (ntt_cnt == 6'd56) ? ntt_cnt : ntt_cnt + 9'd1;
    else                        ntt_cnt <= 9'd0;
end

// reg [3:0] in_data_reg_2 [0:127];
// reg [15:0] ntt_reg [0:127];

// reg [15:0] a [0:7], b [0:7];
always @(*) begin
    integer i;
    for (i = 0; i < 8; i = i + 1) begin
        a[i] = 16'd0;
        b[i] = 16'd0;
    end
    if (current_state == S_NTT) begin
        case (ntt_cnt)
            0: for (i = 0; i < 8; i = i + 1) begin a[i] = ntt_reg[8*0+i]; b[i] = ntt_reg[8*(8+0)+i]; end
            1: for (i = 0; i < 8; i = i + 1) begin a[i] = ntt_reg[8*1+i]; b[i] = ntt_reg[8*(8+1)+i]; end
            2: for (i = 0; i < 8; i = i + 1) begin a[i] = ntt_reg[8*2+i]; b[i] = ntt_reg[8*(8+2)+i]; end
            3: for (i = 0; i < 8; i = i + 1) begin a[i] = ntt_reg[8*3+i]; b[i] = ntt_reg[8*(8+3)+i]; end
            4: for (i = 0; i < 8; i = i + 1) begin a[i] = ntt_reg[8*4+i]; b[i] = ntt_reg[8*(8+4)+i]; end
            5: for (i = 0; i < 8; i = i + 1) begin a[i] = ntt_reg[8*5+i]; b[i] = ntt_reg[8*(8+5)+i]; end
            6: for (i = 0; i < 8; i = i + 1) begin a[i] = ntt_reg[8*6+i]; b[i] = ntt_reg[8*(8+6)+i]; end
            7: for (i = 0; i < 8; i = i + 1) begin a[i] = ntt_reg[8*7+i]; b[i] = ntt_reg[8*(8+7)+i]; end

            8:  for (i = 0; i < 8; i = i + 1) begin a[i] = ntt_reg[8*0+i]; b[i] = ntt_reg[8*(4+0)+i]; end
            9:  for (i = 0; i < 8; i = i + 1) begin a[i] = ntt_reg[8*1+i]; b[i] = ntt_reg[8*(4+1)+i]; end
            10: for (i = 0; i < 8; i = i + 1) begin a[i] = ntt_reg[8*2+i]; b[i] = ntt_reg[8*(4+2)+i]; end
            11: for (i = 0; i < 8; i = i + 1) begin a[i] = ntt_reg[8*3+i]; b[i] = ntt_reg[8*(4+3)+i]; end
            12: for (i = 0; i < 8; i = i + 1) begin a[i] = ntt_reg[8*0+i+64]; b[i] = ntt_reg[8*(4+0)+i+64]; end
            13: for (i = 0; i < 8; i = i + 1) begin a[i] = ntt_reg[8*1+i+64]; b[i] = ntt_reg[8*(4+1)+i+64]; end
            14: for (i = 0; i < 8; i = i + 1) begin a[i] = ntt_reg[8*2+i+64]; b[i] = ntt_reg[8*(4+2)+i+64]; end
            15: for (i = 0; i < 8; i = i + 1) begin a[i] = ntt_reg[8*3+i+64]; b[i] = ntt_reg[8*(4+3)+i+64]; end

            16: for (i = 0; i < 8; i = i + 1) begin a[i] = ntt_reg[8*0+i]; b[i] = ntt_reg[8*(2+0)+i]; end
            17: for (i = 0; i < 8; i = i + 1) begin a[i] = ntt_reg[8*1+i]; b[i] = ntt_reg[8*(2+1)+i]; end
            18: for (i = 0; i < 8; i = i + 1) begin a[i] = ntt_reg[8*0+i+32]; b[i] = ntt_reg[8*(2+0)+i+32]; end
            19: for (i = 0; i < 8; i = i + 1) begin a[i] = ntt_reg[8*1+i+32]; b[i] = ntt_reg[8*(2+1)+i+32]; end
            20: for (i = 0; i < 8; i = i + 1) begin a[i] = ntt_reg[8*0+i+64]; b[i] = ntt_reg[8*(2+0)+i+64]; end
            21: for (i = 0; i < 8; i = i + 1) begin a[i] = ntt_reg[8*1+i+64]; b[i] = ntt_reg[8*(2+1)+i+64]; end
            22: for (i = 0; i < 8; i = i + 1) begin a[i] = ntt_reg[8*0+i+96]; b[i] = ntt_reg[8*(2+0)+i+96]; end
            23: for (i = 0; i < 8; i = i + 1) begin a[i] = ntt_reg[8*1+i+96]; b[i] = ntt_reg[8*(2+1)+i+96]; end
            
            24: for (i = 0; i < 8; i = i + 1) begin a[i] = ntt_reg[i+16*0]; b[i] = ntt_reg[8+i+16*0]; end
            25: for (i = 0; i < 8; i = i + 1) begin a[i] = ntt_reg[i+16*1]; b[i] = ntt_reg[8+i+16*1]; end
            26: for (i = 0; i < 8; i = i + 1) begin a[i] = ntt_reg[i+16*2]; b[i] = ntt_reg[8+i+16*2]; end
            27: for (i = 0; i < 8; i = i + 1) begin a[i] = ntt_reg[i+16*3]; b[i] = ntt_reg[8+i+16*3]; end
            28: for (i = 0; i < 8; i = i + 1) begin a[i] = ntt_reg[i+16*4]; b[i] = ntt_reg[8+i+16*4]; end
            29: for (i = 0; i < 8; i = i + 1) begin a[i] = ntt_reg[i+16*5]; b[i] = ntt_reg[8+i+16*5]; end
            30: for (i = 0; i < 8; i = i + 1) begin a[i] = ntt_reg[i+16*6]; b[i] = ntt_reg[8+i+16*6]; end
            31: for (i = 0; i < 8; i = i + 1) begin a[i] = ntt_reg[i+16*7]; b[i] = ntt_reg[8+i+16*7]; end

            32: for (i = 0; i < 8; i = i + 1) begin a[i] = ntt_reg[0+i*8]; b[i] = ntt_reg[4+i*8]; end
            33: for (i = 0; i < 8; i = i + 1) begin a[i] = ntt_reg[1+i*8]; b[i] = ntt_reg[5+i*8]; end
            34: for (i = 0; i < 8; i = i + 1) begin a[i] = ntt_reg[2+i*8]; b[i] = ntt_reg[6+i*8]; end
            35: for (i = 0; i < 8; i = i + 1) begin a[i] = ntt_reg[3+i*8]; b[i] = ntt_reg[7+i*8]; end
            36: for (i = 0; i < 8; i = i + 1) begin a[i] = ntt_reg[0+i*8+64]; b[i] = ntt_reg[4+i*8+64]; end
            37: for (i = 0; i < 8; i = i + 1) begin a[i] = ntt_reg[1+i*8+64]; b[i] = ntt_reg[5+i*8+64]; end
            38: for (i = 0; i < 8; i = i + 1) begin a[i] = ntt_reg[2+i*8+64]; b[i] = ntt_reg[6+i*8+64]; end
            39: for (i = 0; i < 8; i = i + 1) begin a[i] = ntt_reg[3+i*8+64]; b[i] = ntt_reg[7+i*8+64]; end

            40: for (i = 0; i < 8; i = i + 1) begin a[i] = ntt_reg[0+i*8]; b[i] = ntt_reg[2+i*8]; end
            41: for (i = 0; i < 8; i = i + 1) begin a[i] = ntt_reg[1+i*8]; b[i] = ntt_reg[3+i*8]; end
            42: for (i = 0; i < 8; i = i + 1) begin a[i] = ntt_reg[4+i*8]; b[i] = ntt_reg[6+i*8]; end
            43: for (i = 0; i < 8; i = i + 1) begin a[i] = ntt_reg[5+i*8]; b[i] = ntt_reg[7+i*8]; end
            44: for (i = 0; i < 8; i = i + 1) begin a[i] = ntt_reg[0+i*8+64]; b[i] = ntt_reg[2+i*8+64]; end
            45: for (i = 0; i < 8; i = i + 1) begin a[i] = ntt_reg[1+i*8+64]; b[i] = ntt_reg[3+i*8+64]; end
            46: for (i = 0; i < 8; i = i + 1) begin a[i] = ntt_reg[4+i*8+64]; b[i] = ntt_reg[6+i*8+64]; end
            47: for (i = 0; i < 8; i = i + 1) begin a[i] = ntt_reg[6+i*8+64]; b[i] = ntt_reg[7+i*8+64]; end

            48: for (i = 0; i < 8; i = i + 1) begin a[i] = ntt_reg[0+i*8]; b[i] = ntt_reg[1+i*8]; end
            49: for (i = 0; i < 8; i = i + 1) begin a[i] = ntt_reg[2+i*8]; b[i] = ntt_reg[3+i*8]; end
            50: for (i = 0; i < 8; i = i + 1) begin a[i] = ntt_reg[4+i*8]; b[i] = ntt_reg[5+i*8]; end
            51: for (i = 0; i < 8; i = i + 1) begin a[i] = ntt_reg[6+i*8]; b[i] = ntt_reg[7+i*8]; end
            52: for (i = 0; i < 8; i = i + 1) begin a[i] = ntt_reg[0+i*8+64]; b[i] = ntt_reg[1+i*8+64]; end
            53: for (i = 0; i < 8; i = i + 1) begin a[i] = ntt_reg[2+i*8+64]; b[i] = ntt_reg[3+i*8+64]; end
            54: for (i = 0; i < 8; i = i + 1) begin a[i] = ntt_reg[4+i*8+64]; b[i] = ntt_reg[5+i*8+64]; end
            55: for (i = 0; i < 8; i = i + 1) begin a[i] = ntt_reg[6+i*8+64]; b[i] = ntt_reg[7+i*8+64]; end
        endcase
    end
    // else ntt_reg <= ntt_reg;
end

// reg [13:0] gmb [0:7];
always @(*) begin
    integer i;
    for (i = 0; i < 8; i = i + 1) gmb[i] = 14'd0;
    if (current_state == S_NTT) begin
        case (ntt_cnt)
            0, 1, 2, 3, 4, 5, 6, 7: for (i = 0; i < 8; i = i + 1) gmb[i] = GMb_1;
            8,  9,  10, 11:         for (i = 0; i < 8; i = i + 1) gmb[i] = GMb_2;
            12, 13, 14, 15:         for (i = 0; i < 8; i = i + 1) gmb[i] = GMb_3;
            16, 17:                 for (i = 0; i < 8; i = i + 1) gmb[i] = GMb_4;
            18, 19:                 for (i = 0; i < 8; i = i + 1) gmb[i] = GMb_5;
            20, 21:                 for (i = 0; i < 8; i = i + 1) gmb[i] = GMb_6;
            22, 23:                 for (i = 0; i < 8; i = i + 1) gmb[i] = GMb_7;
            24:                     for (i = 0; i < 8; i = i + 1) gmb[i] = GMb_8;
            25:                     for (i = 0; i < 8; i = i + 1) gmb[i] = GMb_9;
            26:                     for (i = 0; i < 8; i = i + 1) gmb[i] = GMb_10;
            27:                     for (i = 0; i < 8; i = i + 1) gmb[i] = GMb_11;
            28:                     for (i = 0; i < 8; i = i + 1) gmb[i] = GMb_12;
            29:                     for (i = 0; i < 8; i = i + 1) gmb[i] = GMb_13;
            30:                     for (i = 0; i < 8; i = i + 1) gmb[i] = GMb_14;
            31:                     for (i = 0; i < 8; i = i + 1) gmb[i] = GMb_15;
            32, 33, 34, 35: begin gmb[0] = GMb_16; gmb[1] = GMb_17; gmb[2] = GMb_18; gmb[3] = GMb_19; gmb[4] = GMb_20; gmb[5] = GMb_21; gmb[6] = GMb_22; gmb[7] = GMb_23; end
            36, 37, 38, 39: begin gmb[0] = GMb_24; gmb[1] = GMb_25; gmb[2] = GMb_26; gmb[3] = GMb_27; gmb[4] = GMb_28; gmb[5] = GMb_29; gmb[6] = GMb_30; gmb[7] = GMb_31; end
            40, 41: begin gmb[0] = GMb_32; gmb[1] = GMb_34; gmb[2] = GMb_36; gmb[3] = GMb_38; gmb[4] = GMb_40; gmb[5] = GMb_42; gmb[6] = GMb_44; gmb[7] = GMb_46; end
            42, 43: begin gmb[0] = GMb_33; gmb[1] = GMb_35; gmb[2] = GMb_37; gmb[3] = GMb_39; gmb[4] = GMb_41; gmb[5] = GMb_43; gmb[6] = GMb_45; gmb[7] = GMb_47; end
            44, 45: begin gmb[0] = GMb_48; gmb[1] = GMb_50; gmb[2] = GMb_52; gmb[3] = GMb_54; gmb[4] = GMb_56; gmb[5] = GMb_58; gmb[6] = GMb_60; gmb[7] = GMb_62; end
            46, 47: begin gmb[0] = GMb_49; gmb[1] = GMb_51; gmb[2] = GMb_53; gmb[3] = GMb_55; gmb[4] = GMb_57; gmb[5] = GMb_59; gmb[6] = GMb_61; gmb[7] = GMb_63; end
            48: begin gmb[0] = GMb_64; gmb[1] = GMb_68; gmb[2] = GMb_72; gmb[3] = GMb_76; gmb[4] = GMb_80; gmb[5] = GMb_84; gmb[6] = GMb_88; gmb[7] = GMb_92; end
            49: begin gmb[0] = GMb_65; gmb[1] = GMb_69; gmb[2] = GMb_73; gmb[3] = GMb_77; gmb[4] = GMb_81; gmb[5] = GMb_85; gmb[6] = GMb_89; gmb[7] = GMb_93; end
            50: begin gmb[0] = GMb_66; gmb[1] = GMb_70; gmb[2] = GMb_74; gmb[3] = GMb_78; gmb[4] = GMb_82; gmb[5] = GMb_86; gmb[6] = GMb_90; gmb[7] = GMb_94; end
            51: begin gmb[0] = GMb_67; gmb[1] = GMb_71; gmb[2] = GMb_75; gmb[3] = GMb_79; gmb[4] = GMb_83; gmb[5] = GMb_87; gmb[6] = GMb_91; gmb[7] = GMb_95; end
            52: begin gmb[0] = GMb_96; gmb[1] = GMb_100; gmb[2] = GMb_104; gmb[3] = GMb_108; gmb[4] = GMb_112; gmb[5] = GMb_116; gmb[6] = GMb_120; gmb[7] = GMb_124; end
            53: begin gmb[0] = GMb_97; gmb[1] = GMb_101; gmb[2] = GMb_105; gmb[3] = GMb_109; gmb[4] = GMb_113; gmb[5] = GMb_117; gmb[6] = GMb_121; gmb[7] = GMb_125; end
            54: begin gmb[0] = GMb_98; gmb[1] = GMb_102; gmb[2] = GMb_106; gmb[3] = GMb_110; gmb[4] = GMb_114; gmb[5] = GMb_118; gmb[6] = GMb_122; gmb[7] = GMb_126; end
            55: begin gmb[0] = GMb_99; gmb[1] = GMb_103; gmb[2] = GMb_107; gmb[3] = GMb_111; gmb[4] = GMb_115; gmb[5] = GMb_119; gmb[6] = GMb_123; gmb[7] = GMb_127; end
        endcase
    end
end

// wire [15:0] result_a [0:7], result_b [0:7];
generate
    for (k = 0; k < 8; k = k + 1) begin: modq_gen
        BUTTERFLY butterfly(.a(a[k]), .b(b[k]), .gmb(gmb[k]), .result_a(result_a[k]), .result_b(result_b[k]));
    end
endgenerate

// -------------------- output --------------------

// reg [6:0] out_cnt;      // 0~127
always @(posedge clk or negedge rst_n) begin
    if      (!rst_n)                                                   out_cnt <= 7'd0;
    else if (current_state == S_IDLE)                                  out_cnt <= 7'd0;
    else if (current_state == S_NTT && ntt_cnt >= 9'd49 && !fifo_full) out_cnt <= out_cnt + 7'd1;
    else                                                               out_cnt <= out_cnt;
end

// output reg out_valid;
always @(posedge clk or negedge rst_n) begin
    if      (!rst_n)                                                   out_valid <= 1'b0;
    else if (current_state == S_NTT && ntt_cnt >= 9'd49 && !fifo_full) out_valid <= 1'b1;
    else                                                               out_valid <= 1'b0;
end

// output reg [15:0] out_data;
always @(posedge clk or negedge rst_n) begin
    if      (!rst_n)                                                   out_data <= 16'd0;
    else if (current_state == S_NTT && ntt_cnt >= 9'd49 && !fifo_full) out_data <= ntt_reg[out_cnt];
    else                                                               out_data <= out_data;
end

// output busy;
assign busy = (current_state == S_NTT);

endmodule


module BUTTERFLY (
    input  [15:0] a,       // 16-bit
    input  [15:0] b,       // 16-bit
    input  [13:0] gmb,       // 14-bit  max = 12276 = 10111111110100
    output [15:0] result_a,  // 16-bit
    output [15:0] result_b  // 16-bit
);

localparam Q = 14'd12289;   // 11000000000001
localparam Q0I = 14'd12287;

wire [13:0] b_modq;

wire [29:0] x_;   // 28-bit, b*gmb, 804,507,660, 30'b101111111100111101000000001100
wire [15:0] y_;   // 16-bit, 65535
// wire [29:0] t;    // 30-bit, y * Q, 804,507,660, 30'b101111111100111101000000001100
wire [13:0] z_;   // 14-bit

assign x_ = b * gmb;
assign y_ = (x_ * Q0I);     // (...)%(2^16)   // 16-bit
assign z_ = ({1'b0, x_} + y_ * Q) >> 16; // (...)/(2^16)   // 15-bit
assign b_modq = (z_ < Q) ? z_ : (z_ - Q);

assign result_a = (a + b_modq) % Q;
assign result_b = (a < b_modq) ? ((a + Q) - b_modq) : (a - b_modq);


endmodule

module CLK_3_MODULE (
    clk,
    rst_n,
    fifo_empty,
    fifo_rdata,
    fifo_rinc,
    out_valid,
    out_data,

    flag_fifo_to_clk3,
    flag_clk3_to_fifo
);

//---------------------------------------------------------------------
//   PORT DECLARATION          
//---------------------------------------------------------------------
input             clk;
input             rst_n;
input             fifo_empty;
input      [15:0] fifo_rdata;

output reg        fifo_rinc;
output reg        out_valid;
output reg [15:0] out_data;

// You can change the input / output of the custom flag ports
input  flag_fifo_to_clk3;
output flag_clk3_to_fifo;

//---------------------------------------------------------------------
//   Reg / Wire / Parameters DECLARATION          
//---------------------------------------------------------------------

reg read_request_delayed;

//---------------------------------------------------------------------
//   Calculation        
//---------------------------------------------------------------------

// output reg        fifo_rinc;
always @(posedge clk) begin
    if (!fifo_empty) fifo_rinc <= 1'b1;    // request data
    else             fifo_rinc <= 1'b0;
end

// reg read_request_delayed;
always @(posedge clk) begin
    read_request_delayed <= fifo_rinc;
end

// output reg        out_valid;
// output reg [15:0] out_data;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        out_valid <= 1'b0;
        out_data  <= 16'b0;
    end
    else if (read_request_delayed) begin
        out_valid <= 1'b1;
        out_data  <= fifo_rdata;
    end
    else begin
        out_valid <= 1'b0;
        out_data  <= 16'b0;
    end
end




endmodule
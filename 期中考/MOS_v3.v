//############################################################################

//############################################################################

module MOS(
  // Input Port
  rst_n, 
  clk, 
  matrix_size,
  in_valid,
  in_data,
    
    
  // Output Port
  out_valid,
  out_data
);
//==============================================//
//                   PARAMETER                  //
//==============================================//

integer i,j,k;
genvar g;

//==============================================//
//                   I/O PORTS                  //
//==============================================//
input rst_n, clk, matrix_size,in_valid;
input signed[15:0] in_data;
output reg                  out_valid;
output reg signed[39:0]      out_data;
//==============================================//
//            reg & wire declaration            //
//==============================================//

reg [7:0] cnt;
reg matrix_mode;
reg signed [39:0] weight_m [0:63], weight_m_reg [0:63];
reg signed [39:0] input_m [0:63], input_m_reg [0:63];
reg [5:0] input_cnt;

// reg [7:0] cnt;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) cnt <= 8'd0;
    else if (!matrix_mode && cnt == 8'd42 || matrix_mode && cnt == 8'd146)  cnt <= 8'd0;
    else if (in_valid || cnt > 8'd0)                                        cnt <= cnt + 8'd1;
    else cnt <= cnt;
end

// ------------------- input buffer -------------------

// reg matrix_mode;
always @(posedge clk) begin
    if (in_valid && cnt == 8'd0) matrix_mode <= matrix_size;
    else matrix_mode <= matrix_mode;
end

// reg signed [39:0] weight_m_reg [0:63];
always @(posedge clk) begin
    weight_m_reg <= weight_m;
end

// reg signed [39:0] weight_m [0:63]
always @(*) begin
    weight_m = weight_m_reg;
    if (in_valid && (cnt <= 8'd15 || matrix_mode && cnt <= 8'd63)) weight_m[cnt] = {{24{in_data[15]}}, in_data};
end


// reg [5:0] input_cnt;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) input_cnt <= 6'd0;
    else if (!matrix_mode && cnt >= 8'd16 && cnt <= 8'd31 || cnt >= 8'd64 && cnt <= 8'd127) input_cnt <= input_cnt + 1;
    else input_cnt <= 6'd0;
end

// reg signed [39:0] input_m_reg [0:63];
always @(posedge clk) begin
    input_m_reg <= input_m;
end

// reg signed [39:0] input_m [0:63]
always @(*) begin
    input_m = input_m_reg;
    if (in_valid && (cnt <= 8'd31 || matrix_mode && cnt <= 8'd127)) input_m[input_cnt] = {{24{in_data[15]}}, in_data};
end


// ------------------- calulate -------------------

// input signed [39:0] a,
// input signed [39:0] b,
// output signed [39:0] z
reg  signed [39:0] a_reg  [0:63];
wire signed [39:0] b_reg  [0:63];
wire signed [39:0] z_wire [0:63];
reg signed [39:0] b_reg_transpose [0:63];

// wire signed [39:0] z_wire [0:63];
generate
    for (g = 0; g < 64; g = g + 1) begin: mult_gen
        MULT mult (.a(a_reg[g]), .b(b_reg[g]), .z(z_wire[g]));
    end
endgenerate

reg [5:0] idx_0, idx_1, idx_2, idx_3, idx_4, idx_5, idx_6, idx_7;     // 0~63

// reg [5:0] idx_0;     // 0~63
always @(posedge clk) begin
    if (!matrix_mode) begin
        case (cnt + 1)
            29: idx_0 <= 0;
            30: idx_0 <= 4;
            31: idx_0 <= 8;
            32: idx_0 <= 12;
            default: idx_0 <= 0;
        endcase
    end
    else begin
        case (cnt + 1)
            121: idx_0 <= 0;
            122: idx_0 <= 8;
            123: idx_0 <= 16;
            124: idx_0 <= 24;
            125: idx_0 <= 32;
            126: idx_0 <= 40;
            127: idx_0 <= 48;
            128: idx_0 <= 56;
            default: idx_0 <= 0;
        endcase
    end
end

// reg [5:0] idx_1, idx_2, idx_3, idx_4, idx_5, idx_6, idx_7;     // 0~63
always @(posedge clk) begin
    idx_1 <= idx_0 + 1;
    idx_2 <= idx_1 + 1;
    idx_3 <= idx_2 + 1;
    idx_4 <= idx_3 + 1;
    idx_5 <= idx_4 + 1;
    idx_6 <= idx_5 + 1;
    idx_7 <= idx_6 + 1;
end

// ------------------- a_reg -------------------
// reg signed [39:0] a_reg [0:63]
// reg signed [39:0] a_reg[0]
always @(posedge clk) begin
    if   (!matrix_mode && cnt >= 29 && cnt <= 32 || cnt >= 121 && cnt <= 128) a_reg[0] <= input_m_reg[idx_0];
    else                                                                      a_reg[0] <= 40'd0;
end
// reg signed [39:0] a_reg[1]
always @(posedge clk) begin
    if   (!matrix_mode && cnt >= 30 && cnt <= 33 || cnt >= 122 && cnt <= 129) a_reg[1] <= input_m_reg[idx_1];
    else                                                                      a_reg[1] <= 40'd0;
end
// reg signed [39:0] a_reg[2]
always @(posedge clk) begin
    if   (!matrix_mode && cnt >= 31 && cnt <= 34 || cnt >= 123 && cnt <= 130) a_reg[2] <= input_m_reg[idx_2];
    else                                                                      a_reg[2] <= 40'd0;
end
// reg signed [39:0] a_reg[3]
always @(posedge clk) begin
    if   (!matrix_mode && cnt >= 32 && cnt <= 35 || cnt >= 124 && cnt <= 131) a_reg[3] <= input_m_reg[idx_3];
    else                                                                      a_reg[3] <= 40'd0;
end

// reg signed [39:0] a_reg [4]
always @(posedge clk) begin
    if      (!matrix_mode)              a_reg[4] <= a_reg[0];
    else if ( cnt >= 125 && cnt <= 132) a_reg[4] <= input_m_reg[idx_4];
    else                                a_reg[4] <= 40'd0;
end

// reg signed [39:0] a_reg [5]
always @(posedge clk) begin
    if      (!matrix_mode)              a_reg[5] <= a_reg[1];
    else if ( cnt >= 126 && cnt <= 133) a_reg[5] <= input_m_reg[idx_5];
    else                                a_reg[5] <= 40'd0;
end

// reg signed [39:0] a_reg [6]
always @(posedge clk) begin
    if      (!matrix_mode)              a_reg[6] <= a_reg[2];
    else if ( cnt >= 127 && cnt <= 134) a_reg[6] <= input_m_reg[idx_6];
    else                                a_reg[6] <= 40'd0;
end

// reg signed [39:0] a_reg [7]
always @(posedge clk) begin
    if      (!matrix_mode)              a_reg[7] <= a_reg[3];
    else if ( cnt >= 128 && cnt <= 135) a_reg[7] <= input_m_reg[idx_7];
    else                                a_reg[7] <= 40'd0;
end

// reg signed [39:0] a_reg [8~63]
always @(posedge clk) begin
    if (!matrix_mode) begin
        for (i = 8; i < 64; i = i + 1) a_reg[i] <= a_reg[i-4];
    end
    else begin
        for (i = 8; i < 64; i = i + 1) a_reg[i] <= a_reg[i-8];
    end
end


// ------------------- b_reg -------------------


wire signed [39:0] weight_m_transpose [0:63];

// wire signed [39:0] weight_m_transpose [0:63];
generate
    for (g = 0; g < 64; g = g + 1) begin: transpose_weight
        assign weight_m_transpose[g] = (matrix_mode) ? weight_m_reg[g/8 + 8*(g%8)] : weight_m_reg[g/4 + 4*(g%4)];
    end
endgenerate

// wire signed [39:0] b_reg [0:63];
generate
    for (g = 0; g < 64; g = g + 1) begin: transpose_b_reg
        assign b_reg[g] = (matrix_mode) ? b_reg_transpose[g/8 + 8*(g%8)] : b_reg_transpose[g/4 + 4*(g%4)];
    end
endgenerate

// reg signed [39:0] b_reg_transpose[0]
always @(posedge clk) begin
    if   (!matrix_mode && cnt >= 29 && cnt <= 32 || cnt >= 121 && cnt <= 128) b_reg_transpose[0] <= weight_m_transpose[idx_0];
    else                                                                      b_reg_transpose[0] <= 40'd0;
end
// reg signed [39:0] b_reg_transpose[1]
always @(posedge clk) begin
    if   (!matrix_mode && cnt >= 30 && cnt <= 33 || cnt >= 122 && cnt <= 129) b_reg_transpose[1] <= weight_m_transpose[idx_1];
    else                                                                      b_reg_transpose[1] <= 40'd0;
end
// reg signed [39:0] b_reg_transpose[2]
always @(posedge clk) begin
    if   (!matrix_mode && cnt >= 31 && cnt <= 34 || cnt >= 123 && cnt <= 130) b_reg_transpose[2] <= weight_m_transpose[idx_2];
    else                                                                      b_reg_transpose[2] <= 40'd0;
end
// reg signed [39:0] b_reg_transpose[3]
always @(posedge clk) begin
    if   (!matrix_mode && cnt >= 32 && cnt <= 35 || cnt >= 124 && cnt <= 131) b_reg_transpose[3] <= weight_m_transpose[idx_3];
    else                                                                      b_reg_transpose[3] <= 40'd0;
end

// reg signed [39:0] b_reg_transpose [4]
always @(posedge clk) begin
    if      (!matrix_mode)              b_reg_transpose[4] <= b_reg_transpose[0];
    else if ( cnt >= 125 && cnt <= 132) b_reg_transpose[4] <= weight_m_transpose[idx_4];
    else                                b_reg_transpose[4] <= 40'd0;
end

// reg signed [39:0] b_reg_transpose [5]
always @(posedge clk) begin
    if      (!matrix_mode)              b_reg_transpose[5] <= b_reg_transpose[1];
    else if ( cnt >= 126 && cnt <= 133) b_reg_transpose[5] <= weight_m_transpose[idx_5];
    else                                b_reg_transpose[5] <= 40'd0;
end

// reg signed [39:0] b_reg_transpose [6]
always @(posedge clk) begin
    if      (!matrix_mode)              b_reg_transpose[6] <= b_reg_transpose[2];
    else if ( cnt >= 127 && cnt <= 134) b_reg_transpose[6] <= weight_m_transpose[idx_6];
    else                                b_reg_transpose[6] <= 40'd0;
end

// reg signed [39:0] b_reg_transpose [7]
always @(posedge clk) begin
    if      (!matrix_mode)              b_reg_transpose[7] <= b_reg_transpose[3];
    else if ( cnt >= 128 && cnt <= 135) b_reg_transpose[7] <= weight_m_transpose[idx_7];
    else                                b_reg_transpose[7] <= 40'd0;
end

// reg signed [39:0] b_reg_transpose [8~63]
always @(posedge clk) begin
    if (!matrix_mode) begin
        for (i = 8; i < 64; i = i + 1) b_reg_transpose[i] <= b_reg_transpose[i-4];
    end
    else begin
        for (i = 8; i < 64; i = i + 1) b_reg_transpose[i] <= b_reg_transpose[i-8];
    end
end

// ------------------- sys -------------------

reg signed [39:0] z_reg [0:63];

// reg signed [39:0] z_reg [0:63];
always @(posedge clk ) begin
    z_reg <= z_wire;
end

reg signed [39:0] sys [0:63];

// reg signed [39:0] sys [0:63];
always @(posedge clk) begin
    if (cnt == 8'd0) begin
        for (i = 0; i < 64; i = i + 1) sys[i] <= 40'd0;
    end
    else if (!matrix_mode && cnt >= 8'd31 || matrix_mode && cnt >= 8'd123) begin
        for (i = 0; i < 64; i = i + 1) sys[i] <= sys[i] + z_reg[i];
    end
    else sys <= sys;
end


// ------------------- output -------------------

// output reg                  out_valid;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) out_valid <= 1'd0;
    else if (!matrix_mode && cnt == 8'd35 || matrix_mode && cnt == 8'd131) out_valid <= 1'b1;
    else if (!matrix_mode && cnt == 8'd42 || matrix_mode && cnt == 8'd146) out_valid <= 1'b0;
    else out_valid <= out_valid;
end

// output reg signed[39:0]      out_data;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) out_data <= 40'd0;
    else begin
        if (!matrix_mode) begin
            case (cnt)
                35: out_data <= sys[0];
                36: out_data <= sys[1] + sys[4];
                37: out_data <= sys[2] + sys[5] + sys[8];
                38: out_data <= sys[3] + sys[6] + sys[9]  + sys[12];
                39: out_data <=          sys[7] + sys[10] + sys[13];
                40: out_data <=                   sys[11] + sys[14];
                41: out_data <=                             sys[15];
                default: out_data <= 40'd0;
            endcase
        end
        else begin
            case (cnt)
                131: out_data <= sys[0];
                132: out_data <= sys[1] + sys[8];
                133: out_data <= sys[2] + sys[9]  + sys[16];
                134: out_data <= sys[3] + sys[10] + sys[17] + sys[24];
                135: out_data <= sys[4] + sys[11] + sys[18] + sys[25] + sys[32];
                136: out_data <= sys[5] + sys[12] + sys[19] + sys[26] + sys[33] + sys[40];
                137: out_data <= sys[6] + sys[13] + sys[20] + sys[27] + sys[34] + sys[41] + sys[48];
                138: out_data <= sys[7] + sys[14] + sys[21] + sys[28] + sys[35] + sys[42] + sys[49] + sys[56];
                139: out_data <=          sys[15] + sys[22] + sys[29] + sys[36] + sys[43] + sys[50] + sys[57];
                140: out_data <=                    sys[23] + sys[30] + sys[37] + sys[44] + sys[51] + sys[58];
                141: out_data <=                              sys[31] + sys[38] + sys[45] + sys[52] + sys[59];
                142: out_data <=                                        sys[39] + sys[46] + sys[53] + sys[60];
                143: out_data <=                                                  sys[47] + sys[54] + sys[61];
                144: out_data <=                                                            sys[55] + sys[62];
                145: out_data <=                                                                      sys[63];
                default: out_data <= 40'd0;
            endcase
        end
    end
end


endmodule



module MULT (
    input signed [39:0] a,
    input signed [39:0] b,
    output signed [39:0] z
);
assign z = a * b;
endmodule
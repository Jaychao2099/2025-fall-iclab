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
    else if (!matrix_mode && cnt == 8'd41 || matrix_mode && cnt == 8'd145)  cnt <= 8'd0;
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
reg  signed [39:0] a_reg [0:63];
wire signed [39:0] b_reg [0:63];
reg  signed [39:0] z_reg [0:63];
reg signed [39:0] b_reg_transpose [0:63];

// reg signed [39:0] a_reg [0:63], b_reg [0:63], z_reg [0:63];
generate
    for (g = 0; g < 64; g = g + 1) begin: mult_gen
        MULT mult (.a(a_reg[g]), .b(b_reg[g]), .z(z_reg[g]));
    end
endgenerate

// ------------------- a_reg -------------------
// reg signed [39:0] a_reg [0:63]
// reg signed [39:0] a_reg[0]
always @(posedge clk) begin
    if (!matrix_mode) begin
        case (cnt)
            29: a_reg[0] <= input_m_reg[0];
            30: a_reg[0] <= input_m_reg[4];
            31: a_reg[0] <= input_m_reg[8];
            32: a_reg[0] <= input_m_reg[12];
            default: a_reg[0] <= 40'd0;
        endcase
    end
    else begin
        case (cnt)
            121: a_reg[0] <= input_m_reg[0];
            122: a_reg[0] <= input_m_reg[8];
            123: a_reg[0] <= input_m_reg[16];
            124: a_reg[0] <= input_m_reg[24];
            125: a_reg[0] <= input_m_reg[32];
            126: a_reg[0] <= input_m_reg[40];
            127: a_reg[0] <= input_m_reg[48];
            128: a_reg[0] <= input_m_reg[56];
            default: a_reg[0] <= 40'd0;
        endcase
    end
end
// reg signed [39:0] a_reg[1]
always @(posedge clk) begin
    if (!matrix_mode) begin
        case (cnt)
            30: a_reg[1] <= input_m_reg[1];
            31: a_reg[1] <= input_m_reg[5];
            32: a_reg[1] <= input_m_reg[9];
            33: a_reg[1] <= input_m_reg[13];
            default: a_reg[1] <= 40'd0;
        endcase
    end
    else begin
        case (cnt)
            122: a_reg[1] <= input_m_reg[1];
            123: a_reg[1] <= input_m_reg[9];
            124: a_reg[1] <= input_m_reg[17];
            125: a_reg[1] <= input_m_reg[25];
            126: a_reg[1] <= input_m_reg[33];
            127: a_reg[1] <= input_m_reg[41];
            128: a_reg[1] <= input_m_reg[49];
            129: a_reg[1] <= input_m_reg[57];
            default: a_reg[1] <= 40'd0;
        endcase
    end
end
// reg signed [39:0] a_reg[2]
always @(posedge clk) begin
    if (!matrix_mode) begin
        case (cnt)
            31: a_reg[2] <= input_m_reg[2];
            32: a_reg[2] <= input_m_reg[6];
            33: a_reg[2] <= input_m_reg[10];
            34: a_reg[2] <= input_m_reg[14];
            default: a_reg[2] <= 40'd0;
        endcase
    end
    else begin
        case (cnt)
            123: a_reg[2] <= input_m_reg[2];
            124: a_reg[2] <= input_m_reg[10];
            125: a_reg[2] <= input_m_reg[18];
            126: a_reg[2] <= input_m_reg[26];
            127: a_reg[2] <= input_m_reg[34];
            128: a_reg[2] <= input_m_reg[42];
            129: a_reg[2] <= input_m_reg[50];
            130: a_reg[2] <= input_m_reg[58];
            default: a_reg[2] <= 40'd0;
        endcase
    end
end
// reg signed [39:0] a_reg[3]
always @(posedge clk) begin
    if (!matrix_mode) begin
        case (cnt)
            32: a_reg[3] <= input_m_reg[3];
            33: a_reg[3] <= input_m_reg[7];
            34: a_reg[3] <= input_m_reg[11];
            35: a_reg[3] <= input_m_reg[15];
            default: a_reg[3] <= 40'd0;
        endcase
    end
    else begin
        case (cnt)
            124: a_reg[3] <= input_m_reg[3];
            125: a_reg[3] <= input_m_reg[11];
            126: a_reg[3] <= input_m_reg[19];
            127: a_reg[3] <= input_m_reg[27];
            128: a_reg[3] <= input_m_reg[35];
            129: a_reg[3] <= input_m_reg[43];
            130: a_reg[3] <= input_m_reg[51];
            131: a_reg[3] <= input_m_reg[59];
            default: a_reg[3] <= 40'd0;
        endcase
    end
end

// reg signed [39:0] a_reg [4]
always @(posedge clk) begin
    if (!matrix_mode) a_reg[4] <= a_reg[0];
    else begin
        case (cnt)
            125: a_reg[4] <= input_m_reg[4];
            126: a_reg[4] <= input_m_reg[12];
            127: a_reg[4] <= input_m_reg[20];
            128: a_reg[4] <= input_m_reg[28];
            129: a_reg[4] <= input_m_reg[36];
            130: a_reg[4] <= input_m_reg[44];
            131: a_reg[4] <= input_m_reg[52];
            132: a_reg[4] <= input_m_reg[60];
            default: a_reg[4] <= 40'd0;
        endcase
    end
end

// reg signed [39:0] a_reg [5]
always @(posedge clk) begin
    if (!matrix_mode) a_reg[5] <= a_reg[1];
    else begin
        case (cnt)
            126: a_reg[5] <= input_m_reg[5];
            127: a_reg[5] <= input_m_reg[13];
            128: a_reg[5] <= input_m_reg[21];
            129: a_reg[5] <= input_m_reg[29];
            130: a_reg[5] <= input_m_reg[37];
            131: a_reg[5] <= input_m_reg[45];
            132: a_reg[5] <= input_m_reg[53];
            133: a_reg[5] <= input_m_reg[61];
            default: a_reg[5] <= 40'd0;
        endcase
    end
end

// reg signed [39:0] a_reg [6]
always @(posedge clk) begin
    if (!matrix_mode) a_reg[6] <= a_reg[2]; 
    else begin
        case (cnt)
            127: a_reg[6] <= input_m_reg[6];
            128: a_reg[6] <= input_m_reg[14];
            129: a_reg[6] <= input_m_reg[22];
            130: a_reg[6] <= input_m_reg[30];
            131: a_reg[6] <= input_m_reg[38];
            132: a_reg[6] <= input_m_reg[46];
            133: a_reg[6] <= input_m_reg[54];
            134: a_reg[6] <= input_m_reg[62];
            default: a_reg[6] <= 40'd0;
        endcase
    end
end

// reg signed [39:0] a_reg [7]
always @(posedge clk) begin
    if (!matrix_mode) a_reg[7] <= a_reg[3];
    else begin
        case (cnt)
            128: a_reg[7] <= input_m_reg[7];
            129: a_reg[7] <= input_m_reg[15];
            130: a_reg[7] <= input_m_reg[23];
            131: a_reg[7] <= input_m_reg[31];
            132: a_reg[7] <= input_m_reg[39];
            133: a_reg[7] <= input_m_reg[47];
            134: a_reg[7] <= input_m_reg[55];
            135: a_reg[7] <= input_m_reg[63];
            default: a_reg[7] <= 40'd0;
        endcase
    end
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
    if (!matrix_mode) begin
        case (cnt)
            29: b_reg_transpose[0] <= weight_m_transpose[0];
            30: b_reg_transpose[0] <= weight_m_transpose[4];
            31: b_reg_transpose[0] <= weight_m_transpose[8];
            32: b_reg_transpose[0] <= weight_m_transpose[12];
            default: b_reg_transpose[0] <= 40'd0;
        endcase
    end
    else begin
        case (cnt)
            121: b_reg_transpose[0] <= weight_m_transpose[0];
            122: b_reg_transpose[0] <= weight_m_transpose[8];
            123: b_reg_transpose[0] <= weight_m_transpose[16];
            124: b_reg_transpose[0] <= weight_m_transpose[24];
            125: b_reg_transpose[0] <= weight_m_transpose[32];
            126: b_reg_transpose[0] <= weight_m_transpose[40];
            127: b_reg_transpose[0] <= weight_m_transpose[48];
            128: b_reg_transpose[0] <= weight_m_transpose[56];
            default: b_reg_transpose[0] <= 40'd0;
        endcase
    end
end
// reg signed [39:0] b_reg_transpose[1]
always @(posedge clk) begin
    if (!matrix_mode) begin
        case (cnt)
            30: b_reg_transpose[1] <= weight_m_transpose[1];
            31: b_reg_transpose[1] <= weight_m_transpose[5];
            32: b_reg_transpose[1] <= weight_m_transpose[9];
            33: b_reg_transpose[1] <= weight_m_transpose[13];
            default: b_reg_transpose[1] <= 40'd0;
        endcase
    end
    else begin
        case (cnt)
            122: b_reg_transpose[1] <= weight_m_transpose[1];
            123: b_reg_transpose[1] <= weight_m_transpose[9];
            124: b_reg_transpose[1] <= weight_m_transpose[17];
            125: b_reg_transpose[1] <= weight_m_transpose[25];
            126: b_reg_transpose[1] <= weight_m_transpose[33];
            127: b_reg_transpose[1] <= weight_m_transpose[41];
            128: b_reg_transpose[1] <= weight_m_transpose[49];
            129: b_reg_transpose[1] <= weight_m_transpose[57];
            default: b_reg_transpose[1] <= 40'd0;
        endcase
    end
end
// reg signed [39:0] b_reg_transpose[2]
always @(posedge clk) begin
    if (!matrix_mode) begin
        case (cnt)
            31: b_reg_transpose[2] <= weight_m_transpose[2];
            32: b_reg_transpose[2] <= weight_m_transpose[6];
            33: b_reg_transpose[2] <= weight_m_transpose[10];
            34: b_reg_transpose[2] <= weight_m_transpose[14];
            default: b_reg_transpose[2] <= 40'd0;
        endcase
    end
    else begin
        case (cnt)
            123: b_reg_transpose[2] <= weight_m_transpose[2];
            124: b_reg_transpose[2] <= weight_m_transpose[10];
            125: b_reg_transpose[2] <= weight_m_transpose[18];
            126: b_reg_transpose[2] <= weight_m_transpose[26];
            127: b_reg_transpose[2] <= weight_m_transpose[34];
            128: b_reg_transpose[2] <= weight_m_transpose[42];
            129: b_reg_transpose[2] <= weight_m_transpose[50];
            130: b_reg_transpose[2] <= weight_m_transpose[58];
            default: b_reg_transpose[2] <= 40'd0;
        endcase
    end
end
// reg signed [39:0] b_reg_transpose[3]
always @(posedge clk) begin
    if (!matrix_mode) begin
        case (cnt)
            32: b_reg_transpose[3] <= weight_m_transpose[3];
            33: b_reg_transpose[3] <= weight_m_transpose[7];
            34: b_reg_transpose[3] <= weight_m_transpose[11];
            35: b_reg_transpose[3] <= weight_m_transpose[15];
            default: b_reg_transpose[3] <= 40'd0;
        endcase
    end
    else begin
        case (cnt)
            124: b_reg_transpose[3] <= weight_m_transpose[3];
            125: b_reg_transpose[3] <= weight_m_transpose[11];
            126: b_reg_transpose[3] <= weight_m_transpose[19];
            127: b_reg_transpose[3] <= weight_m_transpose[27];
            128: b_reg_transpose[3] <= weight_m_transpose[35];
            129: b_reg_transpose[3] <= weight_m_transpose[43];
            130: b_reg_transpose[3] <= weight_m_transpose[51];
            131: b_reg_transpose[3] <= weight_m_transpose[59];
            default: b_reg_transpose[3] <= 40'd0;
        endcase
    end
end

// reg signed [39:0] b_reg_transpose [4]
always @(posedge clk) begin
    if (!matrix_mode) b_reg_transpose[4] <= b_reg_transpose[0];
    else begin
        case (cnt)
            125: b_reg_transpose[4] <= weight_m_transpose[4];
            126: b_reg_transpose[4] <= weight_m_transpose[12];
            127: b_reg_transpose[4] <= weight_m_transpose[20];
            128: b_reg_transpose[4] <= weight_m_transpose[28];
            129: b_reg_transpose[4] <= weight_m_transpose[36];
            130: b_reg_transpose[4] <= weight_m_transpose[44];
            131: b_reg_transpose[4] <= weight_m_transpose[52];
            132: b_reg_transpose[4] <= weight_m_transpose[60];
            default: b_reg_transpose[4] <= 40'd0;
        endcase
    end
end

// reg signed [39:0] b_reg_transpose [5]
always @(posedge clk) begin
    if (!matrix_mode) b_reg_transpose[5] <= b_reg_transpose[1];
    else begin
        case (cnt)
            126: b_reg_transpose[5] <= weight_m_transpose[5];
            127: b_reg_transpose[5] <= weight_m_transpose[13];
            128: b_reg_transpose[5] <= weight_m_transpose[21];
            129: b_reg_transpose[5] <= weight_m_transpose[29];
            130: b_reg_transpose[5] <= weight_m_transpose[37];
            131: b_reg_transpose[5] <= weight_m_transpose[45];
            132: b_reg_transpose[5] <= weight_m_transpose[53];
            133: b_reg_transpose[5] <= weight_m_transpose[61];
            default: b_reg_transpose[5] <= 40'd0;
        endcase
    end
end

// reg signed [39:0] b_reg_transpose [6]
always @(posedge clk) begin
    if (!matrix_mode) b_reg_transpose[6] <= b_reg_transpose[2]; 
    else begin
        case (cnt)
            127: b_reg_transpose[6] <= weight_m_transpose[6];
            128: b_reg_transpose[6] <= weight_m_transpose[14];
            129: b_reg_transpose[6] <= weight_m_transpose[22];
            130: b_reg_transpose[6] <= weight_m_transpose[30];
            131: b_reg_transpose[6] <= weight_m_transpose[38];
            132: b_reg_transpose[6] <= weight_m_transpose[46];
            133: b_reg_transpose[6] <= weight_m_transpose[54];
            134: b_reg_transpose[6] <= weight_m_transpose[62];
            default: b_reg_transpose[6] <= 40'd0;
        endcase
    end
end

// reg signed [39:0] b_reg_transpose [7]
always @(posedge clk) begin
    if (!matrix_mode) b_reg_transpose[7] <= b_reg_transpose[3];
    else begin
        case (cnt)
            128: b_reg_transpose[7] <= weight_m_transpose[7];
            129: b_reg_transpose[7] <= weight_m_transpose[15];
            130: b_reg_transpose[7] <= weight_m_transpose[23];
            131: b_reg_transpose[7] <= weight_m_transpose[31];
            132: b_reg_transpose[7] <= weight_m_transpose[39];
            133: b_reg_transpose[7] <= weight_m_transpose[47];
            134: b_reg_transpose[7] <= weight_m_transpose[55];
            135: b_reg_transpose[7] <= weight_m_transpose[63];
            default: b_reg_transpose[7] <= 40'd0;
        endcase
    end
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

reg signed [39:0] sys [0:63];

// reg signed [39:0] sys [0:63];
always @(posedge clk) begin
    if (cnt == 8'd0) begin
        for (i = 0; i < 64; i = i + 1) sys[i] <= 40'd0;
    end
    else if (!matrix_mode && cnt >= 8'd30 || matrix_mode && cnt >= 8'd122) begin
        for (i = 0; i < 64; i = i + 1) sys[i] <= sys[i] + z_reg[i];
    end
    else sys <= sys;
end


// ------------------- output -------------------

// output reg                  out_valid;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) out_valid <= 1'd0;
    else if (!matrix_mode && cnt == 8'd34 || matrix_mode && cnt == 8'd130) out_valid <= 1'b1;
    else if (!matrix_mode && cnt == 8'd41 || matrix_mode && cnt == 8'd145) out_valid <= 1'b0;
    else out_valid <= out_valid;
end

// output reg signed[39:0]      out_data;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) out_data <= 40'd0;
    else begin
        if (!matrix_mode) begin
            case (cnt)
                34: out_data <= sys[0];
                35: out_data <= sys[1] + sys[4];
                36: out_data <= sys[2] + sys[5] + sys[8];
                37: out_data <= sys[3] + sys[6] + sys[9]  + sys[12];
                38: out_data <=          sys[7] + sys[10] + sys[13];
                39: out_data <=                   sys[11] + sys[14];
                40: out_data <=                             sys[15];
                default: out_data <= 40'd0;
            endcase
        end
        else begin
            case (cnt)
                130: out_data <= sys[0];
                131: out_data <= sys[1] + sys[8];
                132: out_data <= sys[2] + sys[9]  + sys[16];
                133: out_data <= sys[3] + sys[10] + sys[17] + sys[24];
                134: out_data <= sys[4] + sys[11] + sys[18] + sys[25] + sys[32];
                135: out_data <= sys[5] + sys[12] + sys[19] + sys[26] + sys[33] + sys[40];
                136: out_data <= sys[6] + sys[13] + sys[20] + sys[27] + sys[34] + sys[41] + sys[48];
                137: out_data <= sys[7] + sys[14] + sys[21] + sys[28] + sys[35] + sys[42] + sys[49] + sys[56];
                138: out_data <=          sys[15] + sys[22] + sys[29] + sys[36] + sys[43] + sys[50] + sys[57];
                139: out_data <=                    sys[23] + sys[30] + sys[37] + sys[44] + sys[51] + sys[58];
                140: out_data <=                              sys[31] + sys[38] + sys[45] + sys[52] + sys[59];
                141: out_data <=                                        sys[39] + sys[46] + sys[53] + sys[60];
                142: out_data <=                                                  sys[47] + sys[54] + sys[61];
                143: out_data <=                                                            sys[55] + sys[62];
                144: out_data <=                                                                      sys[63];
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
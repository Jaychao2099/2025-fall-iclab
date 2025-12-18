module MVDM(
    // input signals
    clk,
    rst_n,
    in_valid, 
    in_valid2,
    in_data,
    // output signals
    out_valid,
    out_sad
    );

input clk;
input rst_n;
input in_valid;
input in_valid2;
input [8:0] in_data;

output reg out_valid;
output reg out_sad;

//=======================================================
//                   Reg/Wire
//=======================================================


//=======================================================
//                   Design
//=======================================================

parameter S_IDLE        = 0;
parameter S_W_SRAM      = 1;
parameter S_MV          = 2;
parameter S_P1_READ_L0  = 3;
parameter S_P1_READ_L1  = 4;
parameter S_P1_CAL      = 5;
parameter S_P2_READ_L0  = 6;
parameter S_P2_READ_L1  = 7;
parameter S_P2_CAL      = 8;
parameter S_OUTPUT      = 9;

reg [3:0] current_state, next_state;

// reg [3:0] current_state
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) current_state <= S_IDLE;
    else current_state <= next_state;
end

// reg [3:0] next_state
always @(*) begin
    case (current_state)
        S_IDLE: begin
            if      (in_valid)  next_state = S_W_SRAM;
            else if (in_valid2) next_state = S_MV;
            else                next_state = S_IDLE;
        end
        S_W_SRAM: begin
            if (input_cnt == 16'd32768) next_state = S_IDLE;    // 15'd32767 ??
            else                        next_state = S_W_SRAM;
        end
        S_MV: begin
            if (input2_cnt == 4'd8) next_state = S_P1_READ_L0;  // 3'd7?
            else                    next_state = S_MV;
        end
        // P1
        S_P1_READ_L0: begin
            if (read_cnt == 4'd15) next_state = S_P1_READ_L1;   // 16 pixel in 1 read
            else                   next_state = S_P1_READ_L0;
        end
        S_P1_READ_L1: begin
            if (read_cnt == 4'd15) next_state = S_P1_CAL;
            else                   next_state = S_P1_READ_L1;
        end
        S_P1_CAL: begin
            if (cal_done) next_state = S_P2_READ_L0;
            else          next_state = S_P1_CAL;
        end
        // P2
        S_P2_READ_L0: begin
            if (read_cnt == 4'd15) next_state = S_P2_READ_L1;   // 16 pixel in 1 read
            else                   next_state = S_P2_READ_L0;
        end
        S_P2_READ_L1: begin
            if (read_cnt == 4'd15) next_state = S_P2_CAL;
            else                   next_state = S_P2_READ_L1;
        end
        S_P2_CAL: begin
            if (cal_done) next_state = S_OUTPUT;
            else          next_state = S_P2_CAL;
        end
        S_OUTPUT: begin
            if (out_cnt == 6'd56) next_state = S_IDLE;
            else                  next_state = S_OUTPUT;
        end
        default: next_state = current_state;
    endcase
end


//=======================================================
//                   MEM
//=======================================================

reg current_img;
reg [4:0] current_row, current_col;

reg [7:0] mem_din [0:15], mem_dout [0:15];


MEM_INTERFACE sram_1 (.image(current_img), .row(current_row), .col(current_col), .Dout(mem_dout), .Din(mem_din), .clk(clk), .WEB());

endmodule

module MEM_INTERFACE (
    input       image,
    input [4:0] row,
    input [4:0] col,
    output [7:0] Dout [0:15],
    input  [7:0] Din  [0:15],
    input clk,
    input WEB
);

SRAM_16_PIXEL_2048 sram (
    .A0(col[0]),.A1(col[1]),.A2(col[2]),.A3(col[3]),.A4(col[4]), 
    .A5(row[0]),.A6(row[1]),.A7(row[2]),.A8(row[3]),.A9(row[4]),
    .A10(image),
    
    .DO0(Dout[0][0]),.DO1(Dout[0][1]),.DO2(Dout[0][2]),.DO3(Dout[0][3]),.DO4(Dout[0][4]),.DO5(Dout[0][5]),.DO6(Dout[0][6]),.DO7(Dout[0][7]),
    .DO8(Dout[1][0]),.DO9(Dout[1][1]),.DO10(Dout[1][2]),.DO11(Dout[1][3]),.DO12(Dout[1][4]),.DO13(Dout[1][5]),.DO14(Dout[1][6]),.DO15(Dout[1][7]),
    .DO16(Dout[2][0]),.DO17(Dout[2][1]),.DO18(Dout[2][2]),.DO19(Dout[2][3]),.DO20(Dout[2][4]),.DO21(Dout[2][5]),.DO22(Dout[2][6]),.DO23(Dout[2][7]),
    .DO24(Dout[3][0]),.DO25(Dout[3][1]),.DO26(Dout[3][2]),.DO27(Dout[3][3]),.DO28(Dout[3][4]),.DO29(Dout[3][5]),.DO30(Dout[3][6]),.DO31(Dout[3][7]),
    .DO32(Dout[4][0]),.DO33(Dout[4][1]),.DO34(Dout[4][2]),.DO35(Dout[4][3]),.DO36(Dout[4][4]),.DO37(Dout[4][5]),.DO38(Dout[4][6]),.DO39(Dout[4][7]),
    .DO40(Dout[5][0]),.DO41(Dout[5][1]),.DO42(Dout[5][2]),.DO43(Dout[5][3]),.DO44(Dout[5][4]),.DO45(Dout[5][5]),.DO46(Dout[5][6]),.DO47(Dout[5][7]),
    .DO48(Dout[6][0]),.DO49(Dout[6][1]),.DO50(Dout[6][2]),.DO51(Dout[6][3]),.DO52(Dout[6][4]),.DO53(Dout[6][5]),.DO54(Dout[6][6]),.DO55(Dout[6][7]),
    .DO56(Dout[7][0]),.DO57(Dout[7][1]),.DO58(Dout[7][2]),.DO59(Dout[7][3]),.DO60(Dout[7][4]),.DO61(Dout[7][5]),.DO62(Dout[7][6]),.DO63(Dout[7][7]),
    .DO64(Dout[8][0]),.DO65(Dout[8][1]),.DO66(Dout[8][2]),.DO67(Dout[8][3]),.DO68(Dout[8][4]),.DO69(Dout[8][5]),.DO70(Dout[8][6]),.DO71(Dout[8][7]),
    .DO72(Dout[9][0]),.DO73(Dout[9][1]),.DO74(Dout[9][2]),.DO75(Dout[9][3]),.DO76(Dout[9][4]),.DO77(Dout[9][5]),.DO78(Dout[9][6]),.DO79(Dout[9][7]),
    .DO80(Dout[10][0]),.DO81(Dout[10][1]),.DO82(Dout[10][2]),.DO83(Dout[10][3]),.DO84(Dout[10][4]),.DO85(Dout[10][5]),.DO86(Dout[10][6]),.DO87(Dout[10][7]),
    .DO88(Dout[11][0]),.DO89(Dout[11][1]),.DO90(Dout[11][2]),.DO91(Dout[11][3]),.DO92(Dout[11][4]),.DO93(Dout[11][5]),.DO94(Dout[11][6]),.DO95(Dout[11][7]),
    .DO96(Dout[12][0]),.DO97(Dout[12][1]),.DO98(Dout[12][2]),.DO99(Dout[12][3]),.DO100(Dout[12][4]),.DO101(Dout[12][5]),.DO102(Dout[12][6]),.DO103(Dout[12][7]),
    .DO104(Dout[13][0]),.DO105(Dout[13][1]),.DO106(Dout[13][2]),.DO107(Dout[13][3]),.DO108(Dout[13][4]),.DO109(Dout[13][5]),.DO110(Dout[13][6]),.DO111(Dout[13][7]),
    .DO112(Dout[14][0]),.DO113(Dout[14][1]),.DO114(Dout[14][2]),.DO115(Dout[14][3]),.DO116(Dout[14][4]),.DO117(Dout[14][5]),.DO118(Dout[14][6]),.DO119(Dout[14][7]),
    .DO120(Dout[15][0]),.DO121(Dout[15][1]),.DO122(Dout[15][2]),.DO123(Dout[15][3]),.DO124(Dout[15][4]),.DO125(Dout[15][5]),.DO126(Dout[15][6]),.DO127(Dout[15][7]),

    
    .DI0(Din[0][0]),.DI1(Din[0][1]),.DI2(Din[0][2]),.DI3(Din[0][3]),.DI4(Din[0][4]),.DI5(Din[0][5]),.DI6(Din[0][6]),.DI7(Din[0][7]),
    .DI8(Din[1][0]),.DI9(Din[1][1]),.DI10(Din[1][2]),.DI11(Din[1][3]),.DI12(Din[1][4]),.DI13(Din[1][5]),.DI14(Din[1][6]),.DI15(Din[1][7]),
    .DI16(Din[2][0]),.DI17(Din[2][1]),.DI18(Din[2][2]),.DI19(Din[2][3]),.DI20(Din[2][4]),.DI21(Din[2][5]),.DI22(Din[2][6]),.DI23(Din[2][7]),
    .DI24(Din[3][0]),.DI25(Din[3][1]),.DI26(Din[3][2]),.DI27(Din[3][3]),.DI28(Din[3][4]),.DI29(Din[3][5]),.DI30(Din[3][6]),.DI31(Din[3][7]),
    .DI32(Din[4][0]),.DI33(Din[4][1]),.DI34(Din[4][2]),.DI35(Din[4][3]),.DI36(Din[4][4]),.DI37(Din[4][5]),.DI38(Din[4][6]),.DI39(Din[4][7]),
    .DI40(Din[5][0]),.DI41(Din[5][1]),.DI42(Din[5][2]),.DI43(Din[5][3]),.DI44(Din[5][4]),.DI45(Din[5][5]),.DI46(Din[5][6]),.DI47(Din[5][7]),
    .DI48(Din[6][0]),.DI49(Din[6][1]),.DI50(Din[6][2]),.DI51(Din[6][3]),.DI52(Din[6][4]),.DI53(Din[6][5]),.DI54(Din[6][6]),.DI55(Din[6][7]),
    .DI56(Din[7][0]),.DI57(Din[7][1]),.DI58(Din[7][2]),.DI59(Din[7][3]),.DI60(Din[7][4]),.DI61(Din[7][5]),.DI62(Din[7][6]),.DI63(Din[7][7]),
    .DI64(Din[8][0]),.DI65(Din[8][1]),.DI66(Din[8][2]),.DI67(Din[8][3]),.DI68(Din[8][4]),.DI69(Din[8][5]),.DI70(Din[8][6]),.DI71(Din[8][7]),
    .DI72(Din[9][0]),.DI73(Din[9][1]),.DI74(Din[9][2]),.DI75(Din[9][3]),.DI76(Din[9][4]),.DI77(Din[9][5]),.DI78(Din[9][6]),.DI79(Din[9][7]),
    .DI80(Din[10][0]),.DI81(Din[10][1]),.DI82(Din[10][2]),.DI83(Din[10][3]),.DI84(Din[10][4]),.DI85(Din[10][5]),.DI86(Din[10][6]),.DI87(Din[10][7]),
    .DI88(Din[11][0]),.DI89(Din[11][1]),.DI90(Din[11][2]),.DI91(Din[11][3]),.DI92(Din[11][4]),.DI93(Din[11][5]),.DI94(Din[11][6]),.DI95(Din[11][7]),
    .DI96(Din[12][0]),.DI97(Din[12][1]),.DI98(Din[12][2]),.DI99(Din[12][3]),.DI100(Din[12][4]),.DI101(Din[12][5]),.DI102(Din[12][6]),.DI103(Din[12][7]),
    .DI104(Din[13][0]),.DI105(Din[13][1]),.DI106(Din[13][2]),.DI107(Din[13][3]),.DI108(Din[13][4]),.DI109(Din[13][5]),.DI110(Din[13][6]),.DI111(Din[13][7]),
    .DI112(Din[14][0]),.DI113(Din[14][1]),.DI114(Din[14][2]),.DI115(Din[14][3]),.DI116(Din[14][4]),.DI117(Din[14][5]),.DI118(Din[14][6]),.DI119(Din[14][7]),
    .DI120(Din[15][0]),.DI121(Din[15][1]),.DI122(Din[15][2]),.DI123(Din[15][3]),.DI124(Din[15][4]),.DI125(Din[15][5]),.DI126(Din[15][6]),.DI127(Din[15][7]),
    
    .CK(clk),.WEB(WEB),.OE(1'b1),.CS(1'b1));

endmodule
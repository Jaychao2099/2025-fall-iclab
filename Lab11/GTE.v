//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   ICLAB 2025 Fall 
// Lab11 Exercise : Geometric Transform Engine (GTE)
//      File Name : GTE.v
//    Module Name : GTE
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

module GTE(
    // input signals
    clk,
    rst_n,
	
    in_valid_data,
	data,
	
    in_valid_cmd,
    cmd,    
	
    // output signals
    busy
);

input              clk;
input              rst_n;

input              in_valid_data;
input       [7:0]  data;

input              in_valid_cmd;
input      [17:0]  cmd;

output reg         busy;

//==================================================================
// parameter & integer
//==================================================================


//==================================================================
// reg & wire
//==================================================================

// -----------------------------------------------------
// MEM
// -----------------------------------------------------

// MEM_0, MEM_1, MEM_2, MEM_3: 8-bit width, 4096 depth
wire        mem0_web, mem1_web, mem2_web, mem3_web;
wire [11:0] mem0_addr, mem1_addr, mem2_addr, mem3_addr;
wire  [7:0] mem0_din, mem1_din, mem2_din, mem3_din;
wire  [7:0] mem0_dout, mem1_dout, mem2_dout, mem3_dout;

// MEM_4, MEM_5: 16-bit width, 2048 depth
wire        mem4_web, mem5_web;
wire [10:0] mem4_addr, mem5_addr;
wire [15:0] mem4_din, mem5_din;
wire [15:0] mem4_dout, mem5_dout;

// MEM_6, MEM_7: 32-bit width, 1024 depth
wire        mem6_web, mem7_web;
wire  [9:0] mem6_addr, mem7_addr;
wire [31:0] mem6_din, mem7_din;
wire [31:0] mem6_dout, mem7_dout;

//==================================================================
// design
//==================================================================






//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
/* 
  There are eight SRAMs in your GTE. You should not change the name of those SRAMs.
  TA will check the value in each SRAMs when your GTE is not busy.
  If you change the name of SRAMs below, you must get the fail in this lab.
  
  You should finish SRAM-related signals assignments for each SRAM.
*/
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// SRAM-related signals assignments
assign mem0_addr = 
assign mem0_web  = 
assign mem0_din  = 

assign mem1_addr = 
assign mem1_web  = 
assign mem1_din  = 

assign mem2_addr = 
assign mem2_web  = 
assign mem2_din  = 

assign mem3_addr = 
assign mem3_web  = 
assign mem3_din  = 

assign mem4_addr = 
assign mem4_web  = 
assign mem4_din  = 

assign mem5_addr = 
assign mem5_web  = 
assign mem5_din  = 

assign mem6_addr = 
assign mem6_web  = 
assign mem6_din  = 

assign mem7_addr = 
assign mem7_web  = 
assign mem7_din  = 

// MEM_0, MEM_1, MEM_2, MEM_3, MEM_4, MEM_5, MEM_6, MEM_7 instantiation
SUMA180_4096X8X1BM4 MEM0(
    .A0(mem0_addr[0]), .A1(mem0_addr[1]), .A2(mem0_addr[2]), .A3(mem0_addr[3]), .A4(mem0_addr[4]), .A5(mem0_addr[5]), .A6(mem0_addr[6]), .A7(mem0_addr[7]), 
    .A8(mem0_addr[8]), .A9(mem0_addr[9]), .A10(mem0_addr[10]), .A11(mem0_addr[11]),
    .DO0(mem0_dout[0]), .DO1(mem0_dout[1]), .DO2(mem0_dout[2]), .DO3(mem0_dout[3]), .DO4(mem0_dout[4]), .DO5(mem0_dout[5]), .DO6(mem0_dout[6]), .DO7(mem0_dout[7]),
    .DI0(mem0_din[0]), .DI1(mem0_din[1]), .DI2(mem0_din[2]), .DI3(mem0_din[3]), .DI4(mem0_din[4]), .DI5(mem0_din[5]), .DI6(mem0_din[6]), .DI7(mem0_din[7]),
    .CK(clk), .WEB(mem0_web), .OE(1'b1), .CS(1'b1)
);

SUMA180_4096X8X1BM4 MEM1(
    .A0(mem1_addr[0]), .A1(mem1_addr[1]), .A2(mem1_addr[2]), .A3(mem1_addr[3]), .A4(mem1_addr[4]), .A5(mem1_addr[5]), .A6(mem1_addr[6]), .A7(mem1_addr[7]), 
    .A8(mem1_addr[8]), .A9(mem1_addr[9]), .A10(mem1_addr[10]), .A11(mem1_addr[11]),
    .DO0(mem1_dout[0]), .DO1(mem1_dout[1]), .DO2(mem1_dout[2]), .DO3(mem1_dout[3]), .DO4(mem1_dout[4]), .DO5(mem1_dout[5]), .DO6(mem1_dout[6]), .DO7(mem1_dout[7]),
    .DI0(mem1_din[0]), .DI1(mem1_din[1]), .DI2(mem1_din[2]), .DI3(mem1_din[3]), .DI4(mem1_din[4]), .DI5(mem1_din[5]), .DI6(mem1_din[6]), .DI7(mem1_din[7]),
    .CK(clk), .WEB(mem1_web), .OE(1'b1), .CS(1'b1)
);

SUMA180_4096X8X1BM4 MEM2 (
    .A0(mem2_addr[0]), .A1(mem2_addr[1]), .A2(mem2_addr[2]), .A3(mem2_addr[3]), .A4(mem2_addr[4]), .A5(mem2_addr[5]), .A6(mem2_addr[6]), .A7(mem2_addr[7]),
    .A8(mem2_addr[8]), .A9(mem2_addr[9]), .A10(mem2_addr[10]), .A11(mem2_addr[11]),
    .DO0(mem2_dout[0]), .DO1(mem2_dout[1]), .DO2(mem2_dout[2]), .DO3(mem2_dout[3]), .DO4(mem2_dout[4]), .DO5(mem2_dout[5]), .DO6(mem2_dout[6]), .DO7(mem2_dout[7]),
    .DI0(mem2_din[0]), .DI1(mem2_din[1]), .DI2(mem2_din[2]), .DI3(mem2_din[3]), .DI4(mem2_din[4]), .DI5(mem2_din[5]), .DI6(mem2_din[6]), .DI7(mem2_din[7]),
    .CK(clk), .WEB(mem2_web), .OE(1'b1), .CS(1'b1)
);

SUMA180_4096X8X1BM4 MEM3(
    .A0(mem3_addr[0]), .A1(mem3_addr[1]), .A2(mem3_addr[2]), .A3(mem3_addr[3]), .A4(mem3_addr[4]), .A5(mem3_addr[5]), .A6(mem3_addr[6]), .A7(mem3_addr[7]), 
    .A8(mem3_addr[8]), .A9(mem3_addr[9]), .A10(mem3_addr[10]), .A11(mem3_addr[11]),
    .DO0(mem3_dout[0]), .DO1(mem3_dout[1]), .DO2(mem3_dout[2]), .DO3(mem3_dout[3]), .DO4(mem3_dout[4]), .DO5(mem3_dout[5]), .DO6(mem3_dout[6]), .DO7(mem3_dout[7]),
    .DI0(mem3_din[0]), .DI1(mem3_din[1]), .DI2(mem3_din[2]), .DI3(mem3_din[3]), .DI4(mem3_din[4]), .DI5(mem3_din[5]), .DI6(mem3_din[6]), .DI7(mem3_din[7]),
    .CK(clk), .WEB(mem3_web), .OE(1'b1), .CS(1'b1)
);

SUMA180_2048X16X1BM1 MEM4(
	.A0(mem4_addr[0]), .A1(mem4_addr[1]), .A2(mem4_addr[2]), .A3(mem4_addr[3]), .A4(mem4_addr[4]), .A5(mem4_addr[5]), .A6(mem4_addr[6]), .A7(mem4_addr[7]), 
	.A8(mem4_addr[8]), .A9(mem4_addr[9]), .A10(mem4_addr[10]),
	.DO0(mem4_dout[0]), .DO1(mem4_dout[1]), .DO2(mem4_dout[2]), .DO3(mem4_dout[3]), .DO4(mem4_dout[4]), .DO5(mem4_dout[5]), .DO6(mem4_dout[6]), .DO7(mem4_dout[7]), 
	.DO8(mem4_dout[8]), .DO9(mem4_dout[9]), .DO10(mem4_dout[10]), .DO11(mem4_dout[11]), .DO12(mem4_dout[12]), .DO13(mem4_dout[13]), .DO14(mem4_dout[14]), .DO15(mem4_dout[15]),
	.DI0(mem4_din[0]), .DI1(mem4_din[1]), .DI2(mem4_din[2]), .DI3(mem4_din[3]), .DI4(mem4_din[4]), .DI5(mem4_din[5]), .DI6(mem4_din[6]), .DI7(mem4_din[7]), 
	.DI8(mem4_din[8]), .DI9(mem4_din[9]), .DI10(mem4_din[10]), .DI11(mem4_din[11]), .DI12(mem4_din[12]), .DI13(mem4_din[13]), .DI14(mem4_din[14]), .DI15(mem4_din[15]),
	.CK(clk), .WEB(mem4_web), .OE(1'b1), .CS(1'b1)
);

SUMA180_2048X16X1BM1 MEM5(
	.A0(mem5_addr[0]), .A1(mem5_addr[1]), .A2(mem5_addr[2]), .A3(mem5_addr[3]), .A4(mem5_addr[4]), .A5(mem5_addr[5]), .A6(mem5_addr[6]), .A7(mem5_addr[7]), 
	.A8(mem5_addr[8]), .A9(mem5_addr[9]), .A10(mem5_addr[10]),
	.DO0(mem5_dout[0]), .DO1(mem5_dout[1]), .DO2(mem5_dout[2]), .DO3(mem5_dout[3]), .DO4(mem5_dout[4]), .DO5(mem5_dout[5]), .DO6(mem5_dout[6]), .DO7(mem5_dout[7]), 
	.DO8(mem5_dout[8]), .DO9(mem5_dout[9]), .DO10(mem5_dout[10]), .DO11(mem5_dout[11]), .DO12(mem5_dout[12]), .DO13(mem5_dout[13]), .DO14(mem5_dout[14]), .DO15(mem5_dout[15]),
	.DI0(mem5_din[0]), .DI1(mem5_din[1]), .DI2(mem5_din[2]), .DI3(mem5_din[3]), .DI4(mem5_din[4]), .DI5(mem5_din[5]), .DI6(mem5_din[6]), .DI7(mem5_din[7]), 
	.DI8(mem5_din[8]), .DI9(mem5_din[9]), .DI10(mem5_din[10]), .DI11(mem5_din[11]), .DI12(mem5_din[12]), .DI13(mem5_din[13]), .DI14(mem5_din[14]), .DI15(mem5_din[15]),
	.CK(clk), .WEB(mem5_web), .OE(1'b1), .CS(1'b1)
);

SUMA180_1024X32X1BM2 MEM6(
	.A0(mem6_addr[0]), .A1(mem6_addr[1]), .A2(mem6_addr[2]), .A3(mem6_addr[3]), .A4(mem6_addr[4]), .A5(mem6_addr[5]), .A6(mem6_addr[6]), .A7(mem6_addr[7]), 
	.A8(mem6_addr[8]), .A9(mem6_addr[9]),
	.DO0(mem6_dout[0]), .DO1(mem6_dout[1]), .DO2(mem6_dout[2]), .DO3(mem6_dout[3]), .DO4(mem6_dout[4]), .DO5(mem6_dout[5]), .DO6(mem6_dout[6]), .DO7(mem6_dout[7]), 
	.DO8(mem6_dout[8]), .DO9(mem6_dout[9]), .DO10(mem6_dout[10]), .DO11(mem6_dout[11]), .DO12(mem6_dout[12]), .DO13(mem6_dout[13]), .DO14(mem6_dout[14]), .DO15(mem6_dout[15]), 
	.DO16(mem6_dout[16]), .DO17(mem6_dout[17]), .DO18(mem6_dout[18]), .DO19(mem6_dout[19]), .DO20(mem6_dout[20]), .DO21(mem6_dout[21]), .DO22(mem6_dout[22]), .DO23(mem6_dout[23]), 
	.DO24(mem6_dout[24]), .DO25(mem6_dout[25]), .DO26(mem6_dout[26]), .DO27(mem6_dout[27]), .DO28(mem6_dout[28]), .DO29(mem6_dout[29]), .DO30(mem6_dout[30]), .DO31(mem6_dout[31]),
	.DI0(mem6_din[0]), .DI1(mem6_din[1]), .DI2(mem6_din[2]), .DI3(mem6_din[3]), .DI4(mem6_din[4]), .DI5(mem6_din[5]), .DI6(mem6_din[6]), .DI7(mem6_din[7]), 
	.DI8(mem6_din[8]), .DI9(mem6_din[9]), .DI10(mem6_din[10]), .DI11(mem6_din[11]), .DI12(mem6_din[12]), .DI13(mem6_din[13]), .DI14(mem6_din[14]), .DI15(mem6_din[15]), 
	.DI16(mem6_din[16]), .DI17(mem6_din[17]), .DI18(mem6_din[18]), .DI19(mem6_din[19]), .DI20(mem6_din[20]), .DI21(mem6_din[21]), .DI22(mem6_din[22]), .DI23(mem6_din[23]), 
	.DI24(mem6_din[24]), .DI25(mem6_din[25]), .DI26(mem6_din[26]), .DI27(mem6_din[27]), .DI28(mem6_din[28]), .DI29(mem6_din[29]), .DI30(mem6_din[30]), .DI31(mem6_din[31]),
	.CK(clk), .WEB(mem6_web), .OE(1'b1), .CS(1'b1)
);

SUMA180_1024X32X1BM2 MEM7(
	.A0(mem7_addr[0]), .A1(mem7_addr[1]), .A2(mem7_addr[2]), .A3(mem7_addr[3]), .A4(mem7_addr[4]), .A5(mem7_addr[5]), .A6(mem7_addr[6]), .A7(mem7_addr[7]), 
	.A8(mem7_addr[8]), .A9(mem7_addr[9]),
	.DO0(mem7_dout[0]), .DO1(mem7_dout[1]), .DO2(mem7_dout[2]), .DO3(mem7_dout[3]), .DO4(mem7_dout[4]), .DO5(mem7_dout[5]), .DO6(mem7_dout[6]), .DO7(mem7_dout[7]), 
	.DO8(mem7_dout[8]), .DO9(mem7_dout[9]), .DO10(mem7_dout[10]), .DO11(mem7_dout[11]), .DO12(mem7_dout[12]), .DO13(mem7_dout[13]), .DO14(mem7_dout[14]), .DO15(mem7_dout[15]), 
	.DO16(mem7_dout[16]), .DO17(mem7_dout[17]), .DO18(mem7_dout[18]), .DO19(mem7_dout[19]), .DO20(mem7_dout[20]), .DO21(mem7_dout[21]), .DO22(mem7_dout[22]), .DO23(mem7_dout[23]), 
	.DO24(mem7_dout[24]), .DO25(mem7_dout[25]), .DO26(mem7_dout[26]), .DO27(mem7_dout[27]), .DO28(mem7_dout[28]), .DO29(mem7_dout[29]), .DO30(mem7_dout[30]), .DO31(mem7_dout[31]),
	.DI0(mem7_din[0]), .DI1(mem7_din[1]), .DI2(mem7_din[2]), .DI3(mem7_din[3]), .DI4(mem7_din[4]), .DI5(mem7_din[5]), .DI6(mem7_din[6]), .DI7(mem7_din[7]), 
	.DI8(mem7_din[8]), .DI9(mem7_din[9]), .DI10(mem7_din[10]), .DI11(mem7_din[11]), .DI12(mem7_din[12]), .DI13(mem7_din[13]), .DI14(mem7_din[14]), .DI15(mem7_din[15]), 
	.DI16(mem7_din[16]), .DI17(mem7_din[17]), .DI18(mem7_din[18]), .DI19(mem7_din[19]), .DI20(mem7_din[20]), .DI21(mem7_din[21]), .DI22(mem7_din[22]), .DI23(mem7_din[23]), 
	.DI24(mem7_din[24]), .DI25(mem7_din[25]), .DI26(mem7_din[26]), .DI27(mem7_din[27]), .DI28(mem7_din[28]), .DI29(mem7_din[29]), .DI30(mem7_din[30]), .DI31(mem7_din[31]),
	.CK(clk), .WEB(mem7_web), .OE(1'b1), .CS(1'b1)
);

endmodule
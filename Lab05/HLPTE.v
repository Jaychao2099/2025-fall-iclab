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

SRAM_1024 s1 (A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,
              DO0,DO1,DO2,DO3,DO4,DO5,DO6,DO7,
              DI0,DI1,DI2,DI3,DI4,DI5,DI6,DI7,
              CK,WEB,OE, CS);


endmodule
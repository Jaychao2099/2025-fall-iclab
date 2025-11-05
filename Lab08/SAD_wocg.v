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


//==============================================//
//           reg & wire declaration             //
//==============================================//



//==============================================//
//                  design                      //
//==============================================//



endmodule
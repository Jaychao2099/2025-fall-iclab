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
output flag_clk1_to_handshake;


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
input             clk;
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


endmodule
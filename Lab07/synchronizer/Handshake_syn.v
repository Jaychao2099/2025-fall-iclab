module Handshake_syn #(parameter WIDTH=32) (
    sclk,
    dclk,
    rst_n,
    sready,
    din,
    dbusy,
    sidle,
    dvalid,
    dout,

    flag_handshake_to_clk1,
    flag_clk1_to_handshake,

    flag_handshake_to_clk2,
    flag_clk2_to_handshake
);

input sclk, dclk;
input rst_n;
input sready;
input [WIDTH-1:0] din;
input dbusy;

output sidle;
output reg dvalid;
output reg [WIDTH-1:0] dout;

// You can change the input / output of the custom flag ports
output flag_handshake_to_clk1;
input  flag_clk1_to_handshake;

output flag_handshake_to_clk2;
input  flag_clk2_to_handshake;

//---------------------------------------------------------------------
//   Reg / Wire / Parameters DECLARATION          
//---------------------------------------------------------------------

parameter ndff_width = 8;

// Remember:
//   Don't modify the signal name
reg  sreq;
wire dreq;
reg  dack;
wire sack;

reg [WIDTH-1:0] left_hand, right_hand;
reg src_ctrl, dest_ctrl;

//---------------------------------------------------------------------
//   Design      
//---------------------------------------------------------------------

// input dbusy;
// output reg dvalid;
always @(posedge dclk or rst_n) begin
    if (!rst_n) dvalid <= 1'b0;
    else        dvalid <= (dreq && !dbusy && dack) ? 1'b0 : 1'b1;
end

// output reg [WIDTH-1:0] dout;
always @(posedge dclk or rst_n) begin
    if (!rst_n) dout <= {WIDTH{1'b0}};
    else        dout <= (dreq && !dbusy) ? din : dout;
end

// output sidle;       tell src i'm idle
always @(posedge sclk or negedge rst_n)begin
    if      (!rst_n)                 sidle <= 1'b1;
    else if (sready || sreq || sack) sidle <= 1'b0;
    else                             sidle <= 1'b1;
end

// reg  sreq;
always @(posedge sclk or negedge rst_n) begin
    if     (!rst_n) sreq <= 1'b0;
    else if(sack)   sreq <= 1'b0;
    else if(sready) sreq <= 1'b1;
    else            sreq <= sreq;
end

// reg  dack;
always @(posedge dclk or negedge rst_n) begin
    if      (!rst_n)         dack <= 1'b0;
    else if (dreq && !dbusy) dack <= 1'b1;
    else                     dack <= 1'b0;
end

// output Q;
NDFF_syn ndff_1(.D(sreq), .Q(dreq), .clk(dclk), .rst_n(rst_n));
NDFF_syn ndff_2(.D(dack), .Q(sack), .clk(sclk), .rst_n(rst_n));

endmodule
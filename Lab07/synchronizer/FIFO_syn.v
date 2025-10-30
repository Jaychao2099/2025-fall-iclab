module FIFO_syn #(parameter WIDTH=16, parameter WORDS=64) (
    wclk,
    rclk,
    rst_n,
    winc,
    wdata,
    wfull,
    rinc,
    rdata,
    rempty,

    flag_fifo_to_clk2,
    flag_clk2_to_fifo,

    flag_fifo_to_clk3,
    flag_clk3_to_fifo
);

input wclk, rclk;
input rst_n;
input winc;
input [WIDTH-1:0] wdata;
output reg wfull;
input rinc;
output reg [WIDTH-1:0] rdata;
output reg rempty;

// You can change the input / output of the custom flag ports
output flag_fifo_to_clk2;
input  flag_clk2_to_fifo;

output flag_fifo_to_clk3;
input  flag_clk3_to_fifo;

wire [WIDTH-1:0] rdata_q;

// Remember: 
//   wptr and rptr should be gray coded
//   Don't modify the signal name
reg [$clog2(WORDS):0] wptr;
reg [$clog2(WORDS):0] rptr;

// rdata
//  Add one more register stage to rdata
always @(posedge rclk) begin
    if (rinc)
        rdata <= rdata_q;
end

DUAL_64X16X1BM1 u_dual_sram (
    .CKA(wclk),
    .CKB(rclk),
    .WEAN(),
    .WEBN(),
    .CSA(),
    .CSB(),
    .OEA(),
    .OEB(),
    .A0(),
    .A1(),
    .A2(),
    .A3(),
    .A4(),
    .A5(),
    .B0(),
    .B1(),
    .B2(),
    .B3(),
    .B4(),
    .B5(),
    .DIA0(),
    .DIA1(),
    .DIA2(),
    .DIA3(),
    .DIA4(),
    .DIA5(),
    .DIA6(),
    .DIA7(),
    .DIA8(),
    .DIA9(),
    .DIA10(),
    .DIA11(),
    .DIA12(),
    .DIA13(),
    .DIA14(),
    .DIA15(),
    .DIB0(),
    .DIB1(),
    .DIB2(),
    .DIB3(),
    .DIB4(),
    .DIB5(),
    .DIB6(),
    .DIB7(),
    .DIB8(),
    .DIB9(),
    .DIB10(),
    .DIB11(),
    .DIB12(),
    .DIB13(),
    .DIB14(),
    .DIB15(),
    .DOB0(rdata_q[0]),
    .DOB1(rdata_q[1]),
    .DOB2(rdata_q[2]),
    .DOB3(rdata_q[3]),
    .DOB4(rdata_q[4]),
    .DOB5(rdata_q[5]),
    .DOB6(rdata_q[6]),
    .DOB7(rdata_q[7]),
    .DOB8(rdata_q[8]),
    .DOB9(rdata_q[9]),
    .DOB10(rdata_q[10]),
    .DOB11(rdata_q[11]),
    .DOB12(rdata_q[12]),
    .DOB13(rdata_q[13]),
    .DOB14(rdata_q[14]),
    .DOB15(rdata_q[15])
);


endmodule

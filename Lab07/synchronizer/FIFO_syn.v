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
output wfull;

input rinc;
output reg [WIDTH-1:0] rdata;
output rempty;

// You can change the input / output of the custom flag ports
output flag_fifo_to_clk2;
input  flag_clk2_to_fifo;

output flag_fifo_to_clk3;
input  flag_clk3_to_fifo;

//---------------------------------------------------------------------
//   Reg / Wire / Parameters DECLARATION          
//---------------------------------------------------------------------

wire wen_a;
reg [6:0] w_addr, r_addr;

wire [WIDTH-1:0] rdata_q;

// Remember: 
//   wptr and rptr should be gray coded
//   Don't modify the signal name
wire [$clog2(WORDS):0] wptr;     // 7-bit
wire [$clog2(WORDS):0] rptr;     // 7-bit

//---------------------------------------------------------------------
//   Design      
//---------------------------------------------------------------------

// output reg [WIDTH-1:0] rdata;
//  Add one more register stage to rdata
always @(posedge rclk or negedge rst_n) begin
    if      (!rst_n) rdata <= 16'd0;
    else if (rinc)   rdata <= rdata_q;
    else             rdata <= rdata;
end

// output wfull;
assign wfull = ({~w_addr[6], w_addr[5:0]} == r_addr);
// output rempty;
assign rempty = (w_addr == r_addr);

// wire wen_a;
assign wen_a = winc & ~wfull;

// reg [6:0] w_addr
always @(posedge wclk or negedge rst_n) begin
    if      (!rst_n) w_addr <= 7'd0;
    else if (wen_a)  w_addr <= w_addr + 7'd1;
    else             w_addr <= w_addr;
end

// reg [6:0] r_addr
always @(posedge rclk or negedge rst_n) begin
    if      (!rst_n)          r_addr <= 7'd0;
    else if (rinc && !rempty) r_addr <= r_addr + 7'd1;
    else                      r_addr <= r_addr;
end

// gray code
// wire [$clog2(WORDS):0] wptr;     // 7-bit
assign wptr = (w_addr >> 1) ^ w_addr;
// wire [$clog2(WORDS):0] rptr;     // 7-bit
assign rptr = (r_addr >> 1) ^ r_addr;

wire [$clog2(WORDS):0] sync_rptr, sync_wptr;     // 7-bit
wire [$clog2(WORDS):0] sync_rptr_reg, sync_wptr_reg;     // 7-bit

NDFF_BUS_syn #($clog2(WORDS)+1) ndff_1(.D(rptr), .Q(sync_rptr), .clk(wclk), .rst_n(rst_n));
NDFF_BUS_syn #($clog2(WORDS)+1) ndff_2(.D(wptr), .Q(sync_wptr), .clk(rclk), .rst_n(rst_n));

// wire [$clog2(WORDS):0] sync_rptr_reg;     // 7-bit
always @(posedge wclk or negedge rst_n) begin
    if (!rst_n) sync_rptr_reg <= 7'd0;
    else        sync_rptr_reg <= sync_rptr;
end

// wire [$clog2(WORDS):0] sync_wptr_reg;     // 7-bit
always @(posedge rclk or negedge rst_n) begin
    if (!rst_n) sync_wptr_reg <= 7'd0;
    else        sync_wptr_reg <= sync_wptr;
end

DUAL_64X16X1BM1 u_dual_sram (
    .CKA(wclk), .CKB(rclk),
    .WEAN(wen_a), .WEBN(1'b0),
    
    .CSA(1'b1), .CSB(1'b1),
    .OEA(1'b1), .OEB(1'b1),
    
    .A0(w_addr[0]), .A1(w_addr[1]), .A2(w_addr[2]), .A3(w_addr[3]), .A4(w_addr[4]), .A5(w_addr[5]),
    .B0(r_addr[0]), .B1(r_addr[1]), .B2(r_addr[2]), .B3(r_addr[3]), .B4(r_addr[4]), .B5(r_addr[5]),

    .DIA0(wdata[0]), 
    .DIA1(wdata[1]),  
    .DIA2(wdata[2]),  
    .DIA3(wdata[3]),   
    .DIA4(wdata[4]),   
    .DIA5(wdata[5]),   
    .DIA6(wdata[6]),   
    .DIA7(wdata[7]),
    .DIA8(wdata[8]), 
    .DIA9(wdata[9]), 
    .DIA10(wdata[10]), 
    .DIA11(wdata[11]), 
    .DIA12(wdata[12]), 
    .DIA13(wdata[13]), 
    .DIA14(wdata[14]), 
    .DIA15(wdata[15]),
    
    .DIB0(), .DIB1(), .DIB2(), .DIB3(), .DIB4(), .DIB5(), .DIB6(), .DIB7(),
    .DIB8(), .DIB9(), .DIB10(), .DIB11(), .DIB12(), .DIB13(), .DIB14(), .DIB15(),
    
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

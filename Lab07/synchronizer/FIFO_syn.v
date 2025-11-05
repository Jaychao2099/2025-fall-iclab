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
// output reg flag_fifo_to_clk3;
input  flag_clk3_to_fifo;

//---------------------------------------------------------------------
//   Reg / Wire / Parameters DECLARATION          
//---------------------------------------------------------------------

wire wen_a;
wire [6:0] w_addr, r_addr;
reg  [6:0] w_addr_reg, r_addr_reg;

wire [WIDTH-1:0] rdata_q;

// Remember: 
//   wptr and rptr should be gray coded
//   Don't modify the signal name
wire [$clog2(WORDS):0] wptr;     // 7-bit
wire [$clog2(WORDS):0] rptr;     // 7-bit
reg [$clog2(WORDS):0] wptr_reg;     // 7-bit
reg [$clog2(WORDS):0] rptr_reg;     // 7-bit

wire [$clog2(WORDS):0] sync_rptr, sync_wptr;     // 7-bit
// reg  [$clog2(WORDS):0] sync_rptr_reg, sync_wptr_reg;     // 7-bit

//---------------------------------------------------------------------
//   Design      
//---------------------------------------------------------------------

reg rinc_reg;

always @(posedge rclk) begin
    rinc_reg <= rinc;
end

// output reg [WIDTH-1:0] rdata;
//  Add one more register stage to rdata
always @(posedge rclk or negedge rst_n) begin
    if      (!rst_n)           rdata <= 16'd0;
    else if (rinc || rinc_reg) rdata <= rdata_q;
    else                       rdata <= rdata;
end

wire wfull_condition;

// assign wfull_condition = ({~wptr[6:5], wptr[4:0]} == sync_rptr);
assign wfull_condition = (wptr[6] != sync_rptr[6]) &&
                         (wptr[5] != sync_rptr[5]) &&
                         (wptr[4] == sync_rptr[4]) &&
                         (wptr[3] == sync_rptr[3]) &&
                         (wptr[2] == sync_rptr[2]) &&
                         (wptr[1] == sync_rptr[1]) &&
                         (wptr[0] == sync_rptr[0]);

// output wfull;
// assign wfull = ({~wptr[6], wptr[5:0]} == sync_rptr);
always @(posedge wclk or negedge rst_n) begin
    if (!rst_n) wfull <= 1'b0;
    // else        wfull <= ({~wptr[6], wptr[5:0]} == sync_rptr);
    else        wfull <= wfull_condition;
end
// output rempty;
// assign rempty = (sync_wptr == rptr);
always @(posedge rclk or negedge rst_n)begin
    if (!rst_n) rempty <= 1'b1;
    // else        rempty <= (sync_wptr == rptr);
    else        rempty <= (sync_wptr[6] == rptr[6]) &&
                          (sync_wptr[5] == rptr[5]) &&
                          (sync_wptr[4] == rptr[4]) &&
                          (sync_wptr[3] == rptr[3]) &&
                          (sync_wptr[2] == rptr[2]) &&
                          (sync_wptr[1] == rptr[1]) &&
                          (sync_wptr[0] == rptr[0]);
end

// wire wen_a;
assign wen_a = ~winc | wfull;
// assign wen_a = ~winc;

// reg [6:0] w_addr
// always @(*) begin
//     // w_addr = w_addr_reg + (~wen_a);
//     w_addr = w_addr_reg + (winc & ~wfull);
//     // if (!wen_a) w_addr = w_addr_reg + 7'd1;
//     // else        w_addr = w_addr_reg;
// end
assign w_addr = w_addr_reg + (winc & ~wfull);

// reg [6:0] w_addr_reg
always @(posedge wclk or negedge rst_n) begin
    if (!rst_n) w_addr_reg <= 7'd0;
    else        w_addr_reg <= w_addr;
end

// reg [6:0] r_addr
// always @(*) begin
//     r_addr = r_addr_reg + (rinc & ~rempty);
//     // if (rinc && !rempty) r_addr = r_addr_reg + 7'd1;
//     // else                 r_addr = r_addr_reg;
// end
assign r_addr = r_addr_reg + (rinc & ~rempty);

// reg [6:0] r_addr_reg
always @(posedge rclk or negedge rst_n) begin
    if (!rst_n) r_addr_reg <= 7'd0;
    else        r_addr_reg <= r_addr;
end

// gray code
// wire [$clog2(WORDS):0] wptr;     // 7-bit
assign wptr = (w_addr >> 1) ^ w_addr;

// wire [$clog2(WORDS):0] rptr;     // 7-bit
assign rptr = (r_addr >> 1) ^ r_addr;

// reg [$clog2(WORDS):0] wptr_reg;     // 7-bit
always @(posedge wclk or negedge rst_n) begin
    if (!rst_n) wptr_reg <= 7'd0;
    else wptr_reg <= wptr;
end

// reg [$clog2(WORDS):0] rptr_reg;     // 7-bit
always @(posedge rclk or negedge rst_n) begin
    if (!rst_n) rptr_reg <= 7'd0;
    else rptr_reg <= rptr;
end

// wire [$clog2(WORDS):0] sync_rptr, sync_wptr;     // 7-bit
NDFF_BUS_syn #($clog2(WORDS)+1) ndff_1(.D(rptr_reg), .Q(sync_rptr), .clk(wclk), .rst_n(rst_n));
NDFF_BUS_syn #($clog2(WORDS)+1) ndff_2(.D(wptr_reg), .Q(sync_wptr), .clk(rclk), .rst_n(rst_n));

DUAL_64X16X1BM1 u_dual_sram (
    .CKA(wclk), .CKB(rclk),
    .WEAN(wen_a), .WEBN(1'b1),
    
    .CSA(1'b1), .CSB(1'b1),
    .OEA(1'b1), .OEB(1'b1),
    
    .A0(w_addr_reg[0]), .A1(w_addr_reg[1]), .A2(w_addr_reg[2]), .A3(w_addr_reg[3]), .A4(w_addr_reg[4]), .A5(w_addr_reg[5]),
    .B0(r_addr_reg[0]), .B1(r_addr_reg[1]), .B2(r_addr_reg[2]), .B3(r_addr_reg[3]), .B4(r_addr_reg[4]), .B5(r_addr_reg[5]),

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

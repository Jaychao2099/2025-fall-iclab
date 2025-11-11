//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   (C) Copyright Laboratory System Integration and Silicon Implementation
//   All Right Reserved
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   ICLAB 2021 Final Project: Customized ISA Processor 
//   Author              : Hsi-Hao Huang
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   File Name   : CPU.v
//   Module Name : CPU.v
//   Release version : V1.0 (Release Date: 2021-May)
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

// Finish:
//      R-type
//      


// TODO:
//      I-type


module CPU(

				clk,
			  rst_n,
  
		   IO_stall,

         awid_m_inf,
       awaddr_m_inf,
       awsize_m_inf,
      awburst_m_inf,
        awlen_m_inf,
      awvalid_m_inf,
      awready_m_inf,
                    
        wdata_m_inf,
        wlast_m_inf,
       wvalid_m_inf,
       wready_m_inf,
                    
          bid_m_inf,
        bresp_m_inf,
       bvalid_m_inf,
       bready_m_inf,
                    
         arid_m_inf,
       araddr_m_inf,
        arlen_m_inf,
       arsize_m_inf,
      arburst_m_inf,
      arvalid_m_inf,
                    
      arready_m_inf, 
          rid_m_inf,
        rdata_m_inf,
        rresp_m_inf,
        rlast_m_inf,
       rvalid_m_inf,
       rready_m_inf 

);
// Input port
input  wire clk, rst_n;
// Output port
output reg  IO_stall;   //  should be low for one cycle whenever finished an instruction

parameter ID_WIDTH = 4 , ADDR_WIDTH = 32, DATA_WIDTH = 16, DRAM_NUMBER=2, WRIT_NUMBER=1;

// AXI Interface wire connecttion for pseudo DRAM read/write
/* Hint:
  your AXI-4 interface could be designed as convertor in submodule(which used reg for output signal),
  therefore I declared output of AXI as wire in CPU
*/



// axi write address channel 
output  wire [WRIT_NUMBER * ID_WIDTH-1:0]        awid_m_inf;    // Write address ID
output  wire [WRIT_NUMBER * ADDR_WIDTH-1:0]    awaddr_m_inf;    // Write address 32-bit. the address of the first transfer in a write burst tx
output  wire [WRIT_NUMBER * 3 -1:0]            awsize_m_inf;    // Burst size. only (3'b001)
output  wire [WRIT_NUMBER * 2 -1:0]           awburst_m_inf;    // Burst type. only INCR(2’b01)
output  wire [WRIT_NUMBER * 7 -1:0]             awlen_m_inf;    // Burst length
output  wire [WRIT_NUMBER-1:0]                awvalid_m_inf;    // Write address valid, stay stable until AWREADY goes HIGH.
input   wire [WRIT_NUMBER-1:0]                awready_m_inf;    // Write address ready. DRAM is ready to accept signals
// axi write data channel 
output  wire [WRIT_NUMBER * DATA_WIDTH-1:0]     wdata_m_inf;    // Write data. 16-bit
output  wire [WRIT_NUMBER-1:0]                  wlast_m_inf;    // Write last. high means current transfer is the last write burst.
output  wire [WRIT_NUMBER-1:0]                 wvalid_m_inf;    // Write valid. write data and strobes available
input   wire [WRIT_NUMBER-1:0]                 wready_m_inf;    // Write ready. DRAM is ready to accept the write data
// axi write response channel
input   wire [WRIT_NUMBER * ID_WIDTH-1:0]         bid_m_inf;    // Response ID. must match the AWID value
input   wire [WRIT_NUMBER * 2 -1:0]             bresp_m_inf;    // Write response. only OKAY(2’b00)
input   wire [WRIT_NUMBER-1:0]             	   bvalid_m_inf;    // Write response valid. means a valid write response is available
output  wire [WRIT_NUMBER-1:0]                 bready_m_inf;    // Response ready. CPU can accept the response information
// -----------------------------
// axi read address channel 
output  wire [DRAM_NUMBER * ID_WIDTH-1:0]       arid_m_inf;    // Read address ID. 
output  wire [DRAM_NUMBER * ADDR_WIDTH-1:0]   araddr_m_inf;    // Read address. 32-bit * 2. address of the first transfer in a read burst tx. high = inst, low = data
output  wire [DRAM_NUMBER * 7 -1:0]            arlen_m_inf;    // Burst length.
output  wire [DRAM_NUMBER * 3 -1:0]           arsize_m_inf;    // Burst size. This signal indicates the size of each transfer in the burst. only (3'b001)
output  wire [DRAM_NUMBER * 2 -1:0]          arburst_m_inf;    // Burst type. only INCR(2'b01)
output  wire [DRAM_NUMBER-1:0]               arvalid_m_inf;    // Read address valid, stay stable until ARREADY goes HIGH.
input   wire [DRAM_NUMBER-1:0]               arready_m_inf;    // Read address ready. DRAM is ready to accept signals
// -----------------------------
// axi read data channel 
input   wire [DRAM_NUMBER * ID_WIDTH-1:0]         rid_m_inf;    // Read ID tag. must match the ARID value
input   wire [DRAM_NUMBER * DATA_WIDTH-1:0]     rdata_m_inf;    // Read data. 16-bit
input   wire [DRAM_NUMBER * 2 -1:0]             rresp_m_inf;    // Read response.  only OKAY(2'b00)
input   wire [DRAM_NUMBER-1:0]                  rlast_m_inf;    // Read last. high means current transfer is the last transfer in a read burst.
input   wire [DRAM_NUMBER-1:0]                 rvalid_m_inf;    // Read valid.  read data available
output  wire [DRAM_NUMBER-1:0]                 rready_m_inf;    // Read ready. DRAM can accept the read data and response information
// -----------------------------

//
//
// 
/* Register in each core:
  There are sixteen registers in your CPU. You should not change the name of those registers.
  TA will check the value in each register when your core is not busy.
  If you change the name of registers below, you must get the fail in this lab.
*/

reg signed [15:0] core_r0 , core_r1 , core_r2 , core_r3 ;
reg signed [15:0] core_r4 , core_r5 , core_r6 , core_r7 ;
reg signed [15:0] core_r8 , core_r9 , core_r10, core_r11;
reg signed [15:0] core_r12, core_r13, core_r14, core_r15;


//####################################################
//               reg & wire
//####################################################

parameter offset = 16'h1000;




//###########################################
//
// Wrtie down your design below
//
//###########################################

// -------------------- FSM --------------------

localparam S_INIT_FETCH = 0;
localparam S_FETCH      = 1;
localparam S_DECODE     = 2;
localparam S_EXECUTE    = 3;
localparam S_MEMORY     = 4;
localparam S_WRITE_BACK = 5;

reg [2:0] current_state, next_state;

// reg [2:0] current_state;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) current_state <= S_INIT_FETCH;
    else        current_state <= next_state;
end

//  FSM：
// FETCH: 從指令記憶體中，根據 PC 的位址讀取指令。
// DECODE: 解析指令，例如 ADD rd, rs, rt。你會知道 opcode 是 ADD，來源是 rs 和 rt，目的地是 rd。同時，從 Register File 讀出 rs 和 rt 的值。
// EXECUTE: 將 rs 和 rt 的值送入 ALU，並設定 ALU 執行加法。
// WRITE_BACK: 將 ALU 的運算結果寫回 rd 所指定的暫存器。

// reg [2:0] next_state;
always @(*) begin
    case (current_state)
        S_INIT_FETCH: begin
            // if (/*AXI*/) ...
            // else next_state = S_INIT_FETCH;
        end
        S_FETCH: begin
            next_state = S_DECODE;
        end
        S_DECODE: begin
            case (opcode)
                5, 6:    next_state = S_FETCH;      // branch, jump
                default: next_state = S_EXECUTE;
            endcase
        end
        S_EXECUTE: begin
            case (opcode)
                0:       next_state = S_WRITE_BACK;                     // +, -, <
                1:       next_state = func ? S_WRITE_BACK : S_EXECUTE;  // mult (func == 0) 2 cycle
                default: next_state = S_MEMORY;                         // lw, sw
            endcase
        end
        S_MEMORY: begin
        end
        S_WRITE_BACK: begin
            next_state = S_FETCH;
        end
        default: next_state = current_state;
    endcase
end

reg [9:0] PC;

// reg [9:0] PC;    "16-bit word" word address, need (PC << 1) + 0x1000 for using in memory,
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) PC <= 10'd0;
    else if (current_state != S_IDLE) begin
        case (opcode)
            4:       PC <= PC + 10'd1 + imm;
            5:       PC <= j_addr;
            default: PC <= PC + 10'd1;
        endcase
    end
end

reg [15:0] now_inst;

wire [2:0]  opcode = now_inst[15:13];
wire [3:0]  rs     = now_inst[12:9];
wire [3:0]  rt     = now_inst[8:5];
wire [3:0]  rd     = now_inst[4:1];
wire        func   = now_inst[0];
wire [4:0]  imm    = now_inst[4:0];
wire [12:0] j_addr = now_inst[12:0];

// -------------------- R-type --------------------
// 設計 Datapath：

// 建立一個 16x16-bit 的 Register File (可以用 reg [15:0] core_registers [15:0];，
// 但在取用時要根據指令的 rs, rt 索引來讀取 core_r0, core_r1 等)。
// 注意： 專案規範說不能用二維陣列改寫 core_r，所以你需要用一個大的 case 或 if-else 語句來根據 rs, rt, rd 的位址來讀寫對應的 core_rX 暫存器。這很繁瑣，但必須遵守。

// 建立一個簡單的 ALU，它能接收兩個 16-bit 輸入，並根據一個控制訊號（例如 ALU_op）來執行加法或減法。

// ADD  rd = rs + rt                        R  000-rs-rt-rd-1 
// SUB  rd = rs – rt                        R  000-rs-rt-rd-0 
// Set  less than  if(rs<rt) rd=1 else rd=0 R  001-rs-rt-rd-1 
// Mult rd = rs * rt (16’b LSB)             R  001-rs-rt-rd-0 

reg signed [15:0] rs_value, rt_value, rd_value;

// reg signed [15:0] rs_value;
always @(posedge clk) begin
    case (now_inst[12:9])
        0: rs_value <= core_r0;
        1: rs_value <= core_r1;
        2: rs_value <= core_r2;
        3: rs_value <= core_r3;
        4: rs_value <= core_r4;
        5: rs_value <= core_r5;
        6: rs_value <= core_r6;
        7: rs_value <= core_r7;
        8: rs_value <= core_r8;
        9: rs_value <= core_r9;
        10: rs_value <= core_r10;
        11: rs_value <= core_r11;
        12: rs_value <= core_r12;
        13: rs_value <= core_r13;
        14: rs_value <= core_r14;
        default: rs_value <= core_r15;
    endcase
end

// reg signed [15:0] rt_value;
always @(posedge clk) begin
    case (now_inst[8:5])
        0: rt_value <= core_r0;
        1: rt_value <= core_r1;
        2: rt_value <= core_r2;
        3: rt_value <= core_r3;
        4: rt_value <= core_r4;
        5: rt_value <= core_r5;
        6: rt_value <= core_r6;
        7: rt_value <= core_r7;
        8: rt_value <= core_r8;
        9: rt_value <= core_r9;
        10: rt_value <= core_r10;
        11: rt_value <= core_r11;
        12: rt_value <= core_r12;
        13: rt_value <= core_r13;
        14: rt_value <= core_r14;
        default: rt_value <= core_r15;
    endcase
end

reg [1:0] alu_op;

// wire [2:0]  opcode = now_inst[15:13];
// wire [3:0]  rs     = now_inst[12:9];
// wire [3:0]  rt     = now_inst[8:5];
// wire [3:0]  rd     = now_inst[4:1];
// wire        func   = now_inst[0];
// wire [4:0]  imm    = now_inst[4:0];
// wire [12:0] j_addr = now_inst[12:0];

// ADD  rd = rs + rt                        R  000-rs-rt-rd-1, alu_op = 0(00)
// SUB  rd = rs – rt                        R  000-rs-rt-rd-0, alu_op = 1(01)
// Mult rd = rs * rt (16’b LSB)             R  001-rs-rt-rd-0, alu_op = 2(10)
// Set  less than  if(rs<rt) rd=1 else rd=0 R  001-rs-rt-rd-1, alu_op = 3(11)

// Load  rt = DM[sign(rs+immediate) × 2 + offset ]        I  011-rs-rt-iiiii, alu_op = 0(00)
// Store DM[sign(rs+immediate) × 2 + offset ] = rt        I  010-rs-rt-iiiii, alu_op = 0(00)

// Beq   if(rs==rt) pc=pc+1+immediate(sign) else pc=pc+1   I  101-rs-rt-iiiii
// Jump  Next instruction address = address (range: 0x1000~0x2fff) J 100-address

// reg [1:0] alu_op;
always @(posedge clk) begin
    case (opcode)
        3'd0:    alu_op <= {1'b0, ~func};  // add(+) or sub(-)
        3'd1:    alu_op <= {1'b1,  func};  // mult(*) or slt(-)
        default: alu_op <= 2'd0;           // lw/sw(+)
    endcase
end

reg signed [15:0] imm_extend;

always @(posedge clk) begin
    imm_extend <= {{11{imm[4]}}, imm};
end

reg signed [15:0] alu_b, alu_z;

// reg signed [15:0] alu_b
always @(*) begin
    case (opcode)
        0, 1:    alu_b = rt_value;
        default: alu_b = imm_extend;
    endcase
end

// reg signed [15:0] alu_z;
ALU alu(.clk(clk), .alu_a(rs_value), .alu_b(rt_value), .op(alu_op), .alu_z(rd_value));





reg signed [15:0] reg_write_value;

// reg signed [15:0] reg_write_value;
always @(posedge clk) begin
    if (current_state == S_WRITE_BACK) begin
        case (opcode)
            0, 1: reg_write_value <= rd_value;      // +, -, <, *
            // 3:    reg_write_value <= ;           // load
            default: reg_write_value <= reg_write_value;    // store, branch, jump
        endcase
    end
    else reg_write_value <= reg_write_value;
end






// -------------------- Cache --------------------

reg [2:0] Tag_d, Tag_i;
reg [6:0] Index_d, Index_i;
reg [15:0] Din_d;
wire [15:0] Dout_d, Dout_i;
reg WEB_d;

CACHE_INTERFACE data_cache(.Tag(Tag_d), .Index(Index_d), .Din(Din_d), .Dout(Dout_d), .clk(clk), .WEB(WEB_d));
CACHE_INTERFACE inst_cache(.Tag(Tag_i), .Index(Index_i), .Din(),      .Dout(Dout_i), .clk(clk), .WEB(1'b0));




// -------------------- DRAM --------------------
pseudo_DRAM_data dram_data(
// global signals 
      .clk(clk),
      .rst_n(rst_n),
// axi write address channel 
      .awid_s_inf(   awid_m_inf[3:0]  ),
    .awaddr_s_inf( awaddr_m_inf[31:0] ),
    .awsize_s_inf( awsize_m_inf[2:0]  ),
   .awburst_s_inf(awburst_m_inf[1:0]  ),
     .awlen_s_inf(  awlen_m_inf[6:0]  ),
   .awvalid_s_inf(awvalid_m_inf[0]    ),
   .awready_s_inf(awready_m_inf[0]    ),
// axi write data channel 
     .wdata_s_inf(  wdata_m_inf[15:0] ),
     .wlast_s_inf(  wlast_m_inf[0]    ),
    .wvalid_s_inf( wvalid_m_inf[0]    ),
    .wready_s_inf( wready_m_inf[0]    ),
// axi write response channel
       .bid_s_inf(    bid_m_inf[3:0]  ),
     .bresp_s_inf(  bresp_m_inf[1:0]  ),
    .bvalid_s_inf( bvalid_m_inf[0]    ),
    .bready_s_inf( bready_m_inf[0]    ),
// axi read address channel 
      .arid_s_inf(   arid_m_inf[3:0]  ),
    .araddr_s_inf( araddr_m_inf[31:0] ),
     .arlen_s_inf(  arlen_m_inf[6:0]  ),
    .arsize_s_inf( arsize_m_inf[2:0]  ),
   .arburst_s_inf(arburst_m_inf[1:0]  ),
   .arvalid_s_inf(arvalid_m_inf[0]    ),
   .arready_s_inf(arready_m_inf[0]    ), 
// axi read data channel 
       .rid_s_inf(    rid_m_inf[3:0]  ),
     .rdata_s_inf(  rdata_m_inf[15:0] ),
     .rresp_s_inf(  rresp_m_inf[1:0]  ),
     .rlast_s_inf(  rlast_m_inf[0]    ),
    .rvalid_s_inf( rvalid_m_inf[0]    ),
    .rready_s_inf( rready_m_inf[0]    ) 
);

pseudo_DRAM_inst dram_inst(
// global signals 
      .clk(clk),
      .rst_n(rst_n),
// axi read address channel 
      .arid_s_inf(   arid_m_inf[7:4]   ),
    .araddr_s_inf( araddr_m_inf[63:32] ),
    .arlen_s_inf(  arlen_m_inf[13:7]   ),
    .arsize_s_inf( arsize_m_inf[5:3]   ),
   .arburst_s_inf(arburst_m_inf[3:2]   ),
   .arvalid_s_inf(arvalid_m_inf[1]     ),
   .arready_s_inf(arready_m_inf[1]     ), 
// axi read data channel 
       .rid_s_inf(    rid_m_inf[7:4]   ),
     .rdata_s_inf(  rdata_m_inf[31:16] ),
     .rresp_s_inf(  rresp_m_inf[3:2]   ),
     .rlast_s_inf(  rlast_m_inf[1]     ),
    .rvalid_s_inf( rvalid_m_inf[1]     ),
    .rready_s_inf( rready_m_inf[1]     ) 
);

endmodule


module ALU (
    input clk,
    input signed [15:0] alu_a, 
    input signed [15:0] alu_b, 
    input [1:0] op, 
    output signed reg [15:0] alu_z
);

// ADD  rd = rs + rt                        R  000-rs-rt-rd-1 0
// SUB  rd = rs – rt                        R  000-rs-rt-rd-0 1
// Mult rd = rs * rt (16’b LSB)             R  001-rs-rt-rd-0 2
// Set  less than  if(rs<rt) rd=1 else rd=0 R  001-rs-rt-rd-1 3

// Load  rt = DM[sign(rs+immediate) × 2 + offset ]   I  011-rs-rt-iiiii, alu_op = 0(00)
// Store DM[sign(rs+immediate) × 2 + offset ] = rt   I  010-rs-rt-iiiii, alu_op = 0(00)

wire addsub_op = op[0];  // sub
wire signed [15:0] addsub_z;
wire signed [31:0] mult_z;

DW01_addsub       #(16)     addsub (.A(alu_a), .B(alu_b), .CI(1'b0), .ADD_SUB(addsub_op), .SUM(addsub_z), .CO() );
DW02_mult_2_stage #(16, 16) mult_2 (.A(alu_a), .B(alu_b), .TC(1'b1), .CLK(clk), .PRODUCT(mult_z) );

// output signed reg [15:0] alu_z
always @(posedge clk) begin
    case (op)
        2:       alu_z <= mult_z[15:0];
        3:       alu_z <= {14'd0, addsub_z[15]};
        default: alu_z <= addsub_z;
    endcase
end

endmodule



module CACHE_INTERFACE (
    input [2:0] Tag,    // 1024 byte space ---> 10-bit - 7-bit = 3-bit LSB addr
    input [6:0] Index,  // 128 cacheline (7-bit MSB addr)
    input [15:0] Din,
    output [15:0] Dout,
    input clk,
    input WEB
);
// [ Tag | Index ]

wire [13:0] address = {Tag, Index};      // 0x1000 ~ 0x2FFF -----> 0x2000 bytes space = 1024 16-bit words ------> 10-bit

SRAM_xxxxx sram_1 (.A0(address[0]), /* TODO: make a sram */
                   .A1(address[1]), 
                   .A2(address[2]), 
                   .A3(address[3]), 
                   .A4(address[4]), 
                   .A5(address[5]), 
                   .A6(address[6]), 
                   .A7(address[7]), 
                   .A8(address[8]), 
                   .A9(address[9]),

                   .DO0(Dout[0]),
                   .DO1(Dout[1]),
                   .DO2(Dout[2]),
                   .DO3(Dout[3]),
                   .DO4(Dout[4]),
                   .DO5(Dout[5]),
                   .DO6(Dout[6]),
                   .DO7(Dout[7]),
                   .DO8(Dout[8]),
                   .DO9(Dout[9]),
                   .DO10(Dout[10]),
                   .DO11(Dout[11]),
                   .DO12(Dout[12]),
                   .DO13(Dout[13]),
                   .DO14(Dout[14]),
                   .DO15(Dout[15]),

                   .DI0(Din[0]),
                   .DI1(Din[1]),
                   .DI2(Din[2]),
                   .DI3(Din[3]),
                   .DI4(Din[4]),
                   .DI5(Din[5]),
                   .DI6(Din[6]),
                   .DI7(Din[7]),
                   .DI8(Din[8]),
                   .DI9(Din[9]),
                   .DI10(Din[10]),
                   .DI11(Din[11]),
                   .DI12(Din[12]),
                   .DI13(Din[13]),
                   .DI14(Din[14]),
                   .DI15(Din[15]),

                   .CK(clk),.WEB(WEB),.OE(1'b1),.CS(1'b1));

endmodule

















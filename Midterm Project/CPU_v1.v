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

assign awid_m_inf = 'd0;
assign awsize_m_inf = 3'b001;
assign awburst_m_inf = 2'b01;
assign arsize_m_inf = {3'b001, 3'b001};
assign arburst_m_inf = {2'b01, 2'b01};
assign bready_m_inf = 1'b1;

assign arid_m_inf = 'd0;
assign rready_m_inf = 1'b1;

// 1 write port
// axi write address channel 
output  wire [WRIT_NUMBER * ID_WIDTH-1:0]        awid_m_inf;    // Write address ID
output  wire [WRIT_NUMBER * ADDR_WIDTH-1:0]    awaddr_m_inf;    // Write address 32-bit. the address of the first transfer in a write burst tx
output  wire [WRIT_NUMBER * 3 -1:0]            awsize_m_inf;    // Burst size. only (3'b001)
output  wire [WRIT_NUMBER * 2 -1:0]           awburst_m_inf;    // Burst type. only INCR(2'b01)
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
input   wire [WRIT_NUMBER * 2 -1:0]             bresp_m_inf;    // Write response. only OKAY(2'b00)
input   wire [WRIT_NUMBER-1:0]             	   bvalid_m_inf;    // Write response valid. means a valid write response is available
output  wire [WRIT_NUMBER-1:0]                 bready_m_inf;    // Response ready. CPU can accept the response information
// -----------------------------
// 2 read port
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
input   wire [DRAM_NUMBER * ID_WIDTH-1:0]         rid_m_inf;    // Read ID tag. must match the ARID value   // no use
input   wire [DRAM_NUMBER * DATA_WIDTH-1:0]     rdata_m_inf;    // Read data. 16-bit
input   wire [DRAM_NUMBER * 2 -1:0]             rresp_m_inf;    // Read response.  only OKAY(2'b00)         // no use
input   wire [DRAM_NUMBER-1:0]                  rlast_m_inf;    // Read last. high means current transfer is the last transfer in a read burst.
input   wire [DRAM_NUMBER-1:0]                 rvalid_m_inf;    // Read valid.  read data available
output  wire [DRAM_NUMBER-1:0]                 rready_m_inf;    // Read ready. DRAM can accept the read data and response information
// -----------------------------

// input   wire [DRAM_NUMBER-1:0]               arready_m_inf;    // Read address ready. DRAM is ready to accept signals
assign arready_inst = arready_m_inf[0];
assign arready_data = arready_m_inf[1];

// input   wire [DRAM_NUMBER * DATA_WIDTH-1:0]     rdata_m_inf;    // Read data. 16-bit
assign rlast_inst = rdata_m_inf[0];
assign rlast_data = rdata_m_inf[1];

// input   wire [DRAM_NUMBER-1:0]                  rlast_m_inf;    // Read last. high means current transfer is the last transfer in a read burst.
assign rlast_inst = rlast_m_inf[0];
assign rlast_data = rlast_m_inf[1];

// input   wire [DRAM_NUMBER-1:0]                 rvalid_m_inf;    // Read valid.  read data available
assign rvalid_inst = rvalid_m_inf[0];
assign rvalid_data = rvalid_m_inf[1];

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

// -------------------- control --------------------


reg [2:0] current_state, next_state;

reg [11:0] PC;      // 12-bit

reg [15:0] now_inst;

reg [2:0]  opcode;
reg [3:0]  rs;
reg [3:0]  rt;
reg [3:0]  rd;
reg        func;
reg [4:0]  imm;
reg [12:0] j_addr;

// -------------------- data path --------------------

reg signed [15:0] rs_value, rt_value;//, rd_value;

reg [1:0] alu_op;

wire branch_equal;
reg signed [15:0] imm_extend;
reg signed [15:0] alu_a, alu_b, alu_z;

reg [15:0] ls_addr;

reg signed [15:0] reg_write_value;

reg [4:0] Tag;    // 13 - 8 = 5-bit

reg [7:0] Index;
reg signed [15:0] Din;
reg signed [15:0] Dout;
reg WEB;


//###########################################
//
// Wrtie down your design below
//
//###########################################

// -------------------- FSM --------------------

localparam S_READ_INST_DATA     = 0;
localparam S_FETCH          = 1;
localparam S_DECODE         = 2;
localparam S_EXECUTE        = 3;
localparam S_MEMORY         = 4;
localparam S_WRITE_BACK_REG = 5;

// reg [2:0] current_state;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) current_state <= S_READ_INST_DATA;
    else        current_state <= next_state;
end

// reg [2:0] next_state;
always @(*) begin
    case (current_state)
        S_READ_INST_DATA: begin
            if (rvalid_data & rvalid_inst) next_state = S_FETCH;
            else                           next_state = S_READ_INST_DATA;
        end
        S_FETCH: begin
            if (inst_miss) begin
                if (data_is_dirty) next_state = S_WB_DATA;      // for update data-cache at the same time, first check dirty or not
                else               next_state = S_READ_INST_DATA;
            end
            else                   next_state = S_DECODE;
        end
        S_WB_DATA: begin
            if (bvalid_m_inf) begin
                if      (ten_inst_wb) next_state = S_MEMORY;            // 10 inst
                else if (inst_miss)   next_state = S_READ_INST_DATA;    // inst miss
                else                  next_state = S_READ_DATA;         // load miss
            end
            else next_state = S_WB_DATA;
        end
        S_READ_DATA: begin
            if (rvalid_data) next_state = S_MEMORY;
            else             next_state = S_READ_DATA;
        end
        S_DECODE: begin
            case (opcode)
                5, 6:    next_state = S_UPDATE_PC;      // branch, jump
                default: next_state = S_EXECUTE;
            endcase
        end
        S_EXECUTE: begin
            case (opcode)
                0:       next_state = S_WB_REG;                       // +, -
                1:       next_state = func ? S_WB_REG : S_MULT_DELAY; // < 1 cycle, mult (func == 0) 2 cycle
                default: next_state = S_MEMORY;                       // load, store
            endcase
        end
        S_MULT_DELAY: begin
            next_state = S_WB_REG;
        end
        S_MEMORY: begin             // hot or miss
            if      ((inst_cnt == 4'd9 || load_miss) & data_is_dirty) next_state = S_WB_DATA;
            else if (load_miss)                                       next_state = S_READ_DATA;
            else if (store_miss)                                      next_state = S_WRITE_THROUGH;
            else if (opcode == 3'd3)                                  next_state = S_WB_REG;      // load hit
            else                                                      next_state = S_UPDATE_PC;   // store hit
        end
        S_WRITE_THROUGH: begin       // only for store miss -----> write through
            if (bvalid_m_inf) next_state = S_UPDATE_PC;
            else              next_state = S_WRITE_THROUGH;
        end
        S_WB_REG: begin
            next_state = S_UPDATE_PC;
        end
        S_UPDATE_PC: begin
            if (inst_cnt == 4'd9 & data_is_dirty) next_state = S_WB_DATA;
            else                                  next_state = S_FETCH;
        end
        default: next_state = current_state;
    endcase
end

// reg [11:0] PC;
// "16-bit word" word address, byte address: 0001_0000_0000_0000 ~ 0010_1111_1111_1110
// need (PC << 1) + 0x1000 for using in memory
// need {1'b1, PC[6:0]}    for using in cache
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) PC <= 12'd0;
    else if (current_state == S_UPDATE_PC) begin
        if      (opcode == 3'd4 && branch_equal) PC <= PC + 12'd1 + imm;
        else if (opcode == 3'd5)                 PC <= j_addr;
        else                                     PC <= PC + 12'd1;
    end
    else PC <= PC;
end

wire [9:0] PC_1 = PC - 12'd1;    // for hit

// reg [15:0] now_inst;
always @(posedge clk) begin
    if (current_state == S_DECODE) now_inst <= Dout;
    else                           now_inst <= now_inst;
end

reg [3:0] inst_cnt;       // 0 ~ 10, if 9 ---> SRAM write back DRAM

// reg [2:0]  opcode;
// reg [3:0]  rs;
// reg [3:0]  rt;
// reg [3:0]  rd;
// reg        func;
// reg [4:0]  imm;
// reg [12:0] j_addr;
always @(*) begin
    opcode = now_inst[15:13];
    rs     = now_inst[12:9];
    rt     = now_inst[8:5];
    rd     = now_inst[4:1];
    func   = now_inst[0];
    imm    = now_inst[4:0];
    j_addr = now_inst[12:0];
end

// -------------------- core register --------------------

// ADD  rd = rs + rt                        R  000-rs-rt-rd-1 
// SUB  rd = rs – rt                        R  000-rs-rt-rd-0 
// Set  less than  if(rs<rt) rd=1 else rd=0 R  001-rs-rt-rd-1 
// Mult rd = rs * rt (16’b LSB)             R  001-rs-rt-rd-0 

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        core_r0 <= 16'd0;
        core_r1 <= 16'd0;
        core_r2 <= 16'd0;
        core_r3 <= 16'd0;
        core_r4 <= 16'd0;
        core_r5 <= 16'd0;
        core_r6 <= 16'd0;
        core_r7 <= 16'd0;
        core_r8 <= 16'd0;
        core_r9 <= 16'd0;
        core_r10 <= 16'd0;
        core_r11 <= 16'd0;
        core_r12 <= 16'd0;
        core_r13 <= 16'd0;
        core_r14 <= 16'd0;
        core_r15 <= 16'd0;
    end
    else if (current_state == S_FETCH) begin
        // TODO
    end
    else if (current_state == S_WRITE_BACK) begin
        if (opcode[2:1] == 2'd0) begin      // R-type
            case (rd)
                0: core_r0 <= alu_z;
                1: core_r1 <= alu_z;
                2: core_r2 <= alu_z;
                3: core_r3 <= alu_z;
                4: core_r4 <= alu_z;
                5: core_r5 <= alu_z;
                6: core_r6 <= alu_z;
                7: core_r7 <= alu_z;
                8: core_r8 <= alu_z;
                9: core_r9 <= alu_z;
                10: core_r10 <= alu_z;
                11: core_r11 <= alu_z;
                12: core_r12 <= alu_z;
                13: core_r13 <= alu_z;
                14: core_r14 <= alu_z;
                default: core_r15 <= alu_z;
            endcase
        end
        else if (opcode == 3'd3) begin      // load
            case (rt)
                0: core_r0 <= reg_write_value;
                1: core_r1 <= reg_write_value;
                2: core_r2 <= reg_write_value;
                3: core_r3 <= reg_write_value;
                4: core_r4 <= reg_write_value;
                5: core_r5 <= reg_write_value;
                6: core_r6 <= reg_write_value;
                7: core_r7 <= reg_write_value;
                8: core_r8 <= reg_write_value;
                9: core_r9 <= reg_write_value;
                10: core_r10 <= reg_write_value;
                11: core_r11 <= reg_write_value;
                12: core_r12 <= reg_write_value;
                13: core_r13 <= reg_write_value;
                14: core_r14 <= reg_write_value;
                default: core_r15 <= reg_write_value;
            endcase
        end
    end
end

// -------------------- R-type --------------------

// reg signed [15:0] rs_value;
always @(*) begin
    case (rs)
        0: rs_value = core_r0;
        1: rs_value = core_r1;
        2: rs_value = core_r2;
        3: rs_value = core_r3;
        4: rs_value = core_r4;
        5: rs_value = core_r5;
        6: rs_value = core_r6;
        7: rs_value = core_r7;
        8: rs_value = core_r8;
        9: rs_value = core_r9;
        10: rs_value = core_r10;
        11: rs_value = core_r11;
        12: rs_value = core_r12;
        13: rs_value = core_r13;
        14: rs_value = core_r14;
        default: rs_value = core_r15;
    endcase
end

// reg signed [15:0] rt_value;
always @(*) begin
    case (rt)
        0: rt_value = core_r0;
        1: rt_value = core_r1;
        2: rt_value = core_r2;
        3: rt_value = core_r3;
        4: rt_value = core_r4;
        5: rt_value = core_r5;
        6: rt_value = core_r6;
        7: rt_value = core_r7;
        8: rt_value = core_r8;
        9: rt_value = core_r9;
        10: rt_value = core_r10;
        11: rt_value = core_r11;
        12: rt_value = core_r12;
        13: rt_value = core_r13;
        14: rt_value = core_r14;
        default: rt_value = core_r15;
    endcase
end


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

// reg signed [15:0] imm_extend;
always @(posedge clk) begin
    imm_extend <= {{11{imm[4]}}, imm};
end

// reg signed [15:0] alu_a
always @(posedge clk) begin
    alu_a <= rs_value;
end

// alu src
// reg signed [15:0] alu_b
always @(posedge clk) begin
    case (opcode)
        0, 1:    alu_b <= rt_value;
        default: alu_b <= imm_extend;
    endcase
end

// reg signed [15:0] alu_z;
ALU alu(.clk(clk), .alu_a(alu_a), .alu_b(alu_b), .op(alu_op), .alu_z(alu_z));


// -------------------- I-type --------------------

// beq
// wire branch_equal;
assign branch_equal = !(rs_value ^ rt_value);

// Load  rt = DM[sign(rs+immediate) × 2 + offset ]        I  011-rs-rt-iiiii, alu_op = 0(00)
// Store DM[sign(rs+immediate) × 2 + offset ] = rt        I  010-rs-rt-iiiii, alu_op = 0(00)

// reg [15:0] ls_addr;
always @(posedge clk) begin
    ls_addr <= alu_z;   // word address
end

// load
// store
reg [7:0] Index_reg;
always @(posedge clk) begin
    Index_reg <= Index;
end

// reg [7:0] Index;
always @(*) begin
    Index = Index_reg;
    if      (current_state == S_FETCH)  Index = {1'b1, PC[6:0]};        // fetch code
    else if (current_state == S_MEMORY) Index = {1'b0, ls_addr[6:0]};
    // else Index = ???
end

// reg signed [15:0] Din;
always @(*) begin
    Din = alu_b;        // store
end

// reg WEB;!!!!!!!!!!!!!!!!!!!
always @(*) begin
    WEB = ~(current_state == S_MEMORY && opcode == 3'd2);
end

// reg signed [15:0] reg_write_value;
always @(posedge clk) begin
    reg_write_value <= Dout;        // load
end

// -------------------- Cache --------------------

reg [4:0]   inst_cache_tag [0:127];
// reg [127:0] inst_cache_valid;

reg [4:0]   data_cache_tag [0:127];
// reg [127:0] data_cache_valid;
reg [127:0] data_cache_dirty;

// [ Tag | Index ] = 2^12 word address space * 2
// 0 ~ 0001_1111_1111_1111 byte address

// reg [7:0] Index;
// reg signed [15:0] Din;
// reg signed [15:0] Dout;
// reg WEB;

// reg signed [15:0] Dout;
CACHE_INTERFACE data_inst_cache(.Address(Index), .Din(Din), .Dout(Dout), .clk(clk), .WEB(WEB));

reg [4:0] current_cache_Tag_data, current_cache_Tag_inst;
wire cache_hit_data, cache_hit_inst;

// reg [4:0] current_cache_Tag_inst;
always @(posedge clk) begin
    current_cache_Tag_inst <= inst_cache_tag[Index];
end

// reg [4:0] current_cache_Tag_data;
always @(posedge clk) begin
    current_cache_Tag_data <= data_cache_tag[Index];
end

// wire cache_hit_data, cache_hit_inst;
assign cache_hit_inst = (current_cache_Tag_inst == PC[11:7]);
assign cache_hit_data = (current_cache_Tag_data == ls_addr[11:7]);

wire inst_miss;
wire load_miss;
wire store_miss;

// wire inst_miss;
assign inst_miss = ~cache_hit_inst;
assign load_miss = ~cache_hit_data & (opcode == 3'd3);
assign store_miss = ~cache_hit_data & (opcode == 3'd2);


// -------------------- DRAM --------------------

wire data_is_dirty;

assign data_is_dirty = (data_cache_dirty != 128'd0);




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

//synopsys translate_off
`include “/usr/synthesis/dw/sim_ver/DW01_addsub.v”
`include “/usr/synthesis/dw/sim_ver/DW02_mult_2_stage.v”
//synopsys translate_on

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
        2:       alu_z <= mult_z[15:0];             // mult
        3:       alu_z <= {14'd0, addsub_z[15]};    // slt
        default: alu_z <= addsub_z;                 // add, sub
    endcase
end

//synopsys dc_script_begin
//set_implementation pparch addsub 
//synopsys dc_script_end

endmodule



module CACHE_INTERFACE (
    input [7:0] Address,        // 128 * 2 entry
    input [15:0] Din,
    output [15:0] Dout,
    input clk,
    input WEB
);
// [ Tag | Index ]

// input [4:0] Tag,    // 4096 byte space ---> 12-bit - 7-bit = 5-bit LSB addr
// input [6:0] Index,  // 128 cacheline (7-bit MSB addr)

// wire [13:0] address = {Tag, Index};      // 0x1000 ~ 0x2FFF -----> 0x2000 bytes space = 1024 16-bit words ------> 10-bit
/* TODO: make a sram */
// (128 * 2) x 16
SRAM_xxxxx sram_1 (.A0(Address[0]),
                   .A1(Address[1]), 
                   .A2(Address[2]), 
                   .A3(Address[3]), 
                   .A4(Address[4]), 
                   .A5(Address[5]), 
                   .A6(Address[6]), 
                   .A7(Address[7]), 
                //    .A8(Address[8]), 
                //    .A9(Address[9]),

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

















// Finish:
//      R-type
//      I-type, J-type
//      

// TODO:
//      AXI

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
assign bready_m_inf = 1'b1;         // TODO: base on state?

assign arid_m_inf = 'd0;
assign rready_m_inf = 1'b1;      // TODO: base on state?

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
assign arready_inst = arready_m_inf[1];
assign arready_data = arready_m_inf[0];

// input   wire [DRAM_NUMBER * DATA_WIDTH-1:0]     rdata_m_inf;    // Read data. 16-bit
assign rdata_inst = rdata_m_inf[31:16];
assign rdata_data = rdata_m_inf[15:0];

// input   wire [DRAM_NUMBER-1:0]                  rlast_m_inf;    // Read last. high means current transfer is the last transfer in a read burst.
assign rlast_inst = rlast_m_inf[1];
assign rlast_data = rlast_m_inf[0];

// input   wire [DRAM_NUMBER-1:0]                 rvalid_m_inf;    // Read valid.  read data available
assign rvalid_inst = rvalid_m_inf[1];
assign rvalid_data = rvalid_m_inf[0];


// Read control
reg  arvalid_inst, arvalid_data;
reg [31:0] araddr_inst, araddr_data;
wire [6:0] arlen_inst, arlen_data; // AXI length = burst length - 1
reg [6:0] read_inst_counter, read_data_counter;

// Write control
reg  awvalid;
reg [31:0] awaddr;
reg [6:0] awlen;
reg  wvalid;
reg [15:0] wdata;
reg  wlast;
reg [6:0] write_counter;
reg [6:0] wb_scan_counter;

// output wire
assign arvalid_m_inf = {arvalid_inst, arvalid_data};
assign araddr_m_inf  = {araddr_inst, araddr_data};
assign arlen_m_inf   = {arlen_inst, arlen_data};

assign awvalid_m_inf = awvalid;
assign awaddr_m_inf  = awaddr;
assign awlen_m_inf   = awlen;
assign wvalid_m_inf  = wvalid;
assign wdata_m_inf   = wdata;
assign wlast_m_inf   = wlast;



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

parameter offset = 16'h1000;        // 0000_0000_0000_0000 _ 0001_0000_0000_0000

// -------------------- control --------------------


reg [4:0] current_state, next_state;

reg [11:0] PC;      // 12-bit

reg [15:0] now_inst, now_inst_reg;

reg [2:0]  opcode;
reg [3:0]  rs;
reg [3:0]  rt;
reg [3:0]  rd;
reg        func;
reg [4:0]  imm;
reg [12:0] j_addr;

reg [6:0] init_read_counter_inst, init_read_counter_data; // 0~127
reg       inst_read_complete,     data_read_complete;

reg [6:0] refill_counter_inst, refill_counter_data; // 0~127

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
reg signed [15:0] Din_inst, Din_data;
reg signed [15:0] Dout_inst, Dout_data;
reg we_inst, we_data;

reg [3:0] inst_cnt;       // 0 ~ 10, if 9 ---> SRAM write back DRAM

wire [4:0] tag_inst, tag_data;
wire [6:0] index_inst, index_data;

localparam DS_CLEAN        = 2'd0;
localparam DS_ONE_DIRTY    = 2'd1;
localparam DS_MANY_DIRTY   = 2'd2;

reg dirty_state; // 0: DS_CLEAN, 1: DS_ONE_DIRTY, 2: DS_MANY_DIRTY
reg [4:0] first_dirty_tag;
reg [6:0] first_dirty_index;
reg [15:0] first_dirty_data;

reg [4:0] current_cache_Tag_inst, current_cache_Tag_data;
wire cache_hit_inst, cache_hit_data;
wire inst_miss, load_miss, store_miss;

reg [6:0] wb_scan_counter;
wire data_is_dirty;

//###########################################
//
// Wrtie down your design below
//
//###########################################

// -------------------- FSM --------------------

localparam S_INIT_REQ           = 5'd0;
localparam S_INIT_WAIT          = 5'd1;
localparam S_REFILL_REQ         = 5'd2;
localparam S_REFILL_WAIT        = 5'd3;
localparam S_FETCH              = 5'd4;
localparam S_WB_REQ_INST_MISS   = 5'd5;
localparam S_WB_DATA_INST_MISS  = 5'd6;
localparam S_WB_REQ_LOAD_MISS   = 5'd7;
localparam S_WB_DATA_LOAD_MISS  = 5'd8;
localparam S_READ_DATA_REQ      = 5'd9;
localparam S_READ_DATA          = 5'd10;
localparam S_DECODE             = 5'd11;
localparam S_EXECUTE            = 5'd12;
localparam S_MULT_DELAY         = 5'd13;
localparam S_MEMORY             = 5'd14;
localparam S_WT_REQ             = 5'd15;
localparam S_WT_DATA            = 5'd16;
localparam S_WB_REG             = 5'd17;
localparam S_WB_REQ_TEN         = 5'd18;
localparam S_WB_DATA_TEN        = 5'd19;
localparam S_UPDATE_PC          = 5'd20;

// reg [4:0] current_state;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) current_state <= S_INIT_REQ;
    else        current_state <= next_state;
end

// reg [4:0] next_state;
always @(*) begin
    case (current_state)
        S_INIT_REQ: begin
            next_state = S_INIT_WAIT;
        end
        S_INIT_WAIT: begin    // fetch (0 ~ 128)*2 + offset
            if (inst_read_complete && data_read_complete) next_state = S_FETCH;
            else                                          next_state = S_INIT_WAIT;
        end
        S_REFILL_REQ: begin
            next_state = S_REFILL_WAIT;
        end
        S_REFILL_WAIT: begin        // fetch (PC+1-32 ~ PC+1+96)*2 + offset
            if (inst_read_complete && data_read_complete) next_state = S_FETCH;
            else                                          next_state = S_REFILL_WAIT;
        end
        S_FETCH: begin
            if (inst_miss) begin
                if (data_is_dirty) next_state = S_WB_REQ_INST_MISS;      // for update data-cache at the same time, first check dirty or not
                else               next_state = S_REFILL_REQ;
            end
            else                   next_state = S_DECODE;
        end
        S_WB_REQ_INST_MISS: begin
            if (awready_m_inf) next_state = S_WB_DATA_INST_MISS;
            else               next_state = S_WB_REQ_INST_MISS;
        end
        S_WB_DATA_INST_MISS: begin
            if (bvalid_m_inf) next_state = S_REFILL_REQ;        // inst miss
            else              next_state = S_WB_DATA_INST_MISS;
        end
        S_WB_REQ_LOAD_MISS: begin
            if (awready_m_inf) next_state = S_WB_DATA_LOAD_MISS;
            else               next_state = S_WB_REQ_LOAD_MISS;
        end
        S_WB_DATA_LOAD_MISS: begin
            if (bvalid_m_inf) next_state = S_READ_DATA_REQ; // load miss
            else              next_state = S_WB_DATA_LOAD_MISS;
        end
        S_READ_DATA_REQ: begin
            if (arready_data) next_state = S_READ_DATA;
            else              next_state = S_READ_DATA_REQ;
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
            if      (load_miss & data_is_dirty) next_state = S_WB_REQ_LOAD_MISS;
            else if (load_miss)                 next_state = S_READ_DATA_REQ;
            else if (store_miss)                next_state = S_WT_REQ;
            else if (opcode == 3'd3)            next_state = S_WB_REG;      // load hit
            else                                next_state = S_UPDATE_PC;   // store hit
        end
        S_WT_REQ: begin       // only for store miss -----> write through
            if (awready_m_inf) next_state = S_WT_DATA;
            else               next_state = S_WT_REQ;
        end
        S_WT_DATA: begin
            if (bvalid_m_inf) next_state = S_UPDATE_PC;
            else              next_state = S_WT_DATA;
        end
        S_WB_REG: begin
            next_state = S_UPDATE_PC;
        end
        S_WB_REQ_TEN: begin
            if (awready_m_inf) next_state = S_WB_DATA_TEN;
            else               next_state = S_WB_REQ_TEN;
        end
        S_WB_DATA_TEN: begin
            if (bvalid_m_inf) next_state = S_FETCH;            // 10 inst
            else              next_state = S_WB_DATA_TEN;
        end
        S_UPDATE_PC: begin
            if (inst_cnt == 4'd9 & data_is_dirty) next_state = S_WB_REQ_TEN;
            else                                  next_state = S_FETCH;
        end
        default: next_state = current_state;
    endcase
end

// output reg  IO_stall;   //  should be low for one cycle whenever finished an instruction
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) IO_stall <= 1'b1;
    else        IO_stall <= !(current_state == S_UPDATE_PC);
    // Maybe other states can also finish an instruction
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

// reg [3:0] inst_cnt;       // 0 ~ 10, if 9 ---> SRAM write back DRAM
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) inst_cnt <= 4'd9;
    else if (current_state == S_DECODE) begin
        if (inst_cnt == 4'd9) inst_cnt <= 4'd0;
        else                  inst_cnt <= inst_cnt + 4'd1;
    end
end

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
    else if (current_state == S_WB_REG) begin
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
/////////////////////////////////////////////////////////////////////////////////////////////////

// wire [6:0] Address_inst, Address_data;
assign index_inst = PC[6:0];
assign index_data = ls_addr[6:0];

// wire [4:0] tag_inst, tag_data;
assign tag_inst = PC[11:7];
assign tag_data = ls_addr[11:7];

/////////////////////////////////////////////////////////////////////////////////////////////////

// -------------------- Cache --------------------

// reg dirty_state; // 0: DS_CLEAN, 1: DS_ONE_DIRTY, 2: DS_MANY_DIRTY
// reg [4:0] first_dirty_tag;
// reg [6:0] first_dirty_index;
// reg [15:0] first_dirty_data;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        dirty_state <= DS_CLEAN;
    end
    // store hit
    else if (current_state == S_MEMORY && opcode == 3'd2 && ~store_miss) begin
        case (dirty_state)
            DS_CLEAN: begin // DS_CLEAN -> DS_ONE_DIRTY
                dirty_state       <= DS_ONE_DIRTY;
                first_dirty_tag   <= tag_data;
                first_dirty_index <= index_data;
                first_dirty_data  <= rt_value;
            end
            DS_ONE_DIRTY: begin // DS_ONE_DIRTY -> DS_MANY_DIRTY
                dirty_state <= DS_MANY_DIRTY;
            end
            default: begin // DS_MANY_DIRTY stays DS_MANY_DIRTY
                dirty_state <= DS_MANY_DIRTY;
            end
        endcase
    end
    // Reset dirty_state after a successful write-back
    else if (current_state == S_WB_DATA_INST_MISS && bvalid_m_inf ||
             current_state == S_WB_DATA_LOAD_MISS && bvalid_m_inf ||
             current_state == S_WB_DATA_TEN       && bvalid_m_inf) 
    begin
        dirty_state <= DS_CLEAN;
    end
end



// [ Tag | Index ] = 2^12 word address space * 2
// 0 ~ 0001_1111_1111_1111 byte address

// reg [15:0] now_inst_reg;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) now_inst_reg <= 16'd0;
    else        now_inst_reg <= now_inst;
end

// Inst Cache Write
always @(*) begin
    we_inst = 1'b0;
    Din_inst = 16'b0;
    now_inst = now_inst_reg;
    Address_inst = 8'd0;
    case (current_state)
        S_FETCH: begin
            we_inst      = 1'b0;
            now_inst     = Dout_inst;
            Address_inst = index_inst;
        end
        // wait for write cache
        S_INIT_WAIT: begin
            if (rvalid_inst) begin
                we_inst      = 1'b1;
                Din_inst     = rdata_inst; // from AXI
                Address_inst = {1'b1, init_read_counter_inst};
            end
        end
        S_REFILL_WAIT: begin
            if (rvalid_data) begin
                we_inst = 1'b0;
                Din_inst = rdata_inst; // from AXI
                Address_inst = {1'b1, refill_counter_inst};
            end
        end
    endcase
end

// Data Cache Write
always @(*) begin
    // cache control
    we_data = 1'b1;
    Address_data = 8'd0;
    // cache data in or out
    Din_data = 16'b0;
    case (current_state)
        // wait for write cache
        S_INIT_WAIT: begin
            if (rvalid_data) begin
                we_data      = 1'b0;
                Address_data = {1'b0, init_read_counter_data};
                Din_data     = rdata_data; // from AXI
            end
        end
        S_REFILL_WAIT: begin
            if (rvalid_data) begin
                we_data      = 1'b0;
                Address_data = {1'b0, refill_counter_data};
                Din_data     = rdata_data;
            end
        end
        S_MEMORY: begin
            if (opcode == 3'd3 && ~load_miss) begin
                we_data      = 1'b1;
                Address_data = index_data;        // load hit (read)
            end
            if (opcode == 3'd2 && ~store_miss) begin
                we_data      = 1'b0;
                Address_data = index_data;        // store hit (write)
                Din_data     = rt_value;
            end
        end

        S_WB_DATA_INST_MISS, S_WB_DATA_LOAD_MISS, S_WB_DATA_TEN: begin
            if (dirty_state == DS_MANY_DIRTY) begin
                we_data      = 1'b1;
                Address_data = wb_scan_counter;     // write-back DRAM (read)
            end
        end
    endcase
end

// reg signed [15:0] reg_write_value;
always @(*) begin
    if (opcode == 3'd3) reg_write_value = Dout_data;        // load
    else                reg_write_value = alu_z;
end

// reg [7:0] Index;
// reg signed [15:0] Din_inst, Din_data;
// reg signed [15:0] Dout_inst, Dout_data;
// reg we_inst, we_data;
CACHE_INTERFACE data_inst_cache(
    .Address_inst(Address_inst), .Address_data(Address_data),
    .Din_inst    (Din_inst    ), .Din_data    (Din_data    ), 
    .Dout_inst   (Dout_inst   ), .Dout_data   (Dout_data   ), 
    .we_inst     (we_inst     ), .we_data     (we_data     ),
    .clk(clk)
);

// reg [4:0] current_cache_Tag_inst;
always @(posedge clk or negedge rst_n) begin
    if      (!rst_n)                               current_cache_Tag_inst <= 5'd0;
    else if (current_state == S_WB_DATA_INST_MISS) current_cache_Tag_inst <= PC[11:7];  // update to new tag if inst miss
end

// reg [4:0] current_cache_Tag_data;
always @(posedge clk or negedge rst_n) begin
    if      (!rst_n)                               current_cache_Tag_data <= 5'd0;
    else if (current_state == S_WB_DATA_LOAD_MISS) current_cache_Tag_data <= ls_addr[11:7];  // update to new tag if load miss
end

// wire cache_hit_data, cache_hit_inst;
assign cache_hit_inst = (current_cache_Tag_inst == tag_inst);
assign cache_hit_data = (current_cache_Tag_data == tag_data);

// wire inst_miss, load_miss, store_miss;
assign inst_miss = ~cache_hit_inst;
assign load_miss = ~cache_hit_data & (opcode == 3'd3);
assign store_miss = ~cache_hit_data & (opcode == 3'd2);


// -------------------- DRAM --------------------

// reg inst_read_complete;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) inst_read_complete <= 1'b0;
    // wait rlast
    else if ((current_state == S_INIT_WAIT || current_state == S_REFILL_WAIT) && rvalid_inst && rlast_inst) inst_read_complete <= 1'b1;
    else if (current_state == S_INIT_REQ || current_state == S_REFILL_REQ)                                  inst_read_complete <= 1'b0;
end

// reg data_read_complete;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) data_read_complete <= 1'b0;
    // wait rlast
    else if ((current_state == S_INIT_WAIT || current_state == S_REFILL_WAIT) && rvalid_data && rlast_data) data_read_complete <= 1'b1;
    else if (current_state == S_INIT_REQ || current_state == S_REFILL_REQ)                                  data_read_complete <= 1'b0;
end

// ----------- counter -----------
// reg [6:0] init_read_counter_inst; // 0~127
always @(posedge clk or negedge rst_n) begin
    if      (!rst_n)                                      init_read_counter_inst <= 7'd0;
    else if (current_state == S_INIT_WAIT && rvalid_inst) init_read_counter_inst <= init_read_counter_inst + 7'd1;
end

// reg [6:0] init_read_counter_data; // 0~127
always @(posedge clk or negedge rst_n) begin
    if      (!rst_n)                                      init_read_counter_data <= 6'd0;
    else if (current_state == S_INIT_WAIT && rvalid_data) init_read_counter_data <= init_read_counter_data + 6'd1;
end


// reg [6:0] refill_counter_inst; // 0~127
always @(posedge clk or negedge rst_n) begin
    if      (!rst_n)                                        refill_counter_inst <= 7'd0;
    else if (current_state == S_REFILL_WAIT && rvalid_inst) refill_counter_inst <= refill_counter_inst + 7'd1;
    else if (current_state == S_FETCH)                      refill_counter_inst <= 7'd0;
end

// reg [6:0] refill_counter_data; // 0~127
always @(posedge clk or negedge rst_n) begin
    if      (!rst_n)                                        refill_counter_data <= 7'd0;
    else if (current_state == S_REFILL_WAIT && rvalid_data) refill_counter_data <= refill_counter_data + 7'd1;
    else if (current_state == S_FETCH)                      refill_counter_data <= 7'd0;
end

// reg [6:0] wb_scan_counter;
always @(posedge clk or rst_n) begin
    if (!rst_n) wb_scan_counter <= 7'd0;
    else if (wvalid && wready_m_inf &&
             (current_state == S_WB_DATA_INST_MISS ||
              current_state == S_WB_DATA_LOAD_MISS ||
              current_state == S_WB_DATA_TEN)) wb_scan_counter <= wb_scan_counter + 7'd1;
end


// ----------- control -----------

// always read 128 words
assign arlen_inst = 7'd127;
assign arlen_data = 7'd127;

// wire data_is_dirty;
assign data_is_dirty = (dirty_state == DS_ONE_DIRTY) || (dirty_state == DS_MANY_DIRTY);

// AXI
always @(*) begin
    // Default values for all control signals
    // AXI Read Address Channel
    arvalid_inst = 1'b0;
    arvalid_data = 1'b0;
    araddr_inst = 32'b0;
    araddr_data = 32'b0;
    // AXI Write Address Channel
    awvalid = 1'b0;
    awaddr = 32'b0;
    awlen = 7'b0;
    // AXI Write Data Channel
    wvalid = 1'b0;
    wdata = 16'b0;
    wlast = 1'b0;
    case (current_state)
        // AXI Read Request
        S_INIT_REQ: begin
            arvalid_inst = 1'b1;
            arvalid_data = 1'b1;
            araddr_inst = {16'd0, offset}; // Byte Address
            araddr_data = {16'd0, offset};
        end
        S_REFILL_REQ: begin
            arvalid_inst = 1'b1;
            arvalid_data = 1'b1;
            araddr_inst  = (tag_inst << 1) + offset;
            araddr_data  = araddr_inst;      // base on PC
        end
        S_READ_DATA_REQ: begin
            arvalid_inst = 1'b1;
            arvalid_data = 1'b1;
            // araddr_inst  = ; no use, only data
            araddr_data  = (tag_data << 1) + offset;
        end

        S_WB_REQ_INST_MISS, S_WB_REQ_LOAD_MISS, S_WB_REQ_TEN: begin
            awvalid = 1'b1;
            case (dirty_state)
                DS_ONE_DIRTY: begin
                    awaddr = {first_dirty_tag, first_dirty_index, 1'b0} + offset;
                    awlen  = 7'd0;
                end
                DS_MANY_DIRTY: begin
                    awaddr = {current_cache_Tag_data, 7'b0, 1'b0} + offset;
                    awlen  = 7'd127;
                end
            endcase
        end
        S_WB_DATA_INST_MISS, S_WB_DATA_LOAD_MISS, S_WB_DATA_TEN: begin
            wvalid = 1'b1;
            case (dirty_state)
                DS_ONE_DIRTY: begin
                    wdata = first_dirty_data;
                    wlast = 1'b1;
                end
                DS_MANY_DIRTY: begin
                    wdata = Dout_data;      // need 1 delay?
                    wlast = (wb_scan_counter == 7'd127);
                end
            endcase
        end

        S_WT_REQ: begin
            awvalid = 1'b1;
            awaddr  = {(ls_addr << 1) + offset}; 
            awlen   = 7'd0;
        end
        S_WT_DATA: begin
            wvalid = 1'b1;
            wdata  = rt_value;
            wlast  = 1'b1;     // only 1 data
        end
    endcase
end

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

endmodule



module CACHE_INTERFACE (
    input [6:0] Address_inst, 
    input [6:0] Address_data,        // 128 * 2 entry
    input [15:0] Din_inst, 
    input [15:0] Din_data,
    output [15:0] Dout_inst, 
    output [15:0] Dout_data,
    input clk,
    input we_inst, 
    input we_data
);
// [ Tag | Index ]

// input [4:0] Tag,    // 4096 byte space ---> 12-bit - 7-bit = 5-bit LSB addr
// input [6:0] Index,  // 128 cacheline (7-bit MSB addr)

// wire [13:0] address = {Tag, Index};      // 0x1000 ~ 0x2FFF -----> 0x2000 bytes space = 1024 16-bit words ------> 10-bit

// (128 * 2) x 16
SRAM_256x16_DUAL sram_1(.A0({1'b0, Address_inst[0]}), .B0({1'b1, Address_data[0]}), 
                        .A1({1'b0, Address_inst[1]}), .B1({1'b1, Address_data[1]}), 
                        .A2({1'b0, Address_inst[2]}), .B2({1'b1, Address_data[2]}), 
                        .A3({1'b0, Address_inst[3]}), .B3({1'b1, Address_data[3]}), 
                        .A4({1'b0, Address_inst[4]}), .B4({1'b1, Address_data[4]}), 
                        .A5({1'b0, Address_inst[5]}), .B5({1'b1, Address_data[5]}), 
                        .A6({1'b0, Address_inst[6]}), .B6({1'b1, Address_data[6]}), 
                        .A7({1'b0, Address_inst[7]}), .B7({1'b1, Address_data[7]}), 

                        .DOA0(Dout_inst[0]),   .DOB0(Dout_data[0]), 
                        .DOA1(Dout_inst[1]),   .DOB1(Dout_data[1]), 
                        .DOA2(Dout_inst[2]),   .DOB2(Dout_data[2]), 
                        .DOA3(Dout_inst[3]),   .DOB3(Dout_data[3]), 
                        .DOA4(Dout_inst[4]),   .DOB4(Dout_data[4]), 
                        .DOA5(Dout_inst[5]),   .DOB5(Dout_data[5]), 
                        .DOA6(Dout_inst[6]),   .DOB6(Dout_data[6]), 
                        .DOA7(Dout_inst[7]),   .DOB7(Dout_data[7]), 
                        .DOA8(Dout_inst[8]),   .DOB8(Dout_data[8]), 
                        .DOA9(Dout_inst[9]),   .DOB9(Dout_data[9]), 
                        .DOA10(Dout_inst[10]), .DOB10(Dout_data[10]), 
                        .DOA11(Dout_inst[11]), .DOB11(Dout_data[11]), 
                        .DOA12(Dout_inst[12]), .DOB12(Dout_data[12]), 
                        .DOA13(Dout_inst[13]), .DOB13(Dout_data[13]), 
                        .DOA14(Dout_inst[14]), .DOB14(Dout_data[14]), 
                        .DOA15(Dout_inst[15]), .DOB15(Dout_data[15]), 

                        .DIA0(Din_inst[0]),   .DIB0(Din_data[0]), 
                        .DIA1(Din_inst[1]),   .DIB1(Din_data[1]), 
                        .DIA2(Din_inst[2]),   .DIB2(Din_data[2]), 
                        .DIA3(Din_inst[3]),   .DIB3(Din_data[3]), 
                        .DIA4(Din_inst[4]),   .DIB4(Din_data[4]), 
                        .DIA5(Din_inst[5]),   .DIB5(Din_data[5]), 
                        .DIA6(Din_inst[6]),   .DIB6(Din_data[6]), 
                        .DIA7(Din_inst[7]),   .DIB7(Din_data[7]), 
                        .DIA8(Din_inst[8]),   .DIB8(Din_data[8]), 
                        .DIA9(Din_inst[9]),   .DIB9(Din_data[9]), 
                        .DIA10(Din_inst[10]), .DIB10(Din_data[10]), 
                        .DIA11(Din_inst[11]), .DIB11(Din_data[11]), 
                        .DIA12(Din_inst[12]), .DIB12(Din_data[12]), 
                        .DIA13(Din_inst[13]), .DIB13(Din_data[13]), 
                        .DIA14(Din_inst[14]), .DIB14(Din_data[14]), 
                        .DIA15(Din_inst[15]), .DIB15(Din_data[15]), 

                        .WEAN(we_inst),.WEBN(we_data),
                        .CKA(clk),.CKB(clk),
                        .CSA(1'b1),.CSB(1'b1),
                        .OEA(1'b1),.OEB(1'b1));

endmodule


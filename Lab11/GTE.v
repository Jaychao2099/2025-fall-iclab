//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   ICLAB 2025 Fall 
// Lab11 Exercise : Geometric Transform Engine (GTE)
//      File Name : GTE.v
//    Module Name : GTE
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

// Finished:
//      calculate index logic
//      FSM
//      MEM control at init     (addr, data, web)
//      MEM control at read
//      MEM control at write

// TODO: 
//      

module GTE(
    // input signals
    clk,
    rst_n,
	
    in_valid_data,
	data,
	
    in_valid_cmd,
    cmd,    
	
    // output signals
    busy
);

input              clk;
input              rst_n;

input              in_valid_data;
input       [7:0]  data;

input              in_valid_cmd;
input      [17:0]  cmd;

output reg         busy;

//==================================================================
// parameter & integer
//==================================================================

parameter MEM_WRITE = 1'b0;
parameter MEM_READ  = 1'b1;

parameter S_IDLE        = 3'd0;
parameter S_INIT_SRAM   = 3'd1;
parameter S_READ        = 3'd2;
parameter S_CAL_WRITE   = 3'd3;
parameter S_CHECK_SRAM  = 3'd4;

parameter MX    = 4'd0;
parameter MY    = 4'd1;
parameter TRP   = 4'd2;
parameter STRP  = 4'd3;
parameter R90   = 4'd4;
parameter R180  = 4'd5;
parameter R270  = 4'd6;

parameter RS    = 4'd8;
parameter LS    = 4'd9;
parameter US    = 4'd10;
parameter DS    = 4'd11;
parameter ZZ4   = 4'd12;
parameter ZZ8   = 4'd13;
parameter MO4   = 4'd14;
parameter MO8   = 4'd15;


//==================================================================
// reg & wire
//==================================================================

// -----------------------------------------------------
// FSM
// -----------------------------------------------------
reg [2:0] current_state, next_state;

reg [7:0] old_ms;

reg [1:0] r_byte;
reg [1:0] w_byte;

// -----------------------------------------------------
// init SRAM
// -----------------------------------------------------
reg [14:0] init_cnt, init_cnt_d1;

wire [2:0] init_mem_num;
wire [3:0] init_mem_idx;
wire [7:0] init_mem_offset;

reg [7:0] in_data [0:3], in_data_reg [0:3];

// -----------------------------------------------------
// read / write SRAM
// -----------------------------------------------------
reg [8:0] read_cnt, read_cnt_d1_0;      // 0~255
reg [7:0] img_buffer [0:255];

reg [17:0] cmd_reg;
wire [3:0] op_func;
wire [6:0] ms, md;

wire [2:0] r_mem_num, w_mem_num;
wire [3:0] r_mem_idx, w_mem_idx;

// -----------------------------------------------------
// calulation / output
// -----------------------------------------------------
reg [8:0] out_cnt, out_cnt_d1;      // 0~255
reg [7:0] src_idx [0:3];    // 0~255
reg [7:0] result_pixel [0:3];

// -----------------------------------------------------
// MEM
// -----------------------------------------------------
reg [2:0] mem_num;
reg [3:0] mem_idx;
reg [7:0] mem_offset;

reg [31:0] mem_in_data;  // 4 * 8

// MEM_0, MEM_1, MEM_2, MEM_3: 8-bit width, 4096 depth
reg         mem0_web, mem1_web, mem2_web, mem3_web;
wire [11:0] mem0_addr, mem1_addr, mem2_addr, mem3_addr;
wire  [7:0] mem0_din, mem1_din, mem2_din, mem3_din;
wire  [7:0] mem0_dout, mem1_dout, mem2_dout, mem3_dout;

// MEM_4, MEM_5: 16-bit width, 2048 depth
reg         mem4_web, mem5_web;
wire [10:0] mem4_addr, mem5_addr;
wire [15:0] mem4_din, mem5_din;
wire [15:0] mem4_dout, mem5_dout;

// MEM_6, MEM_7: 32-bit width, 1024 depth
reg         mem6_web, mem7_web;
wire  [9:0] mem6_addr, mem7_addr;
wire [31:0] mem6_din, mem7_din;
wire [31:0] mem6_dout, mem7_dout;

//==================================================================
// design
//==================================================================

// -----------------------------------------------------
// FSM
// -----------------------------------------------------

// reg [2:0] current_state;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) current_state <= S_IDLE;
    else current_state <= next_state;
end

// reg [2:0] current_state, next_state;
always @(*) begin
    case (current_state)
        S_IDLE: begin
            if      (in_valid_data)              next_state = S_INIT_SRAM;
            else if (in_valid_cmd) begin
                if ({1'b0, cmd[13:7]} == old_ms) next_state = S_CAL_WRITE;
                else                             next_state = S_READ;
            end
            else                                 next_state = S_IDLE;
        end
        S_INIT_SRAM: begin
            if (init_cnt == 15'd32767) next_state = S_IDLE;
            else                       next_state = S_INIT_SRAM;
        end
        S_READ: begin
            if (read_cnt == 9'd256) next_state = S_CAL_WRITE;
            else next_state = S_READ;
        end
        S_CAL_WRITE: begin
            if (out_cnt == 9'd256) next_state = S_CHECK_SRAM;
            else next_state = S_CAL_WRITE;
        end
        S_CHECK_SRAM: begin
            next_state = S_IDLE;
        end
        default: next_state = current_state;        // no used
    endcase
end

// old_ms
always @(posedge clk or negedge rst_n) begin
    if      (!rst_n)                        old_ms <= 8'b10000000;
    else if (current_state == S_CHECK_SRAM) old_ms <= {1'b0, ms};
end

// reg [1:0] r_byte;
always @(*) begin
    if      (ms >= 7'd64 && ms < 7'd96) r_byte = 2'd2;
    else if (ms >= 7'd96)               r_byte = 2'd3;
    else                                r_byte = 2'd1;
end

// reg [1:0] r_byte;
always @(*) begin
    if      (md >= 7'd64 && md < 7'd96) w_byte = 2'd2;
    else if (md >= 7'd96)               w_byte = 2'd3;
    else                                w_byte = 2'd1;
end

// output reg         busy;
always @(posedge clk or negedge rst_n) begin
    if      (!rst_n)                        busy <= 1'b1;
    else if (current_state == S_CHECK_SRAM) busy <= 1'b0;
    else                                    busy <= 1'b1;
end

// -----------------------------------------------------
// init SRAM
// -----------------------------------------------------

// 0 ~ 32767
// 111111111111111  15-bit
// reg [14:0] init_cnt;
always @(posedge clk or negedge rst_n) begin
    if      (!rst_n)        init_cnt <= 15'd0;
    else if (in_valid_data) init_cnt <= init_cnt + 15'd1;
end

always @(posedge clk) begin
    init_cnt_d1 <= init_cnt;
end

// wire [2:0] init_mem_num;
// wire [3:0] init_mem_idx;
// wire [7:0] init_mem_offset;
assign init_mem_num    = init_cnt_d1[14:12];   // for which mem "init write" write enable
assign init_mem_idx    = init_cnt_d1[11:8];
assign init_mem_offset = init_cnt_d1[7:0];

// reg [7:0] in_data_reg [0:3];
always @(posedge clk) begin
    in_data_reg <= in_data;
end

// reg [7:0] in_data [0:3];
always @(*) begin
    if (in_valid_data) begin
        case (init_mem_num)
            0,1,2,3: in_data[0]                = data;
            4,5:     in_data[init_cnt[0]]   = data;
            default: in_data[init_cnt[1:0]] = data;
        endcase
    end
end

// -----------------------------------------------------
// read / write SRAM
// -----------------------------------------------------

// reg [17:0] cmd_reg;
always @(posedge clk) begin
    if (in_valid_cmd) cmd_reg <= cmd;
end

// wire [3:0] op_func;
// wire [6:0] ms, md;
assign op_func  = cmd_reg[17:14];
assign ms       = cmd_reg[13:7];
assign md       = cmd_reg[6:0];

// wire [2:0] r_mem_num, w_mem_num;
// wire [3:0] r_mem_idx, w_mem_idx;
assign r_mem_num = ms[6:4]; // 3-bit    for "read" which mem into img_buffer
assign r_mem_idx = ms[3:0]; // 4-bit

assign w_mem_num = md[6:4]; // 3-bit    for which mem "write" enable
assign w_mem_idx = md[3:0]; // 4-bit

// reg [8:0] read_cnt;      // 0~255, 256
always @(posedge clk or negedge rst_n) begin
    if      (!rst_n)                  read_cnt <= 9'd0;
    else if (read_cnt == 9'd256)      read_cnt <= 9'd0;
    else if (current_state == S_READ) read_cnt <= read_cnt + r_byte;
end

// reg [7:0] read_cnt_d1_0;      // 0~255
always @(posedge clk) begin
    read_cnt_d1_0 <= read_cnt;
end

wire [7:0] read_cnt_d1_1 = read_cnt_d1_0 + 8'd1;
wire [7:0] read_cnt_d1_2 = read_cnt_d1_0 + 8'd2;
wire [7:0] read_cnt_d1_3 = read_cnt_d1_0 + 8'd3;

// reg [7:0] img_buffer [0:255]
always @(posedge clk) begin
    if (current_state == S_READ) begin
        case (r_mem_num)
            0: img_buffer[read_cnt_d1_0] <= mem0_dout;
            1: img_buffer[read_cnt_d1_0] <= mem1_dout;
            2: img_buffer[read_cnt_d1_0] <= mem2_dout;
            3: img_buffer[read_cnt_d1_0] <= mem3_dout;
            4: begin
                img_buffer[read_cnt_d1_0] <= mem4_dout[15:8];
                img_buffer[read_cnt_d1_1] <= mem4_dout[7:0];
            end
            5: begin
                img_buffer[read_cnt_d1_0] <= mem5_dout[15:8];
                img_buffer[read_cnt_d1_1] <= mem5_dout[7:0];
            end
            6: begin
                img_buffer[read_cnt_d1_0] <= mem6_dout[31:24];
                img_buffer[read_cnt_d1_1] <= mem6_dout[23:16];
                img_buffer[read_cnt_d1_2] <= mem6_dout[15:8];
                img_buffer[read_cnt_d1_3] <= mem6_dout[7:0];
            end
            default: begin  // 7
                img_buffer[read_cnt_d1_0] <= mem7_dout[31:24];
                img_buffer[read_cnt_d1_1] <= mem7_dout[23:16];
                img_buffer[read_cnt_d1_2] <= mem7_dout[15:8];
                img_buffer[read_cnt_d1_3] <= mem7_dout[7:0];
            end
        endcase
    end
end

// -----------------------------------------------------
// calulation / output
// -----------------------------------------------------

// reg [7:0] out_cnt;      // 0~255
always @(posedge clk or negedge rst_n) begin
    if      (!rst_n)                       out_cnt <= 9'd0;
    else if (out_cnt == 9'd256)            out_cnt <= 9'd0;
    else if (current_state == S_CAL_WRITE) out_cnt <= out_cnt + w_byte;
end

always @(posedge clk) begin
    out_cnt_d1 <= out_cnt;
end

wire [7:0] out_cnt_1 = out_cnt + 9'd1;
wire [7:0] out_cnt_2 = out_cnt + 9'd2;
wire [7:0] out_cnt_3 = out_cnt + 9'd3;

function [7:0] get_zz4_idx;
    input [7:0] out_idx;
    begin
        case(out_idx)
            8'd0: get_zz4_idx = 8'd0; 	8'd1: get_zz4_idx = 8'd1; 	8'd2: get_zz4_idx = 8'd16; 	8'd3: get_zz4_idx = 8'd32; 	8'd4: get_zz4_idx = 8'd4; 	8'd5: get_zz4_idx = 8'd5; 	8'd6: get_zz4_idx = 8'd20; 	8'd7: get_zz4_idx = 8'd36; 	8'd8: get_zz4_idx = 8'd8; 	8'd9: get_zz4_idx = 8'd9; 	8'd10: get_zz4_idx = 8'd24; 	8'd11: get_zz4_idx = 8'd40; 	8'd12: get_zz4_idx = 8'd12; 	8'd13: get_zz4_idx = 8'd13; 	8'd14: get_zz4_idx = 8'd28; 	8'd15: get_zz4_idx = 8'd44; 
            8'd16: get_zz4_idx = 8'd17; 	8'd17: get_zz4_idx = 8'd2; 	8'd18: get_zz4_idx = 8'd3; 	8'd19: get_zz4_idx = 8'd18; 	8'd20: get_zz4_idx = 8'd21; 	8'd21: get_zz4_idx = 8'd6; 	8'd22: get_zz4_idx = 8'd7; 	8'd23: get_zz4_idx = 8'd22; 	8'd24: get_zz4_idx = 8'd25; 	8'd25: get_zz4_idx = 8'd10; 	8'd26: get_zz4_idx = 8'd11; 	8'd27: get_zz4_idx = 8'd26; 	8'd28: get_zz4_idx = 8'd29; 	8'd29: get_zz4_idx = 8'd14; 	8'd30: get_zz4_idx = 8'd15; 	8'd31: get_zz4_idx = 8'd30; 
            8'd32: get_zz4_idx = 8'd33; 	8'd33: get_zz4_idx = 8'd48; 	8'd34: get_zz4_idx = 8'd49; 	8'd35: get_zz4_idx = 8'd34; 	8'd36: get_zz4_idx = 8'd37; 	8'd37: get_zz4_idx = 8'd52; 	8'd38: get_zz4_idx = 8'd53; 	8'd39: get_zz4_idx = 8'd38; 	8'd40: get_zz4_idx = 8'd41; 	8'd41: get_zz4_idx = 8'd56; 	8'd42: get_zz4_idx = 8'd57; 	8'd43: get_zz4_idx = 8'd42; 	8'd44: get_zz4_idx = 8'd45; 	8'd45: get_zz4_idx = 8'd60; 	8'd46: get_zz4_idx = 8'd61; 	8'd47: get_zz4_idx = 8'd46; 
            8'd48: get_zz4_idx = 8'd19; 	8'd49: get_zz4_idx = 8'd35; 	8'd50: get_zz4_idx = 8'd50; 	8'd51: get_zz4_idx = 8'd51; 	8'd52: get_zz4_idx = 8'd23; 	8'd53: get_zz4_idx = 8'd39; 	8'd54: get_zz4_idx = 8'd54; 	8'd55: get_zz4_idx = 8'd55; 	8'd56: get_zz4_idx = 8'd27; 	8'd57: get_zz4_idx = 8'd43; 	8'd58: get_zz4_idx = 8'd58; 	8'd59: get_zz4_idx = 8'd59; 	8'd60: get_zz4_idx = 8'd31; 	8'd61: get_zz4_idx = 8'd47; 	8'd62: get_zz4_idx = 8'd62; 	8'd63: get_zz4_idx = 8'd63; 
            8'd64: get_zz4_idx = 8'd64; 	8'd65: get_zz4_idx = 8'd65; 	8'd66: get_zz4_idx = 8'd80; 	8'd67: get_zz4_idx = 8'd96; 	8'd68: get_zz4_idx = 8'd68; 	8'd69: get_zz4_idx = 8'd69; 	8'd70: get_zz4_idx = 8'd84; 	8'd71: get_zz4_idx = 8'd100; 	8'd72: get_zz4_idx = 8'd72; 	8'd73: get_zz4_idx = 8'd73; 	8'd74: get_zz4_idx = 8'd88; 	8'd75: get_zz4_idx = 8'd104; 	8'd76: get_zz4_idx = 8'd76; 	8'd77: get_zz4_idx = 8'd77; 	8'd78: get_zz4_idx = 8'd92; 	8'd79: get_zz4_idx = 8'd108; 
            8'd80: get_zz4_idx = 8'd81; 	8'd81: get_zz4_idx = 8'd66; 	8'd82: get_zz4_idx = 8'd67; 	8'd83: get_zz4_idx = 8'd82; 	8'd84: get_zz4_idx = 8'd85; 	8'd85: get_zz4_idx = 8'd70; 	8'd86: get_zz4_idx = 8'd71; 	8'd87: get_zz4_idx = 8'd86; 	8'd88: get_zz4_idx = 8'd89; 	8'd89: get_zz4_idx = 8'd74; 	8'd90: get_zz4_idx = 8'd75; 	8'd91: get_zz4_idx = 8'd90; 	8'd92: get_zz4_idx = 8'd93; 	8'd93: get_zz4_idx = 8'd78; 	8'd94: get_zz4_idx = 8'd79; 	8'd95: get_zz4_idx = 8'd94; 
            8'd96: get_zz4_idx = 8'd97; 	8'd97: get_zz4_idx = 8'd112; 	8'd98: get_zz4_idx = 8'd113; 	8'd99: get_zz4_idx = 8'd98; 	8'd100: get_zz4_idx = 8'd101; 	8'd101: get_zz4_idx = 8'd116; 	8'd102: get_zz4_idx = 8'd117; 	8'd103: get_zz4_idx = 8'd102; 	8'd104: get_zz4_idx = 8'd105; 	8'd105: get_zz4_idx = 8'd120; 	8'd106: get_zz4_idx = 8'd121; 	8'd107: get_zz4_idx = 8'd106; 	8'd108: get_zz4_idx = 8'd109; 	8'd109: get_zz4_idx = 8'd124; 	8'd110: get_zz4_idx = 8'd125; 	8'd111: get_zz4_idx = 8'd110; 
            8'd112: get_zz4_idx = 8'd83; 	8'd113: get_zz4_idx = 8'd99; 	8'd114: get_zz4_idx = 8'd114; 	8'd115: get_zz4_idx = 8'd115; 	8'd116: get_zz4_idx = 8'd87; 	8'd117: get_zz4_idx = 8'd103; 	8'd118: get_zz4_idx = 8'd118; 	8'd119: get_zz4_idx = 8'd119; 	8'd120: get_zz4_idx = 8'd91; 	8'd121: get_zz4_idx = 8'd107; 	8'd122: get_zz4_idx = 8'd122; 	8'd123: get_zz4_idx = 8'd123; 	8'd124: get_zz4_idx = 8'd95; 	8'd125: get_zz4_idx = 8'd111; 	8'd126: get_zz4_idx = 8'd126; 	8'd127: get_zz4_idx = 8'd127; 
            8'd128: get_zz4_idx = 8'd128; 	8'd129: get_zz4_idx = 8'd129; 	8'd130: get_zz4_idx = 8'd144; 	8'd131: get_zz4_idx = 8'd160; 	8'd132: get_zz4_idx = 8'd132; 	8'd133: get_zz4_idx = 8'd133; 	8'd134: get_zz4_idx = 8'd148; 	8'd135: get_zz4_idx = 8'd164; 	8'd136: get_zz4_idx = 8'd136; 	8'd137: get_zz4_idx = 8'd137; 	8'd138: get_zz4_idx = 8'd152; 	8'd139: get_zz4_idx = 8'd168; 	8'd140: get_zz4_idx = 8'd140; 	8'd141: get_zz4_idx = 8'd141; 	8'd142: get_zz4_idx = 8'd156; 	8'd143: get_zz4_idx = 8'd172; 
            8'd144: get_zz4_idx = 8'd145; 	8'd145: get_zz4_idx = 8'd130; 	8'd146: get_zz4_idx = 8'd131; 	8'd147: get_zz4_idx = 8'd146; 	8'd148: get_zz4_idx = 8'd149; 	8'd149: get_zz4_idx = 8'd134; 	8'd150: get_zz4_idx = 8'd135; 	8'd151: get_zz4_idx = 8'd150; 	8'd152: get_zz4_idx = 8'd153; 	8'd153: get_zz4_idx = 8'd138; 	8'd154: get_zz4_idx = 8'd139; 	8'd155: get_zz4_idx = 8'd154; 	8'd156: get_zz4_idx = 8'd157; 	8'd157: get_zz4_idx = 8'd142; 	8'd158: get_zz4_idx = 8'd143; 	8'd159: get_zz4_idx = 8'd158; 
            8'd160: get_zz4_idx = 8'd161; 	8'd161: get_zz4_idx = 8'd176; 	8'd162: get_zz4_idx = 8'd177; 	8'd163: get_zz4_idx = 8'd162; 	8'd164: get_zz4_idx = 8'd165; 	8'd165: get_zz4_idx = 8'd180; 	8'd166: get_zz4_idx = 8'd181; 	8'd167: get_zz4_idx = 8'd166; 	8'd168: get_zz4_idx = 8'd169; 	8'd169: get_zz4_idx = 8'd184; 	8'd170: get_zz4_idx = 8'd185; 	8'd171: get_zz4_idx = 8'd170; 	8'd172: get_zz4_idx = 8'd173; 	8'd173: get_zz4_idx = 8'd188; 	8'd174: get_zz4_idx = 8'd189; 	8'd175: get_zz4_idx = 8'd174; 
            8'd176: get_zz4_idx = 8'd147; 	8'd177: get_zz4_idx = 8'd163; 	8'd178: get_zz4_idx = 8'd178; 	8'd179: get_zz4_idx = 8'd179; 	8'd180: get_zz4_idx = 8'd151; 	8'd181: get_zz4_idx = 8'd167; 	8'd182: get_zz4_idx = 8'd182; 	8'd183: get_zz4_idx = 8'd183; 	8'd184: get_zz4_idx = 8'd155; 	8'd185: get_zz4_idx = 8'd171; 	8'd186: get_zz4_idx = 8'd186; 	8'd187: get_zz4_idx = 8'd187; 	8'd188: get_zz4_idx = 8'd159; 	8'd189: get_zz4_idx = 8'd175; 	8'd190: get_zz4_idx = 8'd190; 	8'd191: get_zz4_idx = 8'd191; 
            8'd192: get_zz4_idx = 8'd192; 	8'd193: get_zz4_idx = 8'd193; 	8'd194: get_zz4_idx = 8'd208; 	8'd195: get_zz4_idx = 8'd224; 	8'd196: get_zz4_idx = 8'd196; 	8'd197: get_zz4_idx = 8'd197; 	8'd198: get_zz4_idx = 8'd212; 	8'd199: get_zz4_idx = 8'd228; 	8'd200: get_zz4_idx = 8'd200; 	8'd201: get_zz4_idx = 8'd201; 	8'd202: get_zz4_idx = 8'd216; 	8'd203: get_zz4_idx = 8'd232; 	8'd204: get_zz4_idx = 8'd204; 	8'd205: get_zz4_idx = 8'd205; 	8'd206: get_zz4_idx = 8'd220; 	8'd207: get_zz4_idx = 8'd236; 
            8'd208: get_zz4_idx = 8'd209; 	8'd209: get_zz4_idx = 8'd194; 	8'd210: get_zz4_idx = 8'd195; 	8'd211: get_zz4_idx = 8'd210; 	8'd212: get_zz4_idx = 8'd213; 	8'd213: get_zz4_idx = 8'd198; 	8'd214: get_zz4_idx = 8'd199; 	8'd215: get_zz4_idx = 8'd214; 	8'd216: get_zz4_idx = 8'd217; 	8'd217: get_zz4_idx = 8'd202; 	8'd218: get_zz4_idx = 8'd203; 	8'd219: get_zz4_idx = 8'd218; 	8'd220: get_zz4_idx = 8'd221; 	8'd221: get_zz4_idx = 8'd206; 	8'd222: get_zz4_idx = 8'd207; 	8'd223: get_zz4_idx = 8'd222; 
            8'd224: get_zz4_idx = 8'd225; 	8'd225: get_zz4_idx = 8'd240; 	8'd226: get_zz4_idx = 8'd241; 	8'd227: get_zz4_idx = 8'd226; 	8'd228: get_zz4_idx = 8'd229; 	8'd229: get_zz4_idx = 8'd244; 	8'd230: get_zz4_idx = 8'd245; 	8'd231: get_zz4_idx = 8'd230; 	8'd232: get_zz4_idx = 8'd233; 	8'd233: get_zz4_idx = 8'd248; 	8'd234: get_zz4_idx = 8'd249; 	8'd235: get_zz4_idx = 8'd234; 	8'd236: get_zz4_idx = 8'd237; 	8'd237: get_zz4_idx = 8'd252; 	8'd238: get_zz4_idx = 8'd253; 	8'd239: get_zz4_idx = 8'd238; 
            8'd240: get_zz4_idx = 8'd211; 	8'd241: get_zz4_idx = 8'd227; 	8'd242: get_zz4_idx = 8'd242; 	8'd243: get_zz4_idx = 8'd243; 	8'd244: get_zz4_idx = 8'd215; 	8'd245: get_zz4_idx = 8'd231; 	8'd246: get_zz4_idx = 8'd246; 	8'd247: get_zz4_idx = 8'd247; 	8'd248: get_zz4_idx = 8'd219; 	8'd249: get_zz4_idx = 8'd235; 	8'd250: get_zz4_idx = 8'd250; 	8'd251: get_zz4_idx = 8'd251; 	8'd252: get_zz4_idx = 8'd223; 	8'd253: get_zz4_idx = 8'd239; 	8'd254: get_zz4_idx = 8'd254; 	8'd255: get_zz4_idx = 8'd255; 
            default: get_zz4_idx = 8'd0;    // no used
        endcase
    end
endfunction

function [7:0] get_zz8_idx;
    input [7:0] out_idx;
    begin
        case(out_idx)
            8'd0: get_zz8_idx = 8'd0; 	8'd1: get_zz8_idx = 8'd1; 	8'd2: get_zz8_idx = 8'd16; 	8'd3: get_zz8_idx = 8'd32; 	8'd4: get_zz8_idx = 8'd17; 	8'd5: get_zz8_idx = 8'd2; 	8'd6: get_zz8_idx = 8'd3; 	8'd7: get_zz8_idx = 8'd18; 	8'd8: get_zz8_idx = 8'd8; 	8'd9: get_zz8_idx = 8'd9; 	8'd10: get_zz8_idx = 8'd24; 	8'd11: get_zz8_idx = 8'd40; 	8'd12: get_zz8_idx = 8'd25; 	8'd13: get_zz8_idx = 8'd10; 	8'd14: get_zz8_idx = 8'd11; 	8'd15: get_zz8_idx = 8'd26; 
            8'd16: get_zz8_idx = 8'd33; 	8'd17: get_zz8_idx = 8'd48; 	8'd18: get_zz8_idx = 8'd64; 	8'd19: get_zz8_idx = 8'd49; 	8'd20: get_zz8_idx = 8'd34; 	8'd21: get_zz8_idx = 8'd19; 	8'd22: get_zz8_idx = 8'd4; 	8'd23: get_zz8_idx = 8'd5; 	8'd24: get_zz8_idx = 8'd41; 	8'd25: get_zz8_idx = 8'd56; 	8'd26: get_zz8_idx = 8'd72; 	8'd27: get_zz8_idx = 8'd57; 	8'd28: get_zz8_idx = 8'd42; 	8'd29: get_zz8_idx = 8'd27; 	8'd30: get_zz8_idx = 8'd12; 	8'd31: get_zz8_idx = 8'd13; 
            8'd32: get_zz8_idx = 8'd20; 	8'd33: get_zz8_idx = 8'd35; 	8'd34: get_zz8_idx = 8'd50; 	8'd35: get_zz8_idx = 8'd65; 	8'd36: get_zz8_idx = 8'd80; 	8'd37: get_zz8_idx = 8'd96; 	8'd38: get_zz8_idx = 8'd81; 	8'd39: get_zz8_idx = 8'd66; 	8'd40: get_zz8_idx = 8'd28; 	8'd41: get_zz8_idx = 8'd43; 	8'd42: get_zz8_idx = 8'd58; 	8'd43: get_zz8_idx = 8'd73; 	8'd44: get_zz8_idx = 8'd88; 	8'd45: get_zz8_idx = 8'd104; 	8'd46: get_zz8_idx = 8'd89; 	8'd47: get_zz8_idx = 8'd74; 
            8'd48: get_zz8_idx = 8'd51; 	8'd49: get_zz8_idx = 8'd36; 	8'd50: get_zz8_idx = 8'd21; 	8'd51: get_zz8_idx = 8'd6; 	8'd52: get_zz8_idx = 8'd7; 	8'd53: get_zz8_idx = 8'd22; 	8'd54: get_zz8_idx = 8'd37; 	8'd55: get_zz8_idx = 8'd52; 	8'd56: get_zz8_idx = 8'd59; 	8'd57: get_zz8_idx = 8'd44; 	8'd58: get_zz8_idx = 8'd29; 	8'd59: get_zz8_idx = 8'd14; 	8'd60: get_zz8_idx = 8'd15; 	8'd61: get_zz8_idx = 8'd30; 	8'd62: get_zz8_idx = 8'd45; 	8'd63: get_zz8_idx = 8'd60; 
            8'd64: get_zz8_idx = 8'd67; 	8'd65: get_zz8_idx = 8'd82; 	8'd66: get_zz8_idx = 8'd97; 	8'd67: get_zz8_idx = 8'd112; 	8'd68: get_zz8_idx = 8'd113; 	8'd69: get_zz8_idx = 8'd98; 	8'd70: get_zz8_idx = 8'd83; 	8'd71: get_zz8_idx = 8'd68; 	8'd72: get_zz8_idx = 8'd75; 	8'd73: get_zz8_idx = 8'd90; 	8'd74: get_zz8_idx = 8'd105; 	8'd75: get_zz8_idx = 8'd120; 	8'd76: get_zz8_idx = 8'd121; 	8'd77: get_zz8_idx = 8'd106; 	8'd78: get_zz8_idx = 8'd91; 	8'd79: get_zz8_idx = 8'd76; 
            8'd80: get_zz8_idx = 8'd53; 	8'd81: get_zz8_idx = 8'd38; 	8'd82: get_zz8_idx = 8'd23; 	8'd83: get_zz8_idx = 8'd39; 	8'd84: get_zz8_idx = 8'd54; 	8'd85: get_zz8_idx = 8'd69; 	8'd86: get_zz8_idx = 8'd84; 	8'd87: get_zz8_idx = 8'd99; 	8'd88: get_zz8_idx = 8'd61; 	8'd89: get_zz8_idx = 8'd46; 	8'd90: get_zz8_idx = 8'd31; 	8'd91: get_zz8_idx = 8'd47; 	8'd92: get_zz8_idx = 8'd62; 	8'd93: get_zz8_idx = 8'd77; 	8'd94: get_zz8_idx = 8'd92; 	8'd95: get_zz8_idx = 8'd107; 
            8'd96: get_zz8_idx = 8'd114; 	8'd97: get_zz8_idx = 8'd115; 	8'd98: get_zz8_idx = 8'd100; 	8'd99: get_zz8_idx = 8'd85; 	8'd100: get_zz8_idx = 8'd70; 	8'd101: get_zz8_idx = 8'd55; 	8'd102: get_zz8_idx = 8'd71; 	8'd103: get_zz8_idx = 8'd86; 	8'd104: get_zz8_idx = 8'd122; 	8'd105: get_zz8_idx = 8'd123; 	8'd106: get_zz8_idx = 8'd108; 	8'd107: get_zz8_idx = 8'd93; 	8'd108: get_zz8_idx = 8'd78; 	8'd109: get_zz8_idx = 8'd63; 	8'd110: get_zz8_idx = 8'd79; 	8'd111: get_zz8_idx = 8'd94; 
            8'd112: get_zz8_idx = 8'd101; 	8'd113: get_zz8_idx = 8'd116; 	8'd114: get_zz8_idx = 8'd117; 	8'd115: get_zz8_idx = 8'd102; 	8'd116: get_zz8_idx = 8'd87; 	8'd117: get_zz8_idx = 8'd103; 	8'd118: get_zz8_idx = 8'd118; 	8'd119: get_zz8_idx = 8'd119; 	8'd120: get_zz8_idx = 8'd109; 	8'd121: get_zz8_idx = 8'd124; 	8'd122: get_zz8_idx = 8'd125; 	8'd123: get_zz8_idx = 8'd110; 	8'd124: get_zz8_idx = 8'd95; 	8'd125: get_zz8_idx = 8'd111; 	8'd126: get_zz8_idx = 8'd126; 	8'd127: get_zz8_idx = 8'd127; 
            8'd128: get_zz8_idx = 8'd128; 	8'd129: get_zz8_idx = 8'd129; 	8'd130: get_zz8_idx = 8'd144; 	8'd131: get_zz8_idx = 8'd160; 	8'd132: get_zz8_idx = 8'd145; 	8'd133: get_zz8_idx = 8'd130; 	8'd134: get_zz8_idx = 8'd131; 	8'd135: get_zz8_idx = 8'd146; 	8'd136: get_zz8_idx = 8'd136; 	8'd137: get_zz8_idx = 8'd137; 	8'd138: get_zz8_idx = 8'd152; 	8'd139: get_zz8_idx = 8'd168; 	8'd140: get_zz8_idx = 8'd153; 	8'd141: get_zz8_idx = 8'd138; 	8'd142: get_zz8_idx = 8'd139; 	8'd143: get_zz8_idx = 8'd154; 
            8'd144: get_zz8_idx = 8'd161; 	8'd145: get_zz8_idx = 8'd176; 	8'd146: get_zz8_idx = 8'd192; 	8'd147: get_zz8_idx = 8'd177; 	8'd148: get_zz8_idx = 8'd162; 	8'd149: get_zz8_idx = 8'd147; 	8'd150: get_zz8_idx = 8'd132; 	8'd151: get_zz8_idx = 8'd133; 	8'd152: get_zz8_idx = 8'd169; 	8'd153: get_zz8_idx = 8'd184; 	8'd154: get_zz8_idx = 8'd200; 	8'd155: get_zz8_idx = 8'd185; 	8'd156: get_zz8_idx = 8'd170; 	8'd157: get_zz8_idx = 8'd155; 	8'd158: get_zz8_idx = 8'd140; 	8'd159: get_zz8_idx = 8'd141; 
            8'd160: get_zz8_idx = 8'd148; 	8'd161: get_zz8_idx = 8'd163; 	8'd162: get_zz8_idx = 8'd178; 	8'd163: get_zz8_idx = 8'd193; 	8'd164: get_zz8_idx = 8'd208; 	8'd165: get_zz8_idx = 8'd224; 	8'd166: get_zz8_idx = 8'd209; 	8'd167: get_zz8_idx = 8'd194; 	8'd168: get_zz8_idx = 8'd156; 	8'd169: get_zz8_idx = 8'd171; 	8'd170: get_zz8_idx = 8'd186; 	8'd171: get_zz8_idx = 8'd201; 	8'd172: get_zz8_idx = 8'd216; 	8'd173: get_zz8_idx = 8'd232; 	8'd174: get_zz8_idx = 8'd217; 	8'd175: get_zz8_idx = 8'd202; 
            8'd176: get_zz8_idx = 8'd179; 	8'd177: get_zz8_idx = 8'd164; 	8'd178: get_zz8_idx = 8'd149; 	8'd179: get_zz8_idx = 8'd134; 	8'd180: get_zz8_idx = 8'd135; 	8'd181: get_zz8_idx = 8'd150; 	8'd182: get_zz8_idx = 8'd165; 	8'd183: get_zz8_idx = 8'd180; 	8'd184: get_zz8_idx = 8'd187; 	8'd185: get_zz8_idx = 8'd172; 	8'd186: get_zz8_idx = 8'd157; 	8'd187: get_zz8_idx = 8'd142; 	8'd188: get_zz8_idx = 8'd143; 	8'd189: get_zz8_idx = 8'd158; 	8'd190: get_zz8_idx = 8'd173; 	8'd191: get_zz8_idx = 8'd188; 
            8'd192: get_zz8_idx = 8'd195; 	8'd193: get_zz8_idx = 8'd210; 	8'd194: get_zz8_idx = 8'd225; 	8'd195: get_zz8_idx = 8'd240; 	8'd196: get_zz8_idx = 8'd241; 	8'd197: get_zz8_idx = 8'd226; 	8'd198: get_zz8_idx = 8'd211; 	8'd199: get_zz8_idx = 8'd196; 	8'd200: get_zz8_idx = 8'd203; 	8'd201: get_zz8_idx = 8'd218; 	8'd202: get_zz8_idx = 8'd233; 	8'd203: get_zz8_idx = 8'd248; 	8'd204: get_zz8_idx = 8'd249; 	8'd205: get_zz8_idx = 8'd234; 	8'd206: get_zz8_idx = 8'd219; 	8'd207: get_zz8_idx = 8'd204; 
            8'd208: get_zz8_idx = 8'd181; 	8'd209: get_zz8_idx = 8'd166; 	8'd210: get_zz8_idx = 8'd151; 	8'd211: get_zz8_idx = 8'd167; 	8'd212: get_zz8_idx = 8'd182; 	8'd213: get_zz8_idx = 8'd197; 	8'd214: get_zz8_idx = 8'd212; 	8'd215: get_zz8_idx = 8'd227; 	8'd216: get_zz8_idx = 8'd189; 	8'd217: get_zz8_idx = 8'd174; 	8'd218: get_zz8_idx = 8'd159; 	8'd219: get_zz8_idx = 8'd175; 	8'd220: get_zz8_idx = 8'd190; 	8'd221: get_zz8_idx = 8'd205; 	8'd222: get_zz8_idx = 8'd220; 	8'd223: get_zz8_idx = 8'd235; 
            8'd224: get_zz8_idx = 8'd242; 	8'd225: get_zz8_idx = 8'd243; 	8'd226: get_zz8_idx = 8'd228; 	8'd227: get_zz8_idx = 8'd213; 	8'd228: get_zz8_idx = 8'd198; 	8'd229: get_zz8_idx = 8'd183; 	8'd230: get_zz8_idx = 8'd199; 	8'd231: get_zz8_idx = 8'd214; 	8'd232: get_zz8_idx = 8'd250; 	8'd233: get_zz8_idx = 8'd251; 	8'd234: get_zz8_idx = 8'd236; 	8'd235: get_zz8_idx = 8'd221; 	8'd236: get_zz8_idx = 8'd206; 	8'd237: get_zz8_idx = 8'd191; 	8'd238: get_zz8_idx = 8'd207; 	8'd239: get_zz8_idx = 8'd222; 
            8'd240: get_zz8_idx = 8'd229; 	8'd241: get_zz8_idx = 8'd244; 	8'd242: get_zz8_idx = 8'd245; 	8'd243: get_zz8_idx = 8'd230; 	8'd244: get_zz8_idx = 8'd215; 	8'd245: get_zz8_idx = 8'd231; 	8'd246: get_zz8_idx = 8'd246; 	8'd247: get_zz8_idx = 8'd247; 	8'd248: get_zz8_idx = 8'd237; 	8'd249: get_zz8_idx = 8'd252; 	8'd250: get_zz8_idx = 8'd253; 	8'd251: get_zz8_idx = 8'd238; 	8'd252: get_zz8_idx = 8'd223; 	8'd253: get_zz8_idx = 8'd239; 	8'd254: get_zz8_idx = 8'd254; 	8'd255: get_zz8_idx = 8'd255; 
            default: get_zz8_idx = 8'd0;    // no used
        endcase
    end
endfunction

// x = i%16
// y = i/16
// matrix(a, b) = buffer[(a)+(b)*16]

wire [3:0] out_cnt_0_x = out_cnt[3:0];
wire [3:0] out_cnt_0_y = out_cnt[7:4];

wire [3:0] out_cnt_1_x = out_cnt_1[3:0];
wire [3:0] out_cnt_1_y = out_cnt_1[7:4];

wire [3:0] out_cnt_2_x = out_cnt_2[3:0];
wire [3:0] out_cnt_2_y = out_cnt_2[7:4];

wire [3:0] out_cnt_3_x = out_cnt_3[3:0];
wire [3:0] out_cnt_3_y = out_cnt_3[7:4];

wire [3:0] LS_tmp_0 = 5'd26 - {1'b0, out_cnt_0_x};
wire [3:0] LS_tmp_1 = 5'd26 - {1'b0, out_cnt_1_x};
wire [3:0] LS_tmp_2 = 5'd26 - {1'b0, out_cnt_2_x};
wire [3:0] LS_tmp_3 = 5'd26 - {1'b0, out_cnt_3_x};

wire [3:0] US_tmp_0 = 5'd26 - {1'b0, out_cnt_0_y};
wire [3:0] US_tmp_1 = 5'd26 - {1'b0, out_cnt_1_y};
wire [3:0] US_tmp_2 = 5'd26 - {1'b0, out_cnt_2_y};
wire [3:0] US_tmp_3 = 5'd26 - {1'b0, out_cnt_3_y};

// reg [7:0] src_idx [0:3];
always @(*) begin
    integer i;
    for (i = 0; i < 4; i = i + 1) src_idx[i] = 8'd0;
    // {  row  ,   col  }
    // {4'byyyy, 4'bxxxx}
    case (op_func)
        MX: begin       // {15-y, x}
            src_idx[0] = {~out_cnt_0_y, out_cnt_0_x};
            src_idx[1] = {~out_cnt_1_y, out_cnt_1_x};
            src_idx[2] = {~out_cnt_2_y, out_cnt_2_x};
            src_idx[3] = {~out_cnt_3_y, out_cnt_3_x};
        end
        MY: begin       // {y, 15-x}
            src_idx[0] = {out_cnt_0_y, ~out_cnt_0_x};
            src_idx[1] = {out_cnt_1_y, ~out_cnt_1_x};
            src_idx[2] = {out_cnt_2_y, ~out_cnt_2_x};
            src_idx[3] = {out_cnt_3_y, ~out_cnt_3_x};
        end
        TRP: begin      // {x, y}
            src_idx[0] = {out_cnt_0_x, out_cnt_0_y};
            src_idx[1] = {out_cnt_1_x, out_cnt_1_y};
            src_idx[2] = {out_cnt_2_x, out_cnt_2_y};
            src_idx[3] = {out_cnt_3_x, out_cnt_3_y};
        end
        STRP: begin     // {15-x, 15-y}
            src_idx[0] = {~out_cnt_0_x, ~out_cnt_0_y};
            src_idx[1] = {~out_cnt_1_x, ~out_cnt_1_y};
            src_idx[2] = {~out_cnt_2_x, ~out_cnt_2_y};
            src_idx[3] = {~out_cnt_3_x, ~out_cnt_3_y};
        end
        R90: begin      // {15-x, y}
            src_idx[0] = {~out_cnt_0_x, out_cnt_0_y};
            src_idx[1] = {~out_cnt_1_x, out_cnt_1_y};
            src_idx[2] = {~out_cnt_2_x, out_cnt_2_y};
            src_idx[3] = {~out_cnt_3_x, out_cnt_3_y};
        end
        R180: begin     // 255-cnt
            src_idx[0] = ~out_cnt;
            src_idx[1] = ~out_cnt_1;
            src_idx[2] = ~out_cnt_2;
            src_idx[3] = ~out_cnt_3;
        end
        R270: begin     // {x, 15-y}
            src_idx[0] = {out_cnt_0_x, ~out_cnt_0_y};
            src_idx[0] = {out_cnt_0_x, ~out_cnt_0_y};
            src_idx[0] = {out_cnt_0_x, ~out_cnt_0_y};
            src_idx[0] = {out_cnt_0_x, ~out_cnt_0_y};
        end
        RS: begin
            src_idx[0] = (out_cnt_0_x < 4'd5) ? {out_cnt_0_y, (4'd4 - out_cnt_0_x)} : {out_cnt_0_y, (out_cnt_0_x - 4'd5)};
            src_idx[1] = (out_cnt_1_x < 4'd5) ? {out_cnt_1_y, (4'd4 - out_cnt_1_x)} : {out_cnt_1_y, (out_cnt_1_x - 4'd5)};
            src_idx[2] = (out_cnt_2_x < 4'd5) ? {out_cnt_2_y, (4'd4 - out_cnt_2_x)} : {out_cnt_2_y, (out_cnt_2_x - 4'd5)};
            src_idx[3] = (out_cnt_3_x < 4'd5) ? {out_cnt_3_y, (4'd4 - out_cnt_3_x)} : {out_cnt_3_y, (out_cnt_3_x - 4'd5)};
        end
        LS: begin
            src_idx[0] = (out_cnt_0_x > 4'd10) ? {out_cnt_0_y, LS_tmp_0} : {out_cnt_0_y, (out_cnt_0_x + 4'd5)};
            src_idx[1] = (out_cnt_1_x > 4'd10) ? {out_cnt_1_y, LS_tmp_1} : {out_cnt_1_y, (out_cnt_1_x + 4'd5)};
            src_idx[2] = (out_cnt_2_x > 4'd10) ? {out_cnt_2_y, LS_tmp_2} : {out_cnt_2_y, (out_cnt_2_x + 4'd5)};
            src_idx[3] = (out_cnt_3_x > 4'd10) ? {out_cnt_3_y, LS_tmp_3} : {out_cnt_3_y, (out_cnt_3_x + 4'd5)};
        end
        US: begin
            src_idx[0] = (out_cnt_0_y > 4'd10) ? {US_tmp_0, out_cnt_0_x} : {(out_cnt_0_y + 4'd5), out_cnt_0_x};
            src_idx[1] = (out_cnt_1_y > 4'd10) ? {US_tmp_1, out_cnt_1_x} : {(out_cnt_1_y + 4'd5), out_cnt_1_x};
            src_idx[2] = (out_cnt_2_y > 4'd10) ? {US_tmp_2, out_cnt_2_x} : {(out_cnt_2_y + 4'd5), out_cnt_2_x};
            src_idx[3] = (out_cnt_3_y > 4'd10) ? {US_tmp_3, out_cnt_3_x} : {(out_cnt_3_y + 4'd5), out_cnt_3_x};
        end
        DS: begin
            src_idx[0] = (out_cnt_0_y < 4'd5) ? {(4'd4 - out_cnt_0_y), out_cnt_0_x} : {(out_cnt_0_y - 4'd5), out_cnt_0_x};
            src_idx[1] = (out_cnt_1_y < 4'd5) ? {(4'd4 - out_cnt_1_y), out_cnt_1_x} : {(out_cnt_1_y - 4'd5), out_cnt_1_x};
            src_idx[2] = (out_cnt_2_y < 4'd5) ? {(4'd4 - out_cnt_2_y), out_cnt_2_x} : {(out_cnt_2_y - 4'd5), out_cnt_2_x};
            src_idx[3] = (out_cnt_3_y < 4'd5) ? {(4'd4 - out_cnt_3_y), out_cnt_3_x} : {(out_cnt_3_y - 4'd5), out_cnt_3_x};
        end
        ZZ4: begin
            src_idx[0] = get_zz4_idx(out_cnt);
            src_idx[1] = get_zz4_idx(out_cnt_1);
            src_idx[2] = get_zz4_idx(out_cnt_2);
            src_idx[3] = get_zz4_idx(out_cnt_3);
        end
        ZZ8: begin
            src_idx[0] = get_zz8_idx(out_cnt);
            src_idx[1] = get_zz8_idx(out_cnt_1);
            src_idx[2] = get_zz8_idx(out_cnt_2);
            src_idx[3] = get_zz8_idx(out_cnt_3);
        end
        MO4: begin
            src_idx[0] = {  out_cnt[7:6],   out_cnt[5],   out_cnt[1],   out_cnt[3],   out_cnt[2],   out_cnt[4],   out_cnt[0]};
            src_idx[1] = {out_cnt_1[7:6], out_cnt_1[5], out_cnt_1[1], out_cnt_1[3], out_cnt_1[2], out_cnt_1[4], out_cnt_1[0]};
            src_idx[2] = {out_cnt_2[7:6], out_cnt_2[5], out_cnt_2[1], out_cnt_2[3], out_cnt_2[2], out_cnt_2[4], out_cnt_2[0]};
            src_idx[3] = {out_cnt_3[7:6], out_cnt_3[5], out_cnt_3[1], out_cnt_3[3], out_cnt_3[2], out_cnt_3[4], out_cnt_3[0]};
        end
        MO8: begin
            src_idx[0] = {  out_cnt[7],   out_cnt[5],   out_cnt[3],   out_cnt[1],   out_cnt[6],   out_cnt[4],   out_cnt[2],   out_cnt[0]};
            src_idx[1] = {out_cnt_1[7], out_cnt_1[5], out_cnt_1[3], out_cnt_1[1], out_cnt_1[6], out_cnt_1[4], out_cnt_1[2], out_cnt_1[0]};
            src_idx[2] = {out_cnt_2[7], out_cnt_2[5], out_cnt_2[3], out_cnt_2[1], out_cnt_2[6], out_cnt_2[4], out_cnt_2[2], out_cnt_2[0]};
            src_idx[3] = {out_cnt_3[7], out_cnt_3[5], out_cnt_3[3], out_cnt_3[1], out_cnt_3[6], out_cnt_3[4], out_cnt_3[2], out_cnt_3[0]};
        end
    endcase
end

// reg [7:0] result_pixel [0:3];
always @(posedge clk) begin
    result_pixel[0] <= img_buffer[src_idx[0]];
    result_pixel[1] <= img_buffer[src_idx[1]];
    result_pixel[2] <= img_buffer[src_idx[2]];
    result_pixel[3] <= img_buffer[src_idx[3]];
end

// -----------------------------------------------------
// MEM input
// -----------------------------------------------------

wire [1:0] current_cnt = (current_state == S_INIT_SRAM) ? init_cnt_d1[1:0] : out_cnt_d1[1:0];  // _d1 ???????

// reg        mem0_web, mem1_web, mem2_web, mem3_web;
// reg        mem4_web, mem5_web;
// reg        mem6_web, mem7_web;
always @(*) begin
    mem0_web = MEM_READ;
    mem1_web = MEM_READ;
    mem2_web = MEM_READ;
    mem3_web = MEM_READ;
    mem4_web = MEM_READ;
    mem5_web = MEM_READ;
    mem6_web = MEM_READ;
    mem7_web = MEM_READ;
    if (current_state == S_INIT_SRAM || current_state == S_CAL_WRITE) begin
        case (mem_num)
            0: mem0_web = MEM_WRITE;
            1: mem1_web = MEM_WRITE;
            2: mem2_web = MEM_WRITE;
            3: mem3_web = MEM_WRITE;
            4: if (current_cnt[0]) mem4_web = MEM_WRITE;
            5: if (current_cnt[0]) mem5_web = MEM_WRITE;
            6: if (current_cnt[1] & current_cnt[0]) mem6_web = MEM_WRITE;
            7: if (current_cnt[1] & current_cnt[0]) mem7_web = MEM_WRITE;
        endcase
    end
end

// reg [2:0] mem_num;
always @(*) begin
    case (current_state)
        S_INIT_SRAM: mem_num = init_mem_num;
        // S_READ:      mem_num = r_mem_num;    all mem is MEM_READ already
        S_CAL_WRITE: mem_num = w_mem_num;
        default:     mem_num = 3'd0;
    endcase
end

// reg [3:0] mem_idx;
always @(*) begin
    case (current_state)
        S_INIT_SRAM: mem_idx = init_mem_idx;
        S_READ:      mem_idx = r_mem_idx;
        S_CAL_WRITE: mem_idx = w_mem_idx;
        default:     mem_idx = 4'd0;
    endcase
end

// reg [7:0] mem_offset;
always @(*) begin
    case (current_state)
        S_INIT_SRAM: mem_offset = init_mem_offset;
        S_READ:      mem_offset = read_cnt;
        S_CAL_WRITE: mem_offset = out_cnt_d1;
        default:     mem_offset = 8'd0;
    endcase
end

// reg [31:0] mem_in_data;
always @(*) begin
    case (current_state)
        S_INIT_SRAM: mem_in_data = {in_data_reg[0], in_data_reg[1], in_data_reg[2], in_data_reg[3]};
        // S_READ:      mem_in_data = 
        S_CAL_WRITE: mem_in_data = {result_pixel[0], result_pixel[1], result_pixel[2], result_pixel[3]};
        default:     mem_in_data = 32'd0;
    endcase
end

//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
/* 
  There are eight SRAMs in your GTE. You should not change the name of those SRAMs.
  TA will check the value in each SRAMs when your GTE is not busy.
  If you change the name of SRAMs below, you must get the fail in this lab.
  
  You should finish SRAM-related signals assignments for each SRAM.
*/
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// SRAM-related signals assignments
///////////////////////////////
// 0~15
assign mem0_addr = {mem_idx, mem_offset}; // 12 = 4 + 8
// assign mem0_web  = 
assign mem0_din  = mem_in_data[31:24];
// 16~31
assign mem1_addr = {mem_idx, mem_offset}; // 12 = 4 + 8
// assign mem1_web  = 
assign mem1_din  = mem_in_data[31:24];
// 32~47
assign mem2_addr = {mem_idx, mem_offset}; // 12 = 4 + 8
// assign mem2_web  = 
assign mem2_din  = mem_in_data[31:24];
// 48~63
assign mem3_addr = {mem_idx, mem_offset}; // 12 = 4 + 8
// assign mem3_web  = 
assign mem3_din  = mem_in_data[31:24];
///////////////////////////////
// 64~79
assign mem4_addr = {mem_idx, mem_offset[7:1]};    // 11 = 4 + 7
// assign mem4_web  = 
assign mem4_din  = mem_in_data[31:16];
// 80~95
assign mem5_addr = {mem_idx, mem_offset[7:1]};    // 11 = 4 + 7
// assign mem5_web  = 
assign mem5_din  = mem_in_data[31:16];
///////////////////////////////
// 96~111
assign mem6_addr = {mem_idx, mem_offset[7:2]};    // 10 = 4 + 6
// assign mem6_web  = 
assign mem6_din  = mem_in_data;
// 112~127
assign mem7_addr = {mem_idx, mem_offset[7:2]};    // 10 = 4 + 6
// assign mem7_web  = 
assign mem7_din  = mem_in_data;

// MEM_0, MEM_1, MEM_2, MEM_3, MEM_4, MEM_5, MEM_6, MEM_7 instantiation
SUMA180_4096X8X1BM4 MEM0(
    .A0(mem0_addr[0]), .A1(mem0_addr[1]), .A2(mem0_addr[2]), .A3(mem0_addr[3]), .A4(mem0_addr[4]), .A5(mem0_addr[5]), .A6(mem0_addr[6]), .A7(mem0_addr[7]), 
    .A8(mem0_addr[8]), .A9(mem0_addr[9]), .A10(mem0_addr[10]), .A11(mem0_addr[11]),
    .DO0(mem0_dout[0]), .DO1(mem0_dout[1]), .DO2(mem0_dout[2]), .DO3(mem0_dout[3]), .DO4(mem0_dout[4]), .DO5(mem0_dout[5]), .DO6(mem0_dout[6]), .DO7(mem0_dout[7]),
    .DI0(mem0_din[0]), .DI1(mem0_din[1]), .DI2(mem0_din[2]), .DI3(mem0_din[3]), .DI4(mem0_din[4]), .DI5(mem0_din[5]), .DI6(mem0_din[6]), .DI7(mem0_din[7]),
    .CK(clk), .WEB(mem0_web), .OE(1'b1), .CS(1'b1)
);

SUMA180_4096X8X1BM4 MEM1(
    .A0(mem1_addr[0]), .A1(mem1_addr[1]), .A2(mem1_addr[2]), .A3(mem1_addr[3]), .A4(mem1_addr[4]), .A5(mem1_addr[5]), .A6(mem1_addr[6]), .A7(mem1_addr[7]), 
    .A8(mem1_addr[8]), .A9(mem1_addr[9]), .A10(mem1_addr[10]), .A11(mem1_addr[11]),
    .DO0(mem1_dout[0]), .DO1(mem1_dout[1]), .DO2(mem1_dout[2]), .DO3(mem1_dout[3]), .DO4(mem1_dout[4]), .DO5(mem1_dout[5]), .DO6(mem1_dout[6]), .DO7(mem1_dout[7]),
    .DI0(mem1_din[0]), .DI1(mem1_din[1]), .DI2(mem1_din[2]), .DI3(mem1_din[3]), .DI4(mem1_din[4]), .DI5(mem1_din[5]), .DI6(mem1_din[6]), .DI7(mem1_din[7]),
    .CK(clk), .WEB(mem1_web), .OE(1'b1), .CS(1'b1)
);

SUMA180_4096X8X1BM4 MEM2 (
    .A0(mem2_addr[0]), .A1(mem2_addr[1]), .A2(mem2_addr[2]), .A3(mem2_addr[3]), .A4(mem2_addr[4]), .A5(mem2_addr[5]), .A6(mem2_addr[6]), .A7(mem2_addr[7]),
    .A8(mem2_addr[8]), .A9(mem2_addr[9]), .A10(mem2_addr[10]), .A11(mem2_addr[11]),
    .DO0(mem2_dout[0]), .DO1(mem2_dout[1]), .DO2(mem2_dout[2]), .DO3(mem2_dout[3]), .DO4(mem2_dout[4]), .DO5(mem2_dout[5]), .DO6(mem2_dout[6]), .DO7(mem2_dout[7]),
    .DI0(mem2_din[0]), .DI1(mem2_din[1]), .DI2(mem2_din[2]), .DI3(mem2_din[3]), .DI4(mem2_din[4]), .DI5(mem2_din[5]), .DI6(mem2_din[6]), .DI7(mem2_din[7]),
    .CK(clk), .WEB(mem2_web), .OE(1'b1), .CS(1'b1)
);

SUMA180_4096X8X1BM4 MEM3(
    .A0(mem3_addr[0]), .A1(mem3_addr[1]), .A2(mem3_addr[2]), .A3(mem3_addr[3]), .A4(mem3_addr[4]), .A5(mem3_addr[5]), .A6(mem3_addr[6]), .A7(mem3_addr[7]), 
    .A8(mem3_addr[8]), .A9(mem3_addr[9]), .A10(mem3_addr[10]), .A11(mem3_addr[11]),
    .DO0(mem3_dout[0]), .DO1(mem3_dout[1]), .DO2(mem3_dout[2]), .DO3(mem3_dout[3]), .DO4(mem3_dout[4]), .DO5(mem3_dout[5]), .DO6(mem3_dout[6]), .DO7(mem3_dout[7]),
    .DI0(mem3_din[0]), .DI1(mem3_din[1]), .DI2(mem3_din[2]), .DI3(mem3_din[3]), .DI4(mem3_din[4]), .DI5(mem3_din[5]), .DI6(mem3_din[6]), .DI7(mem3_din[7]),
    .CK(clk), .WEB(mem3_web), .OE(1'b1), .CS(1'b1)
);

SUMA180_2048X16X1BM1 MEM4(
	.A0(mem4_addr[0]), .A1(mem4_addr[1]), .A2(mem4_addr[2]), .A3(mem4_addr[3]), .A4(mem4_addr[4]), .A5(mem4_addr[5]), .A6(mem4_addr[6]), .A7(mem4_addr[7]), 
	.A8(mem4_addr[8]), .A9(mem4_addr[9]), .A10(mem4_addr[10]),
	.DO0(mem4_dout[0]), .DO1(mem4_dout[1]), .DO2(mem4_dout[2]), .DO3(mem4_dout[3]), .DO4(mem4_dout[4]), .DO5(mem4_dout[5]), .DO6(mem4_dout[6]), .DO7(mem4_dout[7]), 
	.DO8(mem4_dout[8]), .DO9(mem4_dout[9]), .DO10(mem4_dout[10]), .DO11(mem4_dout[11]), .DO12(mem4_dout[12]), .DO13(mem4_dout[13]), .DO14(mem4_dout[14]), .DO15(mem4_dout[15]),
	.DI0(mem4_din[0]), .DI1(mem4_din[1]), .DI2(mem4_din[2]), .DI3(mem4_din[3]), .DI4(mem4_din[4]), .DI5(mem4_din[5]), .DI6(mem4_din[6]), .DI7(mem4_din[7]), 
	.DI8(mem4_din[8]), .DI9(mem4_din[9]), .DI10(mem4_din[10]), .DI11(mem4_din[11]), .DI12(mem4_din[12]), .DI13(mem4_din[13]), .DI14(mem4_din[14]), .DI15(mem4_din[15]),
	.CK(clk), .WEB(mem4_web), .OE(1'b1), .CS(1'b1)
);

SUMA180_2048X16X1BM1 MEM5(
	.A0(mem5_addr[0]), .A1(mem5_addr[1]), .A2(mem5_addr[2]), .A3(mem5_addr[3]), .A4(mem5_addr[4]), .A5(mem5_addr[5]), .A6(mem5_addr[6]), .A7(mem5_addr[7]), 
	.A8(mem5_addr[8]), .A9(mem5_addr[9]), .A10(mem5_addr[10]),
	.DO0(mem5_dout[0]), .DO1(mem5_dout[1]), .DO2(mem5_dout[2]), .DO3(mem5_dout[3]), .DO4(mem5_dout[4]), .DO5(mem5_dout[5]), .DO6(mem5_dout[6]), .DO7(mem5_dout[7]), 
	.DO8(mem5_dout[8]), .DO9(mem5_dout[9]), .DO10(mem5_dout[10]), .DO11(mem5_dout[11]), .DO12(mem5_dout[12]), .DO13(mem5_dout[13]), .DO14(mem5_dout[14]), .DO15(mem5_dout[15]),
	.DI0(mem5_din[0]), .DI1(mem5_din[1]), .DI2(mem5_din[2]), .DI3(mem5_din[3]), .DI4(mem5_din[4]), .DI5(mem5_din[5]), .DI6(mem5_din[6]), .DI7(mem5_din[7]), 
	.DI8(mem5_din[8]), .DI9(mem5_din[9]), .DI10(mem5_din[10]), .DI11(mem5_din[11]), .DI12(mem5_din[12]), .DI13(mem5_din[13]), .DI14(mem5_din[14]), .DI15(mem5_din[15]),
	.CK(clk), .WEB(mem5_web), .OE(1'b1), .CS(1'b1)
);

SUMA180_1024X32X1BM2 MEM6(
	.A0(mem6_addr[0]), .A1(mem6_addr[1]), .A2(mem6_addr[2]), .A3(mem6_addr[3]), .A4(mem6_addr[4]), .A5(mem6_addr[5]), .A6(mem6_addr[6]), .A7(mem6_addr[7]), 
	.A8(mem6_addr[8]), .A9(mem6_addr[9]),
	.DO0(mem6_dout[0]), .DO1(mem6_dout[1]), .DO2(mem6_dout[2]), .DO3(mem6_dout[3]), .DO4(mem6_dout[4]), .DO5(mem6_dout[5]), .DO6(mem6_dout[6]), .DO7(mem6_dout[7]), 
	.DO8(mem6_dout[8]), .DO9(mem6_dout[9]), .DO10(mem6_dout[10]), .DO11(mem6_dout[11]), .DO12(mem6_dout[12]), .DO13(mem6_dout[13]), .DO14(mem6_dout[14]), .DO15(mem6_dout[15]), 
	.DO16(mem6_dout[16]), .DO17(mem6_dout[17]), .DO18(mem6_dout[18]), .DO19(mem6_dout[19]), .DO20(mem6_dout[20]), .DO21(mem6_dout[21]), .DO22(mem6_dout[22]), .DO23(mem6_dout[23]), 
	.DO24(mem6_dout[24]), .DO25(mem6_dout[25]), .DO26(mem6_dout[26]), .DO27(mem6_dout[27]), .DO28(mem6_dout[28]), .DO29(mem6_dout[29]), .DO30(mem6_dout[30]), .DO31(mem6_dout[31]),
	.DI0(mem6_din[0]), .DI1(mem6_din[1]), .DI2(mem6_din[2]), .DI3(mem6_din[3]), .DI4(mem6_din[4]), .DI5(mem6_din[5]), .DI6(mem6_din[6]), .DI7(mem6_din[7]), 
	.DI8(mem6_din[8]), .DI9(mem6_din[9]), .DI10(mem6_din[10]), .DI11(mem6_din[11]), .DI12(mem6_din[12]), .DI13(mem6_din[13]), .DI14(mem6_din[14]), .DI15(mem6_din[15]), 
	.DI16(mem6_din[16]), .DI17(mem6_din[17]), .DI18(mem6_din[18]), .DI19(mem6_din[19]), .DI20(mem6_din[20]), .DI21(mem6_din[21]), .DI22(mem6_din[22]), .DI23(mem6_din[23]), 
	.DI24(mem6_din[24]), .DI25(mem6_din[25]), .DI26(mem6_din[26]), .DI27(mem6_din[27]), .DI28(mem6_din[28]), .DI29(mem6_din[29]), .DI30(mem6_din[30]), .DI31(mem6_din[31]),
	.CK(clk), .WEB(mem6_web), .OE(1'b1), .CS(1'b1)
);

SUMA180_1024X32X1BM2 MEM7(
	.A0(mem7_addr[0]), .A1(mem7_addr[1]), .A2(mem7_addr[2]), .A3(mem7_addr[3]), .A4(mem7_addr[4]), .A5(mem7_addr[5]), .A6(mem7_addr[6]), .A7(mem7_addr[7]), 
	.A8(mem7_addr[8]), .A9(mem7_addr[9]),
	.DO0(mem7_dout[0]), .DO1(mem7_dout[1]), .DO2(mem7_dout[2]), .DO3(mem7_dout[3]), .DO4(mem7_dout[4]), .DO5(mem7_dout[5]), .DO6(mem7_dout[6]), .DO7(mem7_dout[7]), 
	.DO8(mem7_dout[8]), .DO9(mem7_dout[9]), .DO10(mem7_dout[10]), .DO11(mem7_dout[11]), .DO12(mem7_dout[12]), .DO13(mem7_dout[13]), .DO14(mem7_dout[14]), .DO15(mem7_dout[15]), 
	.DO16(mem7_dout[16]), .DO17(mem7_dout[17]), .DO18(mem7_dout[18]), .DO19(mem7_dout[19]), .DO20(mem7_dout[20]), .DO21(mem7_dout[21]), .DO22(mem7_dout[22]), .DO23(mem7_dout[23]), 
	.DO24(mem7_dout[24]), .DO25(mem7_dout[25]), .DO26(mem7_dout[26]), .DO27(mem7_dout[27]), .DO28(mem7_dout[28]), .DO29(mem7_dout[29]), .DO30(mem7_dout[30]), .DO31(mem7_dout[31]),
	.DI0(mem7_din[0]), .DI1(mem7_din[1]), .DI2(mem7_din[2]), .DI3(mem7_din[3]), .DI4(mem7_din[4]), .DI5(mem7_din[5]), .DI6(mem7_din[6]), .DI7(mem7_din[7]), 
	.DI8(mem7_din[8]), .DI9(mem7_din[9]), .DI10(mem7_din[10]), .DI11(mem7_din[11]), .DI12(mem7_din[12]), .DI13(mem7_din[13]), .DI14(mem7_din[14]), .DI15(mem7_din[15]), 
	.DI16(mem7_din[16]), .DI17(mem7_din[17]), .DI18(mem7_din[18]), .DI19(mem7_din[19]), .DI20(mem7_din[20]), .DI21(mem7_din[21]), .DI22(mem7_din[22]), .DI23(mem7_din[23]), 
	.DI24(mem7_din[24]), .DI25(mem7_din[25]), .DI26(mem7_din[26]), .DI27(mem7_din[27]), .DI28(mem7_din[28]), .DI29(mem7_din[29]), .DI30(mem7_din[30]), .DI31(mem7_din[31]),
	.CK(clk), .WEB(mem7_web), .OE(1'b1), .CS(1'b1)
);

endmodule
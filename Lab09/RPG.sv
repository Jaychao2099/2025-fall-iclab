//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//    (C) Copyright System Integration and Silicon Implementation Laboratory
//    All Right Reserved
//		Date		: 2025/10
//		Version		: v1.0
//   	File Name   : RPG.sv
//   	Module Name : RPG
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################
module RPG(input clk, INF.RPG_inf inf);
import usertype::*;
//==============================================//
//              logic declaration               //
// ============================================ //

// input
// sel_action_valid    1  pattern  High when input means select the action. 
// type_valid          1  pattern  High when input means type of training. 
// mode_valid          1  pattern  High when input means the mode. 
// date_valid          1  pattern  High when input means today’s date. 
// player_no_valid     1  pattern  High when input means the number of  player. 
// monster_valid       1  pattern  High  when  input  means  the  attributes  of  the monster. (Will pull HIGH 3 times for monster’s attack, monster’s defense, and monster’s HP)
// MP_valid            1  pattern  High  when  input  means  the  list  of  the  MP consumed by the skill (Will pull HIGH 4 times for 4 skills) 
// D[143:0]          144  pattern  Represents the contents of the current input. 
//                                     = {141’bX, Action              } (inf.D.d_act [0])       // 3-bit
//                                     = {142’bX, Training_Type       } (inf.D.d_type[0])       // 2-bit
//                                     = {142’bX, Mode                } (inf.D.d_mode[0])       // 2-bit
//                                     = {135’bX, Month[3:0], Day[4:0]} (inf.D.d_date[0])       // 4-bit, 5-bit
//                                     = {136’bX, Player No.          } (inf.D.d_player_no[0])  // 8-bit
//                                     = {128’bX, Moster_attributes   } (inf.D.d_attribute[0])  // 16-bit
//                                     = {128’bX, Comsumed_MP         } (inf.D.d_attribute[0])  // 16-bit
// AR_READY            1  DRAM     AXI Lite signal 
// R_VALID             1  DRAM     AXI Lite signal 
// R_DATA             96  DRAM     AXI Lite signal 
// R_RESP              2  DRAM     AXI Lite signal 
// AW_READY            1  DRAM     AXI Lite signal 
// W_READY             1  DRAM     AXI Lite signal 
// B_VALID             1  DRAM     AXI Lite signal 
// B_RESP              2  DRAM     AXI Lite signal 

// // output
// out_valid           1  pattern  Should set to high when your output is ready. out_valid will be high for only one cycle. 
// warn_msg            3  pattern  warn_msg will be 3’b000 (No warn) if operation is  complete,  else  it  needs  to  be  corresponding value. 
// complete            1  pattern  1’b1: operation complete, 1’b0: some warning occurred 
// AR_VALID            1  DRAM     AXI Lite signal 
// AR_ADDR            17  DRAM     AXI Lite signal 
// R_READY             1  DRAM     AXI Lite signal 
// AW_VALID            1  DRAM     AXI Lite signal 
// AW_ADDR            17  DRAM     AXI Lite signal 
// W_VALID             1  DRAM     AXI Lite signal 
// W_DATA             96  DRAM     AXI Lite signal 
// B_READY             1  DRAM     AXI Lite signal 


logic read_input_done;

// ------------------ handle input ------------------

// Player_Info current_player;

This_run_info now;

// ------------------ handel output ------------------
Warn_Msg warn_date_exp_hp_mp_flag;
logic    warn_sat_flag;

// ------------------ sort ------------------
Attribute elements [0:3];
Attribute sorted_elements [0:3];

//================================================================
// design
//================================================================

state_t current_state, next_state;

// state_t current_state;
always_ff @(posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n) current_state <= S_IDLE;
    else current_state <= next_state;
end

// state_t next_state;
always_comb begin
    case (current_state)
        S_IDLE: begin
            if (inf.sel_action_valid) next_state = S_READ_INPUT;
            else                      next_state = S_IDLE;
        end
        S_READ_INPUT: begin     // store input into 'now'
            if (read_input_done) next_state = S_READ_DRAM;
            else                 next_state = S_READ_INPUT;
        end
        // read 32-bit
        S_READ_DRAM: begin  // TODO: maybe more state?
            if (inf.R_VALID) begin
                case (now.act)
                    Login:            next_state = S_CHECK_CONSECUTIVE;
                    Level_Up: 	      next_state = S_CHECK_EXP_NEED;
                    Battle:           next_state = S_CHECK_HP;
                    Use_Skill:        next_state = S_GET_MP_SUM;
                    Check_Inactive:   next_state = S_CHECK_DATE;
                    // default: next_state = S_IDLE;
                endcase
            end
            else next_state = S_READ_DRAM;
        end
        // calculation
        S_CHECK_CONSECUTIVE: begin
            next_state = S_UPDATE_DATE_EXP;
        end
        S_UPDATE_DATE_EXP: begin
            next_state = S_END_ACTION;
        end
        S_CHECK_EXP_NEED: begin
            if (warn_date_exp_hp_mp_flag == Exp_Warn) next_state = S_END_ACTION;
            else                                      next_state = S_CAL_DALTA;
        end
        S_CAL_DALTA: begin
            next_state = S_UPDATE_ATTR_LEVEL_UP;
        end
        S_UPDATE_ATTR_LEVEL_UP: begin
            next_state = S_END_ACTION;
        end
        S_CHECK_HP: begin
            if (warn_date_exp_hp_mp_flag == HP_Warn) next_state = S_END_ACTION;
            else                                     next_state = S_CAL_HP_TMP;
        end
        S_CAL_HP_TMP: begin
            next_state = S_CHECK_HP_RESULT;
        end
        S_CHECK_HP_RESULT: begin
            next_state = S_UPDATE_ATTR_BATTLE;
        end
        S_UPDATE_ATTR_BATTLE: begin
            next_state = S_END_ACTION;
        end
        S_GET_MP_SUM: begin
            if (warn_date_exp_hp_mp_flag == MP_Warn) next_state = S_END_ACTION;
            else                                     next_state = S_UPDATE_MP;
        end
        S_UPDATE_MP: begin
            next_state = S_END_ACTION;
        end
        S_CHECK_DATE: begin
            next_state = S_END_ACTION;
        end
        S_END_ACTION: begin
            next_state = S_WRITE_DRAM;
        end
        // write 32-bit
        S_WRITE_DRAM: begin  // TODO: maybe more state?
            if (inf.W_READY) next_state = S_IDLE;
            else             next_state = S_WRITE_DRAM;
        end
    endcase
end

// Player_Info current_player;
// always_ff @( posedge clk ) begin
//     if (current_state == S_READ_DRAM) current_player <= inf.D;
//     else current_player <= current_player;
// end

// This_run_info now;
always_ff @( posedge clk ) begin
    case (current_state)
        S_IDLE: begin
            if (inf.sel_action_valid) now.act <= inf.D.d_act;
        end
        S_READ_INPUT: begin
            
        end
        default: 
    endcase
end

// DRAM: 0x10000 ~ 0x10BFF.
// each player: 96 bits = 12 Bytes
// number "ID" player address = 0x10000 | (ID * 12 == (ID << 3) + (ID << 2))







// Attribute elements [0:3];
// Attribute sorted_elements [0:3];
// for level-up training-type B, use skill greedy select MP
SORT s1 (.elements(elements), .sorted_elements(sorted_elements));




// warn_msg warn_date_exp_hp_mp_flag
// logic warn_sat;
// inf.warn_msg
always_ff @( posedge clk or negedge inf.rst_n ) begin
    if (!inf.rst_n) inf.warn_msg <= No_Warn;
    else if (current_state == S_END_ACTION) begin
        if      (warn_date_exp_hp_mp_flag != No_Warn) inf.warn_msg <= warn_date_exp_hp_mp_flag;
        else if (warn_sat_flag)                       inf.warn_msg <= Saturation_Warn;
    end
    else inf.warn_msg <= No_Warn;
end

always_ff @( posedge clk or negedge inf.rst_n ) begin
    if (!inf.rst_n) begin
        inf.out_valid <= 0;
        inf.complete <= 0;
        inf.AR_VALID <= 0;
        inf.AR_ADDR <= 0;
        inf.R_READY <= 0;
        inf.AW_VALID <= 0;
        inf.AW_ADDR <= 0;
        inf.W_VALID <= 0;
        inf.W_DATA <= 0;
        inf.B_READY <= 0;
    end
end

endmodule

module SORT (
    elements,
    sorted_elements
);
import usertype::*;

input  Attribute elements [0:3];
output Attribute sorted_elements [0:3];

// [(0,2),(1,3)]
// [(0,1),(2,3)]
// [(1,2)]
sorting_element layer0 [0:3];
sorting_element layer1 [0:3];

sorting_element inputs [0:3];
always_comb begin
    inputs[0] = {elements[0], 2'd0};    // MP
    inputs[1] = {elements[1], 2'd1};    // HP
    inputs[2] = {elements[2], 2'd2};    // Attack
    inputs[3] = {elements[3], 2'd3};    // Defense
end

always_comb begin
    // Layer 0: [(0,2),(1,3)]
    // (0,2)
    if (inputs[0] > inputs[2]) begin
        layer0[0] = inputs[2];
        layer0[2] = inputs[0];
    end
    else begin
        layer0[0] = inputs[0];
        layer0[2] = inputs[2];
    end
    // (1,3)
    if (inputs[1] > inputs[3]) begin
        layer0[1] = inputs[3];
        layer0[3] = inputs[1];
    end
    else begin
        layer0[1] = inputs[1];
        layer0[3] = inputs[3];
    end

    // Layer 1: [(0,1),(2,3)]
    // (0,1)
    if (layer0[0] > layer0[1]) begin
        layer1[0] = layer0[1];
        layer1[1] = layer0[0];
    end
    else begin
        layer1[0] = layer0[0];
        layer1[1] = layer0[1];
    end
    // (2,3)
    if (layer0[2] > layer0[3]) begin
        layer1[2] = layer0[3];
        layer1[3] = layer0[2];
    end
    else begin
        layer1[2] = layer0[2];
        layer1[3] = layer0[3];
    end

    // Layer 2: [(1,2)]
    // (0)
    sorted_elements[0] = layer1[0].element;
    // (1,2)
    if (layer1[1] > layer1[2]) begin
        sorted_elements[1] = layer1[2].element;
        sorted_elements[2] = layer1[1].element;
    end
    else begin
        sorted_elements[1] = layer1[1].element;
        sorted_elements[2] = layer1[2].element;
    end
    // (3)
    sorted_elements[3] = layer1[3].element;
end

endmodule
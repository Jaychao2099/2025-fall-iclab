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

// Finished: 
//      FSM
//      sorting module
//      input
//      level up
//      battle
//      use skill
//      check inactive

// TODO:
//      read DRAM


//==============================================//
//              logic declaration               //
// ============================================ //

// ------------------ FSM ------------------
state_t current_state, next_state;

// ------------------ handle input ------------------
current_valid_t valid_vector;
This_run_info_t now;
logic [1:0] monster_cnt;
logic [2:0] mp_cnt;
logic read_input_done;

// ------------------ AXI ------------------

// ------------------ update player ------------------
logic signed [18:0] Exp_tmp, MP_tmp, HP_tmp, Attack_tmp, Defense_tmp;

logic Exp_tmp_sat, MP_tmp_sat, HP_tmp_sat, Attack_tmp_sat, Defense_tmp_sat;

// ------------------ Login ------------------
logic [8:0] today_days_cnt, last_days_cnt;

// ------------------ Level up ------------------
Attribute delta_MP, delta_HP, delta_Attack, delta_Defense;

// ------------------ Battle ------------------
logic [16:0] d_to_p, p_to_d;
logic signed [16:0] m_HP_tmp;
battle_result_t battle_result;

logic Exp_tmp_sat_sub, Attack_tmp_sat_sub, Defense_tmp_sat_sub;

// ------------------ Use skills ------------------
logic [15:0] skill_sum_00;
logic [16:0] skill_sum_01;
logic [17:0] skill_sum_02;
logic [17:0] skill_sum_03;

// ------------------ Check inactive ------------------
// logic [8:0] today_days_cnt, last_days_cnt;

// ------------------ Sort IP ------------------
Attribute attributes [0:3];
// Attribute sorted_attributes [0:3];
sorting_element_t sorted_attributes [0:3];

// ------------------ handel output ------------------
Warn_Msg warn_date_exp_hp_mp_flag;
logic    warn_sat_flag;

//================================================================
// design
//================================================================

// ------------------ FSM ------------------

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
                    default: next_state = S_IDLE;   // no used
                endcase
            end
            else next_state = S_READ_DRAM;
        end
        // login
        S_CHECK_CONSECUTIVE: begin
            next_state = S_UPDATE_DATE_EXP;
        end
        S_UPDATE_DATE_EXP: begin
            next_state = S_END_ACTION;
        end
        // level up
        S_CHECK_EXP_NEED: begin
            if (warn_date_exp_hp_mp_flag == Exp_Warn) next_state = S_END_ACTION;
            else                                      next_state = S_CAL_DALTA;
        end
        S_CAL_DALTA: begin
            next_state = S_CAL_DALTA_FINAL;
        end
        S_CAL_DALTA_FINAL: begin
            next_state = S_UPDATE_ATTR_LEVEL_UP;
        end
        S_UPDATE_ATTR_LEVEL_UP: begin
            next_state = S_END_ACTION;
        end
        // attack
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
        // use skill
        S_GET_MP_SUM: begin
            if (warn_date_exp_hp_mp_flag == MP_Warn) next_state = S_END_ACTION;
            else                                     next_state = S_UPDATE_MP;
        end
        S_UPDATE_MP: begin
            next_state = S_END_ACTION;
        end
        // check inactive
        S_CHECK_DATE: begin
            next_state = S_END_ACTION;
        end
        // raise signal
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

// ------------------ handle input ------------------

// current_valid_t valid_vector;
assign valid_vector = {inf.type_valid, 
                       inf.mode_valid, 
                       inf.date_valid, 
                       inf.player_no_valid, 
                       inf.monster_valid, 
                       inf.MP_valid };

// This_run_info_t now;
always_ff @( posedge clk ) begin
    case (current_state)
        S_IDLE: begin
            if (inf.sel_action_valid) now.act <= inf.D.d_act;
        end
        S_READ_INPUT: begin
            case (valid_vector)
                type_valid      : now.training_type <= inf.D.d_type;
                mode_valid      : now.mode          <= inf.D.d_mode;
                date_valid      : now.today         <= inf.D.d_date;
                player_no_valid : now.player        <= inf.D.d_player_no;
                monster_valid   : begin
                    case (monster_cnt)
                        0: now.m_attack  <= inf.D.d_attribute;
                        1: now.m_defense <= inf.D.d_attribute;
                        2: now.m_HP      <= inf.D.d_attribute;
                    endcase
                end
                MP_valid        : begin
                    case (mp_cnt)
                        0: now.MP_consumed[0] <= inf.D.d_attribute;
                        1: now.MP_consumed[1] <= inf.D.d_attribute;
                        2: now.MP_consumed[2] <= inf.D.d_attribute;
                        3: now.MP_consumed[3] <= inf.D.d_attribute;
                    endcase
                end
            endcase
        end
    endcase
end

// logic [1:0] monster_cnt;    // 0 ~ 2, 3
always_ff @( posedge clk ) begin
    case (current_state)
        S_IDLE:       monster_cnt <= 2'd0;
        S_READ_INPUT: monster_cnt <= (inf.monster_valid) ? monster_cnt + 2'd1 : monster_cnt;
    endcase
end

// logic [2:0] mp_cnt;    // 0 ~ 3, 4
always_ff @( posedge clk ) begin
    case (current_state)
        S_IDLE:       mp_cnt <= 2'd0;
        S_READ_INPUT: mp_cnt <= (inf.MP_valid) ? mp_cnt + 2'd1 : mp_cnt;
    endcase
end

// logic read_input_done;
always_comb begin
    read_input_done = 1'b0;
    case (now.act)
        Login, 
        Level_Up, 
        Check_Inactive: if (inf.player_no_valid) read_input_done = 1'b1;
        Battle:         if (monster_cnt == 3)    read_input_done = 1'b1;
        Use_Skill:      if (mp_cnt == 4)         read_input_done = 1'b1;
    endcase
end

// ------------------ AXI ------------------
// TODO:
// DRAM: 0x10000 ~ 0x10BFF.
// each player: 96 bits = 12 Bytes
// number "ID" player address = 0x10000 | (ID * 12 == (ID << 3) + (ID << 2))

Player_Info current_player_info;        // for calculation, need to write back DRAM


always_ff @( posedge clk or negedge inf.rst_n ) begin
    if (!inf.rst_n) begin
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

// ------------------ update player ------------------

// logic signed [18:0] Exp_tmp, MP_tmp, HP_tmp, Attack_tmp, Defense_tmp;
always_ff @( posedge clk ) begin
    case (current_state)
        S_CHECK_CONSECUTIVE: begin
            if (today_days_cnt == last_days_cnt + 1 ||
                today_days_cnt == 1 && last_days_cnt == 365) begin
                Exp_tmp <= current_player_info.Exp + 18'd512;
                MP_tmp  <= current_player_info.MP  + 18'd2048;
            end
            else begin
                Exp_tmp <= current_player_info.Exp;
                MP_tmp  <= current_player_info.MP;
            end
        end
        S_CAL_DALTA_FINAL: begin
            case (now.mode)
                Easy: begin
                    MP_tmp      <= current_player_info.MP      + (delta_MP      - (delta_MP >> 2));
                    HP_tmp      <= current_player_info.HP      + (delta_HP      - (delta_HP >> 2));
                    Attack_tmp  <= current_player_info.Attack  + (delta_Attack  - (delta_Attack >> 2));
                    Defense_tmp <= current_player_info.Defense + (delta_Defense - (delta_Defense >> 2));
                end
                Normal: begin
                    MP_tmp      <= current_player_info.MP      + delta_MP;
                    HP_tmp      <= current_player_info.HP      + delta_HP;
                    Attack_tmp  <= current_player_info.Attack  + delta_Attack;
                    Defense_tmp <= current_player_info.Defense + delta_Defense;
                end
                Hard: begin
                    MP_tmp      <= current_player_info.MP      + (delta_MP      + (delta_MP >> 2));
                    HP_tmp      <= current_player_info.HP      + (delta_HP      + (delta_HP >> 2));
                    Attack_tmp  <= current_player_info.Attack  + (delta_Attack  + (delta_Attack >> 2));
                    Defense_tmp <= current_player_info.Defense + (delta_Defense + (delta_Defense >> 2));
                end
            endcase
        end
        S_CAL_HP_TMP: begin
            HP_tmp <= d_to_p[16] ? current_player_info.HP : current_player_info.HP - d_to_p;    // TODO: can optimize?
        end
        S_CHECK_HP_RESULT: begin
            case (battle_result)
                win: begin
                    Exp_tmp <= current_player_info.Exp + 17'd2048;
                    MP_tmp  <= current_player_info.MP + 17'd2048;
                    // HP_tmp  <= HP_tmp;
                end
                loss: begin
                    Exp_tmp     <= current_player_info.Exp     - 17'd2048;
                    HP_tmp      <= 17'd0;
                    Attack_tmp  <= current_player_info.Attack  - 17'd2048;
                    Defense_tmp <= current_player_info.Defense - 17'd2048;
                end
                // default: begin
                //     HP_tmp  <= HP_tmp;
                // end
            endcase
        end
        S_GET_MP_SUM: begin
            if      (skill_sum_03 <= current_player_info.MP) MP_tmp <= current_player_info.MP - skill_sum_03;
            else if (skill_sum_02 <= current_player_info.MP) MP_tmp <= current_player_info.MP - skill_sum_02;
            else if (skill_sum_01 <= current_player_info.MP) MP_tmp <= current_player_info.MP - skill_sum_01;
            else if (skill_sum_00 <= current_player_info.MP) MP_tmp <= current_player_info.MP - skill_sum_00;
        end
    endcase
end

// > 65535
// logic Exp_tmp_sat, MP_tmp_sat, HP_tmp_sat, Attack_tmp_sat, Defense_tmp_sat;
assign Exp_tmp_sat      = Exp_tmp[16];//(Exp_tmp > 18'd65535);
assign MP_tmp_sat       = MP_tmp[16];//(MP_tmp > 18'd65535);
assign HP_tmp_sat       = HP_tmp[16];
assign Attack_tmp_sat   = Attack_tmp[16];
assign Defense_tmp_sat  = Defense_tmp[16];

// < 0
// logic Exp_tmp_sat_sub, Attack_tmp_sat_sub, Defense_tmp_sat_sub;
assign Exp_tmp_sat_sub     = Exp_tmp[17];
assign Attack_tmp_sat_sub  = Attack_tmp[17];
assign Defense_tmp_sat_sub = Defense_tmp[17];

always_ff @( posedge clk ) begin
    case (current_state)
        S_UPDATE_DATE_EXP: begin
            current_player_info.Exp <= Exp_tmp_sat ? 16'd65535 : Exp_tmp;
            current_player_info.MP  <= MP_tmp_sat  ? 16'd65535 : MP_tmp;
        end
        S_UPDATE_ATTR_LEVEL_UP: begin
            current_player_info.MP      <= MP_tmp_sat      ? 16'd65535 : MP_tmp;
            current_player_info.HP      <= HP_tmp_sat      ? 16'd65535 : HP_tmp;
            current_player_info.Attack  <= Attack_tmp_sat  ? 16'd65535 : Attack_tmp;
            current_player_info.Defense <= Defense_tmp_sat ? 16'd65535 : Defense_tmp;
        end
        S_UPDATE_ATTR_BATTLE: begin
            current_player_info.Exp     <= Exp_tmp_sat_sub     ? 16'd0 : Exp_tmp_sat     ? 16'd65535 : Exp_tmp;
            current_player_info.MP      <=                               MP_tmp_sat      ? 16'd65535 : MP_tmp;
            current_player_info.HP      <=                               /*HP_tmp_sat      ? 16'd65535 :*/ HP_tmp;
            current_player_info.Attack  <= Attack_tmp_sat_sub  ? 16'd0 : /*Attack_tmp_sat  ? 16'd65535 :*/ Attack_tmp;
            current_player_info.Defense <= Defense_tmp_sat_sub ? 16'd0 : /*Defense_tmp_sat ? 16'd65535 :*/ Defense_tmp;
        end
        S_UPDATE_MP: begin
            current_player_info.MP <= MP_tmp;
        end
    endcase
end

// ------------------ Login ------------------

// (now.today) vs. (current_player_info.M, .D)

// 1~365
function logic [8:0] count_days(Month m, Day d);
    logic [8:0] days;
    days = d;
    case (m)
        1: days = d;
        2: days = d + 31;
        3: days = d + 59;
        4: days = d + 90;
        5: days = d + 120;
        6: days = d + 151;
        7: days = d + 181;
        8: days = d + 212;
        9: days = d + 243;
        10: days = d + 273;
        11: days = d + 304;
        default: days = d + 334;
    endcase
    return days;
endfunction

// This_run_info_t now;
// logic [8:0] today_days_cnt
always_comb begin
    today_days_cnt = count_days(now.today.M, now.today.D);
end

// Player_Info current_player_info;        // for calculation, need to write back DRAM
// logic [8:0] last_days_cnt
always_comb begin
    last_days_cnt = count_days(current_player_info.M, current_player_info.D);
end

// ------------------ Level up ------------------

logic [17:0] attribute_sum = current_player_info.MP +
                             current_player_info.HP +
                             current_player_info.Attack +
                             current_player_info.Defense;

logic [11:0] delta_MP_tmp      = (16'd65535 - current_player_info.MP) >> 4;
logic [11:0] delta_HP_tmp      = (16'd65535 - current_player_info.HP) >> 4;
logic [11:0] delta_Attack_tmp  = (16'd65535 - current_player_info.Attack) >> 4;
logic [11:0] delta_Defense_tmp = (16'd65535 - current_player_info.Defense) >> 4;

Attribute_rank_t rank_MP = {(sorted_attributes_reg[3].stable_idx == 2'd0), 
                            (sorted_attributes_reg[2].stable_idx == 2'd0), 
                            (sorted_attributes_reg[1].stable_idx == 2'd0), 
                            (sorted_attributes_reg[0].stable_idx == 2'd0)};

Attribute_rank_t rank_HP = {(sorted_attributes_reg[3].stable_idx == 2'd1), 
                            (sorted_attributes_reg[2].stable_idx == 2'd1), 
                            (sorted_attributes_reg[1].stable_idx == 2'd1), 
                            (sorted_attributes_reg[0].stable_idx == 2'd1)};

Attribute_rank_t rank_Attack = {(sorted_attributes_reg[3].stable_idx == 2'd2), 
                                (sorted_attributes_reg[2].stable_idx == 2'd2), 
                                (sorted_attributes_reg[1].stable_idx == 2'd2), 
                                (sorted_attributes_reg[0].stable_idx == 2'd2)};

Attribute_rank_t rank_Defense = {(sorted_attributes_reg[3].stable_idx == 2'd3), 
                                 (sorted_attributes_reg[2].stable_idx == 2'd3), 
                                 (sorted_attributes_reg[1].stable_idx == 2'd3), 
                                 (sorted_attributes_reg[0].stable_idx == 2'd3)};

// Attribute delta_MP, delta_HP, delta_Attack, delta_Defense;
always_ff @( posedge clk ) begin
    // if (current_state == S_CAL_DALTA) begin
        case (now.training_type)
            Type_A: begin
                delta_MP      <= {1'b0, attribute_sum[17:3]};
                delta_HP      <= {1'b0, attribute_sum[17:3]};
                delta_Attack  <= {1'b0, attribute_sum[17:3]};
                delta_Defense <= {1'b0, attribute_sum[17:3]};
            end
            Type_B: begin
                case (rank_MP)
                    rank_0: delta_MP <= sorted_attributes_reg[2].element - current_player_info.MP;
                    rank_1: delta_MP <= sorted_attributes_reg[3].element - current_player_info.MP;
                    rank_2,
                    rank_3: delta_MP <= current_player_info.MP;
                endcase
                case (rank_HP)
                    rank_0: delta_HP <= sorted_attributes_reg[2].element - current_player_info.HP;
                    rank_1: delta_HP <= sorted_attributes_reg[3].element - current_player_info.HP;
                    rank_2,
                    rank_3: delta_HP <= current_player_info.HP;
                endcase
                case (rank_Attack)
                    rank_0: delta_Attack <= sorted_attributes_reg[2].element - current_player_info.Attack;
                    rank_1: delta_Attack <= sorted_attributes_reg[3].element - current_player_info.Attack;
                    rank_2,
                    rank_3: delta_Attack <= current_player_info.Attack;
                endcase
                case (rank_Defense)
                    rank_0: delta_Defense <= sorted_attributes_reg[2].element - current_player_info.Defense;
                    rank_1: delta_Defense <= sorted_attributes_reg[3].element - current_player_info.Defense;
                    rank_2,
                    rank_3: delta_Defense <= current_player_info.Defense;
                endcase
            end
            Type_C: begin
                delta_MP      <= (16383 > current_player_info.MP)      ? (16'd16383 - current_player_info.MP)      : 0;
                delta_HP      <= (16383 > current_player_info.HP)      ? (16'd16383 - current_player_info.HP)      : 0;
                delta_Attack  <= (16383 > current_player_info.Attack)  ? (16'd16383 - current_player_info.Attack)  : 0;
                delta_Defense <= (16383 > current_player_info.Defense) ? (16'd16383 - current_player_info.Defense) : 0;
            end
            Type_D: begin
                delta_MP      <= (delta_MP_tmp[11])      ? (16'd5047) : (16'd3000 + delta_MP_tmp);
                delta_HP      <= (delta_HP_tmp[11])      ? (16'd5047) : (16'd3000 + delta_HP_tmp);
                delta_Attack  <= (delta_Attack_tmp[11])  ? (16'd5047) : (16'd3000 + delta_Attack_tmp);
                delta_Defense <= (delta_Defense_tmp[11]) ? (16'd5047) : (16'd3000 + delta_Defense_tmp);
            end
        endcase
    // end
end

// ------------------ Battle ------------------

// logic [16:0] d_to_p, p_to_d;
assign d_to_p = now.m_attack - current_player_info.Defense;
assign p_to_d = current_player_info.Attack - now.m_defense;

// logic signed [16:0] m_HP_tmp;
always_ff @( posedge clk ) begin
    // if (current_state == S_CAL_HP_TMP)
        m_HP_tmp <= p_to_d[16] ? now.m_HP : now.m_HP - p_to_d;
end

// battle_result_t battle_result;
// always_ff @( posedge clk ) begin
always_comb begin
    // S_CHECK_HP_RESULT
    if      (HP_tmp > 0 & m_HP_tmp > 0) battle_result = tie;
    else if (HP_tmp <= 0)               battle_result = loss;
    else                                battle_result = win;
end


// ------------------ Use skills ------------------

// logic [15:0] skill_sum_00;
// logic [16:0] skill_sum_01;
// logic [17:0] skill_sum_02;
// logic [17:0] skill_sum_03;
assign skill_sum_00 = sorted_attributes_reg[0].element;

assign skill_sum_01 = sorted_attributes_reg[0].element +
                      sorted_attributes_reg[1].element;

assign skill_sum_02 = sorted_attributes_reg[0].element +
                      sorted_attributes_reg[1].element +
                      sorted_attributes_reg[2].element;

assign skill_sum_03 = now.MP_consumed[0] +
                      now.MP_consumed[1] +
                      now.MP_consumed[2] +
                      now.MP_consumed[3];


// ------------------ Check inactive ------------------

// logic [8:0] today_days_cnt, last_days_cnt;

// ------------------ Sort IP ------------------

// Attribute attributes [0:3];
always_comb begin
    case (now.act)
        Level_Up: begin
            attributes[0] = current_player_info.MP;
            attributes[1] = current_player_info.HP;
            attributes[2] = current_player_info.Attack;
            attributes[3] = current_player_info.Defense;
        end
        Use_Skill: begin
            attributes[0] = now.MP_consumed[0];
            attributes[1] = now.MP_consumed[1];
            attributes[2] = now.MP_consumed[2];
            attributes[3] = now.MP_consumed[3];
        end
        default: begin
            attributes[0] = 16'd0;
            attributes[1] = 16'd0;
            attributes[2] = 16'd0;
            attributes[3] = 16'd0;
        end
    endcase
end

// sorting_element_t sorted_attributes [0:3];

// for level-up training-type B, use skill greedy select MP
SORT s1 (.attributes(attributes), .sorted_attributes(sorted_attributes));

sorting_element_t sorted_attributes_reg [0:3];

// sorting_element_t sorted_attributes_reg [0:3];
always_ff @( posedge clk ) begin
    // if (current_state == S_CHECK_EXP_NEED || current_state == S_READ_DRAM && now.act == Use_Skill) 
        sorted_attributes_reg <= sorted_attributes;
end

// ------------------ handle output ------------------

// Warn_Msg warn_date_exp_hp_mp_flag;
always_ff @( posedge clk ) begin
    case (current_state)
        S_IDLE: begin
            warn_date_exp_hp_mp_flag <= No_Warn;
        end
        // ------------------ Level up ------------------
        S_CHECK_EXP_NEED: begin
            case (now.mode)
                Easy:    warn_date_exp_hp_mp_flag <= (current_player_info.Exp < 4095)  ? Exp_Warn : No_Warn;
                Normal:  warn_date_exp_hp_mp_flag <= (current_player_info.Exp < 16383) ? Exp_Warn : No_Warn;
                default: warn_date_exp_hp_mp_flag <= (current_player_info.Exp < 32767) ? Exp_Warn : No_Warn;
            endcase
        end
        // ------------------ Battle ------------------
        S_CHECK_HP: begin
            warn_date_exp_hp_mp_flag <= (current_player_info.HP == 0) ? HP_Warn : No_Warn;
        end
        // ------------------ Use skills ------------------
        S_GET_MP_SUM: begin
            warn_date_exp_hp_mp_flag <= (sorted_attributes_reg[0].element > current_player_info.Exp) ? MP_Warn : No_Warn;
        end
        // ------------------ Check inactive ------------------
        S_CHECK_DATE: begin
            if (today_days_cnt       - last_days_cnt > 90 && today_days_cnt >= last_days_cnt ||
                today_days_cnt + 365 - last_days_cnt > 90 && today_days_cnt <  last_days_cnt) begin
                warn_date_exp_hp_mp_flag <= Date_Warn;
            end
        end
    endcase
end

// logic    warn_sat_flag;
always_ff @( posedge clk or negedge rst_n) begin
    if (!rst_n) warn_sat_flag <= 1'b0;
    else begin
        case (current_state)
        S_IDLE: warn_sat_flag <= 1'b0;
        // ------------------ Login ------------------
        S_UPDATE_DATE_EXP: begin
            if (Exp_tmp_sat || MP_tmp_sat) warn_sat_flag <= 1'b1;
        end
        // ------------------ Level up ------------------
        S_UPDATE_ATTR_LEVEL_UP: begin
            if (Exp_tmp_sat || MP_tmp_sat || HP_tmp_sat || Attack_tmp_sat || Defense_tmp_sat) warn_sat_flag <= 1'b1;
        end
        // ------------------ Battle ------------------
        S_UPDATE_ATTR_BATTLE: begin
            if (Exp_tmp_sat_sub || Exp_tmp_sat || MP_tmp_sat || Attack_tmp_sat_sub || Defense_tmp_sat_sub) warn_sat_flag <= 1'b1;
        end
        endcase
    end
end

always_ff @( posedge clk or negedge inf.rst_n ) begin
    if      (!inf.rst_n)                    inf.out_valid <= 1'b0;
    else if (current_state == S_END_ACTION) inf.out_valid <= 1'b1;
    else                                    inf.out_valid <= 1'b0;
end

// Warn_Msg warn_date_exp_hp_mp_flag;
// logic    warn_sat_flag;
// inf.warn_msg
always_ff @( posedge clk or negedge inf.rst_n ) begin
    if      (!inf.rst_n)                              inf.warn_msg <= No_Warn;
    else if (current_state == S_END_ACTION) begin
        if      (warn_date_exp_hp_mp_flag != No_Warn) inf.warn_msg <= warn_date_exp_hp_mp_flag;
        else if (warn_sat_flag)                       inf.warn_msg <= Saturation_Warn;
    end
    else                                              inf.warn_msg <= No_Warn;
end

always_ff @( posedge clk or negedge inf.rst_n ) begin
    if      (!inf.rst_n)                                            inf.complete <= 1'b0;
    else if (current_state == S_END_ACTION && 
             warn_date_exp_hp_mp_flag == No_Warn && !warn_sat_flag) inf.complete <= 1'b1;
    else                                                            inf.complete <= 1'b0;
end

endmodule

module SORT (
    attributes,
    sorted_attributes
);
import usertype::*;

input  Attribute attributes [0:3];
// output Attribute sorted_attributes [0:3];
output sorting_element_t sorted_attributes [0:3];

// [(0,2),(1,3)]
// [(0,1),(2,3)]
// [(1,2)]
sorting_element_t layer0 [0:3];
sorting_element_t layer1 [0:3];

sorting_element_t inputs [0:3];
always_comb begin
    inputs[0] = {attributes[0], 2'd0};    // MP
    inputs[1] = {attributes[1], 2'd1};    // HP
    inputs[2] = {attributes[2], 2'd2};    // Attack
    inputs[3] = {attributes[3], 2'd3};    // Defense
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
    sorted_attributes[0] = layer1[0];
    // (1,2)
    if (layer1[1] > layer1[2]) begin
        sorted_attributes[1] = layer1[2];
        sorted_attributes[2] = layer1[1];
    end
    else begin
        sorted_attributes[1] = layer1[1];
        sorted_attributes[2] = layer1[2];
    end
    // (3)
    sorted_attributes[3] = layer1[3];
end

endmodule
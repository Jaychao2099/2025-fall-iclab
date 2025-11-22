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

// Finished: 
//      FSM
//      sorting module
//      input
//      level up
//      battle
//      use skill
//      check inactive
//      read DRAM
//      write DRAM
//      fix aw_valid, r_valid
//      change FSM, compplete goto the last state, deal with DRAM write delay

// TODO:
//      ensure all tmp get calculated and assigned to player

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
Player_Info current_player_info;        // for calculation, need to write back DRAM

logic [16:0] now_addr;

// ------------------ update player ------------------
logic signed [17:0] Exp_tmp, MP_tmp, HP_tmp, Attack_tmp, Defense_tmp;

logic Exp_tmp_sat, MP_tmp_sat, HP_tmp_sat, Attack_tmp_sat, Defense_tmp_sat;

// ------------------ Login ------------------
logic [8:0] today_days_cnt, last_days_cnt;

// ------------------ Level up ------------------
Attribute delta_MP, delta_HP, delta_Attack, delta_Defense;

logic [17:0] attribute_sum;

logic [11:0] delta_MP_tmp;
logic [11:0] delta_HP_tmp;
logic [11:0] delta_Attack_tmp;
logic [11:0] delta_Defense_tmp;

Attribute_rank_t rank_MP, rank_HP, rank_Attack, rank_Defense;

// ------------------ Battle ------------------
logic signed [16:0] d_to_p, d_to_m;
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
sorting_element_t sorted_attributes [0:3], sorted_attributes_reg [0:3];

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
    next_state = current_state;
    case (current_state)
        S_IDLE: begin
            if (inf.sel_action_valid) next_state = S_READ_INPUT;
            else                      next_state = S_IDLE;
        end
        S_READ_INPUT: begin     // store input into 'now'
            if (read_input_done) next_state = S_READ_DRAM_AR;
            else                 next_state = S_READ_INPUT;
        end
        S_READ_DRAM_AR: begin
            if (inf.AR_VALID && inf.AR_READY) next_state = S_READ_DRAM_R;
            else                              next_state = S_READ_DRAM_AR;
        end
        S_READ_DRAM_R: begin
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
            else next_state = S_READ_DRAM_R;
        end
        // login
        S_CHECK_CONSECUTIVE: begin
            next_state = S_UPDATE_DATE_EXP;
        end
        S_UPDATE_DATE_EXP: begin
            next_state = S_WRITE_DRAM_AW;
        end
        // level up
        S_CHECK_EXP_NEED: begin
            next_state = S_CAL_DALTA;
        end
        S_CAL_DALTA: begin
            if (warn_date_exp_hp_mp_flag == Exp_Warn) next_state = S_END_ACTION;
            else                                      next_state = S_CAL_DALTA_FINAL;
        end
        S_CAL_DALTA_FINAL: begin
            next_state = S_UPDATE_ATTR_LEVEL_UP;
        end
        S_UPDATE_ATTR_LEVEL_UP: begin
            next_state = S_WRITE_DRAM_AW;
        end
        // attack
        S_CHECK_HP: begin
            next_state = S_CAL_HP_TMP;
        end
        S_CAL_HP_TMP: begin
            if (warn_date_exp_hp_mp_flag == HP_Warn) next_state = S_END_ACTION;
            else                                     next_state = S_CHECK_HP_RESULT;
        end
        S_CHECK_HP_RESULT: begin
            next_state = S_UPDATE_ATTR_BATTLE;
        end
        S_UPDATE_ATTR_BATTLE: begin
            next_state = S_WRITE_DRAM_AW;
        end
        // use skill
        S_GET_MP_SUM: begin
            // if ((sorted_attributes_reg[0].element > current_player_info.MP)) next_state = S_END_ACTION;
            // else                                                             next_state = S_UPDATE_MP;
            next_state = S_UPDATE_MP;
        end
        S_UPDATE_MP: begin
            if (warn_date_exp_hp_mp_flag == MP_Warn) next_state = S_END_ACTION;
            else                                     next_state = S_WRITE_DRAM_AW;
        end
        // check inactive
        S_CHECK_DATE: begin
            next_state = S_CHECK_DATE_WARN;
        end
        S_CHECK_DATE_WARN: begin
            if (warn_date_exp_hp_mp_flag == Date_Warn) next_state = S_END_ACTION;
            else                                       next_state = S_WRITE_DRAM_AW;
        end
        // write 32-bit
        S_WRITE_DRAM_AW: begin
            if (inf.AW_VALID && inf.AW_READY) next_state = S_WRITE_DRAM_W;
            else                              next_state = S_WRITE_DRAM_AW;
        end
        S_WRITE_DRAM_W: begin
            if (inf.W_VALID && inf.W_READY) next_state = S_WRITE_DRAM_B;
            else                            next_state = S_WRITE_DRAM_W;
        end
        S_WRITE_DRAM_B: begin
            if (inf.B_VALID && inf.B_READY) next_state = S_END_ACTION;
            else                            next_state = S_WRITE_DRAM_B;
        end
        // raise signal
        S_END_ACTION: begin
            next_state = S_IDLE;
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
always_ff @( posedge clk ) begin
    if (current_state == S_IDLE) read_input_done <= 1'b0;
    else begin
        case (now.act)
            Login, 
            Level_Up, 
            Check_Inactive: if (inf.player_no_valid) read_input_done <= 1'b1;
            Battle:         if (monster_cnt == 3)    read_input_done <= 1'b1;
            Use_Skill:      if (mp_cnt == 4)         read_input_done <= 1'b1;
        endcase
    end
end
// always_ff @( posedge clk ) begin
//     case (now.act)
//         Battle:    if (monster_cnt == 3)    read_input_done = 1'b1;
//         Use_Skill: if (mp_cnt == 4)         read_input_done = 1'b1;
//         default:   if (inf.player_no_valid) read_input_done = 1'b1;
//     endcase
// end

// ------------------ AXI ------------------
// DRAM: 0x10000 ~ 0x10BFF.
// each player: 96 bits = 12 Bytes
// number "ID" player address = 0x10000 | (ID * 12 == (ID << 3) + (ID << 2))

// logic [16:0] now_addr = {5'b10000, ({1'b0, now.player, 1'b0} + {2'b0, now.player}), 2'b0}
// logic [16:0] now_addr;
always_ff @( posedge clk ) begin
    if (current_state == S_READ_INPUT) now_addr <= {5'b10000, ({1'b0, now.player, 1'b0} + {2'b0, now.player}), 2'b0};
end

// ------------------ AXI Read ------------------

always_ff @( posedge clk or negedge inf.rst_n ) begin
    if      (!inf.rst_n)                      inf.AR_VALID <= 1'b0;
    else if (inf.AR_READY)                    inf.AR_VALID <= 1'b0;  // can ignore??
    else if (current_state == S_READ_DRAM_AR) inf.AR_VALID <= 1'b1;
    else                                      inf.AR_VALID <= 1'b0;
end

// logic [16:0] AR_ADDR;
always_ff @( posedge clk or negedge inf.rst_n ) begin
    if      (!inf.rst_n)                      inf.AR_ADDR <= 17'd0;
    // else if (inf.AR_READY)                    inf.AR_ADDR <= 17'd0;  // can ignore??
    else if (current_state == S_READ_DRAM_AR) inf.AR_ADDR <= now_addr;
    else                                      inf.AR_ADDR <= 17'd0;
end

always_ff @( posedge clk or negedge inf.rst_n ) begin
    if      (!inf.rst_n)                     inf.R_READY <= 1'b0;
    else if (inf.R_VALID)                    inf.R_READY <= 1'b0;  // can ignore??
    else if (current_state == S_READ_DRAM_R) inf.R_READY <= 1'b1;
    else                                     inf.R_READY <= 1'b0;
end

// ------------------ AXI Write ------------------

always_ff @( posedge clk or negedge inf.rst_n ) begin
    if      (!inf.rst_n)                       inf.AW_VALID <= 1'b0;
    else if (inf.AW_READY)                     inf.AW_VALID <= 1'b0;
    else if (current_state == S_WRITE_DRAM_AW) inf.AW_VALID <= 1'b1;
    else                                       inf.AW_VALID <= 1'b0;
end

// logic [16:0] AW_ADDR;
always_ff @( posedge clk or negedge inf.rst_n ) begin
    if      (!inf.rst_n)                       inf.AW_ADDR <= 17'd0;
    // else if (inf.AW_READY)                     inf.AW_ADDR <= 17'd0;
    else if (current_state == S_WRITE_DRAM_AW) inf.AW_ADDR <= now_addr;
    else                                       inf.AW_ADDR <= 17'd0;
end

always_ff @( posedge clk or negedge inf.rst_n ) begin
    if      (!inf.rst_n)                      inf.W_VALID <= 1'b0;
    else if (inf.W_READY)                     inf.W_VALID <= 1'b0;
    else if (current_state == S_WRITE_DRAM_W) inf.W_VALID <= 1'b1;
    else                                      inf.W_VALID <= 1'b0;
end

// logic [95:0] W_DATA;
always_ff @( posedge clk or negedge inf.rst_n ) begin
    if (!inf.rst_n) inf.W_DATA <= 96'd0;
    else if (inf.W_READY) inf.W_DATA <= 96'd0;
    else if (current_state == S_WRITE_DRAM_W) begin
        inf.W_DATA <= {current_player_info.HP,
                        4'd0, current_player_info.M,
                        3'd0, current_player_info.D,
                        current_player_info.Attack,
                        current_player_info.Defense,
                        current_player_info.Exp,
                        current_player_info.MP};
    end
    else inf.W_DATA <= 96'd0;
end

// always_ff @( posedge clk or negedge inf.rst_n ) begin
//     if      (!inf.rst_n)                      inf.B_READY <= 1'b0;
//     else if (inf.B_VALID)                     inf.B_READY <= 1'b0;
//     else if (current_state == S_WRITE_DRAM_B) inf.B_READY <= 1'b1;
//     else                                      inf.B_READY <= 1'b0;
// end
assign inf.B_READY = 1'b1;

// ------------------ update player ------------------

Date date_tmp;

// logic signed [17:0] Exp_tmp, MP_tmp, HP_tmp, Attack_tmp, Defense_tmp;
always_ff @( posedge clk ) begin
    case (current_state)
        S_CHECK_CONSECUTIVE: begin
            date_tmp <= now.today;
            if (today_days_cnt == last_days_cnt + 1 ||
                today_days_cnt == 1 && last_days_cnt == 365) begin
                Exp_tmp <= current_player_info.Exp + 18'd512;
                MP_tmp  <= current_player_info.MP  + 18'd1024;
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
                default: begin
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
                    Exp_tmp     <= current_player_info.Exp + 17'd2048;
                    MP_tmp      <= current_player_info.MP  + 17'd2048;
                    Attack_tmp  <= current_player_info.Attack;
                    Defense_tmp <= current_player_info.Defense;
                end
                loss: begin
                    Exp_tmp     <= current_player_info.Exp     - 17'd2048;
                    MP_tmp      <= current_player_info.MP;
                    HP_tmp      <= 17'd0;
                    Attack_tmp  <= current_player_info.Attack  - 17'd2048;
                    Defense_tmp <= current_player_info.Defense - 17'd2048;
                end
                default: begin
                    Exp_tmp     <= current_player_info.Exp;
                    MP_tmp      <= current_player_info.MP;
                    Attack_tmp  <= current_player_info.Attack;
                    Defense_tmp <= current_player_info.Defense;
                end
            endcase
        end
        S_GET_MP_SUM: begin
            if      (skill_sum_03 <= current_player_info.MP) MP_tmp <= current_player_info.MP - skill_sum_03;
            else if (skill_sum_02 <= current_player_info.MP) MP_tmp <= current_player_info.MP - skill_sum_02;
            else if (skill_sum_01 <= current_player_info.MP) MP_tmp <= current_player_info.MP - skill_sum_01;
            else if (skill_sum_00 <= current_player_info.MP) MP_tmp <= current_player_info.MP - skill_sum_00;
            else                                             MP_tmp <= current_player_info.MP;
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
        S_READ_DRAM_R: begin
            if (inf.R_VALID) begin
                current_player_info.MP      <= inf.R_DATA[15:0];
                current_player_info.Exp     <= inf.R_DATA[31:16];
                current_player_info.Defense <= inf.R_DATA[47:32];
                current_player_info.Attack  <= inf.R_DATA[63:48];
                current_player_info.D       <= inf.R_DATA[68:64];   // 5-bit
                current_player_info.M       <= inf.R_DATA[75:72];   // 4-bit
                current_player_info.HP      <= inf.R_DATA[95:80];
            end
        end
        S_UPDATE_DATE_EXP: begin
            current_player_info.M   <= date_tmp.M;
            current_player_info.D   <= date_tmp.D;
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

// logic [17:0] attribute_sum;
assign attribute_sum = current_player_info.MP +
                       current_player_info.HP +
                       current_player_info.Attack +
                       current_player_info.Defense;

// logic [11:0] delta_MP_tmp;
// logic [11:0] delta_HP_tmp;
// logic [11:0] delta_Attack_tmp;
// logic [11:0] delta_Defense_tmp;
always_comb begin
    delta_MP_tmp      = (16'd65535 - current_player_info.MP) >> 4;
    delta_HP_tmp      = (16'd65535 - current_player_info.HP) >> 4;
    delta_Attack_tmp  = (16'd65535 - current_player_info.Attack) >> 4;
    delta_Defense_tmp = (16'd65535 - current_player_info.Defense) >> 4;
end

// Attribute_rank_t rank_MP, rank_HP, rank_Attack, rank_Defense;

assign rank_MP = {(sorted_attributes_reg[3].stable_idx == 2'd0), 
                  (sorted_attributes_reg[2].stable_idx == 2'd0), 
                  (sorted_attributes_reg[1].stable_idx == 2'd0), 
                  (sorted_attributes_reg[0].stable_idx == 2'd0)};

assign rank_HP = {(sorted_attributes_reg[3].stable_idx == 2'd1), 
                  (sorted_attributes_reg[2].stable_idx == 2'd1), 
                  (sorted_attributes_reg[1].stable_idx == 2'd1), 
                  (sorted_attributes_reg[0].stable_idx == 2'd1)};

assign rank_Attack = {(sorted_attributes_reg[3].stable_idx == 2'd2), 
                      (sorted_attributes_reg[2].stable_idx == 2'd2), 
                      (sorted_attributes_reg[1].stable_idx == 2'd2), 
                      (sorted_attributes_reg[0].stable_idx == 2'd2)};

assign rank_Defense = {(sorted_attributes_reg[3].stable_idx == 2'd3), 
                       (sorted_attributes_reg[2].stable_idx == 2'd3), 
                       (sorted_attributes_reg[1].stable_idx == 2'd3), 
                       (sorted_attributes_reg[0].stable_idx == 2'd3)};

// Attribute delta_MP, delta_HP, delta_Attack, delta_Defense;
always_ff @( posedge clk ) begin
    case (now.training_type)
        Type_A: begin
            delta_MP      <= {1'b0, attribute_sum[17:3]};
            delta_HP      <= {1'b0, attribute_sum[17:3]};
            delta_Attack  <= {1'b0, attribute_sum[17:3]};
            delta_Defense <= {1'b0, attribute_sum[17:3]};
        end
        Type_B: begin
            case (rank_MP)
                rank_0:  delta_MP <= sorted_attributes_reg[2].element - current_player_info.MP;
                rank_1:  delta_MP <= sorted_attributes_reg[3].element - current_player_info.MP;
                default: delta_MP <= 16'd0;
            endcase
            case (rank_HP)
                rank_0:  delta_HP <= sorted_attributes_reg[2].element - current_player_info.HP;
                rank_1:  delta_HP <= sorted_attributes_reg[3].element - current_player_info.HP;
                default: delta_HP <= 16'd0;
            endcase
            case (rank_Attack)
                rank_0:  delta_Attack <= sorted_attributes_reg[2].element - current_player_info.Attack;
                rank_1:  delta_Attack <= sorted_attributes_reg[3].element - current_player_info.Attack;
                default: delta_Attack <= 16'd0;
            endcase
            case (rank_Defense)
                rank_0:  delta_Defense <= sorted_attributes_reg[2].element - current_player_info.Defense;
                rank_1:  delta_Defense <= sorted_attributes_reg[3].element - current_player_info.Defense;
                default: delta_Defense <= 16'd0;
            endcase
        end
        Type_C: begin
            delta_MP      <= (16383 > current_player_info.MP)      ? (16'd16383 - current_player_info.MP)      : 0;
            delta_HP      <= (16383 > current_player_info.HP)      ? (16'd16383 - current_player_info.HP)      : 0;
            delta_Attack  <= (16383 > current_player_info.Attack)  ? (16'd16383 - current_player_info.Attack)  : 0;
            delta_Defense <= (16383 > current_player_info.Defense) ? (16'd16383 - current_player_info.Defense) : 0;
        end
        default: begin
            delta_MP      <= (delta_MP_tmp[11])      ? (16'd5047) : (16'd3000 + delta_MP_tmp);
            delta_HP      <= (delta_HP_tmp[11])      ? (16'd5047) : (16'd3000 + delta_HP_tmp);
            delta_Attack  <= (delta_Attack_tmp[11])  ? (16'd5047) : (16'd3000 + delta_Attack_tmp);
            delta_Defense <= (delta_Defense_tmp[11]) ? (16'd5047) : (16'd3000 + delta_Defense_tmp);
        end
    endcase
end

// ------------------ Battle ------------------

// logic signed [16:0] d_to_p, d_to_m;
assign d_to_p = now.m_attack - current_player_info.Defense;
assign d_to_m = current_player_info.Attack - now.m_defense;

// logic signed [16:0] m_HP_tmp;
always_ff @( posedge clk ) begin
    // S_CAL_HP_TMP
    m_HP_tmp <= d_to_m[16] ? now.m_HP : (now.m_HP - d_to_m);
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

// sorting_element_t sorted_attributes_reg [0:3];
always_ff @( posedge clk ) begin
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
                // Easy:    warn_date_exp_hp_mp_flag <= (current_player_info.Exp < 4095)  ? Exp_Warn : No_Warn;
                // Normal:  warn_date_exp_hp_mp_flag <= (current_player_info.Exp < 16383) ? Exp_Warn : No_Warn;
                // default: warn_date_exp_hp_mp_flag <= (current_player_info.Exp < 32767) ? Exp_Warn : No_Warn;
                Easy:    warn_date_exp_hp_mp_flag <= ((|current_player_info.Exp[15:12]) | (&current_player_info.Exp[11:0])) ? No_Warn : Exp_Warn;//0000111111111111
                Normal:  warn_date_exp_hp_mp_flag <= ((|current_player_info.Exp[15:14]) | (&current_player_info.Exp[13:0])) ? No_Warn : Exp_Warn;//0011111111111111
                default: warn_date_exp_hp_mp_flag <= (( current_player_info.Exp[15])    | (&current_player_info.Exp[14:0])) ? No_Warn : Exp_Warn;//0111111111111111
            endcase
        end
        // ------------------ Battle ------------------
        S_CHECK_HP: begin
            warn_date_exp_hp_mp_flag <= (current_player_info.HP == 0) ? HP_Warn : No_Warn;
        end
        // ------------------ Use skills ------------------
        S_GET_MP_SUM: begin
            warn_date_exp_hp_mp_flag <= (sorted_attributes_reg[0].element > current_player_info.MP) ? MP_Warn : No_Warn;
        end
        // ------------------ Check inactive ------------------
        S_CHECK_DATE: begin
            if (today_days_cnt       - last_days_cnt > 90 && today_days_cnt >= last_days_cnt ||
                // today_days_cnt + 365 - last_days_cnt > 90 && today_days_cnt <  last_days_cnt) begin
                today_days_cnt + 275 > last_days_cnt && today_days_cnt <  last_days_cnt) begin
                warn_date_exp_hp_mp_flag <= Date_Warn;
            end
        end
    endcase
end

// logic    warn_sat_flag;
always_ff @( posedge clk or negedge inf.rst_n) begin
    if (!inf.rst_n) warn_sat_flag <= 1'b0;
    else begin
        case (current_state)
        S_IDLE: warn_sat_flag <= 1'b0;
        // ------------------ Login ------------------
        S_UPDATE_DATE_EXP: begin
            if (Exp_tmp_sat || MP_tmp_sat) warn_sat_flag <= 1'b1;
        end
        // ------------------ Level up ------------------
        S_UPDATE_ATTR_LEVEL_UP: begin
            if (MP_tmp_sat || HP_tmp_sat || Attack_tmp_sat || Defense_tmp_sat) warn_sat_flag <= 1'b1;
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
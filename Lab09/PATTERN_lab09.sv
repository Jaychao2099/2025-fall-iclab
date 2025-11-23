// `include "../00_TESTBED/pseudo_DRAM.sv"
`include "Usertype.sv"

program automatic PATTERN(input clk, INF.PATTERN inf);
import usertype::*;
//================================================================
// parameters & integer
//================================================================
parameter DRAM_p_r = "../00_TESTBED/DRAM/dram.dat";
integer i, k;
integer total_latency, latency;
integer pattern_num = 100000;
integer seed = 723749723;

//================================================================
// wire & registers 
//================================================================
// DRAM simulation: 0x10000 ~ 0x10BFF
// Each player uses 12 bytes. Total 256 players.
// Address mapping based on Note 1: {HP, Month, Day, Attack, Defense, Exp, MP}
// Total 96 bits = 12 bytes.
logic [7:0] golden_DRAM [((65536+12*256)-1):(65536+0)];  

// Golden Registers
Player_Info g_player_info;
Player_Info g_player_info_updated;
logic [15:0] g_monster_hp, g_monster_atk, g_monster_def;
logic [15:0] g_skill_costs [0:3];
Warn_Msg g_warn_msg;
logic g_complete;

// Current Operation Info
Action cur_action;
Player_No cur_player_no;
Date cur_date;
Training_Type cur_type;
Mode cur_mode;
// Monster info is stored in g_monster_*

//================================================================
// class random
//================================================================

/**
 * Class representing a random action.
 */
// class random_act;
//     randc Action act_id;
//     constraint range{
//         act_id inside{Login, Level_Up, Battle, Use_Skill, Check_Inactive};
//     }
//     function void set_seed(int seed);
        
//         this.srandom(seed);
//     endfunction
// endclass

class random_act;
    randc Action act_id;
    rand Player_No player_id;
    rand Month mon;
    rand Day d;
    rand Training_Type tr_type;
    rand Mode tr_mode;
    rand logic [15:0] m_hp, m_atk, m_def; // Monster stats
    rand logic [15:0] s_cost [0:3]; // Skill costs

    constraint range {
        act_id inside {Login, Level_Up, Battle, Use_Skill, Check_Inactive};
    }
    
    constraint date_valid {
        mon inside {[1:12]};
        d inside {[1:31]};
        (mon == 2) -> d <= 28;
        (mon inside {4, 6, 9, 11}) -> d <= 30;
    }

    constraint stats_range {
        m_hp inside {[1:65535]}; // Monster HP > 0 usually
        m_atk inside {[0:65535]};
        m_def inside {[0:65535]};
    }

    function void set_seed(int seed);
        this.srandom(seed);
    endfunction
endclass

random_act ra;

//================================================================
// Helper Functions
//================================================================

// Count days from Jan 1st (1-365)
function int count_days(Month m, Day d);
    int days;
    days = d;
    if(m > 1) days += 31;
    if(m > 2) days += 28;
    if(m > 3) days += 31;
    if(m > 4) days += 30;
    if(m > 5) days += 31;
    if(m > 6) days += 30;
    if(m > 7) days += 31;
    if(m > 8) days += 31;
    if(m > 9) days += 30;
    if(m > 10) days += 31;
    if(m > 11) days += 30;
    return days;
endfunction

// Read Player Info from golden_DRAM
function Player_Info get_player_from_dram(Player_No p_no);
    Player_Info p;
    logic [16:0] base_addr;
    base_addr = 17'h10000 + (p_no * 12);
    
    // MSB to LSB: {HP, Month, Day, Attack, Defense, Exp, MP}
    p.MP        = {golden_DRAM[base_addr+1], golden_DRAM[base_addr]};
    p.Exp       = {golden_DRAM[base_addr+3], golden_DRAM[base_addr+2]};
    p.Defense   = {golden_DRAM[base_addr+5], golden_DRAM[base_addr+4]};
    p.Attack    = {golden_DRAM[base_addr+7], golden_DRAM[base_addr+6]};
    p.D         = golden_DRAM[base_addr+8][4:0];
    p.M         = golden_DRAM[base_addr+9][3:0];
    p.HP        = {golden_DRAM[base_addr+11], golden_DRAM[base_addr+10]};
    return p;
endfunction

// Write Player Info to golden_DRAM
function void update_dram(Player_No p_no, Player_Info p);
    logic [16:0] base_addr;
    base_addr = 17'h10000 + (p_no * 12);
    
    {golden_DRAM[base_addr+1], golden_DRAM[base_addr]} = p.MP;
    {golden_DRAM[base_addr+3], golden_DRAM[base_addr+2]} = p.Exp;
    {golden_DRAM[base_addr+5], golden_DRAM[base_addr+4]} = p.Defense;
    {golden_DRAM[base_addr+7], golden_DRAM[base_addr+6]} = p.Attack;
    golden_DRAM[base_addr+8] = {3'b0, p.D};
    golden_DRAM[base_addr+9] = {4'b0, p.M};
    {golden_DRAM[base_addr+11], golden_DRAM[base_addr+10]} = p.HP;
endfunction

// Saturation helper
function logic [15:0] saturate_add(logic [16:0] val);
    if (val > 65535) return 65535;
    else return val[15:0];
endfunction

function logic [15:0] saturate_sub(int val);
    if (val < 0) return 0;
    else if (val > 65535) return 65535; // Should not happen for sub unless wrap
    else return val[15:0];
endfunction

//================================================================
// Main Tasks
//================================================================

task reset_task;
    inf.rst_n = 1;
    inf.sel_action_valid = 0;
    inf.type_valid = 0;
    inf.mode_valid = 0;
    inf.date_valid = 0;
    inf.player_no_valid = 0;
    inf.monster_valid = 0;
    inf.MP_valid = 0;
    inf.D = 'dx;

    total_latency = 0;
    
    #(10)
    inf.rst_n = 0;
    #(100)
    inf.rst_n = 1;
endtask

task input_task;
    int delay;
    
    // Randomize Action
    void'(ra.randomize());
    cur_action = ra.act_id;
    cur_player_no = ra.player_id;
    cur_date.M = ra.mon;
    cur_date.D = ra.d;
    cur_type = ra.tr_type;
    cur_mode = ra.tr_mode;
    g_monster_hp = ra.m_hp;
    g_monster_atk = ra.m_atk;
    g_monster_def = ra.m_def;
    foreach(ra.s_cost[j]) g_skill_costs[j] = ra.s_cost[j];

    // 1. Drive Action
    @(negedge clk);
    inf.sel_action_valid = 1;
    inf.D = {141'd0, cur_action};
    @(negedge clk);
    inf.sel_action_valid = 0;
    inf.D = 'dx;

    delay = $urandom_range(1, 4);
    repeat(delay) @(negedge clk);

    case(cur_action)
        Login: begin
            // Date -> Player
            inf.date_valid = 1;
            inf.D = {135'd0, cur_date.M, cur_date.D};
            @(negedge clk);
            inf.date_valid = 0;
            inf.D = 'dx;
            delay = $urandom_range(1, 4);
            repeat(delay) @(negedge clk);

            inf.player_no_valid = 1;
            inf.D = {136'd0, cur_player_no};
            @(negedge clk);
            inf.player_no_valid = 0;
            inf.D = 'dx;
        end
        Level_Up: begin
            // Type -> Mode -> Player
            inf.type_valid = 1;
            inf.D = {142'd0, cur_type};
            @(negedge clk);
            inf.type_valid = 0;
            inf.D = 'dx;
            delay = $urandom_range(1, 4);
            repeat(delay) @(negedge clk);

            inf.mode_valid = 1;
            inf.D = {142'd0, cur_mode};
            @(negedge clk);
            inf.mode_valid = 0;
            inf.D = 'dx;
            delay = $urandom_range(1, 4);
            repeat(delay) @(negedge clk);

            inf.player_no_valid = 1;
            inf.D = {136'd0, cur_player_no};
            @(negedge clk);
            inf.player_no_valid = 0;
            inf.D = 'dx;
        end
        Battle: begin
            // Player -> Monster(Atk) -> Monster(Def) -> Monster(HP)
            inf.player_no_valid = 1;
            inf.D = {136'd0, cur_player_no};
            @(negedge clk);
            inf.player_no_valid = 0;
            inf.D = 'dx;
            delay = $urandom_range(1, 4);
            repeat(delay) @(negedge clk);

            inf.monster_valid = 1;
            inf.D = {128'd0, g_monster_atk};
            @(negedge clk);
            inf.monster_valid = 0;
            inf.D = 'dx;
            delay = $urandom_range(1, 4);
            repeat(delay) @(negedge clk);

            inf.monster_valid = 1;
            inf.D = {128'd0, g_monster_def};
            @(negedge clk);
            inf.monster_valid = 0;
            inf.D = 'dx;
            delay = $urandom_range(1, 4);
            repeat(delay) @(negedge clk);

            inf.monster_valid = 1;
            inf.D = {128'd0, g_monster_hp};
            @(negedge clk);
            inf.monster_valid = 0;
            inf.D = 'dx;
        end
        Use_Skill: begin
            // Player -> MP list (4 times)
            inf.player_no_valid = 1;
            inf.D = {136'd0, cur_player_no};
            @(negedge clk);
            inf.player_no_valid = 0;
            inf.D = 'dx;
            delay = $urandom_range(1, 4);
            repeat(delay) @(negedge clk);

            for(k=0; k<4; k++) begin
                inf.MP_valid = 1;
                inf.D = {128'd0, g_skill_costs[k]};
                @(negedge clk);
                inf.MP_valid = 0;
                inf.D = 'dx;
                if (k < 3) begin
                    delay = $urandom_range(1, 4);
                    repeat(delay) @(negedge clk);
                end
            end
        end
        Check_Inactive: begin
            // Date -> Player
            inf.date_valid = 1;
            inf.D = {135'd0, cur_date.M, cur_date.D};
            @(negedge clk);
            inf.date_valid = 0;
            inf.D = 'dx;
            delay = $urandom_range(1, 4);
            repeat(delay) @(negedge clk);

            inf.player_no_valid = 1;
            inf.D = {136'd0, cur_player_no};
            @(negedge clk);
            inf.player_no_valid = 0;
            inf.D = 'dx;
        end
    endcase
endtask

task calculate_golden;
    Player_Info p;
    int days_curr, days_last, diff;
    bit consecutive;
    int temp_calc;
    int exp_needed;
    
    // Vars for Level Up
    int sum_attrs;
    int sorted_attr [0:3];
    int delta_vals [0:3]; // corresponding to MP, HP, Atk, Def
    int temp_swap;
    // Mapping for sorting: 0:MP, 1:HP, 2:Atk, 3:Def
    int idx_map [0:3];
    int sorted_indices [0:3];
    int m, n;
    int delta_i, delta_final;
    
    // Vars for Battle
    int dmg_to_p, dmg_to_m;
    int hp_temp_p, hp_temp_m;
    
    // Vars for Use Skill
    int current_mp_local;
    int skill_count;
    
    p = get_player_from_dram(cur_player_no);
    g_player_info = p;
    g_player_info_updated = p; // Default no change
    g_warn_msg = No_Warn;
    g_complete = 1;

    case(cur_action)
        Login: begin
            // Update Login Date
            g_player_info_updated.M = cur_date.M;
            g_player_info_updated.D = cur_date.D;
            
            // Check consecutive
            days_curr = count_days(cur_date.M, cur_date.D);
            days_last = count_days(p.M, p.D);
            
            consecutive = 0;
            if (days_curr == days_last + 1) consecutive = 1;
            else if (days_last == 365 && days_curr == 1) consecutive = 1;
            
            if (consecutive) begin
                // Increase Exp by 512, MP by 1024
                temp_calc = p.Exp + 512;
                g_player_info_updated.Exp = saturate_add(temp_calc);
                if (temp_calc > 65535) g_warn_msg = Saturation_Warn;
                
                temp_calc = p.MP + 1024;
                g_player_info_updated.MP = saturate_add(temp_calc);
                if (temp_calc > 65535) g_warn_msg = Saturation_Warn; // Highest priority will be handled later? 
                // Spec Note: "output the one with the highest priority". Saturation(101) is lowest priority (highest value).
                // Actually table 7: No_Warn(0), Saturation(5). Smaller number = Higher priority.
                // Wait, Note says "Smaller, the higher". No_Warn is 0.
                // Warnings: 3'b001 to 3'b101.
                // Saturation (5) is Lowest priority.
            end
        end
        
        Level_Up: begin
            case(cur_mode)
                Easy: exp_needed = 4095;
                Normal: exp_needed = 16383;
                Hard: exp_needed = 32767;
                default: exp_needed = 0;
            endcase
            
            if (p.Exp < exp_needed) begin
                g_warn_msg = Exp_Warn;
                g_complete = 0;
            end else begin
                // Calculate Delta
                case(cur_type)
                    // Type_A: begin
                    //     sum_attrs = p.MP + p.HP + p.Attack + p.Defense;
                    //     delta_i = sum_attrs / 8; // int div
                        
                    //     // Apply to all? "adjust Delta_i... to get final...". 
                    //     // Assuming Formula A applies uniform delta base.
                    //     // Then adjust per mode.
                    //     // Table 2: Delta_final = Delta_i (+/-) floor(Delta_i/4).
                    // end
                    Type_B: begin
                        // Sort MP, HP, Atk, Def
                        // Store values and original indices
                        sorted_attr[0] = p.MP; sorted_indices[0] = 0;
                        sorted_attr[1] = p.HP; sorted_indices[1] = 1;
                        sorted_attr[2] = p.Attack; sorted_indices[2] = 2;
                        sorted_attr[3] = p.Defense; sorted_indices[3] = 3;
                        
                        // Simple Bubble Sort (Ascending)
                        // stable sort
                        for(m=0; m<4; m++) begin
                            for(n=0; n<3-m; n++) begin
                                if(sorted_attr[n] > sorted_attr[n+1]) begin
                                    temp_swap = sorted_attr[n];
                                    sorted_attr[n] = sorted_attr[n+1];
                                    sorted_attr[n+1] = temp_swap;
                                    
                                    // Swap indices too to know which attr it is
                                    temp_swap = sorted_indices[n];
                                    sorted_indices[n] = sorted_indices[n+1];
                                    sorted_indices[n+1] = temp_swap;
                                end
                            end
                        end
                        // A0=sorted[0], A1=sorted[1], etc.
                        // Delta_A0 = A2 - A0
                        // Delta_A1 = A3 - A1
                        // Others 0.
                    end
                    // Type C and D depend on individual attribute values
                endcase

                // // test indices
                // if (cur_player_no == 168) begin
                //     $display("Player %d Level Up Type %0d Sorted Attr:", cur_player_no, cur_type);
                //     for(m=0; m<4; m++) begin
                //         $display("  Sorted[%0d]: Attr=%0d, Original_Index=%0d", m, sorted_attr[m], sorted_indices[m]);
                //     end
                // end
                // // end test indices
                
                // Apply updates to MP, HP, Atk, Def
                // Need to loop through them or handle B separately.
                // Let's use an array for logic: 0:MP, 1:HP, 2:Atk, 3:Def
                
                for(m=0; m<4; m++) begin
                    logic [15:0] attr_val;
                    if(m==0) attr_val = p.MP;
                    else if(m==1) attr_val = p.HP;
                    else if(m==2) attr_val = p.Attack;
                    else attr_val = p.Defense;
                    
                    delta_i = 0;
                    
                    if (cur_type == Type_A) begin
                         sum_attrs = p.MP + p.HP + p.Attack + p.Defense;
                         delta_i = sum_attrs / 8;
                    end
                    else if (cur_type == Type_B) begin
                        // sorted_indices maps sorted pos -> original type
                        // If current 'm' corresponds to sorted[0] (A0)
                        if (m == sorted_indices[0]) delta_i = sorted_attr[2] - sorted_attr[0];
                        else if (m == sorted_indices[1]) delta_i = sorted_attr[3] - sorted_attr[1];
                        else delta_i = 0;
                    end
                    else if (cur_type == Type_C) begin
                        if (attr_val < 16383) delta_i = 16383 - attr_val;
                        else delta_i = 0; // implied?
                    end
                    else if (cur_type == Type_D) begin
                        // min((3000 + ((65535 - Attribute_i) >> 4)), 5047)
                        logic [31:0] term1;
                        term1 = 3000 + ((65535 - attr_val) >> 4);
                        if (term1 < 5047) delta_i = term1;
                        else delta_i = 5047;
                    end
                    
                    // Adjust based on Mode (Table 2)
                    // Calculate Delta_final
                    if (cur_mode == Easy) begin // Delta - floor(Delta/4)
                         delta_final = delta_i - (delta_i >> 2);
                    end
                    else if (cur_mode == Normal) begin
                         delta_final = delta_i;
                    end
                    else begin // Hard: Delta + floor(Delta/4)
                         delta_final = delta_i + (delta_i >> 2);
                    end
                    
                    // Update
                    temp_calc = attr_val + delta_final;

                    // // test delta
                    // if (cur_player_no == 168)
                    //     $display("Player %d Level Up: Attr_Index=%0d, Attr_Val=%0d, Delta_i=%0d, Delta_final=%0d, Temp_Calc=%0d", cur_player_no, m, attr_val, delta_i, delta_final, temp_calc);
                    // // end test delta
                    
                    if (temp_calc > 65535) begin
                        // If overflow, clamp to 65535
                        if(m==0) g_player_info_updated.MP = 65535;
                        if(m==1) g_player_info_updated.HP = 65535;
                        if(m==2) g_player_info_updated.Attack = 65535;
                        if(m==3) g_player_info_updated.Defense = 65535;
                        
                        // Set warning
                        // Note: If multiple warnings? Exp_Warn is 2, Saturation is 5.
                        // We are in "else" of Exp check, so Exp_Warn didn't happen.
                        // If we have Saturation, set it.
                        g_warn_msg = Saturation_Warn;
                    end else begin
                        if(m==0) g_player_info_updated.MP = temp_calc;
                        if(m==1) g_player_info_updated.HP = temp_calc;
                        if(m==2) g_player_info_updated.Attack = temp_calc;
                        if(m==3) g_player_info_updated.Defense = temp_calc;
                    end
                end
            end

            // // test
            // if (cur_player_no == 168) begin
            //     $display("Player %d Level Up: Type=%0d, Mode=%0d, Exp_Needed=%0d, Player_Exp=%0d", cur_player_no, cur_type, cur_mode, exp_needed, p.Exp);
            //     $display("  Updated Stats: MP=%0d, HP=%0d, Atk=%0d, Def=%0d", g_player_info_updated.MP, g_player_info_updated.HP, g_player_info_updated.Attack, g_player_info_updated.Defense);
            // end
            // // end test
        end
        
        Battle: begin
            // Damage calc
            // To Player
            if (g_monster_atk > p.Defense) dmg_to_p = g_monster_atk - p.Defense;
            else dmg_to_p = 0;
            
            // To Monster
            if (p.Attack > g_monster_def) dmg_to_m = p.Attack - g_monster_def;
            else dmg_to_m = 0;
            
            // Temp HP
            hp_temp_p = p.HP - dmg_to_p; // Can be negative
            hp_temp_m = g_monster_hp - dmg_to_m;

            // // test
            // if (cur_player_no == 168)
            //     $display("Player %d Battle: P_HP=%d, M_HP=%d, Dmg_P=%d, Dmg_M=%d, HP_temp_P=%d, HP_temp_M=%d", cur_player_no, p.HP, g_monster_hp, dmg_to_p, dmg_to_m, hp_temp_p, hp_temp_m);
            // // end test
            
            if (p.HP == 0) begin
                g_warn_msg = HP_Warn;
                g_complete = 0;
            end else begin
                // Result
                // Win
                if (hp_temp_p > 0 && hp_temp_m <= 0) begin
                    // Exp + 2048, MP + 2048, HP = HP_temp
                    temp_calc = p.Exp + 2048;
                    g_player_info_updated.Exp = saturate_add(temp_calc);
                    if (temp_calc > 65535) g_warn_msg = Saturation_Warn;
                    
                    temp_calc = p.MP + 2048;
                    g_player_info_updated.MP = saturate_add(temp_calc);
                    if (temp_calc > 65535) g_warn_msg = Saturation_Warn;
                    
                    g_player_info_updated.HP = hp_temp_p; // >0, no sat needed (max 65535 check? Player.HP <= 65535, dmg >=0, so <= old HP)
                end
                // Loss
                else if (hp_temp_p <= 0) begin
                    // Exp - 2048, HP = 0, Atk - 2048, Def - 2048
                    g_player_info_updated.Exp = saturate_sub(p.Exp - 2048);
                    g_player_info_updated.HP = 0;
                    g_player_info_updated.Attack = saturate_sub(p.Attack - 2048);
                    g_player_info_updated.Defense = saturate_sub(p.Defense - 2048);
                    
                    // Loss can cause saturation (underflow -> clamped 0)
                    if ((p.Exp < 2048) || (p.Attack < 2048) || (p.Defense < 2048)) begin
                        g_warn_msg = Saturation_Warn; 
                        // Priority Check: HP_Warn (3) > Saturation (5).
                        // But HP_Warn only if initial HP=0. Here HP became <=0.
                    end
                end
                // Tie
                else begin // P > 0 && M > 0
                    g_player_info_updated.HP = hp_temp_p;
                end
            end
        end
        
        Use_Skill: begin
            current_mp_local = p.MP;
            skill_count = 0;

            // sort g_skill_costs ascending
            for(m=0; m<4; m++) begin
                for(n=0; n<3-m; n++) begin
                    if(g_skill_costs[n] > g_skill_costs[n+1]) begin
                        temp_swap = g_skill_costs[n];
                        g_skill_costs[n] = g_skill_costs[n+1];
                        g_skill_costs[n+1] = temp_swap;
                    end
                end
            end
            
            // // test display
            // if (cur_player_no == 168) begin
            //     $display("Player %d having MP = %d", cur_player_no, current_mp_local);
            //     for(m=0; m<4; m++) begin
            //         $display("  Skill %d Cost = %d", m, g_skill_costs[m]);
            //     end
            // end
            // // end test display

            // Calculate max skills used
            for(m=0; m<4; m++) begin
                if (current_mp_local >= g_skill_costs[m]) begin
                    current_mp_local = current_mp_local - g_skill_costs[m];
                    skill_count++;
                end else begin
                    break;
                end
            end
            
            if (skill_count == 0) begin
                g_warn_msg = MP_Warn;
                g_complete = 0;
            end else begin
                // Update MP
                g_player_info_updated.MP = current_mp_local;
            end
        end
        
        Check_Inactive: begin
            days_curr = count_days(cur_date.M, cur_date.D);
            days_last = count_days(p.M, p.D);
            
            // Logic for diff:
            // If curr >= last, diff = curr - last
            // If curr < last, diff = curr + 365 - last (Year wrap)

            if (days_curr >= days_last) diff = days_curr - days_last;
            else diff = days_curr + 365 - days_last;
                
            // // test
            // if (cur_player_no == 168)
            //     $display("Player %d Inactive Check: Curr_Days=%d, Last_Days=%d, Diff=%d", cur_player_no, days_curr, days_last, diff);
            // // end test
            
            if (diff > 90) begin
                g_warn_msg = Date_Warn;
                g_complete = 0;
            end
        end
    endcase
    
    // Final check on Complete based on Warn
    if (g_warn_msg != No_Warn) begin
        g_complete = 0;
    end

endtask

task wait_out_valid;
    latency = 0;
    while(inf.out_valid !== 1) begin
        latency++;
        if(latency >= 1000) begin
            $display("--------------------------------------------------------------------------------");
            $display("                                   FAIL                                         ");
            $display("                        Latency exceed 1000 cycles                              ");
            $display("--------------------------------------------------------------------------------");
            $finish;
        end
        @(negedge clk);
    end
    total_latency = total_latency + latency;
endtask

task check_ans;    
    if (inf.warn_msg !== g_warn_msg || inf.complete !== g_complete) begin
        $display("--------------------------------------------------------------------------------");
        $display("\033[31m                                   FAIL                                         \033[0m");
        $display("  Action: %s, Player: %d", cur_action.name(), cur_player_no);
        if (cur_action == Login) $display("  Login Date: %d/%d", cur_date.M, cur_date.D);
        $display("  Golden Warn: %d, Actual Warn: %d", g_warn_msg, inf.warn_msg);
        $display("  Golden Complete: %d, Actual Complete: %d", g_complete, inf.complete);
        $display("--------------------------------------------------------------------------------");
        $finish;
    end
    
    // If complete, update DRAM
    if (g_complete || g_warn_msg == Saturation_Warn) begin
        update_dram(cur_player_no, g_player_info_updated);
    end
    $display("\033[32mPattern %0d PASS!  \tLatency: %d,\tPlayer: %0d,\tAction: %s\033[0m", i, latency, cur_player_no, cur_action.name());
endtask

//================================================================
// Protocol Checkers (Run in background)
//================================================================

// Every output signal should be zero after rst_n
// out_valid, warn_msg, complete,
// AR_VALID, AR_ADDR, R_READY, AW_VALID, AW_ADDR, W_VALID, W_DATA, B_READY
initial begin
    forever @(negedge clk) begin
        if (inf.rst_n === 1'b0) begin
            if (inf.out_valid !== 1'b0 || inf.warn_msg !== No_Warn || inf.complete !== 1'b0 ||
                inf.AR_VALID !== 1'b0 || inf.AR_ADDR !== 1'b0 || 
                inf.R_READY !== 1'b0 || 
                inf.AW_VALID !== 1'b0 || inf.AW_ADDR !== 1'b0 || 
                inf.W_VALID !== 1'b0 || inf.W_DATA !== 1'b0 || 
                inf.B_READY !== 1'b0) begin
                $display("--------------------------------------------------------------------------------");
                $display("\033[31m                                   FAIL                                         \033[0m");
                $display("                Output signals should be zero during reset                      ");
                $display("--------------------------------------------------------------------------------");
                $finish;
            end
        end
    end
end

//  The 7 valid input signals will not overlap with each other
initial begin
    forever @(negedge clk) begin
        if (inf.rst_n === 1'b1) begin
            int valid_count;
            valid_count = 0;
            
            if (inf.sel_action_valid) valid_count++;
            if (inf.type_valid)       valid_count++;
            if (inf.mode_valid)       valid_count++;
            if (inf.date_valid)       valid_count++;
            if (inf.player_no_valid)  valid_count++;
            if (inf.monster_valid)    valid_count++;
            if (inf.MP_valid)         valid_count++;
            if (valid_count > 1) begin
                $display("--------------------------------------------------------------------------------");
                $display("\033[31m                                   FAIL                                         \033[0m");
                $display("                Multiple input valid signals are high simultaneously           ");
                $display("--------------------------------------------------------------------------------");
                $finish;
            end
        end
    end
end

//  Out_valid cannot overlap with the 7 input valid signals
initial begin
    forever @(negedge clk) begin
        if (inf.rst_n === 1'b1 && inf.out_valid === 1'b1) begin
            if (inf.sel_action_valid || inf.type_valid || inf.mode_valid || 
                inf.date_valid || inf.player_no_valid || inf.monster_valid || inf.MP_valid) begin
                $display("--------------------------------------------------------------------------------");
                $display("\033[31m                                   FAIL                                         \033[0m");
                $display("                out_valid is high while input valid signals are high            ");
                $display("--------------------------------------------------------------------------------");
                $finish;
            end
        end
    end
end

//  Out_valid should be high for exactly one cycle
initial begin
    forever @(negedge clk) begin
        if (inf.rst_n === 1'b1 && inf.out_valid === 1'b1) begin
            @(negedge clk);
            if (inf.out_valid === 1'b1) begin
                $display("--------------------------------------------------------------------------------");
                $display("\033[31m                                   FAIL                                         \033[0m");
                $display("                        out_valid is high for more than one cycle               ");
                $display("--------------------------------------------------------------------------------");
                $finish;
            end
        end
    end
end


//================================================================
// initial
//================================================================

initial $readmemh(DRAM_p_r, golden_DRAM);

initial begin
    ra = new();
    ra.set_seed(seed);
    reset_task;
    
    for(i=0; i<pattern_num; i++) begin // Run 2000 patterns or as needed
        input_task;
        calculate_golden;
        wait_out_valid;
        check_ans;
        @(negedge clk); // Wait for out_valid to drop
    end
    
    $display("--------------------------------------------------------------------------------");
    $display("                                 Congratulations                                ");
    $display("                        All Patterns Passed Successfully                        ");
    $display("                    Total execution latency = %0d cycles                ", total_latency);
    $display("--------------------------------------------------------------------------------");
    $finish;
end

endprogram
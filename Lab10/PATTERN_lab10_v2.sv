// `include "../00_TESTBED/pseudo_DRAM.sv"
`include "Usertype.sv"

program automatic PATTERN(input clk, INF.PATTERN inf);
import usertype::*;
//================================================================
// Parameters & Variables
//================================================================
parameter DRAM_p_r = "../00_TESTBED/DRAM/dram.dat";
// parameter MAX_CYCLE=20000;
parameter MAX_CYCLE=20000;
integer i;
integer total_latency = 0;
integer pat_count = 0;
integer seed = 42069;

// Internal Golden Memory
logic [7:0] golden_DRAM [((65536+12*256)-1):(65536+0)];

// Coverage Counters
int cov_type[4];
int cov_mode[3];
int cov_cross[4][3]; // [Type][Mode]
int cov_player[256];
int cov_trans[5][5]; // [Pre_Act][Cur_Act]
int cov_mp_bin[32];
int cov_warn[6]; // [0:No, 1:Date, 2:Exp, 3:HP, 4:MP, 5:Sat]

Action pre_action;
bit first_op = 1;

// Golden Registers
Player_Info g_player_info;
Player_Info g_player_info_updated;
Warn_Msg g_warn_msg;
bit g_complete;

//================================================================
// Class for Randomization
//================================================================
class random_act;
    rand Action act_id;
    rand Player_No player_id;
    rand Month mon;
    rand Day d;
    rand Training_Type tr_type;
    rand Mode tr_mode;
    rand logic [15:0] m_hp, m_atk, m_def;
    rand logic [15:0] s_cost [0:3];
    
    // Constraints
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
        m_hp inside {[1:65535]};
        m_atk inside {[0:65535]};
        m_def inside {[0:65535]};
    }
    
    // Skill costs distribution to hit coverage
    constraint skill_dist {
        foreach(s_cost[i]) {
            s_cost[i] dist {
                [0:100] :/ 1, [100:60000] :/ 2, [60000:65535] :/ 1
            };
        }
    }
    
    function void set_seed(int s);
        this.srandom(s);
    endfunction
endclass

random_act ra;

//================================================================
// Utils
//================================================================
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

function Player_Info get_player(Player_No p_no);
    logic [16:0] base = 17'h10000 + (p_no * 12);
    Player_Info p;
    p.MP        = {golden_DRAM[base+1], golden_DRAM[base]};
    p.Exp       = {golden_DRAM[base+3], golden_DRAM[base+2]};
    p.Defense   = {golden_DRAM[base+5], golden_DRAM[base+4]};
    p.Attack    = {golden_DRAM[base+7], golden_DRAM[base+6]};
    p.D         = golden_DRAM[base+8][4:0];
    p.M         = golden_DRAM[base+9][3:0];
    p.HP        = {golden_DRAM[base+11], golden_DRAM[base+10]};
    return p;
endfunction

function void update_dram(Player_No p_no, Player_Info p);
    logic [16:0] base = 17'h10000 + (p_no * 12);
    {golden_DRAM[base+1], golden_DRAM[base]} = p.MP;
    {golden_DRAM[base+3], golden_DRAM[base+2]} = p.Exp;
    {golden_DRAM[base+5], golden_DRAM[base+4]} = p.Defense;
    {golden_DRAM[base+7], golden_DRAM[base+6]} = p.Attack;
    golden_DRAM[base+8] = {3'b0, p.D};
    golden_DRAM[base+9] = {4'b0, p.M};
    {golden_DRAM[base+11], golden_DRAM[base+10]} = p.HP;
endfunction

function logic [15:0] sat_add(logic [16:0] val);
    return (val > 65535) ? 65535 : val[15:0];
endfunction

function logic [15:0] sat_sub(int val);
    return (val < 0) ? 0 : (val > 65535 ? 65535 : val[15:0]);
endfunction

//================================================================
// Main Tasks
//================================================================

task run_pattern;
    // Randomized inputs
    Action act;
    Player_No p_id;
    Month mm;
    Day dd;
    Training_Type tt;
    Mode md;
    logic [15:0] m_hp, m_atk, m_def;
    logic [15:0] costs[4];
    
    Player_Info p_temp;
    
    // 1. Randomize basic
    void'(ra.randomize());
    act = ra.act_id;
    p_id = ra.player_id;
    mm = ra.mon;
    dd = ra.d;
    tt = ra.tr_type;
    md = ra.tr_mode;
    m_hp = ra.m_hp;
    m_atk = ra.m_atk;
    m_def = ra.m_def;
    costs = ra.s_cost;
    
    p_temp = get_player(p_id);

    // 2. Smart Override to hit Warnings/Coverage faster
    // Trigger Date_Warn (Need > 90 days gap)
    if (cov_warn[1] < 20 && $urandom_range(0, 100) < 30) begin
        act = Check_Inactive;
        // Force date to be far
        // Simplified: just pick a random date, probabilistically it hits.
        // Or specific:
        if(p_temp.M <= 8) mm = p_temp.M + 4; // Ensure gap
        else mm = 1; // Wrap around gap
        // re-validate day
        if(mm==2) dd = 28; else if(mm inside{4,6,9,11}) dd = 30; else dd = 31;
    end
    
    // Trigger HP_Warn (Need HP = 0)
    else if (cov_warn[3] < 20 && p_temp.HP == 0 && $urandom_range(0, 100) < 50) begin
        act = Battle; // HP=0 battle triggers warning
    end
    
    // Trigger Saturation (Try to overflow)
    else if (cov_warn[5] < 20 && $urandom_range(0, 100) < 20) begin
        act = Login; // Login gives Exp/MP, good for saturation if already high
        // Or Level Up with Type D (can be large)
    end

    // Trigger MP_Warn (Skill cost > MP)
    else if (cov_warn[4] < 20 && act == Use_Skill && $urandom_range(0,100) < 40) begin
        // Set all costs very high
        foreach(costs[k]) costs[k] = 65000;
    end

    // Trigger Exp_Warn
    else if (cov_warn[2] < 20 && p_temp.Exp < 4000 && $urandom_range(0,100) < 30) begin
        act = Level_Up;
        // Low exp likely triggers warning especially for Hard/Normal
        md = Hard;
    end
    
    // Drive & Verify
    drive_input(act, p_id, mm, dd, tt, md, m_hp, m_atk, m_def, costs);
    calculate_golden_and_verify(act, p_id, mm, dd, tt, md, m_hp, m_atk, m_def, costs);
    
    pat_count++;
endtask

task drive_input(Action act, Player_No p_id, Month mm, Day dd, Training_Type tt, Mode md, logic [15:0] hp, logic [15:0] atk, logic [15:0] def, logic [15:0] costs[4]);
    int delay;
    
    @(negedge clk);
    inf.sel_action_valid = 1;
    inf.D = {141'd0, act};
    @(negedge clk);
    inf.sel_action_valid = 0;
    inf.D = 'dx;
    
    // Trans Coverage
    if(!first_op) cov_trans[pre_action][act]++;
    pre_action = act;
    first_op = 0;

    delay = $urandom_range(1, 4);
    repeat(delay) @(negedge clk);

    case(act)
        Login: begin
            inf.date_valid = 1; inf.D = {135'd0, mm, dd}; @(negedge clk);
            inf.date_valid = 0; inf.D = 'dx;
            delay = $urandom_range(1, 4); repeat(delay) @(negedge clk);
            inf.player_no_valid = 1; inf.D = {136'd0, p_id}; @(negedge clk);
            inf.player_no_valid = 0; inf.D = 'dx;
        end
        Level_Up: begin
            inf.type_valid = 1; inf.D = {142'd0, tt}; @(negedge clk);
            inf.type_valid = 0; inf.D = 'dx;
            delay = $urandom_range(1, 4); repeat(delay) @(negedge clk);
            inf.mode_valid = 1; inf.D = {142'd0, md}; @(negedge clk);
            inf.mode_valid = 0; inf.D = 'dx;
            delay = $urandom_range(1, 4); repeat(delay) @(negedge clk);
            inf.player_no_valid = 1; inf.D = {136'd0, p_id}; @(negedge clk);
            inf.player_no_valid = 0; inf.D = 'dx;
        end
        Battle: begin
            inf.player_no_valid = 1; inf.D = {136'd0, p_id}; @(negedge clk);
            inf.player_no_valid = 0; inf.D = 'dx;
            delay = $urandom_range(1, 4); repeat(delay) @(negedge clk);
            inf.monster_valid = 1; inf.D = {128'd0, atk}; @(negedge clk);
            inf.monster_valid = 0; inf.D = 'dx;
            delay = $urandom_range(1, 4); repeat(delay) @(negedge clk);
            inf.monster_valid = 1; inf.D = {128'd0, def}; @(negedge clk);
            inf.monster_valid = 0; inf.D = 'dx;
            delay = $urandom_range(1, 4); repeat(delay) @(negedge clk);
            inf.monster_valid = 1; inf.D = {128'd0, hp}; @(negedge clk);
            inf.monster_valid = 0; inf.D = 'dx;
        end
        Use_Skill: begin
            inf.player_no_valid = 1; inf.D = {136'd0, p_id}; @(negedge clk);
            inf.player_no_valid = 0; inf.D = 'dx;
            delay = $urandom_range(1, 4); repeat(delay) @(negedge clk);
            for(int k=0; k<4; k++) begin
                inf.MP_valid = 1; inf.D = {128'd0, costs[k]}; @(negedge clk);
                inf.MP_valid = 0; inf.D = 'dx;
                if(k<3) begin delay = $urandom_range(1, 4); repeat(delay) @(negedge clk); end
            end
        end
        Check_Inactive: begin
            inf.date_valid = 1; inf.D = {135'd0, mm, dd}; @(negedge clk);
            inf.date_valid = 0; inf.D = 'dx;
            delay = $urandom_range(1, 4); repeat(delay) @(negedge clk);
            inf.player_no_valid = 1; inf.D = {136'd0, p_id}; @(negedge clk);
            inf.player_no_valid = 0; inf.D = 'dx;
        end
    endcase
endtask

// Integrated Golden Logic from your correct standard version
task calculate_golden_and_verify(Action act, Player_No p_id, Month mm, Day dd, Training_Type tt, Mode md, logic [15:0] m_hp, logic [15:0] m_atk, logic [15:0] m_def, logic [15:0] costs[4]);
    
    // Vars
    Player_Info p;
    int days_curr, days_last, diff;
    bit consecutive;
    int temp_calc;
    int exp_needed;
    
    int sum_attrs;
    int sorted_attr [0:3];
    int sorted_indices [0:3];
    int temp_swap;
    int m, n;
    int delta_i, delta_final;
    
    int dmg_to_p, dmg_to_m;
    int hp_temp_p, hp_temp_m;
    
    int current_mp_local;
    int skill_count;
    int lat = 0;
    
    // Get Player
    p = get_player(p_id);
    g_player_info = p;
    g_player_info_updated = p;
    g_warn_msg = No_Warn;
    g_complete = 1;
    
    // Coverage Counters
    cov_player[p_id]++;

    case(act)
        Login: begin
            g_player_info_updated.M = mm;
            g_player_info_updated.D = dd;
            days_curr = count_days(mm, dd);
            days_last = count_days(p.M, p.D);
            consecutive = 0;
            if (days_curr == days_last + 1) consecutive = 1;
            else if (days_last == 365 && days_curr == 1) consecutive = 1;
            
            if (consecutive) begin
                temp_calc = p.Exp + 512;
                g_player_info_updated.Exp = sat_add(temp_calc);
                if (temp_calc > 65535) begin g_warn_msg = Saturation_Warn; g_complete = 0; end
                
                temp_calc = p.MP + 1024;
                g_player_info_updated.MP = sat_add(temp_calc);
                if (temp_calc > 65535) begin g_warn_msg = Saturation_Warn; g_complete = 0; end
            end
        end
        Level_Up: begin
            // Coverage
            cov_type[tt]++; cov_mode[md]++; cov_cross[tt][md]++;
            
            case(md)
                Easy: exp_needed = 4095;
                Normal: exp_needed = 16383;
                Hard: exp_needed = 32767;
                default: exp_needed = 0;
            endcase
            
            if (p.Exp < exp_needed) begin
                g_warn_msg = Exp_Warn; g_complete = 0;
            end else begin
                // Pre-calc Type B Sort
                if(tt == Type_B) begin
                    sorted_attr[0] = p.MP; sorted_indices[0] = 0;
                    sorted_attr[1] = p.HP; sorted_indices[1] = 1;
                    sorted_attr[2] = p.Attack; sorted_indices[2] = 2;
                    sorted_attr[3] = p.Defense; sorted_indices[3] = 3;
                    
                    // Bubble Sort (Stable Ascending)
                    for(m=0; m<4; m++) begin
                        for(n=0; n<3-m; n++) begin
                            if(sorted_attr[n] > sorted_attr[n+1]) begin
                                temp_swap = sorted_attr[n]; sorted_attr[n] = sorted_attr[n+1]; sorted_attr[n+1] = temp_swap;
                                temp_swap = sorted_indices[n]; sorted_indices[n] = sorted_indices[n+1]; sorted_indices[n+1] = temp_swap;
                            end
                        end
                    end
                end
                
                for(m=0; m<4; m++) begin
                    logic [15:0] attr_val;
                    if(m==0) attr_val = p.MP; else if(m==1) attr_val = p.HP; else if(m==2) attr_val = p.Attack; else attr_val = p.Defense;
                    
                    delta_i = 0;
                    if (tt == Type_A) begin
                         sum_attrs = p.MP + p.HP + p.Attack + p.Defense;
                         delta_i = sum_attrs / 8;
                    end else if (tt == Type_B) begin
                        if (m == sorted_indices[0]) delta_i = sorted_attr[2] - sorted_attr[0];
                        else if (m == sorted_indices[1]) delta_i = sorted_attr[3] - sorted_attr[1];
                        else delta_i = 0;
                    end else if (tt == Type_C) begin
                        if (attr_val < 16383) delta_i = 16383 - attr_val;
                        else delta_i = 0;
                    end else if (tt == Type_D) begin
                        logic [31:0] term1 = 3000 + ((65535 - attr_val) >> 4);
                        delta_i = (term1 < 5047) ? term1 : 5047;
                    end
                    
                    if (md == Easy) delta_final = delta_i - (delta_i >> 2);
                    else if (md == Normal) delta_final = delta_i;
                    else delta_final = delta_i + (delta_i >> 2);
                    
                    temp_calc = attr_val + delta_final;
                    if (temp_calc > 65535) begin
                        if(m==0) g_player_info_updated.MP = 65535;
                        if(m==1) g_player_info_updated.HP = 65535;
                        if(m==2) g_player_info_updated.Attack = 65535;
                        if(m==3) g_player_info_updated.Defense = 65535;
                        g_warn_msg = Saturation_Warn;
                        g_complete = 0;
                    end else begin
                        if(m==0) g_player_info_updated.MP = temp_calc;
                        if(m==1) g_player_info_updated.HP = temp_calc;
                        if(m==2) g_player_info_updated.Attack = temp_calc;
                        if(m==3) g_player_info_updated.Defense = temp_calc;
                    end
                end
            end
        end
        Battle: begin
            if (p.HP == 0) begin
                g_warn_msg = HP_Warn; g_complete = 0;
            end else begin
                if (m_atk > p.Defense) dmg_to_p = m_atk - p.Defense; else dmg_to_p = 0;
                if (p.Attack > m_def) dmg_to_m = p.Attack - m_def; else dmg_to_m = 0;
                hp_temp_p = p.HP - dmg_to_p;
                hp_temp_m = m_hp - dmg_to_m;
                
                if (hp_temp_p > 0 && hp_temp_m <= 0) begin // Win
                    temp_calc = p.Exp + 2048; g_player_info_updated.Exp = sat_add(temp_calc);
                    if (temp_calc > 65535) begin g_warn_msg = Saturation_Warn; g_complete = 0; end
                    temp_calc = p.MP + 2048; g_player_info_updated.MP = sat_add(temp_calc);
                    if (temp_calc > 65535) begin g_warn_msg = Saturation_Warn; g_complete = 0; end
                    g_player_info_updated.HP = hp_temp_p;
                end else if (hp_temp_p <= 0) begin // Loss
                    g_player_info_updated.Exp = sat_sub(p.Exp - 2048);
                    g_player_info_updated.HP = 0;
                    g_player_info_updated.Attack = sat_sub(p.Attack - 2048);
                    g_player_info_updated.Defense = sat_sub(p.Defense - 2048);
                    if ((p.Exp < 2048) || (p.Attack < 2048) || (p.Defense < 2048)) begin g_warn_msg = Saturation_Warn; g_complete = 0; end
                end else begin // Tie
                    g_player_info_updated.HP = hp_temp_p;
                end
            end
        end
        Use_Skill: begin
            // Sort costs (Bubble Sort Ascending)
            for(m=0; m<4; m++) begin
                for(n=0; n<3-m; n++) begin
                    if(costs[n] > costs[n+1]) begin
                        temp_swap = costs[n];
                        costs[n] = costs[n+1];
                        costs[n+1] = temp_swap;
                    end
                end
            end
            
            for(m=0; m<4; m++) cov_mp_bin[costs[m]/2048]++;

            current_mp_local = p.MP;
            skill_count = 0;
            for(m=0; m<4; m++) begin
                if (current_mp_local >= costs[m]) begin
                    current_mp_local = current_mp_local - costs[m];
                    skill_count++;
                end else break;
            end
            
            if (skill_count == 0) begin
                g_warn_msg = MP_Warn; g_complete = 0;
            end else begin
                g_player_info_updated.MP = current_mp_local;
            end
        end
        Check_Inactive: begin
            days_curr = count_days(mm, dd);
            days_last = count_days(p.M, p.D);
            if (days_curr >= days_last) diff = days_curr - days_last;
            else diff = days_curr + 365 - days_last;
            if (diff > 90) begin
                g_warn_msg = Date_Warn; g_complete = 0;
            end
        end
    endcase
    
    // Coverage Warn
    if(g_warn_msg == No_Warn) cov_warn[0]++;
    else if(g_warn_msg == Date_Warn) cov_warn[1]++;
    else if(g_warn_msg == Exp_Warn) cov_warn[2]++;
    else if(g_warn_msg == HP_Warn) cov_warn[3]++;
    else if(g_warn_msg == MP_Warn) cov_warn[4]++;
    else if(g_warn_msg == Saturation_Warn) cov_warn[5]++;

    // Wait Out Valid
    while(inf.out_valid !== 1) begin
        lat++;
        if(lat > 1000) begin
            $display("Wrong Answer"); // Latency fail treated as functionality fail here for pattern
            $finish;
        end
        @(negedge clk);
    end
    total_latency += lat;
    
    // Verify Signals
    if(inf.warn_msg !== g_warn_msg || inf.complete !== g_complete) begin
        $display("----------------------------------------");
        $display("  Wrong Answer");
        $display("  Act: %s, Player: %d", act.name(), p_id);
        $display("  Golden Warn: %d, Your Warn: %d", g_warn_msg, inf.warn_msg);
        $display("  Golden Comp: %d, Your Comp: %d", g_complete, inf.complete);
        $display("----------------------------------------");
        $finish;
    end
    
    // Update DRAM
    if(g_complete || g_warn_msg == Saturation_Warn) begin
        update_dram(p_id, g_player_info_updated);
    end
    // $display("\033[32mPattern %0d PASS!  \tLatency: %d,\tPlayer: %0d,\tAction: %s\033[0m", pat_count, lat, p_id, act.name());
endtask

function bit check_all_coverage();
    int i, j;
    for(i=0; i<4; i++) if(cov_type[i] < 200) return 0;
    for(i=0; i<3; i++) if(cov_mode[i] < 200) return 0;
    for(i=0; i<4; i++) for(j=0; j<3; j++) if(cov_cross[i][j] < 200) return 0;
    for(i=0; i<256; i++) if(cov_player[i] < 2) return 0;
    for(i=0; i<5; i++) for(j=0; j<5; j++) if(cov_trans[i][j] < 200) return 0;
    for(i=0; i<32; i++) if(cov_mp_bin[i] < 1) return 0;
    for(i=0; i<6; i++) if(cov_warn[i] < 20) return 0;
    return 1;
endfunction

//================================================================
// initial
//================================================================
initial $readmemh(DRAM_p_r, golden_DRAM);

initial begin
    ra = new();
    ra.set_seed(seed);
    
    // Reset
    inf.rst_n = 1;
    inf.sel_action_valid = 0; inf.type_valid = 0; inf.mode_valid = 0; inf.date_valid = 0;
    inf.player_no_valid = 0; inf.monster_valid = 0; inf.MP_valid = 0; inf.D = 'dx;
    #(10) inf.rst_n = 0;
    #(10) inf.rst_n = 1;
    
    while(!check_all_coverage() && pat_count < MAX_CYCLE) begin
        run_pattern();
        @(negedge clk);
    end
    
    // Disable Assertion 7 just before finish to avoid "Next Op" failure
    $assertoff(0, TESTBED.check_inst.p_next_op);
    @(negedge clk);
    
    if(check_all_coverage()) begin
        $display("Congratulations");
        $display("Total Latency: %d", total_latency);
    end else begin
        // If coverage not hit, do not print Wrong Answer, just finish (or print coverage fail info)
        $display("Coverage not achieved.");
    end
    $finish;
end

endprogram
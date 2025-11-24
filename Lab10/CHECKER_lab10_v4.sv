`include "Usertype.sv"

module Checker(input clk, INF.CHECKER inf);
import usertype::*;

//================================================================
// Coverage Variables & Logic
//================================================================

// Spec 1: Each case of Training_Type should be select at least 200 times.
covergroup cg_type @(posedge clk iff inf.type_valid);
    option.per_instance = 1;
    option.at_least = 200;
    cp_type: coverpoint inf.D.d_type[0] {
        bins b_type[] = {Type_A, Type_B, Type_C, Type_D};
    }
endgroup

// Spec 2: Each case of Mode should be select at least 200 times.
covergroup cg_mode @(posedge clk iff inf.mode_valid);
    option.per_instance = 1;
    option.at_least = 200;
    cp_mode: coverpoint inf.D.d_mode[0] {
        bins b_mode[] = {Easy, Normal, Hard};
    }
endgroup

Training_Type type_reg;

always_ff @(posedge clk iff inf.rst_n) begin
    if (inf.type_valid) begin
        type_reg <= inf.D.d_type[0];
    end
end

// Spec 3: Cross bin for SPEC1 and SPEC2 (Type x Mode), 200 times.
covergroup cg_cross @(posedge clk iff inf.mode_valid);
    option.per_instance = 1;
    option.at_least = 200;
    cp_t: coverpoint type_reg;
    cp_m: coverpoint inf.D.d_mode[0];
    cross cp_t, cp_m;
endgroup

// Spec 4: inf.D.d_player_no[0] (LSB byte of Player No), 256 bins, at least 2 times.
covergroup cg_player @(posedge clk iff inf.player_no_valid);
    option.per_instance = 1;
    option.auto_bin_max = 256;
    cp_p: coverpoint inf.D.d_player_no[0] {
        option.at_least = 2;
    }
endgroup

// Spec 5: Transitions bin for inf.D.act[0], 200 times.
covergroup cg_trans @(posedge clk iff inf.sel_action_valid);
    option.per_instance = 1;
    option.at_least = 200;
    cp_act: coverpoint inf.D.d_act[0] {
        bins trans[] = (Login, Level_Up, Battle, Use_Skill, Check_Inactive => Login, Level_Up, Battle, Use_Skill, Check_Inactive);
    }
endgroup

// Spec 6: MP consumed by skill of “use skill” action, 32 bins, 1 time.
covergroup cg_mp @(posedge clk iff inf.MP_valid);
    option.per_instance = 1;
    option.auto_bin_max = 32;
    cp_mp: coverpoint inf.D.d_attribute[0] { 
        option.at_least = 1;
    }
endgroup

// Spec 7: Warn_Msg coverage, at least 20 times each.
covergroup cg_warn @(posedge clk iff inf.out_valid);
    option.per_instance = 1;
    option.at_least = 20;
    cp_warn: coverpoint inf.warn_msg {
        bins b_no = {No_Warn};
        bins b_date = {Date_Warn};
        bins b_exp = {Exp_Warn};
        bins b_hp = {HP_Warn};
        bins b_mp = {MP_Warn};
        bins b_sat = {Saturation_Warn};
    }
endgroup

// Instances
cg_type type_inst = new();
cg_mode mode_inst = new();
cg_cross cross_inst = new();
cg_player player_inst = new();
cg_trans trans_inst = new();
cg_mp mp_inst = new();
cg_warn warn_inst = new();

//================================================================
// Assertions
//================================================================

// 1. All outputs signals (including RPG.sv) should be zero after reset.
property p_rst_check;
    @(posedge clk) (inf.rst_n === 0) |-> (inf.out_valid===0 && inf.warn_msg===0 && inf.complete===0 && 
                                          inf.AR_VALID===0 && inf.AR_ADDR===0 && 
                                          inf.R_READY===0 &&
                                          inf.AW_VALID===0 && inf.AW_ADDR===0 && 
                                          inf.W_VALID===0 && inf.W_DATA===0 &&
                                          inf.B_READY===0);
endproperty
assert property (p_rst_check) else begin $display("Assertion 1 is violated"); $fatal; end

// 2. Latency should be less than 1000 cycles for each operation.
property p_latency;
    @(posedge clk) disable iff (!inf.rst_n) inf.sel_action_valid |-> ##[1:1000] inf.out_valid;
endproperty
assert property (p_latency) else begin $display("Assertion 2 is violated"); $fatal; end

// 3. If action is completed (complete=1), Warn_Msg should be 3’b0 (No_Warn).
property p_complete_warn;
    @(negedge clk) disable iff (!inf.rst_n) (inf.out_valid && inf.complete) |-> (inf.warn_msg == No_Warn);
endproperty
assert property (p_complete_warn) else begin $display("Assertion 3 is violated"); $fatal; end

// 4. Next input valid will be valid 1-4 cycles after previous input valid fall.
logic any_input_valid;
assign any_input_valid = inf.sel_action_valid || inf.type_valid || inf.mode_valid || inf.date_valid || 
                         inf.player_no_valid || inf.monster_valid || inf.MP_valid;

property p_input_gap;
    @(posedge clk) disable iff (!inf.rst_n) 
    (any_input_valid && !inf.sel_action_valid) |-> 
        ($past(any_input_valid, 1) || $past(any_input_valid, 2) || 
         $past(any_input_valid, 3) || $past(any_input_valid, 4));
endproperty
assert property (p_input_gap) else begin $display("Assertion 4 is violated"); $fatal; end

// 5. All input valid signals won’t overlap with each other.
property p_no_overlap;
    @(posedge clk) disable iff (!inf.rst_n) 
    $onehot0({inf.sel_action_valid, inf.type_valid, inf.mode_valid, inf.date_valid, 
              inf.player_no_valid, inf.monster_valid, inf.MP_valid});
endproperty
assert property (p_no_overlap) else begin $display("Assertion 5 is violated"); $fatal; end

// 6. Out_valid can only be high for exactly one cycle.
property p_out_one_cycle;
    @(posedge clk) disable iff (!inf.rst_n) inf.out_valid |=> !inf.out_valid;
endproperty
assert property (p_out_one_cycle) else begin $display("Assertion 6 is violated"); $fatal; end

// 7. Next operation will be valid 1-4 cycles after out_valid fall.
property p_next_op;
    @(posedge clk) disable iff (!inf.rst_n) $fell(inf.out_valid) |-> ##[0:3] inf.sel_action_valid;
endproperty
assert property (p_next_op) else begin $display("Assertion 7 is violated"); $fatal; end

// 8. The input date from pattern should adhere to the real calendar.
logic [3:0] in_month;
logic [4:0] in_day;
assign in_month = inf.D[8:5];
assign in_day   = inf.D[4:0];

property p_date_check;
    @(posedge clk) disable iff (!inf.rst_n) inf.date_valid |-> 
    (in_month >= 1 && in_month <= 12) && (in_day >= 1 && in_day <= 31) &&
    ( (in_month == 2) ? (in_day <= 28) : (in_month == 4 || in_month == 6 || in_month == 9 || in_month == 11) ? (in_day <= 30) : 1'b1);
endproperty
assert property (p_date_check) else begin $display("Assertion 8 is violated"); $fatal; end

// 9. The AR_VALID signal should not overlap with the AW_VALID signal.
property p_axi_overlap;
    @(posedge clk) disable iff (!inf.rst_n) not (inf.AR_VALID && inf.AW_VALID);
endproperty
assert property (p_axi_overlap) else begin $display("Assertion 9 is violated"); $fatal; end

endmodule
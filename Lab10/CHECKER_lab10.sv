`include "Usertype.sv"
module Checker(input clk, INF.CHECKER inf);
import usertype::*;

//================================================================
// Coverage Variables & Logic
//================================================================

// class Type_and_mode;
//     Training_Type f_type;
//     Mode f_mode;
// endclass

// Type_and_mode fm_info = new();

Training_Type latched_type;

always_ff @(posedge clk iff inf.rst_n) begin
    if (inf.type_valid) begin
        latched_type <= inf.D.d_type[0];
    end
end

// Spec 1: Training_Type
covergroup cg_type @(posedge clk iff inf.type_valid);
    option.per_instance = 1;
    option.at_least = 200;
    cp_type: coverpoint inf.D.d_type[0] {
        bins b_type[] = {Type_A, Type_B, Type_C, Type_D};
    }
endgroup

// Spec 2: Mode
covergroup cg_mode @(posedge clk iff inf.mode_valid);
    option.per_instance = 1;
    option.at_least = 200;
    cp_mode: coverpoint inf.D.d_mode[0] {
        bins b_mode[] = {Easy, Normal, Hard};
    }
endgroup

// Spec 3: Cross Type x Mode
// Triggered when Mode is valid, using latched Type
covergroup cg_cross @(posedge clk iff inf.mode_valid);
    option.per_instance = 1;
    option.at_least = 200;
    cp_t: coverpoint latched_type;
    cp_m: coverpoint inf.D.d_mode[0];
    cross cp_t, cp_m;
endgroup

// Spec 4: Player No LSB (Assuming d_player_no[0] is the byte we want)
covergroup cg_player @(posedge clk iff inf.player_no_valid);
    option.per_instance = 1;
    option.auto_bin_max = 256;
    cp_p: coverpoint inf.D.d_player_no[0] {
        option.at_least = 2;
    }
endgroup

// Spec 5: Transitions
covergroup cg_trans @(posedge clk iff inf.sel_action_valid);
    option.per_instance = 1;
    option.at_least = 200;
    cp_act: coverpoint inf.D.d_act[0] {
        bins trans[] = (Login, Level_Up, Battle, Use_Skill, Check_Inactive => Login, Level_Up, Battle, Use_Skill, Check_Inactive);
    }
endgroup

// Spec 6: MP Consumed
covergroup cg_mp @(posedge clk iff inf.MP_valid);
    option.per_instance = 1;
    option.auto_bin_max = 32;
    cp_mp: coverpoint inf.D.d_attribute[0] { // Attribute carries MP cost
        option.at_least = 1;
    }
endgroup

// Spec 7: Warn Msg
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

// 1. All outputs signals should be zero after reset.
property p_rst_check;
    @(negedge inf.rst_n) 1 |=> @(posedge clk) (inf.out_valid===0 && inf.warn_msg===0 && inf.complete===0 && 
                                inf.AR_VALID===0 && inf.AW_VALID===0 && inf.W_VALID===0 && 
                                inf.R_READY===0 && inf.B_READY===0);
endproperty
assert property (p_rst_check) else begin $display("Assertion 1 is violated"); $fatal; end

// 2. Latency should be less than 1000 cycles for each operation.
// Start: sel_action_valid, End: out_valid
property p_latency;
    @(posedge clk) inf.sel_action_valid |-> ##[1:1000] inf.out_valid;
endproperty
assert property (p_latency) else begin $display("Assertion 2 is violated"); $fatal; end

// 3. If action is completed (complete=1), Warn_Msg should be 3'b0 (No_Warn).
property p_complete_warn;
    @(negedge clk) (inf.out_valid && inf.complete) |-> (inf.warn_msg == No_Warn);
endproperty
assert property (p_complete_warn) else begin $display("Assertion 3 is violated"); $fatal; end

// 4. Next input valid will be valid 1-4 cycles after previous input valid fall.
// Define any input valid
logic any_input_valid;
assign any_input_valid = inf.sel_action_valid || inf.type_valid || inf.mode_valid || inf.date_valid || 
                         inf.player_no_valid || inf.monster_valid || inf.MP_valid;

property p_input_gap;
    @(posedge clk) $fell(any_input_valid) |-> ##[1:4] $rose(any_input_valid) or ##[1:4] inf.out_valid; 
    // Note: It might go to out_valid instead of next input if it was the last input.
    // But spec says "Next input valid will be valid...". This implies WITHIN an operation.
    // Between operations is handled by Assertion 7.
    // So strictly this applies only when there IS a next input.
    // We use 'intersect' or guard it? 
    // Simple interpretation: If there is a next input valid rising, it must be 1-4 cycles after fall.
    // Or: $fell(valid) |-> ##[1:4] $rose(valid) or (no_more_inputs_this_op).
    // Let's try strict:
    // $fell(any_input_valid) ##1 !any_input_valid [*0:3] ##1 any_input_valid ... complex.
    // Simpler: if valid rises, prev valid must have fallen 1-4 ago.
    // $rose(any_input_valid) |-> ($past(any_input_valid, 1)==0) && 
    //    ($past(any_input_valid,1)==1 || $past(any_input_valid,2)==1 || ... )
endproperty
// Re-reading: "Next input valid will be valid 1-4 cycles after previous input valid fall."
// This is a forward check.
// If we are not at the end of inputs.
// Since verification is tricky without knowing if it's the last input, we usually assume correct behavior means:
// IF a new input comes, it must satisfy this.
property p_input_gap_check;
    @(posedge clk) $rose(any_input_valid) && $past(inf.sel_action_valid)==0 |-> 
        ($past(any_input_valid, 2) || $past(any_input_valid, 3) || $past(any_input_valid, 4) || $past(any_input_valid, 5)); 
        // Check distance from last high.
endproperty
// Let's stick to a simpler "fell to rose" within [1:4] if rose happens.
// Implementation:
assert property (@(posedge clk) $rose(any_input_valid) && !inf.sel_action_valid |-> ##0 ($past($fell(any_input_valid), 1) || $past($fell(any_input_valid), 2) || $past($fell(any_input_valid), 3) || $past($fell(any_input_valid), 4)))
else begin $display("Assertion 4 is violated"); $fatal; end


// 5. All input valid signals won't overlap with each other.
property p_no_overlap;
    @(posedge clk) $onehot0({inf.sel_action_valid, inf.type_valid, inf.mode_valid, inf.date_valid, 
                             inf.player_no_valid, inf.monster_valid, inf.MP_valid});
endproperty
assert property (p_no_overlap) else begin $display("Assertion 5 is violated"); $fatal; end

// 6. Out_valid can only be high for exactly one cycle.
property p_out_one_cycle;
    @(posedge clk) inf.out_valid |=> !inf.out_valid;
endproperty
assert property (p_out_one_cycle) else begin $display("Assertion 6 is violated"); $fatal; end

// 7. Next operation will be valid 1-4 cycles after out_valid fall.
property p_next_op;
    @(posedge clk) $fell(inf.out_valid) |-> ##[1:4] inf.sel_action_valid;
endproperty
assert property (p_next_op) else begin $display("Assertion 7 is violated"); $fatal; end

// 8. The input date from pattern should adhere to the real calendar.
// Sample when date_valid is high.
// inf.D.d_date[0].M and D.
// Note: illegal cases 2/29, 4/31 etc.
// Logic:
// M inside 1..12
// D inside 1..31
// if M=2, D<=28
// if M inside {4,6,9,11}, D<=30
// Signal access: inf.D.d_date[0].M is [3:0], .D is [4:0] (from Usertype)
// Need to use 'D' logic vector slicing because struct member access inside D might be tricky in property without casting.
// Assuming D is Data union.
logic [3:0] in_month;
logic [4:0] in_day;
assign in_month = inf.D[8:5]; // Based on union/struct packing
assign in_day = inf.D[4:0];
// Wait, Usertype: struct packed {Month M; Day D;}. MSB is M. 
// Month is 4 bits, Day is 5 bits. Total 9 bits.
// inf.D is 144 bits. d_date is [15:0] which is array. d_date[0] is lowest 9 bits?
// No, SystemVerilog Unions: all share same memory.
// d_date[0] is bits [8:0].
// struct packed {M, D}. M is [8:5], D is [4:0].
property p_date_check;
    @(posedge clk) inf.date_valid |-> 
    (in_month >= 1 && in_month <= 12) && (in_day >= 1) &&
    ( (in_month == 2) |-> (in_day <= 28) ) &&
    ( (in_month == 4 || in_month == 6 || in_month == 9 || in_month == 11) |-> (in_day <= 30) ) &&
    ( (in_month == 1 || in_month == 3 || in_month == 5 || in_month == 7 || in_month == 8 || in_month == 10 || in_month == 12) |-> (in_day <= 31) );
endproperty
assert property (p_date_check) else begin $display("Assertion 8 is violated"); $fatal; end

// 9. The AR_VALID signal should not overlap with the AW_VALID signal.
property p_axi_overlap;
    @(posedge clk) not (inf.AR_VALID && inf.AW_VALID);
endproperty
assert property (p_axi_overlap) else begin $display("Assertion 9 is violated"); $fatal; end

endmodule
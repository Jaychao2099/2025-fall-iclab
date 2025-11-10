clear -all 

set_proofgrid_max_local_jobs 10
check_sec -analyze -sv -both ../EXERCISE/01_RTL/GATED_OR.v
check_sec -analyze -sv -both ../EXERCISE/01_RTL/SAD.v 
check_sec -analyze -sv -both checker_only1f.sv 
check_sec -elaborate -both  -top SAD -disable_auto_bbox
check_sec -setup

clock clk -both_edge 
reset ~rst_n

#CDNS added
assume -name T_const {T==1 || T==4 || T==8}
assume -name in_valid_keep_192 {bind_checker_only1f.in_valid_keep |-> in_valid}
assume -name in_valid_invalid_after_192 {bind_checker_only1f.in_valid_forbidden |-> !in_valid}

check_sec -gen
check_sec -interface

assume cg_en==0
assume SAD_imp.cg_en==1
check_sec -waive -waive_signals cg_en
check_sec -waive -waive_signals SAD_imp.cg_en

check_sec -interface


# set_sec_autoprove_strategy design_style
# set_sec_autoprove_design_style_type clock_gating
set_sec_autoprove_strategy clock_gating


check_sec -prove -bg

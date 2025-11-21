// `include "../00_TESTBED/pseudo_DRAM.sv"
`include "Usertype.sv"

program automatic PATTERN(input clk, INF.PATTERN inf);
import usertype::*;
//================================================================
// parameters & integer
//================================================================
parameter DRAM_p_r = "../00_TESTBED/DRAM/dram.dat";
parameter MAX_CYCLE=1000;

//================================================================
// wire & registers 
//================================================================
logic [7:0] golden_DRAM [((65536+12*256)-1):(65536+0)];  

//================================================================
// class random
//================================================================

/**
 * Class representing a random action.
 */
class random_act;
    randc Action act_id;
    constraint range{
        act_id inside{Login, Level_Up, Battle, Use_Skill, Check_Inactive};
    }
endclass


endprogram
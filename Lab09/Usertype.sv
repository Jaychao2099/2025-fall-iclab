`ifndef USERTYPE
`define USERTYPE

package usertype;

typedef enum logic  [2:0] { Login	        = 3'd0,
                            Level_Up	    = 3'd1,
							Battle          = 3'd2,
                            Use_Skill       = 3'd3,
                            Check_Inactive  = 3'd4
							}  Action ;

typedef enum logic  [2:0] { No_Warn       		    = 3'b000, 
                            Date_Warn               = 3'b001, 
							Exp_Warn                = 3'b010,
                            HP_Warn                 = 3'b011,
                            MP_Warn                 = 3'b100,
                            Saturation_Warn         = 3'b101 
                            }  Warn_Msg ;

typedef enum logic  [1:0] { Type_A = 2'd0,
							Type_B = 2'd1,
							Type_C = 2'd2,
							Type_D = 2'd3
                            }  Training_Type; 

typedef enum logic  [1:0]	{ Easy  = 2'b00,
							  Normal  = 2'b01,
							  Hard  = 2'b10
                            } Mode ;

typedef logic [15:0] Attribute; //Flowers
typedef logic [3:0] Month;
typedef logic [4:0] Day;
typedef logic [7:0] Player_No;

typedef struct packed {
    Month M;
    Day D;
} Date;

// in DRAM
typedef struct packed {
    Attribute Exp;
    Attribute MP;
    Attribute HP;
    Attribute Attack;
    Attribute Defense;
    Month M;
    Day D;
} Player_Info;

// input
typedef union packed{ 
    Action [47:0] d_act;  // 3
    Training_Type [71:0] d_type;  // 2
    Mode [71:0] d_mode;  // 2
    Date [15:0] d_date;  // 9
    Player_No [17:0] d_player_no;  // 8
    Attribute [8:0] d_attribute;  // 16
} Data; //144

//################################################## Don't revise the code above

//#################################
// Type your user define type here
//#################################

// store input
typedef struct packed {
    Action act;
    Player_No player;
    Training_Type training_type;
    Mode mode;
    Date today;
    // monster
    Attribute m_attack;
    Attribute m_defense;
    Attribute m_HP;
    // for use skill
    Attribute MP_consumed [0:3];
} This_run_info;

typedef struct packed {
    Attribute element;      // MSB
    logic [1:0] stable_idx; // LSB
} sorting_element;


//################################################## Don't revise the code below
endpackage

import usertype::*; //import usertype into $unit

`endif
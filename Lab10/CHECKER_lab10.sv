`include "Usertype.sv"
module Checker(input clk, INF.CHECKER inf);
import usertype::*;


class Type_and_mode;
    Training_Type f_type;
    Mode f_mode;
endclass

Type_and_mode fm_info = new();



endmodule
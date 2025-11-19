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
//==============================================//
//              logic declaration               //
// ============================================ //

// input
// sel_action_valid    1  pattern  High when input means select the action. 
// type_valid          1  pattern  High when input means type of training. 
// mode_valid          1  pattern  High when input means the mode. 
// date_valid          1  pattern  High when input means today’s date. 
// player_no_valid     1  pattern  High when input means the number of  player. 
// monster_valid       1  pattern  High  when  input  means  the  attributes  of  the monster. (Will pull HIGH 3 times for monster’s attack, monster’s defense, and monster’s HP)
// MP_valid            1  pattern  High  when  input  means  the  list  of  the  MP consumed by the skill (Will pull HIGH 4 times for 4 skills) 
// D[143:0]          144  pattern  Represents the contents of the current input. 
//                                     = {141’bX, Action} (inf.D.d_act [0]) 
//                                     = {142’bX, Training_Type} (inf.D.d_type[0]) 
//                                     = {142’bX, Mode} (inf.D.d_mode[0]) 
//                                     = {135’bX, Month[3:0], Day[4:0]} (inf.D. d_date[0]) 
//                                     = {136’bX, Player No.} (inf.D.d_player_no[0]) 
//                                     = {128’bX, Moster_attributes} (ins.D.d_attribute[0]) 
//                                     = {128’bX, Comsumed_MP}(inf.D. d_attribute[0] 
// AR_READY            1  DRAM     AXI Lite signal 
// R_VALID             1  DRAM     AXI Lite signal 
// R_DATA             96  DRAM     AXI Lite signal 
// R_RESP              2  DRAM     AXI Lite signal 
// AW_READY            1  DRAM     AXI Lite signal 
// W_READY             1  DRAM     AXI Lite signal 
// B_VALID             1  DRAM     AXI Lite signal 
// B_RESP              2  DRAM     AXI Lite signal 

// // output
// out_valid           1  pattern Should set to high when your output is ready. out_valid will be high for only one cycle. 
// warn_msg            3  pattern warn_msg will be 3’b000 (No warn) if operation is  complete,  else  it  needs  to  be  corresponding value. 
// complete            1  pattern 1’b1: operation complete 1’b0: some warning occurred 
// AR_VALID            1  DRAM     AXI Lite signal 
// AR_ADDR            17  DRAM     AXI Lite signal 
// R_READY             1  DRAM     AXI Lite signal 
// AW_VALID            1  DRAM     AXI Lite signal 
// AW_ADDR            17  DRAM     AXI Lite signal 
// W_VALID             1  DRAM     AXI Lite signal 
// W_DATA             96  DRAM     AXI Lite signal 
// B_READY             1  DRAM     AXI Lite signal 


endmodule
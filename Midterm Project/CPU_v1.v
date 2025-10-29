//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   (C) Copyright Laboratory System Integration and Silicon Implementation
//   All Right Reserved
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   ICLAB 2021 Final Project: Customized ISA Processor 
//   Author              : Hsi-Hao Huang
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   File Name   : CPU.v
//   Module Name : CPU.v
//   Release version : V1.0 (Release Date: 2021-May)
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

module CPU(

				clk,
			  rst_n,
  
		   IO_stall,

         awid_m_inf,
       awaddr_m_inf,
       awsize_m_inf,
      awburst_m_inf,
        awlen_m_inf,
      awvalid_m_inf,
      awready_m_inf,
                    
        wdata_m_inf,
        wlast_m_inf,
       wvalid_m_inf,
       wready_m_inf,
                    
          bid_m_inf,
        bresp_m_inf,
       bvalid_m_inf,
       bready_m_inf,
                    
         arid_m_inf,
       araddr_m_inf,
        arlen_m_inf,
       arsize_m_inf,
      arburst_m_inf,
      arvalid_m_inf,
                    
      arready_m_inf, 
          rid_m_inf,
        rdata_m_inf,
        rresp_m_inf,
        rlast_m_inf,
       rvalid_m_inf,
       rready_m_inf 

);
// Input port
input  wire clk, rst_n;
// Output port
output reg  IO_stall;   //  should be low for one cycle whenever finished an instruction

parameter ID_WIDTH = 4 , ADDR_WIDTH = 32, DATA_WIDTH = 16, DRAM_NUMBER=2, WRIT_NUMBER=1;

// AXI Interface wire connecttion for pseudo DRAM read/write
/* Hint:
  your AXI-4 interface could be designed as convertor in submodule(which used reg for output signal),
  therefore I declared output of AXI as wire in CPU
*/



// axi write address channel 
output  wire [WRIT_NUMBER * ID_WIDTH-1:0]        awid_m_inf;    // Write address ID
output  wire [WRIT_NUMBER * ADDR_WIDTH-1:0]    awaddr_m_inf;    // Write address 32-bit. the address of the first transfer in a write burst tx
output  wire [WRIT_NUMBER * 3 -1:0]            awsize_m_inf;    // Burst size. only (3'b001)
output  wire [WRIT_NUMBER * 2 -1:0]           awburst_m_inf;    // Burst type. only INCR(2’b01)
output  wire [WRIT_NUMBER * 7 -1:0]             awlen_m_inf;    // Burst length
output  wire [WRIT_NUMBER-1:0]                awvalid_m_inf;    // Write address valid, stay stable until AWREADY goes HIGH.
input   wire [WRIT_NUMBER-1:0]                awready_m_inf;    // Write address ready. DRAM is ready to accept signals
// axi write data channel 
output  wire [WRIT_NUMBER * DATA_WIDTH-1:0]     wdata_m_inf;    // Write data. 16-bit
output  wire [WRIT_NUMBER-1:0]                  wlast_m_inf;    // Write last. high means current transfer is the last write burst.
output  wire [WRIT_NUMBER-1:0]                 wvalid_m_inf;    // Write valid. write data and strobes available
input   wire [WRIT_NUMBER-1:0]                 wready_m_inf;    // Write ready. DRAM is ready to accept the write data
// axi write response channel
input   wire [WRIT_NUMBER * ID_WIDTH-1:0]         bid_m_inf;    // Response ID. must match the AWID value
input   wire [WRIT_NUMBER * 2 -1:0]             bresp_m_inf;    // Write response. only OKAY(2’b00)
input   wire [WRIT_NUMBER-1:0]             	   bvalid_m_inf;    // Write response valid. means a valid write response is available
output  wire [WRIT_NUMBER-1:0]                 bready_m_inf;    // Response ready. CPU can accept the response information
// -----------------------------
// axi read address channel 
output  wire [DRAM_NUMBER * ID_WIDTH-1:0]       arid_m_inf;    // Read address ID. 
output  wire [DRAM_NUMBER * ADDR_WIDTH-1:0]   araddr_m_inf;    // Read address. 32-bit * 2. address of the first transfer in a read burst tx. high = inst, low = data
output  wire [DRAM_NUMBER * 7 -1:0]            arlen_m_inf;    // Burst length.
output  wire [DRAM_NUMBER * 3 -1:0]           arsize_m_inf;    // Burst size. This signal indicates the size of each transfer in the burst. only (3'b001)
output  wire [DRAM_NUMBER * 2 -1:0]          arburst_m_inf;    // Burst type. only INCR(2'b01)
output  wire [DRAM_NUMBER-1:0]               arvalid_m_inf;    // Read address valid, stay stable until ARREADY goes HIGH.
input   wire [DRAM_NUMBER-1:0]               arready_m_inf;    // Read address ready. DRAM is ready to accept signals
// -----------------------------
// axi read data channel 
input   wire [DRAM_NUMBER * ID_WIDTH-1:0]         rid_m_inf;    // Read ID tag. must match the ARID value
input   wire [DRAM_NUMBER * DATA_WIDTH-1:0]     rdata_m_inf;    // Read data. 16-bit
input   wire [DRAM_NUMBER * 2 -1:0]             rresp_m_inf;    // Read response.  only OKAY(2'b00)
input   wire [DRAM_NUMBER-1:0]                  rlast_m_inf;    // Read last. high means current transfer is the last transfer in a read burst.
input   wire [DRAM_NUMBER-1:0]                 rvalid_m_inf;    // Read valid.  read data available
output  wire [DRAM_NUMBER-1:0]                 rready_m_inf;    // Read ready. DRAM can accept the read data and response information
// -----------------------------

//
//
// 
/* Register in each core:
  There are sixteen registers in your CPU. You should not change the name of those registers.
  TA will check the value in each register when your core is not busy.
  If you change the name of registers below, you must get the fail in this lab.
*/

reg signed [15:0] core_r0 , core_r1 , core_r2 , core_r3 ;
reg signed [15:0] core_r4 , core_r5 , core_r6 , core_r7 ;
reg signed [15:0] core_r8 , core_r9 , core_r10, core_r11;
reg signed [15:0] core_r12, core_r13, core_r14, core_r15;


//####################################################
//               reg & wire
//####################################################



//###########################################
//
// Wrtie down your design below
//
//###########################################















endmodule




















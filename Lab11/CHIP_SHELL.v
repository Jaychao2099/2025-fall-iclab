// ##############################################################
//   You can modify by your own
//   You can modify by your own
//   You can modify by your own
// ##############################################################

module CHIP(
    // input signals
    clk,
    rst_n,
	
    in_valid_data,
	data,
	
    in_valid_cmd,
    cmd,    
	
    // output signals
    busy
);

input            clk;
input            rst_n;
		  
input            in_valid_data;
input     [7:0]  data;
		  
input            in_valid_cmd;
input    [17:0]  cmd;
		  
output           busy;

//==================================================================
// reg & wire
//==================================================================
wire             C_clk;
wire             C_rst_n;

wire             C_in_valid_data;
wire      [7:0]  C_data;

wire             C_in_valid_cmd;
wire     [17:0]  C_cmd;

wire             C_busy;

//==================================================================
// CORE
//==================================================================
GTE CORE(
	// input signals
	.clk(C_clk),
	.rst_n(C_rst_n),

	.in_valid_data(C_in_valid_data),
	.data(C_data),

	.in_valid_cmd(C_in_valid_cmd),
	.cmd(C_cmd),

	// output signals
	.busy(C_busy)
);

//==================================================================
// INPUT PAD: XMD
// Syntax: XMD PAD_NAME ( .O(CORE_PORT_NAME), .I(CHIP_PORT_NAME), .PU(1'b0), .PD(1'b0), .SMT(1'b0));
//     Ex: XMD    I_CLK ( .O(C_clk),          .I(clk),            .PU(1'b0), .PD(1'b0), .SMT(1'b0));
//==================================================================
// You need to finish this part



//==================================================================
// OUTPUT PAD: YA2GSD
// Syntax: YA2GSD PAD_NAME (.I(CORE_PIN_NAME), .O(PAD_PIN_NAME), .E(1'b1), .E2(1'b1), .E4(1'b1), .E8(1'b0), .SR(1'b0));
//     Ex: YA2GSD  O_VALID (.I(C_out_valid),   .O(out_valid),    .E(1'b1), .E2(1'b1), .E4(1'b1), .E8(1'b0), .SR(1'b0));
//==================================================================
// You need to finish this part


//==================================================================
// I/O power 3.3V pads: VCC3IOD/GNDIOD 
// Syntax: VCC3IOD/GNDIOD PAD_NAME ();
//    Ex1: VCC3IOD        VDDP0 ();
//    Ex2: GNDIOD         GNDP0 ();
//==================================================================
// You need to finish this part


//==================================================================
// Core power 1.8V pads: VCCKD/GNDKD
// Syntax: VCCKD/GNDKD PAD_NAME ();
//    Ex1: VCCKD       VDDC0 ();
//    Ex2: GNDKD       GNDC0 ();
//==================================================================
// You need to finish this part


endmodule


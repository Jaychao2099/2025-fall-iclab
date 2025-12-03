// ##############################################################
//   You can modify by your own
//   You can modify by your own
//   You can modify by your own
// ##############################################################

module CHIP(
	// input signals
	clk,
	rst_n,
	in_valid,
	delay,
	source,
	destination,
	// output signals
	out_valid,
	worst_delay,
	path
);

input         clk, rst_n, in_valid;
input  [3:0]  delay;
input  [3:0]  source;
input  [3:0]  destination;

output        out_valid;
output [7:0]  worst_delay;
output [3:0]  path;

//==================================================================
// reg & wire
//==================================================================
wire        C_clk, C_rst_n, C_in_valid;
wire [3:0]  C_delay;
wire [3:0]  C_source;
wire [3:0]  C_destination;

wire        C_out_valid;
wire [7:0]  C_worst_delay;
wire [3:0]  C_path;

//==================================================================
// CORE
//==================================================================
STA CORE(
	// input signals
    .clk(C_clk),
    .rst_n(C_rst_n),
    .in_valid(C_in_valid),
    .delay(C_delay),
    .source(C_source),
    .destination(C_destination),
	
    // output signals
    .out_valid(C_out_valid),
    .worst_delay(C_worst_delay),
    .path(C_path)
);

//==================================================================
// INPUT PAD
// Syntax: XMD PAD_NAME ( .O(CORE_PORT_NAME), .I(CHIP_PORT_NAME), .PU(1'b0), .PD(1'b0), .SMT(1'b0));
//     Ex: XMD    I_CLK ( .O(C_clk),          .I(clk),            .PU(1'b0), .PD(1'b0), .SMT(1'b0));
//==================================================================
// You need to finish this part

//==================================================================
// OUTPUT PAD
// Syntax: YA2GSD PAD_NAME (.I(CORE_PIN_NAME), .O(PAD_PIN_NAME), .E(1'b1), .E2(1'b1), .E4(1'b1), .E8(1'b0), .SR(1'b0));
//     Ex: YA2GSD  O_VALID (.I(C_out_valid),   .O(out_valid),    .E(1'b1), .E2(1'b1), .E4(1'b1), .E8(1'b0), .SR(1'b0));
//==================================================================
// You need to finish this part

//==================================================================
// I/O power 3.3V pads x? (DVDD + DGND)
// Syntax: VCC3IOD/GNDIOD PAD_NAME ();
//    Ex1: VCC3IOD        VDDP0 ();
//    Ex2: GNDIOD         GNDP0 ();
//==================================================================
// You need to finish this part

//==================================================================
// Core power 1.8V pads x? (VDD + GND)
// Syntax: VCCKD/GNDKD PAD_NAME ();
//    Ex1: VCCKD       VDDC0 ();
//    Ex2: GNDKD       GNDC0 ();
//==================================================================
// You need to finish this part

endmodule


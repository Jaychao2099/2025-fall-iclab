`define CYCLE_TIME  20.0

module PATTERN(
    // output signals
    clk,
    rst_n,
    in_valid_data,
    in_valid_param,
    
    data,
	index,
	mode,
    QP,
	
    // input signals
    out_valid,
    out_value
);

// ========================================
// I/O declaration
// ========================================
// Output
output reg          clk;
output reg          rst_n;
output reg          in_valid_data;
output reg          in_valid_param;

output reg    [7:0] data;
output reg    [3:0] index;
output reg          mode;
output reg    [4:0] QP;

// Input
input               out_valid;
input signed [31:0] out_value;

// ========================================
// clock
// ========================================
real CYCLE = `CYCLE_TIME;
always	#(CYCLE/2.0) clk = ~clk; //clock

// ========================================
// integer & parameter
// ========================================


// ========================================
// wire & reg
// ========================================



//================================================================
// design
//================================================================



endmodule




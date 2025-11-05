/**************************************************************************
 * Copyright (c) 2025, OASIS Lab
 * MODULE: PATTERN
 * FILE NAME: PATTERN.v
 * VERSRION: 1.0
 * DATE: Oct 29, 2025
 * AUTHOR: Chao-En Kuo, NYCU IAIS
 * DESCRIPTION: ICLAB2025FALL / LAB7 / PATTERN
 * MODIFICATION HISTORY:
 * Date                 Description
 * 
 *************************************************************************/
`ifdef RTL
	`define CYCLE_TIME_clk1 14.1
	`define CYCLE_TIME_clk2 10.1
	`define CYCLE_TIME_clk3 20.7
	// `define CYCLE_TIME_clk3 11.1
	// `define CYCLE_TIME_clk3 4.1
	// `define CYCLE_TIME_clk3 3.1
`endif
`ifdef GATE
	`define CYCLE_TIME_clk1 14.1
	`define CYCLE_TIME_clk2 10.1
	`define CYCLE_TIME_clk3 20.7
`endif

module PATTERN(
	clk1,
	clk2,
	clk3,
	rst_n,
	in_valid,
	in_data,
	out_valid,
	out_data
);

//---------------------------------------------------------------------
//   PORT DECLARATION          
//---------------------------------------------------------------------
output reg        clk1, clk2, clk3;
output reg        rst_n;
output reg        in_valid;
output reg [31:0] in_data;

input             out_valid;
input      [15:0] out_data;


//---------------------------------------------------------------------
//   PARAMETER & INTEGER
//---------------------------------------------------------------------
// Verification Control Parameters
parameter PAT_NUM       = 1000;                // Number of patterns to test
parameter RANDOM_MODE   = 1;                   // 0 = "FIXED", 1 = "RANDOM"
parameter SEED          = 42069;               // Seed for "FIXED" mode
parameter MAX_LATENCY   = 5000;                // Maximum latency allowed by spec before timeout

// Cycle Time
real	CYCLE_clk1 = `CYCLE_TIME_clk1;
real	CYCLE_clk2 = `CYCLE_TIME_clk2;
real	CYCLE_clk3 = `CYCLE_TIME_clk3;

// Internal Variables
integer total_latency;
integer latency;
integer i_pat;
integer i, j;

//---------------------------------------------------------------------
//   REG & WIRE & GOLDEN MODEL DATA
//---------------------------------------------------------------------
reg [15:0]  golden_array[127:0]; // Used for both input generation and storing golden output
reg [3:0]   coeffs_per_cycle[7:0];
reg [13:0]  GMb[0:127]; // Twiddle factors from C model

//---------------------------------------------------------------------
//  CLOCK
//---------------------------------------------------------------------
initial begin
    clk1 = 1'b0;
    clk2 = 1'b0;
    clk3 = 1'b0;
end

always #(CYCLE_clk1/2.0) clk1 = ~clk1;
always #(CYCLE_clk2/2.0) clk2 = ~clk2;
always #(CYCLE_clk3/2.0) clk3 = ~clk3;

//---------------------------------------------------------------------
//  BEHAVIORAL GOLDEN MODEL (from NTT_test.c)
//---------------------------------------------------------------------

// Initialize the GMb twiddle factor table
initial begin
    GMb[0] = 4091;  GMb[1] = 7888;  GMb[2] = 11060; GMb[3] = 11208;
    GMb[4] = 6960;  GMb[5] = 4342;  GMb[6] = 6275;  GMb[7] = 9759;
    GMb[8] = 1591;  GMb[9] = 6399;  GMb[10] = 9477; GMb[11] = 5266;
    GMb[12] = 586;  GMb[13] = 5825; GMb[14] = 7538; GMb[15] = 9710;
    GMb[16] = 1134; GMb[17] = 6407; GMb[18] = 1711; GMb[19] = 965;
    GMb[20] = 7099; GMb[21] = 7674; GMb[22] = 3743; GMb[23] = 6442;
    GMb[24] = 10414;GMb[25] = 8100;  GMb[26] = 1885; GMb[27] = 1688;
    GMb[28] = 1364; GMb[29] = 10329;GMb[30] = 10164;GMb[31] = 9180;
    GMb[32] = 12210;GMb[33] = 6240;  GMb[34] = 997;  GMb[35] = 117;
    GMb[36] = 4783; GMb[37] = 4407; GMb[38] = 1549; GMb[39] = 7072;
    GMb[40] = 2829; GMb[41] = 6458; GMb[42] = 4431; GMb[43] = 8877;
    GMb[44] = 7144; GMb[45] = 2564; GMb[46] = 5664; GMb[47] = 4042;
    GMb[48] = 12189;GMb[49] = 432;   GMb[50] = 10751;GMb[51] = 1237;
    GMb[52] = 7610; GMb[53] = 1534; GMb[54] = 3983; GMb[55] = 7863;
    GMb[56] = 2181; GMb[57] = 6308; GMb[58] = 8720; GMb[59] = 6570;
    GMb[60] = 4843; GMb[61] = 1690; GMb[62] = 14;    GMb[63] = 3872;
    GMb[64] = 5569; GMb[65] = 9368; GMb[66] = 12163;GMb[67] = 2019;
    GMb[68] = 7543; GMb[69] = 2315; GMb[70] = 4673; GMb[71] = 7340;
    GMb[72] = 1553; GMb[73] = 1156; GMb[74] = 8401; GMb[75] = 11389;
    GMb[76] = 1020; GMb[77] = 2967; GMb[78] = 10772;GMb[79] = 7045;
    GMb[80] = 3316; GMb[81] = 11236;GMb[82] = 5285; GMb[83] = 11578;
    GMb[84] = 10637;GMb[85] = 10086;GMb[86] = 9493; GMb[87] = 6180;
    GMb[88] = 9277; GMb[89] = 6130; GMb[90] = 3323; GMb[91] = 883;
    GMb[92] = 10469;GMb[93] = 489;   GMb[94] = 1502; GMb[95] = 2851;
    GMb[96] = 11061;GMb[97] = 9729; GMb[98] = 2742; GMb[99] = 12241;
    GMb[100] = 4970;GMb[101] = 10481;GMb[102] = 10078;GMb[103] = 1195;
    GMb[104] = 730; GMb[105] = 1762; GMb[106] = 3854;GMb[107] = 2030;
    GMb[108] = 5892;GMb[109] = 10922;GMb[110] = 9020;GMb[111] = 5274;
    GMb[112] = 9179;GMb[113] = 3604; GMb[114] = 3782;GMb[115] = 10206;
    GMb[116] = 3180;GMb[117] = 3467; GMb[118] = 4668;GMb[119] = 2446;
    GMb[120] = 7613;GMb[121] = 9386; GMb[122] = 834; GMb[123] = 7703;
    GMb[124] = 6836;GMb[125] = 3403; GMb[126] = 5351;GMb[127] = 12276;
end

// Golden model for Montgomery multiplication
function [13:0] modq_mul(input [15:0] a, input [13:0] b);
    // Use integer for wider intermediate products to prevent overflow
    integer Q   = 12289;
    integer Q0I = 12287;
    integer x, y, z;
    reg [31:0] R;
    begin
        R = 65536;
        x = a * b;
        y = (x * Q0I) % R;
        z = (x + y * Q) / R;
        modq_mul = (z >= Q) ? (z - Q) : z;
    end
endfunction

// Golden model for NTT calculation
task NTT_golden_model;
    inout [15:0] array[0:127]; // Use inout to modify the array in place
    integer m, ht, i, j_1, j;
    reg [13:0] s;
    reg [15:0] u;
    reg [13:0] v;
    integer Q = 12289;
    begin
        for (m = 1, ht = 64; m < 128; m = m << 1, ht = ht >> 1) begin
            for (i = 0, j_1 = 0; i < m; i = i + 1, j_1 = j_1 + (ht << 1)) begin
                s = GMb[m+i];
                for (j = j_1; j < j_1 + ht; j = j + 1) begin
                    u = array[j];
                    v = modq_mul(array[j + ht], s);
                    array[j]      = (u + v) % Q;
                    array[j + ht] = (u >= v) ? (u - v) : ((u + Q) - v);
                end
            end
        end
    end
endtask


//---------------------------------------------------------------------
//  MAIN SIMULATION FLOW
//---------------------------------------------------------------------
initial begin
    reset_task;
    
    // Seed the random number generator based on the selected mode
    if (RANDOM_MODE == 1) begin
        void'($urandom(SEED));
        $display("\033[33mRANDOM mode (seed = %0d).\033[0m", SEED);
    end else begin
        $display("\033[33mFIXED mode (seed = %0d).\033[0m", SEED);
    end

    total_latency = 0;
	$display("\033[33mStart!!, Total patterns = %d\033[0m", PAT_NUM);
    
    for (i_pat = 0; i_pat < PAT_NUM; i_pat = i_pat + 1) begin
        generate_and_drive_input_task(golden_array);
        NTT_golden_model(golden_array); // Calculate expected result
        wait_and_check_output_task(golden_array);

        total_latency = total_latency + latency;
        $display("\033[32mPASS PATTERN NO.%4d, Latency: %4d clk3 cycles\033[0m", i_pat, latency);

        // Add random timing jitter between patterns
        repeat($urandom_range(1, 3)) @(negedge clk1);
    end

    YOU_PASS_task;
end

//---------------------------------------------------------------------
//  TASKS
//---------------------------------------------------------------------
task reset_task;
begin
    rst_n    = 1'b1;
    in_valid = 1'b0;
    in_data  = 32'hxxxxxxxx;

    force clk1 = 1'b0;
    force clk2 = 1'b0;
    force clk3 = 1'b0;
    #1;
    rst_n = 1'b0;
    #(100);

    // Protocol Assertion: Check if outputs are reset to 0
    if (out_valid !== 1'b0 || out_data !== 16'b0) begin
        $display("\033[31mSPEC FAIL: Outputs did not reset to 0 after initial reset.\033[0m");
        YOU_FAIL_task;
        repeat(2) @(negedge clk3);
        $finish;
    end

    #10;
    rst_n = 1'b1;
	#10;
    release clk1;
    release clk2;
    release clk3;
    @(negedge clk1);
end
endtask

task generate_and_drive_input_task;
    output [15:0] array_out[0:127];
begin
    // Generate 128 random 4-bit coefficients
    for (i = 0; i < 128; i = i + 1) begin
        array_out[i] = $urandom_range(15, 0);
    end

    // // Add random timing jitter before sending data
    // repeat($urandom_range(1, 3)) @(negedge clk1);
    
    in_valid = 1'b1;
    // Drive inputs for 16 cycles
    for (i = 0; i < 16; i = i + 1) begin
        // Pack 8 4-bit coefficients into in_data
        for (j = 0; j < 8; j = j + 1) begin
            coeffs_per_cycle[j] = array_out[i*8 + j][3:0];
        end
        in_data = {
            coeffs_per_cycle[7], coeffs_per_cycle[6],
            coeffs_per_cycle[5], coeffs_per_cycle[4],
            coeffs_per_cycle[3], coeffs_per_cycle[2],
            coeffs_per_cycle[1], coeffs_per_cycle[0]
        };
        @(negedge clk1);
    end
    in_valid = 1'b0;
    in_data = 32'hxxxxxxxx;
end
endtask

task wait_and_check_output_task;
    input [15:0] golden_data[0:127];
    integer output_counter;
begin
    latency = 0;
    output_counter = 0;
    
    while (in_valid);

    while (output_counter < 128) begin
        latency = latency + 1;

        if (latency > MAX_LATENCY) begin
            $display("\033[31mSPEC FAIL: Latency timeout. Waited for more than %d cycles.\033[0m", MAX_LATENCY);
            $display("\033[31m           Only received %d out of 128 expected outputs for pattern %d.\033[0m", output_counter, i_pat);
            YOU_FAIL_task;
            $finish;
        end

        if (out_valid === 1'b1) begin
            if (out_data !== golden_data[output_counter]) begin
                $display("\033[31mDATA MISMATCH on PATTERN %d, output number #%d\033[0m", i_pat, output_counter);
                $display("\033[31m  >> Golden Result: %d\033[0m", golden_data[output_counter]);
                $display("\033[31m  >> Your   Result: %d\033[0m", out_data);
                YOU_FAIL_task;
                $finish;
            end
            output_counter = output_counter + 1;
        end
        
        @(negedge clk3);
    end
end
endtask

task YOU_FAIL_task;
begin
	$display("\033[31m \033[5m     //   / /     //   ) )     //   ) )     //   ) )     //   ) )\033[0m");
    $display("\033[31m \033[5m    //____       //___/ /     //___/ /     //   / /     //___/ /\033[0m");
    $display("\033[31m \033[5m   / ____       / ___ (      / ___ (      //   / /     / ___ (\033[0m");
    $display("\033[31m \033[5m  //           //   | |     //   | |     //   / /     //   | |\033[0m");
    $display("\033[31m \033[5m //____/ /    //    | |    //    | |    ((___/ /     //    | |\033[0m");
    $finish;
end
endtask

task YOU_PASS_task;
begin
    $display("\033[0;32m \033[5m    //   ) )     // | |     //   ) )     //   ) )\033[m");
    $display("\033[0;32m \033[5m   //___/ /     //__| |    ((           ((\033[m");
    $display("\033[0;32m \033[5m  / ____ /     / ___  |      \\           \\\033[m");
    $display("\033[0;32m \033[5m //           //    | |        ) )          ) )\033[m");
    $display("\033[0;32m \033[5m//           //     | | ((___ / /    ((___ / /\033[m");
    $display("*************************************************************************");
    $display("*                         Congratulations!                              *");
    $display("*                Total execution latency = %5d clk3 cycles              *", total_latency);
    $display("*                Your clock period (clk3) = %.1f ns                     *", CYCLE_clk3);
    $display("*                Total Latency = %.1f ns                                *", total_latency*CYCLE_clk3);
    $display("*************************************************************************");
    $finish;
end
endtask

always @(negedge clk3) begin
	if(out_valid == 1'b0) begin
		if(out_data !==0) begin
			$display("\033[31m SPEC FAIL: out_data must be 0 when out_valid is low.\033[0m");
            YOU_FAIL_task;
			$finish;
		end
	end
end

always @(*) begin
	if(out_valid == 1'b1) begin
		if(in_valid == 1'b1) begin
			$display("\033[31m SPEC FAIL: out_valid and in_valid cannot be high simultaneously.\033[0m");
            YOU_FAIL_task;
			$finish;
		end
	end
end

endmodule
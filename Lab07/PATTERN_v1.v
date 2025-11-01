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
real	CYCLE_clk1 = `CYCLE_TIME_clk1;
real	CYCLE_clk2 = `CYCLE_TIME_clk2;
real	CYCLE_clk3 = `CYCLE_TIME_clk3;

integer total_latency;
integer latency;
integer i_pat, PAT_NUM;
integer in_fd, out_fd;
integer i, j;
integer temp_val;
integer file_golden_output;

// Maximum latency allowed by spec before timeout
parameter MAX_LATENCY = 5000;

//---------------------------------------------------------------------
//   REG & WIRE
//---------------------------------------------------------------------
reg [15:0]  current_input[127:0];
reg [15:0]  golden_output;
reg [3:0]   coeffs_per_cycle[7:0];

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
//  MAIN SIMULATION FLOW
//---------------------------------------------------------------------
initial begin
    // Open golden files
    in_fd = $fopen("../00_TESTBED/NTT_in.txt", "r");
    out_fd = $fopen("../00_TESTBED/NTT_out.txt", "r");
    if (in_fd === 0 || out_fd === 0) begin
        $display("FATAL ERROR: Could not open input/output files.");
        $finish;
    end
    reset_task;
    temp_val = $fscanf(in_fd, "%d\n", PAT_NUM);
    total_latency = 0;
	$display(" Start!!, Total patterns = %d", PAT_NUM);
    for (i_pat = 0; i_pat < PAT_NUM; i_pat = i_pat + 1) begin
        read_and_drive_input_task;
        wait_and_check_output_task;

        total_latency = total_latency + latency;
        $display("PASS PATTERN NO.%4d, Latency: %4d clk3 cycles", i_pat, latency);

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
    #1;

    // Protocol Assertion: Check if outputs are reset to 0
    if (out_valid !== 1'b0 || out_data !== 16'b0) begin
        $display("SPEC FAIL: Outputs did not reset to 0 after initial reset.");
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
end
endtask

task read_and_drive_input_task;
begin
    // Read 128 coefficients for the current pattern for later use in error messages
    for (i = 0; i < 128; i = i + 1) begin
        temp_val = $fscanf(in_fd, "%d\n", current_input[i]);
    end
    // Skip the blank line between patterns
    temp_val = $fscanf(in_fd, "\n");

    repeat(2) @(negedge clk1);
    in_valid = 1'b1;
    // Drive inputs for 16 cycles
    for (i = 0; i < 16; i = i + 1) begin
        // Pack 8 4-bit coefficients into in_data
        for (j = 0; j < 8; j = j + 1) begin
            coeffs_per_cycle[j] = current_input[i*8 + j][3:0];
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
    $display("Read file done.");
end
endtask

task wait_and_check_output_task;
begin
    latency = 0;
    
    // Start measuring latency from the falling edge of in_valid
    while (in_valid);

    // Wait for the first out_valid
    while (out_valid !== 1'b1) begin
        latency = latency + 1;
        // Timing Assertion: Check for latency timeout
        if (latency > MAX_LATENCY) begin
            $display("SPEC FAIL: Latency timeout. Waited for more than %d cycles.", MAX_LATENCY);
            YOU_FAIL_task;
            $finish;
        end
        @(negedge clk3);
    end

    // Check all 128 output data points
    for (i = 0; i < 128; i = i + 1) begin
        // Protocol Assertion: out_valid must stay high for 128 cycles
        if (out_valid !== 1'b1) begin
            $display("SPEC FAIL: out_valid dropped before 128 cycles were complete.");
            YOU_FAIL_task;
            $finish;
        end
        
        temp_val = $fscanf(out_fd, "%d\n", golden_output);

        if (out_data !== golden_output) begin
            $display("DATA MISMATCH on PATTERN %d, output index %d", i_pat, i);
            $display("  >> Golden Result: %d", golden_output);
            $display("  >> Your   Result: %d", out_data);
            YOU_FAIL_task;
            $finish;
        end
        
        latency = latency + 1; // Increment latency for each output cycle
        @(negedge clk3);
    end

    // The latency spec includes the falling edge of the final out_valid.
    // The loop has performed 128 `@(negedge clk3)`, placing us exactly at the falling edge.
    // No extra cycle count is needed.
    
    // Protocol Assertion: out_valid must go low after 128 cycles
    if (out_valid === 1'b1) begin
        $display("SPEC FAIL: out_valid was high for more than 128 cycles.");
        YOU_FAIL_task;
        $finish;
    end
    
    // Skip the blank line in the golden output file
    temp_val = $fscanf(out_fd, "\n");
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
    $display("*                Your execution cycles = %5d cycles          *", total_latency);
    $display("*                Your clock period = %.1f ns          *", CYCLE_clk3);
    $display("*                Total Latency = %.1f ns          *", total_latency*CYCLE_clk3);
    $display("*************************************************************************");
    $fclose(in_fd);
    $fclose(out_fd);
    $finish;
end
endtask


endmodule
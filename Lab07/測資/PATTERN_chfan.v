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
real	CYCLE_clk1 = `CYCLE_TIME_clk1;
real	CYCLE_clk2 = `CYCLE_TIME_clk2;
real	CYCLE_clk3 = `CYCLE_TIME_clk3;
integer total_latency;
integer local_latency;
integer PATNUM;
integer patcount;
integer input_file;
integer output_file;
integer i, j, k;

//---------------------------------------------------------------------
//   REG & WIRE
//---------------------------------------------------------------------
reg [3:0] temp_in_data [0:7];
reg [15:0] golden_ans, output_ans;

//---------------------------------------------------------------------
//  CLOCK
//---------------------------------------------------------------------
always #(CYCLE_clk1/2.0) clk1 = ~clk1;
always #(CYCLE_clk2/2.0) clk2 = ~clk2;
always #(CYCLE_clk3/2.0) clk3 = ~clk3;

//---------------------------------------------------------------------
//  INITIAL
//---------------------------------------------------------------------
initial begin
	input_file = $fopen("../00_TESTBED/input_1000.txt", "r");
    output_file = $fopen("../00_TESTBED/output_1000.txt", "r");

	reset_signal_task; //reset
	
    k = $fscanf(input_file, "%d\n", PATNUM);
	k = $fscanf(output_file, "%d\n", PATNUM); // read PATNUM from output file
	total_latency = 0;
	patcount = 0;

	$display(" Start!!, Total patterns = %d", PATNUM);
    @(negedge clk1);
	for(patcount=0; patcount<PATNUM; patcount=patcount+1) begin
		input_task;
		local_latency = 0;
        for(i=0; i<128; i=i+1) begin // The output should be raised for 128 cycles
			wait_out_valid_task;
			check_ans_task;
			local_latency = local_latency + 1; // from the falling edge of in_valid to the falling edge of the final out_valid signal
			// @(negedge clk3);
			if (i != 127) begin
				@(negedge clk3);
			end
			else begin
				@(negedge clk3);
				// @(posedge clk3);
			end
		end
        total_latency = total_latency + local_latency;
		$display ("\033[0;32mPass Pattern NO. %d, latency: %d\033[m         ", patcount, local_latency);
		repeat($urandom_range(1, 3)) @(negedge clk1); // The next input pattern will arrive 1~3 clk1 cycles
		// @(negedge clk1);
	end

	$fclose(input_file);
    $fclose(output_file);
	
	YOU_PASS_task;
	$finish;
end

//---------------------------------------------------------------------
//  TASK
//---------------------------------------------------------------------
task reset_signal_task; begin
	rst_n = 1'b1;
	in_valid = 1'b0;
	force clk1 = 1'b0;
    force clk2 = 1'b0;
    force clk3 = 1'b0;
	#(0.5);
	rst_n = 1'b0;
	#(100); // CHECK: All output signals should be reset after the reset signal is asserted. 
	if (out_valid !== 1'b0 || out_data !== 16'b0) begin
		$display(" RESET FAIL ");
        $display(" out_valid = %b, out_data = %h", out_valid, out_data);
        #(100);
		$finish;
	end
	#(10);
	rst_n = 1'b1;
	#(30);
	release clk1;
    release clk2;
    release clk3;
end endtask

task input_task; begin
    in_valid = 1'b1;
    for (i = 0; i < 16; i = i + 1) begin
        for (j = 0; j < 8; j = j + 1) begin
            k = $fscanf(input_file, "%d", temp_in_data[j]);
        end
        in_data = {temp_in_data[7], temp_in_data[6], temp_in_data[5], temp_in_data[4],
                   temp_in_data[3], temp_in_data[2], temp_in_data[1], temp_in_data[0]};
        @(negedge clk1); // Input data are synchronous to clk1
    end

	in_valid = 1'b0;
    in_data = 'bx;

end endtask

task wait_out_valid_task; begin
    // local_latency = 0;
    while(out_valid !== 1'b1) begin
        if(local_latency > 5000) begin // smaller than 5000 cycles in clk3
            $display("          Failed > 5000 cycles latency!          ");
            $finish;
        end
        local_latency = local_latency + 1;
        @(negedge clk3); // output data are synchronous to clk3
    end
end endtask

task check_ans_task; begin
    k = $fscanf(output_file, "%d", golden_ans);
    output_ans = out_data;

    // $display(" Your Answer   :   %d", output_ans);
    // $display(" Expected Answr:   %d", golden_ans);

    if (output_ans !== golden_ans) begin
        display_fail;
        $display("Error: Test case %d failed", patcount);
        $display("Expected Answer  :   %d", golden_ans);
        $display("Your Wrong Answer:   %d", output_ans);
        $finish;
    end
end endtask

task YOU_PASS_task; begin
    $display("*************************************************************************");
    $display("*                         Congratulations!                              *");
    $display("*                Your execution cycles = %5d cycles          *", total_latency);
    $display("*                Your clock period = %.1f ns          *", CYCLE_clk3);
    $display("*                Total Latency = %.1f ns          *", total_latency*CYCLE_clk3);
    $display("*************************************************************************");
    $finish;
end endtask

task display_fail; begin
	$display("\033[31m \033[5m     //   / /     //   ) )     //   ) )     //   ) )     //   ) )\033[0m");
    $display("\033[31m \033[5m    //____       //___/ /     //___/ /     //   / /     //___/ /\033[0m");
    $display("\033[31m \033[5m   / ____       / ___ (      / ___ (      //   / /     / ___ (\033[0m");
    $display("\033[31m \033[5m  //           //   | |     //   | |     //   / /     //   | |\033[0m");
    $display("\033[31m \033[5m //____/ /    //    | |    //    | |    ((___/ /     //    | |\033[0m");
end endtask

always @(negedge clk3) begin
	if(out_valid == 1'b0) begin
		if(out_data !==0) begin
			$display(" out_valid == 1'b0         out_data !==0 ");
			$finish;
		end
	end
end

always @(*) begin
	if(out_valid == 1'b1) begin
		if(in_valid == 1'b1) begin
			$display("  out_valid == 1'b1      in_valid == 1'b1  ");
			$finish;
		end
	end
end

endmodule

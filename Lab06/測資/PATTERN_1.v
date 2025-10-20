`ifdef RTL
    `define CYCLE_TIME 15
`endif
`ifdef GATE
    `define CYCLE_TIME 15
`endif

module PATTERN(
    // Output signals
    clk,
	rst_n,
	in_valid,
    in_hole_num,
    in_hole_suit,
    in_pub_num,
    in_pub_suit,
    out_valid,
    out_win_rate
);

// ========================================
// Input & Output
// ========================================
output reg clk;
output reg rst_n;
output reg in_valid;
output reg [71:0] in_hole_num;
output reg [35:0] in_hole_suit;
output reg [11:0] in_pub_num;
output reg [5:0] in_pub_suit;

input out_valid;
input [62:0] out_win_rate;

//---------------------------------------------------------------------
//   PARAMETER & INTEGER DECLARATION
//---------------------------------------------------------------------
integer local_latency;
integer total_latency;
integer PATNUM;
real CYCLE = `CYCLE_TIME;
integer input_file;
integer i, j, k, l, patcount;

reg [3:0] pub_card_num   [0:2];
reg [1:0] pub_card_suit  [0:2];
reg [3:0] hole_card_num  [0:17];
reg [1:0] hole_card_suit [0:17];
reg [62:0] output_ans, golden_ans;
integer rate;
integer golden_rate[0:8];
//---------------------------------------------------------------------
//   REG & WIRE DECLARATION
//---------------------------------------------------------------------


//---------------------------------------------------------------------
//  CLOCK
//---------------------------------------------------------------------

always #(CYCLE/2.0) clk = ~clk;

//---------------------------------------------------------------------
//  SIMULATION
//---------------------------------------------------------------------
initial begin
	input_file = $fopen("../00_TESTBED/input.txt", "r");
	reset_signal_task; //reset
	k = $fscanf(input_file, "%d\n", PATNUM);
	total_latency = 0;
	patcount = 0;
	$display(" Start!!, Total patterns = %d", PATNUM);
	for(patcount=0; patcount<PATNUM; patcount=patcount+1) begin
		input_task;
        wait_out_valid_task;
        total_latency = total_latency + local_latency;
		check_ans_task;
        $display ("\033[0;32mPass Pattern NO. %d, latency: %d\033[m         ", patcount, local_latency);
		repeat($urandom_range(1, 5)) @(negedge clk);
	end
	
	$fclose(input_file);
	
	display_pass;
	$finish;
end

task reset_signal_task; begin
	rst_n = 1'b1;
	in_valid = 1'b0;
	force clk = 1'b0;
	#(0.5);
	rst_n = 1'b0;
	#(100);
	if (out_valid !== 1'b0 || out_win_rate !== 63'b0) begin
		$display(" RESET FAIL ");
        $display(" out_valid = %b, out_win_rate = %h", out_valid, out_win_rate);
        repeat(2) @(negedge clk);
		$finish;
	end
	#(10);
	rst_n = 1'b1;
	#(3);
	release clk;
end endtask

task input_task; begin
	// $display(" Reading input pattern %d ...", patcount);
    for(i=0; i<18; i=i+2) begin
        k = $fscanf(input_file, "%d %d %d %d", hole_card_num[i], hole_card_suit[i], hole_card_num[i+1], hole_card_suit[i+1]);
    end
    k = $fscanf(input_file, "%d %d %d %d %d %d", pub_card_num[0], pub_card_suit[0], pub_card_num[1], pub_card_suit[1], pub_card_num[2], pub_card_suit[2]);
    // $display(" Reading OK %d ...", patcount);

    in_valid = 1'b1;
    in_pub_num = {pub_card_num[2], pub_card_num[1], pub_card_num[0]};
    in_pub_suit= {pub_card_suit[2], pub_card_suit[1], pub_card_suit[0]};
    in_hole_num = {hole_card_num[17], hole_card_num[16], hole_card_num[15], hole_card_num[14], hole_card_num[13],
                    hole_card_num[12], hole_card_num[11], hole_card_num[10], hole_card_num[9], hole_card_num[8],
                    hole_card_num[7], hole_card_num[6], hole_card_num[5], hole_card_num[4], hole_card_num[3],
                    hole_card_num[2], hole_card_num[1], hole_card_num[0]};
    in_hole_suit = {hole_card_suit[17], hole_card_suit[16], hole_card_suit[15], hole_card_suit[14], hole_card_suit[13],
                    hole_card_suit[12], hole_card_suit[11], hole_card_suit[10], hole_card_suit[9], hole_card_suit[8],
                    hole_card_suit[7], hole_card_suit[6], hole_card_suit[5], hole_card_suit[4], hole_card_suit[3],
                    hole_card_suit[2], hole_card_suit[1], hole_card_suit[0]};

	@(negedge clk);

	in_valid = 1'b0;
    in_pub_num = 12'dx;
    in_pub_suit= 6'dx;
    in_hole_num = 72'dx;
    in_hole_suit = 36'dx;

end endtask

task wait_out_valid_task; begin
    local_latency = 0;
    while(out_valid !== 1'b1) begin
        if(local_latency > 1000) begin
            $display("          Failed > 1000 cycles latency!          ");
            $finish;
        end
        local_latency = local_latency + 1;
        @(negedge clk);
    end
end endtask

task check_ans_task; begin
	for(i=0; i<9; i=i+1) begin
		k = $fscanf(input_file, "%d", rate);
		golden_rate[i] = rate;
	end
	golden_ans = {golden_rate[8][6:0], golden_rate[7][6:0], golden_rate[6][6:0], golden_rate[5][6:0],
                  golden_rate[4][6:0], golden_rate[3][6:0], golden_rate[2][6:0], golden_rate[1][6:0], golden_rate[0][6:0]};
    output_ans = out_win_rate;

    if (output_ans !== golden_ans) begin
        display_fail;
        $display("Error: Test case %d failed", patcount);
        $display("Expected Answer  :   %b", golden_ans);
        $display("Your Wrong Answer:   %b", output_ans);
        $finish;
    end
end endtask

task display_fail; begin
	$display("\033[31m \033[5m     //   / /     //   ) )     //   ) )     //   ) )     //   ) )\033[0m");
    $display("\033[31m \033[5m    //____       //___/ /     //___/ /     //   / /     //___/ /\033[0m");
    $display("\033[31m \033[5m   / ____       / ___ (      / ___ (      //   / /     / ___ (\033[0m");
    $display("\033[31m \033[5m  //           //   | |     //   | |     //   / /     //   | |\033[0m");
    $display("\033[31m \033[5m //____/ /    //    | |    //    | |    ((___/ /     //    | |\033[0m");
end endtask

task display_pass; begin
    $display("\033[0;32m \033[5m    //   ) )     // | |     //   ) )     //   ) )\033[m");
    $display("\033[0;32m \033[5m   //___/ /     //__| |    ((           ((\033[m");
    $display("\033[0;32m \033[5m  / ____ /     / ___  |      \\           \\\033[m");
    $display("\033[0;32m \033[5m //           //    | |        ) )          ) )\033[m");
    $display("\033[0;32m \033[5m//           //     | | ((___ / /    ((___ / /\033[m");
	$display("                  Congratulations!               ");
	$display("              execution cycles = %7d", total_latency);
	$display("              clock period = %4fns", CYCLE);
end endtask

always @(negedge clk) begin
	if(out_valid == 1'b0) begin
		if(out_win_rate !==0) begin
			$display(" out_valid == 1'b0         out_win_rate !==0 ");
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
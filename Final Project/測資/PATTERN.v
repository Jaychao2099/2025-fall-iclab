`ifdef RTL
    `define CYCLE_TIME 20.0
`endif
`ifdef GATE
    `define CYCLE_TIME 20.0
`endif
`ifdef POST
    `define CYCLE_TIME 20.0
`endif

`define CYCLE_TIME 20.0

module PATTERN(
    clk,
    rst_n,
    in_valid,
    in_valid2,
    in_data,
    out_valid,
    out_sad
);
output reg clk, rst_n, in_valid, in_valid2;
output reg [8:0] in_data;
input out_valid;
input out_sad;

// ========================================
// clock
// ========================================
real CYCLE = `CYCLE_TIME;
always	#(CYCLE/2.0) clk = ~clk; //clock

// ========================================
// integer & parameter
// ========================================
integer input_file, output_file;
integer i, j, k;
integer total_latency = 0;
integer local_latency;
integer PATNUM = 50;
integer pat_cnt, set_cnt;
integer out_cycle_cnt;

// ========================================
// wire & reg
// ========================================
reg [8:0] temp_in_data;
reg [55:0] golden_out_ans;


//================================================================
// design
//================================================================
initial begin
    input_file = $fopen("../00_TESTBED/input.txt", "r");
    output_file = $fopen("../00_TESTBED/output.txt", "r");
    reset_task;
    for (pat_cnt = 0; pat_cnt < PATNUM; pat_cnt = pat_cnt + 1) begin
        input_data_task;
        repeat($urandom_range(3, 6)) @(negedge clk);
        for (set_cnt = 0; set_cnt < 64; set_cnt = set_cnt + 1) begin // repeat 64 sets
            local_latency = 0;
            input_set_task;
            wait_out_task;
            check_ans_task;
            $display("\033[0;32m        PATTERN %d SET %d PASS!,  cycle: %5d         \033[0m", pat_cnt, set_cnt, local_latency);
            total_latency = total_latency + local_latency;
            repeat($urandom_range(3, 6)) @(negedge clk);
        end
    end

    $fclose(input_file);
    $fclose(output_file);
	
	pass_task;
	$finish;
end


//================================================================
//  TASK
//================================================================
task reset_task; begin
	rst_n = 1'b1;
	in_valid = 1'b0;
    in_valid2 = 1'b0;
    in_data = 'bx;
	force clk = 1'b0;
	#(0.5);
	rst_n = 1'b0;
	#(100); // CHECK: All output signals should be reset after the reset signal is asserted. 
	if (out_valid !== 1'b0 || out_sad !== 1'b0) begin
		$display("\033[31mRESET FAIL \033[0m");
        $display(" out_valid = %b, out_sad = %h", out_valid, out_sad);
		$display("==========================================================================================");
        #(100);
		$finish;
	end
	rst_n = 1'b1;
	#(30);
	release clk;
end endtask

task input_data_task; begin
    @(negedge clk);
    in_valid = 1'b1;
    for (i = 0; i < 128; i = i + 1) begin // L0
        for (j = 0; j < 128; j = j + 1) begin
            k = $fscanf(input_file, "%d", temp_in_data[8:1]);
            in_data = temp_in_data;
            @(negedge clk);
        end
    end
    for (i = 0; i < 128; i = i + 1) begin // L1
        for (j = 0; j < 128; j = j + 1) begin
            k = $fscanf(input_file, "%d", temp_in_data[8:1]);
            in_data = temp_in_data;
            @(negedge clk);
        end
    end
    in_valid = 1'b0;
    in_data = 'bx;
end endtask

task input_set_task; begin
    in_valid2 = 1'b1;
    for (i = 0; i < 8; i = i + 1) begin
        k = $fscanf(input_file, "%d", temp_in_data[8:1]);
        k = $fscanf(input_file, "%d", temp_in_data[0]);
        in_data = temp_in_data;
        @(negedge clk);
    end
    in_valid2 = 1'b0;
    in_data = 'bx;
end endtask

task wait_out_task; begin
    while (out_valid !== 1'b1) begin
        if (local_latency > 1000) begin
            $display("\033[31m        PATTERN %d Failed > 1000 cycles latency!         \033[0m", pat_cnt);
            $display("==========================================================================================");
            #(100);
            $finish;
        end
        local_latency = local_latency + 1;
        @(negedge clk);
    end
end endtask

task check_ans_task; begin
    golden_out_ans = 56'b0;
    k = $fscanf(output_file, "%d %d %d %d", golden_out_ans[27:24], golden_out_ans[23:0], golden_out_ans[55:52], golden_out_ans[51:28]);
    for (i = 0; i < 56; i = i + 1) begin // 56 cycle
        if (out_sad !== golden_out_ans[i]) begin
            $display("\033[31m        PATTERN %d Failed!         \033[0m", pat_cnt);
            $display("                SET %d                         ", set_cnt);
            $display("        Your SAD = %d, Golden SAD = %d, bit = %1d         ", out_sad, golden_out_ans[i], i);
            $display("        Golden point2 = %d, SATD = %d, point1 = %d SATD = %d", golden_out_ans[55:52], golden_out_ans[51:28], golden_out_ans[27:24], golden_out_ans[23:0]);
            $display("==========================================================================================");
            #(100);
            $finish;
        end
        else begin
            // $display("PATTERN %d SET %d PASS!,  cycle: %5d", pat_cnt, set_cnt, local_latency);
        end
        @(negedge clk);
    end
end endtask

task pass_task; begin
    $display("*************************************************************************");
    $display("*                Congratulations!                                       *");
    $display("*                Your execution cycles = %5d cycles                     *", total_latency);
    $display("*                Average cycles of a set = %5d cycles                   *", total_latency/(PATNUM*64));
    $display("*                Your clock period = %.1f ns                            *", CYCLE);
    $display("*************************************************************************");
	$display("==========================================================================================");
    $finish;
end endtask

always @(*) begin
	if(out_valid === 1'b0 && rst_n === 1'b1) begin
		if(out_sad !== 0) begin
			$display("\033[31m \033[5m out_valid == 1'b0         out_sad !==0 \033[0m");
			$display("==========================================================================================");
			$finish;
		end
	end
end

always @(*) begin
	if(out_valid === 1'b1) begin
		if(in_valid === 1'b1) begin
			$display("\033[31m \033[5m  out_valid == 1'b1      in_valid == 1'b1  \033[0m");
			$display("==========================================================================================");
			$finish;
		end
	end
end

endmodule




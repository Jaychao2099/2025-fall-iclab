`ifdef RTL
    `define CYCLE_TIME 20.0
`endif
`ifdef GATE
    `define CYCLE_TIME 20.0
`endif

module PATTERN(
    // DUT Inputs
    clk,
	rst_n,
	in_valid,
    in_hole_num,
    in_hole_suit,
    in_pub_num,
    in_pub_suit,
    
    // DUT Outputs
    out_valid,
    out_win_rate
);

// ========================================
// Port Declaration (Reversed from DUT)
// ========================================
output reg clk;
output reg rst_n;
output reg in_valid;
output reg [71:0] in_hole_num;
output reg [35:0] in_hole_suit;
output reg [11:0] in_pub_num;
output reg [5:0]  in_pub_suit;

input out_valid;
input [62:0] out_win_rate;

// ========================================
// Parameters & Internal Variables
// ========================================
parameter MAX_LATENCY = 1000; // As per specification

// --- File I/O and Control ---
integer pat_fd;
integer PAT_NUM;
integer i_pat;
integer scan_status;

// --- Latency Tracking ---
integer latency_counter;
integer total_latency;

// --- Data Storage for one pattern ---
reg [3:0]  hole_card1_num, hole_card2_num;
reg [1:0]  hole_card1_suit, hole_card2_suit;
reg [3:0]  pub_card1_num, pub_card2_num, pub_card3_num;
reg [1:0]  pub_card1_suit, pub_card2_suit, pub_card3_suit;
reg [6:0]  temp_win_rate [0:8];
reg [62:0] golden_win_rate;


// ========================================
// Clock Generation
// ========================================
real CYCLE = `CYCLE_TIME;
always #(CYCLE/2.0) clk = ~clk;

// ========================================
// Main Simulation Flow
// ========================================
initial begin
    // --- Initialization ---
    clk = 1'b0;
    total_latency = 0;
    pat_fd = $fopen("../00_TESTBED/input.txt", "r");
    if (pat_fd == 0) begin
        $display("[ERROR] Could not open input file. Aborting simulation.");
        $finish;
    end

    // --- Start of Simulation ---
    reset_task;
    
    scan_status = $fscanf(pat_fd, "%d", PAT_NUM); // Read total number of patterns

    for (i_pat = 0; i_pat < PAT_NUM; i_pat = i_pat + 1) begin
        drive_input_task;
        check_output_task;
    end

    // --- End of Simulation ---
    pass_and_finish_task;
end

// ========================================
// Verification Tasks
// ========================================

//-------------------------------------------------
// Task: reset_task
// Description: Performs an asynchronous, active-low reset and verifies 
//              that DUT outputs return to their specified initial state.
//-------------------------------------------------
task reset_task;
begin
    // Initial state before reset
    rst_n    = 1'b1;
    in_valid = 1'b0;
    in_hole_num  = 72'hx;
    in_hole_suit = 36'hx;
    in_pub_num   = 12'hx;
    in_pub_suit  = 6'hx;

    // Apply reset
    force clk = 1'b0;
    #(CYCLE);
    rst_n = 1'b0;
    #(CYCLE * 2);

    // Release reset and check initial output state (Protocol & Timing Assertion)
    rst_n = 1'b1;
    #(CYCLE);
    if (out_valid !== 1'b0 || out_win_rate !== 63'd0) begin
        $display("============================================================");
        $display("[FAIL] SPEC VIOLATION at time %0t", $time);
        $display("       DUT outputs did not reset to 0 after initial reset.");
        $display("       - out_valid: %b", out_valid);
        $display("       - out_win_rate: %h", out_win_rate);
        $display("============================================================");
        $finish;
    end
    release clk;
    @(negedge clk);
end
endtask

//-------------------------------------------------
// Task: drive_input_task
// Description: Reads one full pattern (stimulus and golden answer) from the
//              file, introduces timing jitter, and drives the DUT inputs.
//-------------------------------------------------
task drive_input_task;
    integer i;
begin
    // Read 9 players' hole cards
    for (i = 8; i >= 0; i = i - 1) begin
        scan_status = $fscanf(pat_fd, "%d %d %d %d", hole_card1_num, hole_card1_suit, hole_card2_num, hole_card2_suit);
        in_hole_num[i*8 +: 8]   = {hole_card1_num, hole_card2_num};
        in_hole_suit[i*4 +: 4] = {hole_card1_suit, hole_card2_suit};
    end

    // Read 3 public community cards
    scan_status = $fscanf(pat_fd, "%d %d %d %d %d %d", pub_card1_num, pub_card1_suit, pub_card2_num, pub_card2_suit, pub_card3_num, pub_card3_suit);
    in_pub_num   = {pub_card1_num, pub_card2_num, pub_card3_num};
    in_pub_suit  = {pub_card1_suit, pub_card2_suit, pub_card3_suit};

    // Read 9 players' golden win rates
    for (i = 8; i >= 0; i = i - 1) begin
        scan_status = $fscanf(pat_fd, "%d", temp_win_rate[i]);
    end
    golden_win_rate = {temp_win_rate[8], temp_win_rate[7], temp_win_rate[6], temp_win_rate[5], temp_win_rate[4], temp_win_rate[3], temp_win_rate[2], temp_win_rate[1], temp_win_rate[0]};

    // // Introduce random timing jitter (2-6 cycles as per spec)
    // repeat ($urandom_range(2, 6)) @(negedge clk);

    // Drive inputs for one cycle
    in_valid = 1'b1;
    @(negedge clk);
    in_valid = 1'b0;
    
    // Set inputs to 'x' when not valid to catch potential design issues
    in_hole_num  = 72'hx;
    in_hole_suit = 36'hx;
    in_pub_num   = 12'hx;
    in_pub_suit  = 6'hx;
end
endtask

//-------------------------------------------------
// Task: check_output_task
// Description: Waits for DUT's out_valid, checks for latency timeout,
//              and compares the DUT's output with the golden result.
//-------------------------------------------------
task check_output_task;
    integer k;
begin
    latency_counter = 0;
    // Wait for out_valid, with a timeout check (Protocol & Timing Assertion)
    while (out_valid !== 1'b1) begin
        latency_counter = latency_counter + 1;
        if (latency_counter > MAX_LATENCY) begin
            $display("============================================================");
            $display("[FAIL] PATTERN %0d at time %0t", i_pat, $time);
            $display("       SPEC VIOLATION: Latency Timeout.");
            $display("       Waited for %0d cycles, which exceeds MAX_LATENCY of %0d.", latency_counter, MAX_LATENCY);
            $display("============================================================");
            $finish;
        end
        @(negedge clk);
    end
    latency_counter = latency_counter + 1; // Count the cycle where out_valid is high

    // Check if out_valid remains high for more than 1 cycle
    @(negedge clk);
    if(out_valid === 1'b1) begin
        $display("============================================================");
        $display("[FAIL] PATTERN %0d at time %0t", i_pat, $time);
        $display("       SPEC VIOLATION: out_valid was high for more than 1 cycle.");
        $display("============================================================");
        $finish;
    end

    // Compare DUT output with golden answer
    // Using $strobe ensures we display the final, stable value of the cycle.
    if (out_win_rate !== golden_win_rate) begin
        // $display("============================================================");
        // $display("[FAIL] PATTERN %0d at time %0t", i_pat, $time);
        // $display("       Data Mismatch!");
        // $write  ("       - Golden Result: {");
        // for (k = 0; k < 9; k = k + 1) begin
        //     $write("%d, ", golden_win_rate[62-7*k:56-7*k]);
        // end
        // $display("}");
        // // $display("       - DUT Output:    %h", out_win_rate);
        // $write  ("       - Golden Result: {");
        // for (k = 0; k < 9; k = k + 1) begin
        //     $write("%d, ", out_win_rate[62-7*k:56-7*k]);
        // end
        // $display("}");
        // $display("============================================================");
        // $finish;
        $display("============================================================");
        $display("[FAIL] PATTERN %0d at time %0t", i_pat, $time);
        $display("       Data Mismatch!");
        $display("       - Golden Result: %h", golden_win_rate);
        $display("       - DUT Output:    %h", out_win_rate);
        $display("============================================================");
        $finish;
    end else begin
        $display("[PASS] PATTERN %0d, Latency: %0d cycles.", i_pat, latency_counter);
        total_latency = total_latency + latency_counter;
    end
end
endtask

//-------------------------------------------------
// Task: pass_and_finish_task
// Description: Prints a final success message and performance summary.
//-------------------------------------------------
task pass_and_finish_task;
begin
    $fclose(pat_fd);
    $display("------------------------------------------------------------");
    $display("                  Congratulations!                          ");
    $display("              All %0d patterns passed.                    ", PAT_NUM);
    $display("------------------------------------------------------------");
    $display("  Performance Summary:");
    $display("  - Total Execution Cycles : %0d", total_latency);
    $display("  - Clock Period           : %.1f ns", CYCLE);
    $display("  - Average Latency        : %.2f cycles", (total_latency * 1.0) / PAT_NUM);
    $display("------------------------------------------------------------");
    $finish;
end
endtask

// ========================================
// Protocol Assertions
// ========================================
// Continuously check for illegal overlap of in_valid and out_valid
always @(posedge clk) begin
    if (in_valid && out_valid) begin
        $display("============================================================");
        $display("[FAIL] PATTERN %0d at time %0t", i_pat, $time);
        $display("       SPEC VIOLATION: in_valid and out_valid cannot be high simultaneously.");
        $display("============================================================");
        $finish;
    end
end

endmodule
`define CYCLE_TIME  20.0
`define PAT_NUM     10     // Total number of patterns to test
`define MAX_LATENCY 10000  // Maximum allowed latency per set as per spec

module PATTERN(
    // output signals to DUT
    clk,
    rst_n,
    in_valid_data,
    in_valid_param,
    data,
    index,
    mode,
    QP,
    
    // input signals from DUT
    out_valid,
    out_value
);

// ========================================
// I/O declaration
// ========================================
// Output to DUT
output reg          clk;
output reg          rst_n;
output reg          in_valid_data;
output reg          in_valid_param;

output reg    [7:0] data;
output reg    [3:0] index;
output reg          mode;
output reg    [4:0] QP;

// Input from DUT
input               out_valid;
input signed [31:0] out_value;

// ========================================
// Clock Generation
// ========================================
real CYCLE = `CYCLE_TIME;
always	#(CYCLE/2.0) clk = ~clk;

// ========================================
// Parameters and Test Control
// ========================================
integer i_pat, i_set, i;
integer total_latency;

// File descriptors for Golden File I/O
integer frame_file, param_file, golden_z_file;
integer file_status;

// ========================================
// Data Storage for a single pattern
// ========================================
reg [7:0]       frame_storage [0:16][0:1023]; // 16 frames of 32x32 pixels
reg [3:0]       index_storage [0:15];         // Frame index for 16 sets
reg [3:0]       mode_storage [0:15];          // 4x 1-bit modes for 16 sets
reg [4:0]       qp_storage [0:15];            // QP for 16 sets
reg signed [31:0] golden_z_storage [0:1023];    // Golden Z values for one set

// ========================================
// Main Test Flow
// ========================================
initial begin
    $display("============================================================");
    $display("      HLPTE Design Verification - PATTERN Start");
    $display("============================================================");

    total_latency = 0;
    
    // Open golden files for I/O
    frame_file    = $fopen("../00_TESTBED/frames.txt", "r");
    param_file    = $fopen("../00_TESTBED/params.txt", "r");
    golden_z_file = $fopen("../00_TESTBED/golden_Z.txt", "r");
    
    if (frame_file == 0 || param_file == 0 || golden_z_file == 0) begin
        $display("\n[FATAL ERROR] Failed to open golden files. Check paths and permissions.");
        $finish;
    end

    reset_task;

    for (i_pat = 0; i_pat < `PAT_NUM; i_pat = i_pat + 1) begin
        load_pattern_data_task;
        drive_frame_data_task;
        
        for (i_set = 0; i_set < 16; i_set = i_set + 1) begin
            drive_param_task(i_set);
            check_output_task(i_set);
        end
        $display("\033[0;32mPASS PATTERN NO.%4d\033[m", i_pat);
    end
    
    pass_and_finish_task;
end

// ========================================
// Verification Tasks
// ========================================
task reset_task; begin
    clk = 1'b0;
    rst_n = 1'b1;
    in_valid_data = 1'b0;
    in_valid_param = 1'b0;
    data = 8'h_xx;
    index = 4'h_x;
    mode = 1'b_x;
    QP = 5'h_xx;
    
    // Asynchronous active-low reset pulse for 3 clock cycles as per spec
    force clk = 1'b0;
    #(CYCLE * 1.5);
    rst_n = 1'b0;
    #(CYCLE * 3);
    rst_n = 1'b1;
    
    // After reset, check if outputs are at their defined initial state (0)
    if (out_valid !== 1'b0 || out_value !== 32'd0) begin
        $display("\n[FAIL] SPEC VIOLATION: Outputs are not 0 after initial reset.");
        $display("       out_valid = %b, out_value = %d", out_valid, out_value);
        $finish;
    end
    
    #(CYCLE); // Release clock after 1 cycle post-reset deassertion
    release clk;
    @(negedge clk);
end
endtask

task load_pattern_data_task; begin
    integer j;
    // Load 16 frames of pixel data
    for (i = 0; i < 16; i = i + 1) begin
        for (j = 0; j < 1024; j = j + 1) begin
            file_status = $fscanf(frame_file, "%h", frame_storage[i][j]);
        end
    end
    
    // Load parameters for all 16 sets
    for (i = 0; i < 16; i = i + 1) begin
        file_status = $fscanf(param_file, "%d %h %d", index_storage[i], mode_storage[i], qp_storage[i]);
    end
end
endtask

task drive_frame_data_task; begin
    // Drive 16 frames sequentially (16 * 1024 = 16384 pixels)
    in_valid_data = 1'b1;
    for (i = 0; i < 16384; i = i + 1) begin
        data = frame_storage[i/1024][i%1024];
        @(negedge clk);
    end
    in_valid_data = 1'b0;
    data = 8'h_xx;
end
endtask

task drive_param_task;
    input integer set_idx;
begin
    integer k;
    // Wait for 2-4 cycles based on spec (random jitter)
    if (set_idx == 0) begin
        // First in_valid_param after in_valid_data falls
        repeat($urandom_range(2, 4)) @(negedge clk);
    end else begin
        // Subsequent in_valid_param after previous out_valid falls
        repeat($urandom_range(2, 4)) @(negedge clk);
    end

    // Drive parameters
    in_valid_param = 1'b1;
    index = index_storage[set_idx];
    QP = qp_storage[set_idx];

    for (k = 0; k < 4; k = k + 1) begin
        mode = mode_storage[set_idx][3-k];
        @(negedge clk);
    end

    in_valid_param = 1'b0;
    index = 4'h_x;
    mode = 1'b_x;
    QP = 5'h_xx;
end
endtask

task check_output_task;
    input integer set_idx;
    integer latency_counter;
begin
    // Load golden results for the current set
    for (i = 0; i < 1024; i = i + 1) begin
        file_status = $fscanf(golden_z_file, "%d", golden_z_storage[i]);
    end

    latency_counter = 0;
    // Wait for out_valid with timeout
    while (out_valid !== 1'b1) begin
        latency_counter = latency_counter + 1;
        if (latency_counter > `MAX_LATENCY) begin
            $display("\n[FAIL] TIMEOUT at PATTERN %d, SET %d.", i_pat, set_idx);
            $display("       Latency exceeded %d cycles.", `MAX_LATENCY);
            $finish;
        end
        // Check for I/O valid overlap violation
        if (in_valid_param === 1'b1) begin
            $display("\n[FAIL] PROTOCOL VIOLATION: in_valid_param and out_valid overlapped.");
            $finish;
        end
        @(negedge clk);
    end
    total_latency = total_latency + latency_counter;
    
    // Check all 1024 output values
    for (i = 0; i < 1024; i = i + 1) begin
        // Check if out_valid drops prematurely
        if (out_valid !== 1'b1) begin
            $display("\n[FAIL] PROTOCOL VIOLATION at PATTERN %d, SET %d.", i_pat, set_idx);
            $display("       out_valid dropped after %d cycles (expected 1024).", i);
            $finish;
        end
        
        // Compare DUT output with golden value
        if (out_value !== golden_z_storage[i]) begin
            $display("\n[FAIL] DATA MISMATCH at PATTERN %d, SET %d, output index %d.", i_pat, set_idx, i);
            $strobe("       DUT Output: %d (%h)", out_value, out_value);
            $strobe("       Golden    : %d (%h)", golden_z_storage[i], golden_z_storage[i]);
            $finish;
        end
        @(negedge clk);
    end
    
    // Check if out_valid stays high for too long
    if (out_valid === 1'b1) begin
        $display("\n[FAIL] PROTOCOL VIOLATION at PATTERN %d, SET %d.", i_pat, set_idx);
        $display("       out_valid remained high for more than 1024 cycles.");
        $finish;
    end
end
endtask

task pass_and_finish_task; begin
    $display("============================================================");
    $display("    \033[1;32mCongratulations! All %d patterns have passed.\033[m", `PAT_NUM);
    $display("    Total Execution Cycles (Latency): %d cycles", total_latency);
    $display("    Clock Period: %.1f ns", CYCLE);
    $display("    Total Latency: %.1f ns", total_latency * CYCLE);
    $display("============================================================");
    $finish;
end
endtask

endmodule
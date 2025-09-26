/**************************************************************************/
// Copyright (c) 2025, OASIS Lab
// MODULE: PATTERN
// FILE NAME: PATTERN.v
// VERSRION: 2.0
// DATE: September 24, 2025
// AUTHOR: Gemini DV Engineer (Corrected based on user feedback)
// DESCRIPTION: ICLAB2025FALL / LAB3 / PATTERN
// MODIFICATION HISTORY:
// Date                 Description
// 2025/9/25            V1 - Initial release for Convex Hull verification.
// 2025/9/26            V2 - Corrected golden model logic for collinear points
//                      that extend a hull edge. Added is_between function.
/**************************************************************************/

`ifdef RTL
    `define CYCLE_TIME 40.0
`endif
`ifdef GATE
    `define CYCLE_TIME 40.0
`endif

module PATTERN (
	// Output to DUT
	rst_n,
	clk,
	in_valid,
	pt_num,
	in_x,
	in_y,
	// Input from DUT
	out_valid,
	out_x,
	out_y,
	drop_num
);

//---------------------------------------------------------------------
//   PORT DECLARATION          
//---------------------------------------------------------------------
output reg			rst_n;
output reg			clk;
output reg			in_valid;
output reg	[8:0]	pt_num;
output reg	[9:0]	in_x;
output reg	[9:0]	in_y;

input				out_valid;
input		[9:0]	out_x;
input		[9:0]	out_y;
input		[6:0]	drop_num;

//---------------------------------------------------------------------
//   PARAMETER & INTEGER DECLARATION
//---------------------------------------------------------------------
integer total_latency;
real CYCLE = `CYCLE_TIME;
integer i, j, k;

// Pattern and File I/O
integer file_descriptor;
integer num_patterns;
integer num_points_in_pattern;
integer current_pattern_idx;
integer current_point_idx;
integer temp_x, temp_y;
integer ret;

// Golden Model Data Structures
parameter MAX_HULL_POINTS = 128;
reg [9:0] hull_x [0:MAX_HULL_POINTS-1];
reg [9:0] hull_y [0:MAX_HULL_POINTS-1];
integer hull_size;

reg [6:0] golden_drop_num;
reg [19:0] golden_dropped_points [0:MAX_HULL_POINTS-1]; // {x, y}
reg [6:0] dut_drop_num;
reg [19:0] dut_dropped_points [0:MAX_HULL_POINTS-1];

// Latency Counter
integer latency_counter;
parameter MAX_LATENCY = 1000;
			
//---------------------------------------------------------------------
//   REG & WIRE DECLARATION
//---------------------------------------------------------------------
// (Additional regs are declared within the parameter section)

//---------------------------------------------------------------------
//  CLOCK
//---------------------------------------------------------------------
initial clk = 1'b0;
always #(`CYCLE_TIME/2.0) clk = ~clk;

//---------------------------------------------------------------------
//  SPEC-6 Check: in_valid and out_valid should not overlap
//---------------------------------------------------------------------
always @(*) begin
    if (in_valid && out_valid) begin
        $display("------------------------------------------------------------");
        $display("                    SPEC-6 FAIL                   ");
        $display("FAIL: 'in_valid' and 'out_valid' cannot be high simultaneously.");
        $display("Time: %t", $time);
        $display("------------------------------------------------------------");
        $finish;
    end
end

//---------------------------------------------------------------------
//  SIMULATION
//---------------------------------------------------------------------
initial begin
    file_descriptor = $fopen("../00_TESTBED/input.txt", "r");
    if (file_descriptor == 0) begin
        $display("[ERROR] Could not open input.txt. Simulation aborted.");
        $finish;
    end

    reset_task;

    ret = $fscanf(file_descriptor, "%d", num_patterns);
    for (current_pattern_idx = 0; current_pattern_idx < num_patterns; current_pattern_idx = current_pattern_idx + 1) begin
        
        // Initialize for new pattern
        initialize_golden_model;
        ret = $fscanf(file_descriptor, "%d", num_points_in_pattern);
        
        for (current_point_idx = 0; current_point_idx < num_points_in_pattern; current_point_idx = current_point_idx + 1) begin
            ret = $fscanf(file_descriptor, "%d %d", temp_x, temp_y);
            
            // Calculate golden answer before applying stimulus
            update_golden_hull(temp_x, temp_y);
            
            // Apply stimulus
            apply_stimulus(num_points_in_pattern, temp_x, temp_y);
            
            // Wait for DUT response and check result
            wait_and_check_result;
            
            $display("Pattern [%3d/%3d], Point [%3d/%3d] PASS. Latency: %4d cycles.", 
                     current_pattern_idx + 1, num_patterns, 
                     current_point_idx + 1, num_points_in_pattern, 
                     latency_counter);
        end
    end
    
    // Final success message
    $display("------------------------------------------------------------");
    $display("                  Congratulations!               ");
    $display("              All patterns passed successfully.            ");
    $display("              execution cycles = %7d", total_latency);
    $display("              clock period = %4.1fns", CYCLE);
    $display("------------------------------------------------------------");
    $finish;
end

// ====================================================================
//  TASKS and FUNCTIONS
// ====================================================================

// --- Reset Task and Initial State Check (SPEC-4) ---
task reset_task;
begin
    rst_n = 1'b1;
    in_valid = 1'b0;
    pt_num = 'dx;
    in_x = 'dx;
    in_y = 'dx;
    total_latency = 0;

    force clk = 1'b0;
    #10;
    rst_n = 1'b0;
    #(100); // Hold reset low
    
    // SPEC-4 Check: All outputs should be 0 after reset
    if (out_valid !== 1'b0 || drop_num !== 7'b0 || out_x !== 10'b0 || out_y !== 10'b0) begin
        $display("------------------------------------------------------------");
        $display("                    SPEC-4 FAIL                   ");
        $display("FAIL: Outputs are not reset to 0 after rst_n is asserted.");
        $display("out_valid=%b, drop_num=%d, out_x=%d, out_y=%d", out_valid, drop_num, out_x, out_y);
        $display("------------------------------------------------------------");
        $finish;
    end
    
    rst_n = 1'b1;
    #(`CYCLE_TIME);
    release clk;
end
endtask

// --- Golden Model Initialization ---
task initialize_golden_model;
begin
    hull_size = 0;
    golden_drop_num = 0;
    for (i = 0; i < MAX_HULL_POINTS; i = i + 1) begin
        hull_x[i] = 0;
        hull_y[i] = 0;
        golden_dropped_points[i] = 0;
    end
end
endtask

// --- Stimulus Generation Task ---
task apply_stimulus;
    input [8:0] total_points;
    input [9:0] new_x;
    input [9:0] new_y;
begin
    // Random delay between points as per spec (1-4 negedges after out_valid goes low)
    if (current_point_idx > 0) begin
        repeat($urandom_range(1, 4)) @(negedge clk);
    end

    @(negedge clk);
    in_valid = 1'b1;
    in_x = new_x;
    in_y = new_y;
    if (current_point_idx == 0) begin
        pt_num = total_points;
    end

    @(negedge clk);
    in_valid = 1'b0;
    in_x = 'dx;
    in_y = 'dx;
    pt_num = 'dx;
end
endtask

// --- Result Verification Task ---
task wait_and_check_result;
begin
    latency_counter = 0;
    
    // SPEC-5 Check before waiting
    if (drop_num !== 7'b0 || out_x !== 10'b0 || out_y !== 10'b0) begin
        $display("------------------------------------------------------------");
        $display("                    SPEC-5 FAIL                   ");
        $display("FAIL: drop_num/out_x/out_y must be 0 when out_valid is low.");
        $display("Time: %t", $time);
        $display("------------------------------------------------------------");
        $finish;
    end

    // Wait for out_valid, with Latency Timeout (SPEC-7)
    while (out_valid !== 1'b1) begin
        latency_counter = latency_counter + 1;
        if (latency_counter > MAX_LATENCY) begin
            $display("------------------------------------------------------------");
            $display("                    SPEC-7 FAIL                   ");
            $display("FAIL: Latency exceeded the maximum of %d cycles.", MAX_LATENCY);
            $display("Time: %t", $time);
            $display("------------------------------------------------------------");
            $finish;
        end
        @(negedge clk);
    end
    
    // First valid cycle
    total_latency = total_latency + latency_counter;
    dut_drop_num = drop_num;

    // Check if drop_num matches
    if (dut_drop_num != golden_drop_num) begin
        $display("------------------------------------------------------------");
        $display("                    SPEC-8 FAIL                   ");
        $display("FAIL: Mismatch in number of dropped points.");
        $display("Pattern: %d, Point: %d ({%d, %d})", current_pattern_idx+1, current_point_idx+1, temp_x, temp_y);
        $display("Expected drop_num: %d, DUT drop_num: %d", golden_drop_num, dut_drop_num);
        $display("------------------------------------------------------------");
        $finish;
    end
    
    // Collect all dropped points from DUT
    for (i = 0; i < dut_drop_num; i = i + 1) begin
        // SPEC-9 Check: out_valid must stay high for multiple drops
        if (out_valid !== 1'b1) begin
            $display("------------------------------------------------------------");
            $display("                    SPEC-9 FAIL                   ");
            $display("FAIL: out_valid went low during multi-point drop.");
            $display("Time: %t", $time);
            $display("------------------------------------------------------------");
            $finish;
        end
        dut_dropped_points[i] = {out_x, out_y};
        @(negedge clk);
    end

    if (dut_drop_num == 0) @(negedge clk);
    
    // After collecting, out_valid should be low
    if (out_valid === 1'b1) begin
       $display("Warning: out_valid stayed high for longer than drop_num cycles.");
    end

    // Compare DUT results with golden results (order-independent)
    sort_task(dut_dropped_points, dut_drop_num);
    sort_task(golden_dropped_points, golden_drop_num);

    for (i = 0; i < golden_drop_num; i = i + 1) begin
        if (dut_dropped_points[i] !== golden_dropped_points[i]) begin
            $display("------------------------------------------------------------");
            $display("                    SPEC-8 FAIL                   ");
            $display("FAIL: Mismatch in dropped point coordinates.");
            $display("Pattern: %d, Point: %d", current_pattern_idx+1, current_point_idx+1);
            $display("Mismatch at index %d after sorting.", i);
            $display("Expected: {%d, %d}, DUT: {%d, %d}", golden_dropped_points[i][19:10], golden_dropped_points[i][9:0], dut_dropped_points[i][19:10], dut_dropped_points[i][9:0]);
            $display("--- Golden Dropped Points ---");
            for(j=0; j<golden_drop_num; j=j+1) $display("  (%d, %d)", golden_dropped_points[j][19:10], golden_dropped_points[j][9:0]);
            $display("--- DUT Dropped Points ---");
            for(j=0; j<dut_drop_num; j=j+1) $display("  (%d, %d)", dut_dropped_points[j][19:10], dut_dropped_points[j][9:0]);
            $display("------------------------------------------------------------");
            $finish;
        end
    end
end
endtask


// ====================================================================
//  Behavioral Golden Model
// ====================================================================

// --- cross_product: Determines orientation.
// > 0 for Counter-Clockwise (left turn)
// < 0 for Clockwise (right turn)
// = 0 for Collinear
function signed [63:0] cross_product;
    input [9:0] p1x, p1y, p2x, p2y, p3x, p3y;
    reg signed [31:0] dx1, dy1, dx2, dy2;
    begin
        dx1 = p2x - p1x;
        dy1 = p2y - p1y;
        dx2 = p3x - p1x;
        dy2 = p3y - p1y;
        cross_product = dx1 * dy2 - dx2 * dy1;
    end
endfunction

// --- is_between: Checks if collinear point C is between A and B
function integer is_between;
    input [9:0] ax, ay, bx, by, cx, cy;
    begin
        is_between = (cx >= ((ax < bx) ? ax : bx)) && (cx <= ((ax > bx) ? ax : bx)) &&
                     (cy >= ((ay < by) ? ay : by)) && (cy <= ((ay > by) ? ay : by));
    end
endfunction

// --- update_golden_hull: The core golden model logic
task update_golden_hull;
    input [9:0] px, py;
    // Local variables
    reg [9:0] next_hull_x [0:MAX_HULL_POINTS];
    reg [9:0] next_hull_y [0:MAX_HULL_POINTS];
    integer next_hull_size;
    integer start_tangent_idx, end_tangent_idx;
    reg is_strictly_outside;
    reg signed [63:0] orientation_sign;
    
begin
    golden_drop_num = 0;
    
    // Case 1: First 3 points form a triangle
    if (hull_size < 3) begin
        hull_x[hull_size] = px;
        hull_y[hull_size] = py;
        hull_size = hull_size + 1;
        
        if (hull_size == 3) begin
            // Ensure CCW order. The first 3 points are guaranteed not to be collinear by spec.
            if (cross_product(hull_x[0], hull_y[0], hull_x[1], hull_y[1], hull_x[2], hull_y[2]) < 0) begin
                {temp_x, temp_y} = {hull_x[1], hull_y[1]};
                {hull_x[1], hull_y[1]} = {hull_x[2], hull_y[2]};
                {hull_x[2], hull_y[2]} = {temp_x, temp_y};
            end
        end
        return;
    end
    
    // Case 2: Point is inside, on an edge, or on a vertex
    is_strictly_outside = 1'b0;
    for (i = 0; i < hull_size; i = i + 1) begin
        j = (i + 1) % hull_size;
        orientation_sign = cross_product(hull_x[i], hull_y[i], hull_x[j], hull_y[j], px, py);

        if (orientation_sign < 0) begin // Strictly to the right -> definitely outside
            is_strictly_outside = 1'b1;
            break;
        end
        if (orientation_sign == 0) begin // Collinear
            if (is_between(hull_x[i], hull_y[i], hull_x[j], hull_y[j], px, py)) begin
                // On an edge segment, discard new point
                golden_drop_num = 1;
                golden_dropped_points[0] = {px, py};
                return;
            end
        end
    end

    if (!is_strictly_outside) begin
        // If not strictly outside, it's inside, on a vertex, or collinear but not between (on a vertex).
        // Per spec, these cases all result in the new point being discarded.
        golden_drop_num = 1;
        golden_dropped_points[0] = {px, py};
        return;
    end
    
    // Case 3: Point is strictly outside, find tangents and rebuild hull
    for(i = 0; i < hull_size; i=i+1) begin
        j = (i + 1) % hull_size;
        k = (i + hull_size - 1) % hull_size;
        // Upper tangent (right or zero turn, then left turn)
        if (cross_product(px, py, hull_x[i], hull_y[i], hull_x[j], hull_y[j]) >= 0 && cross_product(px, py, hull_x[k], hull_y[k], hull_x[i], hull_y[i]) < 0) begin
            end_tangent_idx = i;
        end
        // Lower tangent (left turn, then right or zero turn)
        if (cross_product(px, py, hull_x[i], hull_y[i], hull_x[j], hull_y[j]) < 0 && cross_product(px, py, hull_x[k], hull_y[k], hull_x[i], hull_y[i]) >= 0) begin
            start_tangent_idx = i;
        end
    end
    
    // Rebuild the hull: from end_tangent to start_tangent
    next_hull_size = 0;
    i = end_tangent_idx;
    while(i != start_tangent_idx) begin
        next_hull_x[next_hull_size] = hull_x[i];
        next_hull_y[next_hull_size] = hull_y[i];
        next_hull_size = next_hull_size + 1;
        i = (i + 1) % hull_size;
    end
    next_hull_x[next_hull_size] = hull_x[start_tangent_idx];
    next_hull_y[next_hull_size] = hull_y[start_tangent_idx];
    next_hull_size = next_hull_size + 1;
    
    // Add the new point
    next_hull_x[next_hull_size] = px;
    next_hull_y[next_hull_size] = py;
    next_hull_size = next_hull_size + 1;
    
    // Identify dropped points (those between start and end tangents)
    i = (start_tangent_idx + 1) % hull_size;
    while(i != end_tangent_idx) begin
        golden_dropped_points[golden_drop_num] = {hull_x[i], hull_y[i]};
        golden_drop_num = golden_drop_num + 1;
        i = (i + 1) % hull_size;
    end

    // Update hull with the new one
    hull_size = next_hull_size;
    for (i = 0; i < hull_size; i = i + 1) begin
        hull_x[i] = next_hull_x[i];
        hull_y[i] = next_hull_y[i];
    end
end
endtask

// --- Utility: Sort Task for Order-Independent Comparison ---
task sort_task;
    inout [19:0] arr [0:MAX_HULL_POINTS-1];
    input integer size;
    reg [19:0] temp;
begin
    if (size < 2) return;
    for (i = 0; i < size - 1; i = i + 1) begin
        for (j = 0; j < size - i - 1; j = j + 1) begin
            if (arr[j] > arr[j+1]) begin
                temp = arr[j];
                arr[j] = arr[j+1];
                arr[j+1] = temp;
            end
        end
    end
end
endtask

endmodule
// for spec check
// $display("                    SPEC-4 FAIL                   ");
// $display("                    SPEC-5 FAIL                   ");
// $display("                    SPEC-6 FAIL                   ");
// $display("                    SPEC-7 FAIL                   ");
// $display("                    SPEC-8 FAIL                   ");
// $display("                    SPEC-9 FAIL                   ");
// for successful design
// $display("                  Congratulations!               ");
// $display("              execution cycles = %7d", total_latency);
// $display("              clock period = %4fns", CYCLE);
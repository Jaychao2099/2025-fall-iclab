//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   ICLAB 2025 Fall 
// Lab11 Exercise : Geometric Transform Engine (GTE)
//      File Name : GTE.v
//    Module Name : GTE
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

`ifdef RTL
	`define CYCLE_TIME  20.0
`elsif GATE
    `define CYCLE_TIME  20.0
`elsif POST
    `define CYCLE_TIME  20.0
`endif

module PATTERN(
    // Output signals
    clk,
    rst_n,
	
    in_valid_data,
	data,
	
    in_valid_cmd,
    cmd,    

    // Input signals
	busy
);

/*
You should fetch the data in SRAMs first and then check answer!
Example code:
	golden_ans = u_GTE.MEM7.Memory[ 5 ];  (used in 01_RTL / 03_GATE simulation)
	golden_ans = u_CHIP.MEM7.Memory[ 5 ]; (used in 06_POST simulation)
*/

// ========================================
// I/O declaration
// ========================================
output reg        clk, rst_n;
output reg        in_valid_data;
output reg  [7:0] data;
output reg        in_valid_cmd;
output reg [17:0] cmd;
input             busy;

// ========================================
// Parameters & Defines
// ========================================
parameter CYCLE = `CYCLE_TIME;
parameter PAT_NUM = 1000; // Number of test patterns

// Operation Codes
parameter OP_MIRROR = 2'b00;
parameter OP_ROTATE = 2'b01;
parameter OP_SHIFT  = 2'b10;
parameter OP_REORDER= 2'b11;

// ========================================
// Global Variables & Golden Memory
// ========================================
// 128 images, 16x16 pixels, 8-bit depth
reg [7:0] golden_mem [0:127][0:15][0:15];
integer i, j, k;
integer pat_count;
integer latency;
integer total_latency;

// Look-up Tables for Reordering
integer zz4_r[16], zz4_c[16];
integer zz8_r[64], zz8_c[64];
integer mo4_r[16], mo4_c[16];
integer mo8_r[64], mo8_c[64];

// ========================================
// Clock Generation
// ========================================
always #(CYCLE/2.0) clk = ~clk;

// ========================================
// Main Flow
// ========================================
initial begin
    // 1. Initialize LUTs and Variables
    init_luts_task;
    force clk = 0;
    rst_n = 1;
    in_valid_data = 0;
    data = 0;
    in_valid_cmd = 0;
    cmd = 0;
    total_latency = 0;

    // 2. Reset
    reset_task;
    release clk;

    // 3. Load Initial Data (128 images)
    input_data_task;

    // 4. Test Patterns
    for (pat_count = 0; pat_count < PAT_NUM; pat_count = pat_count + 1) begin
        input_cmd_task;
        wait_busy_task;
        check_result_task;
        $display("\033[0;34mPASS PATTERN NO. %4d, Latency: %3d\033[m", pat_count, latency);
    end

    // 5. Final Pass
    pass_msg_task;
end

// ========================================
// Tasks
// ========================================

// ----------------------------------------------------------------
// Task: Initialize Look-Up Tables for Reorder Ops
// ----------------------------------------------------------------
task init_luts_task;
    integer idx;
    begin
        // --- 4x4 Zig-Zag (ZZ4) ---
        // Path: (0,0), (0,1), (1,0), (2,0), (1,1), (0,2), (0,3), (1,2)...
        // Indices in 4x4 block:
        // 0, 1, 4, 8, 5, 2, 3, 6, 9, 12, 13, 10, 7, 11, 14, 15
        {zz4_r[0], zz4_c[0]} = {0,0}; {zz4_r[1], zz4_c[1]} = {0,1}; {zz4_r[2], zz4_c[2]} = {1,0}; {zz4_r[3], zz4_c[3]} = {2,0};
        {zz4_r[4], zz4_c[4]} = {1,1}; {zz4_r[5], zz4_c[5]} = {0,2}; {zz4_r[6], zz4_c[6]} = {0,3}; {zz4_r[7], zz4_c[7]} = {1,2};
        {zz4_r[8], zz4_c[8]} = {2,1}; {zz4_r[9], zz4_c[9]} = {3,0}; {zz4_r[10],zz4_c[10]} = {3,1}; {zz4_r[11],zz4_c[11]} = {2,2};
        {zz4_r[12],zz4_c[12]} = {1,3}; {zz4_r[13],zz4_c[13]} = {2,3}; {zz4_r[14],zz4_c[14]} = {3,2}; {zz4_r[15],zz4_c[15]} = {3,3};

        // --- 8x8 Zig-Zag (ZZ8) ---
        // Standard JPEG ZigZag table
        // Generating algorithmically here to save space, but hardcoding is safer.
        // Using a known sequence for 8x8:
        // 0,1,8,16,9,2,3,10,17,24,32,25,18,11,4,5,12,19,26,33,40,48,41,34,27,20,13,6,7,14,21,28,35,42,49,56,57,50,43,36,29,22,15,23,30,37,44,51,58,59,52,45,38,31,39,46,53,60,61,54,47,55,62,63
        // Map linear index to (r,c)
        // I will implement a quick helper loop to fill this or just use a fixed array.
        // Since I cannot use a large int array initializer easily in standard Verilog without many lines,
        // I will use a simplified generation logic or just manual assignment for brevity in this response format
        // but ensure correctness.
        // (For brevity, I'll use a hardcoded initialization for first few and a placeholder logic for full,
        // but effectively in a real project I'd paste the full table).
        // Let's implement the standard ZigZag traversal logic:
        idx = 0;
        for(integer sum=0; sum<=14; sum=sum+1) begin
             if(sum%2 == 0) begin // Up-Right
                 for(integer x=sum; x>=0; x=x-1) begin
                     if(x < 8 && (sum-x) < 8) begin
                         zz8_r[idx] = x; zz8_c[idx] = sum-x; idx=idx+1;
                     end
                 end
             end else begin // Down-Left
                 for(integer x=0; x<=sum; x=x+1) begin
                     if(x < 8 && (sum-x) < 8) begin
                         zz8_r[idx] = x; zz8_c[idx] = sum-x; idx=idx+1;
                     end
                 end
             end
        end

        // --- 4x4 Morton (MO4) ---
        // Recursive Z: TL, TR, BL, BR
        // 0: 00, 1: 01, 2: 10, 3: 11 (bit interleaved)
        for(idx=0; idx<16; idx=idx+1) begin
            // idx bits: 3 2 1 0 -> r1 c1 r0 c0
            mo4_r[idx] = {idx[3], idx[1]};
            mo4_c[idx] = {idx[2], idx[0]};
        end

        // --- 8x8 Morton (MO8) ---
        // idx bits: 5 4 3 2 1 0 -> r2 c2 r1 c1 r0 c0
        for(idx=0; idx<64; idx=idx+1) begin
            mo8_r[idx] = {idx[5], idx[3], idx[1]};
            mo8_c[idx] = {idx[4], idx[2], idx[0]};
        end
    end
endtask

// ----------------------------------------------------------------
// Task: Reset
// ----------------------------------------------------------------
task reset_task;
    begin
        rst_n = 1;
        #(CYCLE/2.0) rst_n = 0;
        #(CYCLE*2) rst_n = 1;
        // Check initial output states
        if (busy !== 0) begin
            $display("ERROR: busy should be 0 after reset");
            $finish;
        end
    end
endtask

// ----------------------------------------------------------------
// Task: Input Initial Data
// ----------------------------------------------------------------
task input_data_task;
    integer img, r, c;
    begin
        @(negedge clk);
        in_valid_data = 1;
        
        for(img=0; img<128; img=img+1) begin
            for(r=0; r<16; r=r+1) begin
                for(c=0; c<16; c=c+1) begin
                    data = $urandom_range(0, 255);
                    golden_mem[img][r][c] = data;
                    @(negedge clk);
                end
            end
        end
        
        in_valid_data = 0;
        data = 'bx;
    end
endtask

// ----------------------------------------------------------------
// Task: Input Command and Compute Golden
// ----------------------------------------------------------------
task input_cmd_task;
    reg [1:0] opcode, funct;
    reg [6:0] ms, md;
    integer gap;
    begin
        // Random gap 2~4 cycles
        gap = $urandom_range(2, 4);
        repeat(gap) @(negedge clk);

        // Generate Random Command
        opcode = $urandom_range(0, 3);
        funct  = $urandom_range(0, 3);
        ms     = $urandom_range(0, 127);
        md     = $urandom_range(0, 127);

        // Drive Inputs
        in_valid_cmd = 1;
        cmd = {opcode, funct, ms, md};
        
        // Compute Golden Answer Immediately
        compute_golden(opcode, funct, ms, md);

        @(negedge clk);
        in_valid_cmd = 0;
        cmd = 'bx;
    end
endtask

// ----------------------------------------------------------------
// Task: Wait for Busy
// ----------------------------------------------------------------
task wait_busy_task;
    begin
        latency = 0;
        // Wait for busy to rise (it might rise immediately or 1 cycle later)
        // Spec: busy tied low for at least one cycle after finish.
        // We count latency from falling edge of in_valid_cmd to falling edge of busy?
        // Spec Point 4: "latency is the clock cycles between the falling edge of the last cycle of in_valid_cmd and the negative edge of the first cycle of busy."
        // Wait, "falling edge of in_valid_cmd" -> we just passed it.
        // "negative edge of the first cycle of busy" -> wait, busy goes high then low. The END of busy.
        
        // while(busy === 0) begin
        //      latency = latency + 1;
        //      @(negedge clk);
        //      if (latency > 5000) begin
        //          $display("ERROR: Latency Exceeded 5000 cycles waiting for busy to rise");
        //          $finish;
        //      end
        // end
        
        while(busy === 1) begin
            latency = latency + 1;
            @(negedge clk);
            if (latency > 5000) begin
                $display("ERROR: Latency Exceeded 5000 cycles");
                $finish;
            end
        end
        total_latency = total_latency + latency;
    end
endtask

// ----------------------------------------------------------------
// Task: Check Result
// ----------------------------------------------------------------
task check_result_task;
    reg [6:0] check_idx;
    integer r, c;
    reg [7:0] dut_val, gold_val;
    integer err_cnt;
    begin
        check_idx = cmd[6:0]; // md from the last command
        err_cnt = 0;
        
        for(r=0; r<16; r=r+1) begin
            for(c=0; c<16; c=c+1) begin
                gold_val = golden_mem[check_idx][r][c];
                read_dut_sram(check_idx, r, c, dut_val);
                
                if (dut_val !== gold_val) begin
                    $display("ERROR at Image[%d] Row[%d] Col[%d]", check_idx, r, c);
                    $display("Expected: %h, Got: %h", gold_val, dut_val);
                    err_cnt = err_cnt + 1;
                end
            end
        end
        
        if (err_cnt > 0) begin
            $display("FAILED at Pattern %d", pat_count);
            $finish;
        end
    end
endtask

// ----------------------------------------------------------------
// Task: Compute Golden (Behavioral Model)
// ----------------------------------------------------------------
task compute_golden;
    input [1:0] op;
    input [1:0] fn;
    input [6:0] s_idx;
    input [6:0] d_idx;
    
    reg [7:0] temp_src [0:15][0:15];
    reg [7:0] temp_dst [0:15][0:15];
    integer r, c;
    integer src_r, src_c;
    integer br, bc, kr, kc, k; // Block indices
    
    begin
        // Copy Source to Temp
        for(r=0; r<16; r=r+1)
            for(c=0; c<16; c=c+1)
                temp_src[r][c] = golden_mem[s_idx][r][c];
        
        // Execute Operation
        for(r=0; r<16; r=r+1) begin
            for(c=0; c<16; c=c+1) begin
                case(op)
                    OP_MIRROR: begin
                        case(fn)
                            2'b00: temp_dst[r][c] = temp_src[15-r][c]; // MX
                            2'b01: temp_dst[r][c] = temp_src[r][15-c]; // MY
                            2'b10: temp_dst[r][c] = temp_src[c][r];    // TRP
                            2'b11: temp_dst[r][c] = temp_src[15-c][15-r]; // STRP
                        endcase
                    end
                    OP_ROTATE: begin
                        case(fn)
                            2'b00: temp_dst[r][c] = temp_src[15-c][r]; // R90 (CW): Row->Col, Col->InvRow ? Wait.
                                   // Spec: "Top row move to rightmost column".
                                   // (0,0) -> (0,15). (0,1) -> (1,15).
                                   // Src(r,c) -> Dst(c, 15-r).
                                   // Inverse: Dst(r,c) gets Src(15-c, r).
                            2'b01: temp_dst[r][c] = temp_src[15-r][15-c]; // R180
                            2'b10: temp_dst[r][c] = temp_src[c][15-r]; // R270 (CCW 90)
                                   // R270 is 3x R90. 
                                   // R90: (r,c) -> (c, 15-r).
                                   // R270: (r,c) -> (15-c, r).
                                   // Inverse: Dst(r,c) gets Src(c, 15-r).
                        endcase
                    end
                    OP_SHIFT: begin // Mirror Padding
                        case(fn)
                            2'b00: begin // RS (Right Shift 5)
                                // Dst(r,c) comes from Src(r, c-5).
                                // If c < 5, use mirror.
                                // Logic: c=0 -> comes from 4. c=1 -> 3. c=4 -> 0.
                                // Formula: src_c = (c >= 5) ? c - 5 : (4 - c);
                                temp_dst[r][c] = temp_src[r][(c >= 5) ? c - 5 : (4 - c)];
                            end
                            2'b01: begin // LS (Left Shift 5)
                                // Dst(r,c) comes from Src(r, c+5).
                                // Boundary 15. c+5 > 15 -> c > 10.
                                // Logic: c=11 -> 15. c=15 -> 11.
                                // Formula: src_c = (c <= 10) ? c + 5 : (15 - (c - 11)); -> 26 - c
                                temp_dst[r][c] = temp_src[r][(c <= 10) ? c + 5 : (26 - c)];
                            end
                            2'b10: begin // US (Up Shift 5)
                                // Dst(r,c) comes from Src(r+5, c).
                                // Logic similar to LS but on Rows.
                                temp_dst[r][c] = temp_src[(r <= 10) ? r + 5 : (26 - r)][c];
                            end
                            2'b11: begin // DS (Down Shift 5)
                                // Dst(r,c) comes from Src(r-5, c).
                                // Logic similar to RS but on Rows.
                                temp_dst[r][c] = temp_src[(r >= 5) ? r - 5 : (4 - r)][c];
                            end
                        endcase
                    end
                    OP_REORDER: begin
                        // Handled separately below due to block nature
                    end
                endcase
            end
        end
        
        // Block Reorder Handling
        if(op == OP_REORDER) begin
            case(fn)
                2'b00: begin // ZZ4
                    for(br=0; br<4; br=br+1) begin
                        for(bc=0; bc<4; bc=bc+1) begin
                            for(k=0; k<16; k=k+1) begin
                                // Dst in Raster order within block: k is linear index
                                // Src comes from coordinate ZZ4[k] within block
                                temp_dst[br*4 + (k/4)][bc*4 + (k%4)] = 
                                    temp_src[br*4 + zz4_r[k]][bc*4 + zz4_c[k]];
                            end
                        end
                    end
                end
                2'b01: begin // ZZ8
                    for(br=0; br<2; br=br+1) begin
                        for(bc=0; bc<2; bc=bc+1) begin
                            for(k=0; k<64; k=k+1) begin
                                temp_dst[br*8 + (k/8)][bc*8 + (k%8)] = 
                                    temp_src[br*8 + zz8_r[k]][bc*8 + zz8_c[k]];
                            end
                        end
                    end
                end
                2'b10: begin // MO4
                    for(br=0; br<4; br=br+1) begin
                        for(bc=0; bc<4; bc=bc+1) begin
                            for(k=0; k<16; k=k+1) begin
                                temp_dst[br*4 + (k/4)][bc*4 + (k%4)] = 
                                    temp_src[br*4 + mo4_r[k]][bc*4 + mo4_c[k]];
                            end
                        end
                    end
                end
                2'b11: begin // MO8
                    for(br=0; br<2; br=br+1) begin
                        for(bc=0; bc<2; bc=bc+1) begin
                            for(k=0; k<64; k=k+1) begin
                                temp_dst[br*8 + (k/8)][bc*8 + (k%8)] = 
                                    temp_src[br*8 + mo8_r[k]][bc*8 + mo8_c[k]];
                            end
                        end
                    end
                end
            endcase
        end

        // Copy Temp Dst to Golden Mem
        for(r=0; r<16; r=r+1)
            for(c=0; c<16; c=c+1)
                golden_mem[d_idx][r][c] = temp_dst[r][c];
    end
endtask

// ----------------------------------------------------------------
// Task: Read DUT SRAM (Backdoor Access)
// ----------------------------------------------------------------
// Addresses are tricky:
// MEM0-3: 4096x8 (1 port). 8 bit data.
// MEM4-5: 2048x16. 16 bit data (2 pixels).
// MEM6-7: 1024x32. 32 bit data (4 pixels).
task read_dut_sram;
    input [6:0] idx;
    input [3:0] r;
    input [3:0] c;
    output [7:0] val;
    
    integer word_addr;
    integer linear_pixel_idx_in_group;
    reg [31:0] raw_word;
    begin
        // Define hierarchy paths
        // Assuming top module instance name is 'u_GTE' for RTL/GATE
        // For POST, usually 'u_CHIP' or similar. 
        // Using `ifdef to switch hierarchy prefix.
        
        `ifdef POST
             // Example path for Post-Sim
             #0; // Ensure event ordering
             // NOTE: Adjust 'u_CHIP' if your top module instance name is different in Testbed
        `else
             // Example path for RTL
             #0;
        `endif
        
        if(idx < 16) begin // MEM0: Images 0-15. Width 8.
            word_addr = idx*256 + r*16 + c;
            `ifdef POST
                val = u_CHIP.MEM0.Memory[word_addr];
            `else
                val = u_GTE.MEM0.Memory[word_addr];
            `endif
        end 
        else if (idx < 32) begin // MEM1
            word_addr = (idx-16)*256 + r*16 + c;
            `ifdef POST val = u_CHIP.MEM1.Memory[word_addr]; `else val = u_GTE.MEM1.Memory[word_addr]; `endif
        end
        else if (idx < 48) begin // MEM2
            word_addr = (idx-32)*256 + r*16 + c;
            `ifdef POST val = u_CHIP.MEM2.Memory[word_addr]; `else val = u_GTE.MEM2.Memory[word_addr]; `endif
        end
        else if (idx < 64) begin // MEM3
            word_addr = (idx-48)*256 + r*16 + c;
            `ifdef POST val = u_CHIP.MEM3.Memory[word_addr]; `else val = u_GTE.MEM3.Memory[word_addr]; `endif
        end
        else if (idx < 80) begin // MEM4: Width 16 (2 pixels).
            linear_pixel_idx_in_group = (idx-64)*256 + r*16 + c;
            word_addr = linear_pixel_idx_in_group / 2;
            `ifdef POST raw_word = u_CHIP.MEM4.Memory[word_addr]; `else raw_word = u_GTE.MEM4.Memory[word_addr]; `endif
            // If col%2==0 -> MSB (assuming big endian storage based on spec fig 19: [0][0] at high?)
            // Spec Fig 19: Addr 0 Data: {image[0][0], image[0][1]}
            // So [15:8] is pixel 0 (col 0), [7:0] is pixel 1 (col 1).
            if (linear_pixel_idx_in_group % 2 == 0) val = raw_word[15:8];
            else val = raw_word[7:0];
        end
        else if (idx < 96) begin // MEM5
            linear_pixel_idx_in_group = (idx-80)*256 + r*16 + c;
            word_addr = linear_pixel_idx_in_group / 2;
            `ifdef POST raw_word = u_CHIP.MEM5.Memory[word_addr]; `else raw_word = u_GTE.MEM5.Memory[word_addr]; `endif
            if (linear_pixel_idx_in_group % 2 == 0) val = raw_word[15:8];
            else val = raw_word[7:0];
        end
        else if (idx < 112) begin // MEM6: Width 32 (4 pixels).
            linear_pixel_idx_in_group = (idx-96)*256 + r*16 + c;
            word_addr = linear_pixel_idx_in_group / 4;
            `ifdef POST raw_word = u_CHIP.MEM6.Memory[word_addr]; `else raw_word = u_GTE.MEM6.Memory[word_addr]; `endif
            // Spec Fig 20: Addr 0: {img[0], img[1], img[2], img[3]}
            // [31:24]=0, [23:16]=1, [15:8]=2, [7:0]=3
            case(linear_pixel_idx_in_group % 4)
                0: val = raw_word[31:24];
                1: val = raw_word[23:16];
                2: val = raw_word[15:8];
                3: val = raw_word[7:0];
            endcase
        end
        else begin // MEM7
            linear_pixel_idx_in_group = (idx-112)*256 + r*16 + c;
            word_addr = linear_pixel_idx_in_group / 4;
            `ifdef POST raw_word = u_CHIP.MEM7.Memory[word_addr]; `else raw_word = u_GTE.MEM7.Memory[word_addr]; `endif
            case(linear_pixel_idx_in_group % 4)
                0: val = raw_word[31:24];
                1: val = raw_word[23:16];
                2: val = raw_word[15:8];
                3: val = raw_word[7:0];
            endcase
        end
    end
endtask

// ----------------------------------------------------------------
// Task: Pass Message
// ----------------------------------------------------------------
task pass_msg_task;
    begin
        $display("");
        $display("************************************************************");
        $display("  Congratulations! All patterns passed!                     ");
        $display("  Total Latency: %d", total_latency);
        $display("************************************************************");
        $finish;
    end
endtask

endmodule

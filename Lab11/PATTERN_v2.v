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
parameter PAT_NUM = 1000;
parameter IMG_SIZE = 16;
parameter NUM_IMG = 128;
parameter CYCLE = `CYCLE_TIME;

// ========================================
// File Handles & Memory
// ========================================
integer f_in, f_cmd, f_check;
integer pat_idx;
integer i, j;
integer latency;
integer total_latency;

reg [7:0] golden_mem [0 : IMG_SIZE*IMG_SIZE - 1]; // Buffer for expected image
reg [17:0] current_cmd;
reg [1:0]  opcode, funct;
reg [6:0]  ms, md;

// ========================================
// Clock Generation
// ========================================
initial clk = 0;
always #(CYCLE/2.0) clk = ~clk;

// ========================================
// Main Validation Flow
// ========================================
initial begin
    // 1. Initialization
    setup_files();
    reset_task();

    // 2. Load Data Phase
    input_data_task();

    // 3. Command & Verify Loop
    total_latency = 0;
    
    for (pat_idx = 0; pat_idx < PAT_NUM; pat_idx = pat_idx + 1) begin
        input_cmd_task();
        wait_process_task();
        verify_result_task();
        display_pass_task();
    end

    // 4. Final Report
    congratulation_task();
end

// ========================================
// Tasks
// ========================================

task setup_files;
    begin
        f_in    = $fopen("../00_TESTBED/data.txt", "r");
        f_cmd   = $fopen("../00_TESTBED/cmd.txt", "r");
        f_check = $fopen("../00_TESTBED/mem_check.txt", "r");

        if (f_in == 0 || f_cmd == 0 || f_check == 0) begin
            $display("------------------------------------------------------------");
            $display("    Error: Cannot open input/golden files!");
            $display("    Please run golden_gen.c first.");
            $display("------------------------------------------------------------");
            $finish;
        end
    end
endtask

task reset_task;
    begin
        rst_n = 1'b1;
        in_valid_data = 1'b0;
        in_valid_cmd = 1'b0;
        data = 8'b0;
        cmd = 18'b0;

        force clk = 0;
        # (CYCLE); rst_n = 1'b0; // Active low reset
        # (CYCLE * 3); rst_n = 1'b1;
        
        if(busy !== 1'b1) begin
            $display("------------------------------------------------------------");
            $display("    FAIL: Busy signal should be high after reset!");
            $display("------------------------------------------------------------");
            $finish;
        end

        # (CYCLE)
        release clk;
    end
endtask

task input_data_task;
    integer img, pix;
    reg [7:0] pixel_val;
    integer scan_res;
    begin
        // Wait for busy to fall? 
        // Spec 11: in_valid_data will come after reset.
        // Spec does not strictly say busy must be 0 before in_valid_data.
        // But usually we send data when system is ready.
        // Assuming busy is high during reset indicating "not ready", 
        // we might need to wait, but Spec rule 19 says "busy is limited to be tied low only when GTE is not busy."
        // Rule 9 says "busy should be reset to 1".
        // It's safer to just drive data as Spec 12 says "delivered ... when in_valid_data is tied high".
        
        @(negedge clk);
        in_valid_data = 1'b1;
        
        for(img = 0; img < NUM_IMG; img = img + 1) begin
            for(pix = 0; pix < IMG_SIZE * IMG_SIZE; pix = pix + 1) begin
                scan_res = $fscanf(f_in, "%h", pixel_val);
                data = pixel_val;
                @(negedge clk);
            end
        end
        
        in_valid_data = 1'b0;
        data = 8'bx;
    end
endtask

task input_cmd_task;
    integer scan_res;
    reg [1:0] r_opcode;
    reg [1:0] r_funct;
    reg [6:0] r_ms;
    reg [6:0] r_md;
    integer gap;
    begin
        // Read command
        scan_res = $fscanf(f_cmd, "%b", current_cmd);
        if (scan_res == 0) begin
            $display("Error reading cmd.txt"); $finish;
        end

        // Extract fields for debug
        {r_opcode, r_funct, r_ms, r_md} = current_cmd;
        opcode = r_opcode; funct = r_funct; ms = r_ms; md = r_md;

        // Read Golden result for this pattern
        for(i = 0; i < 256; i = i + 1) begin
            scan_res = $fscanf(f_check, "%h", golden_mem[i]);
        end

        // Wait random gap (2~4 cycles after previous done)
        // Note: The first command comes 2~4 cycles after in_valid_data falls.
        // Subsequent commands come 2~4 cycles after busy falls.
        gap = $urandom_range(2, 4);
        repeat(gap) @(negedge clk);

        in_valid_cmd = 1'b1;
        cmd = current_cmd;
        @(negedge clk);
        in_valid_cmd = 1'b0;
        cmd = 18'bx;
    end
endtask

task wait_process_task;
    begin
        latency = 0;
        // Wait for busy to rise (if it wasn't already high)
        // Spec says: "busy is limited to be tied low only when GTE is not busy."
        // Spec: "latency is clock cycles between falling edge of in_valid_cmd and negative edge of first cycle of busy"???
        // Wait, Rule 4: "latency is the clock cycles between the falling edge of the last cycle of in_valid_cmd and the negative edge of the first cycle of busy."
        // This phrasing is confusing. Usually latency ends when busy falls.
        // Let's re-read Rule 4 carefully.
        // "between falling edge ... of in_valid_cmd ... and negative edge of the first cycle of busy."
        // This sounds like "Time until busy asserts"? No, that's response time.
        // Usually Verification Latency = Time from CMD_DONE to BUSY_DONE.
        // Let's check Waveform.
        // Pattern 18-bit cmd high for 1 cycle.
        // Then busy goes high (maybe with delay).
        // Then busy goes low.
        // "If GTE finish ... busy should be tied low ... and then pattern will check".
        // So we wait for busy to fall.
        
        // while(busy === 1'b0) begin
        //      @(negedge clk);
        //      latency = latency + 1;
        //      if (latency > 5000) begin
        //         $display("FAIL: Busy signal did not assert in time!");
        //         $finish;
        //      end
        // end
        
        while(busy === 1'b1) begin
            @(negedge clk);
            latency = latency + 1;
            if (latency > 5000) begin
                $display("------------------------------------------------------------");
                $display("    FAIL: Latency Exceeded 5000 cycles at Pattern %d", pat_idx);
                $display("------------------------------------------------------------");
                $finish;
            end
        end
        total_latency = total_latency + latency;
    end
endtask

task verify_result_task;
    integer r, c, pix_idx;
    reg [7:0] dut_val;
    reg [31:0] raw_word;
    integer addr_base;
    integer word_addr;
    begin
        // Access SRAM Backdoor based on `md`
        // Memory mapping logic
        // 0-63: 8-bit SRAMs (MEM0-MEM3)
        // 64-95: 16-bit SRAMs (MEM4-MEM5)
        // 96-127: 32-bit SRAMs (MEM6-MEM7)
        
        for(r=0; r<16; r=r+1) begin
            for(c=0; c<16; c=c+1) begin
                pix_idx = r*16 + c;
                
                // Fetch from DUT
                if (md < 16) 
                    dut_val = u_GTE.MEM0.Memory[md * 256 + pix_idx];
                else if (md < 32)
                    dut_val = u_GTE.MEM1.Memory[(md-16) * 256 + pix_idx];
                else if (md < 48)
                    dut_val = u_GTE.MEM2.Memory[(md-32) * 256 + pix_idx];
                else if (md < 64)
                    dut_val = u_GTE.MEM3.Memory[(md-48) * 256 + pix_idx];
                else if (md < 80) begin
                    // MEM4: 16-bit. 2 pixels per word.
                    word_addr = (md-64) * 128 + (pix_idx / 2);
                    raw_word = u_GTE.MEM4.Memory[word_addr];
                    // Spec Figure 19: Addr 0 Data {img[0][0], img[0][1]}
                    // Assuming Big Endian packing in word: [15:8] is pixel 0 (even), [7:0] is pixel 1 (odd)
                    if (pix_idx % 2 == 0) dut_val = raw_word[15:8];
                    else                  dut_val = raw_word[7:0];
                end
                else if (md < 96) begin
                    // MEM5: 16-bit
                    word_addr = (md-80) * 128 + (pix_idx / 2);
                    raw_word = u_GTE.MEM5.Memory[word_addr];
                    if (pix_idx % 2 == 0) dut_val = raw_word[15:8];
                    else                  dut_val = raw_word[7:0];
                end
                else if (md < 112) begin
                    // MEM6: 32-bit. 4 pixels per word.
                    // Spec Fig 20: Addr 0 {p0, p1, p2, p3}
                    word_addr = (md-96) * 64 + (pix_idx / 4);
                    raw_word = u_GTE.MEM6.Memory[word_addr];
                    case(pix_idx % 4)
                        0: dut_val = raw_word[31:24];
                        1: dut_val = raw_word[23:16];
                        2: dut_val = raw_word[15:8];
                        3: dut_val = raw_word[7:0];
                    endcase
                end
                else begin
                    // MEM7: 32-bit
                    word_addr = (md-112) * 64 + (pix_idx / 4);
                    raw_word = u_GTE.MEM7.Memory[word_addr];
                    case(pix_idx % 4)
                        0: dut_val = raw_word[31:24];
                        1: dut_val = raw_word[23:16];
                        2: dut_val = raw_word[15:8];
                        3: dut_val = raw_word[7:0];
                    endcase
                end

                // Compare
                if (dut_val !== golden_mem[pix_idx]) begin
                    $display("------------------------------------------------------------");
                    $display("    FAIL: Pattern %0d, Pixel (%0d, %0d) Mismatch!", pat_idx, r, c);
                    $display("    Opcode: %b, Funct: %b, MS: %d, MD: %d", opcode, funct, ms, md);
                    $display("    Golden: %d, Yours: %d", golden_mem[pix_idx], dut_val);
                    $display("------------------------------------------------------------");
                    $finish;
                end
            end
        end
    end
endtask

task display_pass_task;
    begin
        if(pat_idx % 50 == 0) 
            $display("\033[0;34mPASS PATTERN NO. %4d, Latency: %4d\033[m", pat_idx, latency);
    end
endtask

task congratulation_task;
    begin
        $display("\n");
        $display("------------------------------------------------------------");
        $display("    Congratulations! All patterns passed.");
        $display("    Total Patterns: %d", PAT_NUM);
        $display("    Total Latency : %d cycles", total_latency);
        $display("------------------------------------------------------------");
        $finish;
    end
endtask

endmodule
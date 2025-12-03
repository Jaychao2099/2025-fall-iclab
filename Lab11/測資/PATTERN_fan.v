//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   ICLAB 2025 Fall 
// Lab11 Exercise : Geometric Transform Engine (GTE)
//      File Name : PATTERN.v
//      Module    : Pattern Verification
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

`ifdef RTL
    `define CYCLE_TIME  5.4
`elsif GATE
    `define CYCLE_TIME  5.4
`elsif POST
    `define CYCLE_TIME  12.0
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

// ========================================
// I/O declaration
// ========================================
output reg        clk, rst_n;
output reg        in_valid_data;
output reg  [7:0] data;
output reg        in_valid_cmd;
output reg [17:0] cmd;

input busy;

// ========================================
// clock
// ========================================
real CYCLE = `CYCLE_TIME;
always  #(CYCLE/2.0) clk = ~clk; //clock

// ========================================
// integer & parameter
// ========================================
integer i, j, k;
integer pat;
integer total_pat = 1000; // Testing patterns count
integer total_lat, latency;
integer gap;
integer seed = 42069;

// 128 images, 16x16 pixels
reg [7:0] golden_data [0:127][0:15][0:15];
reg [7:0] temp_img    [0:15][0:15]; // Source buffer for calculation
reg [7:0] result_img  [0:15][0:15]; // Result buffer

// Command fields
reg [1:0] opcode;
reg [1:0] funct;
reg [6:0] ms; // Source
reg [6:0] md; // Destination

// ========================================
// Main Flow
// ========================================
initial begin
    reset_task;
    input_data_task;
    total_lat = 0;
    for (pat = 0; pat < total_pat; pat = pat + 1) begin
        latency = 0;
        input_cmd_task;
        wait_busy_task;
        total_lat = total_lat + latency;
        check_ans_task;
        display_pass_task;
    end
    
    you_pass_task;
    $finish;
end

// ========================================
// Tasks
// ========================================

task reset_task; begin
    clk = 0;
    rst_n = 1;
    in_valid_data = 0;
    data = 8'bx;
    in_valid_cmd = 0;
    cmd = 18'bx;
    
    force clk = 0;
    
    #CYCLE; rst_n = 0; 
    #CYCLE; rst_n = 1;
    
    if (busy !== 1) begin
        $display("Error: busy should be 1 after reset");
        $finish;
    end
    #CYCLE; release clk;
end endtask

task input_data_task; begin
    $display("--------------------------------------");
    $display("  Start Loading 128 Images ...        ");
    $display("--------------------------------------");
    
    @(negedge clk);
    in_valid_data = 1;
    
    for (i = 0; i < 128; i = i + 1) begin // 128 Images
        for (j = 0; j < 16; j = j + 1) begin // Row
            for (k = 0; k < 16; k = k + 1) begin // Col
                data = $random(seed) % 256;
                golden_data[i][j][k] = data;
                @(negedge clk);
            end
        end
    end
    
    in_valid_data = 0;
    data = 8'bx;
end endtask

task input_cmd_task; begin
    // Randomize Command
    opcode = $random(seed) % 4;
    funct  = $random(seed) % 4;
    ms     = $random(seed) % 128;
    md     = $random(seed) % 128;
    if({opcode, funct} == 4'b0111) begin
        funct = 2'b00; // Avoid invalid command
    end
    
    // Gap between data/busy and command (2~4 cycles)
    gap = 2 + ($random(seed) % 3);
    repeat(gap) @(negedge clk);
    // Send Command
    in_valid_cmd = 1;
    cmd = {opcode, funct, ms, md};
    
    // Update Golden Model immediately
    run_golden_model(opcode, funct, ms, md);
    
    @(negedge clk);
    in_valid_cmd = 0;
    cmd = 18'bx;
end endtask

task wait_busy_task; begin
    // Wait for busy to fall
    while (busy === 1) begin
        latency = latency + 1;
        @(negedge clk);
    end
end endtask

// ========================================
// SRAM Access & Checking
// ========================================
task check_ans_task; 
    integer r, c;
    reg [7:0] sram_val;
begin
    // Check the Destination Image (md) in SRAM
    for (r = 0; r < 16; r = r + 1) begin
        for (c = 0; c < 16; c = c + 1) begin
            sram_val = get_sram_data(md, r, c);
            
            if (sram_val !== golden_data[md][r][c]) begin
                $display("\n--------------------------------------");
                $display("  ERROR at Pattern %0d", pat);
                $display("  Image ID: %0d, Row: %0d, Col: %0d", md, r, c);
                $display("  Opcode: %b, Funct: %b", opcode, funct);
                $display("  Expected: %d, Got: %d", golden_data[md][r][c], sram_val);
                $display("--------------------------------------");
                $finish;
            end
        end
    end
end endtask

// Function to read data from specific SRAM based on Image ID
function [7:0] get_sram_data;
    input [6:0] img_idx;
    input [3:0] row;
    input [3:0] col;
    
    integer sram_idx; // 0~15 relative index
    integer addr;
    reg [31:0] raw_word;
    
    begin
        sram_idx = img_idx % 16; // 0~15
        
        // Define path prefix macro to handle RTL/GATE/POST
        `ifdef RTL
            `define MEM_PATH(mem) TESTBED.u_GTE.mem.Memory
        `elsif GATE
            `define MEM_PATH(mem) TESTBED.u_GTE.mem.Memory
        `elsif POST
            `define MEM_PATH(mem) TESTBED.u_CHIP.CORE.mem.Memory
        `endif

        if (img_idx < 64) begin 
            // MEM0 ~ MEM3 (4096x8) - 1 pixel per address
            addr = sram_idx * 256 + row * 16 + col;
            case (img_idx / 16)
                0: get_sram_data = `MEM_PATH(MEM0)[addr];
                1: get_sram_data = `MEM_PATH(MEM1)[addr];
                2: get_sram_data = `MEM_PATH(MEM2)[addr];
                3: get_sram_data = `MEM_PATH(MEM3)[addr];
            endcase
        end
        else if (img_idx < 96) begin
            // MEM4 ~ MEM5 (2048x16) - 2 pixels per address
            addr = sram_idx * 128 + row * 8 + (col / 2);
            case (img_idx / 16) // 4 or 5
                4: raw_word = `MEM_PATH(MEM4)[addr];
                5: raw_word = `MEM_PATH(MEM5)[addr];
            endcase
            // Spec: Data {image[0][0], image[0][1]}
            if (col % 2 == 0) get_sram_data = raw_word[15:8];
            else              get_sram_data = raw_word[7:0];
        end
        else begin
            // MEM6 ~ MEM7 (1024x32) - 4 pixels per address
            addr = sram_idx * 64 + row * 4 + (col / 4);
            case (img_idx / 16) // 6 or 7
                6: raw_word = `MEM_PATH(MEM6)[addr];
                7: raw_word = `MEM_PATH(MEM7)[addr];
            endcase
            // Spec: Data {p0, p1, p2, p3}
            case (col % 4)
                0: get_sram_data = raw_word[31:24];
                1: get_sram_data = raw_word[23:16];
                2: get_sram_data = raw_word[15:8];
                3: get_sram_data = raw_word[ 7: 0];
            endcase
        end
    end
endfunction

// ========================================
// Golden Model Logic
// ========================================
task run_golden_model;
    input [1:0] op;
    input [1:0] fn;
    input [6:0] s_idx;
    input [6:0] d_idx;
    integer r, c;
    integer src_r, src_c;
    integer shift_amt;
    integer blk_r, blk_c;   // Block index
    integer in_r, in_c;     // Inner block index
    integer linear_idx;     // Linear index inside block
    integer mapped_idx;     // Source index after mapping
    begin
        // 1. Copy Source to Temp
        for(r=0; r<16; r=r+1)
            for(c=0; c<16; c=c+1)
                temp_img[r][c] = golden_data[s_idx][r][c];
        
        // 2. Perform Operation
        for(r=0; r<16; r=r+1) begin
            for(c=0; c<16; c=c+1) begin
                
                case(op)
                    2'b00: begin // Mirror / Transpose
                        case(fn)
                            2'b00: result_img[r][c] = temp_img[15-r][c]; // MX
                            2'b01: result_img[r][c] = temp_img[r][15-c]; // MY
                            2'b10: result_img[r][c] = temp_img[c][r];    // TRP
                            2'b11: result_img[r][c] = temp_img[15-c][15-r]; // STRP
                        endcase
                    end
                    
                    2'b01: begin // Rotation
                        case(fn)
                            2'b00: result_img[c][15-r] = temp_img[r][c]; // R90
                            2'b01: result_img[15-r][15-c] = temp_img[r][c]; // R180
                            2'b10: result_img[15-c][r] = temp_img[r][c]; // R270
                            default: result_img[r][c] = temp_img[r][c];
                        endcase
                    end
                    
                    2'b10: begin // Shift (Amount = 5, with Mirror Padding)
                        shift_amt = 5;
                        case(fn)
                            2'b00: begin // RS
                                src_c = c - shift_amt;
                                if(src_c < 0) src_c = -1 - src_c;
                                result_img[r][c] = temp_img[r][src_c];
                            end
                            2'b01: begin // LS
                                src_c = c + shift_amt;
                                if(src_c > 15) src_c = 15 - (src_c - 16);
                                result_img[r][c] = temp_img[r][src_c];
                            end
                            2'b10: begin // US
                                src_r = r + shift_amt;
                                if(src_r > 15) src_r = 15 - (src_r - 16);
                                result_img[r][c] = temp_img[src_r][c];
                            end
                            2'b11: begin // DS
                                src_r = r - shift_amt;
                                if(src_r < 0) src_r = -1 - src_r;
                                result_img[r][c] = temp_img[src_r][c];
                            end
                        endcase
                    end
                    
                    2'b11: begin // Reorder (Zigzag / Morton)
                        case(fn)
                            2'b00: begin // ZZ4 (4x4 Zig-zag)
                                blk_r = r / 4; blk_c = c / 4;
                                in_r  = r % 4; in_c  = c % 4;
                                linear_idx = in_r * 4 + in_c;
                                mapped_idx = get_zz4_idx(linear_idx);
                                result_img[r][c] = temp_img[blk_r*4 + mapped_idx/4][blk_c*4 + mapped_idx%4];
                            end
                            
                            2'b01: begin // ZZ8 (8x8 Zig-zag)
                                blk_r = r / 8; blk_c = c / 8;
                                in_r  = r % 8; in_c  = c % 8;
                                linear_idx = in_r * 8 + in_c;
                                mapped_idx = get_zz8_idx(linear_idx);
                                result_img[r][c] = temp_img[blk_r*8 + mapped_idx/8][blk_c*8 + mapped_idx%8];
                            end
                            
                            2'b10: begin // MO4 (4x4 Morton)
                                blk_r = r / 4; blk_c = c / 4;
                                in_r  = r % 4; in_c  = c % 4;
                                linear_idx = in_r * 4 + in_c;
                                mapped_idx = get_mo4_idx(linear_idx);
                                result_img[r][c] = temp_img[blk_r*4 + mapped_idx/4][blk_c*4 + mapped_idx%4];
                            end
                            
                            2'b11: begin // MO8 (8x8 Morton)
                                blk_r = r / 8; blk_c = c / 8;
                                in_r  = r % 8; in_c  = c % 8;
                                linear_idx = in_r * 8 + in_c;
                                mapped_idx = get_mo8_idx(linear_idx);
                                result_img[r][c] = temp_img[blk_r*8 + mapped_idx/8][blk_c*8 + mapped_idx%8];
                            end
                        endcase
                    end
                endcase
            end
        end
        
        // 3. Write Back to Golden Data
        for(r=0; r<16; r=r+1)
            for(c=0; c<16; c=c+1)
                golden_data[d_idx][r][c] = result_img[r][c];
    end
endtask

// 4x4 Zig-zag Mapping Table
function integer get_zz4_idx;
    input integer idx;
    begin
        case(idx)
            0:  get_zz4_idx = 0;   1:  get_zz4_idx = 1;   2:  get_zz4_idx = 4;   3:  get_zz4_idx = 8;
            4:  get_zz4_idx = 5;   5:  get_zz4_idx = 2;   6:  get_zz4_idx = 3;   7:  get_zz4_idx = 6;
            8:  get_zz4_idx = 9;   9:  get_zz4_idx = 12;  10: get_zz4_idx = 13;  11: get_zz4_idx = 10;
            12: get_zz4_idx = 7;   13: get_zz4_idx = 11;  14: get_zz4_idx = 14;  15: get_zz4_idx = 15;
            default: get_zz4_idx = 0;
        endcase
    end
endfunction

// 4x4 Morton Mapping Table
function integer get_mo4_idx;
    input integer idx;
    begin
        case(idx)
            0:  get_mo4_idx = 0;   1:  get_mo4_idx = 1;   2:  get_mo4_idx = 4;   3:  get_mo4_idx = 5;
            4:  get_mo4_idx = 2;   5:  get_mo4_idx = 3;   6:  get_mo4_idx = 6;   7:  get_mo4_idx = 7;
            8:  get_mo4_idx = 8;   9:  get_mo4_idx = 9;   10: get_mo4_idx = 12;  11: get_mo4_idx = 13;
            12: get_mo4_idx = 10;  13: get_mo4_idx = 11;  14: get_mo4_idx = 14;  15: get_mo4_idx = 15;
            default: get_mo4_idx = 0;
        endcase
    end
endfunction

// 8x8 Zig-zag Mapping Table
function integer get_zz8_idx;
    input integer idx;
    begin
        case(idx)
            0: get_zz8_idx = 0;   1: get_zz8_idx = 1;   2: get_zz8_idx = 8;   3: get_zz8_idx = 16;
            4: get_zz8_idx = 9;   5: get_zz8_idx = 2;   6: get_zz8_idx = 3;   7: get_zz8_idx = 10;
            8: get_zz8_idx = 17;  9: get_zz8_idx = 24;  10: get_zz8_idx = 32; 11: get_zz8_idx = 25;
            12: get_zz8_idx = 18; 13: get_zz8_idx = 11; 14: get_zz8_idx = 4;  15: get_zz8_idx = 5;
            16: get_zz8_idx = 12; 17: get_zz8_idx = 19; 18: get_zz8_idx = 26; 19: get_zz8_idx = 33;
            20: get_zz8_idx = 40; 21: get_zz8_idx = 48; 22: get_zz8_idx = 41; 23: get_zz8_idx = 34;
            24: get_zz8_idx = 27; 25: get_zz8_idx = 20; 26: get_zz8_idx = 13; 27: get_zz8_idx = 6;
            28: get_zz8_idx = 7;  29: get_zz8_idx = 14; 30: get_zz8_idx = 21; 31: get_zz8_idx = 28;
            32: get_zz8_idx = 35; 33: get_zz8_idx = 42; 34: get_zz8_idx = 49; 35: get_zz8_idx = 56;
            36: get_zz8_idx = 57; 37: get_zz8_idx = 50; 38: get_zz8_idx = 43; 39: get_zz8_idx = 36;
            40: get_zz8_idx = 29; 41: get_zz8_idx = 22; 42: get_zz8_idx = 15; 43: get_zz8_idx = 23;
            44: get_zz8_idx = 30; 45: get_zz8_idx = 37; 46: get_zz8_idx = 44; 47: get_zz8_idx = 51;
            48: get_zz8_idx = 58; 49: get_zz8_idx = 59; 50: get_zz8_idx = 52; 51: get_zz8_idx = 45;
            52: get_zz8_idx = 38; 53: get_zz8_idx = 31; 54: get_zz8_idx = 39; 55: get_zz8_idx = 46;
            56: get_zz8_idx = 53; 57: get_zz8_idx = 60; 58: get_zz8_idx = 61; 59: get_zz8_idx = 54;
            60: get_zz8_idx = 47; 61: get_zz8_idx = 55; 62: get_zz8_idx = 62; 63: get_zz8_idx = 63;
            default: get_zz8_idx = 0;
        endcase
    end
endfunction

// 8x8 Morton Mapping Table
function integer get_mo8_idx;
    input integer idx;
    begin
        case(idx)
            0: get_mo8_idx = 0;   1: get_mo8_idx = 1;   2: get_mo8_idx = 8;   3: get_mo8_idx = 9;
            4: get_mo8_idx = 2;   5: get_mo8_idx = 3;   6: get_mo8_idx = 10;  7: get_mo8_idx = 11;
            8: get_mo8_idx = 16;  9: get_mo8_idx = 17;  10: get_mo8_idx = 24; 11: get_mo8_idx = 25;
            12: get_mo8_idx = 18; 13: get_mo8_idx = 19; 14: get_mo8_idx = 26; 15: get_mo8_idx = 27;
            16: get_mo8_idx = 4;  17: get_mo8_idx = 5;  18: get_mo8_idx = 12; 19: get_mo8_idx = 13;
            20: get_mo8_idx = 6;  21: get_mo8_idx = 7;  22: get_mo8_idx = 14; 23: get_mo8_idx = 15;
            24: get_mo8_idx = 20; 25: get_mo8_idx = 21; 26: get_mo8_idx = 28; 27: get_mo8_idx = 29;
            28: get_mo8_idx = 22; 29: get_mo8_idx = 23; 30: get_mo8_idx = 30; 31: get_mo8_idx = 31;
            32: get_mo8_idx = 32; 33: get_mo8_idx = 33; 34: get_mo8_idx = 40; 35: get_mo8_idx = 41;
            36: get_mo8_idx = 34; 37: get_mo8_idx = 35; 38: get_mo8_idx = 42; 39: get_mo8_idx = 43;
            40: get_mo8_idx = 48; 41: get_mo8_idx = 49; 42: get_mo8_idx = 56; 43: get_mo8_idx = 57;
            44: get_mo8_idx = 50; 45: get_mo8_idx = 51; 46: get_mo8_idx = 58; 47: get_mo8_idx = 59;
            48: get_mo8_idx = 36; 49: get_mo8_idx = 37; 50: get_mo8_idx = 44; 51: get_mo8_idx = 45;
            52: get_mo8_idx = 38; 53: get_mo8_idx = 39; 54: get_mo8_idx = 46; 55: get_mo8_idx = 47;
            56: get_mo8_idx = 52; 57: get_mo8_idx = 53; 58: get_mo8_idx = 60; 59: get_mo8_idx = 61;
            60: get_mo8_idx = 54; 61: get_mo8_idx = 55; 62: get_mo8_idx = 62; 63: get_mo8_idx = 63;
            default: get_mo8_idx = 0;
        endcase
    end
endfunction

task display_pass_task; begin
    $display("PASS Pattern %0d", pat);
end endtask

task you_pass_task; begin
    $display("----------------------------------------------------------------------------------------------------------------------");
    $display("                                                  Congratulations!                                                    ");
    $display("                                           You have passed all patterns!                                              ");
    $display("                                                execution cycles = %7d                                               ", total_lat);
    $display("----------------------------------------------------------------------------------------------------------------------");
end endtask

endmodule
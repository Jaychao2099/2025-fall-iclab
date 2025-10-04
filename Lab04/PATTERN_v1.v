//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   (C) Copyright Laboratory System Integration and Silicon Implementation
//   All Right Reserved
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   ICLAB 2025 Fall
//   Lab04 Exercise		: Convolution Neural Network 
//   Author     		: Chung-Shuo Lee
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//   File Name   : CNN.v
//   Module Name : CNN
//   Release version : V 1.0
//
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

`define CYCLE_TIME      45.0
`define PAT_NUM         200
`define MAX_LATENCY     150
`define ERROR_TOLERANCE 1.0e-6

module PATTERN(
    // Output Port
    clk,
    rst_n,
    in_valid,
    Image,
    Kernel_ch1,
    Kernel_ch2,
	Weight_Bias,
    task_number,
    mode,
    capacity_cost,
    // Input Port
    out_valid,
    out
    );

//---------------------------------------------------------------------
//   PORT DECLARATION          
//---------------------------------------------------------------------
output reg          clk, rst_n, in_valid;
output reg [31:0]   Image;
output reg [31:0]   Kernel_ch1;
output reg [31:0]   Kernel_ch2;
output reg [31:0]   Weight_Bias;
output reg          task_number;
output reg [1:0]    mode;
output reg [3:0]    capacity_cost;

input           out_valid;
input   [31:0]  out;

//---------------------------------------------------------------------
//   PARAMETER & INTEGER DECLARATION
//---------------------------------------------------------------------
real CYCLE = `CYCLE_TIME;

parameter inst_sig_width = 23;
parameter inst_exp_width = 8;
parameter inst_ieee_compliance = 0;
parameter inst_arch_type = 0;
parameter inst_arch = 0;

integer i_pat;
integer latency_counter;
integer total_latency;
integer seed = 12345;

// Golden Model Storage
// Task 0 specific
real image_g[1:0][5:0][5:0]; // [channel][row][col]
real kernel_ch1_g[1:0][2:0][2:0]; // [kernel_num][row][col]
real kernel_ch2_g[1:0][2:0][2:0]; // [kernel_num][row][col]
real weight_bias_g[56:0];
real golden_out_task0[2:0];

// Task 1 specific
real image_t1_g[5:0][5:0];
real kernel_A_g[2:0][2:0], kernel_B_g[2:0][2:0], kernel_C_g[2:0][2:0], kernel_D_g[2:0][2:0];
real cost_g[3:0];
integer capacity_g;
reg [3:0] golden_out_task1;

// Stimulus Storage
reg [31:0] image_s[71:0];
reg [31:0] kernel_ch1_s[17:0];
reg [31:0] kernel_ch2_s[17:0];
reg [31:0] weight_bias_s[56:0];
reg [3:0]  capacity_cost_s[4:0];
reg        task_number_s;
reg [1:0]  mode_s;


//---------------------------------------------------------------------
//   Clock and Reset Generation
//---------------------------------------------------------------------
always #(`CYCLE_TIME/2.0) clk = ~clk;

initial begin
    clk = 1'b0;
    rst_n = 1'b1;
    total_latency = 0;
    reset_task;

    for (i_pat = 0; i_pat < `PAT_NUM; i_pat = i_pat + 1) begin
        generate_stimulus_task;
        calculate_golden_model_task;
        drive_and_check_task;
        $display("PASS PATTERN NO.%4d, Latency: %3d cycles", i_pat, latency_counter);
    end

    pass_task;
end

//---------------------------------------------------------------------
//   TASKS for Modular Design
//---------------------------------------------------------------------
task reset_task;
begin
    force clk = 1'b0;
    rst_n = 1'b1;
    in_valid = 1'b0;
    Image = 32'hxxxxxxxx;
    Kernel_ch1 = 32'hxxxxxxxx;
    Kernel_ch2 = 32'hxxxxxxxx;
    Weight_Bias = 32'hxxxxxxxx;
    task_number = 1'bx;
    mode = 2'bxx;
    capacity_cost = 4'hx;
    
    #(`CYCLE_TIME * 2);
    rst_n = 1'b0;
    #(`CYCLE_TIME * 2);

    // Specification Assertion: Check if outputs are reset to 0
    if (out_valid !== 1'b0 || out !== 32'b0) begin
        $display("************************************************************");  
        $display("                          FAIL!                              ");    
        $display("*  Output signal should be 0 after initial RESET at %8t   *",$time);
        $display("************************************************************");
        $finish;
    end

    rst_n = 1'b1;
    #(`CYCLE_TIME);
    release clk;
end
endtask

task generate_stimulus_task;
    integer i, j, k;
begin
    // task_number_s = $urandom_range(0, 1);
    task_number_s = 1'b0;
    // task_number_s = 1'b1;

    mode_s = $urandom_range(0, 3);
    
    if (task_number_s == 1'b0) begin // Task 0
        // Generate Image (6x6x2)
        for (i = 0; i < 2; i = i + 1) begin
            for (j = 0; j < 6; j = j + 1) begin
                for (k = 0; k < 6; k = k + 1) begin
                    image_g[i][j][k] = rand_real();
                    image_s[i*36 + j*6 + k] = real_to_bits(image_g[i][j][k]);
                end
            end
        end
        // Generate Kernels (two 3x3x2 kernels)
        for (i = 0; i < 2; i = i + 1) begin // kernel num
            for (j = 0; j < 3; j = j + 1) begin
                for (k = 0; k < 3; k = k + 1) begin
                    kernel_ch1_g[i][j][k] = rand_real();
                    kernel_ch2_g[i][j][k] = rand_real();
                    // Raster scan order: k0_ch1(0,0), k0_ch2(0,0), k0_ch1(0,1), k0_ch2(0,1)...
                    kernel_ch1_s[i*9 + j*3 + k] = real_to_bits(kernel_ch1_g[i][j][k]);
                    kernel_ch2_s[i*9 + j*3 + k] = real_to_bits(kernel_ch2_g[i][j][k]);
                end
            end
        end
        // Generate Weights & Biases (5x8 + bias -> 41, 3x5 + bias -> 16)
        for (i = 0; i < 57; i = i + 1) begin
            weight_bias_g[i] = rand_real();
            weight_bias_s[i] = real_to_bits(weight_bias_g[i]);
        end
    end else begin // Task 1
        // Generate Image (6x6x1)
        for (j = 0; j < 6; j = j + 1) begin
            for (k = 0; k < 6; k = k + 1) begin
                image_t1_g[j][k] = rand_real();
                image_s[j*6 + k] = real_to_bits(image_t1_g[j][k]);
            end
        end
        // Generate 4 Kernels (3x3)
        for(j=0; j<3; j=j+1) for(k=0; k<3; k=k+1) kernel_A_g[j][k] = rand_real();
        for(j=0; j<3; j=j+1) for(k=0; k<3; k=k+1) kernel_B_g[j][k] = rand_real();
        for(j=0; j<3; j=j+1) for(k=0; k<3; k=k+1) kernel_C_g[j][k] = rand_real();
        for(j=0; j<3; j=j+1) for(k=0; k<3; k=k+1) kernel_D_g[j][k] = rand_real();

        // Pack kernels for stimulus stream
        for (i=0; i<9; i=i+1) begin
            kernel_ch1_s[i*2]   = real_to_bits(kernel_A_g[i/3][i%3]);
            kernel_ch1_s[i*2+1] = real_to_bits(kernel_B_g[i/3][i%3]);
            kernel_ch2_s[i*2]   = real_to_bits(kernel_C_g[i/3][i%3]);
            kernel_ch2_s[i*2+1] = real_to_bits(kernel_D_g[i/3][i%3]);
        end
        // Generate Capacity and Costs
        capacity_g = $urandom_range(1, 15);
        for(i=0; i<4; i=i+1) cost_g[i] = $urandom_range(1, 8);
        capacity_cost_s[0] = capacity_g;
        capacity_cost_s[1] = cost_g[0];
        capacity_cost_s[2] = cost_g[1];
        capacity_cost_s[3] = cost_g[2];
        capacity_cost_s[4] = cost_g[3];
    end
end
endtask

task calculate_golden_model_task;
    // Layer arrays
    real padded_image[1:0][7:0][7:0];
    real conv_out[1:0][5:0][5:0];
    real maxpool_out[1:0][1:0][1:0];
    real activation_out[1:0][1:0][1:0];
    real fc1_in[7:0];
    real fc1_out[4:0];
    real leaky_relu_out[4:0];
    real fc2_out[2:0];
    
    integer i, j, k, ch, kr, kc, pr, pc;
begin
    if (task_number_s == 1'b0) begin
        // --- Stage 1: Padding (8x8x2) ---
        for (ch = 0; ch < 2; ch = ch + 1) begin
            perform_padding(image_g[ch], padded_image[ch]);
        end

        // --- Stage 2: Convolution (6x6x2) ---
        for (ch = 0; ch < 2; ch = ch + 1) conv_out[ch] = '{default:0.0};
        // Kernel 0
        for (pr=0; pr<6; pr=pr+1) for(pc=0; pc<6; pc=pc+1) for (kr=0; kr<3; kr=kr+1) for(kc=0; kc<3; kc=kc+1) begin
            conv_out[0][pr][pc] = conv_out[0][pr][pc] + padded_image[0][pr+kr][pc+kc] * kernel_ch1_g[0][kr][kc];
            conv_out[0][pr][pc] = conv_out[0][pr][pc] + padded_image[1][pr+kr][pc+kc] * kernel_ch2_g[0][kr][kc];
        end
        // Kernel 1
        for (pr=0; pr<6; pr=pr+1) for(pc=0; pc<6; pc=pc+1) for (kr=0; kr<3; kr=kr+1) for(kc=0; kc<3; kc=kc+1) begin
            conv_out[1][pr][pc] = conv_out[1][pr][pc] + padded_image[0][pr+kr][pc+kc] * kernel_ch1_g[1][kr][kc];
            conv_out[1][pr][pc] = conv_out[1][pr][pc] + padded_image[1][pr+kr][pc+kc] * kernel_ch2_g[1][kr][kc];
        end

        // --- Stage 3: Max Pooling (2x2x2) ---
        for (ch=0; ch<2; ch=ch+1) for(pr=0; pr<2; pr=pr+1) for(pc=0; pc<2; pc=pc+1) begin
            maxpool_out[ch][pr][pc] = find_max(conv_out[ch], pr*3, pc*3);
        end
        
        // --- Stage 4: Activation (tanh or swish) ---
        for (ch=0; ch<2; ch=ch+1) for(pr=0; pr<2; pr=pr+1) for(pc=0; pc<2; pc=pc+1) begin
             if (mode_s == 2'b00 || mode_s == 2'b10) activation_out[ch][pr][pc] = tanh(maxpool_out[ch][pr][pc]);
             else activation_out[ch][pr][pc] = swish(maxpool_out[ch][pr][pc]);
        end

        // --- Stage 5: Fully Connected Layer 1 (Flatten -> 8 -> 5) ---
        fc1_in[0] = activation_out[0][0][0]; fc1_in[1] = activation_out[0][0][1];
        fc1_in[2] = activation_out[0][1][0]; fc1_in[3] = activation_out[0][1][1];
        fc1_in[4] = activation_out[1][0][0]; fc1_in[5] = activation_out[1][0][1];
        fc1_in[6] = activation_out[1][1][0]; fc1_in[7] = activation_out[1][1][1];

        for (i=0; i<5; i=i+1) begin
            fc1_out[i] = weight_bias_g[i*8+8]; // bias
            for (j=0; j<8; j=j+1) begin
                fc1_out[i] = fc1_out[i] + fc1_in[j] * weight_bias_g[i*8+j];
            end
        end
        
        // --- Stage 6: Leaky ReLU ---
        for (i=0; i<5; i=i+1) leaky_relu_out[i] = (fc1_out[i] < 0) ? 0.01 * fc1_out[i] : fc1_out[i];

        // --- Stage 7: Fully Connected Layer 2 (5 -> 3) ---
        for (i=0; i<3; i=i+1) begin
            fc2_out[i] = weight_bias_g[40 + i*5 + 5]; // bias
            for (j=0; j<5; j=j+1) begin
                fc2_out[i] = fc2_out[i] + leaky_relu_out[j] * weight_bias_g[40 + i*5+j];
            end
        end
        
        // --- Stage 8: Softmax ---
        perform_softmax(fc2_out, golden_out_task0);

    end else begin // Task 1 Golden Model
        real sum_results[3:0];
        real max_sum = -1.0e38; // A very small number
        integer current_cost;
        real current_sum;

        sum_results[0] = run_cnn_task1(image_t1_g, kernel_A_g);
        sum_results[1] = run_cnn_task1(image_t1_g, kernel_B_g);
        sum_results[2] = run_cnn_task1(image_t1_g, kernel_C_g);
        sum_results[3] = run_cnn_task1(image_t1_g, kernel_D_g);
        
        golden_out_task1 = 4'b0000;
        
        // Iterate through all 16 combinations
        for (i = 0; i < 16; i = i + 1) begin
            current_cost = 0;
            current_sum = 0.0;
            if (i[0]) begin current_cost = current_cost + cost_g[0]; current_sum = current_sum + sum_results[0]; end
            if (i[1]) begin current_cost = current_cost + cost_g[1]; current_sum = current_sum + sum_results[1]; end
            if (i[2]) begin current_cost = current_cost + cost_g[2]; current_sum = current_sum + sum_results[2]; end
            if (i[3]) begin current_cost = current_cost + cost_g[3]; current_sum = current_sum + sum_results[3]; end

            if (current_cost <= capacity_g) begin
                if (current_sum > max_sum) begin
                    max_sum = current_sum;
                    golden_out_task1 = i;
                end
            end
        end
    end
end
endtask

task drive_and_check_task;
    integer i;
    real your_real, golden_real, abs_error;
    reg [31:0] golden_bits;
begin
    // Insert random delay (timing jitter) before starting
    repeat($urandom_range(2, 5)) @(negedge clk);
    
    // Drive inputs
    @(negedge clk);
    in_valid = 1'b1;
    task_number = task_number_s;
    mode = mode_s;
    if (task_number_s == 1'b0) begin // Task 0
        for (i = 0; i < 72; i = i + 1) begin
            Image = image_s[i];
            if (i < 18) begin
                Kernel_ch1 = kernel_ch1_s[i];
                Kernel_ch2 = kernel_ch2_s[i];
            end
            if (i >= 18) begin
                Kernel_ch1 = 32'hxxxxxxxx;
                Kernel_ch2 = 32'hxxxxxxxx;
            end
            if (i < 57) Weight_Bias = weight_bias_s[i];
            if (i >= 57) Weight_Bias = 32'hxxxxxxxx;
            if (i > 0) begin task_number = 1'bx; mode = 2'bxx; end
            @(negedge clk);
        end
    end else begin // Task 1
        for (i=0; i<36; i=i+1) begin
            Image = image_s[i];
            if (i < 18) begin
                Kernel_ch1 = kernel_ch1_s[i];
                Kernel_ch2 = kernel_ch2_s[i];
            end
            if (i >= 18) begin
                Kernel_ch1 = 32'hxxxxxxxx;
                Kernel_ch2 = 32'hxxxxxxxx;
            end
            if (i < 5) capacity_cost = capacity_cost_s[i];
            if (i >= 5) capacity_cost = 4'hx;
            if (i > 0) begin task_number = 1'bx; mode = 2'bxx; end
            @(negedge clk);
        end
    end
    in_valid = 1'b0;
    Image = 32'hxxxxxxxx;

    // Wait for output and check
    latency_counter = 0;
    while(out_valid !== 1'b1) begin
        latency_counter = latency_counter + 1;
        // Specification Assertion: Latency Timeout
        if (latency_counter > `MAX_LATENCY) begin
            $display("********************************************************");     
            $display("                          FAIL!                         ");
            $display("*  Execution latency > %3d cycles. Timeout! at %8t *", `MAX_LATENCY, $time);
            $display("********************************************************");
            $finish;
        end
        // Specification Assertion: No overlap
        if (in_valid) begin
           $display("FAIL! in_valid and out_valid cannot overlap."); $finish;
        end
        @(negedge clk);
    end

    // Latency count for the first valid cycle
    latency_counter = latency_counter + 1;
    total_latency = total_latency + latency_counter;

    // Check results
    if (task_number_s == 1'b0) begin
        for (i = 0; i < 3; i = i + 1) begin
            if (out_valid !== 1'b1) begin $display("FAIL! out_valid dropped early."); $finish; end
            
            your_real = bits_to_real(out);
            golden_real = golden_out_task0[i];
            abs_error = (your_real > golden_real) ? (your_real - golden_real) : (golden_real - your_real);

            golden_bits = real_to_bits(golden_real);

            if (abs_error > `ERROR_TOLERANCE) begin
                $display("*********************** TASK 0 FAIL ***********************");
                $display("Pattern %d, Output index %d", i_pat, i);
                $display("Your result (real) : %f (%h)", your_real, out);
                $display("Golden result (real): %f (%h)", golden_real, golden_bits);
                $display("Absolute Error     : %f > %f", abs_error, `ERROR_TOLERANCE);
                $display("*********************************************************");
                $finish;
            end
            @(negedge clk);
        end
    end else begin // Task 1 check
        if (out[3:0] !== golden_out_task1) begin
            $display("*********************** TASK 1 FAIL ***********************");
            $display("Pattern %d", i_pat);
            $display("Your result  : 4'b%b", out[3:0]);
            $display("Golden result: 4'b%b", golden_out_task1);
            $display("*********************************************************");
            $finish;
        end
        @(negedge clk);
    end

    // After out_valid is low, out should be zero
    if (out !== 32'b0) begin
        $display("FAIL! 'out' signal should be zero after 'out_valid' is pulled down.");
        $finish;
    end
end
endtask

task pass_task;
begin
    $display ("----------------------------------------------------------------------------------------------------------------------");
    $display ("                                                  Congratulations!                                                    ");
    $display ("                                           You have passed all %4d patterns!                                            ", `PAT_NUM);
    $display ("                                           Average execution latency = %5d cycles                                       ", total_latency / `PAT_NUM);
    $display ("                                           Your clock period = %.1f ns                                                ", CYCLE);
    $display ("----------------------------------------------------------------------------------------------------------------------");     
    $finish;
end
endtask

//---------------------------------------------------------------------
//   HELPER FUNCTIONS
//---------------------------------------------------------------------
function real rand_real;
    // Generate a random real number in range [-0.5, 0.5]
    reg [31:0] rand_int;
    real rand_frac;
    begin
        rand_int = {$random(seed)};
        rand_frac = rand_int / (2.0**32); // Normalize to [0, 1]
        rand_real = rand_frac - 0.5; // Shift to [-0.5, 0.5]
    end
endfunction

function [31:0] real_to_bits;
    input real val;
    reg [63:0] real_bits;
    reg [31:0] float_bits;
    begin
        real_bits = $realtobits(val);
        float_bits[31] = real_bits[63]; // sign
        float_bits[30:23] = real_bits[62:52] - 1023 + 127; // exponent
        float_bits[22:0] = real_bits[51:29]; // fraction
        real_to_bits = float_bits;
    end
endfunction

function real bits_to_real;
    input [31:0] val;
    reg [63:0] real_bits;
    begin
        real_bits[63] = val[31];
        if (val[30:23] == 8'd0) real_bits[62:52] = 11'd0;
        else real_bits[62:52] = val[30:23] - 127 + 1023;
        real_bits[51:29] = val[22:0];
        real_bits[28:0] = 29'd0;
        bits_to_real = $bitstoreal(real_bits);
    end
endfunction

task perform_padding;
    input real in_image[5:0][5:0];
    output real out_padded[7:0][7:0];
    integer r, c;
    reg replication;
begin
    replication = (mode_s == 2'b00 || mode_s == 2'b01);

    // Copy core image
    for (r=0; r<6; r=r+1) for(c=0; c<6; c=c+1) out_padded[r+1][c+1] = in_image[r][c];
    
    // Pad rows
    for (c=0; c<6; c=c+1) begin
        out_padded[0][c+1]   = replication ? in_image[0][c] : in_image[1][c];
        out_padded[7][c+1] = replication ? in_image[5][c] : in_image[4][c];
    end
    
    // Pad columns
    for (r=0; r<6; r=r+1) begin
        out_padded[r+1][0]   = replication ? in_image[r][0] : in_image[r][1];
        out_padded[r+1][7] = replication ? in_image[r][5] : in_image[r][4];
    end
    
    // Pad corners
    out_padded[0][0] = replication ? in_image[0][0] : in_image[1][1];
    out_padded[0][7] = replication ? in_image[0][5] : in_image[1][4];
    out_padded[7][0] = replication ? in_image[5][0] : in_image[4][1];
    out_padded[7][7] = replication ? in_image[5][5] : in_image[4][4];
end
endtask

function real find_max;
    input real image[5:0][5:0];
    input integer r_start, c_start;
    integer r, c;
    real max_val;
begin
    max_val = image[r_start][c_start];
    for(r=0; r<3; r=r+1) for(c=0; c<3; c=c+1) begin
        if (image[r_start+r][c_start+c] > max_val) max_val = image[r_start+r][c_start+c];
    end
    find_max = max_val;
end
endfunction

function real tanh;
    input real x;
    begin
        tanh = ($exp(x) - $exp(-x)) / ($exp(x) + $exp(-x));
    end
endfunction

function real swish;
    input real x;
    begin
        swish = x / (1.0 + $exp(-x));
    end
endfunction

task perform_softmax;
    input real in_vec[2:0];
    output real out_vec[2:0];
    real exp_sum;
    integer i;
begin
    exp_sum = 0.0;
    for (i=0; i<3; i=i+1) exp_sum = exp_sum + $exp(in_vec[i]);
    for (i=0; i<3; i=i+1) out_vec[i] = $exp(in_vec[i]) / exp_sum;
end
endtask

function real run_cnn_task1;
    input real image[5:0][5:0];
    input real kernel[2:0][2:0];
    real padded_image[7:0][7:0];
    real conv_out[5:0][5:0];
    real total_sum;
    integer r, c, kr, kc;
begin
    perform_padding(image, padded_image);
    conv_out = '{default:0.0};
    for(r=0; r<6; r=r+1) for(c=0; c<6; c=c+1) for(kr=0; kr<3; kr=kr+1) for(kc=0; kc<3; kc=kc+1) begin
        conv_out[r][c] = conv_out[r][c] + padded_image[r+kr][c+kc] * kernel[kr][kc];
    end
    
    total_sum = 0.0;
    for(r=0; r<6; r=r+1) for(c=0; c<6; c=c+1) total_sum = total_sum + conv_out[r][c];
    run_cnn_task1 = total_sum;
end
endfunction


endmodule




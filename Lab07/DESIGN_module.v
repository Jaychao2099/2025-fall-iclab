/**************************************************************************
 * Copyright (c) 2025, OASIS Lab
 * MODULE: CLK_1_MODULE, CLK_2_MODULE, CLK_3_MODULE
 * FILE NAME: DESIGN_module.v
 * VERSRION: 1.0
 * DATE: Oct 29, 2025
 * AUTHOR: Chao-En Kuo, NYCU IAIS
 * DESCRIPTION: ICLAB2025FALL / LAB7 / DESIGN_module
 * MODIFICATION HISTORY:
 * Date                 Description
 * 
 *************************************************************************/
module CLK_1_MODULE (
    clk,
    rst_n,
    in_valid,
    in_data,
    out_idle,
    out_valid,
    out_data,

    flag_handshake_to_clk1,
    flag_clk1_to_handshake
);

//---------------------------------------------------------------------
//   PORT DECLARATION          
//---------------------------------------------------------------------
input             clk;
input             rst_n;
input             in_valid;
input      [31:0] in_data;
input             out_idle;

output reg        out_valid;
output reg [31:0] out_data;

// You can use the the custom flag ports for your design
input  flag_handshake_to_clk1;

output flag_clk1_to_handshake;      // tell hankshake it's last data packet

//---------------------------------------------------------------------
//   Reg / Wire / Parameters DECLARATION          
//---------------------------------------------------------------------

reg [3:0] input_cnt;

//---------------------------------------------------------------------
//   Calculation         
//---------------------------------------------------------------------

// output reg        out_valid;
// output reg [31:0] out_data;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        out_valid <= 1'b0;
        out_data  <= 32'b0;
    end
    else if (out_idle && in_valid) begin     // Handshake idle
        out_valid <= 1'b1;
        out_data  <= in_data;
    end
    else begin
        out_valid <= 1'b0;
        out_data  <= 32'd0;
    end
end

// reg [3:0] input_cnt;
always @(posedge clk or negedge rst_n) begin
    if      (!rst_n)   input_cnt <= 4'd0;
    else if (in_valid) input_cnt <= input_cnt + 4'd1;
    else               input_cnt <= 4'd0;
end

// // output flag_clk1_to_handshake;      // tell hankshake it's last data packet
// always @(posedge clk) begin
//     if (sending_data) begin
//         if (input_cnt == 4'd15) flag_clk1_to_handshake <= 1'b1;
//         else                    flag_clk1_to_handshake <= 1'b0;
//     end
// end


endmodule

module CLK_2_MODULE (
    clk,
    rst_n,
    in_valid,
    in_data,
    fifo_full,
    out_valid,
    out_data,
    busy,
    
    flag_handshake_to_clk2,
    flag_clk2_to_handshake,

    flag_fifo_to_clk2,
    flag_clk2_to_fifo
);

//---------------------------------------------------------------------
//   PORT DECLARATION          
//---------------------------------------------------------------------
input             clk;      // clk 2
input             rst_n;
input             in_valid;
input             fifo_full;
input      [31:0] in_data;

output reg        out_valid;
output reg [15:0] out_data;
output            busy;

// You can use the the custom flag ports for your design
input  flag_handshake_to_clk2;
output flag_clk2_to_handshake;

input  flag_fifo_to_clk2;
output flag_clk2_to_fifo;

//---------------------------------------------------------------------
//   Reg / Wire / Parameters DECLARATION          
//---------------------------------------------------------------------

genvar k;

parameter S_IDLE   = 2'd0;
parameter S_INPUT  = 2'd1;
parameter S_NTT    = 2'd2;
// parameter S_OUTPUT = 2'd3;

reg [3:0] input_cnt;    // 0~15
reg [8:0] ntt_cnt;      // 0~317
reg [6:0] out_cnt;      // 0~127


reg [15:0] ntt_output;

//---------------------------------------------------------------------
//   Design      
//---------------------------------------------------------------------

// -------------------- FSM --------------------

reg [1:0] current_state;
reg [1:0] next_state;

// reg [1:0] current_state;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) current_state <= S_IDLE;
    else        current_state <= next_state;
end

// reg [1:0] next_state;
always @(*) begin
    case (current_state)
        S_IDLE: begin
            if (in_valid) next_state = S_INPUT;
            else          next_state = S_IDLE;
        end
        S_INPUT: begin
            if (input_cnt == 4'd15) next_state = S_NTT;
            else                    next_state = S_INPUT;
        end
        S_NTT: begin
            if (out_cnt == 7'd127) next_state = S_IDLE;
            else                   next_state = S_NTT;
        end
        default: next_state = current_state;
    endcase
end

// -------------------- input --------------------

// reg [3:0] input_cnt;    // 0~15
always @(posedge clk or negedge rst_n) begin
    if      (!rst_n)   input_cnt <= 4'd0;
    else if (in_valid) input_cnt <= input_cnt + 4'd1;
    else               input_cnt <= input_cnt;
end

// input [31:0] in_data;
reg [15:0] ntt_reg [0:127];

always @(posedge clk) begin
    // -------------------- input --------------------
    if (in_valid) begin     // TODO: change to shift reg
        for (i = 0; i < 8; i = i + 1) ntt_reg[input_cnt*8 + i] <= {12'd0, in_data[i*4+3:i*4]};
        // case (input_cnt)
        //     0: for (i = 0; i < 8; i = i + 1) ntt_reg[0*8 + i] <= in_data[i*4+3:i*4];
        //     1: for (i = 0; i < 8; i = i + 1) ntt_reg[1*8 + i] <= in_data[i*4+3:i*4];
        //     2: for (i = 0; i < 8; i = i + 1) ntt_reg[2*8 + i] <= in_data[i*4+3:i*4];
        //     3: for (i = 0; i < 8; i = i + 1) ntt_reg[3*8 + i] <= in_data[i*4+3:i*4];
        //     4: for (i = 0; i < 8; i = i + 1) ntt_reg[4*8 + i] <= in_data[i*4+3:i*4];
        //     5: for (i = 0; i < 8; i = i + 1) ntt_reg[5*8 + i] <= in_data[i*4+3:i*4];
        //     6: for (i = 0; i < 8; i = i + 1) ntt_reg[6*8 + i] <= in_data[i*4+3:i*4];
        //     7: for (i = 0; i < 8; i = i + 1) ntt_reg[7*8 + i] <= in_data[i*4+3:i*4];
        //     8: for (i = 0; i < 8; i = i + 1) ntt_reg[8*8 + i] <= in_data[i*4+3:i*4];
        //     9: for (i = 0; i < 8; i = i + 1) ntt_reg[9*8 + i] <= in_data[i*4+3:i*4];
        //     10: for (i = 0; i < 8; i = i + 1) ntt_reg[10*8 + i] <= in_data[i*4+3:i*4];
        //     11: for (i = 0; i < 8; i = i + 1) ntt_reg[11*8 + i] <= in_data[i*4+3:i*4];
        //     12: for (i = 0; i < 8; i = i + 1) ntt_reg[12*8 + i] <= in_data[i*4+3:i*4];
        //     13: for (i = 0; i < 8; i = i + 1) ntt_reg[13*8 + i] <= in_data[i*4+3:i*4];
        //     14: for (i = 0; i < 8; i = i + 1) ntt_reg[14*8 + i] <= in_data[i*4+3:i*4];
        //     15: for (i = 0; i < 8; i = i + 1) ntt_reg[15*8 + i] <= in_data[i*4+3:i*4];
        //     // default: for (i = 0; i < 128; i = i + 1) ntt_reg[i] <= 32'd0;
        // endcase
    end
    // -------------------- NTT --------------------
    else if (current_state == S_NTT) begin
        
    end
    // else ntt_reg <= ntt_reg;
end

// -------------------- NTT --------------------

// reg [8:0] ntt_cnt;
always @(posedge clk) begin
    case (current_state)
        S_IDLE:  ntt_cnt <= 9'd0;
        S_NTT:   ntt_cnt <= ntt_cnt + 9'd1;
        default: ntt_cnt <= ntt_cnt;
    endcase
end

// reg [3:0] in_data_reg [0:127];
// reg [15:0] ntt_reg [0:127];

reg [15:0] a [0:7], b [0:7];
reg [13:0] gmb [0:7];
wire [15:0] result_a [0:7], result_b [0:7];

// wire [15:0] result_a [0:7], result_b [0:7];
generate
    for (k = 0; k < 8; k = k + 1) begin: modq_gen
        BUTTERFLY butterfly(.a(a[k]), .b(b[k]), .gmb(gmb[k]), .result_a(result_a[k]), .result_b(result_b[k]));
    end
endgenerate

// -------------------- output --------------------

// reg [6:0] out_cnt;      // 0~127
always @(posedge clk or negedge rst_n) begin
    if      (!rst_n)                                                    out_cnt <= 7'd0;
    else if (current_state == S_NTT && ntt_cnt >= 9'd254 && !fifo_full) out_cnt <= out_cnt + 7'd1;
    else                                                                out_cnt <= 7'd0;
end

// output reg out_valid;
always @(posedge clk or negedge rst_n) begin
    if      (!rst_n)                                                    out_valid <= 1'b0;
    else if (current_state == S_NTT && ntt_cnt >= 9'd254 && !fifo_full) out_valid <= 1'b1;
    else                                                                out_valid <= 1'b0;
end

// output reg [15:0] out_data;
always @(posedge clk or negedge rst_n) begin
    if      (!rst_n)                                                    out_data <= 16'd0;
    else if (current_state == S_NTT && ntt_cnt >= 9'd254 && !fifo_full) out_data <= ntt_reg[out_cnt];
    else                                                                out_data <= 16'd0;
end

// output busy;
assign busy = (current_state != S_IDLE);

endmodule


module BUTTERFLY (
    input  [15:0] a,       // 16-bit
    input  [15:0] b,       // 16-bit
    input  [13:0] gmb,       // 14-bit  max = 12276 = 10111111110100
    output [15:0] result_a,  // 16-bit
    output [15:0] result_b,  // 16-bit
);

localparam Q = 14'd12289;   // 11000000000001
localparam Q0I = 14'd12287;

wire [13:0] b_modq;

wire [29:0] x_;   // 28-bit, b*gmb, 804,507,660, 30'b101111111100111101000000001100
wire [15:0] y_;   // 16-bit, 65535
// wire [29:0] t;    // 30-bit, y * Q, 804,507,660, 30'b101111111100111101000000001100
wire [13:0] z_;   // 14-bit

assign x_ = b * gmb;
assign y_ = (x_ * Q0I)[15:0];     // (...)%(2^16)   // 16-bit
assign z_ = ({1'b0, x_} + y_ * Q)[30:16]; // (...)/(2^16)   // 15-bit
assign b_modq = (z_ < Q) ? z_ : (z_ - Q);

assign result_a = (a + b_modq) % Q;
assign result_b = (a < b_modq) ? ((a + Q) - b_modq) : (a - b_modq);


endmodule

module CLK_3_MODULE (
    clk,
    rst_n,
    fifo_empty,
    fifo_rdata,
    fifo_rinc,
    out_valid,
    out_data,

    flag_fifo_to_clk3,
    flag_clk3_to_fifo
);

//---------------------------------------------------------------------
//   PORT DECLARATION          
//---------------------------------------------------------------------
input             clk;
input             rst_n;
input             fifo_empty;
input      [15:0] fifo_rdata;

output reg        fifo_rinc;
output reg        out_valid;
output reg [15:0] out_data;

// You can change the input / output of the custom flag ports
input  flag_fifo_to_clk3;
output flag_clk3_to_fifo;

//---------------------------------------------------------------------
//   Reg / Wire / Parameters DECLARATION          
//---------------------------------------------------------------------

reg read_request_delayed;

//---------------------------------------------------------------------
//   Calculation        
//---------------------------------------------------------------------

// output reg        fifo_rinc;
always @(posedge clk) begin
    if (!fifo_empty) fifo_rinc <= 1'b1;    // request data
    else             fifo_rinc <= 1'b0;
end

// reg read_request_delayed;
always @(posedge clk) begin
    read_request_delayed <= fifo_rinc;
end

// output reg        out_valid;
// output reg [15:0] out_data;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        out_valid <= 1'b0;
        out_data  <= 16'b0;
    end
    else if (read_request_delayed) begin
        out_valid <= 1'b1;
        out_data  <= fifo_rdata;
    end
    else begin
        out_valid <= 1'b0;
        out_data  <= 16'b0;
    end
end




endmodule
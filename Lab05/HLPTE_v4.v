module HLPTE(
    // input signals
    clk,
    rst_n,
    in_valid_data,
    in_valid_param,
    
    data,
	index,
	mode,
    QP,
	
    // output signals
    out_valid,
    out_value
);

input                     clk;
input                     rst_n;
input                     in_valid_data;
input                     in_valid_param;

input              [7:0]  data;
input              [3:0]  index;
input                     mode;
input              [4:0]  QP;

output reg                out_valid;
output reg signed [31:0]  out_value;

//==================================================================
// parameter & integer
//==================================================================

genvar i;

parameter S_IDLE        = 3'd0;
parameter S_INPUT_DATA  = 3'd1;
parameter S_INPUT_PARAM = 3'd2;
parameter S_PREDICTION  = 3'd3;
parameter S_TRANSFORM   = 3'd4;

//==================================================================
// reg & wire
//==================================================================

// ----------------- input (memory) -----------------
reg [3:0] mem_frame_num;
reg [4:0] mem_row_num;
reg [4:0] mem_col_num;
reg [7:0] mem_input_data;
reg [7:0] mem_output_data, mem_output_data_reg;
reg mem_web;

reg [13:0] input_cnt;

// ----------------- input (param) -----------------
reg [3:0] set_cnt;
reg [1:0] param_cnt;
reg [3:0] index_reg;
reg [3:0] mode_reg;
reg [4:0] QP_reg;

// ----------------- FSM -----------------
reg [2:0] current_state;
reg [2:0] next_state;

// ----------------- referance -----------------
reg current_mode;
reg [1:0] MB_cnt, next_MB_cnt;    // 0~3
// intra_4
reg [3:0] intra_4_cnt;     // 0~15

// ----------------- predict -----------------
// 0~255
reg [7:0] prediction_dc   [0:255];
reg [7:0] prediction_hori [0:255];
reg [7:0] prediction_vert [0:255];
reg [7:0] real_prediction [0:255];

reg [12:0] ref_left [0:31], ref_left_reg [0:31];
reg [12:0] ref_top  [0:31], ref_top_reg [0:31];

reg [12:0] left_sum16 [0:1], left_sum4 [0:7];
reg [12:0] top_sum16 [0:1], top_sum4 [0:7];
reg [12:0] dc;

wire [7:0] in_data;   // 0~255

wire [8:0] max_predict_cnt;     // 15 or 255

reg [8:0] predict_cnt, prev_predict_cnt, pprev_predict_cnt, ppprev_predict_cnt, pppprev_predict_cnt;     // 0~15, 0~255

// input - prediction, -255~255
reg signed [8:0] residual_dc   [0:255], residual_dc_reg   [0:255];
reg signed [8:0] residual_hori [0:255], residual_hori_reg [0:255];
reg signed [8:0] residual_vert [0:255], residual_vert_reg [0:255];

// ABS(input - prediction)
reg [11:0] out_sad_dc, out_sad_hori, out_sad_vert;
reg [31:0] acc_sad_dc, acc_sad_hori, acc_sad_vert;
reg signed [8:0] real_residual [0:255];

// ----------------- int transform -----------------
reg [8:0] transform_cnt;
reg [7:0] prev_transform_cnt;
reg [7:0] pprev_transform_cnt;
reg [7:0] ppprev_transform_cnt;

wire reconstruct_done;

// ----------------- Quantization -----------------
reg [12:0] q_in;
reg signed [31:0] q_out;

// ----------------- output -----------------
wire need_output;
reg [9:0] out_cnt;  // 0~1023

// ----------------- De-Quantization -----------------
wire signed [31:0] de_q_out;
reg signed [31:0] de_W [0:15], de_W_reg [0:15];

// ----------------- inverse int transform -----------------
reg signed [31:0] new_left [0:3];
reg signed [31:0] new_top  [0:3];

// ----------------- feedback referance -----------------
reg signed [31:0] re_left [0:3];
reg signed [31:0] re_top  [0:3];

//==================================================================
// design
//==================================================================

// ----------------- input (memory) -----------------

// reg [3:0] mem_frame_num;
// reg [4:0] mem_row_num;
// reg [4:0] mem_col_num;
// reg [7:0] mem_input_data;
// reg [7:0] mem_output_data, mem_output_data_reg;
MEM_INTERFACE m1 (.frame(mem_frame_num), .row(mem_row_num), .col(mem_col_num), .Dout(mem_output_data), .Din(mem_input_data), .clk(clk), .WEB(mem_web));


// reg [13:0] input_cnt;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) input_cnt <= 14'b0;
    else if (in_valid_data) input_cnt <= input_cnt + 14'd1;
    else input_cnt <= 14'd0;
end

// reg [3:0] mem_frame_num;
// reg [4:0] mem_row_num;
// reg [4:0] mem_col_num;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        mem_frame_num <= 4'd0;
        mem_row_num <= 5'd0;
        mem_col_num <= 5'd0;
    end
    // ----------------- input (memory) -----------------
    else if (in_valid_data) begin
        mem_frame_num <= input_cnt[13:10];
        mem_row_num <= input_cnt[9:5];
        mem_col_num <= input_cnt[4:0];
    end
    // ----------------- predict -----------------
    else if (current_state == S_PREDICTION) begin
        mem_frame_num <= index_reg;
        if (current_mode) begin
            mem_row_num <= {MB_cnt[1], intra_4_cnt[3:2], predict_cnt[3:2]};  // (cnt/4) + (intra_4_cnt/4)*4
            mem_col_num <= {MB_cnt[0], intra_4_cnt[1:0], predict_cnt[1:0]};  // (cnt%4) + (intra_4_cnt%4)*4
        end
        else begin
            mem_row_num <= {MB_cnt[1], predict_cnt[7:6], predict_cnt[3:2]};  // 4*((cnt/16)/4) + (cnt%16)/4
            mem_col_num <= {MB_cnt[0], predict_cnt[5:4], predict_cnt[1:0]};  // 4*((cnt/16)%4) + (cnt%16)%4
        end
    end
    // -----------------  -----------------
    else begin
        mem_frame_num <= 4'd0;
        mem_row_num <= 5'd0;
        mem_col_num <= 5'd0;
    end
end

// wire mem_web;
// assign mem_web = ~in_valid_data;
always @(posedge clk) begin
    mem_web <= ~in_valid_data;
end

// reg [7:0] mem_input_data;
always @(posedge clk) begin
    if (in_valid_data) mem_input_data <= data;
    else mem_input_data <= 8'd0;
end

// reg [7:0] mem_output_data, mem_output_data_reg;
always @(posedge clk) begin
    if (mem_web) mem_output_data_reg <= mem_output_data;
    else mem_output_data_reg <= 8'd0;
end

// ----------------- input (param) -----------------

// reg [3:0] set_cnt;
always @(posedge clk) begin
    if      (in_valid_data)                       set_cnt <= 4'd0;
    else if (in_valid_param && param_cnt == 2'd0) set_cnt <= set_cnt + 4'd1;
    else                                          set_cnt <= set_cnt;
end

// reg [1:0] param_cnt;
always @(posedge clk or negedge rst_n) begin
    if      (!rst_n)         param_cnt <= 2'b0;
    else if (in_valid_param) param_cnt <= param_cnt + 2'd1;
    else                     param_cnt <= 2'b0;
end

// reg [3:0]  index_reg;
always @(posedge clk) begin
    if (in_valid_param && param_cnt == 2'd0) index_reg <= index;
    else                                     index_reg <= index_reg;
end

// reg [3:0] mode_reg;
always @(posedge clk) begin
    if (in_valid_param) begin
        mode_reg[3] <= mode;
        mode_reg[2] <= mode_reg[3];
        mode_reg[1] <= mode_reg[2];
        mode_reg[0] <= mode_reg[1];
    end
    else mode_reg <= mode_reg;
end

// reg [4:0]  QP_reg;
always @(posedge clk) begin
    if (in_valid_param && param_cnt == 2'd0) QP_reg <= QP;
    else QP_reg <= QP_reg;
end

// ----------------- FSM -----------------

// parameter S_IDLE        = 0;
// parameter S_INPUT_DATA  = 1;
// parameter S_INPUT_PARAM = 2;
// parameter S_PREDICTION  = 3;
// parameter S_TRANSFORM   = 4;

// reg [2:0] current_state;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) current_state <= S_IDLE;
    else        current_state <= next_state;
end

// reg [2:0] next_state;
always @(*) begin
    if (!rst_n) next_state = S_IDLE;
    else begin
        next_state = current_state;
        case (current_state)
            S_IDLE: begin
                if      (in_valid_data)  next_state = S_INPUT_DATA;
                else if (in_valid_param) next_state = S_INPUT_PARAM;
                else                     next_state = S_IDLE;
            end
            S_INPUT_DATA: begin
                if (input_cnt == 14'd16383) next_state = S_IDLE;
                else                        next_state = S_INPUT_DATA;
            end
            S_INPUT_PARAM: begin
                if (param_cnt == 2'd3) next_state = S_PREDICTION;
                else                   next_state = S_INPUT_PARAM;
            end
            S_PREDICTION: begin
                if (current_mode && pppprev_predict_cnt == 9'd15 || pppprev_predict_cnt == 9'd255) next_state = S_TRANSFORM;
                else                                                                               next_state = S_PREDICTION;
            end
            S_TRANSFORM: begin
                if (out_cnt == 10'd1023)   next_state = S_IDLE;       // all 16 sets are done
                else if (reconstruct_done) next_state = S_PREDICTION;
                else                       next_state = S_TRANSFORM;
            end
        endcase
    end
end

// ----------------- referance -----------------

// wire current_mode;
// assign current_mode = mode_reg[MB_cnt];
always @(posedge clk) begin
    current_mode <= mode_reg[MB_cnt];
end

// reg [1:0] MB_cnt;    // 0~3
always @(posedge clk) begin
    if      (current_state == S_INPUT_PARAM) MB_cnt <= 2'd0;
    else if (current_state == S_TRANSFORM)   MB_cnt <= next_MB_cnt;
    else                                     MB_cnt <= MB_cnt;
end

// reg [1:0] next_MB_cnt;    // 0~3
always @(*) begin
    next_MB_cnt = MB_cnt;
    if (out_cnt[7:0] == 8'd0 && next_state != current_state) next_MB_cnt = MB_cnt + 2'd1;
end

// reg [3:0] intra_4_cnt;
always @(posedge clk) begin
    if      (current_state == S_INPUT_PARAM)                                             intra_4_cnt <= 4'd0;
    else if (current_state == S_TRANSFORM && next_state == S_PREDICTION && current_mode) intra_4_cnt <= intra_4_cnt + 4'd1;
    else                                                                                 intra_4_cnt <= intra_4_cnt;
end

// ----------------- feedback referance -----------------

// reg [12:0] ref_left_reg [0:15];SS
// reg [12:0] ref_top_reg  [0:31];

// reg [12:0] ref_left [0:31];
// reg [12:0] ref_top  [0:31];

// reg [7:0] prediction_dc   [0:255];
// reg [7:0] prediction_hori [0:255];
// reg [7:0] prediction_vert [0:255];
always @(*) begin
    integer i;
    for (i = 0; i < 256; i = i + 1) begin
        prediction_hori[i] = ref_left_reg[4*(i/64) + (i%16)/4 + {MB_cnt[1], 4'd0}][7:0];
        prediction_vert[i] = ref_top_reg[4*((i/16)%4) + (i%4) + {MB_cnt[0], 4'd0}][7:0];
        prediction_dc[i] = dc[7:0];
    end
end

// reg [12:0] left_sum16 [0:1], left_sum4 [0:7];
assign left_sum4[0] = ref_left_reg[0]  + ref_left_reg[1]  + ref_left_reg[2]   + ref_left_reg[3];
assign left_sum4[1] = ref_left_reg[4]  + ref_left_reg[5]  + ref_left_reg[6]   + ref_left_reg[7];
assign left_sum4[2] = ref_left_reg[8]  + ref_left_reg[9]  + ref_left_reg[10]  + ref_left_reg[11];
assign left_sum4[3] = ref_left_reg[12] + ref_left_reg[13] + ref_left_reg[14]  + ref_left_reg[15];

assign left_sum4[4] = ref_left_reg[16] + ref_left_reg[17] + ref_left_reg[18]  + ref_left_reg[19];
assign left_sum4[5] = ref_left_reg[20] + ref_left_reg[21] + ref_left_reg[22]  + ref_left_reg[23];
assign left_sum4[6] = ref_left_reg[24] + ref_left_reg[25] + ref_left_reg[26]  + ref_left_reg[27];
assign left_sum4[7] = ref_left_reg[28] + ref_left_reg[29] + ref_left_reg[30]  + ref_left_reg[31];

assign left_sum16[0] = left_sum4[0] + left_sum4[1] + left_sum4[2] + left_sum4[3];
assign left_sum16[1] = left_sum4[4] + left_sum4[5] + left_sum4[6] + left_sum4[7];

// reg [12:0] top_sum16 [0:1], top_sum4 [0:7];
assign top_sum4[0] = ref_top_reg[0]  + ref_top_reg[1]  + ref_top_reg[2]   + ref_top_reg[3];
assign top_sum4[1] = ref_top_reg[4]  + ref_top_reg[5]  + ref_top_reg[6]   + ref_top_reg[7];
assign top_sum4[2] = ref_top_reg[8]  + ref_top_reg[9]  + ref_top_reg[10]  + ref_top_reg[11];
assign top_sum4[3] = ref_top_reg[12] + ref_top_reg[13] + ref_top_reg[14]  + ref_top_reg[15];

assign top_sum4[4] = ref_top_reg[16] + ref_top_reg[17] + ref_top_reg[18]  + ref_top_reg[19];
assign top_sum4[5] = ref_top_reg[20] + ref_top_reg[21] + ref_top_reg[22]  + ref_top_reg[23];
assign top_sum4[6] = ref_top_reg[24] + ref_top_reg[25] + ref_top_reg[26]  + ref_top_reg[27];
assign top_sum4[7] = ref_top_reg[28] + ref_top_reg[29] + ref_top_reg[30]  + ref_top_reg[31];

assign top_sum16[0] = top_sum4[0] + top_sum4[1] + top_sum4[2] + top_sum4[3];
assign top_sum16[1] = top_sum4[4] + top_sum4[5] + top_sum4[6] + top_sum4[7];

reg [12:0] dc_reg;

always @(posedge clk) begin
    dc_reg <= dc;
end
// top []   // intra_4_cnt % 4 + MB_cnt[0]*4
// left[]   // intra_4_cnt / 4 + MB_cnt[1]*4
// reg [12:0] dc;
always @(*) begin
    dc = dc_reg;
    // if (current_mode && intra_4_cnt > 0) begin     // 4 x 4
    if (current_mode) begin     // 4 x 4
        if      (MB_cnt == 2'd0 && intra_4_cnt      == 4'd0) dc = 13'd128;
        else if (!MB_cnt[0]     && intra_4_cnt[1:0] == 2'd0) dc = top_sum4[0]  >> 2;
        else if (!MB_cnt[1]     && intra_4_cnt[3:2] == 2'd0) dc = left_sum4[0] >> 2;
        else dc = (top_sum4[{MB_cnt[0], intra_4_cnt[1:0]}] + left_sum4[{MB_cnt[1], intra_4_cnt[3:2]}]) >> 3;
    end
    else if (!current_mode) begin  // 16 x 16
        case (MB_cnt)
            0: dc = 13'd128;
            1: dc = left_sum16[0] >> 4;
            2: dc = top_sum16[0]  >> 4;
            3: dc = (left_sum16[1] + top_sum16[1]) >> 5;
            default: dc = 13'd0;
        endcase
    end
end

// ----------------- predict -----------------

// wire [7:0] in_data;   // 0~255
assign in_data = mem_output_data_reg;

// wire max_predict_cnt;
assign max_predict_cnt = current_mode ? 9'd15 : 9'd255;

// reg [8:0] predict_cnt;     // 0~17, 0~255
always @(posedge clk or negedge rst_n) begin
    if      (!rst_n)                                                          predict_cnt <= 9'd0;
    else if (current_state == S_PREDICTION && predict_cnt == max_predict_cnt) predict_cnt <= predict_cnt;
    else if (current_state == S_PREDICTION)                                   predict_cnt <= predict_cnt + 9'd1;
    else                                                                      predict_cnt <= 9'd0;
end

// reg [8:0] prev_predict_cnt;     // 0~17, 0~255
// reg [8:0] pprev_predict_cnt;     // 0~17, 0~255
// reg [8:0] ppprev_predict_cnt;     // 0~17, 0~255
always @(posedge clk) begin
    prev_predict_cnt <= (predict_cnt < 9'd16 && current_mode || predict_cnt < 9'd256 && !current_mode) ? predict_cnt : 9'd0;
    pprev_predict_cnt <= prev_predict_cnt;
    ppprev_predict_cnt <= pprev_predict_cnt;
    pppprev_predict_cnt <= ppprev_predict_cnt;
end

wire signed [8:0] sad_dc_residual;
wire signed [8:0] sad_hori_residual;
wire signed [8:0] sad_vert_residual;

// input - prediction, -255~255
// reg signed [8:0] residual_dc   [0:255];
// reg signed [8:0] residual_hori [0:255];
// reg signed [8:0] residual_vert [0:255];
always @(posedge clk) begin
    residual_dc_reg   <= residual_dc;
    residual_hori_reg <= residual_hori;
    residual_vert_reg <= residual_vert;
end

always @(*) begin
    residual_dc   = residual_dc_reg;
    residual_hori = residual_hori_reg;
    residual_vert = residual_vert_reg;
    residual_dc  [ppprev_predict_cnt + {intra_4_cnt, 4'd0}] = sad_dc_residual;
    residual_hori[ppprev_predict_cnt + {intra_4_cnt, 4'd0}] = sad_hori_residual;
    residual_vert[ppprev_predict_cnt + {intra_4_cnt, 4'd0}] = sad_vert_residual;
end

wire [7:0] sad_dc_prediction;
wire [7:0] sad_hori_prediction;
wire [7:0] sad_vert_prediction;

assign sad_dc_prediction   = prediction_dc[0];
assign sad_hori_prediction = prediction_hori[ppprev_predict_cnt + {intra_4_cnt, 4'd0}];
assign sad_vert_prediction = prediction_vert[ppprev_predict_cnt + {intra_4_cnt, 4'd0}];


// ABS(input - prediction)
// reg [11:0] out_sad_dc, out_sad_hori, out_sad_vert;
SAD sad_dc   (.in_data(in_data), .prediction(sad_dc_prediction)  , .residual(sad_dc_residual)  , .out_sad(out_sad_dc));
SAD sad_hori (.in_data(in_data), .prediction(sad_hori_prediction), .residual(sad_hori_residual), .out_sad(out_sad_hori));
SAD sad_vert (.in_data(in_data), .prediction(sad_vert_prediction), .residual(sad_vert_residual), .out_sad(out_sad_vert));

// reg [31:0] acc_sad_dc, acc_sad_hori, acc_sad_vert;
always @(posedge clk) begin
    // if (current_state == S_PREDICTION) begin
    if (predict_cnt >= 9'd3) begin
        acc_sad_dc   <= acc_sad_dc + out_sad_dc;
        acc_sad_hori <= acc_sad_hori + out_sad_hori;
        acc_sad_vert <= acc_sad_vert + out_sad_vert;
    end
    else begin
        acc_sad_dc   <= 31'd0;
        acc_sad_hori <= 31'd0;
        acc_sad_vert <= 31'd0;
    end
end

reg signed [8:0] real_residual_reg [0:255];
reg [7:0] real_prediction_reg [0:255];

always @(posedge clk) begin
    real_residual_reg <= real_residual;
    real_prediction_reg <= real_prediction;
end

// smallest SAD
// reg signed [8:0] real_residual [0:255];
// reg [7:0] real_prediction [0:255];
always @(*) begin
    real_residual = real_residual_reg;
    real_prediction = real_prediction_reg;
    if (current_state == S_PREDICTION) begin
        if (current_mode) begin
            if (MB_cnt == 2'd0 && intra_4_cnt == 4'd0) begin
                real_residual = residual_dc;
                real_prediction = prediction_dc;
            end
            else if (!MB_cnt[0] && intra_4_cnt[1:0] == 2'd0) begin
                if (acc_sad_dc > acc_sad_vert) begin
                    real_residual = residual_vert;
                    real_prediction = prediction_vert;
                end
                else begin
                    real_residual = residual_dc;
                    real_prediction = prediction_dc;
                end
            end
            else if (!MB_cnt[1] && intra_4_cnt[3:2] == 2'd0) begin
                if (acc_sad_dc > acc_sad_hori) begin
                    real_residual = residual_hori;
                    real_prediction = prediction_hori;
                end
                else begin
                    real_residual = residual_dc;
                    real_prediction = prediction_dc;
                end
            end
            else begin
                if (acc_sad_vert >= acc_sad_hori && acc_sad_dc > acc_sad_hori) begin
                    real_residual = residual_hori;
                    real_prediction = prediction_hori;
                end
                else if (acc_sad_hori >  acc_sad_vert && acc_sad_dc > acc_sad_vert) begin
                    real_residual = residual_vert;
                    real_prediction = prediction_vert;
                end
                else begin
                    real_residual = residual_dc;
                    real_prediction = prediction_dc;
                end
            end
        end
        else begin
            // TODO: can optimize
            case (MB_cnt)
                0: begin
                    real_residual = residual_dc;
                    real_prediction = prediction_dc;
                end
                1: begin
                    if (acc_sad_dc > acc_sad_hori) begin
                        real_residual = residual_hori;
                        real_prediction = prediction_hori;
                    end
                    else begin
                        real_residual = residual_dc;
                        real_prediction = prediction_dc;
                    end
                end
                2: begin
                    if (acc_sad_dc > acc_sad_vert) begin
                        real_residual = residual_vert;
                        real_prediction = prediction_vert;
                    end
                    else begin
                        real_residual = residual_dc;
                        real_prediction = prediction_dc;
                    end
                end
                default: begin
                    if (acc_sad_vert >= acc_sad_hori && acc_sad_dc > acc_sad_hori) begin
                        real_residual = residual_hori;
                        real_prediction = prediction_hori;
                    end
                    else if (acc_sad_hori >  acc_sad_vert && acc_sad_dc > acc_sad_vert) begin
                        real_residual = residual_vert;
                        real_prediction = prediction_vert;
                    end
                    else begin
                        real_residual = residual_dc;
                        real_prediction = prediction_dc;
                    end
                end
            endcase
        end
    end
end

// ----------------- int transform -----------------

// reg [8:0] transform_cnt;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)                            transform_cnt <= 9'd0;
    else if (current_state == S_TRANSFORM) transform_cnt <= transform_cnt + 9'd1;
    else                                   transform_cnt <= 9'd0;
end

// reg [7:0] prev_transform_cnt;
// reg [7:0] pprev_transform_cnt;
// reg [7:0] ppprev_transform_cnt;
// always @(posedge clk or negedge rst_n) begin
always @(posedge clk) begin
    // if (!rst_n) begin
    //     prev_transform_cnt <= 8'd0;
    //     pprev_transform_cnt <= 8'd0;
    //     ppprev_transform_cnt <= 8'd0;
    // end
    // else begin
        prev_transform_cnt <= (transform_cnt < 9'd16 && current_mode || transform_cnt < 9'd256 && !current_mode) ? transform_cnt : 8'd0;
        pprev_transform_cnt <= prev_transform_cnt;
        ppprev_transform_cnt <= pprev_transform_cnt;
    // end
end

// wire reconstruct_done;
assign reconstruct_done = (ppprev_transform_cnt == 8'd15) && current_mode || (ppprev_transform_cnt == 8'd255);

reg signed [8:0] int_input [0:15];
reg signed [12:0] int_result;

// reg signed [8:0] int_input [0:15];
always @(*) begin
    integer i;
    for (i = 0; i < 16; i = i + 1) int_input[i] = 9'd0;
    if (current_state == S_TRANSFORM) begin
        if (current_mode) begin
            for (i = 0; i < 16; i = i + 1) int_input[i] = real_residual[i + {intra_4_cnt, 4'd0}];
        end
        else begin
            for (i = 0; i < 16; i = i + 1) int_input[i] = real_residual[i + {transform_cnt[8:4], 4'b0}];
        end
    end
end

// reg signed [12:0] int_result;
INT_TRANSFORM i_1 (.A(int_input), .cnt(transform_cnt[3:0]), .result(int_result));

// ----------------- Quantization -----------------

// reg [12:0] q_in;
always @(posedge clk) begin
    q_in <= int_result;
end

// input signed [12:0] in,
// input [4:0] QP,
// input [3:0] cnt,
// output signed [31:0] out

// reg signed [31:0] q_out;
QUANTIZATION q_1 (.in(q_in), .QP(QP_reg), .cnt(prev_transform_cnt[3:0]), .out(q_out));

// ----------------- output -----------------

// wire need_output;
assign need_output = current_state == S_TRANSFORM && 
                     transform_cnt >= 9'd1 && 
                     (transform_cnt <= 9'd16 && current_mode || transform_cnt <= 9'd256 && !current_mode);

// output reg signed [31:0] out_value;
always @(posedge clk or negedge rst_n) begin
    if      (!rst_n)      out_value <= 32'b0;
    else if (need_output) out_value <= q_out;
    else                  out_value <= 32'b0;
end

// output reg out_valid;
always @(posedge clk or negedge rst_n) begin
    if      (!rst_n)      out_valid <= 1'b0;
    else if (need_output) out_valid <= 1'b1;
    else                  out_valid <= 1'b0;
end

// reg [9:0] out_cnt;  // 0~1023
always @(posedge clk or negedge rst_n) begin
    if      (!rst_n)              out_cnt <= 10'd0;
    else if (out_cnt == 10'd1023) out_cnt <= 10'd0;
    else if (need_output)         out_cnt <= out_cnt + 10'd1;
    else                          out_cnt <= out_cnt;
end

// ----------------- De-Quantization -----------------

// input signed [31:0] in,
// input [4:0] QP,
// input [3:0] cnt,
// output signed [31:0] out

// reg signed [31:0] de_q_out;
DE_QUANTIZATION q_2 (.in(out_value), .QP(QP_reg), .cnt(pprev_transform_cnt[3:0]), .out(de_q_out));

// reg signed [31:0] de_W_reg [0:15];
always @(posedge clk) begin
    de_W_reg <= de_W;
end

// reg signed [31:0] de_W [0:15]
always @(*) begin
    de_W = de_W_reg;
    de_W[pprev_transform_cnt[3:0]] = de_q_out;
end

// ----------------- inverse int transform -----------------

// input signed [20:0] A [0:15],        // 21-bit
// input [4:0] QP,
// output signed [31:0] left [0:3],
// output signed [31:0] top  [0:3],

// reg signed [31:0] new_left [0:3];
// reg signed [31:0] new_top  [0:3];
INVERSE_INT_TRANSFORM i_2 (.A(de_W_reg), .QP(QP_reg), .left(new_left), .top(new_top));

// ----------------- re-construction -----------------

// reg [7:0] real_prediction [0:255];

// reg signed [31:0] re_left [0:3];
// reg signed [31:0] re_top  [0:3];
always @(*) begin
    integer i;
    for (i = 0; i < 4; i = i + 1) begin
        re_left[i] = {24'd0, real_prediction[ppprev_transform_cnt + {intra_4_cnt, 4'd0} + (4*i - 12)]} + new_left[i];
        re_top[i]  = {24'd0, real_prediction[ppprev_transform_cnt + {intra_4_cnt, 4'd0} + (i - 3)]} + new_top[i];
        if      (re_left[i] > 255) re_left[i] = 255;
        else if (re_left[i] < 0)   re_left[i] = 0;
        if      (re_top[i] > 255) re_top[i] = 255;
        else if (re_top[i] < 0)   re_top[i] = 0;
    end
end

// ----------------- feedback referance ----------------- L 309

// reg [12:0] ref_left [0:31], ref_left_reg [0:31];
// reg [12:0] ref_top  [0:31], ref_top_reg [0:31];

// reg [12:0] ref_left_reg [0:15];
// reg [12:0] ref_top_reg  [0:31];
always @(posedge clk) begin
    ref_left_reg <= ref_left;
    ref_top_reg <= ref_top;
end

// reg [12:0] ref_left [0:31];
// reg [12:0] ref_top  [0:31];
always @(*) begin
    integer i;
    ref_left = ref_left_reg;
    ref_top = ref_top_reg;
    case (current_state)
        S_INPUT_PARAM: begin
            for (i = 0; i < 32; i = i + 1) begin
                ref_left[i] = 13'd128;
                ref_top [i] = 13'd128;
            end
        end
        S_TRANSFORM: begin
            if (&ppprev_transform_cnt[3:0]) begin
                for (i = 0; i < 4; i = i + 1) begin
                    ref_left[{1'b0, ppprev_transform_cnt[7:6], ppprev_transform_cnt[3:2]} + {MB_cnt[1], intra_4_cnt[3:2], 2'd0} + (i - 3)] = re_left[i][12:0];
                    ref_top [{1'b0, ppprev_transform_cnt[5:4], ppprev_transform_cnt[1:0]} + {MB_cnt[0], intra_4_cnt[1:0], 2'd0} + (i - 3)] = re_top[i][12:0];
                    // ref_left[{1'b0, ppprev_transform_cnt[7:6], ppprev_transform_cnt[3:2]} + {MB_cnt[1], intra_4_cnt[3:2], i[1:0]} - 3] = re_left[i][12:0];
                    // ref_top [{1'b0, ppprev_transform_cnt[5:4], ppprev_transform_cnt[1:0]} + {MB_cnt[0], intra_4_cnt[1:0], i[1:0]} - 3] = re_top[i][12:0];
                end
            end
        end
    endcase
end



endmodule


module SAD (
    input [7:0] in_data,   // 0~255
    input [7:0] prediction,   // 0~255

    output signed [8:0] residual,   // input - prediction, -255~255
    output [11:0] out_sad       // ABS(input - prediction), accumulate in main module
);

// output signed [8:0] residual,   // input - prediction, -255~255
assign residual = {1'b0, in_data} - {1'b0, prediction};

// output [11:0] out_sad       // ABS(input - prediction), accumulate in main module     // 0~255
MATRIX_ABS #(9, 12) a1 (.a(residual), .result(out_sad));

endmodule


// Cf * A * Cf
module INT_TRANSFORM (
    input signed [8:0] A [0:15],        // 9-bit
    input [3:0] cnt,
    output reg signed [12:0] result
);

// output reg signed [12:0] result
always @(*) begin
    case (cnt)
        0:  result = (A[0] + A[1] + A[2] + A[3] + A[4] + A[5] + A[6] + A[7] + A[8] + A[9] + A[10] + A[11] + A[12] + A[13] + A[14] + A[15]);
        1:  result = (A[0] + A[1] - A[2] - A[3] + A[4] + A[5] - A[6] - A[7] + A[8] + A[9] - A[10] - A[11] + A[12] + A[13] - A[14] - A[15]);
        2:  result = (A[0] - A[1] - A[2] + A[3] + A[4] - A[5] - A[6] + A[7] + A[8] - A[9] - A[10] + A[11] + A[12] - A[13] - A[14] + A[15]);
        3:  result = (A[0] - A[1] + A[2] - A[3] + A[4] - A[5] + A[6] - A[7] + A[8] - A[9] + A[10] - A[11] + A[12] - A[13] + A[14] - A[15]);
        4:  result = (A[0] + A[1] + A[2] + A[3] + A[4] + A[5] + A[6] + A[7] - A[8] - A[9] - A[10] - A[11] - A[12] - A[13] - A[14] - A[15]);
        5:  result = (A[0] + A[1] - A[2] - A[3] + A[4] + A[5] - A[6] - A[7] - A[8] - A[9] + A[10] + A[11] - A[12] - A[13] + A[14] + A[15]);
        6:  result = (A[0] - A[1] - A[2] + A[3] + A[4] - A[5] - A[6] + A[7] - A[8] + A[9] + A[10] - A[11] - A[12] + A[13] + A[14] - A[15]);
        7:  result = (A[0] - A[1] + A[2] - A[3] + A[4] - A[5] + A[6] - A[7] - A[8] + A[9] - A[10] + A[11] - A[12] + A[13] - A[14] + A[15]);
        8:  result = (A[0] + A[1] + A[2] + A[3] - A[4] - A[5] - A[6] - A[7] - A[8] - A[9] - A[10] - A[11] + A[12] + A[13] + A[14] + A[15]);
        9:  result = (A[0] + A[1] - A[2] - A[3] - A[4] - A[5] + A[6] + A[7] - A[8] - A[9] + A[10] + A[11] + A[12] + A[13] - A[14] - A[15]);
        10: result = (A[0] - A[1] - A[2] + A[3] - A[4] + A[5] + A[6] - A[7] - A[8] + A[9] + A[10] - A[11] + A[12] - A[13] - A[14] + A[15]);
        11: result = (A[0] - A[1] + A[2] - A[3] - A[4] + A[5] - A[6] + A[7] - A[8] + A[9] - A[10] + A[11] + A[12] - A[13] + A[14] - A[15]);
        12: result = (A[0] + A[1] + A[2] + A[3] - A[4] - A[5] - A[6] - A[7] + A[8] + A[9] + A[10] + A[11] - A[12] - A[13] - A[14] - A[15]);
        13: result = (A[0] + A[1] - A[2] - A[3] - A[4] - A[5] + A[6] + A[7] + A[8] + A[9] - A[10] - A[11] - A[12] - A[13] + A[14] + A[15]);
        14: result = (A[0] - A[1] - A[2] + A[3] - A[4] + A[5] + A[6] - A[7] + A[8] - A[9] - A[10] + A[11] - A[12] + A[13] + A[14] - A[15]);
        15: result = (A[0] - A[1] + A[2] - A[3] - A[4] + A[5] - A[6] + A[7] + A[8] - A[9] + A[10] - A[11] - A[12] + A[13] - A[14] + A[15]);
        default: result = 13'd0;
    endcase
end

endmodule


// Cf * A * Cf
module INVERSE_INT_TRANSFORM (
    input signed [31:0] A [0:15],        // 21-bit
    input [4:0] QP,
    output signed [31:0] left [0:3],
    output signed [31:0] top  [0:3]
);

reg [2:0] shift_bits;     // 2~6

// reg [2:0] shift_bits;     // 2~6
always @(*) begin
    case (QP)
        0, 1, 2, 3, 4, 5      : shift_bits = 3'd6;
        6, 7, 8, 9, 10, 11    : shift_bits = 3'd5;
        12, 13, 14, 15, 16, 17: shift_bits = 3'd4;
        18, 19, 20, 21, 22, 23: shift_bits = 3'd3;
        default               : shift_bits = 3'd2;
    endcase
end

assign left[0] = (A[0] - A[1] + A[2] - A[3] + A[4] - A[5] + A[6] - A[7] + A[8] - A[9] + A[10] - A[11] + A[12] - A[13] + A[14] - A[15]) >>> shift_bits;  // 3
assign left[1] = (A[0] - A[1] + A[2] - A[3] + A[4] - A[5] + A[6] - A[7] - A[8] + A[9] - A[10] + A[11] - A[12] + A[13] - A[14] + A[15]) >>> shift_bits;  // 7
assign left[2] = (A[0] - A[1] + A[2] - A[3] - A[4] + A[5] - A[6] + A[7] - A[8] + A[9] - A[10] + A[11] + A[12] - A[13] + A[14] - A[15]) >>> shift_bits;  // 11
assign left[3] = top[3];

assign top[0] = (A[0] + A[1] + A[2] + A[3] - A[4] - A[5] - A[6] - A[7] + A[8] + A[9] + A[10] + A[11] - A[12] - A[13] - A[14] - A[15]) >>> shift_bits;  // 12
assign top[1] = (A[0] + A[1] - A[2] - A[3] - A[4] - A[5] + A[6] + A[7] + A[8] + A[9] - A[10] - A[11] - A[12] - A[13] + A[14] + A[15]) >>> shift_bits;  // 13
assign top[2] = (A[0] - A[1] - A[2] + A[3] - A[4] + A[5] + A[6] - A[7] + A[8] - A[9] - A[10] + A[11] - A[12] + A[13] + A[14] - A[15]) >>> shift_bits;  // 14
assign top[3] = (A[0] - A[1] + A[2] - A[3] - A[4] + A[5] - A[6] + A[7] + A[8] - A[9] + A[10] - A[11] - A[12] + A[13] - A[14] + A[15]) >>> shift_bits;  // 15


endmodule



module QUANTIZATION (
    input signed [12:0] in,
    input [4:0] QP,
    input [3:0] cnt,
    output signed [31:0] out
);

genvar i;

wire signed [31:0] in_abs;
reg signed [31:0] mf_a, mf_b, mf_c;
reg signed [31:0] MF;
wire signed [31:0] q_tmp;
reg signed [31:0] f;
reg signed [4:0] qbits;
reg signed [31:0] z_abs;

// wire signed [31:0] in_abs;
MATRIX_ABS #(13, 32) abs_1 (.a(in), .result(in_abs));

// reg signed [31:0] mf_a
always @(*) begin
    case (QP)
        0, 6,  12, 18, 24: mf_a = 31'd13107;
        1, 7,  13, 19, 25: mf_a = 31'd11916;
        2, 8,  14, 20, 26: mf_a = 31'd10082;
        3, 9,  15, 21, 27: mf_a = 31'd9362;
        4, 10, 16, 22, 28: mf_a = 31'd8192;
        default          : mf_a = 31'd7282;
    endcase
end

// reg signed [31:0] mf_b
always @(*) begin
    case (QP)
        0, 6,  12, 18, 24: mf_b = 31'd5243;
        1, 7,  13, 19, 25: mf_b = 31'd4660;
        2, 8,  14, 20, 26: mf_b = 31'd4194;
        3, 9,  15, 21, 27: mf_b = 31'd3647;
        4, 10, 16, 22, 28: mf_b = 31'd3355;
        default          : mf_b = 31'd2893;
    endcase
end

// reg signed [31:0] mf_c;
always @(*) begin
    case (QP)
        0, 6,  12, 18, 24: mf_c = 31'd8066;
        1, 7,  13, 19, 25: mf_c = 31'd7490;
        2, 8,  14, 20, 26: mf_c = 31'd6554;
        3, 9,  15, 21, 27: mf_c = 31'd5825;
        4, 10, 16, 22, 28: mf_c = 31'd5243;
        default          : mf_c = 31'd4559;
    endcase
end

// reg signed [31:0] MF;
always @(*) begin
    case (cnt)
        0, 2, 8, 10:  MF = mf_a;
        5, 7, 13, 15: MF = mf_b;
        default:      MF = mf_c;
    endcase
end

// wire signed [31:0] q_tmp [0:15];
assign q_tmp = in_abs * MF;

// reg signed [31:0] f;
always @(*) begin
    case (QP)
        0, 1, 2, 3, 4, 5      : f = 32'd10922;
        6, 7, 8, 9, 10, 11    : f = 32'd21845;
        12, 13, 14, 15, 16, 17: f = 32'd43690;
        18, 19, 20, 21, 22, 23: f = 32'd87381;
        default               : f = 32'd174762;
    endcase
end

// reg signed [4:0] qbits;
always @(*) begin
    case (QP)
        0, 1, 2, 3, 4, 5      : qbits = 5'd15;
        6, 7, 8, 9, 10, 11    : qbits = 5'd16;
        12, 13, 14, 15, 16, 17: qbits = 5'd17;
        18, 19, 20, 21, 22, 23: qbits = 5'd18;
        default               : qbits = 5'd19;
    endcase
end

assign z_abs = (q_tmp + f) >> qbits;

assign out = (z_abs ^ {32{in[12]}}) + {31'd0, in[12]};


endmodule


module DE_QUANTIZATION (
    input signed [31:0] in,
    input [4:0] QP,
    input [3:0] cnt,
    output signed [31:0] out
);

reg signed [31:0] V_a, V_b, V_c;
reg signed [31:0] V;

// reg signed [31:0] V_a
always @(*) begin
    case (QP)
        0, 6,  12, 18, 24: V_a = 31'd10;
        1, 7,  13, 19, 25: V_a = 31'd11;
        2, 8,  14, 20, 26: V_a = 31'd13;
        3, 9,  15, 21, 27: V_a = 31'd14;
        4, 10, 16, 22, 28: V_a = 31'd16;
        default          : V_a = 31'd18;
    endcase
end

// reg signed [31:0] V_b
always @(*) begin
    case (QP)
        0, 6,  12, 18, 24: V_b = 31'd16;
        1, 7,  13, 19, 25: V_b = 31'd18;
        2, 8,  14, 20, 26: V_b = 31'd20;
        3, 9,  15, 21, 27: V_b = 31'd23;
        4, 10, 16, 22, 28: V_b = 31'd25;
        default          : V_b = 31'd29;
    endcase
end

// reg signed [31:0] V_c;
always @(*) begin
    case (QP)
        0, 6,  12, 18, 24: V_c = 31'd13;
        1, 7,  13, 19, 25: V_c = 31'd14;
        2, 8,  14, 20, 26: V_c = 31'd16;
        3, 9,  15, 21, 27: V_c = 31'd18;
        4, 10, 16, 22, 28: V_c = 31'd20;
        default          : V_c = 31'd23;
    endcase
end

// reg signed [31:0] V;
always @(*) begin
    case (cnt)
        0, 2, 8, 10:  V = V_a;
        5, 7, 13, 15: V = V_b;
        default:      V = V_c;
    endcase
end

// output signed [31:0] out
assign out = in * V;


endmodule


// ABS(x) = (x ^ sign) - sign;
module MATRIX_ABS #(
    parameter a_bit_num = 32, 
    parameter result_bit_num = 32
) (
    input signed [a_bit_num-1:0] a,
    output signed [result_bit_num-1:0] result
);

wire [result_bit_num-1:0] a_extend;
wire [result_bit_num-1:0] sign;

assign sign = {result_bit_num{a[a_bit_num-1]}};
assign a_extend = {{(result_bit_num - a_bit_num){a[a_bit_num-1]}}, a};
assign result = (a_extend ^ sign) - sign;

endmodule

module MEM_INTERFACE (
    input [3:0] frame,
    input [4:0] row,
    input [4:0] col,
    output [7:0] Dout,
    input [7:0] Din,
    input clk,
    input WEB
);

// wire [13:0] address;
// assign address = {frame, row, col};

SRAM_16384 sram_1 (.A0(col[0]), .A1(col[1]), .A2(col[2]), .A3(col[3]), .A4(col[4]), 
                   .A5(row[0]), .A6(row[1]), .A7(row[2]), .A8(row[3]), .A9(row[4]), 
                   .A10(frame[0]), .A11(frame[1]), .A12(frame[2]), .A13(frame[3]),
                   .DO0(Dout[0]),.DO1(Dout[1]),.DO2(Dout[2]),.DO3(Dout[3]),.DO4(Dout[4]),.DO5(Dout[5]),.DO6(Dout[6]),.DO7(Dout[7]),
                   .DI0(Din[0]),.DI1(Din[1]),.DI2(Din[2]),.DI3(Din[3]),.DI4(Din[4]),.DI5(Din[5]),.DI6(Din[6]),.DI7(Din[7]),
                   .CK(clk),.WEB(WEB),.OE(1'b1),.CS(1'b1));

endmodule

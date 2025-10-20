`ifdef RTL
    `define CYCLE_TIME 20.0
`endif
`ifdef GATE
    `define CYCLE_TIME 20.0
`endif

module PATTERN #(parameter IP_WIDTH = 9)(
    // input signals
    OUT_WINNER,
	// Output signals
    IN_HOLE_CARD_NUM, IN_HOLE_CARD_SUIT, IN_PUB_CARD_NUM, IN_PUB_CARD_SUIT
);
// ========================================
// Input & Output
// ========================================
output reg [IP_WIDTH*8-1:0]  IN_HOLE_CARD_NUM;
output reg [IP_WIDTH*4-1:0]  IN_HOLE_CARD_SUIT;
output reg [19:0]  IN_PUB_CARD_NUM;
output reg [9:0]  IN_PUB_CARD_SUIT;

input [IP_WIDTH-1:0]  OUT_WINNER;

// ========================================
// Internal Variables
// ========================================
integer f, r, pat_cnt, err_cnt;
reg [256*8-1:0] line;
reg [IP_WIDTH-1:0] expected_bits;
reg [127:0] exp_str;
integer i, len;
reg [255:0] tmp_line;
integer pattern_index;

// temporary read vars
reg [8*IP_WIDTH-1:0]  tmp_hn;
reg [4*IP_WIDTH-1:0]  tmp_hs;
reg [19:0]  tmp_pn;
reg [9:0]   tmp_ps;

// ========================================
// Simulation Control
// ========================================
real CYCLE = `CYCLE_TIME;
reg clk;
initial clk = 0;
always #(`CYCLE_TIME/2.0) clk = ~clk;

// ========================================
// Main process
// ========================================
initial begin
    err_cnt = 0;
    pat_cnt = 0;
    IN_HOLE_CARD_NUM  = 'dx;
    IN_HOLE_CARD_SUIT = 'dx;
    IN_PUB_CARD_NUM   = 'dx;
    IN_PUB_CARD_SUIT  = 'dx;
    expected_bits     = 0;

    f = $fopen("../00_TESTBED/patterns_random.txt", "r");
    if (f == 0) begin
        $display("ERROR: Cannot open patterns_random.txt !");
        $finish;
    end

    $display("==============================================");
    $display("   Start Poker.v Pattern Simulation");
    $display("==============================================");

    while (!$feof(f)) begin
        // 每行格式: <IN_HOLE_CARD_NUM> <IN_HOLE_CARD_SUIT> <IN_PUB_CARD_NUM> <IN_PUB_CARD_SUIT> <EXPECTED_OUT_WINNER>
        r = $fscanf(f, "%h %h %h %h %b\n", tmp_hn, tmp_hs, tmp_pn, tmp_ps, expected_bits);
        if (r != 5) continue;  // 跳過空行

        IN_HOLE_CARD_NUM  = tmp_hn;
        IN_HOLE_CARD_SUIT = tmp_hs;
        IN_PUB_CARD_NUM   = tmp_pn;
        IN_PUB_CARD_SUIT  = tmp_ps;

        // 將 exp_str 轉成位元陣列 (MSB→player[IP_WIDTH-1])
        // for (i = 0; i < IP_WIDTH; i = i + 1) begin
        //     expected_bits[i] = (exp_str[i] == "1") ? 1'b1 : 1'b0;
        // end

        // 等待 combinational 結果穩定
        @(posedge clk);
        pat_cnt = pat_cnt + 1;

        if (OUT_WINNER === expected_bits)
            $display("Pattern %0d : PASS  | OUT=%b  EXP=%b", pat_cnt, OUT_WINNER, expected_bits);
        else begin
            $display("Pattern %0d : FAIL  | OUT=%b  EXP=%b", pat_cnt, OUT_WINNER, expected_bits);
            err_cnt = err_cnt + 1;
            $finish;
        end
        // #(CYCLE);
    end

    $display("==============================================");
    $display("  Total Patterns : %0d", pat_cnt);
    $display("  Total Errors   : %0d", err_cnt);
    $display("==============================================");

    if (err_cnt == 0)
        $display("✅ All Patterns PASS!");
    else
        $display("❌ %0d Patterns FAIL!", err_cnt);

    $fclose(f);
    #(CYCLE) $finish;
end

endmodule


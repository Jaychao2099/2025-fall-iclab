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
// Parameter
// ========================================
parameter Path_in9  = "../00_TESTBED/data_ip9.txt";
parameter Path_in8  = "../00_TESTBED/data_ip8.txt";
parameter Path_in7  = "../00_TESTBED/data_ip7.txt";
parameter Path_in6  = "../00_TESTBED/data_ip6.txt";
parameter Path_in5  = "../00_TESTBED/data_ip5.txt";
parameter Path_in4  = "../00_TESTBED/data_ip4.txt";
parameter Path_in3  = "../00_TESTBED/data_ip3.txt";
parameter Path_in2  = "../00_TESTBED/data_ip2.txt";


integer pat;
integer patnum ;
integer file_in, file_out;
integer j, k;

reg [3:0] r[13:0];
reg [8:0] gold;

reg [IP_WIDTH-1:0] golden_out;
reg [3:0] hcn [8:0][1:0];
reg [1:0] hcs [8:0][1:0];
reg [3:0] pcn [4:0];
reg [1:0] pcs [4:0];
//================================================================
// clock
//================================================================
reg clk;
real	CYCLE = `CYCLE_TIME;
always	#(CYCLE/2.0) clk = ~clk;
initial	clk = 0;



initial begin
	case(IP_WIDTH)
		2 : file_in = $fopen(Path_in2, "r");
		3 : file_in = $fopen(Path_in3, "r");
		4 : file_in = $fopen(Path_in4, "r");
		5 : file_in = $fopen(Path_in5, "r");
		6 : file_in = $fopen(Path_in6, "r");
		7 : file_in = $fopen(Path_in7, "r");
		8 : file_in = $fopen(Path_in8, "r");
		9 : file_in = $fopen(Path_in9, "r");
		default file_in = $fopen(Path_in7, "r");
	endcase
	if(!file_in) $display("Open in file Error!");
	$fscanf(file_in, "%d ", patnum);
	for (pat = 0; pat < patnum; pat = pat + 1)begin
		input_task;
		calculate_task;
		repeat(1) @(negedge clk);
		check_ans_task;
		repeat(3) @(negedge clk);
		$display("PASS PATTERN NO.%4d", pat);
	end
	YOU_PASS_task;
end

task input_task; begin
	
	for(j=0; j<IP_WIDTH; j=j+1)begin
		$fscanf(file_in, "%d %d %d %d", hcn[j][1], hcs[j][1], hcn[j][0], hcs[j][0]);	
	end
	$fscanf(file_in, "%d %d %d %d %d %d %d %d %d %d ", pcn[4], pcs[4], pcn[3], pcs[3], pcn[2], pcs[2], pcn[1], pcs[1], pcn[0], pcs[0]);	
	IN_PUB_CARD_NUM = {pcn[4], pcn[3], pcn[2], pcn[1], pcn[0]};
	IN_PUB_CARD_SUIT = {pcs[4], pcs[3], pcs[2], pcs[1], pcs[0]};
	case(IP_WIDTH)
		2 : begin
			IN_HOLE_CARD_NUM  = {hcn[1][1], hcn[1][0], hcn[0][1], hcn[0][0]};
			IN_HOLE_CARD_SUIT = {hcs[1][1], hcs[1][0], hcs[0][1], hcs[0][0]};
		end
		3 : begin
			IN_HOLE_CARD_NUM  = {hcn[2][1], hcn[2][0], hcn[1][1], hcn[1][0], hcn[0][1], hcn[0][0]};
			IN_HOLE_CARD_SUIT = {hcs[2][1], hcs[2][0], hcs[1][1], hcs[1][0], hcs[0][1], hcs[0][0]};
		end
		4 : begin
			IN_HOLE_CARD_NUM  = {hcn[3][1], hcn[3][0], hcn[2][1], hcn[2][0], hcn[1][1], hcn[1][0], hcn[0][1], hcn[0][0]};
			IN_HOLE_CARD_SUIT = {hcs[3][1], hcs[3][0], hcs[2][1], hcs[2][0], hcs[1][1], hcs[1][0], hcs[0][1], hcs[0][0]};
		end
		5 : begin
			IN_HOLE_CARD_NUM  = {hcn[4][1], hcn[4][0], hcn[3][1], hcn[3][0], hcn[2][1], hcn[2][0], hcn[1][1], hcn[1][0], hcn[0][1], hcn[0][0]};
			IN_HOLE_CARD_SUIT = {hcs[4][1], hcs[4][0], hcs[3][1], hcs[3][0], hcs[2][1], hcs[2][0], hcs[1][1], hcs[1][0], hcs[0][1], hcs[0][0]};
		end
		6 : begin
			IN_HOLE_CARD_NUM  = {hcn[5][1], hcn[5][0], hcn[4][1], hcn[4][0], hcn[3][1], hcn[3][0], hcn[2][1], hcn[2][0], hcn[1][1], hcn[1][0], hcn[0][1], hcn[0][0]};
			IN_HOLE_CARD_SUIT = {hcs[5][1], hcs[5][0], hcs[4][1], hcs[4][0], hcs[3][1], hcs[3][0], hcs[2][1], hcs[2][0], hcs[1][1], hcs[1][0], hcs[0][1], hcs[0][0]};
		end
		7 : begin
			IN_HOLE_CARD_NUM  = {hcn[6][1], hcn[6][0], hcn[5][1], hcn[5][0], hcn[4][1], hcn[4][0], hcn[3][1], hcn[3][0], hcn[2][1], hcn[2][0], hcn[1][1], hcn[1][0], hcn[0][1], hcn[0][0]};
			IN_HOLE_CARD_SUIT = {hcs[6][1], hcs[6][0], hcs[5][1], hcs[5][0], hcs[4][1], hcs[4][0], hcs[3][1], hcs[3][0], hcs[2][1], hcs[2][0], hcs[1][1], hcs[1][0], hcs[0][1], hcs[0][0]};
		end
		8 : begin
			IN_HOLE_CARD_NUM  = {hcn[7][1], hcn[7][0], hcn[6][1], hcn[6][0], hcn[5][1], hcn[5][0], hcn[4][1], hcn[4][0], hcn[3][1], hcn[3][0], hcn[2][1], hcn[2][0], hcn[1][1], hcn[1][0], hcn[0][1], hcn[0][0]};
			IN_HOLE_CARD_SUIT = {hcs[7][1], hcs[7][0], hcs[6][1], hcs[6][0], hcs[5][1], hcs[5][0], hcs[4][1], hcs[4][0], hcs[3][1], hcs[3][0], hcs[2][1], hcs[2][0], hcs[1][1], hcs[1][0], hcs[0][1], hcs[0][0]};
		end
		9 : begin
			IN_HOLE_CARD_NUM  = {hcn[8][1], hcn[8][0], hcn[7][1], hcn[7][0], hcn[6][1], hcn[6][0], hcn[5][1], hcn[5][0], hcn[4][1], hcn[4][0], hcn[3][1], hcn[3][0], hcn[2][1], hcn[2][0], hcn[1][1], hcn[1][0], hcn[0][1], hcn[0][0]};
			IN_HOLE_CARD_SUIT = {hcs[8][1], hcs[8][0], hcs[7][1], hcs[7][0], hcs[6][1], hcs[6][0], hcs[5][1], hcs[5][0], hcs[4][1], hcs[4][0], hcs[3][1], hcs[3][0], hcs[2][1], hcs[2][0], hcs[1][1], hcs[1][0], hcs[0][1], hcs[0][0]};
		end
		default begin
			IN_HOLE_CARD_NUM = 0;
			IN_HOLE_CARD_SUIT = 0;
		end
	endcase
end endtask

task calculate_task; begin
	$fscanf(file_in, "%b", gold);
	case(IP_WIDTH)
		2 : golden_out = {gold[1], gold[0]};
		3 : golden_out = {gold[2], gold[1], gold[0]};
		4 : golden_out = {gold[3], gold[2], gold[1], gold[0]};
		5 : golden_out = {gold[4], gold[3], gold[2], gold[1], gold[0]};
		6 : golden_out = {gold[5], gold[4], gold[3], gold[2], gold[1], gold[0]};
		7 : golden_out = {gold[6], gold[5], gold[4], gold[3], gold[2], gold[1], gold[0]};
		8 : golden_out = {gold[7], gold[6], gold[5], gold[4], gold[3], gold[2], gold[1], gold[0]};
		9 : golden_out = {gold[8], gold[7], gold[6], gold[5], gold[4], gold[3], gold[2], gold[1], gold[0]};
		default : golden_out = 0;
	endcase
end endtask

task check_ans_task; begin
	if(golden_out !== OUT_WINNER)begin
		$display("********************************************************");     
		$display("*                    FAIL!                             *");
		$display("*                 Wrong answer                         *");
		$display("********************************************************");
		$finish;
	end
end endtask

task YOU_PASS_task; begin
    $display ("--------------------------------------------------------------------");
    $display ("                         Congratulations!                           ");
    $display ("                  You have passed all patterns!                     ");
    $display ("--------------------------------------------------------------------");     
    $finish;
end endtask

endmodule
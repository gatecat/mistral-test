module top(input clk, btn, input [3:0] sw, output [7:0] led);

reg [27:0] ctr;

always @(posedge clk)
	if (!btn)
		ctr <= 0;
	else 
		ctr <= ctr + 1'b1;

assign led = ctr[27:20];

endmodule
module top(input clk, btn, input [3:0] sw, output [7:0] led);

reg [23:0] ctr;

localparam N = 50000-1;
wire [N:0] osc;
generate
	genvar ii;
	for (ii = 0; ii < N; ii = ii + 1'b1) begin : luts
		(* keep *) MISTRAL_NOT not_i(.A(osc[ii]), .Q(osc[ii+1'b1]));
	end
endgenerate
assign osc[0] = osc[N];
wire ringosc = osc[N];

always @(posedge ringosc)
	if (!btn)
		ctr <= 0;
	else 
		ctr <= ctr + 1'b1;

assign led = ctr[19:12];

endmodule
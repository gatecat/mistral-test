module top(input [3:0] sw, input btn, output [5:0] led);
	
assign led[0] = &sw;
assign led[1] = |sw;
assign led[2] = ^sw;
assign led[3] = sw[0] ? sw[1] : sw[2];
assign led[4] = btn ? &sw : |sw;
assign led[5] = (sw == 4'hE);

endmodule
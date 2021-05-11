module top(input [3:0] sw, input btn, output [5:0] led);
	
assign led = {{2{btn}}, sw};

endmodule
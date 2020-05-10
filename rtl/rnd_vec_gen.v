
module rnd_vec_gen
(
	input         clk,
	input         save,restore,next, // strobes for required events: positive, one clock cycle long
	output [15:0] out
);

assign out = lfsr[15:0];

reg [16:0] lfsr, saved; 

always @(posedge clk) begin
	if( next )    lfsr  <= {(lfsr[0] ^ lfsr[2] ^ !lfsr), lfsr[16:1]}; 
	if( save )    saved <= lfsr;
	if( restore ) lfsr  <= saved;
end

endmodule

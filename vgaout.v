// input clock: 14MHz
// output format: 31460 x 70 Hz (like 720x400@70)

module vgaout(
 input clk,

 input [31:0] rez1,
 input [31:0] rez2,
 input [5:0] rez3,
 input [5:0] rez4,

 output reg hs,
 output reg vs,
 output reg de,
 output reg [1:0] b,
 output reg [1:0] r,
 output reg [1:0] g
);

/*
parameter H_TOTAL = 12'd858;
parameter H_FP = 12'd16;
parameter H_SYNC = 12'd62;
parameter H_BP = 12'd60;
*/

 localparam HSYNC_BEG   = 12'd0;
 localparam HSYNC_END   = 12'd62;
 localparam HSCRN_BEG   = 12'd78;
 localparam HREZ        = 12'd200;
 localparam HSCRN_END   = 12'd798;
 localparam HMAX        = 12'd858; // 890;

/*
parameter V_TOTAL_0 = 12'd525;
parameter V_FP_0 = 12'd9;
parameter V_SYNC_0 = 12'd6;
parameter V_BP_0 = 12'd30;
*/
 localparam VSYNC_BEG   = 12'd0;
 localparam VSYNC_END   = 12'd6;
 localparam VSCRN_BEG   = 12'd15;
 localparam VREZ1       = 12'd128;
 localparam VREZ3       = 12'd54; // 9'd216;
 localparam VREZ4       = 12'd59; // 9'd236;
 localparam VREZ2       = 12'd256;
 localparam VSCRN_END   = 12'd495;
 localparam VMAX        = 12'd525;

 reg [11:0] hcount, vcount;
 reg hscr, vscr, nextline;
 reg [31:0] r1, r2;

 reg [5:0] xr;          initial xr=6'h3f;
 reg [3:0] yr;          initial yr=4'hf;

 reg [5:0] rrc;         initial rrc=6'h3f;
 wire r34pix;
 assign r34pix = ( ( (vcount[8:2]==VREZ3) || (vcount[8:2]==VREZ4) ) && (rrc==xr) );

 wire [3:0] rn;
 wire rezpix;

 assign rn = (vcount[8]) ? r2[31:28] : r1[31:28];

 hexnum digs( .value(rn), .x({xr[2],xr[1]|xr[0]}), .y({yr[3:2],yr[1]|yr[0]}), .image(rezpix) );

always @(posedge clk) begin

	if (hcount==HMAX) hcount <= 9'd0;
		else hcount <= hcount + 9'd1;

	if (hcount==HSCRN_END) begin
		hscr <= 1'b0;
		de <= 0;
	end else if (hcount==HSCRN_BEG) begin
		hscr <= 1'b1;
		de <= vscr;
	end

	if (hcount==HSYNC_BEG) begin
		nextline <= 1'b1;
		hs <= 1'b0;                  // negative H-sync
	end
	else
	begin
		nextline <= 1'b0;
		if (hcount==HSYNC_END)
			hs <= 1'b1;
	end

	if (hcount==HREZ) begin
		xr <= 6'd0;
		r1 <= rez1;
		r2 <= rez2;
		if (vcount[11:2]==VREZ3)
			rrc <= rez3;
		else if (vcount[11:2]==VREZ4)
			rrc <= rez4;
	end
	else if ( (!hcount[2:0]) && (xr!=6'h3f) ) begin
		xr <= xr + 6'd1;
		if (xr[2:0]==3'd7) begin
			r1[31:4] <= r1[27:0];
			r2[31:4] <= r2[27:0];
		end
	end

	if (nextline) begin
		if (vcount==VMAX)
			vcount <= 9'd0;
		else
			vcount <= vcount + 9'd1;

		if (vcount==VSCRN_END)
			vscr <= 1'b0;
		else if (vcount==VSCRN_BEG)
			vscr <= 1'b1;

		if (vcount==VSYNC_BEG)
			vs <= 1'b1;                 // positive V-sync
		else if (vcount==VSYNC_END)
			vs <= 1'b0;

		if ( (vcount==VREZ1) || (vcount==VREZ2) )
			yr <= 4'd0;
		else if ( (vcount[2:0]==3'b000) && (yr!=4'hf) )
			yr <= yr + 4'd1;

	end

	{g,r,b} <= (r34pix) ? 6'b101010 :
             (
              (rezpix) ?
              ( (vcount[8]) ? 6'b001100 : 6'b110000 )
              :
              ( (hscr&vscr) ? 6'b000001 : 6'b000000 )
             );
end

endmodule

//=============================================================================

module hexnum
(
	input wire [3:0] value,
	input wire [1:0] x,
	input wire [2:0] y,

	output wire image
);

reg [6:0] ss;
reg i;

always @(*) begin
	case (value)  //gfedcba
	4'h0: ss <= 7'b0111111;
	4'h1: ss <= 7'b0000110;
	4'h2: ss <= 7'b1011011;
	4'h3: ss <= 7'b1001111;
	4'h4: ss <= 7'b1100110;
	4'h5: ss <= 7'b1101101;
	4'h6: ss <= 7'b1111101;
	4'h7: ss <= 7'b0000111;
	4'h8: ss <= 7'b1111111;
	4'h9: ss <= 7'b1101111;
	4'ha: ss <= 7'b1110111;
	4'hb: ss <= 7'b1111100;
	4'hc: ss <= 7'b0111001;
	4'hd: ss <= 7'b1011110;
	4'he: ss <= 7'b1111001;
	4'hf: ss <= 7'b1110001;
	endcase
end

always @(*) begin
	case (y)
	3'd0: case (x)
				3'd0: i <= ss[0]|ss[5];
				3'd1: i <= ss[0];
				3'd2: i <= ss[0]|ss[1];
				default: i <= 1'b0;
			endcase
	3'd1: case (x)
				3'd0: i <= ss[5];
				3'd2: i <= ss[1];
				default: i <= 1'b0;
			endcase
	3'd2: case (x)
				3'd0: i <= ss[5]|ss[4];//|ss[6];
				3'd1: i <= ss[6];
				3'd2: i <= ss[1]|ss[2];//|ss[6];
				default: i <= 1'b0;
			endcase
	3'd3: case (x)
				3'd0: i <= ss[4];
				3'd2: i <= ss[2];
				default: i <= 1'b0;
			endcase
	3'd4: case (x)
				3'd0: i <= ss[3]|ss[4];
				3'd1: i <= ss[3];
				3'd2: i <= ss[3]|ss[2];
				default: i <= 1'b0;
			endcase
	default: i <= 1'b0;
	endcase
end

assign image = i;

endmodule

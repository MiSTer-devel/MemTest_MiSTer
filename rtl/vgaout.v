// input clock: 14MHz
// output format: 31460 x 70 Hz (like 720x400@70)

module vgaout
(
	input clk,

	input [31:0] rez1,
	input [31:0] rez2,
	input  [1:0] rez3,
	input  [5:0] bg,

	input [15:0] freq,
	input [15:0] elapsed,
	input  [7:0] mark,

	output reg hs,
	output reg vs,
	output reg de,
	output reg [1:0] b,
	output reg [1:0] r,
	output reg [1:0] g
);

localparam HSYNC_BEG   = 12'd0;
localparam HSYNC_END   = 12'd62;
localparam HSCRN_BEG   = 12'd128;
localparam HREZ        = 12'd240;
localparam HSCRN_END   = 12'd848;
localparam HMAX        = 12'd858;

localparam VSYNC_BEG   = 12'd0;
localparam VSYNC_END   = 12'd6;
localparam VSCRN_BEG   = 12'd30;
localparam VREZ4       = 12'd96;
localparam VREZ3       = 12'd112;
localparam VREZ1       = 12'd240;
localparam VREZ2       = 12'd368;
localparam VSCRN_END   = 12'd510;
localparam VMAX        = 12'd525;

reg [11:0] hcount, vcount;
reg hscr, vscr, nextline;
reg [31:0] r1, r2, r3;
reg [7:0] r4;

reg [5:0] xr;
reg [3:0] yr;

wire [3:0] rn;
wire rezpix;

assign rn = (vcount>=VREZ2) ? r2[31:28] : (vcount>=VREZ1) ? r1[31:28] : r3[31:28];

wire pix = (vcount<VREZ3) ? mpix : rezpix;
wire [5:0] pixcolor = (vcount>=VREZ2) ? 6'b001100 : (vcount>=VREZ1) ? (!xr[5:4] ? 6'b110011 : 6'b110000) : (vcount>=VREZ3) ? 6'b111100 : 6'b110011;

hexnum digs
(
	.value((vcount<VREZ2 && vcount>=VREZ1 && xr[5:3]==1) ? {1'b1, 2'b00, rez3} : rn),
	.x(xr[2:0]),
	.y({yr[3:2],yr[1]|yr[0]}),
	.hide(vcount<VREZ1 && xr[5:3]==4),

	.image(rezpix)
);

wire mpix = ({xr[2],xr[1]|xr[0]} <= 2) && ((vcount>>3) == (VREZ4>>3)) && r4[7];

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
		r3 <= {elapsed, freq};
		r4 <= mark;
	end
	else if ( (!hcount[2:0]) && (xr!=6'h3f) ) begin
		xr <= xr + 6'd1;
		if (xr[2:0]==3'd7) begin
			r1[31:4] <= r1[27:0];
			r2[31:4] <= r2[27:0];
			r3[31:4] <= r3[27:0];
			r4[7:1]  <= r4[6:0];
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

		if ( (vcount==VREZ1) || (vcount==VREZ2) || (vcount==VREZ3))
			yr <= 4'd0;
		else if ( (vcount[2:0]==3'b000) && (yr!=4'hf) )
			yr <= yr + 4'd1;

	end

	{g,r,b} <= pix ? pixcolor : (hscr&vscr) ? bg : 6'b000000;

end

endmodule

//=============================================================================

module hexnum
(
	input  [4:0] value,
	input  [2:0] x,
	input  [2:0] y,
	input        hide,

	output image
);

reg [8:0] ss;
reg i;

always @(*) begin
	ss = 9'b000000000;
	if(~hide) begin
		case (value)  //gfedcba
		'h00: ss = 9'b000111111;
		'h01: ss = 9'b000000110;
		'h02: ss = 9'b001011011;
		'h03: ss = 9'b001001111;
		'h04: ss = 9'b001100110;
		'h05: ss = 9'b001101101;
		'h06: ss = 9'b001111101;
		'h07: ss = 9'b000000111;
		'h08: ss = 9'b001111111;
		'h09: ss = 9'b001101111;
		'h0a: ss = 9'b001110111;
		'h0b: ss = 9'b001111100;
		'h0c: ss = 9'b000111001;
		'h0d: ss = 9'b001011110;
		'h0e: ss = 9'b001111001;
		'h0f: ss = 9'b001110001;
		'h10: ss = 9'b000000000;
		'h11: ss = 9'b010000000;
		'h12: ss = 9'b100000000;
		'h13: ss = 9'b110000000;
		default: ss = 9'b000000000;
		endcase
	end
end

always @(*) begin
	case (y)
	0: case (x)
			0:       i = ss[0]|ss[5];
			1,2,3:   i = ss[0];
			4:       i = ss[0]|ss[1];
			default: i = 0;
		endcase
	1: case (x)
			0:       i = ss[5];
			2:       i = ss[7];
			4:       i = ss[1];
			default: i = 0;
		endcase
	2: case (x)
			0:       i = ss[5]|ss[4];//|ss[6];
			1,2,3:   i = ss[6];
			4:       i = ss[1]|ss[2];//|ss[6];
			default: i = 0;
		endcase
	3: case (x)
			0:       i = ss[4];
			2:       i = ss[8];
			4:       i = ss[2];
			default: i = 0;
		endcase
	4: case (x)
			0:       i = ss[3]|ss[4];
			1,2,3:   i = ss[3];
			4:       i = ss[3]|ss[2];
			default: i = 0;
		endcase
	default:       i = 0;
	endcase
end

assign image = i;

endmodule

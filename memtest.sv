//============================================================================
//
//  Memory testes for MiSTer.
//  Copyright (C) 2017-2019 Sorgelig
//
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [45:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	output  [7:0] VIDEO_ARX,
	output  [7:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = 0;

assign VGA_SL = 0;
assign VGA_F1 = 0;
assign VIDEO_ARX = 16;
assign VIDEO_ARY = 9;

assign AUDIO_S = 0;
assign AUDIO_L = 0;
assign AUDIO_R = 0;
assign AUDIO_MIX = 0;

assign LED_DISK  = 0;
assign LED_POWER = 0;
assign LED_USER  = 0;
assign BUTTONS   = 0;

wire [31:0] status;
wire  [1:0] buttons;

`include "build_id.v" 
localparam CONF_STR = 
{
	"MEMTEST;;",
	"V,v",`BUILD_DATE
};

reg  [10:0] ps2_key;
wire  [1:0] sdram_sz;
hps_io #(.STRLEN($size(CONF_STR)>>3)) hps_io
(
	.clk_sys(CLK_50M),
	.HPS_BUS(HPS_BUS),

	.conf_str(CONF_STR),
	.status(status),
	.buttons(buttons),
	.sdram_sz(sdram_sz),

	.ps2_key(ps2_key),
	.ps2_kbd_led_use(0),
	.ps2_kbd_led_status(0)
);


///////////////////////////////////////////////////////////////////
wire clk_ram, locked;

pll pll
(
	.*,
	.refclk(CLK_50M),
	.rst(pll_reset | RESET),
	.outclk_0(clk_ram)
);

wire        mgmt_waitrequest;
reg         mgmt_write;
reg  [5:0]  mgmt_address;
reg  [31:0] mgmt_writedata;
wire [63:0] reconfig_to_pll;
wire [63:0] reconfig_from_pll;

pll_cfg pll_cfg
(
	.*,
	.mgmt_clk(CLK_50M),
	.mgmt_reset(RESET),
	.mgmt_read(0),
	.mgmt_readdata()
);

reg recfg = 0;
reg pll_reset = 0;

// Phases here are empirically adjusted based on 167MHz synthesized core 
// so arn't reliable for fixed frequency cores.
wire [31:0] cfg_param[44] =
'{ //      M         K          C
	'h167, 'h00808, 'hB33332DD, 'h20302,
	'h160, 'h00808, 'h00000001, 'h20302,
	'h150, 'h20807, 'h00000001, 'h20302,
	'h140, 'h00707, 'h00000001, 'h20302,
	'h130, 'h00505, 'h66666611, 'h00202,
	'h120, 'h00707, 'h66666611, 'h00303,
	'h110, 'h20706, 'h333332DD, 'h00303,
	'h100, 'h00404, 'h00000001, 'h00202,
	 'h90, 'h00707, 'h66666666, 'h00404,
	 'h80, 'h00707, 'h66666666, 'h20504,
	 'h70, 'h00707, 'h00000001, 'h00505
};

reg   [3:0] pos  = 0;
reg  [15:0] mins = 0;
reg  [15:0] secs = 0;
reg         auto = 0;

always @(posedge CLK_50M) begin
	reg  [7:0] state = 0;
	integer    min = 0, sec = 0;
	reg        old_stb = 0;

	mgmt_write <= 0;

	if(((locked && !mgmt_waitrequest) || pll_reset) && recfg) begin
		state <= state + 1'd1;
		if(!state[2:0]) begin
			case(state[7:3])
				// Start
				0: begin
						mgmt_address   <= 0;
						mgmt_writedata <= 0;
						mgmt_write     <= 1;
					end

				// M
				1: begin
						mgmt_address   <= 4;
						mgmt_writedata <= cfg_param[{pos, 2'd1}];
						mgmt_write     <= 1;
					end

				// K
				2: begin
						mgmt_address   <= 7;
						mgmt_writedata <= cfg_param[{pos, 2'd2}];
						mgmt_write     <= 1;
					end

				// N
				3: begin
						mgmt_address   <= 3;
						mgmt_writedata <= 'h10000;
						mgmt_write     <= 1;
					end

				// C0
				4: begin
						mgmt_address   <= 5;
						mgmt_writedata <= cfg_param[{pos, 2'd3}];
						mgmt_write     <= 1;
					end

				// Charge pump
				5: begin
						mgmt_address   <= 9;
						mgmt_writedata <= 1;
						mgmt_write     <= 1;
					end

				// Bandwidth
				6: begin
						mgmt_address   <= 8;
						mgmt_writedata <= 7;
						mgmt_write     <= 1;
					end

				// Apply
				7: begin
						mgmt_address   <= 2;
						mgmt_writedata <= 0;
						mgmt_write     <= 1;
					end

				8: pll_reset <= 1;
				9: pll_reset <= 0;

				10: recfg <= 0;
			endcase
		end
	end

	if(recfg) begin
		{min, mins} <= 0;
		{sec, secs} <= 0;
	end else begin
		min <= min + 1;
		if(min == 2999999999) begin
			min <= 0;
			if(mins[3:0]<9) mins[3:0] <= mins[3:0] + 1'd1;
			else begin
				mins[3:0] <= 0;
				if(mins[7:4]<9) mins[7:4] <= mins[7:4] + 1'd1;
				else begin
					mins[7:4] <= 0;
					if(mins[11:8]<9) mins[11:8] <= mins[11:8] + 1'd1;
					else begin
						mins[11:8] <= 0;
						if(mins[15:12]<9) mins[15:12] <= mins[15:12] + 1'd1;
						else mins[15:12] <= 0;
					end
				end
			end
		end
		sec <= sec + 1;
		if(sec == 4999999) begin
			sec <= 0;
			secs <= secs + 1'd1;
		end
	end

	old_stb <= ps2_key[10];
	if(old_stb != ps2_key[10]) begin
		state <= 0;
		if(ps2_key[9]) begin
			if(ps2_key[7:0] == 'h75 && pos > 0) begin
				recfg <= 1;
				pos <= pos - 1'd1;
				auto <= 0;
			end
			if(ps2_key[7:0] == 'h72 && pos < 10) begin
				recfg <= 1;
				pos <= pos + 1'd1;
				auto <= 0;
			end
			if(ps2_key[7:0] == 'h5a) begin
				recfg <= 1;
				auto <= 0;
			end
			if(ps2_key[7:0] == 'h1c) begin
				recfg <= 1;
				pos <= 0;
				auto <= 1;
			end
		end
	end

	if(auto && (failcount && passcount) && !recfg && pos < 10) begin
		recfg <= 1;
		pos <= pos + 1'd1;
	end
	
	if(status[0] | buttons[1]) begin
		recfg <= 1;
		pos <= 0;
		auto <= 1;
	end
end


///////////////////////////////////////////////////////////////////
assign SDRAM_CKE = 1;

reg reset = 0;
always @(posedge clk_ram) begin
	integer timeout;

	if(timeout) timeout <= timeout - 1;
	reset <= |timeout;

	if((recfg || ~locked) && (timeout < 1000000)) timeout <= 1000000;

	if(RESET) timeout <= 100000000;
end

wire [31:0] passcount, failcount;
tester my_memtst
(
	.clk(clk_ram),
	.rst_n(~reset),
	.sz(sdram_sz),
	.passcount(passcount),
	.failcount(failcount),
	.DRAM_CLK(SDRAM_CLK),
	.DRAM_DQ(SDRAM_DQ),
	.DRAM_ADDR(SDRAM_A),
	.DRAM_LDQM(SDRAM_DQML),
	.DRAM_UDQM(SDRAM_DQMH),
	.DRAM_WE_N(SDRAM_nWE),
	.DRAM_CS_N(SDRAM_nCS),
	.DRAM_RAS_N(SDRAM_nRAS),
	.DRAM_CAS_N(SDRAM_nCAS),
	.DRAM_BA_0(SDRAM_BA[0]),
	.DRAM_BA_1(SDRAM_BA[1])
);


///////////////////////////////////////////////////////////////////
wire videoclk;

vpll vpll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(videoclk)
);

assign CLK_VIDEO = videoclk;
assign CE_PIXEL  = 1;

wire hs, vs;
wire [1:0] b, r, g;
vgaout showrez
(
	.clk(videoclk),
	.rez1({sdram_sz, passcount[27:0]}),
	.rez2(failcount),
	.bg(6'b000001),
	.freq(16'hF000 | cfg_param[{pos, 2'd0}][11:0]),
	.elapsed(mins),
	.mark(8'h80 >> {~auto, secs[2:0]}),
	.hs(hs),
	.vs(vs),
	.de(VGA_DE),
	.b(b),
	.r(r),
	.g(g)
);

assign VGA_HS = ~hs;
assign VGA_VS = ~vs;

assign VGA_B  = {4{b}};
assign VGA_R  = {4{r}};
assign VGA_G  = {4{g}};

endmodule

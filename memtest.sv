module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [44:0] HPS_BUS,

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

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)
	input         TAPE_IN,

	// SD-SPI
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
	output        SDRAM_nWE
);

assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;

assign VIDEO_ARX = 16;
assign VIDEO_ARY = 9;

assign AUDIO_S = 0;
assign AUDIO_L = 0;
assign AUDIO_R = 0;
assign AUDIO_MIX = 0;

assign LED_DISK  = 0;
assign LED_POWER = 0;
assign LED_USER  = 0;

localparam CONF_STR = 
{
	"MEMTEST;;"
};


hps_io #(.STRLEN($size(CONF_STR)>>3)) hps_io
(
	.clk_sys(clk),
	.HPS_BUS(HPS_BUS),

	.conf_str(CONF_STR),

	.ps2_kbd_led_use(0),
	.ps2_kbd_led_status(0)
);


////////////////////   CLOCKS   ///////////////////
wire clk, videoclk, locked;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk),
	.outclk_1(SDRAM_CLK),
	.outclk_2(videoclk),
	.locked(locked)
);

assign CLK_VIDEO = videoclk;
assign CE_PIXEL  = 1;

parameter DRAM_COL_SIZE = 9;
parameter DRAM_ROW_SIZE = 13;


assign SDRAM_CKE = ~RESET;

wire rst_n;
defparam my_reset.RST_CNT_SIZE = 16;
resetter my_reset
(
	.clk(clk),
	.rst_in_n( ~RESET & locked ),
	.rst_out_n(rst_n)
);


wire [31:0] passcount, failcount;
wire [3:0] mmtst_state;
wire [5:0] sdram_state;
defparam my_memtst.DRAM_COL_SIZE = DRAM_COL_SIZE;
defparam my_memtst.DRAM_ROW_SIZE = DRAM_ROW_SIZE;
mem_tester my_memtst
(
	.clk(clk),
	.rst_n(rst_n),
	.passcount(passcount),
	.failcount(failcount),
	.mmtst_state(mmtst_state),
	.sdram_state(sdram_state),
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


wire hs, vs;
wire [1:0] b, r, g;
vgaout showrez
(
	.clk(videoclk),
	.rez1(passcount),
	.rez2(failcount),
	.rez3({2'b00,mmtst_state}),
	.rez4(sdram_state),
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

//`define MEM_SIZE_32M    // uncomment for K4S561632, else (for K4S281632) comment it


module sdram_test
(
 input CLK_20,
 input CLK_20_ALT,

 output [7:0] SOUND_LEFT,
 output [7:0] SOUND_RIGHT,

 output [7:0] VIDEO_R,
 output [7:0] VIDEO_G,
 output [7:0] VIDEO_B,

 output VIDEO_HSYNC,
 output VIDEO_VSYNC,

 inout [15:0] ARM_AD,
 input [23:16] ARM_A,

 input ARM_RD,
 input ARM_WR,
 input ARM_ALE,
 output ARM_WAIT,

 input [5:0] JOY0,
 output JOY0_SEL,
 input [5:0] JOY1,
 output JOY1_SEL,

 inout KEYS_CLK,
 inout KEYS_DATA,

 inout MOUSE_CLK,
 inout MOUSE_DATA,

 // SD-RAM ports
 output pMemClk,            // SD-RAM Clock
 output pMemCke,            // SD-RAM Clock enable
 output pMemCs_n,           // SD-RAM Chip select
 output pMemRas_n,          // SD-RAM Row/RAS
 output pMemCas_n,          // SD-RAM /CAS
 output pMemWe_n,           // SD-RAM /WE
 output pMemUdq,            // SD-RAM UDQM
 output pMemLdq,            // SD-RAM LDQM
 output pMemBa1,            // SD-RAM Bank select address 1
 output pMemBa0,            // SD-RAM Bank select address 0
 output [12:0] pMemAdr,     // SD-RAM Address
 inout  [15:0] pMemDat,     // SD-RAM Data

 input RESET_n
);

 assign ARM_AD = 16'hzzzz;
 assign KEYS_CLK = 1'bz;
 assign KEYS_DATA = 1'bz;
 assign MOUSE_CLK = 1'bz;
 assign MOUSE_DATA = 1'bz;

 assign SOUND_LEFT = 8'd0;
 assign SOUND_RIGHT = 8'd0;
 assign ARM_WAIT = 1'b0;
 assign JOY0_SEL = 1'b0;
 assign JOY1_SEL = 1'b0;

//-----------------------------------------------------------------------------

`ifdef MEM_SIZE_32M
 parameter DRAM_COL_SIZE = 9;
 parameter DRAM_ROW_SIZE = 13;
`else
 assign pMemAdr[12] = 1'b0;
 parameter DRAM_COL_SIZE = 9;
 parameter DRAM_ROW_SIZE = 12;
`endif

//-----------------------------------------------------------------------------


 wire clk, sdram_clk, videoclk, locked;
 pll my_pll( .inclk0(CLK_20), .c0(clk), .c1(videoclk), .c2(sdram_clk), .locked(locked) );
 assign pMemClk = sdram_clk;
 assign pMemCke = 1'b1;


 wire rst_n;
 defparam my_reset.RST_CNT_SIZE = 16;
 resetter my_reset( .clk(clk), .rst_in_n( RESET_n & locked ), .rst_out_n(rst_n) );


 wire [31:0] passcount, failcount;
 wire [3:0] mmtst_state;
 wire [5:0] sdram_state;
 defparam my_memtst.DRAM_COL_SIZE = DRAM_COL_SIZE;
 defparam my_memtst.DRAM_ROW_SIZE = DRAM_ROW_SIZE;
 mem_tester my_memtst( .clk(clk), .rst_n(rst_n), .passcount(passcount), .failcount(failcount),
                       .mmtst_state(mmtst_state),
                       .sdram_state(sdram_state),
                       .DRAM_DQ(pMemDat),      .DRAM_ADDR(pMemAdr[DRAM_ROW_SIZE-1:0]),
                       .DRAM_LDQM(pMemLdq),    .DRAM_UDQM(pMemUdq),
                       .DRAM_WE_N(pMemWe_n),   .DRAM_CS_N(pMemCs_n),
                       .DRAM_RAS_N(pMemRas_n), .DRAM_CAS_N(pMemCas_n),
                       .DRAM_BA_0(pMemBa0),    .DRAM_BA_1(pMemBa1) );


 wire hs, vs;
 wire [1:0] b, r, g;
 vgaout showrez( .clk(videoclk),
                 .rez1(passcount),
                 .rez2(failcount),
                 .rez3({2'b00,mmtst_state}),
                 .rez4(sdram_state),
                 .hs(hs),
                 .vs(vs),
                 .b(b), .r(r), .g(g)
               );
 assign VIDEO_HSYNC = hs;
 assign VIDEO_VSYNC = vs;
 assign VIDEO_B = { 1'b0,b[1],b[0],b[1],b[0],b[1],b[0],b[1] };
 assign VIDEO_R = { 1'b0,r[1],r[0],r[1],r[0],r[1],r[0],r[1] };
 assign VIDEO_G = { 1'b0,g[1],g[0],g[1],g[0],g[1],g[0],g[1] };


endmodule

//-----------------------------------------------------------------------------

/*
  read sequence

clk   ``\____/````\____/` ..... _/````\____/````\____/` ..... _/````\____/````\____/`
             |         |         |         |         |         |         |
start XXXX```````````\__ ....... ____________________________________________________
             |         |         |         |         |         |         |
rnw   XXXXXX```XXXXXXXXX ....... XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
             |         | some    |         |         |         |         |
ready XXXXXXX\__________ clocks __/``````````````````  ....... ```````````\__________
                         before                                |         |
rdat  ------------------ ready  -< cell 0  | cell 1  | ....... |last cell>-----------
             |         |         |         |         |         |         |
done  XXXXXXX\__________ ....... _____________________ ....... ___________/``````````
                                                                            ^all operations stopped until next start strobe



  write sequence

clk   ``\____/````\____/` ..... _/````\____/````\____/````\____/````\____/````\____/````\____/````\____/
             |         | some    |         | some    |         |         |         |         |         |
start XXXX```````````\__ ....... _____________ .... ______________ .... ________________________________
             |         | clocks  |         | clocks  |         |         |         |         |         |
rnw   XXXXXX___XXXXXXXXX ....... XXXXXXXXXXXXX .... XXXXXXXXXXXXXX .... XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
             |         | before  |         | before  |         |         |         |         |         |
ready XXXXXXX\__________ ....... _/`````````\_ .... __/`````````\_ .... __/`````````\___________________
             |         | first   |         | next    |         |         |         |         |         |
wdat  XXXXXXXXXXXXXXXXXXXXXXXXXXXX< cell 0  >X .... XX< cell 1  >X .... XX<last cell>XXXXXXXXXXXXXXXXXXX
             |         | ready   |         | ready   |         |         |         |         |         |
done  XXXXXXXX\_________ ....... _____________ .... ______________ .... ____________/```````````````````
             |         | strobe  |         | strobe  |         |         |         |         |         |

*/


module sdram
(
	input             clk,
	input             rst_n, // total reset

	input             start, // start sequence
	output reg        done,  // =1 when operation is done,
						          // also done=0 while reset SDRAM initialisation is in progress

	input             rnw,   // 1 - read, 0 - write sequence (latched when start=1)
	output reg        ready, // strobe. when writing, one means that data from wdat written to the memory
						          // when reading, one means that data read from memory is on rdat output

	input      [15:0] wdat,  // input, data to be written to memory
	output reg [15:0] rdat,  // output, data last read from memory

	input       [1:0] sz,

	output reg        DRAM_LDQM,DRAM_UDQM,
	output reg        DRAM_WE_N,
	output reg        DRAM_CAS_N,
	output reg        DRAM_RAS_N,
	output reg        DRAM_CS_N,
	output reg        DRAM_BA_0,
	output reg        DRAM_BA_1,
	inout  reg [15:0] DRAM_DQ,
	output reg [12:0] DRAM_ADDR
);

reg [12:0] sdaddr;
reg  [1:0] ba;

always @(*) begin
	if(!rst_n) begin
		{DRAM_UDQM,DRAM_LDQM} = 2'bZZ;
		{DRAM_BA_1,DRAM_BA_0} = 2'bZZ;
		DRAM_ADDR  = 13'bZ;
		DRAM_WE_N  = 1'bZ;
		DRAM_CAS_N = 1'bZ;
		DRAM_RAS_N = 1'bZ;
		DRAM_CS_N  = 1'bZ;
	end
	else begin
		{DRAM_UDQM,DRAM_LDQM} = sdaddr[12:11];
		{DRAM_BA_1,DRAM_BA_0} = ba;
		DRAM_ADDR  = sdaddr;
		DRAM_WE_N  = cmd[0];
		DRAM_CAS_N = cmd[1];
		DRAM_RAS_N = cmd[2];
		DRAM_CS_N  = cs;
	end
end

reg  [2:0] cmd;
reg        cs;

wire [2:0] CMD_NOP             = 3'b111;
wire [2:0] CMD_ACTIVE          = 3'b011;
wire [2:0] CMD_READ            = 3'b101;
wire [2:0] CMD_WRITE           = 3'b100;
wire [2:0] CMD_PRECHARGE       = 3'b010;
wire [2:0] CMD_AUTO_REFRESH    = 3'b001;
wire [2:0] CMD_LOAD_MODE       = 3'b000;


reg [4:0] initstate;
reg       init_done;
always @ (posedge clk) begin
	if(!rst_n) begin
		initstate <= 0;
		init_done <= 0;
	end else begin
		if (state == 5) begin
			if(~&initstate) initstate <= initstate + 4'd1;
			else init_done <= 1;
		end
	end
end

reg [2:0] state;
always @ (posedge clk) state <= state + 1'd1;

always @ (posedge clk) begin
	ready <= 0;
	if(wr) case(state) 3,4,5,6: ready <= 1; endcase
	if(rd) case(state) 0,1,2,3: ready <= 1; endcase
end

reg  [2:0] cas_cmd;
reg        wr,rd;
always @ (posedge clk) begin
	reg  [9:0] cas_addr;
	reg [23:0] addr; // x4
	reg  [5:0] rcnt = 0;
	reg        rnw_reg;

	DRAM_DQ <= (wr & ready) ? wdat : 16'bZ;
	rdat    <= DRAM_DQ;
	cmd     <= CMD_NOP;

	if(!init_done) begin
		cs <= initstate[4];

		if(state == 1) begin
			case(initstate[3:0])
				2 : begin
					sdaddr[10] <= 1; // all banks
					cmd        <= CMD_PRECHARGE;
				end
				4,7 : begin
					cmd        <= CMD_AUTO_REFRESH;
				end
				10, 13 : begin
					cmd        <= CMD_LOAD_MODE;
					sdaddr     <= 13'b000_0_00_011_0_010; // WRITE BURST, LATENCY=3, BURST=4
				end
			endcase
		end
		wr     <= 0;
		rd     <= 0;
		rcnt   <= 0;
		done   <= 0;
		addr   <= -24'b1;
	end
	else begin
		
		if(cmd == CMD_AUTO_REFRESH && !cs) {cs,cmd} <= {1'b1, CMD_AUTO_REFRESH};

		case(state)

			// RAS
			1 : begin
				cas_cmd    <= CMD_NOP;
				wr         <= 0;
				rcnt       <= rcnt + 1'd1;

				if(rcnt == 50) begin
					cmd     <= CMD_AUTO_REFRESH;
					cs      <= 0;
					rcnt    <= 0;
				end
				else if(sz == 3 && &addr[23:0]) done <= 1;
				else if(sz == 2 && &addr[22:0]) done <= 1;
				else if(sz <= 1 && &addr[21:0]) done <= 1;
				else begin
					{cs,cas_addr[9],cas_addr[8:2],sdaddr,ba,cas_addr[1:0]} <= {addr, 2'b00};
					wr      <= ~rnw_reg;
					cas_cmd <= rnw_reg ? CMD_READ : CMD_WRITE;
					cmd     <= CMD_ACTIVE;
					addr    <= addr + 1'd1;
				end
			end

			// CAS
			4 : begin
				sdaddr     <= {1'b1, cas_addr}; // AUTO PRECHARGE
				cmd        <= cas_cmd;
				rd         <= (cas_cmd == CMD_READ);
			end
		endcase

		if(done) begin
			if(start) begin
				done       <= 0;
				rnw_reg    <= rnw;
				addr       <= 0;
			end
		end
	end
end

endmodule

//=====================================================================
//
// Designer   : Yili Gong
//
// Description:
// As part of the project of Computer Organization Experiments, Wuhan University
// In spring 2021
// The datapath of the pipeline.
// ====================================================================

`include "xgriscv_defines.v"

module datapath(
	input         			 	 	   clk, reset,

	input [`INSTR_SIZE-1:0] instrF, 	// from instructon memory
	output[`ADDR_SIZE-1:0] 	pcF, 		// to instruction memory

	input [`XLEN-1:0]  	    readdataM, 	// from data memory: read data
  	output[`XLEN-1:0] 		aluoutM, 	// to data memory: address
 	output[`XLEN-1:0]		writedataM, // to data memory: write data
  	output					memwriteM,	// to data memory: write enable
 	output[3:0]  			ampM, 		// to data memory: access memory pattern
	
	// from controller
	input [4:0]				immctrlD,
	input					itype, jalD, jalrD, bunsignedD, pcsrcD,
	input [3:0]				aluctrlD,
	input [1:0]				alusrcaD,
	input					alusrcbD,
	input					memwriteD, lunsignedD,
	input [1:0]				lwhbD, swhbD,  
	input          			memtoregD, regwriteD,
	
  // to controller
	output [6:0]			opD,
	output [2:0]			funct3D,
	output [6:0]			funct7D,
	output [4:0] 			rdD, rs1D,
	output [11:0]  			immD,
	output 	       			zeroD, ltD

//    output       			flushE
	);

	wire [6:0] opF = instrF[6:0];
	wire [`RFIDX_WIDTH-1:0] rdF = instrF[11:7];
	wire [3:0] funct3F = instrF[14:12];
	wire [`RFIDX_WIDTH-1:0] rs1F = instrF[19:15];
	wire [`RFIDX_WIDTH-1:0] rs2F = instrF[24:20];
	wire [6:0] funct7F = instrF[31:25];
	wire [11:0] immF = instrF[31:20];

	// next PC logic (operates in fetch and decode)
	wire [`ADDR_SIZE-1:0]	 pcplus4F, nextpcF, pcbranchD, pcadder2aD, pcadder2bD, pcbranch0D, pcadder2bD1;
	mux2 #(`ADDR_SIZE)	pcsrcmux(pcplus4F, pcbranchD, pcsrcD, nextpcF); //choose from pc+4 and branch, now pcsrcD = 0, need to be change
	
	// Fetch stage logic
	pcenr pcreg(clk, reset,en, nextpcF, pcF); //choose pc from nextpc and initial, pcF is output to IMeM
	wire hazard;
	assign en = !hazard;// pcF = nextpcF, when hazerd, this need to change
	addr_adder  pcadder1 (pcF, `ADDR_SIZE'b100, pcplus4F); //pc = pc + 4

	///////////////////////////////////////////////////////////////////////////////////
	// ID/EX pipeline registers
	wire [`INSTR_SIZE-1:0]	instrD; 
	wire [`ADDR_SIZE-1:0]	pcD, pcplus4D;
	wire flushD = pcsrcD | hazard;//clear
	//mux2 #(1) flushDmux(0, 1, jalD, flushD);
	//Data from IF/ID to ID/EX
	floprc #(`INSTR_SIZE) 	pr1D(clk, reset, flushD, instrF, instrD); // instruction
	floprc #(`ADDR_SIZE)	pr2D(clk, reset, flushD, pcF, pcD); // pc now
	floprc #(`ADDR_SIZE)	pr3D(clk, reset, flushD, pcplus4F, pcplus4D); // pc+4, maybe used to choose

	// Decode stage logic ID
	wire [`RFIDX_WIDTH-1:0] rs2D;
	assign  opD 	= instrD[6:0];
	assign  rdD     = instrD[11:7];
	assign  funct3D = instrD[14:12];
	assign  rs1D    = instrD[19:15];
	assign  rs2D   	= instrD[24:20];
	assign  funct7D = instrD[31:25];
	assign  immD    = instrD[31:20];

	// immediate generate
	wire [11:0]	iimmD 	= instrD[31:20];
	wire [11:0]	simmD	= {instrD[31:25], instrD[11:7]};
	wire [11:0] bimmD	= {instrD[31], instrD[7], instrD[30:25], instrD[11:8]};
	wire [19:0]	uimmD	= instrD[31:12];
	wire [19:0] jimmD	= {instrD[31], instrD[19:12], instrD[20], instrD[30:21]};
	wire [`XLEN-1:0]	immoutD, shftimmD;
	wire [`XLEN:0] immoutD_sl1;
	wire [`XLEN-1:0]	rdata1D, rdata2D, wdataW, wdataW1, rdata1D1, rdata2D1;
	wire [`RFIDX_WIDTH-1:0]	waddrW;

	imm 	im(iimmD, simmD, bimmD, uimmD, jimmD, immctrlD, immoutD);// output a imm class

	//S5---------------------------------------------------------------
  	sl1 immGen(immoutD, immoutD_sl1); 
	addr_adder pcadder2(pcD, immoutD_sl1, pcadder2aD); //jal or b-type

	// register file (operates in decode and writeback)
	//output rdata1D and rdata2D
	//write in former half T, and read later

	regfile rf(clk, rs1D, rs2D, rdata1D, rdata2D, regwriteW, waddrW, wdataW);

	// shift amount
	wire [4:0]	shamt0D = instrD[24:20];
	wire [4:0] shamtD;
	mux2 #(5) shamtmux(rdata2D[4:0], shamt0D, itype, shamtD); // itype to decide rs2data or imm

	//MEM->ID
	wire regwriteM;
	wire [`RFIDX_WIDTH-1:0]	rdM;
	wire forwardaD = (regwriteM && rdM != 5'b0 && rdM == rs1D);
	wire forwardbD = (regwriteM && rdM != 5'b0 && rdM == rs2D);
	mux2 #(`XLEN)  rdata1Dmux(rdata1D, aluoutM, forwardaD, rdata1D1);
	mux2 #(`XLEN)  rdata2Dmux(rdata2D, aluoutM, forwardbD, rdata2D1);

	addr_adder pcadder3(rdata1D1, immoutD, pcadder2bD1); //jalr_1
	set_last_zero set_zero(pcadder2bD1, pcadder2bD); //jalr_2

	mux2 #(`XLEN) pcsrcmux2(pcadder2aD, pcadder2bD, jalrD, pcbranchD);
	

	cmp cmp(rdata1D1, rdata2D1, bunsignedD, zeroD, ltD);// compare r1data with r2data


	// hazard detection
	wire memtoregE;
	wire [`RFIDX_WIDTH-1:0] rdE;

	assign hazard = (memtoregD & rdD != 5'b0 & (
		(opF == `OP_JALR) & (rdD == rs1F) |
		(opF == `OP_LOAD) & (rdD == rs1F) |
		(opF == `OP_ADDI) & (rdD == rs1F) |
		(opF == `OP_ADD) & ((rdD == rs1F) | (rdD == rs2F)) |
		(opF == `OP_BRANCH) & ((rdD == rs1F) | (rdD == rs2F)) |
		(opF == `OP_STORE) & ((rdD == rs1F) | (rdD == rs2F))) 
	)|
	(regwriteD & rdD != 5'b0 & (
		(opF == `OP_JALR) & (rdD == rs1F) |
		(opF == `OP_BRANCH) & ((rdD == rs1F) | (rdD == rs2F))
	) )|
	(memtoregE & rdE != 5'b0 & (
		(opF == `OP_JALR) & (rdE == rs1F) |
		(opF == `OP_BRANCH) & ((rdE == rs1F) | (rdE == rs2F))
	) );
	

	// to do

	///////////////////////////////////////////////////////////////////////////////////
	// ID/EX pipeline registers

	// for control signals
	wire regwriteE, memwriteE, lunsignedE, alusrcbE, jalE;
	wire [1:0] swhbE, lwhbE, alusrcaE;
	wire [3:0] aluctrlE;

	//S7_1
	wire 	   flushE= 0; //if clear
	//flow from ID/EX to EX/MEM
	floprc #(16) regE(clk, reset, flushE,
                  {memtoregD, regwriteD, memwriteD, swhbD, lwhbD, lunsignedD, alusrcaD, alusrcbD, aluctrlD, jalD}, 
                  {memtoregE, regwriteE, memwriteE, swhbE, lwhbE, lunsignedE, alusrcaE, alusrcbE, aluctrlE, jalE});
	wire [1:0] forwardaE, forwardbE;
  
	// for data
	wire [`XLEN-1:0]		srca1E, srcb1E, immoutE, srca2E, srca3E, srcb2E, srcb3E, aluoutE;
	wire [`RFIDX_WIDTH-1:0] rs1E, rs2E;
	wire [4:0] 				shamtE;
	wire [`ADDR_SIZE-1:0] 	pcE, pcplus4E;
	floprc #(`XLEN) 		pr1E(clk, reset, flushE, rdata1D, srca1E); 	//???????1
	floprc #(`XLEN) 		pr2E(clk, reset, flushE, rdata2D, srcb1E); 	//???????2
	floprc #(`XLEN) 		pr3E(clk, reset, flushE, immoutD, immoutE); //???????
	floprc #(`RFIDX_WIDTH)	pr4E(clk, reset, flushE, rs1D, rs1E); 		//??????1
  	floprc #(`RFIDX_WIDTH)  pr5E(clk, reset, flushE, rs2D, rs2E); 		//??????2
  	floprc #(`RFIDX_WIDTH)  pr6E(clk, reset, flushE, rdD, rdE);			//???????
  	floprc #(5)  			pr7E(clk, reset, flushE, shamtD, shamtE);	//32????shift??????
  	floprc #(`ADDR_SIZE)	pr8E(clk, reset, flushE, pcD, pcE); 		//pc
  	floprc #(`ADDR_SIZE)	pr9E(clk, reset, flushE, pcplus4D, pcplus4E); // pc+4

	// execute stage logic
	mux3 #(`XLEN)  srca1mux(srca1E, wdataW, aluoutM, forwardaE, srca2E);// srca1mux
	mux3 #(`XLEN)  srca2mux(srca2E, 0, pcE, alusrcaE, srca3E);			// srca2mux
	mux3 #(`XLEN)  srcb1mux(srcb1E, wdataW, aluoutM, forwardbE, srcb2E);// srcb1mux
	mux2 #(`XLEN)  srcb2mux(srcb2E, immoutE, alusrcbE, srcb3E);			// srcb2mux

	alu alu(srca3E, srcb3E, shamtE, aluctrlE, aluoutE, overflowE, zeroE, ltE, geE);

	//S7_2, MEM-->EX, WB-->EX
	wire aM = (regwriteM && rdM != 5'b0 && rdM == rs1E);
	wire aW = (regwriteW && waddrW != 5'b0 && waddrW == rs1E && !(regwriteM && rdM != 5'b0 && rdM == rs1E));
	wire bM = (regwriteM && rdM != 5'b0 && rdM == rs2E);
	wire bW = (regwriteW && waddrW != 5'b0 && waddrW == rs2E && !(regwriteM && rdM != 5'b0 && rdM == rs2E));
	mux3 #(2) forwardaEmux(2'b00, 2'b01, 2'b10, {aM, aW}, forwardaE);
	mux3 #(2) forwardbEmux(2'b00, 2'b01, 2'b10, {bM, bW}, forwardbE);

  
	// EX/MEM pipeline registers
	// for control signals
	wire 		memtoregM, jalM, lunsignedM;
	wire [1:0] 	swhbM, lwhbM;
	wire 		flushM = 0;
	floprc #(9) regM(clk, reset, flushM,
                  {memtoregE, regwriteE, memwriteE, lunsignedE, swhbE, lwhbE, jalE},
                  {memtoregM, regwriteM, memwriteM, lunsignedM, swhbM, lwhbM, jalM});
	

	// for data
 	wire [`ADDR_SIZE-1:0] 	pcplus4M;
	wire [`RFIDX_WIDTH-1:0] rs2M; //s7_2
	wire [`XLEN-1:0] writedataM1; //s7_2
	floprc #(`XLEN) 		pr1M(clk, reset, flushM, aluoutE, aluoutM);
	floprc #(`XLEN) 		pr2M(clk, reset, flushM, srcb1E, writedataM1);
	floprc #(`RFIDX_WIDTH) 	pr3M(clk, reset, flushM, rdE, rdM);
	floprc #(`ADDR_SIZE)	pr4M(clk, reset, flushM, pcplus4E, pcplus4M); // pc+4
	floprc #(`RFIDX_WIDTH)  pr5M(clk, reset, flushM, rs2E, rs2M); //s7_2

	// mux2 #(32)  forwardmmux(writedataM1, memdataW, forwardM, writedataM); // forwarding unit, to do
	
	//s7_2 WB-->MEM
	wire forwardM = ((waddrW != 0) && (rs2M == waddrW) && regwriteW);
  	mux2 #(`XLEN) memOrwbmux(writedataM1, wdataW, forwardM, writedataM);

  	// memory stage logic
  	ampattern   amp(aluoutM[1:0], swhbM, ampM); // for sw, sh and sb, ampM to data memory
  	
	wire [`XLEN-1:0] membyteM, memhalfM, readdatabyteM, readdatahalfM, memdataM;
	
  	mux2 #(16) lhmux(readdataM[15:0], readdataM[31:16], aluoutM[1], memhalfM[15:0]); // for lh and lhu
  	wire[`XLEN-1:0] signedhalfM = {{16{memhalfM[15]}}, memhalfM[15:0]}; // for lh
  	wire[`XLEN-1:0] unsignedhalfM = {16'b0, memhalfM[15:0]}; // for lhu
  	mux2 #(32) lhumux(signedhalfM, unsignedhalfM, lunsignedM, readdatahalfM);

  	mux4 #(8) lbmux(readdataM[7:0], readdataM[15:8], readdataM[23:16], readdataM[31:24], aluoutM[1:0], membyteM[7:0]);
  	wire[`XLEN-1:0] signedbyteM = {{24{membyteM[7]}}, membyteM[7:0]}; // for lb
  	wire[`XLEN-1:0] unsignedbyteM = {24'b0, membyteM[7:0]}; // for lbu

  	mux2 #(`XLEN) lbumux(signedbyteM, unsignedbyteM, lunsignedM, readdatabyteM);

  	mux3 #(`XLEN) lwhbmux(readdataM, readdatahalfM, readdatabyteM, lwhbM, memdataM);


  	// MEM/WB pipeline registers
  	// for control signals
  	wire flushW = 0;
	floprc #(3) regW(clk, reset, flushW,
                  {memtoregM, regwriteM, jalM},
                  {memtoregW, regwriteW, jalW});

  	// for data
  	wire[`XLEN-1:0]			aluoutW, memdataW, wdata0W, pcplus4W;

	floprc #(`XLEN) 		pr1W(clk, reset, flushW, aluoutM, aluoutW);
	floprc #(`XLEN) 		pr2W(clk, reset, flushW, memdataM, memdataW);
	floprc #(`RFIDX_WIDTH) 	pr3W(clk, reset, flushW, rdM, waddrW);
	floprc #(`ADDR_SIZE)	pr4W(clk, reset, flushW, pcplus4M, pcplus4W); // pc+4, for JAL(store pc+4 to rd)


	// write-back stage logic
	mux2 #(`XLEN) wbmux1(aluoutW, memdataW, memtoregW, wdataW1);
	mux2 #(`XLEN) wbmux2(wdataW1, pcplus4W, jalW, wdataW);

endmodule
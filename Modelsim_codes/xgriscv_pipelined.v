//=====================================================================
//
// Designer   : Yili Gong
//
// Description:
// As part of the project of Computer Organization Experiments, Wuhan University
// In spring 2021
// The overall of the pipelined xg-riscv implementation.
//
// ====================================================================

`include "xgriscv_defines.v"
module xgriscv_pipeline(clk, reset);
  input clk, reset;
  
  wire [31:0]    instr; //instruction
  wire [31:0]    pc;
  wire           memwrite;
  wire [3:0]     amp;
  wire [31:0]    addr, writedata, readdata;
   
  imem U_imem(pc, instr); // I mem, get instruction

  dmem U_dmem(clk, memwrite, amp, addr, writedata, readdata); // D mem
  
  xgriscv U_xgriscv(clk, reset, pc, instr, memwrite, amp, addr, writedata, readdata); //Middle part
  
endmodule

// xgriscv: a pipelined riscv processor
module xgriscv(input         			        clk, reset,
               output [31:0] 			        pc, //new pc
               input  [`INSTR_SIZE-1:0]   instr,
               output					            memwrite, //IF write mem
               output [3:0]  			        amp, //How to visit mem
               output [`ADDR_SIZE-1:0] 	  daddr, 
               output [`XLEN-1:0] 		    writedata,
               input  [`XLEN-1:0] 		    readdata);// why input
               
	//-D means these vars are in IF/ID stage
  wire [6:0]  opD;
 	wire [2:0]  funct3D;
	wire [6:0]  funct7D;
  wire [4:0]  rdD, rs1D;
  wire [11:0] immD;
  wire        zeroD, ltD;
  wire [4:0]  immctrlD;
  wire        itypeD, jalD, jalrD, bunsignedD, pcsrcD;
  wire [3:0]  aluctrlD;
  wire [1:0]  alusrcaD;
  wire        alusrcbD;
  wire        memwriteD, lunsignedD;
  wire [1:0]  swhbD, lwhbD;
  wire        memtoregD, regwriteD;

  controller  c(clk, reset, opD, funct3D, funct7D, rdD, rs1D, immD, zeroD, ltD,
              immctrlD, itypeD, jalD, jalrD, bunsignedD, pcsrcD, 
              aluctrlD, alusrcaD, alusrcbD, 
              memwriteD, lunsignedD, lwhbD, swhbD, 
              memtoregD, regwriteD);

  datapath    dp(clk, reset,
              instr, pc, //new pc
              readdata, daddr, writedata, memwrite, amp,
              immctrlD, itypeD, jalD, jalrD, bunsignedD, pcsrcD, 
              aluctrlD, alusrcaD, alusrcbD, 
              memwriteD, lunsignedD, lwhbD, swhbD, 
              memtoregD, regwriteD, 
              opD, funct3D, funct7D, rdD, rs1D, immD, zeroD, ltD);

endmodule

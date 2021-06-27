# Test the RISC-V processor in simulation
# 已经能正确执行：addi, add, lw, sw, beq, jalr
# 待验证：能否正确处理转发：MEM-->EX, WB-->EX, WB-->MEM, MEM-->ID

main:	addi x5, x0, 1
		addi x6, x0, 2
		add  x7, x5, x6		#EX rs1 from WB, rs2 from MEM, x7 = 3
		add  x8, x7, x6		#EX rs1 from MEM, rs2 from WB, x8 = 5
		sw	 x8, 0(x0)		#MEM write data from WB's arith op, mem[0] = 5
		lw	 x9, 0(x0)
		sw	 x9, 4(x0)		#MEM write data from WB's load, mem[4] = 5

		addi x5, x0, 3
		addi x6, x0, 3
		addi x0, x0, 0
		beq  x5, x6, br1 	#ID rs1 from MEM
		addi x10, x0, 10	#should not run
br1ret:	jalr x0, x0, main

br1: 	addi x11, x0, 0x30
        addi x0, x0, 0
        jalr x0, x11, main  #jalr x0, x0, br1ret
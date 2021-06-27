//=====================================================================
//
// Designer   : Yili Gong
//
// Description:
// As part of the project of Computer Organization Experiments, Wuhan University
// In spring 2021
// testbench for simulation
//
// ====================================================================

module xgriscv_tb();
    
   reg  clk, rstn;
    
// instantiation of xgriscv 
// Define a pipline, so we should see what pipline consist of!
   xgriscv_pipeline xgriscvp(clk, rstn);

   integer counter = 0;
   
   initial begin
      clk = 1;
      rstn = 1;
      #5 ;
      rstn = 0;
   end
   
  always begin
    #(50) clk = ~clk;
     
    if (clk == 1'b1) 
      begin
    	counter = counter + 1;
    	$display("clock: %d", counter);
		$display("pc:\t\t%h", xgriscvp.pc);
		$display("instr:\t%h", xgriscvp.instr);
      end
  end //end always
   
endmodule

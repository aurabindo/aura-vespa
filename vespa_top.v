module vespa;
   
   //global definitions
   parameter WIDTH = 32;
   parameter NUMREGS = 32;
   parameter MEMSIZE = (1 << 13); //  0 to (2^13 -1) memory location. MEMSIZE = 8192

   // Memory declaration

   reg [7:0] MEM[NUMREG-1 : 0];
   reg [WIDTH-1:0] R[NUMREG-1 : 0];
   reg [WIDTH-1:0] PC;
   reg [WIDTH-1:0] IR;
   reg 		   C;
   reg 		   V;
   reg 		   Z;
   reg 		   N;
   reg 		   RUN;

   // For ALU

   reg [WIDTH-1:0] op1;
   reg [WIDTH-1:0] op2;
   reg [WIDTH:0] result; // 33 bit result

   //OpCodes

`define NOP 'd0 
`define ADD 'd1 
`define SUB 'd2 
`define OR 'd3 
`define AND 'd4
`define NOT 'd5
`define XOR 'd6
`define CMP 'd7
`define BXX 'd8
`define JMP 'd9
`define LD 'd10
`define LDI 'd11
`define LDX 'd12
`define ST 'd13
`define STX 'd14
`define HLT 'd15

   // defines for BXX

`define BRA 'b0000 
`define BNV 'b1000 
`define BCC 'b0001 
`define BCS 'b1001 
`define BVC 'b0010 
`define BVS 'b1010
`define BEQ 'b0011
`define BNE 'b1011
`define BGE 'b0100
`define BLT 'b1100
`define BGT 'b0101
`define BLE 'b1101
`define BPL 'b0110
`define BMI 'b1110

   // defintions for symbols in opcode
`define OPCODE IR[31:27]
`define rdst IR[26:22]
`define rs1 IR[21:17]
`define IMM_OP IR[16] // Immediate operand
`define rs2 IR[15:11]
`define rst IR[26:22] // Store OP source
`define immed23 IR[22:0]
`define immed22 IR[21:0]
`define immed17 IR[16:0]
`define immed16 IR[15:0]
`define COND IR[26:23] //conditions for BXX branch instructions

// Fetch Execute Cycle

   integer	 num_instrns; // store number of instructions executed
   
initial begin
   $readmemh("v.out", MEM); //read v.out into MEM

   RUN = 1; //gets reset by HLT
   PC = 0;
   num_instrns = 0;

   while(RUN == 1) begin
      num_instrns = num_instrns + 1;
      fetch;  //functions for core operations
      execute;
      print_trace;
   end

   $display("\n Total number of instructions executed: %d\n\n",num_instrs);
   $finish;

end // initial begin
   
// tasks and functions

function [WIDTH-1:0] read_mem;
   input [WIDTH-1:0] addr;
   begin
      read_mem = {MEM[addr], MEM[addr+1], MEM[addr+2], MEM[addr+3]};
   end
endfunction //
   
   
function check_cond;
   input 		Z;
   input 		C;
   input 		N;
   input 		V;
   
   case(`COND)
     `BRA : check_cond = 'd1;
     `BNV : check_cond = 'd0;
     `BCC : check_cond = ~C;
     `BCS : check_cond = C;
     `BVC : check_cond = ~V;
     `BVS : check_cond = V;
     `BEQ : check_cond = Z;
     `BNE : check_cond = ~Z;
     `BGE : check_cond = (N & V) | (~N & ~V);
     `BLT : check_cond = ~(N & V) | (~N & ~V); // ~ of BGE
     `BGT : check_cond = ~Z & ((N & V) | (~N & ~V));
     `BLE : check_cond = Z | ((N & V) | (~N & ~V)); // or (~ of BGT)
     `BPL : check_cond = ~N;
     `BMI : check_cond = N;
     default : $display("Illegal condition %d",`COND);
   endcase // case (`COND)
endfunction // check_cond
   
   
task write_mem; //for generic use with 8, 16 and 32 bit mem writes
   input [WIDTH-1:0] addr;
   input [WIDTH-1:0] data;
   integer 	     i;
   integer 	     j;
   begin
      i = WIDTH / 8;
      for(j=0;j<i;j=j+1) begin
	 MEM[addr+(i-j-1)] = data[(j*8):((j*8) + 8)-1];
      end
   end
endtask // write_mem
   
task setcc;
   input [WIDTH-1:0] op1;
   input [WIDTH-1:0] op2;
   input [WIDTH:0]   result;
   input 	     subt; //subt is 1 when the insn is SUB.
   begin
      //set flags
      Z = ~(|result[WIDTH-1:0]);
      C = result[WIDTH];
      N = result[WIDTH-1];
      V = (result[WIDTH-1] & ~op1[WIDTH-1] & ~(subt ^ op2[WIDTH-1])) | (~result[WIDTH-1] & op1[WIDTH-1] & (subt ^ op2[WIDTH-1]));
   end
endtask // setcc
   
   
     
function [WIDTH-1:0] sign_ext16;
   input [15:0] 	data;
   sign_ext16 = {{16{data[15]}},data};
endfunction //
      
function [WIDTH-1:0] sign_ext17;
   input [16:0] 	num;
   sign_ext17 = {{15{data[16]}},num};
endfunction //

function [WIDTH-1:0] sign_ext22;
   input [21:0] 	num;
   sign_ext22 = {{10{num[21]}},num};
endfunction // read_mem
   
/********************************************************************/   
task fetch;
   begin
      IR = read_mem(PC);
      PC = PC + 4;
   end
endtask // fetch
   
task execute;
   reg temp[WIDTH-1:0];
   begin
      case (`OPCODE)
	`ADD : begin
	   if(`IMM_OP == 'd0)
	     op2 = R[`rs2];
	   else
	     op2 = sign_ext16(immed16);
	   op1 = R[`rs1];
	   result = op1 + op2;
	   R[`rdst] = result[WIDTH-1:0];
	   setcc(op1,op2,result,0); //manually setting 0 as last arg as insn is ADD
	end
	
	`NOP : begin
	end
	
	`AND : begin
	   if(`IMM_OP == 'd0)
	     op2 = R[`rs2];
	   else
	     op2 = sign_ext16(`immed16);
	   
	   op1 = R[`rs1];
	   result = op1 & op2;
	   R[`rdst] = result[WIDTH-1:0];
	end
	
	`XOR : begin
	   if(`IMM_OP == 'd0)
	     op2 = sign_ext16(`immed16);
	   else
	     op2 = R[`rs2];
	   
	   op1 = R[`rs1];
	   result = op1 ^ op2;
	   R[`rdst] = result[WIDTH-1:0];
	end
	
	`BXX : begin
	   if(check_cond(Z,C,N,V) == 1)
	     PC = PC + sign_ext23(`immed23);
	end
	
	`CMP : begin
	   op1 = R[`rs1];
	   if(`IMM_OP == 'd0)
	     op2 = R[`rs2];
	   else
	     op2 = sign_ext16(`immed16);
	   
	   result = op1 - op2;
	   setcc(op1,op2,result,1); //subtraction , hence 1
	end
	
	`HLT : RUN = 0;
	`JMP : begin
	   if(`IMM_OP == 'd1)
	     R[`rdst] = PC; // for JMPL insn
	   
	   PC = PC + R[`rs1] + sign_ext16(`immed16);
	end
	
	`LD : begin
	   R[`rst] = read_mem(sign_ext16(`immed22));
	end
	
	`LDI : R[`rst] = sign_ext22(`immed22);
	
	`LDX : begin
	   R[`rst] = read_mem(R[`rs1] + sign_ext17(`immed17));
	end
	
	`NOP : begin
	end
	
	`NOT : begin
	   if(`IMM_OP == 'd1)
	     op1 = sign_ext22(`immed22);
	   else
	     op1 = R[`rs1];
	   
	   result = ~op1;
	   R[`rdst] = result[WIDTH-1:0];
	end
	
	`OR : begin
	   if(`IMM_OP == 'd1)
	     op2 = sign_ext16(`immed16);
	   else
	     op2 = R[`rs2];
	   op1 = R[`rs1];
	   result = op1 | op2;
	   R[`rdst] = result[WIDTH-1:0];
	end
	
	`ST : begin
	   
	   temp = sign_ext22(`immed22);
	   
	   write_mem(temp,R[`rdst]); //write mem is a task. so it seems I cant put sign_ext22 as an arg
	end
	
	`STX : begin
	   write_mem(R[`rs1]+sign_ext17(`immed17),R[`rdst]);
	end
	
	`SUB : begin
	   if(`IMM_OP == 'd1)
	     op2 = sign_ext16(`immed16);
	   else
	     op2 = R[`rs2];
	   op1 = R[`rs1];
	   
	   result = op1 - op2;
	   R[`rdst] = result[WIDTH-1:0];
	   setcc(op1,op2,result,1);
	end // case: `SUB
	
	default: $display("Undefined OpCode %d",`OPCODE);
      endcase // case (`OPCODE)
   end
endtask // execute
endmodule // vespa

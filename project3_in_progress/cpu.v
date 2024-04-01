`define OPCODE_READRAM8 1
`define OPCODE_JUMPMINUS 2

module cpu(input rst, input ram_clk);
  reg stage12_clk;
  reg [15:0]pc;
  wire stage12_ready;
  wire [15:0]stage3_read_address;
  wire stage3_read;
  
  stage12 stage12(.pc(pc), .stage12_clk(stage12_clk), .rst(rst),.ram_clk(ram_clk),
  	.stage12_ready(stage12_ready),.stage3_read_address(stage3_read_address), .stage3_read(stage3_read));
  
  always @(rst) begin
    	$display($time,"reset");
    	pc=0;
    	stage12_clk=1;
  end
  always @(posedge stage12_ready) begin
	$display($time,"posedge stage12ready");
	//if (instruction[0]=OPCODE_JUMPMINUS) begin
	//	pc-=instruction[1]*4;
//	end else begin
	   	pc=pc+4;
//	end
       	stage12_clk=0;
  end
  always @(negedge stage12_clk) begin
   	$display($time,"negedge stage12ready");
    	stage12_clk=1;
  end
endmodule

module stage12(input [15:0]pc, input stage12_clk, input rst,input ram_clk,
  output reg stage12_ready, output reg [15:0]stage3_read_address, output reg stage3_read);
  reg ram_write_enable;
  reg [15:0]ram_address;
  reg [7:0]ram_data_in;
  wire [7:0]ram_data_out;
  ram ram(.ram_clk(ram_clk),.write_enable(ram_write_enable),.address(ram_address),.data_in(ram_data_in),
  	.data_out(ram_data_out));

  reg [7:0]instruction[0:3];
 
  always @ (stage12_clk) begin
	stage12_ready <= 0;
    	ram_write_enable = 0; 
	$display($time," executing pc ",pc);
	ram_address = pc;
	@(posedge ram_clk)
	@(posedge ram_clk)
	instruction[0] = ram_data_out;
	ram_address=pc+1;
	@(posedge ram_clk)
	@(posedge ram_clk)
	instruction[1] = ram_data_out;
	ram_address=pc+2;
	@(posedge ram_clk)    
	@(posedge ram_clk)
	instruction[2] = ram_data_out;
	ram_address=pc+3;
	@(posedge ram_clk)
	@(posedge ram_clk)
	instruction[3] = ram_data_out;
	$display($time," ",instruction[0], " ", instruction[1]," ",
		instruction[2]," ",instruction[3]);
	stage3_read<=0;	
	if (instruction[0]==`OPCODE_READRAM8) begin
		$display($time," READRAM8");
		stage3_read<=1;
		stage3_read_address=instruction[1];
	end else if (instruction[0]==`OPCODE_JUMPMINUS) begin
		$display($time," JUMPMINUS");
	end
	stage12_ready<=1;
  end
endmodule

// we have to use standard RAM = definition is "as is"
module ram(input ram_clk,input write_enable,input [15:0]address,input [7:0]data_in,
	output reg [7:0]data_out);
  reg [7:0]ram_memory[0:65536];
  
  initial begin
    $readmemh("rom.mem", ram_memory);
  end
  always @(posedge ram_clk) begin
    if(write_enable)
        ram_memory[address] <= data_in;
    else
        data_out <= ram_memory[address];
  end
endmodule


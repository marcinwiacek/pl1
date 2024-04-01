`define OPCODE_READRAM8 1
`define OPCODE_JUMPMINUS 2

module cpu(input rst, input ram_clk);
  reg [7:0]registers[0:511];
 
  reg stage12_clk;
  wire stage12_ready;

  reg stage3_clk;
  wire stage3_ready;
  wire [15:0]stage3_read_address; //address, which we should read
  wire stage3_read; //should we do it?
  
  wire stage12_ram_read;
  wire [15:0] stage12_ram_read_address;
  wire stage12_ram_read_ready;
  wire [7:0] stage12_ram_read_data_out;
	
  ram2 ram2(.ram_clk(ram_clk), .stage12_read(stage12_ram_read), .stage12_read_address(stage12_ram_read_address),
	.stage12_read_ready(stage12_ram_read_ready), .stage12_read_data_out(stage12_ram_read_data_out));
	
  stage12 stage12(.stage12_clk(stage12_clk), .rst(rst),
  	.stage12_ready(stage12_ready),.stage3_read_address(stage3_read_address), .stage3_read(stage3_read),
  	
  	.stage12_ram_read(stage12_ram_read), .stage12_ram_read_address(stage12_ram_read_address),
	.stage12_ram_read_ready(stage12_ram_read_ready), .stage12_ram_read_data_out(stage12_ram_read_data_out));
  
  always @(rst) begin
    	$display($time,"reset1");
    	stage12_clk=1;
  end
  always @(posedge stage12_ready) begin
	$display($time,"posedge stage12ready");
       	stage12_clk=0;
  end
  always @(negedge stage12_clk) begin
   	$display($time,"negedge stage12ready");
    	stage12_clk=1;
  end
endmodule

module stage12(input stage12_clk, input rst,input ram_clk,
  output reg stage12_ready, output reg [15:0]stage3_read_address, output reg stage3_read,
  output reg stage12_ram_read, output reg [15:0] stage12_ram_read_address,
	input stage12_ram_read_ready, input [7:0] stage12_ram_read_data_out);
 
  reg [7:0]instruction[0:3];
  reg [15:0]pc;
 
  always @(rst) begin
    	$display($time,"reset2");
    	pc=0;
  end
    always @(posedge stage12_ram_read_ready) begin
  	stage12_ram_read <= 0;
  end
  always @(stage12_clk) begin
	stage12_ready <= 0;
	$display($time," executing pc ",pc);
	stage12_ram_read_address <= pc;
	stage12_ram_read <= 1;
	@(posedge stage12_ram_read_ready)
	stage12_ram_read <= 0;
	instruction[0] = stage12_ram_read_data_out;

	stage12_ram_read_address <= pc+1;
	stage12_ram_read <= 1;
	@(posedge stage12_ram_read_ready)
	stage12_ram_read <= 0;
	instruction[1] = stage12_ram_read_data_out;

	stage12_ram_read_address <= pc+2;
	stage12_ram_read = 1;
	@(posedge stage12_ram_read_ready)
	stage12_ram_read = 0;
	instruction[2] = stage12_ram_read_data_out;

	stage12_ram_read_address <= pc+3;
	stage12_ram_read = 1;
	@(posedge stage12_ram_read_ready)
	stage12_ram_read = 0;
	instruction[3] = stage12_ram_read_data_out;

	$display($time," ",instruction[0], " ", instruction[1]," ",
		instruction[2]," ",instruction[3]);
	stage3_read<=0;	
	if (instruction[0]==`OPCODE_READRAM8) begin
		$display($time," READRAM8");
		stage3_read<=1;
		stage3_read_address=instruction[1];
		pc+=4;
	end else if (instruction[0]==`OPCODE_JUMPMINUS) begin
		$display($time," JUMPMINUS");
		pc-=instruction[1]*4;
	end
	stage12_ready<=1;
  end
endmodule

module ram2(input ram_clk, input stage12_read, input [15:0] stage12_read_address,
	output reg stage12_read_ready, output reg [7:0] stage12_read_data_out);
  reg ram_write_enable;
  reg [15:0]ram_address;
  reg [7:0]ram_data_in;
  wire [7:0]ram_data_out;
  ram ram(.ram_clk(ram_clk),.write_enable(ram_write_enable),.address(ram_address),.data_in(ram_data_in),
  	.data_out(ram_data_out));
  
  always @(posedge stage12_read) begin
  	stage12_read_ready = 0;
  	ram_write_enable = 0; 
	ram_address = stage12_read_address;
	@(posedge ram_clk)
	@(posedge ram_clk)
	stage12_read_data_out <= ram_data_out;
	stage12_read_ready<=1;
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


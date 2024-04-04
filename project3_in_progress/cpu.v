`define OPCODE_LOADFROMRAM 1
`define OPCODE_JUMPMINUS 2
`define OPCODE_WRITETORAM 3

`define OPER_ADD 1

//`define DEBUG_LEVEL 2 //higher=more info
//`define DEBUG1(TXT) \
//    	if (`DEBUG_LEVEL==1 || `DEBUG_LEVEL==2) $display($time,$sformatf TXT);
//`define DEBUG2(TXT) \
//    	if (`DEBUG_LEVEL==2) $display($time,TXT);

module cpu(input rst, input ram_clk);
  wire [7:0]registers[63:0];
    
  // ram with extra prioritization
  wire stage12_ram_read;
  wire stage12_ram_read_ready;
  wire [15:0] stage12_ram_read_address;
  wire [7:0] stage12_ram_read_data_out;

  wire stage3_ram_read;
  wire stage3_ram_read_ready;
  wire [15:0] stage3_ram_read_address;
  wire [7:0] stage3_ram_read_data_out;

  wire stage5_ram_save;
  wire stage5_ram_save_ready;
  wire [15:0] stage5_ram_save_address;
  wire [7:0] stage5_ram_save_data_in;
  
  ram2 ram2(.ram_clk(ram_clk),
  	.stage12_read(stage12_ram_read), .stage12_read_ready(stage12_ram_read_ready),
  	.stage12_read_address(stage12_ram_read_address), .stage12_read_data_out(stage12_ram_read_data_out),
	.stage3_read(stage3_ram_read), .stage3_read_ready(stage3_ram_read_ready),
	.stage3_read_address(stage3_ram_read_address), .stage3_read_data_out(stage3_ram_read_data_out),
	.stage5_save(stage5_ram_save), .stage5_save_ready(stage5_ram_save_ready),
	.stage5_save_address(stage5_ram_save_address), .stage5_save_data_in(stage5_ram_save_data_in));
	
  //fetch & decode
  reg stage12_exec;
  wire stage12_exec_ready;
  wire stage3_should_exec; //should we do it?
  wire [15:0]stage3_source_ram_address; //address, which we should read
  wire [15:0]stage3_target_register_start;
  wire [15:0]stage3_target_register_length;
  wire stage5_should_exec; //should we do it?
  wire [15:0]stage5_source_register_start;
  wire [15:0]stage5_source_register_length;
  wire [15:0]stage5_target_ram_address;
 
  stage12 stage12(.rst(rst), .stage12_exec(stage12_exec), .stage12_exec_ready(stage12_exec_ready),
  	.stage3_should_exec(stage3_should_exec), .stage3_source_ram_address(stage3_source_ram_address),
  	.stage3_target_register_start(stage3_target_register_start), .stage3_target_register_length(stage3_target_register_length),
  	.stage5_should_exec(stage5_should_exec), .stage5_source_register_start(stage5_source_register_start),
  	.stage5_source_register_length(stage5_source_register_length),.stage5_target_ram_address(stage5_target_ram_address),
  	//ram
  	.stage12_ram_read(stage12_ram_read), .stage12_ram_read_ready(stage12_ram_read_ready),
  	.stage12_ram_read_address(stage12_ram_read_address), .stage12_ram_read_data_out(stage12_ram_read_data_out));
	
  //ram read
  reg stage3_exec;
  wire stage3_exec_ready;
  
  stage3 stage3(.stage3_exec(stage3_exec), .stage3_exec_ready(stage3_exec_ready),
  	.stage3_source_ram_address(stage3_source_ram_address), .stage3_target_register_start(stage3_target_register_start),
  	.stage3_target_register_length(stage3_target_register_length),
  	.registers(registers),
  	//ram
  	.stage3_ram_read(stage3_ram_read), .stage3_ram_read_ready(stage3_ram_read_ready),
  	.stage3_ram_read_address(stage3_ram_read_address), .stage3_ram_read_data_out(stage3_ram_read_data_out));
  
  //alu
  
  //ram save
  reg stage5_exec;
  wire stage5_exec_ready;
  
  stage5 stage5(.stage5_exec(stage5_exec), .stage5_exec_ready(stage5_exec_ready),
  	.stage5_source_register_start(stage5_source_register_start), .stage5_source_register_length(stage5_source_register_length),
  	.stage5_target_ram_address(stage5_target_ram_address),  
  	.registers(registers),
  	//ram
  	.stage5_ram_save(stage5_ram_save), .stage5_ram_save_ready(stage5_ram_save_ready),
  	.stage5_ram_save_address(stage5_ram_save_address), .stage5_ram_save_data_in(stage5_ram_save_data_in));
	
  always @(rst) begin
    	$display($time," reset1");
    	stage12_exec=1; //start it
  end
  always @(negedge stage12_exec) begin
   	$display($time," negedge stage12exec");
    	stage12_exec=1; //force it to start again
  end
  always @(posedge stage12_exec_ready) begin
	$display($time," posedge stage12execready");
       	stage12_exec=0;
       	if (stage3_should_exec) begin
       		stage3_exec=1; // start when necessary
       	end
       	if (stage5_should_exec) begin
	//$display($time," stage5_should_exec");
       		stage5_exec=1; // start when necessary
       	end
  end
  always @(posedge stage3_exec_ready) begin
	$display($time," posedge stage3execready");
       	stage3_exec=0;
  end
  always @(posedge stage5_exec_ready) begin
	$display($time," posedge stage5execready");
       	stage5_exec=0;
  end
endmodule

module stage12(
	input rst,
	input stage12_exec, output reg stage12_exec_ready, 
  	output reg stage3_should_exec, 
  	output reg [15:0]stage3_source_ram_address, 
  	output reg [15:0]stage3_target_register_start, 
  	output reg [15:0]stage3_target_register_length,
  	output reg stage5_should_exec, 
  	output reg [15:0] stage5_source_register_start,
  	output reg [15:0] stage5_source_register_length,
  	output reg [15:0] stage5_target_ram_address,
  	//ram
  	output reg stage12_ram_read, input stage12_ram_read_ready, 
  	output reg [15:0] stage12_ram_read_address,
  	input [7:0] stage12_ram_read_data_out);
 
  reg [7:0] instruction[0:3];
  reg [15:0] pc;
 
  always @(rst) begin
    	$display($time," reset2");
    	pc=0;
  end
  always @(posedge stage12_exec) begin
	stage12_exec_ready <= 0;
	stage3_should_exec<=0;	
	stage5_should_exec<=0;
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

	if (instruction[0]==`OPCODE_JUMPMINUS) begin
		$display($time,"   JUMPMINUS");
		pc-=instruction[1]*4;
	end else begin
		stage12_ram_read_address <= pc+2;
		stage12_ram_read <= 1;
		@(posedge stage12_ram_read_ready)
		stage12_ram_read <= 0;
		instruction[2] = stage12_ram_read_data_out;

		stage12_ram_read_address <= pc+3;
		stage12_ram_read <= 1;
		@(posedge stage12_ram_read_ready)
		stage12_ram_read <= 0;
		instruction[3] = stage12_ram_read_data_out;
		
		if (instruction[0]==`OPCODE_LOADFROMRAM) begin
			stage3_target_register_start=instruction[1];
  			stage3_target_register_length=instruction[2];
			stage3_source_ram_address=instruction[3];
			$display($time,"   LOADFROMRAM ",stage3_target_register_length," bytes from RAM address ",stage3_source_ram_address,"+ and save to register ",stage3_target_register_start,"+");
			stage3_should_exec<=1;
			pc+=4;
		end else if (instruction[0]==`OPCODE_WRITETORAM) begin
			stage5_source_register_start=instruction[1];
  			stage5_source_register_length=instruction[2];
  			stage5_target_ram_address=instruction[3];  
			$display($time,"   WRITETORAM ",stage5_source_register_length," bytes from register ",stage5_source_register_start,"+ and save to RAM address ",stage5_target_ram_address,"+");
			stage5_should_exec<=1;
			pc+=4;
		end
	end
	$display($time,"   ",instruction[0], " ", instruction[1]," ",
			instruction[2]," ",instruction[3]);
	stage12_exec_ready<=1;
  end
endmodule

module stage3(
	input stage3_exec, output reg stage3_exec_ready,
	input [15:0]stage3_source_ram_address,
	input [15:0]stage3_target_register_start, 
	input [15:0]stage3_target_register_length,
    	output reg [7:0]registers[63:0],
  	//ram
  	output reg stage3_ram_read, input stage3_ram_read_ready, 
  	output reg [15:0] stage3_ram_read_address,
  	input [7:0] stage3_ram_read_data_out);
 
 integer i;
 string s;
 
  always @(posedge stage3_exec) begin
	stage3_exec_ready <= 0;
	for (i=0;i<stage3_target_register_length;i++) begin
		stage3_ram_read_address <= stage3_source_ram_address+i;
		stage3_ram_read <= 1;
		@(posedge stage3_ram_read_ready)
		stage3_ram_read <= 0;
		registers[i] = stage3_ram_read_data_out;
	end
	s=" ";
	for (i=0;i<20;i++) begin
		s={s,$sformatf("%02x ",registers[i])};
	end
	$display($time,s);
	stage3_exec_ready<=1;
  end
endmodule

module stage4(input [7:0] a, input [7:0] b, input [4:0] oper, output reg [7:0] out);
    always @(*) begin
        case (oper)
        	`OPER_ADD: out <= a+b;
        endcase
    end
endmodule

module stage5(
	input stage5_exec,
	output reg stage5_exec_ready, 
	input [15:0] stage5_source_register_start, 
	input [15:0] stage5_source_register_length,
	input [15:0] stage5_target_ram_address,
	input [7:0]registers[63:0],
  	//ram
  	output reg stage5_ram_save, input stage5_ram_save_ready, 
  	output reg [15:0] stage5_ram_save_address,
  	output reg [7:0] stage5_ram_save_data_in);

integer i;
 
  always @(posedge stage5_exec) begin
	stage5_exec_ready <= 0;
	for (i=0;i<stage5_source_register_length;i++) begin
		stage5_ram_save_address <= stage5_target_ram_address+i;
		stage5_ram_save_data_in <= registers[i+stage5_source_register_start];
		stage5_ram_save <= 1;
		@(posedge stage5_ram_save_ready)
		stage5_ram_save <= 0;
	end
	stage5_exec_ready<=1;
  end
endmodule

module ram2(input ram_clk,
	input stage12_read, output reg stage12_read_ready, input [15:0] stage12_read_address, output reg [7:0] stage12_read_data_out,
	input stage3_read,  output reg stage3_read_ready,  input [15:0] stage3_read_address,  output reg [7:0] stage3_read_data_out,
	input stage5_save,  output reg stage5_save_ready,  input [15:0] stage5_save_address,  input [7:0] stage5_save_data_in);

  reg ram_write_enable;
  reg [15:0]ram_address;
  reg [7:0]ram_data_in;
  wire [7:0]ram_data_out;
  
  ram ram(.ram_clk(ram_clk),.write_enable(ram_write_enable),.address(ram_address),.data_in(ram_data_in),
  	.data_out(ram_data_out));
  
  always @(posedge stage12_read or posedge stage3_read or posedge stage5_save) begin
	if (stage5_save) begin
  		stage5_save_ready <= 0;
		ram_write_enable <= 1;
		ram_address = stage5_save_address;
		ram_data_in = stage5_save_data_in; 	
  		$display($time," saving RAM from stage5 address ",stage5_save_address);
		@(posedge ram_clk)
  		@(negedge ram_clk)
		ram_write_enable <= 0; 	
		stage5_save_ready <= 1;
	end
	if (stage3_read) begin
  		stage3_read_ready <= 0;
  		ram_write_enable <= 0; 	
		ram_address = stage3_read_address;
		@(posedge ram_clk)
		@(negedge ram_clk)
  		$display($time," reading RAM from stage3 address ",stage3_read_address," value ",ram_data_out);
		stage3_read_data_out <= ram_data_out;
		stage3_read_ready<=1;
	end
	if (stage12_read) begin
  		stage12_read_ready <= 0;
  		ram_write_enable <= 0; 	
		ram_address = stage12_read_address;
		@(posedge ram_clk)
		@(negedge ram_clk)
  		$display($time," reading RAM from stage12 address ",stage12_read_address," value ",ram_data_out);
		stage12_read_data_out <= ram_data_out;
		stage12_read_ready<=1;
	end
 //$display($time," ",stage3_read, " ",stage12_read," ",stage5_save);
  end
endmodule

// we have to use standard RAM = definition is "as is"
module ram(input ram_clk, input write_enable, input [15:0] address, input [7:0] data_in,
	output reg [7:0] data_out);
  reg [7:0] ram_memory[0:65536];
  
  initial begin
    $readmemh("rom.mem", ram_memory);
  end
  always @(posedge ram_clk) begin
    if (write_enable) begin
        ram_memory[address] <= data_in;
    end else begin
        data_out <= ram_memory[address];
    end
  end
endmodule

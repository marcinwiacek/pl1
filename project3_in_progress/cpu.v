`define OPCODE_LOADFROMRAM 1
`define OPCODE_JUMPMINUS 2
`define OPCODE_WRITETORAM 3
`define OPCODE_ADD8 4
`define OPCODE_JUMPPLUS 5
`define OPCODE_ADDNUM8 6
`define OPCODE_READFROMRAM 7
`define OPCODE_SAVETORAM 8
`define OPCODE_SET8 9


`define OPER_ADD 1
`define OPER_ADDNUM 2
`define OPER_SETNUM 3

//`define DEBUG_LEVEL 2 //higher=more info
//`define DEBUG1(TXT) \
//    	if (`DEBUG_LEVEL==1 || `DEBUG_LEVEL==2) $display($time,$sformatf TXT);
//`define DEBUG2(TXT) \
//    	if (`DEBUG_LEVEL==2) $display($time,TXT);

module cpu(input rst, input ram_clk);
  //registers (in the future with extra prioritization and hazard detection)
  reg dump_reg;
  wire dump_reg_ready;
  
  wire stage12_register_read;
  wire stage12_register_read_ready;
  wire [15:0] stage12_register_read_address;
  wire [7:0] stage12_register_read_data_out;
  
  wire stage3_register_save;
  wire stage3_register_save_ready;
  wire [15:0] stage3_register_save_address;
  wire [7:0] stage3_register_save_data_in;

  wire stage4_register_save;
  wire stage4_register_save_ready;
  wire [15:0] stage4_register_save_address;
  wire [7:0] stage4_register_save_data_in;
  
  wire stage4_register_read;
  wire stage4_register_read_ready;
  wire [15:0] stage4_register_read_address;
  wire [7:0] stage4_register_read_data_out;

  wire stage5_register_read;
  wire stage5_register_read_ready;
  wire [15:0] stage5_register_read_address;
  wire [7:0] stage5_register_read_data_out;
  
  registers registers(
  	.dump_reg(dump_reg),
	.dump_reg_ready(dump_reg_ready),  
	.stage12_read(stage12_register_read),  .stage12_read_ready(stage12_register_read_ready),  .stage12_read_address(stage12_register_read_address),  .stage12_read_data_out(stage12_register_read_data_out),
	.stage3_save(stage3_register_save),  .stage3_save_ready(stage3_register_save_ready),  .stage3_save_address(stage3_register_save_address),  .stage3_save_data_in(stage3_register_save_data_in),
	.stage4_save(stage4_register_save),  .stage4_save_ready(stage4_register_save_ready),  .stage4_save_address(stage4_register_save_address),  .stage4_save_data_in(stage4_register_save_data_in),
	.stage4_read(stage4_register_read),  .stage4_read_ready(stage4_register_read_ready),  .stage4_read_address(stage4_register_read_address),  .stage4_read_data_out(stage4_register_read_data_out),
	.stage5_read(stage5_register_read),  .stage5_read_ready(stage5_register_read_ready),  .stage5_read_address(stage5_register_read_address),  .stage5_read_data_out(stage5_register_read_data_out)	
	);

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
  wire stage4_should_exec;
  wire [15:0]stage4_oper;
  wire [15:0]stage4_register_A_start;
  wire [15:0]stage4_register_B_start;
  wire [15:0]stage4_value_B;  
  wire [15:0]stage4_register_out_start;
  wire [15:0]stage4_register_length;  
  wire stage5_should_exec; //should we do it?
  wire [15:0]stage5_source_register_start;
  wire [15:0]stage5_source_register_length;
  wire [15:0]stage5_target_ram_address;
 
  stage12 stage12(.rst(rst), .stage12_exec(stage12_exec), .stage12_exec_ready(stage12_exec_ready),
  	.stage3_should_exec(stage3_should_exec), .stage3_source_ram_address(stage3_source_ram_address),
  	.stage3_target_register_start(stage3_target_register_start), .stage3_target_register_length(stage3_target_register_length),
  	.stage4_should_exec(stage4_should_exec),
  	.stage4_oper(stage4_oper), .stage4_register_A_start(stage4_register_A_start),.stage4_register_B_start(stage4_register_B_start),
  	.stage4_value_B(stage4_value_B), .stage4_register_out_start(stage4_register_out_start),
  	.stage4_register_length(stage4_register_length),
  	.stage5_should_exec(stage5_should_exec), .stage5_source_register_start(stage5_source_register_start),
  	.stage5_source_register_length(stage5_source_register_length),.stage5_target_ram_address(stage5_target_ram_address),
  	//registers
	.stage12_register_read(stage12_register_read),  .stage12_register_read_ready(stage12_register_read_ready), 
	.stage12_register_read_address(stage12_register_read_address),  .stage12_register_read_data_out(stage12_register_read_data_out),
  	//ram
  	.stage12_ram_read(stage12_ram_read), .stage12_ram_read_ready(stage12_ram_read_ready),
  	.stage12_ram_read_address(stage12_ram_read_address), .stage12_ram_read_data_out(stage12_ram_read_data_out));
	
  //ram read
  reg stage3_exec;
  wire stage3_exec_ready;
  
  stage3 stage3(.stage3_exec(stage3_exec), .stage3_exec_ready(stage3_exec_ready),
  	.stage3_source_ram_address(stage3_source_ram_address), .stage3_target_register_start(stage3_target_register_start),
  	.stage3_target_register_length(stage3_target_register_length),
	.stage3_register_save(stage3_register_save),  .stage3_register_save_ready(stage3_register_save_ready), 
	.stage3_register_save_address(stage3_register_save_address),  .stage3_register_save_data_in(stage3_register_save_data_in),
  	//ram
  	.stage3_ram_read(stage3_ram_read), .stage3_ram_read_ready(stage3_ram_read_ready),
  	.stage3_ram_read_address(stage3_ram_read_address), .stage3_ram_read_data_out(stage3_ram_read_data_out));
  
  //alu
  reg stage4_exec;
  wire stage4_exec_ready;
  
  stage4 stage4(.stage4_exec(stage4_exec), .stage4_exec_ready(stage4_exec_ready),.stage4_oper(stage4_oper),  .stage4_register_A_start(stage4_register_A_start),
  .stage4_register_B_start(stage4_register_B_start),  .stage4_value_B(stage4_value_B),  .stage4_register_out_start(stage4_register_out_start),
  .stage4_register_length(stage4_register_length),
	.stage4_register_save(stage4_register_save),  .stage4_register_save_ready(stage4_register_save_ready), 
	.stage4_register_save_address(stage4_register_save_address),  .stage4_register_save_data_in(stage4_register_save_data_in),
	.stage4_register_read(stage4_register_read),  .stage4_register_read_ready(stage4_register_read_ready), 
	.stage4_register_read_address(stage4_register_read_address),  .stage4_register_read_data_out(stage4_register_read_data_out));
  	  
  //ram save
  reg stage5_exec;
  wire stage5_exec_ready;
  
  stage5 stage5(.stage5_exec(stage5_exec), .stage5_exec_ready(stage5_exec_ready),
  	.stage5_source_register_start(stage5_source_register_start), .stage5_source_register_length(stage5_source_register_length),
  	.stage5_target_ram_address(stage5_target_ram_address), 
  	//registers 
	.stage5_register_read(stage5_register_read),  .stage5_register_read_ready(stage5_register_read_ready), 
	.stage5_register_read_address(stage5_register_read_address),  .stage5_register_read_data_out(stage5_register_read_data_out),
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
       	if (stage4_should_exec) begin
       		stage4_exec=1; // start when necessary
       	end
       	if (stage5_should_exec) begin
	//$display($time," stage5_should_exec");
       		stage5_exec=1; // start when necessary
       	end
  end
  always @(posedge stage3_exec_ready) begin
	$display($time," posedge stage3execready");
	dump_reg <= 1;
	@(posedge dump_reg_ready)
	dump_reg <= 0;
       	stage3_exec=0;
  end
  always @(posedge stage4_exec_ready) begin
	$display($time," posedge stage4execready");
	dump_reg <= 1;
	@(posedge dump_reg_ready)
	dump_reg <= 0;
       	stage4_exec=0;
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
  	output reg stage4_should_exec,
   	output reg [15:0]stage4_oper,
  	output reg [15:0]stage4_register_A_start,
	output reg [15:0]stage4_register_B_start,
  	output reg [15:0]stage4_value_B,
  	output reg [15:0]stage4_register_out_start,
  	output reg [15:0]stage4_register_length,
  	output reg stage5_should_exec, 
  	output reg [15:0] stage5_source_register_start,
  	output reg [15:0] stage5_source_register_length,
  	output reg [15:0] stage5_target_ram_address,
  	//registers
	output reg stage12_register_read,  input stage12_register_read_ready,
	output reg [15:0] stage12_register_read_address,
	input [7:0] stage12_register_read_data_out,
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
	stage4_should_exec<=0;
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
	end if (instruction[0]==`OPCODE_JUMPPLUS) begin
		$display($time,"   JUMPPLUS");
		pc+=instruction[1]*4;
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
		end if (instruction[0]==`OPCODE_READFROMRAM) begin
			stage12_register_read_address <= instruction[3];
			stage12_register_read <= 1;
			@(posedge stage12_register_read_ready)
			stage12_register_read <= 0;

			stage3_target_register_start=instruction[1];
  			stage3_target_register_length=instruction[2];
			stage3_source_ram_address=stage12_register_read_data_out;

			$display($time,"   READFROMRAM ",stage3_target_register_length," bytes from RAM address ",stage3_source_ram_address,"+ and save to register ",stage3_target_register_start,"+");
			stage3_should_exec<=1;
			pc+=4;
		end else if (instruction[0]==`OPCODE_WRITETORAM) begin
			stage5_source_register_start=instruction[1];
  			stage5_source_register_length=instruction[2];
  			stage5_target_ram_address=instruction[3];  
			$display($time,"   WRITETORAM ",stage5_source_register_length," bytes from register ",stage5_source_register_start,"+ and save to RAM address ",stage5_target_ram_address,"+");
			stage5_should_exec<=1;
			pc+=4;
		end else if (instruction[0]==`OPCODE_SAVETORAM) begin
			stage12_register_read_address <= instruction[3];
			stage12_register_read <= 1;
			@(posedge stage12_register_read_ready)
			stage12_register_read <= 0;
			
			stage5_source_register_start=instruction[1];
  			stage5_source_register_length=instruction[2];
  			stage5_target_ram_address=stage12_register_read_data_out;  
			$display($time,"   SAVETORAM ",stage5_source_register_length," bytes from register ",stage5_source_register_start,"+ and save to RAM address ",stage5_target_ram_address,"+");
			stage5_should_exec<=1;
			pc+=4;
		end else if (instruction[0]==`OPCODE_ADD8) begin
		   	stage4_oper=`OPER_ADD;
  			stage4_register_A_start=instruction[1];
			stage4_register_B_start=instruction[1];
		  	stage4_register_out_start=instruction[2];
		  	stage4_register_length=instruction[3];
			$display($time,"   OPCODE_ADD8 add register ",stage4_register_A_start,"+ to register ",stage4_register_B_start," and save to register ",stage4_register_out_start,"+, len ",stage4_register_length);
			stage4_should_exec<=1;
			pc+=4;
		end else if (instruction[0]==`OPCODE_ADDNUM8) begin
		   	stage4_oper=`OPER_ADDNUM;
  			stage4_register_A_start=instruction[1];
			stage4_value_B=instruction[1];
		  	stage4_register_out_start=instruction[2];
		  	stage4_register_length=instruction[3];
			$display($time,"   OPCODE_ADDNUM8 add value ",stage4_value_B," to register ",stage4_register_A_start," and save to register ",stage4_register_out_start,"+, len ",stage4_register_length);
			stage4_should_exec<=1;
			pc+=4;
		end else if (instruction[0]==`OPCODE_SET8) begin
		   	stage4_oper=`OPER_SETNUM;
  			//stage4_register_A_start=instruction[1];
			stage4_value_B=0;
		  	stage4_register_out_start=instruction[1];
		  	stage4_register_length=instruction[2];
			$display($time,"   OPCODE_SET8 add value ",stage4_value_B," to register ",stage4_register_A_start," and save to register ",stage4_register_out_start,"+, len ",stage4_register_length);
			stage4_should_exec<=1;
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
	//registers
	output reg stage3_register_save,  input stage3_register_save_ready,
	output reg [15:0] stage3_register_save_address,
	output reg [7:0] stage3_register_save_data_in,
  	//ram
  	output reg stage3_ram_read, input stage3_ram_read_ready, 
  	output reg [15:0] stage3_ram_read_address,
  	input [7:0] stage3_ram_read_data_out);
 
 integer i;
 
  always @(posedge stage3_exec) begin
	stage3_exec_ready <= 0;
	for (i=0;i<stage3_target_register_length;i++) begin
		stage3_ram_read_address <= stage3_source_ram_address+i;
		stage3_ram_read <= 1;
		@(posedge stage3_ram_read_ready)
		stage3_ram_read <= 0;
		
		stage3_register_save_address <= i;
		stage3_register_save_data_in <= stage3_ram_read_data_out;
		stage3_register_save <= 1;
		@(posedge stage3_register_save_ready)
		stage3_register_save <= 0;
	end
	stage3_exec_ready<=1;
  end
endmodule

module stage4(input stage4_exec, output reg stage4_exec_ready,
  input [15:0]stage4_oper,
  input [15:0]stage4_register_A_start,
  input [15:0]stage4_register_B_start,
  input [15:0]stage4_value_B,
  input [15:0]stage4_register_out_start,
  input [15:0]stage4_register_length,
  //registers
  output reg stage4_register_save,  input stage4_register_save_ready,
  output reg [15:0] stage4_register_save_address,
  output reg [7:0] stage4_register_save_data_in,
  output reg stage4_register_read,  input stage4_register_read_ready,
  output reg [15:0] stage4_register_read_address,
  input [7:0] stage4_register_read_data_out);
  
  	integer i;
	string s2;
	reg [7:0] temp;
  
     always @(posedge stage4_exec) begin
     	stage4_exec_ready <= 0;
        $display($time," stage 4 starting ",stage4_value_B);
       for (i=0;i<stage4_register_length;i++) begin
	       if (stage4_oper==`OPER_SETNUM) begin
				temp=stage4_value_B;
	       end else begin
	       		stage4_register_read_address <= i+stage4_register_A_start;
			stage4_register_read <= 1;
			@(posedge stage4_register_read_ready)
			stage4_register_read <= 0;
		
			temp = stage4_register_read_data_out;

       			if (stage4_oper==`OPER_ADD) begin
		       		stage4_register_read_address <= i+stage4_register_B_start;
				stage4_register_read <= 1;
				@(posedge stage4_register_read_ready)
				stage4_register_read <= 0;
				//$display($time," stage 4 value ",temp, " ",stage4_register_read_data_out);
				temp+=stage4_register_read_data_out;
			end else begin
				//$display($time," stage 4 value ",temp, " ",stage4_value_B);
				temp+=stage4_value_B;
			end
		end
		
	       	stage4_register_save_address <= i+stage4_register_out_start;
		stage4_register_save_data_in <= temp;
		stage4_register_save <= 1;
		@(posedge stage4_register_save_ready)
		stage4_register_save <= 0;
       end
        stage4_exec_ready <= 1;
    end
endmodule

module stage5(
	input stage5_exec, output reg stage5_exec_ready, 
	input [15:0] stage5_source_register_start, 
	input [15:0] stage5_source_register_length,
	input [15:0] stage5_target_ram_address,
	//registers
	output reg stage5_register_read,  input stage5_register_read_ready,
	output reg [15:0] stage5_register_read_address,
	input [7:0] stage5_register_read_data_out,
  	//ram
  	output reg stage5_ram_save, input stage5_ram_save_ready, 
  	output reg [15:0] stage5_ram_save_address,
  	output reg [7:0] stage5_ram_save_data_in);

integer i;
 
  always @(posedge stage5_exec) begin
	stage5_exec_ready <= 0;
	for (i=0;i<stage5_source_register_length;i++) begin
		stage5_register_read_address <= i+stage5_source_register_start;
		stage5_register_read <= 1;
		@(posedge stage5_register_read_ready)
		stage5_register_read <= 0;

		stage5_ram_save_address <= stage5_target_ram_address+i;
		stage5_ram_save_data_in <= stage5_register_read_data_out;
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

module registers(
	input stage12_read, output reg stage12_read_ready, input [15:0] stage12_read_address, output reg [7:0] stage12_read_data_out,
	input stage3_save,  output reg stage3_save_ready,  input [15:0] stage3_save_address,  input [7:0] stage3_save_data_in,
	input stage4_save,  output reg stage4_save_ready,  input [15:0] stage4_save_address,  input [7:0] stage4_save_data_in,
	input stage4_read,  output reg stage4_read_ready,  input [15:0] stage4_read_address,  output reg [7:0] stage4_read_data_out,
	input stage5_read,  output reg stage5_read_ready,  input [15:0] stage5_read_address,  output reg [7:0] stage5_read_data_out,
	input dump_reg,  output reg dump_reg_ready
	);
  reg [7:0]registers_memory[63:0];
  
  integer i;
  string s2;

  always @(posedge stage12_read) begin
	stage12_read_ready <= 0;
	stage12_read_data_out = registers_memory[stage12_read_address];
	stage12_read_ready<=1;
  end
  always @(posedge stage3_save) begin
	stage3_save_ready <= 0;
	registers_memory[stage3_save_address] = stage3_save_data_in;
	stage3_save_ready<=1;
  end
  always @(posedge stage4_save) begin
	stage4_save_ready <= 0;
	registers_memory[stage4_save_address] = stage4_save_data_in;
	stage4_save_ready<=1;
  end
  always @(posedge stage4_read) begin
	stage4_read_ready <= 0;
	stage4_read_data_out = registers_memory[stage4_read_address];
	stage4_read_ready<=1;
  end
  always @(posedge stage5_read) begin
	stage5_read_ready <= 0;
	stage5_read_data_out = registers_memory[stage5_read_address];
	stage5_read_ready<=1;
  end
  always @(posedge dump_reg) begin
	dump_reg_ready <= 0;
        s2=" ";
	for (i=0;i<20;i++) begin
		s2={s2,$sformatf("%02x ",registers_memory[i])};
	end
	$display($time,s2);
	dump_reg_ready<=1;
  end
endmodule


module cpu(input rst, input ram_clk);
  reg stage1_clk;
  reg [15:0]pc;
  wire stage1_ready;
  stage1 stage1(.pc(pc), .stage1_clk(stage1_clk), .rst(rst),.ram_clk(ram_clk),
  	.stage1_ready(stage1_ready));
  
  always @(rst) begin
    	$display($time,"reset");
    	pc=0;
    	stage1_clk=1;
  end
  always @(posedge stage1_ready) begin
	$display($time,"posedge stage1ready");
   	pc=pc+4;
       	stage1_clk=0;
  end
  always @(negedge stage1_clk) begin
   	$display($time,"negedge stage1ready");
    	stage1_clk=1;
  end
endmodule

module stage1(input [15:0]pc, input stage1_clk, input rst,input ram_clk, output reg stage1_ready);
  reg ram_write_enable;
  reg [15:0]ram_address;
  reg [7:0]ram_data_in;
  wire [7:0]ram_data_out;
  ram ram(.ram_clk(ram_clk),.write_enable(ram_write_enable),.address(ram_address),.data_in(ram_data_in),
  	.data_out(ram_data_out));

  reg [7:0]instruction[0:3];
 
  always @ (stage1_clk) begin
	stage1_ready <= 0;
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
	stage1_ready<=1;
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


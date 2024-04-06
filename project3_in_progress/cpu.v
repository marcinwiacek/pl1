//process instruction codes
`define OPCODE_LOADFROMRAM 1
`define OPCODE_JUMPMINUS 2
`define OPCODE_WRITETORAM 3
`define OPCODE_ADD8 4
`define OPCODE_JUMPPLUS 5
`define OPCODE_ADDNUM8 6
`define OPCODE_READFROMRAM 7
`define OPCODE_SAVETORAM 8
`define OPCODE_SET8 9

//alu operations
`define OPER_ADD 1
`define OPER_ADDNUM 2
`define OPER_SETNUM 3

//offsets for process
`define ADDRESS_NEXT_PROCESS 0
`define ADDRESS_PC 4
`define ADDRESS_REG_USED 8
`define ADDRESS_REG 16
`define ADDREES_PROGRAM `REGISTER_NUM+12

//number of registers
`define REGISTER_NUM 64

//`define DEBUG_LEVEL 2 //higher=more info
//`define DEBUG1(TXT) \
//    	if (`DEBUG_LEVEL==1 || `DEBUG_LEVEL==2) $display($time,$sformatf TXT);
//`define DEBUG2(TXT) \
//    	if (`DEBUG_LEVEL==2) $display($time,TXT);

module cpu(
    input rst,
    input ram_clk
);
  //task switcher  
  reg switcher_exec;
  wire switcher_exec_ready;
  wire [15:0] start_pc;
  wire [15:0] pc;
  wire [`REGISTER_NUM-1:0] registers_used;
  reg [7:0] executed;
  switcher switcher (
      .rst(rst),
      .start_pc(start_pc),
      .pc(pc),
      .registers_used(registers_used),
      .switcher_exec(switcher_should_exec),
      .switcher_exec_ready(switcher_exec_ready),
      //registers
      .switcher_register_save(switcher_register_save),
      .switcher_register_save_ready(switcher_register_save_ready),
      .switcher_register_save_address(switcher_register_save_address),
      .switcher_register_save_data_in(switcher_register_save_data_in),
      .switcher_register_read(switcher_register_read),
      .switcher_register_read_ready(switcher_register_read_ready),
      .switcher_register_read_address(switcher_register_read_address),
      .switcher_register_read_data_out(switcher_register_read_data_out),
      //ram
      .switcher_ram_save(switcher_ram_save),
      .switcher_ram_save_ready(switcher_ram_save_ready),
      .switcher_ram_save_address(switcher_ram_save_address),
      .switcher_ram_save_data_in(switcher_ram_save_data_in),
      .switcher_ram_read(switcher_ram_read),
      .switcher_ram_read_ready(switcher_ram_read_ready),
      .switcher_ram_read_address(switcher_ram_read_address),
      .switcher_ram_read_data_out(switcher_ram_read_data_out)
  );

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

  wire switcher_register_save;
  wire switcher_register_save_ready;
  wire [15:0] switcher_register_save_address;
  wire [7:0] switcher_register_save_data_in;

  wire switcher_register_read;
  wire switcher_register_read_ready;
  wire [15:0] switcher_register_read_address;
  wire [7:0] switcher_register_read_data_out;

  registers registers (
      .start_pc(start_pc),
      .registers_used(registers_used),
      .dump_reg(dump_reg),
      .dump_reg_ready(dump_reg_ready),
      .stage12_read(stage12_register_read),
      .stage12_read_ready(stage12_register_read_ready),
      .stage12_read_address(stage12_register_read_address),
      .stage12_read_data_out(stage12_register_read_data_out),
      .stage3_save(stage3_register_save),
      .stage3_save_ready(stage3_register_save_ready),
      .stage3_save_address(stage3_register_save_address),
      .stage3_save_data_in(stage3_register_save_data_in),
      .stage4_save(stage4_register_save),
      .stage4_save_ready(stage4_register_save_ready),
      .stage4_save_address(stage4_register_save_address),
      .stage4_save_data_in(stage4_register_save_data_in),
      .stage4_read(stage4_register_read),
      .stage4_read_ready(stage4_register_read_ready),
      .stage4_read_address(stage4_register_read_address),
      .stage4_read_data_out(stage4_register_read_data_out),
      .stage5_read(stage5_register_read),
      .stage5_read_ready(stage5_register_read_ready),
      .stage5_read_address(stage5_register_read_address),
      .stage5_read_data_out(stage5_register_read_data_out),
      .switcher_save(switcher_register_save),
      .switcher_save_ready(switcher_register_save_ready),
      .switcher_save_address(switcher_register_save_address),
      .switcher_save_data_in(switcher_register_save_data_in),
      .switcher_read(switcher_register_read),
      .switcher_read_ready(switcher_register_read_ready),
      .switcher_read_address(switcher_register_read_address),
      .switcher_read_data_out(switcher_register_read_data_out)
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

  wire switcher_ram_read;
  wire switcher_ram_read_ready;
  wire [15:0] switcher_ram_read_address;
  wire [7:0] switcher_ram_read_data_out;

  wire switcher_ram_save;
  wire switcher_ram_save_ready;
  wire [15:0] switcher_ram_save_address;
  wire [7:0] switcher_ram_save_data_in;

  ram2 ram2 (
      .ram_clk(ram_clk),
      .stage12_read(stage12_ram_read),
      .stage12_read_ready(stage12_ram_read_ready),
      .stage12_read_address(stage12_ram_read_address),
      .stage12_read_data_out(stage12_ram_read_data_out),
      .stage3_read(stage3_ram_read),
      .stage3_read_ready(stage3_ram_read_ready),
      .stage3_read_address(stage3_ram_read_address),
      .stage3_read_data_out(stage3_ram_read_data_out),
      .stage5_save(stage5_ram_save),
      .stage5_save_ready(stage5_ram_save_ready),
      .stage5_save_address(stage5_ram_save_address),
      .stage5_save_data_in(stage5_ram_save_data_in),
      .switcher_read(switcher_ram_read),
      .switcher_read_ready(switcher_ram_read_ready),
      .switcher_read_address(switcher_ram_read_address),
      .switcher_read_data_out(switcher_ram_read_data_out),
      .switcher_save(switcher_ram_save),
      .switcher_save_ready(switcher_ram_save_ready),
      .switcher_save_address(switcher_ram_save_address),
      .switcher_save_data_in(switcher_ram_save_data_in)
  );

  //fetch & decode
  reg stage12_exec;
  wire stage12_exec_ready;
  wire stage3_should_exec;  //should we do it?
  wire [15:0] stage3_source_ram_address;  //address, which we should read
  wire [15:0] stage3_target_register_start;
  wire [15:0] stage3_target_register_length;
  wire stage4_should_exec;
  wire [15:0] stage4_oper;
  wire [15:0] stage4_register_A_start;
  wire [15:0] stage4_register_B_start;
  wire [15:0] stage4_value_B;
  wire [15:0] stage4_register_out_start;
  wire [15:0] stage4_register_length;
  wire stage5_should_exec;  //should we do it?
  wire [15:0] stage5_source_register_start;
  wire [15:0] stage5_source_register_length;
  wire [15:0] stage5_target_ram_address;
  reg switcher_should_exec;

  stage12 stage12 (
      .stage12_exec(stage12_exec),
      .stage12_exec_ready(stage12_exec_ready),
      .pc(pc),
      .start_pc(start_pc),
      .stage3_should_exec(stage3_should_exec),
      .stage3_source_ram_address(stage3_source_ram_address),
      .stage3_target_register_start(stage3_target_register_start),
      .stage3_target_register_length(stage3_target_register_length),
      .stage4_should_exec(stage4_should_exec),
      .stage4_oper(stage4_oper),
      .stage4_register_A_start(stage4_register_A_start),
      .stage4_register_B_start(stage4_register_B_start),
      .stage4_value_B(stage4_value_B),
      .stage4_register_out_start(stage4_register_out_start),
      .stage4_register_length(stage4_register_length),
      .stage5_should_exec(stage5_should_exec),
      .stage5_source_register_start(stage5_source_register_start),
      .stage5_source_register_length(stage5_source_register_length),
      .stage5_target_ram_address(stage5_target_ram_address),
      //registers
      .stage12_register_read(stage12_register_read),
      .stage12_register_read_ready(stage12_register_read_ready),
      .stage12_register_read_address(stage12_register_read_address),
      .stage12_register_read_data_out(stage12_register_read_data_out),
      //ram
      .stage12_ram_read(stage12_ram_read),
      .stage12_ram_read_ready(stage12_ram_read_ready),
      .stage12_ram_read_address(stage12_ram_read_address),
      .stage12_ram_read_data_out(stage12_ram_read_data_out)
  );

  //ram read
  reg  stage3_exec;
  wire stage3_exec_ready;

  stage3 stage3 (
      .stage3_exec(stage3_exec),
      .stage3_exec_ready(stage3_exec_ready),
      .stage3_source_ram_address(stage3_source_ram_address),
      .stage3_target_register_start(stage3_target_register_start),
      .stage3_target_register_length(stage3_target_register_length),
      //registers
      .stage3_register_save(stage3_register_save),
      .stage3_register_save_ready(stage3_register_save_ready),
      .stage3_register_save_address(stage3_register_save_address),
      .stage3_register_save_data_in(stage3_register_save_data_in),
      //ram
      .stage3_ram_read(stage3_ram_read),
      .stage3_ram_read_ready(stage3_ram_read_ready),
      .stage3_ram_read_address(stage3_ram_read_address),
      .stage3_ram_read_data_out(stage3_ram_read_data_out)
  );

  //alu
  reg  stage4_exec;
  wire stage4_exec_ready;

  stage4 stage4 (
      .stage4_exec(stage4_exec),
      .stage4_exec_ready(stage4_exec_ready),
      .stage4_oper(stage4_oper),
      .stage4_register_A_start(stage4_register_A_start),
      .stage4_register_B_start(stage4_register_B_start),
      .stage4_value_B(stage4_value_B),
      .stage4_register_out_start(stage4_register_out_start),
      .stage4_register_length(stage4_register_length),
      //register save
      .stage4_register_save(stage4_register_save),
      .stage4_register_save_ready(stage4_register_save_ready),
      .stage4_register_save_address(stage4_register_save_address),
      .stage4_register_save_data_in(stage4_register_save_data_in),
      //register read
      .stage4_register_read(stage4_register_read),
      .stage4_register_read_ready(stage4_register_read_ready),
      .stage4_register_read_address(stage4_register_read_address),
      .stage4_register_read_data_out(stage4_register_read_data_out)
  );

  //ram save
  reg  stage5_exec;
  wire stage5_exec_ready;

  stage5 stage5 (
      .stage5_exec(stage5_exec),
      .stage5_exec_ready(stage5_exec_ready),
      .stage5_source_register_start(stage5_source_register_start),
      .stage5_source_register_length(stage5_source_register_length),
      .stage5_target_ram_address(stage5_target_ram_address),
      //register read
      .stage5_register_read(stage5_register_read),
      .stage5_register_read_ready(stage5_register_read_ready),
      .stage5_register_read_address(stage5_register_read_address),
      .stage5_register_read_data_out(stage5_register_read_data_out),
      //ram
      .stage5_ram_save(stage5_ram_save),
      .stage5_ram_save_ready(stage5_ram_save_ready),
      .stage5_ram_save_address(stage5_ram_save_address),
      .stage5_ram_save_data_in(stage5_ram_save_data_in)
  );

  always @(rst) begin
    $display($time, " reset1");
    switcher_should_exec = 0;
    executed = 0;
    stage12_exec = 1;  //start it
  end
  always @(negedge stage12_exec) begin
    $display($time, " negedge stage12exec");
    $display($time, " abc ", switcher_should_exec);
    if (switcher_should_exec == 0) begin
      executed++;
      if (executed == 4) begin
        switcher_should_exec = 1;
        $display($time, "   switcher should exec");
      end else begin
        stage12_exec = 1;  //force it to start again
      end
    end
  end
  always @(posedge stage12_exec_ready) begin
    $display($time, " posedge stage12execready");
    stage12_exec = 0;
    if (stage3_should_exec) begin
      stage3_exec = 1;  // start when necessary
    end
    if (stage4_should_exec) begin
      stage4_exec = 1;  // start when necessary
    end
    if (stage5_should_exec) begin
      //$display($time," stage5_should_exec");
      stage5_exec = 1;  // start when necessary
    end
  end
  always @(posedge stage3_exec_ready) begin
    $display($time, " posedge stage3execready");
    dump_reg <= 1;
    @(posedge dump_reg_ready) dump_reg <= 0;
    stage3_exec = 0;
  end
  always @(posedge stage4_exec_ready) begin
    $display($time, " posedge stage4execready");
    dump_reg <= 1;
    @(posedge dump_reg_ready) dump_reg <= 0;
    stage4_exec = 0;
  end
  always @(posedge stage5_exec_ready) begin
    $display($time, " posedge stage5execready");
    stage5_exec = 0;
  end
  always @(posedge switcher_exec_ready) begin
    $display($time, " posedge switcherexecready");
    switcher_exec = 0;
  end
endmodule

module stage12 (
    input [15:0] start_pc,
    output reg [15:0] pc,
    input stage12_exec,
    output reg stage12_exec_ready,
    output reg stage3_should_exec,
    output reg [15:0] stage3_source_ram_address,
    output reg [15:0] stage3_target_register_start,
    output reg [15:0] stage3_target_register_length,
    output reg stage4_should_exec,
    output reg [15:0] stage4_oper,
    output reg [15:0] stage4_register_A_start,
    output reg [15:0] stage4_register_B_start,
    output reg [15:0] stage4_value_B,
    output reg [15:0] stage4_register_out_start,
    output reg [15:0] stage4_register_length,
    output reg stage5_should_exec,
    output reg [15:0] stage5_source_register_start,
    output reg [15:0] stage5_source_register_length,
    output reg [15:0] stage5_target_ram_address,
    //registers
    output reg stage12_register_read,
    input stage12_register_read_ready,
    output reg [15:0] stage12_register_read_address,
    input [7:0] stage12_register_read_data_out,
    //ram
    output reg stage12_ram_read,
    input stage12_ram_read_ready,
    output reg [15:0] stage12_ram_read_address,
    input [7:0] stage12_ram_read_data_out
);

  reg [7:0] instruction[0:3];

  integer i;

  //fixme, two processes can have the same start_pc
  always @(start_pc) begin
    pc = start_pc;
    $display($time, " new pc ", start_pc);
  end

  always @(posedge stage12_exec) begin
    stage12_exec_ready <= 0;
    stage3_should_exec <= 0;
    stage4_should_exec <= 0;
    stage5_should_exec <= 0;
    $display($time, " executing pc ", pc);

    stage12_ram_read_address <= pc;
    stage12_ram_read <= 1;
    @(posedge stage12_ram_read_ready) stage12_ram_read <= 0;
    instruction[0] = stage12_ram_read_data_out;

    stage12_ram_read_address <= pc + 1;
    stage12_ram_read <= 1;
    @(posedge stage12_ram_read_ready) stage12_ram_read <= 0;
    instruction[1] = stage12_ram_read_data_out;

    if (instruction[0] == `OPCODE_JUMPMINUS) begin
      $display($time, "   JUMPMINUS");
      pc -= instruction[1] * 4;
    end
    if (instruction[0] == `OPCODE_JUMPPLUS) begin
      $display($time, "   JUMPPLUS");
      pc += instruction[1] * 4;
    end else begin
      stage12_ram_read_address <= pc + 2;
      stage12_ram_read <= 1;
      @(posedge stage12_ram_read_ready) stage12_ram_read <= 0;
      instruction[2] = stage12_ram_read_data_out;

      stage12_ram_read_address <= pc + 3;
      stage12_ram_read <= 1;
      @(posedge stage12_ram_read_ready) stage12_ram_read <= 0;
      instruction[3] = stage12_ram_read_data_out;

      if (instruction[0] == `OPCODE_LOADFROMRAM) begin
        stage3_target_register_start = instruction[1];
        stage3_target_register_length = instruction[2];
        stage3_source_ram_address = instruction[3];
        $display($time, "   LOADFROMRAM ", stage3_target_register_length,
                 " bytes from RAM address ", stage3_source_ram_address, "+ and save to register ",
                 stage3_target_register_start, "+");
        stage3_should_exec <= 1;
      end
      if (instruction[0] == `OPCODE_READFROMRAM) begin
        stage12_register_read_address <= instruction[3];
        stage12_register_read <= 1;
        @(posedge stage12_register_read_ready) stage12_register_read <= 0;

        stage3_target_register_start = instruction[1];
        stage3_target_register_length = instruction[2];
        stage3_source_ram_address = stage12_register_read_data_out;

        $display($time, "   READFROMRAM ", stage3_target_register_length,
                 " bytes from RAM address ", stage3_source_ram_address, "+ and save to register ",
                 stage3_target_register_start, "+");
        stage3_should_exec <= 1;
      end else if (instruction[0] == `OPCODE_WRITETORAM) begin
        stage5_source_register_start = instruction[1];
        stage5_source_register_length = instruction[2];
        stage5_target_ram_address = instruction[3];
        $display($time, "   WRITETORAM ", stage5_source_register_length, " bytes from register ",
                 stage5_source_register_start, "+ and save to RAM address ",
                 stage5_target_ram_address, "+");
        stage5_should_exec <= 1;
      end else if (instruction[0] == `OPCODE_SAVETORAM) begin
        stage12_register_read_address <= instruction[3];
        stage12_register_read <= 1;
        @(posedge stage12_register_read_ready) stage12_register_read <= 0;

        stage5_source_register_start = instruction[1];
        stage5_source_register_length = instruction[2];
        stage5_target_ram_address = stage12_register_read_data_out;
        $display($time, "   SAVETORAM ", stage5_source_register_length, " bytes from register ",
                 stage5_source_register_start, "+ and save to RAM address ",
                 stage5_target_ram_address, "+");
        stage5_should_exec <= 1;
      end else if (instruction[0] == `OPCODE_ADD8) begin
        stage4_oper = `OPER_ADD;
        stage4_register_A_start = instruction[1];
        stage4_register_B_start = instruction[1];
        stage4_register_out_start = instruction[2];
        stage4_register_length = instruction[3];
        $display($time, "   OPCODE_ADD8 add register ", stage4_register_A_start, "+ to register ",
                 stage4_register_B_start, " and save to register ", stage4_register_out_start,
                 "+, len ", stage4_register_length);
        stage4_should_exec <= 1;
      end else if (instruction[0] == `OPCODE_ADDNUM8) begin
        stage4_oper = `OPER_ADDNUM;
        stage4_register_A_start = instruction[1];
        stage4_value_B = instruction[1];
        stage4_register_out_start = instruction[2];
        stage4_register_length = instruction[3];
        $display($time, "   OPCODE_ADDNUM8 add value ", stage4_value_B, " to register ",
                 stage4_register_A_start, " and save to register ", stage4_register_out_start,
                 "+, len ", stage4_register_length);
        stage4_should_exec <= 1;
      end else if (instruction[0] == `OPCODE_SET8) begin
        stage4_oper = `OPER_SETNUM;
        //stage4_register_A_start=instruction[1];
        stage4_value_B = 0;
        stage4_register_out_start = instruction[1];
        stage4_register_length = instruction[2];
        $display($time, "   OPCODE_SET8 add value ", stage4_value_B, " to register ",
                 stage4_register_A_start, " and save to register ", stage4_register_out_start,
                 "+, len ", stage4_register_length);
        stage4_should_exec <= 1;
      end
      pc += 4;
    end
    $display($time, "   ", instruction[0], " ", instruction[1], " ", instruction[2], " ",
             instruction[3]);
    stage12_exec_ready <= 1;
  end
endmodule

module stage3 (
    input stage3_exec,
    output reg stage3_exec_ready,
    input [15:0] stage3_source_ram_address,
    input [15:0] stage3_target_register_start,
    input [15:0] stage3_target_register_length,
    //registers
    output reg stage3_register_save,
    input stage3_register_save_ready,
    output reg [15:0] stage3_register_save_address,
    output reg [7:0] stage3_register_save_data_in,
    //ram
    output reg stage3_ram_read,
    input stage3_ram_read_ready,
    output reg [15:0] stage3_ram_read_address,
    input [7:0] stage3_ram_read_data_out
);

  integer i;

  always @(posedge stage3_exec) begin
    stage3_exec_ready <= 0;
    for (i = 0; i < stage3_target_register_length; i++) begin
      stage3_ram_read_address <= stage3_source_ram_address + i;
      stage3_ram_read <= 1;
      @(posedge stage3_ram_read_ready) stage3_ram_read <= 0;

      stage3_register_save_address <= i;
      stage3_register_save_data_in <= stage3_ram_read_data_out;
      stage3_register_save <= 1;
      @(posedge stage3_register_save_ready) stage3_register_save <= 0;
    end
    stage3_exec_ready <= 1;
  end
endmodule

module stage4 (
    input stage4_exec,
    output reg stage4_exec_ready,
    input [15:0] stage4_oper,
    input [15:0] stage4_register_A_start,
    input [15:0] stage4_register_B_start,
    input [15:0] stage4_value_B,
    input [15:0] stage4_register_out_start,
    input [15:0] stage4_register_length,
    //registers
    output reg stage4_register_save,
    input stage4_register_save_ready,
    output reg [15:0] stage4_register_save_address,
    output reg [7:0] stage4_register_save_data_in,
    output reg stage4_register_read,
    input stage4_register_read_ready,
    output reg [15:0] stage4_register_read_address,
    input [7:0] stage4_register_read_data_out
);

  integer i;
  string s2;
  reg [7:0] temp;

  always @(posedge stage4_exec) begin
    stage4_exec_ready <= 0;
    $display($time, " stage 4 starting ", stage4_value_B);
    for (i = 0; i < stage4_register_length; i++) begin
      if (stage4_oper == `OPER_SETNUM) begin
        temp = stage4_value_B;
      end else begin
        stage4_register_read_address <= i + stage4_register_A_start;
        stage4_register_read <= 1;
        @(posedge stage4_register_read_ready) stage4_register_read <= 0;

        temp = stage4_register_read_data_out;

        if (stage4_oper == `OPER_ADD) begin
          stage4_register_read_address <= i + stage4_register_B_start;
          stage4_register_read <= 1;
          @(posedge stage4_register_read_ready) stage4_register_read <= 0;
          //$display($time," stage 4 value ",temp, " ",stage4_register_read_data_out);
          temp += stage4_register_read_data_out;
        end else begin
          //$display($time," stage 4 value ",temp, " ",stage4_value_B);
          temp += stage4_value_B;
        end
      end

      stage4_register_save_address <= i + stage4_register_out_start;
      stage4_register_save_data_in <= temp;
      stage4_register_save <= 1;
      @(posedge stage4_register_save_ready) stage4_register_save <= 0;
    end
    stage4_exec_ready <= 1;
  end
endmodule

module stage5 (
    input stage5_exec,
    output reg stage5_exec_ready,
    input [15:0] stage5_source_register_start,
    input [15:0] stage5_source_register_length,
    input [15:0] stage5_target_ram_address,
    //registers
    output reg stage5_register_read,
    input stage5_register_read_ready,
    output reg [15:0] stage5_register_read_address,
    input [7:0] stage5_register_read_data_out,
    //ram
    output reg stage5_ram_save,
    input stage5_ram_save_ready,
    output reg [15:0] stage5_ram_save_address,
    output reg [7:0] stage5_ram_save_data_in
);

  integer i;

  always @(posedge stage5_exec) begin
    stage5_exec_ready <= 0;
    for (i = 0; i < stage5_source_register_length; i++) begin
      stage5_register_read_address <= i + stage5_source_register_start;
      stage5_register_read <= 1;
      @(posedge stage5_register_read_ready) stage5_register_read <= 0;

      stage5_ram_save_address <= stage5_target_ram_address + i;
      stage5_ram_save_data_in <= stage5_register_read_data_out;
      stage5_ram_save <= 1;
      @(posedge stage5_ram_save_ready) stage5_ram_save <= 0;
    end
    stage5_exec_ready <= 1;
  end
endmodule

module switcher (
    input [15:0] pc,
    input switcher_exec,
    output reg switcher_exec_ready,
    input rst,
    output reg [15:0] start_pc,
    input [`REGISTER_NUM-1:0] registers_used,
    //registers
    output reg switcher_register_save,
    input switcher_register_save_ready,
    output reg [15:0] switcher_register_save_address,
    output reg [7:0] switcher_register_save_data_in,
    output reg switcher_register_read,
    input switcher_register_read_ready,
    output reg [15:0] switcher_register_read_address,
    input [7:0] switcher_register_read_data_out,
    //ram
    output reg switcher_ram_save,
    input switcher_ram_save_ready,
    output reg [15:0] switcher_ram_save_address,
    output reg [7:0] switcher_ram_save_data_in,
    output reg switcher_ram_read,
    input switcher_ram_read_ready,
    output reg [15:0] switcher_ram_read_address,
    input [7:0] switcher_ram_read_data_out
);


  integer i, j,z;
  reg [15:0] process_address;
  reg[7:0]temp[7:0];

  always @(rst) begin
    $display($time, " reset2");
    process_address=0;
    start_pc = 12 + `REGISTER_NUM;
  end

  //`define ADDRESS_NEXT_PROCESS 0
  //`define ADDRESS_PC 4
  //`define ADDRESS_REG_USED 8
  //`define ADDRESS_REG 12
  //`define ADDREES_PROGRAM `REGISTER_NUM+12

  always @(posedge switcher_exec) begin
    $display($time, "switcher start");
    switcher_exec_ready <= 0;

temp[0] = registers_used[0]+registers_used[1]*2+registers_used[2]*4+registers_used[3]*8+registers_used[4]*16+registers_used[5]*32+registers_used[6]*64+registers_used[7]*128;
temp[1] = registers_used[8]+registers_used[9]*2+registers_used[10]*4+registers_used[11]*8+registers_used[12]*16+registers_used[13]*32+registers_used[14]*64+registers_used[15]*128;
temp[2] = registers_used[16]+registers_used[17]*2+registers_used[18]*4+registers_used[19]*8+registers_used[20]*16+registers_used[21]*32+registers_used[22]*64+registers_used[23]*128;
temp[3] = registers_used[24]+registers_used[25]*2+registers_used[26]*4+registers_used[27]*8+registers_used[28]*16+registers_used[29]*32+registers_used[30]*64+registers_used[31]*128;
temp[4] = registers_used[32]+registers_used[33]*2+registers_used[34]*4+registers_used[35]*8+registers_used[36]*16+registers_used[37]*32+registers_used[38]*64+registers_used[39]*128;
temp[5] = registers_used[40]+registers_used[41]*2+registers_used[42]*4+registers_used[43]*8+registers_used[44]*16+registers_used[45]*32+registers_used[46]*64+registers_used[47]*128;
temp[6] = registers_used[48]+registers_used[49]*2+registers_used[50]*4+registers_used[51]*8+registers_used[52]*16+registers_used[53]*32+registers_used[54]*64+registers_used[55]*128;
temp[7] = registers_used[56]+registers_used[57]*2+registers_used[58]*4+registers_used[59]*8+registers_used[60]*16+registers_used[61]*32+registers_used[62]*64+registers_used[63]*128;
    $display($time, "abcd ",temp[0]," ",temp[1]," ",temp[2]," ",temp[3]);

	//dump registers used
	
   //dump registers
    for (i = 0; i < `REGISTER_NUM; i++) begin
      if (registers_used[i]) begin
        switcher_register_read_address <= process_address;
        switcher_register_read <= 1;
        @(posedge switcher_register_read_ready) switcher_register_read <= 0;

        switcher_ram_save_address <= i + `ADDRESS_REG;
        switcher_ram_save_data_in <= switcher_register_read_data_out;
        switcher_ram_save <= 1;
        @(posedge switcher_ram_save_ready) switcher_ram_save <= 0;
      end
    end
    
    //next process address
    j = 0;
    for (i = 0; i < 4; i++) begin
      switcher_ram_read_address <= process_address+i;
      switcher_ram_read <= 1;
      @(posedge switcher_ram_read_ready) switcher_ram_read <= 0;
      j += switcher_ram_read_data_out * (2 ** i);
    end

    j = 0;
    for (i = 0; i < 4; i++) begin
      switcher_ram_read_address <= 100 + i + `ADDRESS_PC;
      switcher_ram_read <= 1;
      @(posedge switcher_ram_read_ready) switcher_ram_read <= 0;
      j += switcher_ram_read_data_out * (2 ** i);
    end
    start_pc = j;
    for (i = 0; i < `REGISTER_NUM; i++) begin
      switcher_ram_read_address <= 100 + i + `ADDRESS_REG;
      switcher_ram_read <= 1;
      @(posedge switcher_ram_read_ready) switcher_ram_read <= 0;

      switcher_register_save_address <= i;
      switcher_register_save_data_in <= switcher_register_read_data_out;
      switcher_register_save <= 1;
      @(posedge switcher_register_save_ready) switcher_register_save <= 0;
    end
    switcher_exec_ready <= 1;
  end
endmodule

module ram2 (
    input ram_clk,
    input stage12_read,
    output reg stage12_read_ready,
    input [15:0] stage12_read_address,
    output reg [7:0] stage12_read_data_out,
    input stage3_read,
    output reg stage3_read_ready,
    input [15:0] stage3_read_address,
    output reg [7:0] stage3_read_data_out,
    input stage5_save,
    output reg stage5_save_ready,
    input [15:0] stage5_save_address,
    input [7:0] stage5_save_data_in,
    input switcher_read,
    output reg switcher_read_ready,
    input [15:0] switcher_read_address,
    output reg [7:0] switcher_read_data_out,
    input switcher_save,
    output reg switcher_save_ready,
    input [15:0] switcher_save_address,
    input [7:0] switcher_save_data_in
);

  reg ram_write_enable;
  reg [15:0] ram_address;
  reg [7:0] ram_data_in;
  wire [7:0] ram_data_out;

  ram ram (
      .ram_clk(ram_clk),
      .write_enable(ram_write_enable),
      .address(ram_address),
      .data_in(ram_data_in),
      .data_out(ram_data_out)
  );

  always @(posedge stage12_read or posedge stage3_read or posedge stage5_save or posedge switcher_save or posedge switcher_read) begin
    if (switcher_save) begin
      switcher_save_ready <= 0;
      ram_write_enable <= 1;
      ram_address = switcher_save_address;
      ram_data_in = switcher_save_data_in;
      $display($time, " saving RAM from switcher address ", switcher_save_address);
      @(posedge ram_clk) @(negedge ram_clk) ram_write_enable <= 0;
      switcher_save_ready <= 1;
    end
    if (stage5_save) begin
      stage5_save_ready <= 0;
      ram_write_enable  <= 1;
      ram_address = stage5_save_address;
      ram_data_in = stage5_save_data_in;
      $display($time, " saving RAM from stage5 address ", stage5_save_address);
      @(posedge ram_clk) @(negedge ram_clk) ram_write_enable <= 0;
      stage5_save_ready <= 1;
    end
    if (switcher_read) begin
      switcher_read_ready <= 0;
      ram_write_enable <= 0;
      ram_address = switcher_read_address;
      @(posedge ram_clk)
      @(negedge ram_clk)
      $display(
          $time,
          " reading RAM from switcher address ",
          switcher_read_address,
          " value ",
          ram_data_out
      );
      switcher_read_data_out <= ram_data_out;
      switcher_read_ready <= 1;
    end
    if (stage3_read) begin
      stage3_read_ready <= 0;
      ram_write_enable  <= 0;
      ram_address = stage3_read_address;
      @(posedge ram_clk)
      @(negedge ram_clk)
      $display(
          $time, " reading RAM from stage3 address ", stage3_read_address, " value ", ram_data_out
      );
      stage3_read_data_out <= ram_data_out;
      stage3_read_ready <= 1;
    end
    if (stage12_read) begin
      stage12_read_ready <= 0;
      ram_write_enable   <= 0;
      ram_address = stage12_read_address;
      @(posedge ram_clk)
      @(negedge ram_clk)
      $display(
          $time, " reading RAM from stage12 address ", stage12_read_address, " value ", ram_data_out
      );
      stage12_read_data_out <= ram_data_out;
      stage12_read_ready <= 1;
    end
    //$display($time," ",stage3_read, " ",stage12_read," ",stage5_save);
  end
endmodule

// we have to use standard RAM = definition is "as is"
module ram (
    input ram_clk,
    input write_enable,
    input [15:0] address,
    input [7:0] data_in,
    output reg [7:0] data_out
);
  reg [7:0] ram_memory[0:65536];

  initial begin
    $readmemh("rom2.mem", ram_memory);
  end
  always @(posedge ram_clk) begin
    if (write_enable) begin
      ram_memory[address] <= data_in;
    end else begin
      data_out <= ram_memory[address];
    end
  end
endmodule

module registers (
    input [15:0] start_pc,
    input stage12_read,
    output reg stage12_read_ready,
    input [15:0] stage12_read_address,
    output reg [7:0] stage12_read_data_out,
    input stage3_save,
    output reg stage3_save_ready,
    input [15:0] stage3_save_address,
    input [7:0] stage3_save_data_in,
    input stage4_save,
    output reg stage4_save_ready,
    input [15:0] stage4_save_address,
    input [7:0] stage4_save_data_in,
    input stage4_read,
    output reg stage4_read_ready,
    input [15:0] stage4_read_address,
    output reg [7:0] stage4_read_data_out,
    input stage5_read,
    output reg stage5_read_ready,
    input [15:0] stage5_read_address,
    output reg [7:0] stage5_read_data_out,
    input switcher_save,
    output reg switcher_save_ready,
    input [15:0] switcher_save_address,
    input [7:0] switcher_save_data_in,
    input switcher_read,
    output reg switcher_read_ready,
    input [15:0] switcher_read_address,
    output reg [7:0] switcher_read_data_out,
    input dump_reg,
    output reg dump_reg_ready,
    output reg [`REGISTER_NUM-1:0] registers_used
);
  reg [7:0] registers_memory[`REGISTER_NUM-1:0];

  integer i;
  string s2;

  always @(start_pc) begin
    for (i = 0; i < `REGISTER_NUM; i++) begin
      registers_used[i] = 0;
    end
  end
  always @(posedge stage12_read) begin
    stage12_read_ready <= 0;
    stage12_read_data_out = registers_memory[stage12_read_address];
    stage12_read_ready <= 1;
  end
  always @(posedge stage3_save) begin
    stage3_save_ready <= 0;
    registers_memory[stage3_save_address] = stage3_save_data_in;
    registers_used[stage3_save_address]   = 1;
    stage3_save_ready <= 1;
  end
  always @(posedge stage4_save) begin
    stage4_save_ready <= 0;
    registers_memory[stage4_save_address] = stage4_save_data_in;
    registers_used[stage4_save_address]   = 1;
    stage4_save_ready <= 1;
  end
  always @(posedge stage4_read) begin
    stage4_read_ready <= 0;
    stage4_read_data_out = registers_memory[stage4_read_address];
    stage4_read_ready <= 1;
  end
  always @(posedge stage5_read) begin
    stage5_read_ready <= 0;
    stage5_read_data_out = registers_memory[stage5_read_address];
    stage5_read_ready <= 1;
  end
  always @(posedge switcher_save) begin
    switcher_save_ready <= 0;
    registers_memory[switcher_save_address] = switcher_save_data_in;
    registers_used[switcher_save_address]   = 1;
    switcher_save_ready <= 1;
  end
  always @(posedge switcher_read) begin
    switcher_read_ready <= 0;
    switcher_read_data_out = registers_memory[switcher_read_address];
    switcher_read_ready <= 1;
  end
  always @(posedge dump_reg) begin
    dump_reg_ready <= 0;
    s2 = " ";
    for (i = 0; i < 20; i++) begin
      s2 = {s2, $sformatf("%02x ", registers_memory[i])};
    end
    $display($time, s2);
    dump_reg_ready <= 1;
  end
endmodule


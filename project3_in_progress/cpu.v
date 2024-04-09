//process instruction codes
`define OPCODE_LOADFROMRAM 1 //load from memory with specified address, params: target register number, length, source memory address
`define OPCODE_JUMPMINUS 2
`define OPCODE_WRITETORAM 3 //save to memory with specified address, params: source register number, length, target memory address
`define OPCODE_ADD8 4 //add register A and B and save to register "out", 8-bit processing
`define OPCODE_JUMPPLUS 5
`define OPCODE_ADDNUM8 6 //add numeric value to registers
`define OPCODE_READFROMRAM 7 //load from memory from address in register to register, params: target register number, length, register with source address
`define OPCODE_SAVETORAM 8 //save to memory with address in register, params: source register number, length, register with target address
`define OPCODE_SET8 9 //set registers
`define OPCODE_PROC 10 //new process

//alu operations
`define OPER_ADD 1
`define OPER_ADDNUM 2
`define OPER_SETNUM 3

//offsets for process
`define ADDRESS_NEXT_PROCESS 0
`define ADDRESS_PC 4
`define ADDRESS_REG_USED 8
`define ADDRESS_REG 16
`define ADDRESS_PROGRAM `REGISTER_NUM+16

`define REGISTER_NUM 64 //number of registers
`define MAX_BITS_IN_REGISTER_NUM 6 //2^6=64
`define OP_PER_TASK 7 // opcodes per task before switching
`define MAX_BITS_IN_ADDRESS 31 //32-bit addresses

`define DEBUG_LEVEL 1 //higher=more info

module cpu (
    input rst,
    input ram_clk
);
  //task switcher  
  reg switcher_exec;
  wire switcher_exec_ready;
  wire [`MAX_BITS_IN_ADDRESS:0] start_pc;
  wire [`MAX_BITS_IN_ADDRESS:0] pc;
  wire [`REGISTER_NUM-1:0] registers_used;
  reg [7:0] executed;
  switcher switcher (
      .rst(rst),
      .start_pc(start_pc),
      .pc(pc),
      .registers_used(registers_used),
      .switcher_exec(switcher_exec),
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
  wire [`MAX_BITS_IN_REGISTER_NUM:0] stage12_register_read_address;
  wire [7:0] stage12_register_read_data_out;

  wire stage3_register_save;
  wire stage3_register_save_ready;
  wire [`MAX_BITS_IN_REGISTER_NUM:0] stage3_register_save_address;
  wire [7:0] stage3_register_save_data_in;

  wire stage4_register_save;
  wire stage4_register_save_ready;
  wire [`MAX_BITS_IN_REGISTER_NUM:0] stage4_register_save_address;
  wire [7:0] stage4_register_save_data_in;

  wire stage4_register_read;
  wire stage4_register_read_ready;
  wire [`MAX_BITS_IN_REGISTER_NUM:0] stage4_register_read_address;
  wire [7:0] stage4_register_read_data_out;

  wire stage5_register_read;
  wire stage5_register_read_ready;
  wire [`MAX_BITS_IN_REGISTER_NUM:0] stage5_register_read_address;
  wire [7:0] stage5_register_read_data_out;

  wire switcher_register_save;
  wire switcher_register_save_ready;
  wire [`MAX_BITS_IN_REGISTER_NUM:0] switcher_register_save_address;
  wire [7:0] switcher_register_save_data_in;

  wire switcher_register_read;
  wire switcher_register_read_ready;
  wire [`MAX_BITS_IN_REGISTER_NUM:0] switcher_register_read_address;
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
  wire [`MAX_BITS_IN_ADDRESS:0] stage12_ram_read_address;
  wire [7:0] stage12_ram_read_data_out;

  wire stage12_split_process;
  wire stage12_split_process_ready;
  wire [`MAX_BITS_IN_ADDRESS:0] stage12_split_process_start;
  wire [`MAX_BITS_IN_ADDRESS:0] stage12_split_process_end;

  wire stage3_ram_read;
  wire stage3_ram_read_ready;
  wire [`MAX_BITS_IN_ADDRESS:0] stage3_ram_read_address;
  wire [7:0] stage3_ram_read_data_out;

  wire stage5_ram_save;
  wire stage5_ram_save_ready;
  wire [`MAX_BITS_IN_ADDRESS:0] stage5_ram_save_address;
  wire [7:0] stage5_ram_save_data_in;

  wire switcher_ram_read;
  wire switcher_ram_read_ready;
  wire [`MAX_BITS_IN_ADDRESS:0] switcher_ram_read_address;
  wire [7:0] switcher_ram_read_data_out;

  wire switcher_ram_save;
  wire switcher_ram_save_ready;
  wire [`MAX_BITS_IN_ADDRESS:0] switcher_ram_save_address;
  wire [7:0] switcher_ram_save_data_in;

  ram2 ram2 (
      .ram_clk(ram_clk),
      .start_pc(start_pc),
      .stage12_split_process(stage12_split_process),
      .stage12_split_process_ready(stage12_split_process_ready),
      .stage12_split_process_start(stage12_split_process_start),
      .stage12_split_process_end(stage12_split_process_end),
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
  wire [`MAX_BITS_IN_ADDRESS:0] stage3_source_ram_address;  //address, which we should read
  wire [`MAX_BITS_IN_REGISTER_NUM:0] stage3_target_register_start;
  wire [`MAX_BITS_IN_REGISTER_NUM:0] stage3_target_register_length;
  wire stage4_should_exec;
  wire [15:0] stage4_oper;
  wire [`MAX_BITS_IN_REGISTER_NUM:0] stage4_register_A_start;
  wire [`MAX_BITS_IN_REGISTER_NUM:0] stage4_register_B_start;
  wire [15:0] stage4_value_B;
  wire [`MAX_BITS_IN_REGISTER_NUM:0] stage4_register_out_start;
  wire [`MAX_BITS_IN_REGISTER_NUM:0] stage4_register_length;
  wire stage5_should_exec;  //should we do it?
  wire [`MAX_BITS_IN_REGISTER_NUM:0] stage5_source_register_start;
  wire [`MAX_BITS_IN_REGISTER_NUM:0] stage5_source_register_length;
  wire [`MAX_BITS_IN_ADDRESS:0] stage5_target_ram_address;

  stage12 stage12 (
      .stage12_exec(stage12_exec),
      .stage12_exec_ready(stage12_exec_ready),
      .pc(pc),
      .start_pc(start_pc),
      .stage12_split_process(stage12_split_process),
      .stage12_split_process_ready(stage12_split_process_ready),
      .stage12_split_process_start(stage12_split_process_start),
      .stage12_split_process_end(stage12_split_process_end),
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
    if (`DEBUG_LEVEL == 2) $display($time, " reset1");
    switcher_exec = 0;
    if (`DEBUG_LEVEL == 2) $display($time, "   switcher should exec ", switcher_exec);
    executed = 0;
    stage12_exec = 1;  //start it
  end
  always @(negedge stage12_exec) begin
    if (`DEBUG_LEVEL == 2) $display($time, " negedge stage12exec");
    if (executed < `OP_PER_TASK) begin
      if (`DEBUG_LEVEL == 2) $display($time, " start 12 ", executed);
      stage12_exec = 1;  //force it to start again
    end
  end
  always @(posedge stage12_exec_ready) begin
    if (`DEBUG_LEVEL == 2) $display($time, " posedge stage12execready");
    stage12_exec = 0;
    if (stage3_should_exec) begin
      stage3_exec = 1;  // start when necessary
    end else if (stage4_should_exec) begin
      stage4_exec = 1;  // start when necessary
    end else if (stage5_should_exec) begin
      //$display($time," stage5_should_exec");
      stage5_exec = 1;  // start when necessary
    end else begin
      if (executed == `OP_PER_TASK) begin
        switcher_exec = 1;
        if (`DEBUG_LEVEL == 2) $display($time, "   switcher should exec12 ", switcher_exec);
      end else begin
        executed++;
      end
    end
  end
  always @(posedge stage3_exec_ready) begin
    if (`DEBUG_LEVEL == 2) $display($time, " posedge stage3execready");
    dump_reg <= 1;
    @(posedge dump_reg_ready) dump_reg <= 0;
    if (executed == `OP_PER_TASK) begin
      switcher_exec = 1;
      if (`DEBUG_LEVEL == 2) $display($time, "   switcher should exec3 ", switcher_exec);
    end else begin
      executed++;
    end
    stage3_exec = 0;
  end
  always @(posedge stage4_exec_ready) begin
    if (`DEBUG_LEVEL == 2) $display($time, " posedge stage4execready");
    dump_reg <= 1;
    @(posedge dump_reg_ready) dump_reg <= 0;
    if (executed == `OP_PER_TASK) begin
      switcher_exec = 1;
      if (`DEBUG_LEVEL == 2) $display($time, "   switcher should exec4 ", switcher_exec);
    end else begin
      executed++;
    end
    stage4_exec = 0;
  end
  always @(posedge stage5_exec_ready) begin
    if (`DEBUG_LEVEL == 2) $display($time, " posedge stage5execready");
    if (executed == `OP_PER_TASK) begin
      switcher_exec = 1;
      if (`DEBUG_LEVEL == 2) $display($time, "   switcher should exec5 ", switcher_exec);
    end else begin
      executed++;
    end
    stage5_exec = 0;
  end
  always @(posedge switcher_exec_ready) begin
    if (`DEBUG_LEVEL == 2) $display($time, " posedge switcherexecready");
    dump_reg <= 1;
    @(posedge dump_reg_ready) dump_reg <= 0;
    executed = 0;
    stage12_exec = 1;
    switcher_exec = 0;
  end
endmodule

module stage12 (
    input [`MAX_BITS_IN_ADDRESS:0] start_pc,
    output reg [`MAX_BITS_IN_ADDRESS:0] pc,
    input stage12_exec,
    output reg stage12_exec_ready,
    output reg stage12_split_process,
    input stage12_split_process_ready,
    output reg [`MAX_BITS_IN_ADDRESS:0] stage12_split_process_start,
    output reg [`MAX_BITS_IN_ADDRESS:0] stage12_split_process_end,
    output reg stage3_should_exec,
    output reg [`MAX_BITS_IN_ADDRESS:0] stage3_source_ram_address,
    output reg [`MAX_BITS_IN_REGISTER_NUM:0] stage3_target_register_start,
    output reg [`MAX_BITS_IN_REGISTER_NUM:0] stage3_target_register_length,
    output reg stage4_should_exec,
    output reg [15:0] stage4_oper,
    output reg [`MAX_BITS_IN_REGISTER_NUM:0] stage4_register_A_start,
    output reg [`MAX_BITS_IN_REGISTER_NUM:0] stage4_register_B_start,
    output reg [15:0] stage4_value_B,
    output reg [`MAX_BITS_IN_REGISTER_NUM:0] stage4_register_out_start,
    output reg [`MAX_BITS_IN_REGISTER_NUM:0] stage4_register_length,
    output reg stage5_should_exec,
    output reg [`MAX_BITS_IN_REGISTER_NUM:0] stage5_source_register_start,
    output reg [`MAX_BITS_IN_REGISTER_NUM:0] stage5_source_register_length,
    output reg [`MAX_BITS_IN_ADDRESS:0] stage5_target_ram_address,
    //registers
    output reg stage12_register_read,
    input stage12_register_read_ready,
    output reg [`MAX_BITS_IN_REGISTER_NUM:0] stage12_register_read_address,
    input [7:0] stage12_register_read_data_out,
    //ram
    output reg stage12_ram_read,
    input stage12_ram_read_ready,
    output reg [`MAX_BITS_IN_ADDRESS:0] stage12_ram_read_address,
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
    if (`DEBUG_LEVEL == 2) $display($time, " executing pc ", pc);

    stage12_ram_read_address <= pc;
    stage12_ram_read <= 1;
    @(posedge stage12_ram_read_ready) stage12_ram_read <= 0;
    instruction[0] = stage12_ram_read_data_out;

    stage12_ram_read_address <= pc + 1;
    stage12_ram_read <= 1;
    @(posedge stage12_ram_read_ready) stage12_ram_read <= 0;
    instruction[1] = stage12_ram_read_data_out;

    if (instruction[0] == `OPCODE_JUMPMINUS) begin
      $display($time, instruction[0], " ", instruction[1], " ", instruction[2], " ",
               instruction[3], "   JUMPMINUS");
      pc -= instruction[1] * 4;
    end
    if (instruction[0] == `OPCODE_JUMPPLUS) begin
      $display($time, instruction[0], " ", instruction[1], " ", instruction[2], " ",
               instruction[3], "   JUMPPLUS");
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
        $display($time, instruction[0], " ", instruction[1], " ", instruction[2], " ",
                 instruction[3], "   LOADFROMRAM ", stage3_target_register_length
                 , " bytes from RAM address ", stage3_source_ram_address, "+ and save to register "
                 , stage3_target_register_start, "+");
        stage3_should_exec <= 1;
      end
      if (instruction[0] == `OPCODE_READFROMRAM) begin
        stage12_register_read_address <= instruction[3];
        stage12_register_read <= 1;
        @(posedge stage12_register_read_ready) stage12_register_read <= 0;

        stage3_target_register_start = instruction[1];
        stage3_target_register_length = instruction[2];
        stage3_source_ram_address = stage12_register_read_data_out;

        $display($time, instruction[0], " ", instruction[1], " ", instruction[2], " ",
                 instruction[3], "   READFROMRAM ", stage3_target_register_length
                 , " bytes from RAM address ", stage3_source_ram_address, "+ and save to register "
                 , stage3_target_register_start, "+");
        stage3_should_exec <= 1;
      end else if (instruction[0] == `OPCODE_WRITETORAM) begin
        stage5_source_register_start = instruction[1];
        stage5_source_register_length = instruction[2];
        stage5_target_ram_address = instruction[3];
        $display($time, instruction[0], " ", instruction[1], " ", instruction[2], " ",
                 instruction[3], "   WRITETORAM ", stage5_source_register_length,
                 " bytes from register ", stage5_source_register_start,
                 "+ and save to RAM address ", stage5_target_ram_address, "+");
        stage5_should_exec <= 1;
      end else if (instruction[0] == `OPCODE_SAVETORAM) begin
        stage12_register_read_address <= instruction[3];
        stage12_register_read <= 1;
        @(posedge stage12_register_read_ready) stage12_register_read <= 0;

        stage5_source_register_start = instruction[1];
        stage5_source_register_length = instruction[2];
        stage5_target_ram_address = stage12_register_read_data_out;
        $display($time, instruction[0], " ", instruction[1], " ", instruction[2], " ",
                 instruction[3], "   SAVETORAM ", stage5_source_register_length,
                 " bytes from register ", stage5_source_register_start,
                 "+ and save to RAM address ", stage5_target_ram_address, "+");
        stage5_should_exec <= 1;
      end else if (instruction[0] == `OPCODE_ADD8) begin
        stage4_oper = `OPER_ADD;
        stage4_register_A_start = instruction[1];
        stage4_register_B_start = instruction[1];
        stage4_register_out_start = instruction[2];
        stage4_register_length = instruction[3];
        $display($time, instruction[0], " ", instruction[1], " ", instruction[2], " ",
                 instruction[3], "   ADD8 add register ", stage4_register_A_start,
                 "+ to register ", stage4_register_B_start, " and save to register ",
                 stage4_register_out_start, "+, len ", stage4_register_length);
        stage4_should_exec <= 1;
      end else if (instruction[0] == `OPCODE_ADDNUM8) begin
        stage4_oper = `OPER_ADDNUM;
        stage4_register_A_start = instruction[1];
        stage4_value_B = instruction[1];
        stage4_register_out_start = instruction[2];
        stage4_register_length = instruction[3];
        $display($time, instruction[0], " ", instruction[1], " ", instruction[2], " ",
                 instruction[3], "   ADDNUM8 add value ", stage4_value_B, " to register "
                 , stage4_register_A_start, " and save to register ", stage4_register_out_start
                 , "+, len ", stage4_register_length);
        stage4_should_exec <= 1;
      end else if (instruction[0] == `OPCODE_SET8) begin
        stage4_oper = `OPER_SETNUM;
        //stage4_register_A_start=instruction[1];
        stage4_value_B = 0;
        stage4_register_out_start = instruction[1];
        stage4_register_length = instruction[2];
        $display($time, instruction[0], " ", instruction[1], " ", instruction[2], " ",
                 instruction[3], "   SET8 add value ", stage4_value_B, " to register ",
                 stage4_register_A_start, " and save to register ", stage4_register_out_start
                 , "+, len ", stage4_register_length);
        stage4_should_exec <= 1;
      end else if (instruction[0] == `OPCODE_PROC) begin
        stage12_split_process_start = instruction[1];
        stage12_split_process_end   = instruction[2];
        stage12_split_process <= 1;
        @(posedge stage12_split_process_ready) stage12_split_process <= 0;
        $display($time, instruction[0], " ", instruction[1], " ", instruction[2], " ",
                 instruction[3],
                 "   PROC create new process from current process, take memory segments ",
                 instruction[1], "-", instruction[2]);
      end
      pc += 4;
    end
    // $display($time, "  OPCODE ", instruction[0], " ", instruction[1], " ", instruction[2], " ",
    //        instruction[3]);
    stage12_exec_ready <= 1;
  end
endmodule

module stage3 (
    input stage3_exec,
    output reg stage3_exec_ready,
    input [`MAX_BITS_IN_ADDRESS:0] stage3_source_ram_address,
    input [`MAX_BITS_IN_REGISTER_NUM:0] stage3_target_register_start,
    input [`MAX_BITS_IN_REGISTER_NUM:0] stage3_target_register_length,
    //registers
    output reg stage3_register_save,
    input stage3_register_save_ready,
    output reg [`MAX_BITS_IN_REGISTER_NUM:0] stage3_register_save_address,
    output reg [7:0] stage3_register_save_data_in,
    //ram
    output reg stage3_ram_read,
    input stage3_ram_read_ready,
    output reg [`MAX_BITS_IN_ADDRESS:0] stage3_ram_read_address,
    input [7:0] stage3_ram_read_data_out
);

  integer i;

  always @(posedge stage3_exec) begin
    stage3_exec_ready <= 0;
    for (i = 0; i < stage3_target_register_length; i++) begin
      stage3_ram_read_address <= stage3_source_ram_address + i;
      stage3_ram_read <= 1;
      @(posedge stage3_ram_read_ready) stage3_ram_read <= 0;

      stage3_register_save_address <= stage3_target_register_start + i;
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
    input [`MAX_BITS_IN_REGISTER_NUM:0] stage4_register_A_start,
    input [`MAX_BITS_IN_REGISTER_NUM:0] stage4_register_B_start,
    input [15:0] stage4_value_B,
    input [`MAX_BITS_IN_REGISTER_NUM:0] stage4_register_out_start,
    input [`MAX_BITS_IN_REGISTER_NUM:0] stage4_register_length,
    //registers
    output reg stage4_register_save,
    input stage4_register_save_ready,
    output reg [`MAX_BITS_IN_REGISTER_NUM:0] stage4_register_save_address,
    output reg [7:0] stage4_register_save_data_in,
    output reg stage4_register_read,
    input stage4_register_read_ready,
    output reg [`MAX_BITS_IN_REGISTER_NUM:0] stage4_register_read_address,
    input [7:0] stage4_register_read_data_out
);

  integer i;
  string s2;
  reg [7:0] temp;

  always @(posedge stage4_exec) begin
    stage4_exec_ready <= 0;
    if (`DEBUG_LEVEL == 2) $display($time, " stage 4 starting ", stage4_value_B);
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
    input [`MAX_BITS_IN_REGISTER_NUM:0] stage5_source_register_start,
    input [`MAX_BITS_IN_REGISTER_NUM:0] stage5_source_register_length,
    input [`MAX_BITS_IN_ADDRESS:0] stage5_target_ram_address,
    //registers
    output reg stage5_register_read,
    input stage5_register_read_ready,
    output reg [`MAX_BITS_IN_REGISTER_NUM:0] stage5_register_read_address,
    input [7:0] stage5_register_read_data_out,
    //ram
    output reg stage5_ram_save,
    input stage5_ram_save_ready,
    output reg [`MAX_BITS_IN_ADDRESS:0] stage5_ram_save_address,
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
    input [`MAX_BITS_IN_ADDRESS:0] pc,
    input switcher_exec,
    output reg switcher_exec_ready,
    input rst,
    output reg [`MAX_BITS_IN_ADDRESS:0] start_pc,
    input [`REGISTER_NUM-1:0] registers_used,
    //registers
    output reg switcher_register_save,
    input switcher_register_save_ready,
    output reg [`MAX_BITS_IN_REGISTER_NUM:0] switcher_register_save_address,
    output reg [7:0] switcher_register_save_data_in,
    output reg switcher_register_read,
    input switcher_register_read_ready,
    output reg [`MAX_BITS_IN_REGISTER_NUM:0] switcher_register_read_address,
    input [7:0] switcher_register_read_data_out,
    //ram
    output reg switcher_ram_save,
    input switcher_ram_save_ready,
    output reg [`MAX_BITS_IN_ADDRESS:0] switcher_ram_save_address,
    output reg [7:0] switcher_ram_save_data_in,
    output reg switcher_ram_read,
    input switcher_ram_read_ready,
    output reg [`MAX_BITS_IN_ADDRESS:0] switcher_ram_read_address,
    input [7:0] switcher_ram_read_data_out
);

  integer i, j, z;
  string s2;
  reg [`MAX_BITS_IN_ADDRESS:0] process_address;
  reg [7:0] temp[7:0];
  reg [7:0] old_reg_used[7:0];
  reg [`REGISTER_NUM-1:0] old_registers_used;

  always @(rst) begin
    if (`DEBUG_LEVEL == 2) $display($time, " reset2");
    process_address = 0;
    start_pc = 12 + `REGISTER_NUM;
    for (i = 0; i < 8; i++) begin
      old_reg_used[i] = 0;
    end
    for (i = 0; i < `REGISTER_NUM; i++) begin
      old_registers_used[i] = 0;
    end
  end

  always @(posedge switcher_exec) begin
    if (`DEBUG_LEVEL == 2) $display($time, "switcher start");
    switcher_exec_ready <= 0;

    //dump pc
    if (`DEBUG_LEVEL == 2) $display($time, "dump pc");
    temp[0] = pc[0]+pc[1]*2+pc[2]*4+pc[3]*8+pc[4]*16+pc[5]*32+pc[6]*64+pc[7]*128;
    temp[1] = pc[8]+pc[9]*2+pc[10]*4+pc[11]*8+pc[12]*16+pc[13]*32+pc[14]*64+pc[15]*128;
    for (i = 0; i < 2; i++) begin
      switcher_ram_save_address <= process_address + `ADDRESS_PC + i;
      switcher_ram_save_data_in <= temp[i];
      switcher_ram_save <= 1;
      @(posedge switcher_ram_save_ready) switcher_ram_save <= 0;
    end

    //dump registers used
    if (`DEBUG_LEVEL == 2) $display($time, "dump reg used");
    temp[0] = registers_used[0]+registers_used[1]*2+registers_used[2]*4+registers_used[3]*8+registers_used[4]*16+registers_used[5]*32+registers_used[6]*64+registers_used[7]*128;
    temp[1] = registers_used[8]+registers_used[9]*2+registers_used[10]*4+registers_used[11]*8+registers_used[12]*16+registers_used[13]*32+registers_used[14]*64+registers_used[15]*128;
    temp[2] = registers_used[16]+registers_used[17]*2+registers_used[18]*4+registers_used[19]*8+registers_used[20]*16+registers_used[21]*32+registers_used[22]*64+registers_used[23]*128;
    temp[3] = registers_used[24]+registers_used[25]*2+registers_used[26]*4+registers_used[27]*8+registers_used[28]*16+registers_used[29]*32+registers_used[30]*64+registers_used[31]*128;
    temp[4] = registers_used[32]+registers_used[33]*2+registers_used[34]*4+registers_used[35]*8+registers_used[36]*16+registers_used[37]*32+registers_used[38]*64+registers_used[39]*128;
    temp[5] = registers_used[40]+registers_used[41]*2+registers_used[42]*4+registers_used[43]*8+registers_used[44]*16+registers_used[45]*32+registers_used[46]*64+registers_used[47]*128;
    temp[6] = registers_used[48]+registers_used[49]*2+registers_used[50]*4+registers_used[51]*8+registers_used[52]*16+registers_used[53]*32+registers_used[54]*64+registers_used[55]*128;
    temp[7] = registers_used[56]+registers_used[57]*2+registers_used[58]*4+registers_used[59]*8+registers_used[60]*16+registers_used[61]*32+registers_used[62]*64+registers_used[63]*128;
    if (`DEBUG_LEVEL == 2)
      $display(
          $time,
          "reg used ",
          temp[0],
          " ",
          temp[1],
          " ",
          temp[2],
          " ",
          temp[3],
          " ",
          temp[4],
          " ",
          temp[5],
          " ",
          temp[6],
          " ",
          temp[7]
      );

    for (i = 0; i < 8; i++) begin
      if (old_reg_used[i] != temp[i]) begin
        switcher_ram_save_address <= process_address + `ADDRESS_REG_USED + i;
        switcher_ram_save_data_in <= temp[i];
        switcher_ram_save <= 1;
        @(posedge switcher_ram_save_ready) switcher_ram_save <= 0;
      end
    end

    //dump registers
    if (`DEBUG_LEVEL == 2) $display($time, "dump reg");

    for (i = 0; i < `REGISTER_NUM; i++) begin
      if (registers_used[i]) begin
        switcher_register_read_address <= i;
        switcher_register_read <= 1;
        @(posedge switcher_register_read_ready) switcher_register_read <= 0;

        if (old_registers_used[i] != switcher_register_read_data_out) begin
          switcher_ram_save_address <= process_address + i + `ADDRESS_REG;
          switcher_ram_save_data_in <= switcher_register_read_data_out;
          switcher_ram_save <= 1;
          @(posedge switcher_ram_save_ready) switcher_ram_save <= 0;
        end
      end
    end

    //read next process address
    j = 0;
    for (i = 0; i < 4; i++) begin
      switcher_ram_read_address <= process_address + i;
      switcher_ram_read <= 1;
      @(posedge switcher_ram_read_ready) switcher_ram_read <= 0;
      j += switcher_ram_read_data_out * (256 ** i);
    end
    process_address = j;
    if (`DEBUG_LEVEL == 2) $display($time, "new process address ", process_address);
    $display($time, "");
    $display($time, "");
    $display($time, "");
    $display($time, "");

    //read next registers used and next registers
    for (i = 0; i < 8; i++) begin
      switcher_ram_read_address <= process_address + i + `ADDRESS_REG_USED;
      switcher_ram_read <= 1;
      @(posedge switcher_ram_read_ready) switcher_ram_read <= 0;
      old_reg_used[i] = switcher_ram_read_data_out;

      for (j = 0; j < 8; j++) begin
        if ((old_reg_used[i] & (2 ** j)) != 0) begin
          switcher_ram_read_address <= process_address + i * 8 + j + `ADDRESS_REG;
          switcher_ram_read <= 1;
          @(posedge switcher_ram_read_ready) switcher_ram_read <= 0;

          old_registers_used[i*8+j] = switcher_register_read_data_out;
        end else begin
          old_registers_used[i*8+j] = 0;
        end
        switcher_register_save_address <= i * 8 + j;
        switcher_register_save_data_in <= old_registers_used[i*8+j];
        switcher_register_save <= 1;
        @(posedge switcher_register_save_ready) switcher_register_save <= 0;
      end
    end

    //read next pc
    j = 0;
    for (i = 0; i < 4; i++) begin
      switcher_ram_read_address <= process_address + i + `ADDRESS_PC;
      switcher_ram_read <= 1;
      @(posedge switcher_ram_read_ready) switcher_ram_read <= 0;
      j += switcher_ram_read_data_out * (256 ** i);
    end
    start_pc = j;

    switcher_exec_ready <= 1;
  end
endmodule

module ram2 (
    input ram_clk,
    input [`MAX_BITS_IN_ADDRESS:0] start_pc,
    input stage12_read,
    output reg stage12_read_ready,
    input [`MAX_BITS_IN_ADDRESS:0] stage12_read_address,
    output reg [7:0] stage12_read_data_out,
    input stage3_read,
    output reg stage3_read_ready,
    input [`MAX_BITS_IN_ADDRESS:0] stage3_read_address,
    output reg [7:0] stage3_read_data_out,
    input stage5_save,
    output reg stage5_save_ready,
    input [`MAX_BITS_IN_ADDRESS:0] stage5_save_address,
    input [7:0] stage5_save_data_in,
    input switcher_read,
    output reg switcher_read_ready,
    input [`MAX_BITS_IN_ADDRESS:0] switcher_read_address,
    output reg [7:0] switcher_read_data_out,
    input switcher_save,
    output reg switcher_save_ready,
    input [`MAX_BITS_IN_ADDRESS:0] switcher_save_address,
    input [7:0] switcher_save_data_in,
    input stage12_split_process,
    output stage12_split_process_ready,
    input [`MAX_BITS_IN_ADDRESS:0] stage12_split_process_start,
    input [`MAX_BITS_IN_ADDRESS:0] stage12_split_process_end
);

  reg ram_write_enable;
  reg [`MAX_BITS_IN_ADDRESS:0] ram_address;
  reg [7:0] ram_data_in;
  wire [7:0] ram_data_out;

  ram ram (
      .ram_clk(ram_clk),
      .write_enable(ram_write_enable),
      .address(ram_address),
      .data_in(ram_data_in),
      .data_out(ram_data_out)
  );

  reg [`MAX_BITS_IN_ADDRESS:0] mmu_physical_process_address;
  reg [`MAX_BITS_IN_ADDRESS:0] mmu_logical_address;
  wire [`MAX_BITS_IN_ADDRESS:0] mmu_physical_address;
  reg mmu_get_physical_address;
  wire mmu_get_physical_address_ready;

  mmu mmu (
      .physical_process_address(start_pc),
      .logical_address(mmu_logical_address),
      .physical_address(mmu_physical_address),
      .mmu_get_physical_address(mmu_get_physical_address),
      .mmu_get_physical_address_ready(mmu_get_physical_address_ready),
      .mmu_split_process(stage12_split_process),
      .mmu_split_process_ready(stage12_split_process_ready),
      .mmu_split_process_start(stage12_split_process_start),
      .mmu_split_process_end(stage12_split_process_end)

  );

  always @(posedge stage12_read or posedge stage3_read or posedge stage5_save or posedge switcher_save or posedge switcher_read) begin
    if (switcher_save) begin
      switcher_save_ready <= 0;
      ram_write_enable <= 1;
      ram_address = switcher_save_address;
      ram_data_in = switcher_save_data_in;
      if (`DEBUG_LEVEL == 2)
        $display($time, " saving RAM from switcher address ", switcher_save_address);
      @(posedge ram_clk) @(negedge ram_clk) ram_write_enable <= 0;
      switcher_save_ready <= 1;
    end
    if (stage5_save) begin
      stage5_save_ready <= 0;
      mmu_logical_address = stage5_save_address;
      mmu_get_physical_address <= 1;
      @(posedge mmu_get_physical_address_ready) mmu_get_physical_address <= 0;
      ram_write_enable <= 1;
      ram_address = mmu_physical_address;
      ram_data_in = stage5_save_data_in;
      if (`DEBUG_LEVEL == 2)
        $display(
            $time,
            " saving RAM from stage5 address ",
            stage5_save_address,
            " ",
            mmu_physical_address
        );
      @(posedge ram_clk) @(negedge ram_clk) ram_write_enable <= 0;
      stage5_save_ready <= 1;
    end
    if (switcher_read) begin
      switcher_read_ready <= 0;
      ram_write_enable <= 0;
      ram_address = switcher_read_address;
      @(posedge ram_clk)
      @(negedge ram_clk)
      if (`DEBUG_LEVEL == 2)
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
      mmu_logical_address = stage3_read_address;
      mmu_get_physical_address <= 1;
      @(posedge mmu_get_physical_address_ready) mmu_get_physical_address <= 0;
      ram_write_enable <= 0;
      ram_address = mmu_physical_address;
      @(posedge ram_clk)
      @(negedge ram_clk)
      if (`DEBUG_LEVEL == 2)
        $display(
            $time,
            " reading RAM from stage3 address ",
            stage3_read_address,
            " ",
            mmu_physical_address,
            " value ",
            ram_data_out
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
      if (`DEBUG_LEVEL == 2)
        $display(
            $time,
            " reading RAM from stage12 address ",
            stage12_read_address,
            " value ",
            ram_data_out
        );
      stage12_read_data_out <= ram_data_out;
      stage12_read_ready <= 1;
    end
    //$display($time," ",stage3_read, " ",stage12_read," ",stage5_save);
  end
endmodule

//in final project: mme page 16384 bytes = 65536 pages per 1GB
module mmu (
    input mmu_get_physical_address,
    output reg mmu_get_physical_address_ready,
    input [`MAX_BITS_IN_ADDRESS:0] physical_process_address,
    input [`MAX_BITS_IN_ADDRESS:0] logical_address,
    output reg [`MAX_BITS_IN_ADDRESS:0] physical_address,
    input mmu_split_process,
    output reg mmu_split_process_ready,
    input [`MAX_BITS_IN_ADDRESS:0] mmu_split_process_start,
    input [`MAX_BITS_IN_ADDRESS:0] mmu_split_process_end
);
  reg [15:0] mmu_page_memory[0:65535];  //values = next physical start point for task
  reg [15:0] mmu_page_memory2[0:65535];  //values = logical page assign to this physical page
  reg [15:0] index_start;

  //cache
  // reg[`MAX_BITS_IN_ADDRESS:0] last_mmu_process_address;
  //  reg[15:0] last_mmu_physical_page_index;
  //  reg[15:0] last_mmu_logical_page_index;

  string s;
  integer i, j, index, previndex, z, newindex, previndex2, toprocess;

  initial begin
    for (i = 0; i < 65536; i++) begin
      //every new process cannot have one entry (mmu_page_memory==0) assigned to logical page >0 (first page must be assigned to logical page 0)
      mmu_page_memory[i]  = 0;
      mmu_page_memory2[i] = 1;
    end
    index_start = 1;
    // for now we have two tasks in rom, remove when rom will be ready
    //  mmu_page_memory2[0] = 0;
    //  mmu_page_memory2[1] = 0;
    mmu_page_memory[0] = 1;
    mmu_page_memory[1] = 2;
    mmu_page_memory[2] = 3;
    mmu_page_memory[3] = 0;
    mmu_page_memory2[0] = 0;
    mmu_page_memory2[1] = 1;
    mmu_page_memory2[2] = 2;
    mmu_page_memory2[3] = 3;
  end
  always @(posedge mmu_split_process) begin
    mmu_split_process_ready <= 0;

    s = " mmu reg ";
    for (i = 0; i < 20; i++) begin
      s = {s, $sformatf("%01x-%01x ", mmu_page_memory[i], mmu_page_memory2[i])};
    end
    $display($time, s);
    newindex  = physical_process_address / 171;  //start point for existing process
    previndex = newindex;
    do begin
      $display($time, "process chain0 ", mmu_page_memory[newindex], " ",
               mmu_page_memory2[newindex], newindex, " ", mmu_page_memory[previndex], " ",
               mmu_page_memory2[previndex], " ", previndex);
      previndex = newindex;
      newindex  = mmu_page_memory[previndex];
    end while (mmu_page_memory[previndex] !== 0);

    //algo to fix, problem when segments in parent process are not in increasing order
    j = 0;
    for (i = mmu_split_process_start; i <= mmu_split_process_end; i++) begin
      newindex  = physical_process_address / 171;  //start point for existing process
      previndex = newindex;
      do begin
        if (mmu_page_memory2[newindex] == i) begin
          mmu_page_memory[previndex] = mmu_page_memory[newindex];
          mmu_page_memory2[newindex] = j;
          j++;
          if (j == mmu_split_process_end) begin
            mmu_page_memory[newindex] = 0;
          end
          s = " mmu reg ";
          for (z = 0; z < 10; z++) begin
            s = {s, $sformatf("%01x-%01x ", mmu_page_memory[z], mmu_page_memory2[z])};
          end
          $display($time, s);
        end
        previndex = newindex;
        newindex  = mmu_page_memory[previndex];
      end while (mmu_page_memory[previndex] !== 0);
    end

    s = " mmu reg ";
    for (i = 0; i < 20; i++) begin
      s = {s, $sformatf("%01x-%01x ", mmu_page_memory[i], mmu_page_memory2[i])};
    end
    $display($time, s);

    mmu_split_process_ready <= 1;
  end
  //todo: caching last value
  always @(posedge mmu_get_physical_address) begin
    mmu_get_physical_address_ready <= 0;
    index = physical_process_address / 171;
    i = logical_address / 171;
    if (`DEBUG_LEVEL == 2)
      $display(
          $time,
          " MMU  process ",
          physical_process_address,
          " process logical page ",
          index,
          " logical address ",
          logical_address,
          " logical page ",
          i
      );

    while (mmu_page_memory[index] !== 0 && mmu_page_memory2[index] != i) begin
      index = mmu_page_memory[index];
    end
    if (mmu_page_memory2[index] != i) begin
      while (mmu_page_memory[index_start] !== 0 || mmu_page_memory2[index_start] !== 1) begin
        index_start++;
      end
      //fixme: no free memory situation
      mmu_page_memory[index] = index_start;
      index = index_start;
      mmu_page_memory2[index] = i;
    end
    physical_address = index * 171 + logical_address % 171;
    if (`DEBUG_LEVEL == 2) $display($time, " MMU  physical address ", physical_address);
    //    if (last_mmu_process_address==process_address && last_mmu_logical_page_index==i) begin
    //      	physical_address = last_mmu_logical_page_index*16384+logical_address%16384;

    s = " mmu reg ";
    for (i = 0; i < 20; i++) begin
      s = {s, $sformatf("%01x-%01x ", mmu_page_memory[i], mmu_page_memory2[i])};
    end
    if (`DEBUG_LEVEL == 2) $display($time, s);

    mmu_get_physical_address_ready <= 1;
  end
endmodule

// we have to use standard RAM = definition is "as is"
module ram (
    input ram_clk,
    input write_enable,
    input [`MAX_BITS_IN_ADDRESS:0] address,
    input [7:0] data_in,
    output reg [7:0] data_out
);
  reg [7:0] ram_memory[0:1048576];

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
    input [`MAX_BITS_IN_ADDRESS:0] start_pc,
    input stage12_read,
    output reg stage12_read_ready,
    input [`MAX_BITS_IN_REGISTER_NUM:0] stage12_read_address,
    output reg [7:0] stage12_read_data_out,
    input stage3_save,
    output reg stage3_save_ready,
    input [`MAX_BITS_IN_REGISTER_NUM:0] stage3_save_address,
    input [7:0] stage3_save_data_in,
    input stage4_save,
    output reg stage4_save_ready,
    input [`MAX_BITS_IN_REGISTER_NUM:0] stage4_save_address,
    input [7:0] stage4_save_data_in,
    input stage4_read,
    output reg stage4_read_ready,
    input [`MAX_BITS_IN_REGISTER_NUM:0] stage4_read_address,
    output reg [7:0] stage4_read_data_out,
    input stage5_read,
    output reg stage5_read_ready,
    input [`MAX_BITS_IN_REGISTER_NUM:0] stage5_read_address,
    output reg [7:0] stage5_read_data_out,
    input switcher_save,
    output reg switcher_save_ready,
    input [`MAX_BITS_IN_REGISTER_NUM:0] switcher_save_address,
    input [7:0] switcher_save_data_in,
    input switcher_read,
    output reg switcher_read_ready,
    input [`MAX_BITS_IN_REGISTER_NUM:0] switcher_read_address,
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
      //  registers_memory[i] = 0;
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
    registers_used[stage3_save_address]   = stage3_save_data_in != 0;
    stage3_save_ready <= 1;
  end
  always @(posedge stage4_save) begin
    stage4_save_ready <= 0;
    registers_memory[stage4_save_address] = stage4_save_data_in;
    registers_used[stage4_save_address]   = stage4_save_data_in != 0;
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
    registers_used[switcher_save_address]   = switcher_save_data_in != 0;
    switcher_save_ready <= 1;
  end
  always @(posedge switcher_read) begin
    switcher_read_ready <= 0;
    switcher_read_data_out = registers_memory[switcher_read_address];
    switcher_read_ready <= 1;
  end
  always @(posedge dump_reg) begin
    dump_reg_ready <= 0;
    s2 = " reg ";
    for (i = 0; i < 20; i++) begin
      s2 = {s2, $sformatf("%02x ", registers_memory[i])};
    end
    $display($time, s2);
    s2 = " reg used ";
    for (i = 0; i < 20; i++) begin
      s2 = {s2, $sformatf("%01x ", registers_used[i])};
    end
    if (`DEBUG_LEVEL == 2) $display($time, s2);
    dump_reg_ready <= 1;
  end
endmodule




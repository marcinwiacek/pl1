//process instruction codes
`define OPCODE_LOADFROMRAM 1 //load from memory with specified address, params: target register number, length, source memory address
`define OPCODE_JUMPMINUS 2 //param: how many instructions
`define OPCODE_WRITETORAM 3 //save to memory with specified address, params: source register number, length, target memory address
`define OPCODE_ADD8 4 //add register A and B and save to register "out", 8-bit processing, params: register A and B start (now the same, later other), out register start, how many 8-bit elements
`define OPCODE_JUMPPLUS 5 //param: how many instructions
`define OPCODE_ADDNUM8 6 //add numeric value to registers, params: register A start/number (now the same, later other), out register start, how many 8-bit elements
`define OPCODE_READFROMRAM 7 //load from memory from address in register to register, params: target register number, length, register with source address
`define OPCODE_SAVETORAM 8 //save to memory with address in register, params: source register number, length, register with target address
`define OPCODE_SET8 9 //set registers to 0 (now, in the future any value), params: register start num, how many 8-bit elements
`define OPCODE_PROC 10 //new process, params: start, end memory segment from existing process

//alu operations
`define OPER_ADD 1
`define OPER_ADDNUM 2
`define OPER_SETNUM 3

//offsets for process info
`define ADDRESS_NEXT_PROCESS 0
`define ADDRESS_PC 4
`define ADDRESS_REG_USED 8
`define ADDRESS_REG 16
`define ADDRESS_PROGRAM `REGISTER_NUM+16

`define REGISTER_NUM 64 //number of registers
`define MAX_BITS_IN_REGISTER_NUM 6 //64 registers = 2^6
`define OP_PER_TASK 4 // opcodes per task before switching
`define MAX_BITS_IN_ADDRESS 31 //32-bit addresses
`define MMU_PAGE_SIZE 172 //size of every MMU page, can be divided by 4

`define DEBUG_LEVEL 1 //higher=more info //DEBUG info

module cpu (
    input rst,
    input ram_clk
);

  //registers (in the future with extra prioritization and hazard detection)
  reg dump_reg;  //DEBUG info
  wire dump_reg_ready;  //DEBUG info

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
      .rst(rst),
      .physical_process_address(physical_process_address),
      .registers_used(registers_used),
      .dump_reg(dump_reg),  //DEBUG info
      .dump_reg_ready(dump_reg_ready),  //DEBUG info
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
  wire stage12_ram_read_read_with_mmu;
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
      .physical_process_address(physical_process_address),
      .stage12_split_process(stage12_split_process),
      .stage12_split_process_ready(stage12_split_process_ready),
      .stage12_split_process_start(stage12_split_process_start),
      .stage12_split_process_end(stage12_split_process_end),
      .stage12_read(stage12_ram_read),
      .stage12_read_ready(stage12_ram_read_ready),
      .stage12_read_with_mmu(stage12_ram_read_read_with_mmu),
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

  //task switcher  

  wire [`MAX_BITS_IN_ADDRESS:0] start_pc;
  wire [`MAX_BITS_IN_ADDRESS:0] pc;
  wire [`MAX_BITS_IN_ADDRESS:0] physical_process_address;
  wire [`REGISTER_NUM-1:0] registers_used;
  reg [7:0] executed;
  reg switcher_exec;
  wire switcher_exec_ready;
  switcher switcher (
      .rst(rst),
      .start_pc(start_pc),
      .pc(pc),
      .physical_process_address(physical_process_address),
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
      .physical_process_address(physical_process_address),
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
      .stage12_ram_read_with_mmu(stage12_ram_read_read_with_mmu),
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
    if (`DEBUG_LEVEL == 2) $display($time, " reset1");  //DEBUG info
    executed = 0;
    switcher_exec = 0;
    stage12_exec = 1;  //punch it
  end
  always @(negedge stage12_exec) begin
    if (`DEBUG_LEVEL == 2) $display($time, " negedge stage12exec");  //DEBUG info
    stage12_exec = 1;  //force it to start again
  end
  always @(posedge stage12_exec_ready) begin
    if (`DEBUG_LEVEL == 2)  //DEBUG info
      $display(  //DEBUG info
          $time, " posedge stage12execready "  //DEBUG info
      );  //DEBUG info
    executed++;
    if (stage3_should_exec) begin
      stage3_exec = 1;  // start when necessary
    end
    if (stage4_should_exec) begin
      stage4_exec = 1;  // start when necessary
    end
    if (stage5_should_exec) begin
      stage5_exec = 1;  // start when necessary
    end
    if (!stage3_should_exec && !stage4_should_exec && !stage5_should_exec && executed == `OP_PER_TASK) begin
      if (`DEBUG_LEVEL == 2)  //DEBUG info
        $display($time, "   switcher should exec12 ", executed, " ", switcher_exec);  //DEBUG info
      switcher_exec = 1;  //engage
    end
    if (executed < `OP_PER_TASK) stage12_exec = 0;
  end
  always @(posedge stage3_exec_ready) begin
    if (`DEBUG_LEVEL == 2) $display($time, " posedge stage3execready");  //DEBUG info
    dump_reg <= 1;  //DEBUG info
    @(posedge dump_reg_ready) dump_reg <= 0;  //DEBUG info
    if (executed == `OP_PER_TASK) begin
      switcher_exec = 1;  //make it so
      if (`DEBUG_LEVEL == 2)  //DEBUG info
        $display($time, "   switcher should exec3 ", executed, " ", switcher_exec);  //DEBUG info
    end
    stage3_exec = 0;
  end
  always @(posedge stage4_exec_ready) begin
    if (`DEBUG_LEVEL == 2) $display($time, " posedge stage4execready");  //DEBUG info
    dump_reg <= 1;  //DEBUG info
    @(posedge dump_reg_ready) dump_reg <= 0;  //DEBUG info
    if (executed == `OP_PER_TASK) begin
      switcher_exec = 1;
      if (`DEBUG_LEVEL == 2)  //DEBUG info
        $display($time, "   switcher should exec4 ", executed, " ", switcher_exec);  //DEBUG info
    end
    stage4_exec = 0;
  end
  always @(posedge stage5_exec_ready) begin
    if (`DEBUG_LEVEL == 2) $display($time, " posedge stage5execready");  //DEBUG info
    if (executed == `OP_PER_TASK) begin
      switcher_exec = 1;
      if (`DEBUG_LEVEL == 2)  //DEBUG info
        $display($time, "   switcher should exec5 ", executed, " ", switcher_exec);  //DEBUG info
    end
    stage5_exec = 0;
  end
  always @(posedge switcher_exec_ready) begin
    if (`DEBUG_LEVEL == 2) $display($time, " posedge switcherexecready");  //DEBUG info
    dump_reg <= 1;  //DEBUG info
    @(posedge dump_reg_ready) dump_reg <= 0;  //DEBUG info
    executed = 0;
    switcher_exec = 0;
    stage12_exec = 0;
  end
endmodule

module stage12 (
    input [`MAX_BITS_IN_ADDRESS:0] start_pc,
    input [`MAX_BITS_IN_ADDRESS:0] physical_process_address,
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
    output reg stage12_ram_read_with_mmu,
    output reg [`MAX_BITS_IN_ADDRESS:0] stage12_ram_read_address,
    input [7:0] stage12_ram_read_data_out
);

  reg [7:0] instruction[0:3];

  always @(physical_process_address) begin
    pc = start_pc;
    if (`DEBUG_LEVEL == 2) $display($time, " new pc ", start_pc);  //DEBUG info
  end

  always @(posedge stage12_exec) begin
    stage12_exec_ready <= 0;
    stage3_should_exec <= 0;
    stage4_should_exec <= 0;
    stage5_should_exec <= 0;
    if (`DEBUG_LEVEL == 2) $display($time, " executing pc ", pc);  //DEBUG info

    stage12_ram_read_address <= pc;
    stage12_ram_read_with_mmu <= 1;
    stage12_ram_read <= 1;
    @(posedge stage12_ram_read_ready) stage12_ram_read <= 0;
    instruction[0] = stage12_ram_read_data_out;

    stage12_ram_read_address <= pc + 1;
    stage12_ram_read_with_mmu <= 0;
    stage12_ram_read <= 1;
    @(posedge stage12_ram_read_ready) stage12_ram_read <= 0;
    instruction[1] = stage12_ram_read_data_out;

    if (instruction[0] == `OPCODE_JUMPMINUS) begin
      $display($time, instruction[0], " ", instruction[1], " ", instruction[2], " ",  //DEBUG info
               instruction[3], "   JUMPMINUS");  //DEBUG info
      pc -= instruction[1] * 4;
    end else if (instruction[0] == `OPCODE_JUMPPLUS) begin
      $display($time, instruction[0], " ", instruction[1], " ", instruction[2], " ",  //DEBUG info
               instruction[3], "   JUMPPLUS");  //DEBUG info
      pc += instruction[1] * 4;
    end else begin
      stage12_ram_read_address <= pc + 2;
      stage12_ram_read_with_mmu <= 0;
      stage12_ram_read <= 1;
      @(posedge stage12_ram_read_ready) stage12_ram_read <= 0;
      instruction[2] = stage12_ram_read_data_out;

      stage12_ram_read_address <= pc + 3;
      stage12_ram_read_with_mmu <= 0;
      stage12_ram_read <= 1;
      @(posedge stage12_ram_read_ready) stage12_ram_read <= 0;
      instruction[3] = stage12_ram_read_data_out;

      if (instruction[0] == `OPCODE_LOADFROMRAM) begin
        stage3_target_register_start = instruction[1];
        stage3_target_register_length = instruction[2];
        stage3_source_ram_address = instruction[3];
        $display($time, instruction[0], " ", instruction[1], " ", instruction[2], " ",  //DEBUG info
                 instruction[3], "   LOADFROMRAM ", stage3_target_register_length  //DEBUG info
                 , " bytes from RAM address ", stage3_source_ram_address,  //DEBUG info
                 "+ and save to register "  //DEBUG info
                 , stage3_target_register_start, "+");  //DEBUG info
        stage3_should_exec <= 1;
      end else if (instruction[0] == `OPCODE_READFROMRAM) begin
        stage12_register_read_address <= instruction[3];
        stage12_register_read <= 1;
        @(posedge stage12_register_read_ready) stage12_register_read <= 0;

        stage3_target_register_start = instruction[1];
        stage3_target_register_length = instruction[2];
        stage3_source_ram_address = stage12_register_read_data_out;

        $display($time, instruction[0], " ", instruction[1], " ", instruction[2], " ",  //DEBUG info
                 instruction[3], "   READFROMRAM ", stage3_target_register_length  //DEBUG info
                 , " bytes from RAM address ", stage3_source_ram_address,  //DEBUG info
                 "+ and save to register "  //DEBUG info
                 , stage3_target_register_start, "+");  //DEBUG info
        stage3_should_exec <= 1;
      end else if (instruction[0] == `OPCODE_WRITETORAM) begin
        stage5_source_register_start = instruction[1];
        stage5_source_register_length = instruction[2];
        stage5_target_ram_address = instruction[3];
        $display($time, instruction[0], " ", instruction[1], " ", instruction[2], " ",  //DEBUG info
                 instruction[3], "   WRITETORAM ", stage5_source_register_length,  //DEBUG info
                 " bytes from register ", stage5_source_register_start,  //DEBUG info
                 "+ and save to RAM address ", stage5_target_ram_address, "+");  //DEBUG info
        stage5_should_exec <= 1;
      end else if (instruction[0] == `OPCODE_SAVETORAM) begin
        stage12_register_read_address <= instruction[3];
        stage12_register_read <= 1;
        @(posedge stage12_register_read_ready) stage12_register_read <= 0;

        stage5_source_register_start = instruction[1];
        stage5_source_register_length = instruction[2];
        stage5_target_ram_address = stage12_register_read_data_out;
        $display($time, instruction[0], " ", instruction[1], " ", instruction[2], " ",  //DEBUG info
                 instruction[3], "   SAVETORAM ", stage5_source_register_length,  //DEBUG info
                 " bytes from register ", stage5_source_register_start,  //DEBUG info
                 "+ and save to RAM address ", stage5_target_ram_address, "+");  //DEBUG info
        stage5_should_exec <= 1;
      end else if (instruction[0] == `OPCODE_ADD8) begin
        stage4_oper = `OPER_ADD;
        stage4_register_A_start = instruction[1];
        stage4_register_B_start = instruction[1];
        stage4_register_out_start = instruction[2];
        stage4_register_length = instruction[3];
        $display($time, instruction[0], " ", instruction[1], " ", instruction[2], " ",  //DEBUG info
                 instruction[3], "   ADD8 add register ", stage4_register_A_start,  //DEBUG info
                 "+ to register ", stage4_register_B_start, " and save to register ",  //DEBUG info
                 stage4_register_out_start, "+, len ", stage4_register_length);  //DEBUG info
        stage4_should_exec <= 1;
      end else if (instruction[0] == `OPCODE_ADDNUM8) begin
        stage4_oper = `OPER_ADDNUM;
        stage4_register_A_start = instruction[1];
        stage4_value_B = instruction[1];
        stage4_register_out_start = instruction[2];
        stage4_register_length = instruction[3];
        $display(  //DEBUG info
            $time, instruction[0], " ", instruction[1], " ", instruction[2], " ",  //DEBUG info
            instruction[3], "   ADDNUM8 add value ", stage4_value_B, " to register "  //DEBUG info
            , stage4_register_A_start, " and save to register ",  //DEBUG info
            stage4_register_out_start  //DEBUG info
            , "+, len ", stage4_register_length);  //DEBUG info
        stage4_should_exec <= 1;
      end else if (instruction[0] == `OPCODE_SET8) begin
        stage4_oper = `OPER_SETNUM;
        //stage4_register_A_start=instruction[1];
        stage4_value_B = 0;
        stage4_register_out_start = instruction[1];
        stage4_register_length = instruction[2];
        $display(  //DEBUG info
            $time, instruction[0], " ", instruction[1], " ", instruction[2], " ",  //DEBUG info
            instruction[3], "   SET8 add value ", stage4_value_B, " to register ",  //DEBUG info
            stage4_register_A_start, " and save to register ",  //DEBUG info
            stage4_register_out_start  //DEBUG info
            , "+, len ", stage4_register_length);  //DEBUG info
        stage4_should_exec <= 1;
      end else if (instruction[0] == `OPCODE_PROC) begin
        $display(  //DEBUG info
            $time, instruction[0], " ", instruction[1], " ", instruction[2], " ",  //DEBUG info
            instruction[3],  //DEBUG info
            "   PROC create new process from current process, take memory segments ",  //DEBUG info
            instruction[1], " to ", instruction[2]);  //DEBUG info
        stage12_split_process_start = instruction[1];
        stage12_split_process_end   = instruction[2];
        stage12_split_process <= 1;
        @(posedge stage12_split_process_ready) stage12_split_process <= 0;

        //setup pc in new process
        //update process chain - get next from exeisting process and save into new one and in existing process point to new one

        //    read next process address
        /*j = 0;
    for (i = 0; i < 4; i++) begin
      switcher_ram_read_address <= process_address + i;
      switcher_ram_read <= 1;
      @(posedge switcher_ram_read_ready) switcher_ram_read <= 0;
      j += switcher_ram_read_data_out * (256 ** i);
    end*/
      end else if (  instruction[0] !== `OPCODE_JUMPMINUS && instruction[0] !== `OPCODE_JUMPPLUS) begin
        $display(  //DEBUG info
            $time, instruction[0], " ", instruction[1], " ", instruction[2], " ",  //DEBUG info
            instruction[3],  //DEBUG info
            "   unknown PCCODE");  //DEBUG info
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
  reg [7:0] temp;

  always @(posedge stage4_exec) begin
    stage4_exec_ready <= 0;
    if (`DEBUG_LEVEL == 2) $display($time, " stage 4 starting ", stage4_value_B);  //DEBUG info
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
          temp += stage4_register_read_data_out;
        end else begin
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
    output reg [`MAX_BITS_IN_ADDRESS:0] physical_process_address,
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
  string s2;  //DEBUG info
  reg [7:0] temp[7:0];
  reg [7:0] old_reg_used[7:0];
  reg [7:0] old_registers_memory[`REGISTER_NUM-1:0];

  always @(rst) begin
    if (`DEBUG_LEVEL == 2) $display($time, " reset2");  //DEBUG info
    physical_process_address = 0;
    start_pc = `ADDRESS_PROGRAM;
    for (i = 0; i < 8; i++) begin
      old_reg_used[i] = 0;
    end
    for (i = 0; i < `REGISTER_NUM; i++) begin
      old_registers_memory[i] = 0;
    end
  end

  always @(posedge switcher_exec) begin
    $display($time, " switcher start");  //DEBUG info
    switcher_exec_ready <= 0;

    //dump pc
    if (`DEBUG_LEVEL == 2) $display($time, " dump pc");  //DEBUG info
    temp[0] = pc[0]+pc[1]*2+pc[2]*4+pc[3]*8+pc[4]*16+pc[5]*32+pc[6]*64+pc[7]*128;
    temp[1] = pc[8]+pc[9]*2+pc[10]*4+pc[11]*8+pc[12]*16+pc[13]*32+pc[14]*64+pc[15]*128;
    for (i = 0; i < 2; i++) begin
      switcher_ram_save_address <= physical_process_address + `ADDRESS_PC + i;
      switcher_ram_save_data_in <= temp[i];
      switcher_ram_save <= 1;
      @(posedge switcher_ram_save_ready) switcher_ram_save <= 0;
    end

    //dump registers used
    if (`DEBUG_LEVEL == 2) $display($time, " dump reg used");  //DEBUG info
    temp[0] = registers_used[0]+registers_used[1]*2+registers_used[2]*4+registers_used[3]*8+registers_used[4]*16+registers_used[5]*32+registers_used[6]*64+registers_used[7]*128;
    temp[1] = registers_used[8]+registers_used[9]*2+registers_used[10]*4+registers_used[11]*8+registers_used[12]*16+registers_used[13]*32+registers_used[14]*64+registers_used[15]*128;
    temp[2] = registers_used[16]+registers_used[17]*2+registers_used[18]*4+registers_used[19]*8+registers_used[20]*16+registers_used[21]*32+registers_used[22]*64+registers_used[23]*128;
    temp[3] = registers_used[24]+registers_used[25]*2+registers_used[26]*4+registers_used[27]*8+registers_used[28]*16+registers_used[29]*32+registers_used[30]*64+registers_used[31]*128;
    temp[4] = registers_used[32]+registers_used[33]*2+registers_used[34]*4+registers_used[35]*8+registers_used[36]*16+registers_used[37]*32+registers_used[38]*64+registers_used[39]*128;
    temp[5] = registers_used[40]+registers_used[41]*2+registers_used[42]*4+registers_used[43]*8+registers_used[44]*16+registers_used[45]*32+registers_used[46]*64+registers_used[47]*128;
    temp[6] = registers_used[48]+registers_used[49]*2+registers_used[50]*4+registers_used[51]*8+registers_used[52]*16+registers_used[53]*32+registers_used[54]*64+registers_used[55]*128;
    temp[7] = registers_used[56]+registers_used[57]*2+registers_used[58]*4+registers_used[59]*8+registers_used[60]*16+registers_used[61]*32+registers_used[62]*64+registers_used[63]*128;
    if (`DEBUG_LEVEL == 2)  //DEBUG info
      $display(  //DEBUG info
          $time,  //DEBUG info
          " reg used ",  //DEBUG info
          temp[0],  //DEBUG info
          " ",  //DEBUG info
          temp[1],  //DEBUG info
          " ",  //DEBUG info
          temp[2],  //DEBUG info
          " ",  //DEBUG info
          temp[3],  //DEBUG info
          " ",  //DEBUG info
          temp[4],  //DEBUG info
          " ",  //DEBUG info
          temp[5],  //DEBUG info
          " ",  //DEBUG info
          temp[6],  //DEBUG info
          " ",  //DEBUG info
          temp[7]  //DEBUG info
      );  //DEBUG info

    for (i = 0; i < 8; i++) begin
      if (old_reg_used[i] != temp[i]) begin
        switcher_ram_save_address <= physical_process_address + `ADDRESS_REG_USED + i;
        switcher_ram_save_data_in <= temp[i];
        switcher_ram_save <= 1;
        @(posedge switcher_ram_save_ready) switcher_ram_save <= 0;
      end
    end

    //dump registers
    if (`DEBUG_LEVEL == 2) $display($time, " dump reg");  //DEBUG info

    for (i = 0; i < `REGISTER_NUM; i++) begin
      if (registers_used[i]) begin
        switcher_register_read_address <= i;
        switcher_register_read <= 1;
        @(posedge switcher_register_read_ready) switcher_register_read <= 0;

        if (old_registers_memory[i] != switcher_register_read_data_out) begin
          switcher_ram_save_address <= physical_process_address + i + `ADDRESS_REG;
          switcher_ram_save_data_in <= switcher_register_read_data_out;
          switcher_ram_save <= 1;
          @(posedge switcher_ram_save_ready) switcher_ram_save <= 0;
        end
      end
    end

    //read next process address
    j = 0;
    for (i = 0; i < 4; i++) begin
      switcher_ram_read_address <= physical_process_address + i;
      switcher_ram_read <= 1;
      @(posedge switcher_ram_read_ready) switcher_ram_read <= 0;
      j += switcher_ram_read_data_out * (256 ** i);
    end
    physical_process_address = j;
    if (`DEBUG_LEVEL == 2) //DEBUG info
      $display($time, " new process address ", physical_process_address);  //DEBUG info
    $display($time, "");  //DEBUG info
    $display($time, "");  //DEBUG info
    $display($time, "");  //DEBUG info
    $display($time, "");  //DEBUG info

    //read next pc
    z = 0;
    for (i = 0; i < 4; i++) begin
      switcher_ram_read_address <= physical_process_address + i + `ADDRESS_PC;
      switcher_ram_read <= 1;
      @(posedge switcher_ram_read_ready) switcher_ram_read <= 0;
      z += switcher_ram_read_data_out * (256 ** i);
    end
    if (z == 0) begin
      for (i = 0; i < 8; i++) begin
        old_reg_used[i] = 0;
      end
      for (i = 0; i < `REGISTER_NUM; i++) begin
        old_registers_memory[i] = 0;
      end
      start_pc = `ADDRESS_PROGRAM;
    end else begin
      //read next registers used and next registers
      for (i = 0; i < 8; i++) begin
        switcher_ram_read_address <= physical_process_address + i + `ADDRESS_REG_USED;
        switcher_ram_read <= 1;
        @(posedge switcher_ram_read_ready) switcher_ram_read <= 0;
        old_reg_used[i] = switcher_ram_read_data_out;

        for (j = 0; j < 8; j++) begin
          if ((old_reg_used[i] & (2 ** j)) != 0) begin
            switcher_ram_read_address <= physical_process_address + i * 8 + j + `ADDRESS_REG;
            switcher_ram_read <= 1;
            @(posedge switcher_ram_read_ready) switcher_ram_read <= 0;

            old_registers_memory[i*8+j] = switcher_ram_read_data_out;
          end else begin
            old_registers_memory[i*8+j] = 0;
          end
          switcher_register_save_address <= i * 8 + j;
          switcher_register_save_data_in = old_registers_memory[i*8+j];
          switcher_register_save <= 1;
          @(posedge switcher_register_save_ready) switcher_register_save <= 0;
        end
      end
      start_pc = z;
    end

    $display($time, " switcher end");  //DEBUG info
    switcher_exec_ready <= 1;
  end
endmodule

module ram2 (
    input ram_clk,
    input [`MAX_BITS_IN_ADDRESS:0] physical_process_address,
    input stage12_read,
    output reg stage12_read_ready,
    input stage12_read_with_mmu,
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
    output reg stage12_split_process_ready,
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
  reg mmu_split_process;
  wire mmu_split_process_ready;

  mmu mmu (
      .physical_process_address(physical_process_address),
      .logical_address(mmu_logical_address),
      .physical_address(mmu_physical_address),
      .mmu_get_physical_address(mmu_get_physical_address),
      .mmu_get_physical_address_ready(mmu_get_physical_address_ready),
      .mmu_split_process(mmu_split_process),
      .mmu_split_process_ready(mmu_split_process_ready),
      .mmu_split_process_start(stage12_split_process_start),
      .mmu_split_process_end(stage12_split_process_end)
  );

  integer i, j;

  always @(posedge stage12_split_process) begin
    stage12_split_process_ready <= 0;
    mmu_split_process <= 1;
    @(posedge mmu_split_process_ready) mmu_split_process <= 0;
    //setup pc in new process
    //update process chain - get next from exeisting process and save into new one and in existing process point to new one

    //    read next process address
    /*j = 0;
    for (i = 0; i < 4; i++) begin
      switcher_ram_read_address <= process_address + i;
      switcher_ram_read <= 1;
      @(posedge switcher_ram_read_ready) switcher_ram_read <= 0;
      j += switcher_ram_read_data_out * (256 ** i);
    end*/
    stage12_split_process_ready <= 1;
  end

  always @(posedge stage12_read or posedge stage3_read or posedge stage5_save or posedge switcher_save or posedge switcher_read) begin
    if (switcher_save) begin
      switcher_save_ready <= 0;
      ram_write_enable <= 1;
      ram_address = switcher_save_address;
      ram_data_in = switcher_save_data_in;
      if (`DEBUG_LEVEL == 2)  //DEBUG info
        $display($time, " saving RAM from switcher address ", switcher_save_address);  //DEBUG info
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
      if (`DEBUG_LEVEL == 2)  //DEBUG info
        $display(  //DEBUG info
            $time,  //DEBUG info
            " saving RAM from stage5 address ",  //DEBUG info
            stage5_save_address,  //DEBUG info
            " ",  //DEBUG info
            mmu_physical_address  //DEBUG info
        );  //DEBUG info
      @(posedge ram_clk) @(negedge ram_clk) ram_write_enable <= 0;
      stage5_save_ready <= 1;
    end
    if (switcher_read) begin
      switcher_read_ready <= 0;
      ram_write_enable <= 0;
      ram_address = switcher_read_address;
      @(posedge ram_clk)
      @(negedge ram_clk)
      if (`DEBUG_LEVEL == 2)  //DEBUG info
        $display(  //DEBUG info
            $time,  //DEBUG info
            " reading RAM from switcher address ",  //DEBUG info
            switcher_read_address,  //DEBUG info
            " value ",  //DEBUG info
            ram_data_out  //DEBUG info
        );  //DEBUG info
      switcher_read_data_out = ram_data_out;
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
      if (`DEBUG_LEVEL == 2)  //DEBUG info
        $display(  //DEBUG info
            $time,  //DEBUG info
            " reading RAM from stage3 address ",  //DEBUG info
            stage3_read_address,  //DEBUG info
            " ",  //DEBUG info
            mmu_physical_address,  //DEBUG info
            " value ",  //DEBUG info
            ram_data_out  //DEBUG info
        );  //DEBUG info
      stage3_read_data_out <= ram_data_out;
      stage3_read_ready <= 1;
    end
    if (stage12_read) begin
      stage12_read_ready <= 0;
      if (stage12_read_with_mmu) begin
        mmu_logical_address = stage12_read_address;
        mmu_get_physical_address <= 1;
        @(posedge mmu_get_physical_address_ready) mmu_get_physical_address <= 0;
        ram_address = mmu_physical_address;
      end else begin
        ram_address = stage12_read_address;
      end
      ram_write_enable <= 0;

      @(posedge ram_clk)
      @(negedge ram_clk)
      if (`DEBUG_LEVEL == 2)  //DEBUG info
        $display(  //DEBUG info
            $time,  //DEBUG info
            " reading RAM from stage12 address ",  //DEBUG info
            stage12_read_address,  //DEBUG info
            " value ",  //DEBUG info
            ram_data_out  //DEBUG info
        );  //DEBUG info
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

  reg [15:0] mmu_chain_memory[0:65535];  //values = next physical start point for task; last entry = 0
  reg [15:0] mmu_logical_pages_memory[0:65535];  //values = logical page assign to this physical page; 0 means page is empty (in existing processes, where first page is 0, we setup here value > 0 and ignore it)
  reg [15:0] index_start;

  //cache
  // reg[`MAX_BITS_IN_ADDRESS:0] last_mmu_process_address;
  //  reg[15:0] last_mmu_physical_page_index;
  //  reg[15:0] last_mmu_logical_page_index;

  string s;  //DEBUG info
  integer i, j, index, previndex, z, newindex, newindex2, newstartpoint;

  initial begin
    for (i = 0; i < 65536; i++) begin
      //value 0 means, that it's empty. in every process on first entry we setup something != 0 and ignore it (first process page is always from segment 0)
      mmu_logical_pages_memory[i] = 0;
    end
    index_start = 1;
    // for now we have two tasks in rom, remove when rom will be ready
    //  mmu_logical_pages_memory[0] = 0;
    //  mmu_logical_pages_memory[1] = 0;
    mmu_chain_memory[0] = 1;
    mmu_chain_memory[1] = 3;
    mmu_chain_memory[3] = 2;
    mmu_chain_memory[2] = 5;
    mmu_chain_memory[5] = 0;
    mmu_logical_pages_memory[0] = 255 * 255;
    mmu_logical_pages_memory[1] = 2;
    mmu_logical_pages_memory[2] = 4;
    mmu_logical_pages_memory[3] = 3;
    mmu_logical_pages_memory[5] = 1;
  end
  always @(posedge mmu_split_process) begin
    mmu_split_process_ready <= 0;

    s = " MMU ";  //DEBUG info
    for (i = 0; i < 10; i++) begin  //DEBUG info
      s = {  //DEBUG info
        s, $sformatf("%01x-%01x ", mmu_chain_memory[i], mmu_logical_pages_memory[i])  //DEBUG info
      };  //DEBUG info
    end  //DEBUG info
    if (`DEBUG_LEVEL == 2) $display($time, s, " ...");  //DEBUG info
    newindex  = physical_process_address / `MMU_PAGE_SIZE;  //start point for existing process //DEBUG info
    previndex = newindex;  //DEBUG info
    do begin  //DEBUG info
      if (`DEBUG_LEVEL == 2)  //DEBUG info
        $display(  //DEBUG info
            $time,  //DEBUG info
            " MMU old process chain ",  //DEBUG info
            mmu_chain_memory[newindex],  //DEBUG info
            " ",  //DEBUG info
            mmu_logical_pages_memory[newindex],  //DEBUG info
            " ",  //DEBUG info
            mmu_chain_memory[previndex],  //DEBUG info
            " ",  //DEBUG info
            mmu_logical_pages_memory[previndex],  //DEBUG info
            " ",  //DEBUG info
            newindex,  //DEBUG info
            " ",  //DEBUG info
            previndex  //DEBUG info
        );  //DEBUG info
      previndex = newindex;  //DEBUG info
      newindex  = mmu_chain_memory[previndex];  //DEBUG info
    end while (mmu_chain_memory[previndex] !== 0);  //DEBUG info

    newindex2 = 0;
    j = 255 * 255;  //some known value like 255*255 could be used for checking mmu validity
    for (i = mmu_split_process_start; i <= mmu_split_process_end; i++) begin
      newindex  = physical_process_address / `MMU_PAGE_SIZE;  //start point for existing process
      previndex = newindex;
      do begin
        if (mmu_logical_pages_memory[newindex] == i && newindex != physical_process_address / `MMU_PAGE_SIZE) begin
          if (`DEBUG_LEVEL == 2) //DEBUG info
            $display($time, " first page", i, " ", j, " ", newindex);  //DEBUG info
          mmu_chain_memory[previndex] = mmu_chain_memory[newindex];
          mmu_logical_pages_memory[newindex] = j;
          if (j == 0) newstartpoint = newindex;
          if (newindex2 != 0) begin
            mmu_chain_memory[newindex2] = newindex;
          end
          newindex2 = newindex;
          if (j == mmu_split_process_end) begin
            mmu_chain_memory[newindex] = 0;
          end
          if (j == 255 * 255) begin
            j = 1;
          end else begin
            j++;
          end
          s = " MMU ";  //DEBUG info
          for (z = 0; z < 10; z++) begin  //DEBUG info
            s = {  //DEBUG info
              s,  //DEBUG info
              $sformatf(  //DEBUG info
                  "%01x-%01x ", mmu_chain_memory[z], mmu_logical_pages_memory[z]  //DEBUG info
              )  //DEBUG info
            };  //DEBUG info
          end  //DEBUG info
          if (`DEBUG_LEVEL == 2) $display($time, s, " ...");  //DEBUG info
        end
        previndex = newindex;
        newindex  = mmu_chain_memory[previndex];
      end while (mmu_chain_memory[previndex] !== 0);
    end

    s = " MMU ";  //DEBUG info
    for (i = 0; i < 10; i++) begin  //DEBUG info
      s = {  //DEBUG info
        s, $sformatf("%01x-%01x ", mmu_chain_memory[i], mmu_logical_pages_memory[i])  //DEBUG info
      };  //DEBUG info
    end  //DEBUG info
    $display($time, s, " ...");  //DEBUG info

    newindex  = physical_process_address / `MMU_PAGE_SIZE;  //start point for existing process //DEBUG info
    previndex = newindex;  //DEBUG info
    do begin  //DEBUG info
      if (`DEBUG_LEVEL == 2)  //DEBUG info
        $display(  //DEBUG info
            $time,  //DEBUG info
            " MMU old process chain ",  //DEBUG info
            mmu_chain_memory[newindex],  //DEBUG info
            " ",  //DEBUG info
            mmu_logical_pages_memory[newindex],  //DEBUG info
            " ",  //DEBUG info
            mmu_chain_memory[previndex],  //DEBUG info
            " ",  //DEBUG info
            mmu_logical_pages_memory[previndex],  //DEBUG info
            " ",  //DEBUG info
            newindex,  //DEBUG info
            " ",  //DEBUG info
            previndex  //DEBUG info
        );  //DEBUG info
      previndex = newindex;  //DEBUG info
      newindex  = mmu_chain_memory[previndex];  //DEBUG info
    end while (mmu_chain_memory[previndex] !== 0);  //DEBUG info

    mmu_split_process_ready <= 1;
  end
  //todo: caching last value
  always @(posedge mmu_get_physical_address) begin
    mmu_get_physical_address_ready <= 0;
    index = physical_process_address / `MMU_PAGE_SIZE;
    i = logical_address / `MMU_PAGE_SIZE;
    //  if (`DEBUG_LEVEL == 2)  //DEBUG info
    //  $display(  //DEBUG info
    //     $time,  //DEBUG info
    //    " MMU  process start point ",  //DEBUG info
    //   physical_process_address,  //DEBUG info
    //    " process logical page ",  //DEBUG info
    //    index,  //DEBUG info
    //    " logical address ",  //DEBUG info
    //    logical_address,  //DEBUG info
    //    " logical address page ",  //DEBUG info
    //    i  //DEBUG info
    //);  //DEBUG info

    if (i != 0) begin
      while (mmu_chain_memory[index] !== 0 && mmu_logical_pages_memory[index] != i) begin
        index = mmu_chain_memory[index];
      end
      $display($time, " MMU index after searching  ", index);  //DEBUG info
      if (mmu_logical_pages_memory[index] != i) begin
        while (mmu_logical_pages_memory[index_start] !== 0) begin
          index_start++;
        end
        //fixme: no free memory situation
        mmu_chain_memory[index] = index_start;
        index = index_start;
        $display($time, " MMU assigning new page ", index);  //DEBUG info
        mmu_logical_pages_memory[index] = i;
      end
    end
    // $display($time, " MMU calculated index  ", index);  //DEBUG info

    physical_address = index * `MMU_PAGE_SIZE + logical_address % `MMU_PAGE_SIZE;
    if (`DEBUG_LEVEL == 2)  //DEBUG info
      $display(  //DEBUG info
          $time,  //DEBUG info
          " MMU  process start ",  //DEBUG info
          physical_process_address,  //DEBUG info
          " (logical page ",  //DEBUG info
          index,  //DEBUG info
          ") logical address ",  //DEBUG info
          logical_address,  //DEBUG info
          " (page ",  //DEBUG info
          i,  //DEBUG info
          ") MMU physical address ",  //DEBUG info
          physical_address  //DEBUG info
      );  //DEBUG info

    s = " MMU ";  //DEBUG info
    for (i = 0; i < 10; i++) begin  //DEBUG info
      s = {  //DEBUG info
        s, $sformatf("%01x-%01x ", mmu_chain_memory[i], mmu_logical_pages_memory[i])  //DEBUG info
      };  //DEBUG info
    end  //DEBUG info
    if (`DEBUG_LEVEL == 2) $display($time, s, " ...");  //DEBUG info

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
    input rst,
    input [`MAX_BITS_IN_ADDRESS:0] physical_process_address,
    input dump_reg,  //DEBUG info
    output reg dump_reg_ready,  //DEBUG info
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
    output reg [`REGISTER_NUM-1:0] registers_used
);

  reg [7:0] registers_memory[`REGISTER_NUM-1:0];

  integer i;
  string s2;  //DEBUG info

  always @(rst) begin
    for (i = 0; i < `REGISTER_NUM; i++) begin
      registers_memory[i] = 0;
    end
  end
  always @(physical_process_address) begin
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
  always @(posedge dump_reg) begin  //DEBUG info
    dump_reg_ready <= 0;  //DEBUG info
    s2 = " reg ";  //DEBUG info
    for (i = 0; i < 20; i++) begin  //DEBUG info
      s2 = {s2, $sformatf("%02x ", registers_memory[i])};  //DEBUG info
    end  //DEBUG info
    $display($time, s2, " ...");  //DEBUG info
    s2 = " reg used ";  //DEBUG info
    for (i = 0; i < 20; i++) begin  //DEBUG info
      s2 = {s2, $sformatf("%01x ", registers_used[i])};  //DEBUG info
    end  //DEBUG info
    if (`DEBUG_LEVEL == 2) $display($time, s2, " ...");  //DEBUG info
    dump_reg_ready <= 1;  //DEBUG info
  end  //DEBUG info
endmodule




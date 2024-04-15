//process instruction codes
`define OPCODE_LOAD_FROM_RAM 1 //load from memory with specified address, params: target register number, length, source memory address
`define OPCODE_JUMP_MINUS 2 //param: how many instructions
`define OPCODE_WRITE_TO_RAM 3 //save to memory with specified address, params: source register number, length, target memory address
`define OPCODE_ADD8 4 //add register A and B and save to register "out", 8-bit processing, params: register A and B start (now the same, later other), out register start, how many 8-bit elements
`define OPCODE_JUMP_PLUS 5 //param: how many instructions
`define OPCODE_ADD_NUM8 6 //add numeric value to registers, params: register A start/number (now the same, later other), out register start, how many 8-bit elements
`define OPCODE_READ_FROM_RAM 7 //load from memory from address in register to register, params: target register number, length, register with source address
`define OPCODE_SAVE_TO_RAM 8 //save to memory with address in register, params: source register number, length, register with target address
`define OPCODE_SET8 9 //set registers to 0 (now, in the future any value), params: register start num, how many 8-bit elements
`define OPCODE_PROC 10 //new process, params: start, end memory segment from existing process
`define OPCODE_PROC_END 11//remove current process
`define OPCODE_PROC_SUSPEND 12 //code for test instruction for suspending task //DEBUG info
`define OPCODE_PROC_RESUME 14 //code for test instruction for resuming task //DEBUG info
`define OPCODE_REG_INT 15
`define OPCODE_INT 16
`define OPCODE_INT_RET 17

//invalidate registers
//invalidate registers after x instructions - delete all in cycles before switcher

//alu operations
`define OPER_ADD 1
`define OPER_ADDNUM 2
`define OPER_SETNUM 3

//offsets for process info
`define ADDRESS_NEXT_PROCESS 0
`define ADDRESS_PC 4
`define ADDRESS_REG_USED 8
`define ADDRESS_REG 20
`define ADDRESS_PROGRAM `REGISTER_NUM+`ADDRESS_REG

`define REGISTER_NUM 64 //number of registers in bytes, for example 64 bytes = 512 bits like in AVX-512
`define MAX_BITS_IN_REGISTER_NUM 6 //64 registers = 2^6
`define OP_PER_TASK 4 // opcodes per task before switching
`define MAX_BITS_IN_ADDRESS 31 //32-bit addresses
`define MMU_PAGE_SIZE 172 //size of every MMU page (in the future important, if this can be divided by 4)

`define DEBUG_LEVEL 1 //higher=more info, 1 - simple, 2 - more detailed, 3 - with MMU info //DEBUG info

module cpu (
    input rst,
    input sim_end,  //DEBUG info
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

  wire mmu_split_process;
  wire mmu_split_process_ready;
  wire [`MAX_BITS_IN_ADDRESS:0] mmu_split_process_start;
  wire [`MAX_BITS_IN_ADDRESS:0] mmu_split_process_end;
  wire [`MAX_BITS_IN_ADDRESS:0] mmu_split_new_process_address;

  reg mmu_remove_process;
  wire mmu_remove_process_ready;

  ram2 ram2 (
      .ram_clk(ram_clk),
      .sim_end(sim_end),  //DEBUG info
      .physical_process_address(physical_process_address),
      .mmu_split_process(mmu_split_process),
      .mmu_split_process_ready(mmu_split_process_ready),
      .mmu_split_process_start(mmu_split_process_start),
      .mmu_split_process_end(mmu_split_process_end),
      .mmu_split_new_process_address(mmu_split_new_process_address),
      .mmu_remove_process(mmu_remove_process),
      .mmu_remove_process_ready(mmu_remove_process_ready),
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

  //task switcher  
  wire [`MAX_BITS_IN_ADDRESS:0] start_pc_after_task_switch;
  wire [`MAX_BITS_IN_ADDRESS:0] pc;
  wire [`MAX_BITS_IN_ADDRESS:0] physical_process_address;
  wire [`REGISTER_NUM-1:0] registers_used;
  reg switcher_exec;
  wire switcher_exec_ready;
  reg switcher_with_removal;
  wire switcher_split_process;
  wire switcher_split_process_ready;

  wire switcher_setup_int;
  wire switcher_setup_int_ready;
  wire [7:0] switcher_setup_int_number;

  wire switcher_execute_return_int;
  wire switcher_execute_return_int_ready;
  wire [7:0] switcher_execute_return_int_number;

  reg [4:0] started;
  reg [4:0] completed;

  switcher switcher (
      .rst(rst),
      .start_pc_after_task_switch(start_pc_after_task_switch),
      .pc(pc),
      .physical_process_address(physical_process_address),
      .registers_used(registers_used),
      .switcher_exec(switcher_exec),
      .switcher_exec_ready(switcher_exec_ready),
      .switcher_with_removal(switcher_with_removal),
      .switcher_split_process(switcher_split_process),
      .switcher_split_process_ready(switcher_split_process_ready),
      .switcher_split_new_process_address(mmu_split_new_process_address),
      .switcher_setup_int(witcher_setup_int),
      .switcher_setup_int_ready(switcher_setup_int_ready),
      .switcher_setup_int_number(switcher_setup_int_number),
      .switcher_execute_return_int(switcher_execute_return_int),
      .switcher_execute_return_int_ready(switcher_execute_return_int_ready),
      .switcher_execute_return_int_number(switcher_execute_return_int_number),
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
  reg  stage12_exec;
  wire stage12_exec_ready;

  wire complete_instruction;
  wire mmu_remove_should_exec;

  stage12 stage12 (
      .rst(rst),
      .stage12_exec(stage12_exec),
      .stage12_exec_ready(stage12_exec_ready),
      .complete_instruction(complete_instruction),
      .pc(pc),
      .start_pc_after_task_switch(start_pc_after_task_switch),
      .physical_process_address(physical_process_address),
      .switcher_split_process(switcher_split_process),
      .switcher_split_process_ready(switcher_split_process_ready),
      .switcher_setup_int(witcher_setup_int),
      .switcher_setup_int_ready(switcher_setup_int_ready),
      .switcher_setup_int_number(switcher_setup_int_number),
      .switcher_execute_return_int(switcher_execute_return_int),
      .switcher_execute_return_int_ready(switcher_execute_return_int_ready),
      .switcher_execute_return_int_number(switcher_execute_return_int_number),
      .mmu_split_process(mmu_split_process),
      .mmu_split_process_ready(mmu_split_process_ready),
      .mmu_split_process_start(mmu_split_process_start),
      .mmu_split_process_end(mmu_split_process_end),
      .mmu_remove_should_exec(mmu_remove_should_exec),
      .stage3_exec(stage3_exec),
      .stage3_exec_ready(stage3_exec_ready),
      .stage3_source_ram_address(stage3_source_ram_address),
      .stage3_target_register_start(stage3_target_register_start),
      .stage3_target_register_length(stage3_target_register_length),
      .stage4_exec(stage4_exec),
      .stage4_exec_ready(stage4_exec_ready),
      .stage4_oper(stage4_oper),
      .stage4_register_A_start(stage4_register_A_start),
      .stage4_register_B_start(stage4_register_B_start),
      .stage4_value_B(stage4_value_B),
      .stage4_register_out_start(stage4_register_out_start),
      .stage4_register_length(stage4_register_length),
      .stage5_exec(stage5_exec),
      .stage5_exec_ready(stage5_exec_ready),
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
  wire stage3_exec;
  wire stage3_exec_ready;

  wire [`MAX_BITS_IN_ADDRESS:0] stage3_source_ram_address;  //address, which we should read
  wire [`MAX_BITS_IN_REGISTER_NUM:0] stage3_target_register_start;
  wire [`MAX_BITS_IN_REGISTER_NUM:0] stage3_target_register_length;

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
  wire stage4_exec;
  wire stage4_exec_ready;

  wire [15:0] stage4_oper;
  wire [`MAX_BITS_IN_REGISTER_NUM:0] stage4_register_A_start;
  wire [`MAX_BITS_IN_REGISTER_NUM:0] stage4_register_B_start;
  wire [15:0] stage4_value_B;
  wire [`MAX_BITS_IN_REGISTER_NUM:0] stage4_register_out_start;
  wire [`MAX_BITS_IN_REGISTER_NUM:0] stage4_register_length;

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
  wire stage5_exec;
  wire stage5_exec_ready;

  wire [`MAX_BITS_IN_REGISTER_NUM:0] stage5_source_register_start;
  wire [`MAX_BITS_IN_REGISTER_NUM:0] stage5_source_register_length;
  wire [`MAX_BITS_IN_ADDRESS:0] stage5_target_ram_address;

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
    if (`DEBUG_LEVEL > 1) $display($time, " reset1");  //DEBUG info
    switcher_exec = 0;
    started = 0;
    completed = 0;
  end
  always @(negedge stage12_exec) begin
    if (`DEBUG_LEVEL > 1) $display($time, " negedge stage12exec");  //DEBUG info
    stage12_exec = 1;  //make it so
    started++;
  end
  always @(posedge stage12_exec_ready) begin
    if (`DEBUG_LEVEL > 1) $display($time, " posedge stage12execready");  //DEBUG info
    if (complete_instruction) begin
      completed++;
    end
  end
  always @(posedge stage3_exec_ready) begin
    completed++;
  end
  always @(posedge stage4_exec_ready) begin
    completed++;
  end
  always @(posedge stage5_exec_ready) begin
    completed++;
  end
  always @(completed) begin
    if (`DEBUG_LEVEL > 1) //DEBUG info
      $display($time, " completed=", completed, " started=", started);  //DEBUG info
    if (mmu_remove_should_exec && started == completed) begin
      mmu_remove_process = 1;
    end else if (started == `OP_PER_TASK && started == completed) begin
      dump_reg <= 1;  //DEBUG info
      @(posedge dump_reg_ready) dump_reg <= 0;  //DEBUG info
      switcher_with_removal = 0;
      switcher_exec = 1;  //engage
    end else if (started < `OP_PER_TASK) begin
      stage12_exec = 0;
    end
  end
  always @(posedge mmu_remove_process_ready) begin
    if (`DEBUG_LEVEL > 1) $display($time, " posedge mmuremoveexecready");  //DEBUG info
    switcher_with_removal = 1;
    switcher_exec = 1;  //punch it
  end
  always @(posedge switcher_exec_ready) begin
    if (`DEBUG_LEVEL > 1) $display($time, " posedge switcherexecready");  //DEBUG info
    dump_reg <= 1;  //DEBUG info
    @(posedge dump_reg_ready) dump_reg <= 0;  //DEBUG info
    switcher_exec = 0;
    started = 0;
    completed = 0;
    stage12_exec = 0;
  end
endmodule

module stage12 (
    input rst,

    input [`MAX_BITS_IN_ADDRESS:0] start_pc_after_task_switch,
    input [`MAX_BITS_IN_ADDRESS:0] physical_process_address,
    output reg [`MAX_BITS_IN_ADDRESS:0] pc,

    input stage12_exec,
    output reg stage12_exec_ready,
    output reg complete_instruction,

    output reg mmu_split_process,
    input mmu_split_process_ready,
    output reg [`MAX_BITS_IN_ADDRESS:0] mmu_split_process_start,
    output reg [`MAX_BITS_IN_ADDRESS:0] mmu_split_process_end,
    output reg switcher_split_process,
    input switcher_split_process_ready,

    output reg mmu_remove_should_exec,

    output reg switcher_setup_int,
    input switcher_setup_int_ready,
    output reg [7:0] switcher_setup_int_number,

    output reg switcher_execute_return_int,
    input switcher_execute_return_int_ready,
    output reg [7:0] switcher_execute_return_int_number,

    output reg stage3_exec,
    input stage3_exec_ready,
    output reg [`MAX_BITS_IN_ADDRESS:0] stage3_source_ram_address,
    output reg [`MAX_BITS_IN_REGISTER_NUM:0] stage3_target_register_start,
    output reg [`MAX_BITS_IN_REGISTER_NUM:0] stage3_target_register_length,

    output reg stage4_exec,
    input stage4_exec_ready,
    output reg [15:0] stage4_oper,
    output reg [`MAX_BITS_IN_REGISTER_NUM:0] stage4_register_A_start,
    output reg [`MAX_BITS_IN_REGISTER_NUM:0] stage4_register_B_start,
    output reg [15:0] stage4_value_B,
    output reg [`MAX_BITS_IN_REGISTER_NUM:0] stage4_register_out_start,
    output reg [`MAX_BITS_IN_REGISTER_NUM:0] stage4_register_length,

    output reg stage5_exec,
    input stage5_exec_ready,
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

  always @(rst) begin
    stage3_exec = 0;
    stage4_exec = 0;
    stage5_exec = 0;
  end

  always @(physical_process_address) begin
    pc = start_pc_after_task_switch;
    if (`DEBUG_LEVEL > 1) $display($time, " new pc ", start_pc_after_task_switch);  //DEBUG info
  end

  always @(posedge stage3_exec_ready) begin
    if (`DEBUG_LEVEL > 1) $display($time, " posedge stage3execready");  //DEBUG info
    stage3_exec = 0;
  end
  always @(posedge stage4_exec_ready) begin
    if (`DEBUG_LEVEL > 1) $display($time, " posedge stage4execready");  //DEBUG info
    stage4_exec = 0;
  end
  always @(posedge stage5_exec_ready) begin
    if (`DEBUG_LEVEL > 1) $display($time, " posedge stage5execready");  //DEBUG info
    stage5_exec = 0;
  end

  always @(posedge stage12_exec) begin
    stage12_exec_ready <= 0;
    mmu_remove_should_exec <= 0;
    complete_instruction = 1;
    if (`DEBUG_LEVEL > 1) $display($time, " executing pc ", pc);  //DEBUG info

    stage12_ram_read_address <= pc;
    stage12_ram_read <= 1;
    @(posedge stage12_ram_read_ready) stage12_ram_read <= 0;
    instruction[0] = stage12_ram_read_data_out;

    //TODO: if ram pages size can be divided by 4, we could ask mmu for memory page and just increase address
    //in this and other readings. Currently we always ask MMU for calculation
    stage12_ram_read_address <= pc + 1;
    stage12_ram_read <= 1;
    @(posedge stage12_ram_read_ready) stage12_ram_read <= 0;
    instruction[1] = stage12_ram_read_data_out;

    if (instruction[0] == `OPCODE_JUMP_MINUS) begin
      $display($time, instruction[0], " ",  //DEBUG info
               instruction[1], "   x   x   JUMPMINUS");  //DEBUG info
      pc -= instruction[1] * 4;
    end else if (instruction[0] == `OPCODE_JUMP_PLUS) begin
      $display($time, instruction[0], " ",  //DEBUG info
               instruction[1], "   x   x   JUMPPLUS");  //DEBUG info
      pc += instruction[1] * 4;
    end else if (instruction[0] == `OPCODE_PROC_END) begin
      //fixme: read only one byte instead of two
      $display($time, instruction[0], " ",  //DEBUG info
               "   x    x   x   PROCEND");  //DEBUG info
      mmu_remove_should_exec <= 1;
    end else begin
      stage12_ram_read_address <= pc + 2;
      stage12_ram_read <= 1;
      @(posedge stage12_ram_read_ready) stage12_ram_read <= 0;
      instruction[2] = stage12_ram_read_data_out;

      stage12_ram_read_address <= pc + 3;
      stage12_ram_read <= 1;
      @(posedge stage12_ram_read_ready) stage12_ram_read <= 0;
      instruction[3] = stage12_ram_read_data_out;

      if (instruction[0] == `OPCODE_LOAD_FROM_RAM) begin
        if (stage3_exec) @(stage3_exec_ready) stage3_exec = 0;
        stage3_target_register_start = instruction[1];
        stage3_target_register_length = instruction[2];
        stage3_source_ram_address = instruction[3];
        $display($time, instruction[0], " ", instruction[1], " ", instruction[2], " ",  //DEBUG info
                 instruction[3], "   LOADFROMRAM ", stage3_target_register_length  //DEBUG info
                 , " bytes from RAM address ", stage3_source_ram_address,  //DEBUG info
                 "+ and save to register "  //DEBUG info
                 , stage3_target_register_start, "+");  //DEBUG info
        complete_instruction = 0;
        stage3_exec = 1;
      end else if (instruction[0] == `OPCODE_READ_FROM_RAM) begin
        stage12_register_read_address <= instruction[3];
        stage12_register_read <= 1;
        @(posedge stage12_register_read_ready) stage12_register_read <= 0;

        if (stage3_exec) @(stage3_exec_ready) stage3_exec = 0;
        stage3_target_register_start = instruction[1];
        stage3_target_register_length = instruction[2];
        stage3_source_ram_address = stage12_register_read_data_out;

        $display($time, instruction[0], " ", instruction[1], " ", instruction[2], " ",  //DEBUG info
                 instruction[3], "   READFROMRAM ", stage3_target_register_length  //DEBUG info
                 , " bytes from RAM address ", stage3_source_ram_address,  //DEBUG info
                 "+ and save to register "  //DEBUG info
                 , stage3_target_register_start, "+");  //DEBUG info
        complete_instruction = 0;
        stage3_exec = 1;
      end else if (instruction[0] == `OPCODE_WRITE_TO_RAM) begin
        if (stage5_exec) @(stage5_exec_ready) stage5_exec = 0;
        stage5_source_register_start = instruction[1];
        stage5_source_register_length = instruction[2];
        stage5_target_ram_address = instruction[3];
        $display($time, instruction[0], " ", instruction[1], " ", instruction[2], " ",  //DEBUG info
                 instruction[3], "   WRITETORAM ", stage5_source_register_length,  //DEBUG info
                 " bytes from register ", stage5_source_register_start,  //DEBUG info
                 "+ and save to RAM address ", stage5_target_ram_address, "+");  //DEBUG info
        complete_instruction = 0;
        stage5_exec = 1;
      end else if (instruction[0] == `OPCODE_SAVE_TO_RAM) begin
        stage12_register_read_address <= instruction[3];
        stage12_register_read <= 1;
        @(posedge stage12_register_read_ready) stage12_register_read <= 0;

        if (stage5_exec) @(stage5_exec_ready) stage5_exec = 0;
        stage5_source_register_start = instruction[1];
        stage5_source_register_length = instruction[2];
        stage5_target_ram_address = stage12_register_read_data_out;
        $display($time, instruction[0], " ", instruction[1], " ", instruction[2], " ",  //DEBUG info
                 instruction[3], "   SAVETORAM ", stage5_source_register_length,  //DEBUG info
                 " bytes from register ", stage5_source_register_start,  //DEBUG info
                 "+ and save to RAM address ", stage5_target_ram_address, "+");  //DEBUG info
        complete_instruction = 0;
        stage5_exec = 1;
      end else if (instruction[0] == `OPCODE_ADD8) begin
        if (stage4_exec) @(stage4_exec_ready) stage4_exec = 0;
        stage4_oper = `OPER_ADD;
        stage4_register_A_start = instruction[1];
        stage4_register_B_start = instruction[1];
        stage4_register_out_start = instruction[2];
        stage4_register_length = instruction[3];
        $display($time, instruction[0], " ", instruction[1], " ", instruction[2], " ",  //DEBUG info
                 instruction[3], "   ADD8 add register ", stage4_register_A_start,  //DEBUG info
                 "+ to register ", stage4_register_B_start, " and save to register ",  //DEBUG info
                 stage4_register_out_start, "+, len ", stage4_register_length);  //DEBUG info
        complete_instruction = 0;
        stage4_exec = 1;
      end else if (instruction[0] == `OPCODE_ADD_NUM8) begin
        if (stage4_exec) @(stage4_exec_ready) stage4_exec = 0;
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
        complete_instruction = 0;
        stage4_exec = 1;
      end else if (instruction[0] == `OPCODE_SET8) begin
        if (stage4_exec) @(stage4_exec_ready) stage4_exec = 0;
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
        complete_instruction = 0;
        stage4_exec = 1;
      end else if (instruction[0] == `OPCODE_PROC) begin
        $display(  //DEBUG info
            $time, instruction[0], " ", instruction[1], " ", instruction[2], " ",  //DEBUG info
            instruction[3],  //DEBUG info
            "   PROC create new process from current process, take memory segments ",  //DEBUG info
            instruction[1], " to ", instruction[2]);  //DEBUG info
        mmu_split_process_start = instruction[1];
        mmu_split_process_end   = instruction[2];
        //potentially after mmu update we could do the rest in parallel
        mmu_split_process <= 1;
        @(posedge mmu_split_process_ready) mmu_split_process <= 0;
        //update task list, etc.
        switcher_split_process <= 1;
        @(posedge switcher_split_process_ready) switcher_split_process <= 0;
      end else if (instruction[0] == `OPCODE_PROC_SUSPEND) begin  //DEBUG info
        $display(  //DEBUG info
            $time, instruction[0], " ", instruction[1], " ", instruction[2], " ",  //DEBUG info
            instruction[3],  //DEBUG info
            "   PROC_SUSPEND suspend this process");  //DEBUG info  
      end else if (instruction[0] == `OPCODE_PROC_RESUME) begin  //DEBUG info
        $display(  //DEBUG info
            $time, instruction[0], " ", instruction[1], " ", instruction[2], " ",  //DEBUG info
            instruction[3],  //DEBUG info
            "   PROC_RESUME resume process");  //DEBUG info  
      end else if (instruction[0] == `OPCODE_REG_INT) begin
        $display(  //DEBUG info
            $time, instruction[0], " ", instruction[1], " ", instruction[2], " ",  //DEBUG info
            instruction[3],  //DEBUG info
            "   REGINT register interrupt ", instruction[1]);  //DEBUG info
        switcher_setup_int_number = instruction[1];
        switcher_setup_int <= 1;
        @(posedge switcher_setup_int_ready) switcher_setup_int <= 0;
      end else if (instruction[0] == `OPCODE_INT) begin
        $display(  //DEBUG info
            $time, instruction[0], " ", instruction[1], " ", instruction[2], " ",  //DEBUG info
            instruction[3],  //DEBUG info
            "   INT interrupt ", instruction[1]);  //DEBUG info
        switcher_execute_return_int_number = instruction[1];
        switcher_execute_return_int <= 1;
        @(posedge switcher_execute_return_int_ready) switcher_execute_return_int <= 0;
      end else if (instruction[0] == `OPCODE_INT_RET) begin
        $display(  //DEBUG info
            $time, instruction[0], " ", instruction[1], " ", instruction[2], " ",  //DEBUG info
            instruction[3],  //DEBUG info
            "   INTRET return from interrupt ", instruction[1]);  //DEBUG info            
        switcher_execute_return_int_number = instruction[1];
        switcher_execute_return_int <= 1;
        @(posedge switcher_execute_return_int_ready) switcher_execute_return_int <= 0;
      end else if (  instruction[0] !== `OPCODE_JUMP_MINUS && instruction[0] !== `OPCODE_JUMP_PLUS && instruction[0] !== `OPCODE_PROC_END) begin
        $display(  //DEBUG info
            $time, instruction[0], " ", instruction[1], " ", instruction[2], " ",  //DEBUG info
            instruction[3],  //DEBUG info
            "   unknown PCCODE");  //DEBUG info
      end
      pc += 4;
    end
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
    if (`DEBUG_LEVEL > 1) $display($time, " stage 4 starting ", stage4_value_B);  //DEBUG info
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
    input rst,
    input [`MAX_BITS_IN_ADDRESS:0] pc,
    output reg [`MAX_BITS_IN_ADDRESS:0] start_pc_after_task_switch,
    output reg [`MAX_BITS_IN_ADDRESS:0] physical_process_address,

    input switcher_exec,
    input switcher_with_removal,
    output reg switcher_exec_ready,

    input switcher_split_process,
    output reg switcher_split_process_ready,
    input [`MAX_BITS_IN_ADDRESS:0] switcher_split_new_process_address,
    input [`REGISTER_NUM-1:0] registers_used,

    input switcher_setup_int,
    output reg switcher_setup_int_ready,
    input [7:0] switcher_setup_int_number,

    input switcher_execute_return_int,
    output reg switcher_execute_return_int_ready,
    input [7:0] switcher_execute_return_int_number,

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

  integer i, j, z, p, temp_new_process_address;
  string s2;  //DEBUG info
  reg [7:0] temp[8:0];

  //cache
  reg [7:0] old_reg_used[8:0];
  reg [7:0] old_registers_memory[`REGISTER_NUM-1:0];
  reg [`MAX_BITS_IN_ADDRESS:0] old_physical_process_address;

  reg [7:0] active_task_num;  //we could replace it with boolean sying, if have >1 active tasks

  reg [7:0] suspended_task_address;
  reg suspended_task_available;

  reg [`MAX_BITS_IN_ADDRESS:0] int_process_address[7:0];

  reg dump_process_state;
  reg dump_process_state_ready;
  reg read_new_process_state;
  reg read_new_process_state_ready;

  reg remove_process_from_chain;
  reg remove_process_from_chain_ready;

  `define SWITCHER_RAM_SAVE(ADDRESS, VALUE) \
   switcher_ram_save_address <= ADDRESS; \
   switcher_ram_save_data_in <= VALUE; \
   switcher_ram_save <= 1; \
   @(posedge switcher_ram_save_ready) switcher_ram_save <= 0;

  always @(posedge dump_process_state) begin
    dump_process_state_ready <= 0;
    //dump pc
    if (`DEBUG_LEVEL > 1) $display($time, " dump pc");  //DEBUG info
    temp[0] = pc[0]+pc[1]*2+pc[2]*4+pc[3]*8+pc[4]*16+pc[5]*32+pc[6]*64+pc[7]*128;
    temp[1] = pc[8]+pc[9]*2+pc[10]*4+pc[11]*8+pc[12]*16+pc[13]*32+pc[14]*64+pc[15]*128;
    for (i = 0; i < 2; i++) begin
      //should I go this way?
      `SWITCHER_RAM_SAVE(physical_process_address + `ADDRESS_PC + i, temp[i]);
    end

    //dump registers used
    if (`DEBUG_LEVEL > 1) $display($time, " dump reg used");  //DEBUG info
    temp[0] = registers_used[0]*2+registers_used[1]*4+registers_used[2]*8+registers_used[3]*16+registers_used[4]*32+registers_used[5]*64+registers_used[6]*128;
    temp[1] = registers_used[7]*2+registers_used[8]*4+registers_used[9]*8+registers_used[10]*16+registers_used[11]*32+registers_used[12]*64+registers_used[13]*128;
    temp[2] = registers_used[14]*2+registers_used[15]*4+registers_used[16]*8+registers_used[17]*16+registers_used[18]*32+registers_used[19]*64+registers_used[20]*128;
    temp[3] = registers_used[21]*2+registers_used[22]*4+registers_used[23]*8+registers_used[24]*16+registers_used[25]*32+registers_used[26]*64+registers_used[27]*128;
    temp[4] = registers_used[28]*2+registers_used[29]*4+registers_used[30]*8+registers_used[31]*16+registers_used[32]*32+registers_used[33]*64+registers_used[34]*128;
    temp[5] = registers_used[35]*2+registers_used[36]*4+registers_used[37]*8+registers_used[38]*16+registers_used[39]*32+registers_used[40]*64+registers_used[41]*128;
    temp[6] = registers_used[42]*2+registers_used[43]*4+registers_used[44]*8+registers_used[45]*16+registers_used[46]*32+registers_used[47]*64+registers_used[48]*128;
    temp[7] = registers_used[49]*2+registers_used[50]*4+registers_used[51]*8+registers_used[52]*16+registers_used[53]*32+registers_used[54]*64+registers_used[55]*128;
    temp[8] = registers_used[56]+registers_used[57]*2+registers_used[58]*4+registers_used[59]*8+registers_used[60]*16+registers_used[61]*32+registers_used[62]*64+registers_used[63]*128;

    s2 = " reg used ";  //DEBUG info
    for (i = 0; i < 9; i++) begin  //DEBUG info
      s2 = {s2, $sformatf("%01x ", temp[i])};  //DEBUG info
    end  //DEBUG info
    if (`DEBUG_LEVEL > 1) $display($time, s2);  //DEBUG info

    for (i = 7; i >= 0; i--) begin
      if (temp[i+1] !== 0) begin
        temp[i] += 1;
      end
      if (old_reg_used[i] != temp[i]) begin
        switcher_ram_save_address <= physical_process_address + `ADDRESS_REG_USED + i;
        switcher_ram_save_data_in <= temp[i];
        switcher_ram_save <= 1;
        @(posedge switcher_ram_save_ready) switcher_ram_save <= 0;
      end
    end

    //dump registers
    if (`DEBUG_LEVEL > 1) $display($time, " dump reg");  //DEBUG info

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
    dump_process_state_ready <= 1;
  end

  always @(posedge read_new_process_state) begin
    read_new_process_state_ready <= 0;
    //read next pc
    z = 0;
    for (i = 0; i < 4; i++) begin
      switcher_ram_read_address <= temp_new_process_address + i + `ADDRESS_PC;
      switcher_ram_read <= 1;
      @(posedge switcher_ram_read_ready) switcher_ram_read <= 0;
      z += switcher_ram_read_data_out * (256 ** i);
    end
    for (i = 0; i < 9; i++) begin
      old_reg_used[i] = 0;
    end
    if (z == 0) begin
      if (`DEBUG_LEVEL > 1) $display($time, " default registers");  //DEBUG info

      for (i = 0; i < `REGISTER_NUM; i++) begin
        old_registers_memory[i] = 0;

        switcher_register_save_address <= i;
        switcher_register_save_data_in = 0;
        switcher_register_save <= 1;
        @(posedge switcher_register_save_ready) switcher_register_save <= 0;
      end
      start_pc_after_task_switch = `ADDRESS_PROGRAM;  //this is later recalculated with mmu
    end else begin
      if (`DEBUG_LEVEL > 1) $display($time, " non default registers");  //DEBUG info
      //read next registers used and next registers
      i = 0;
      do begin
        switcher_ram_read_address <= temp_new_process_address + i + `ADDRESS_REG_USED;
        switcher_ram_read <= 1;
        @(posedge switcher_ram_read_ready) switcher_ram_read <= 0;
        old_reg_used[i] = switcher_ram_read_data_out;
        i++;
      end while ((old_reg_used[i-1] & (2 ** 0)) !== 0 || i == 9);
      i = 0;
      j = 1;
      for (p = 0; p < `REGISTER_NUM; p++) begin
        if ((old_reg_used[i] & (2 ** j)) != 0) begin
          switcher_ram_read_address <= temp_new_process_address + p + `ADDRESS_REG;
          switcher_ram_read <= 1;
          @(posedge switcher_ram_read_ready) switcher_ram_read <= 0;

          old_registers_memory[p] = switcher_ram_read_data_out;
        end else begin
          old_registers_memory[p] = 0;
        end
        switcher_register_save_address <= p;
        switcher_register_save_data_in = old_registers_memory[p];
        switcher_register_save <= 1;
        @(posedge switcher_register_save_ready) switcher_register_save <= 0;

        j++;
        if (j == 8) begin
          j = i == 8 ? 0 : 1;
          i++;
        end
      end
      start_pc_after_task_switch = z;
    end
    read_new_process_state_ready <= 1;
  end


  always @(posedge remove_process_from_chain) begin
    remove_process_from_chain_ready <= 0;

    //update chain of command
    for (i = 0; i < 4; i++) begin
      switcher_ram_read_address <= physical_process_address + i + `ADDRESS_NEXT_PROCESS;
      switcher_ram_read <= 1;
      @(posedge switcher_ram_read_ready) switcher_ram_read <= 0;

      switcher_ram_save_address <= old_physical_process_address + `ADDRESS_NEXT_PROCESS + i;
      switcher_ram_save_data_in <= switcher_ram_read_data_out;
      switcher_ram_save <= 1;
      @(posedge switcher_ram_save_ready) switcher_ram_save <= 0;
    end

    active_task_num--;

    remove_process_from_chain_ready <= 1;
  end

  always @(rst) begin
    if (`DEBUG_LEVEL > 1) $display($time, " reset2");  //DEBUG info
    physical_process_address = 0;
    old_physical_process_address = 0;
    active_task_num = 1;
    start_pc_after_task_switch = `ADDRESS_PROGRAM;
    for (i = 0; i < 9; i++) begin
      old_reg_used[i] = 0;
    end
    for (i = 0; i < `REGISTER_NUM; i++) begin
      old_registers_memory[i] = 0;
    end
    for (i = 0; i < 256; i++) begin
      int_process_address[i] = 1;
    end
  end

  always @(posedge switcher_setup_int) begin
    switcher_setup_int_ready <= 0;
    if (int_process_address[switcher_setup_int_number] == 1) begin
      $display($time, " setup int ", switcher_setup_int_number, " with process with address ",
               physical_process_address);
      int_process_address[switcher_setup_int_number] = physical_process_address;

      //save current process state
      dump_process_state <= 1;
      @(posedge dump_process_state_ready) dump_process_state <= 0;

      //read next process address
      j = 0;
      for (i = 0; i < 4; i++) begin
        switcher_ram_read_address <= physical_process_address + i;
        switcher_ram_read <= 1;
        @(posedge switcher_ram_read_ready) switcher_ram_read <= 0;
        j += switcher_ram_read_data_out * (256 ** i);
      end
      temp_new_process_address = j;

      remove_process_from_chain <= 1;
      @(posedge remove_process_from_chain_ready) remove_process_from_chain <= 0;

      //switch to next process
      physical_process_address = temp_new_process_address;
    end
    $display($time, " end setup int, returned to process ", physical_process_address);
    switcher_setup_int_ready <= 1;
  end

  always @(posedge switcher_execute_return_int) begin
    switcher_execute_return_int_ready <= 0;
    if (int_process_address[switcher_execute_return_int_number] !== 1) begin

      $display($time, " execute/return int - calling process address ",  //DEBUG info
               physical_process_address,  //DEBUG info
               " int process - ",  //DEBUG info
               int_process_address[switcher_execute_return_int_number]);  //DEBUG info

      $display($time, " end execute/return inta");
      //save current process state
      dump_process_state <= 1;
      @(posedge dump_process_state_ready) dump_process_state <= 0;

      $display($time, " end execute/return intb");
      //read next process address
      j = 0;
      for (i = 0; i < 4; i++) begin
        switcher_ram_read_address <= physical_process_address + i;
        switcher_ram_read <= 1;
        @(posedge switcher_ram_read_ready) switcher_ram_read <= 0;
        j += switcher_ram_read_data_out * (256 ** i);
      end
      temp_new_process_address = j;

      $display($time, " end execute/return int1");
      //fixme! - update all 4 bytes
      switcher_ram_save_address <= old_physical_process_address + `ADDRESS_NEXT_PROCESS + 0;
      switcher_ram_save_data_in <= int_process_address[switcher_execute_return_int_number] % 256;
      switcher_ram_save <= 1;
      @(posedge switcher_ram_save_ready) switcher_ram_save <= 0;

      switcher_ram_save_address <= old_physical_process_address + `ADDRESS_NEXT_PROCESS + 1;
      switcher_ram_save_data_in <= int_process_address[switcher_execute_return_int_number] / 256;
      switcher_ram_save <= 1;
      @(posedge switcher_ram_save_ready) switcher_ram_save <= 0;

      $display($time, " end execute/return int2");

      //fixme! update all 4 bytes
      switcher_ram_save_address <= int_process_address[switcher_execute_return_int_number] + `ADDRESS_NEXT_PROCESS + 0;
      switcher_ram_save_data_in <= temp_new_process_address % 256;
      switcher_ram_save <= 1;
      @(posedge switcher_ram_save_ready) switcher_ram_save <= 0;

      switcher_ram_save_address <= int_process_address[switcher_execute_return_int_number] + `ADDRESS_NEXT_PROCESS + 1;
      switcher_ram_save_data_in <= temp_new_process_address / 256;
      switcher_ram_save <= 1;
      @(posedge switcher_ram_save_ready) switcher_ram_save <= 0;

      $display($time, " end execute/return int3");

      //switch to next process and change int vector
      temp_new_process_address = int_process_address[switcher_setup_int_number];
      int_process_address[switcher_setup_int_number] = physical_process_address;
      physical_process_address = temp_new_process_address;

      $display($time, " end execute/return int4");

      read_new_process_state <= 1;
      @(posedge read_new_process_state_ready) read_new_process_state <= 0;
    end
    $display($time, " end execute/return int - process address ",  //DEBUG info
             physical_process_address,  //DEBUG info
             " int process - ",  //DEBUG info
             int_process_address[switcher_execute_return_int_number]);  //DEBUG info

    switcher_execute_return_int_ready <= 1;
  end

  always @(posedge switcher_split_process) begin
    switcher_split_process_ready <= 0;

    //trust no one - setup pc in new process
    for (i = 0; i < 4; i++) begin
      switcher_ram_save_address <= switcher_split_new_process_address + `ADDRESS_PC + i;
      switcher_ram_save_data_in <= 0;
      switcher_ram_save <= 1;
      @(posedge switcher_ram_save_ready) switcher_ram_save <= 0;
    end

    //update chain of the command

    //    read next process address from existing and setup it in new process
    for (i = 0; i < 4; i++) begin
      switcher_ram_read_address <= physical_process_address + `ADDRESS_NEXT_PROCESS + i;
      switcher_ram_read <= 1;
      @(posedge switcher_ram_read_ready) switcher_ram_read <= 0;

      switcher_ram_save_address <= switcher_split_new_process_address + `ADDRESS_NEXT_PROCESS + i;
      switcher_ram_save_data_in <= switcher_ram_read_data_out;
      switcher_ram_save <= 1;
      @(posedge switcher_ram_save_ready) switcher_ram_save <= 0;
    end

    //fixme! - update all 4 bytes
    switcher_ram_save_address <= physical_process_address + `ADDRESS_NEXT_PROCESS + 0;
    switcher_ram_save_data_in <= switcher_split_new_process_address % 256;
    switcher_ram_save <= 1;
    @(posedge switcher_ram_save_ready) switcher_ram_save <= 0;

    switcher_ram_save_address <= physical_process_address + `ADDRESS_NEXT_PROCESS + 1;
    switcher_ram_save_data_in <= switcher_split_new_process_address / 256;
    switcher_ram_save <= 1;
    @(posedge switcher_ram_save_ready) switcher_ram_save <= 0;

    active_task_num++;

    switcher_split_process_ready <= 1;
  end

  //fixme: to track, if dont have problems because of assuming that reg and reg_used are initially setup to 0
  always @(posedge switcher_exec) begin
    $display($time, " switcher start - process address ", physical_process_address,  //DEBUG info
             " removal - ",  //DEBUG info
             switcher_with_removal);  //DEBUG info
    switcher_exec_ready <= 0;

    if (active_task_num > 1) begin
      if (switcher_with_removal == 0) begin
        dump_process_state <= 1;
        @(posedge dump_process_state_ready) dump_process_state <= 0;
      end

      $display($time, "");  //DEBUG info
      $display($time, "");  //DEBUG info
      $display($time, "");  //DEBUG info
      $display($time, "");  //DEBUG info

      //read next process address
      j = 0;
      for (i = 0; i < 4; i++) begin
        switcher_ram_read_address <= physical_process_address + i;
        switcher_ram_read <= 1;
        @(posedge switcher_ram_read_ready) switcher_ram_read <= 0;
        j += switcher_ram_read_data_out * (256 ** i);
      end
      temp_new_process_address = j;

      read_new_process_state <= 1;
      @(posedge read_new_process_state_ready) read_new_process_state <= 0;

      if (switcher_with_removal == 1) begin
        remove_process_from_chain <= 1;
        @(posedge remove_process_from_chain_ready) remove_process_from_chain <= 0;
      end

      old_physical_process_address = physical_process_address;
      physical_process_address = temp_new_process_address;
    end
    $display($time, " switcher end - process address ", physical_process_address,  //DEBUG info
             " start pc after ", start_pc_after_task_switch);  //DEBUG info

    switcher_exec_ready <= 1;
  end
endmodule

module ram2 (
    input ram_clk,
    input sim_end,  //DEBUG info
    input [`MAX_BITS_IN_ADDRESS:0] physical_process_address,
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
    input mmu_split_process,
    output reg mmu_split_process_ready,
    input [`MAX_BITS_IN_ADDRESS:0] mmu_split_process_start,
    input [`MAX_BITS_IN_ADDRESS:0] mmu_split_process_end,
    output reg [`MAX_BITS_IN_ADDRESS:0] mmu_split_new_process_address,
    input mmu_remove_process,
    output reg mmu_remove_process_ready
);

  reg ram_write_enable;
  reg [`MAX_BITS_IN_ADDRESS:0] ram_address;
  reg [7:0] ram_data_in;
  wire [7:0] ram_data_out;

  ram ram (
      .sim_end(sim_end),  //DEBUG info
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
      .physical_process_address(physical_process_address),
      .logical_address(mmu_logical_address),
      .physical_address(mmu_physical_address),
      .mmu_get_physical_address(mmu_get_physical_address),
      .mmu_get_physical_address_ready(mmu_get_physical_address_ready),
      .mmu_split_process(mmu_split_process),
      .mmu_split_process_ready(mmu_split_process_ready),
      .mmu_split_process_start(mmu_split_process_start),
      .mmu_split_process_end(mmu_split_process_end),
      .mmu_split_new_process_address(mmu_split_new_process_address),
      .mmu_remove_process(mmu_remove_process),
      .mmu_remove_process_ready(mmu_remove_process_ready)
  );

  always @(posedge stage12_read or posedge stage3_read or posedge stage5_save or posedge switcher_save or posedge switcher_read) begin
    if (switcher_save) begin
      switcher_save_ready <= 0;
      ram_write_enable <= 1;
      ram_address = switcher_save_address;
      ram_data_in = switcher_save_data_in;
      if (`DEBUG_LEVEL > 1)  //DEBUG info
        $display(  //DEBUG info
            $time,  //DEBUG info
            " saving RAM from switcher address ",  //DEBUG info
            switcher_save_address,  //DEBUG info
            " ",  //DEBUG info
            switcher_save_data_in  //DEBUG info
        );  //DEBUG info
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
      if (`DEBUG_LEVEL > 1)  //DEBUG info
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
      if (`DEBUG_LEVEL > 1)  //DEBUG info
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
      if (`DEBUG_LEVEL > 1)  //DEBUG info
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
      mmu_logical_address = stage12_read_address;
      mmu_get_physical_address <= 1;
      @(posedge mmu_get_physical_address_ready) mmu_get_physical_address <= 0;
      ram_address = mmu_physical_address;
      ram_write_enable <= 0;
      @(posedge ram_clk)
      @(negedge ram_clk)
      if (`DEBUG_LEVEL > 1)  //DEBUG info
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
    input [`MAX_BITS_IN_ADDRESS:0] mmu_split_process_end,
    output reg [`MAX_BITS_IN_ADDRESS:0] mmu_split_new_process_address,
    input mmu_remove_process,
    output reg mmu_remove_process_ready,
    input mmu_setup_int_sharing,
    input mmu_start_int_sharing,
    input mmu_stop_int_sharing
);

  reg [15:0] mmu_chain_memory[0:65535];  //values = next physical start point for task; last entry = 0
  reg [15:0] mmu_logical_pages_memory[0:65535];  //values = logical page assign to this physical page; 0 means page is empty (in existing processes, where first page is 0, we setup here value > 0 and ignore it)
  reg [15:0] index_start; // this is start index of the loop searching for free mmeory page; when reserving pages, increase; when deleting, setup to lowest free value
  reg [15:0] start_process_segment;

  reg [`MAX_BITS_IN_ADDRESS:0] int_process_shared_mem_start_segment[255:0];
  reg [`MAX_BITS_IN_ADDRESS:0] int_process_shared_mem_end_segment[255:0];
  reg [`MAX_BITS_IN_ADDRESS:0] int_process_shared_ret_mem_start_segment[255:0];

  reg mmu_dump;  //DEBUG info
  reg mmu_dump_ready;  //DEBUG info
  reg [2:0] mmu_dump_level;  //DEBUG info
  reg mmu_show_process_chain;  //DEBUG info
  reg mmu_show_process_chain_ready;  //DEBUG info

  string s;  //DEBUG info
  integer i, j, index, previndex, z, newindex, newindex2, newstartpoint;

  always @(physical_process_address) begin
    start_process_segment = physical_process_address / `MMU_PAGE_SIZE;
  end
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
    mmu_logical_pages_memory[1] = 1;
    mmu_logical_pages_memory[2] = 4;
    mmu_logical_pages_memory[3] = 3;
    mmu_logical_pages_memory[5] = 2;
  end

  always @(posedge mmu_setup_int_sharing) begin
  end

  always @(posedge mmu_start_int_sharing) begin
  end

  always @(posedge mmu_stop_int_sharing) begin
  end

  always @(posedge mmu_dump) begin  //DEBUG info
    mmu_dump_ready <= 0;  //DEBUG info
    s = " MMU ";  //DEBUG info
    for (z = 0; z < 10; z++) begin  //DEBUG info
      s = {  //DEBUG info
        s, $sformatf("%01x-%01x ", mmu_chain_memory[z], mmu_logical_pages_memory[z])  //DEBUG info
      };  //DEBUG info
    end  //DEBUG info
    if (`DEBUG_LEVEL >= mmu_dump_level) $display($time, s, " ...");  //DEBUG info
    mmu_dump_ready <= 1;  //DEBUG info
  end  //DEBUG info

  always @(posedge mmu_show_process_chain) begin  //DEBUG info
    mmu_show_process_chain_ready <= 0;  //DEBUG info
    previndex = newindex;  //DEBUG info
    do begin  //DEBUG info
      if (`DEBUG_LEVEL > 1)  //DEBUG info
        $display(  //DEBUG info
            $time,  //DEBUG info
            " MMU process chain ",  //DEBUG info              
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
    mmu_show_process_chain_ready <= 1;  //DEBUG info
  end  //DEBUG info

  always @(posedge mmu_get_physical_address or posedge mmu_split_process or posedge mmu_remove_process) begin
    //todo: caching last value
    if (mmu_get_physical_address) begin
      mmu_get_physical_address_ready <= 0;

      index = start_process_segment;
      i = logical_address / `MMU_PAGE_SIZE;

      //we don't need to calculate it for first segment - it's always equal to process address segment
      if (i != 0) begin
        while (mmu_chain_memory[index] !== 0 && mmu_logical_pages_memory[index] != i) begin
          index = mmu_chain_memory[index];
        end
        $display($time, " MMU index after searching  ", index);  //DEBUG info
        if (mmu_logical_pages_memory[index] != i) begin
          while (mmu_logical_pages_memory[index_start] !== 0) begin
            index_start++;
          end
          //fixme: support for 100% memory usage
          mmu_chain_memory[index] = index_start;
          index = index_start;
          $display($time, " MMU assigning new page ", index);  //DEBUG info
          mmu_logical_pages_memory[index] = i;
        end
      end
      physical_address = index * `MMU_PAGE_SIZE + logical_address % `MMU_PAGE_SIZE;

      if (`DEBUG_LEVEL > 2)  //DEBUG info
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

      mmu_get_physical_address_ready <= 1;
    end else if (mmu_split_process) begin
      mmu_split_process_ready <= 0;

      mmu_dump_level <= 0;  //DEBUG info
      mmu_dump <= 1;  //DEBUG info
      @(posedge mmu_dump_ready) mmu_dump <= 0;  //DEBUG info

      newindex = start_process_segment;  //start point for existing process //DEBUG info
      mmu_show_process_chain <= 1;  //DEBUG info
      @(posedge mmu_show_process_chain_ready) mmu_show_process_chain <= 0;  //DEBUG info

      newindex2 = 0;
      j = 255 * 255;  //some known value like 255*255 could be used for checking mmu validity
      for (i = mmu_split_process_start; i <= mmu_split_process_end; i++) begin
        newindex  = start_process_segment;  //start point for existing process
        previndex = newindex;
        do begin
          if (mmu_logical_pages_memory[newindex] == i && newindex != start_process_segment) begin
            if (`DEBUG_LEVEL > 2)  //DEBUG info
              $display($time, " first page", i, " ", j, " ", newindex);  //DEBUG info
            mmu_chain_memory[previndex] = mmu_chain_memory[newindex];
            mmu_logical_pages_memory[newindex] = j;
            if (newindex2 != 0) begin
              mmu_chain_memory[newindex2] = newindex;
            end
            newindex2 = newindex;
            if (j == 255 * 255) begin
              newstartpoint = newindex;
              j = 1;
            end else begin
              j++;
            end
            if (j == mmu_split_process_end) begin
              mmu_chain_memory[newindex] = 0;
            end
            mmu_dump_level <= 3;  //DEBUG info
            mmu_dump <= 1;  //DEBUG info
            @(posedge mmu_dump_ready) mmu_dump <= 0;  //DEBUG info
          end
          previndex = newindex;
          newindex  = mmu_chain_memory[previndex];
        end while (mmu_chain_memory[previndex] !== 0);
      end

      mmu_dump_level <= 0;  //DEBUG info
      mmu_dump <= 1;  //DEBUG info
      @(posedge mmu_dump_ready) mmu_dump <= 0;  //DEBUG info

      newindex = start_process_segment;  //start point for existing process //DEBUG info
      mmu_show_process_chain <= 1;  //DEBUG info
      @(posedge mmu_show_process_chain_ready) mmu_show_process_chain <= 0;  //DEBUG info

      if (`DEBUG_LEVEL > 1) $display($time, "");  //DEBUG info

      newindex = newstartpoint;  //DEBUG info
      mmu_show_process_chain <= 1;  //DEBUG info
      @(posedge mmu_show_process_chain_ready) mmu_show_process_chain <= 0;  //DEBUG info

      mmu_split_new_process_address = newstartpoint * `MMU_PAGE_SIZE;

      mmu_split_process_ready <= 1;
    end else if (mmu_remove_process) begin
      mmu_remove_process_ready <= 0;

      mmu_dump_level <= 0;  //DEBUG info
      mmu_dump <= 1;  //DEBUG info
      @(posedge mmu_dump_ready) mmu_dump <= 0;  //DEBUG info

      newindex = start_process_segment;  //start point for existing process //DEBUG info
      mmu_show_process_chain <= 1;  //DEBUG info
      @(posedge mmu_show_process_chain_ready) mmu_show_process_chain <= 0;  //DEBUG info

      newindex = start_process_segment;  //start point for existing process
      do begin
        if (newindex < index_start) index_start = newindex;
        mmu_logical_pages_memory[newindex] = 0;
        previndex = newindex;
        newindex = mmu_chain_memory[previndex];
      end while (mmu_chain_memory[previndex] !== 0);

      mmu_dump_level <= 0;  //DEBUG info
      mmu_dump <= 1;  //DEBUG info
      @(posedge mmu_dump_ready) mmu_dump <= 0;  //DEBUG info

      mmu_remove_process_ready <= 1;
    end
  end
endmodule

// we have to use standard RAM = definition is "as is"
module ram (
    input ram_clk,
    input sim_end,  //DEBUG info
    input write_enable,
    input [`MAX_BITS_IN_ADDRESS:0] address,
    input [7:0] data_in,
    output reg [7:0] data_out
);

  reg [7:0] ram_memory[0:1048576];

  initial begin  //DEBUG info
    $readmemh("rom3.mem", ram_memory);  //DEBUG info
  end  //DEBUG info
  always @(sim_end) begin  //DEBUG info
  end  //DEBUG info
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

  integer i, j;
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
    j  = 64;  //DEBUG info
    do begin  //DEBUG info
      j--;  //DEBUG info
    end while (registers_memory[j] == 0);  //DEBUG info
    for (i = 0; i <= j; i++) begin  //DEBUG info
      s2 = {s2, $sformatf("%02x ", registers_memory[i])};  //DEBUG info
    end  //DEBUG info
    $display($time, s2, " ...");  //DEBUG info

    s2 = " reg used ";  //DEBUG info
    for (i = 0; i < 20; i++) begin  //DEBUG info
      s2 = {s2, $sformatf("%01x ", registers_used[i])};  //DEBUG info
    end  //DEBUG info
    if (`DEBUG_LEVEL > 1) $display($time, s2, " ...");  //DEBUG info
    dump_reg_ready <= 1;  //DEBUG info
  end  //DEBUG info
endmodule

`timescale 1ns / 1ps

`define MMU_CHANGES_DEBUG 1 //1 enabled, 0 disabled
`define MMU_TRANSLATION_DEBUG 1 //1 enabled, 0 disabled
`define TASK_SWITCHER_DEBUG 1 //1 enabled, 0 disabled
`define MMU_PAGE_SIZE 200 //how many bytes are assigned to one memory page in MMU

module cpu (
    input rst,
    input clka,
    clkb
);

  wire clka, clkb, ena, enb, wea;
  wire [9:0] addra, addrb;
  wire [15:0] dia;
  wire [15:0] dob;

  simple_dual_two_clocks simple_dual_two_clocks (
      .clka (clka),
      .clkb (clkb),
      .ena  (ena),
      .enb  (enb),
      .wea  (wea),
      .addra(addra),
      .addrb(addrb),
      .dia  (dia),
      .dob  (dob)
  );

  stage1 stage1 (
      .clka (clka),
      .clkb (clkb),
      .rst  (rst),
      .ena  (ena),
      .enb  (enb),
      .wea  (wea),
      .addra(addra),
      .addrb(addrb),
      .dia  (dia),
      .dob  (dob)
  );

endmodule

module stage1 (
    input             clka,
    clkb,
    input             rst,
    output reg        ena,
    enb,
    wea,
    output reg [ 9:0] addra,
    addrb,
    output reg [15:0] dia,
    input      [15:0] dob
);

  integer i;  //DEBUG info

  //offsets for process info
  `define ADDRESS_NEXT_PROCESS 0
  `define ADDRESS_PC 4
  `define ADDRESS_REG_USED 8
  `define ADDRESS_REG 14
  `define ADDRESS_PROGRAM `ADDRESS_REG+32

  `define LOOP_TILL_VALUE 0
  `define LOOP_TILL_NON_VALUE 1
  `define LOOP_FOR 2

  `define STAGE_READ_PC1_REQUEST 0
  `define STAGE_READ_PC1_RESPONSE 1
  `define STAGE_READ_PC2_REQUEST 2
  `define STAGE_READ_PC2_RESPONSE 3
  `define STAGE_DECODE 4
  `define STAGE_READ_RAM2REG 5
  `define STAGE_SAVE_REG2RAM 6
  `define STAGE_MMU_TRANSLATE_A 7
  `define STAGE_MMU_TRANSLATE_B 8
  `define STAGE_TASK_SWITCHER 9
  `define STAGE_SEPARATE_PROCESS 10

  `define SWITCHER_STAGE_WAIT 0
  `define SWITCHER_STAGE_SAVE_PC 1 //save current pc
  `define SWITCHER_STAGE_SAVE_REG_0 2
  //...
  `define SWITCHER_STAGE_SAVE_REG_31 33
  `define SWITCHER_STAGE_READ_NEW_PROCESS_ADDR 34
  `define SWITCHER_STAGE_READ_NEW_PC 35
  `define SWITCHER_STAGE_READ_NEW_REG_0 36
  //...
  `define SWITCHER_STAGE_READ_NEW_REG_31 37

  `define MMU_STAGE_WAIT 0
  `define MMU_STAGE_SEARCH 1
  `define MMU_STAGE_FOUND 2
  `define MMU_SEPARATE_PROCESS 3

  reg [15:0] mmu_start_process_segment;  //needs to be updated on process switch
  reg [15:0] start_process_address;  //needs to be updated on process switch

  //current instruction - we don't need to multiply it among processes, because we don't support partially executed op before process switch
  reg [4:0] stage; //it doesn't need process index - we switch to other process after completing instruction
  reg [4:0] stage_after_mmu; //temporary value - after MMU related stage we switch to another "correct one"
  reg [7:0] inst_op;  //instruction / operation code
  reg [7:0] inst_reg_num;  //in majority cases: processed / affected register number
  reg [15:0] inst_address_num;  //in majority caes: processed / affected memory address

  reg [2:0] process_index = 0; //process related. We cache data about n=8 processes - here we save index value for other tables
  reg [2:0] process_instruction_done = 0; //process related. how many instructions were done for current process

  //values for all processes - need to be separated for every process
  reg [9:0] address_pc[2:0];  //n=2^3=8 addresses
  reg [15:0] registers[2:0][5:0];  //64 8-bit registers * n=8 processes = 512 16-bit registers

  //cache used in all loops - needs to be separated for every process
  reg [7:0] inst_op_cache[2:0][255:0];  // 256 * n=8 processes = 2048
  reg [7:0] inst_reg_num_cache[2:0][255:0];
  reg [15:0] inst_address_num_cache[2:0][255:0];

  //loop executions - need to be separate for every process
  reg [7:0] loop_counter[2:0];
  reg [7:0] loop_counter_max[2:0];
  reg [5:0] loop_reg_num[2:0];
  reg [7:0] loop_comp_value[2:0];
  reg [1:0] loop_type[2:0];

  reg [15:0] task_switcher_stage;

  //MMU (Memory Management Unit)
  reg [9:0] mmu_input_addr;  //address to translate
  reg [15:0] mmu_chain_memory[0:1000];  //values = next physical page index for process; last entry = 0
  reg [15:0] mmu_logical_pages_memory[0:1000];  //values = logical process page assigned to physical page; 0 means empty oage
                                                //(in existing processes - we setup here value > 0 for first page with index 0 and ignore it)
  reg [15:0] mmu_index_start; // this is start index of the loop searching for free memory page; when reserving pages, increase;
                              // when deleting, setup to lowest free value
  reg [15:0] mmu_logical_index_new;
  reg [15:0] mmu_logical_index_old;
  reg [15:0] mmu_physical_index_old;
  reg [15:0] mmu_last_process_segment;  //used during search for finding last process segment
  reg [15:0] mmu_separate_process_segment;
  reg [4:0] mmu_stage;
  reg [2:0] mmu_changes_debug;  //DEBUG info

  always @(mmu_stage) begin
    if (mmu_stage == `MMU_STAGE_SEARCH) begin
      if (mmu_logical_index_old == mmu_logical_index_new) begin
        //we have already translated address. We can use it.
        mmu_stage <= `MMU_STAGE_FOUND;
      end else begin
        //start searching page
        mmu_physical_index_old <= mmu_start_process_segment;
        mmu_logical_index_old  <= mmu_logical_index_new;
      end
    end else if (mmu_stage == `MMU_STAGE_FOUND) begin
      //page found, we can create translated address and exit.
      if (stage == `STAGE_MMU_TRANSLATE_A) begin
        addra <= mmu_physical_index_old * `MMU_PAGE_SIZE + mmu_input_addr % `MMU_PAGE_SIZE; //FIXME: bits moving and concatenation
        wea <= 1;
      end else begin
        addrb <= mmu_physical_index_old * `MMU_PAGE_SIZE + mmu_input_addr % `MMU_PAGE_SIZE;
      end
      stage <= stage_after_mmu;
      mmu_stage <= `MMU_STAGE_WAIT;
      if (`MMU_TRANSLATION_DEBUG === 1)  //DEBUG info
        $display(  //DEBUG info
            $time,  //DEBUG info
            " mmu from ",  //DEBUG info
            mmu_input_addr,  //DEBUG info
            " to ",  //DEBUG info
            (mmu_physical_index_old * `MMU_PAGE_SIZE + mmu_input_addr % `MMU_PAGE_SIZE)  //DEBUG info
        );  //DEBUG info
      if (`MMU_CHANGES_DEBUG === 1 && mmu_changes_debug == 1) $write($time, " mmu ");  //DEBUG info
      for (i = 0; i <= 10; i = i + 1) begin  //DEBUG info
        if (`MMU_CHANGES_DEBUG === 1 && mmu_changes_debug == 1)  //DEBUG info
          $write(  //DEBUG info
              $sformatf(  //DEBUG info
                  "%02x-%02x ", mmu_chain_memory[i], mmu_logical_pages_memory[i]  //DEBUG info
              )  //DEBUG info
          );  //DEBUG info
      end  //DEBUG info
      if (`MMU_CHANGES_DEBUG === 1 && mmu_changes_debug == 1) $display("");  //DEBUG info
      mmu_changes_debug <= 0;  //DEBUG info
    end
  end

  always @(mmu_separate_process_segment) begin
    if (mmu_chain_memory[mmu_separate_process_segment] === 0) begin
      if (inst_address_num != inst_reg_num) begin
        $display("error");
        //switch to task switcher update
      end else begin
        //terminate new process and switch to task switcher update
      end
    end else begin
      //inst_address_num<=inst_address_num+inst_reg_num
      if (mmu_logical_pages_memory[mmu_separate_process_segment] >= inst_address_num && 
    	    mmu_logical_pages_memory[mmu_separate_process_segment] <= inst_address_num+inst_reg_num) begin
        //newprocessprevious -> next = mmu_separate_process_segment;
        //oldprocessprevious -> next = current -> next;
      end
      mmu_separate_process_segment <= mmu_chain_memory[mmu_separate_process_segment];
    end
  end

  //searching in the process memory and exiting with translated address or switching to searching free memory
  always @(mmu_logical_index_old) begin
    if (mmu_logical_index_new === 0 && mmu_physical_index_old === mmu_start_process_segment) begin
      //value found in current process chain
      mmu_stage <= `MMU_STAGE_FOUND;
    end else if (mmu_physical_index_old !== mmu_start_process_segment && mmu_logical_pages_memory[mmu_physical_index_old]===mmu_logical_index_new) begin
      //value found in current process chain
      mmu_stage <= `MMU_STAGE_FOUND;
    end else if (mmu_chain_memory[mmu_physical_index_old] === 0) begin
      //we need to start searching first free memory page and allocate it
      mmu_last_process_segment <= mmu_physical_index_old;
      mmu_index_start <= mmu_index_start + 1;
    end else begin
      //go into next memory page in process chain
      mmu_physical_index_old <= mmu_chain_memory[mmu_physical_index_old];
      mmu_logical_index_old  <= mmu_logical_pages_memory[mmu_chain_memory[mmu_physical_index_old]];
    end
  end

  //allocating new memory for process
  always @(mmu_index_start) begin
    if (!rst) begin
      if (mmu_logical_pages_memory[mmu_index_start] === 0) begin
        //we have free memory page. Let's allocate it and add to process chain
        if (`MMU_CHANGES_DEBUG === 1) $display($time, " mmu new page ");  //DEBUG info
        if (`MMU_CHANGES_DEBUG === 1) mmu_changes_debug <= 1;  //DEBUG info
        mmu_chain_memory[mmu_last_process_segment] <= mmu_index_start;
        mmu_chain_memory[mmu_index_start] <= 0;
        mmu_logical_pages_memory[mmu_index_start] <= mmu_logical_index_new;
        mmu_physical_index_old <= mmu_index_start;
        mmu_stage <= `MMU_STAGE_FOUND;
      end else begin
        //FIXME: support for lack of free memory
        mmu_index_start <= mmu_index_start + 1;
      end
    end
  end

  always @(posedge rst) begin
    $display($time, "rst");  //DEBUG info
    enb <= 1;
    ena <= 1;
    address_pc[process_index] <= `ADDRESS_PROGRAM;
    loop_counter[process_index] <= 0;
    loop_counter_max[process_index] <= 0;
    start_process_address <= 0;
    mmu_start_process_segment <= 0;
    mmu_index_start <= 0;
    mmu_chain_memory[0] <= 0;
    //problem: we shouldn't mix blocking and non-blocking
    for (
        mmu_logical_index_new = 0;
        mmu_logical_index_new < 1000;
        mmu_logical_index_new = mmu_logical_index_new + 1
    ) begin
      //value 0 means, that it's empty. in every process on first entry we setup something != 0 and ignore it
      // (first process page is always from segment 0)
      mmu_logical_pages_memory[mmu_logical_index_new] <= 0;
    end
    mmu_logical_pages_memory[0] <= 1;
    mmu_stage <= `MMU_STAGE_WAIT;
    mmu_changes_debug <= 1;  //DEBUG info
    task_switcher_stage <= `SWITCHER_STAGE_WAIT;
    stage <= `STAGE_READ_PC1_REQUEST;
  end

  `define OPCODE_JMP 1     //256 or register num for first 16-bits of the address, 16 bit address
  `define OPCODE_RAM2REG 2 //register num, 16 bit source addr //ram -> reg
  `define OPCODE_REG2RAM 3 //register num, 16 bit source addr //reg -> ram
  `define OPCODE_NUM2REG 4 //register num, 16 bit value //value -> reg
  `define OPCODE_REG_PLUS 5 //register num, 16 bit value // reg += value
  `define OPCODE_REG_MINUS 6 //register num, 16 bit value  //reg -= value
  `define OPCODE_REG_MUL 7 //register num, 16 bit value // reg *= value
  `define OPCODE_REG_DIV 8 //register num, 16 bit value  //reg /= value
  `define OPCODE_TILL_VALUE 9   //register num, value, how many instructions (8 bit value) // do..while
  `define OPCODE_TILL_NON_VALUE 10   //register num, value, how many instructions (8 bit value) //do..while
  `define OPCODE_LOOP 11   //x, x, how many instructions (8 bit value) //for...
  `define OPCODE_PROC 12 //new process //how many segments, start segment number (16 bit)
  `define OPCODE_REG_INT 14
  `define OPCODE_INT 15
  `define OPCODE_INT_RET 16
  `define OPCODE_EXIT 17 //exit process
  `define OPCODE_JMP_PLUS 18 //x, how many instructions
  `define OPCODE_JMP_MINUS 19 //x, how many instructions

  always @(stage) begin
    if (stage == `STAGE_MMU_TRANSLATE_A || stage == `STAGE_MMU_TRANSLATE_B) begin
      if (`MMU_CHANGES_DEBUG === 1 && mmu_changes_debug == 1) $write($time, " mmu ");  //DEBUG info
      for (i = 0; i <= 10; i = i + 1) begin  //DEBUG info
        if (`MMU_CHANGES_DEBUG === 1 && mmu_changes_debug == 1)  //DEBUG info
          $write(  //DEBUG info
              $sformatf(  //DEBUG info
                  "%02x-%02x ", mmu_chain_memory[i], mmu_logical_pages_memory[i]  //DEBUG info
              )  //DEBUG info
          );  //DEBUG info
      end  //DEBUG info
      if (`MMU_CHANGES_DEBUG === 1 && mmu_changes_debug == 1) $display("");  //DEBUG info
      mmu_changes_debug <= 0;  //DEBUG info
      mmu_logical_index_new <= mmu_input_addr / `MMU_PAGE_SIZE; //FIXME: it's enough just to take concrete bits
      mmu_stage <= `MMU_STAGE_SEARCH;
    end else if (stage == `STAGE_READ_PC1_REQUEST) begin
      process_instruction_done <= process_instruction_done + 1;
      if (process_instruction_done == 2) begin
        //time to switch process
        stage <= `STAGE_TASK_SWITCHER;
        //first save PC
        addra <= start_process_address + `ADDRESS_PC;
        dia <= address_pc[process_index];
        wea <= 1;
        task_switcher_stage <= `SWITCHER_STAGE_SAVE_PC;
      end else begin
        if (loop_counter[process_index] > loop_counter_max[process_index]) begin
          inst_op <= inst_op_cache[process_index][loop_counter_max[process_index]];
          inst_reg_num <= inst_reg_num_cache[process_index][loop_counter_max[process_index]];
          inst_address_num <= inst_address_num_cache[process_index][loop_counter_max[process_index]];
          loop_counter_max[process_index] <= loop_counter_max[process_index] + 1;
          address_pc[process_index] <= address_pc[process_index] + 2;
          $display($time, (address_pc[process_index]), "=", inst_op, inst_reg_num,  //DEBUG info
                   inst_address_num / 256,  //DEBUG info
                   inst_address_num % 256, " (cache)");  //DEBUG info
          stage <= `STAGE_DECODE;
        end else begin
          mmu_input_addr <= address_pc[process_index];
          stage_after_mmu <= `STAGE_READ_PC1_RESPONSE;
          stage <= `STAGE_MMU_TRANSLATE_B;
        end
      end
    end else if (stage == `STAGE_READ_PC2_REQUEST) begin
      mmu_input_addr <= address_pc[process_index];
      stage_after_mmu <= `STAGE_READ_PC2_RESPONSE;
      stage <= `STAGE_MMU_TRANSLATE_B;
    end else if (stage == `STAGE_DECODE) begin
      if (inst_op == `OPCODE_RAM2REG) begin
        $display($time, " opcode = ram2reg address ", inst_address_num, " to reg ",  //DEBUG info
                 inst_reg_num);  //DEBUG info
        mmu_input_addr <= inst_address_num;
        stage_after_mmu <= `STAGE_READ_RAM2REG;
        stage <= `STAGE_MMU_TRANSLATE_B;
      end else if (inst_op == `OPCODE_REG2RAM) begin
        $display($time, " opcode = reg2ram value ",  //DEBUG info
                 registers[process_index][inst_reg_num],  //DEBUG info
                 " to address ",  //DEBUG info
                 inst_address_num);  //DEBUG info
        dia <= registers[process_index][inst_reg_num];
        mmu_input_addr <= inst_address_num;
        stage_after_mmu <= `STAGE_SAVE_REG2RAM;
        stage <= `STAGE_MMU_TRANSLATE_A;
      end else if (inst_op == `OPCODE_PROC) begin
        $display($time, " opcode = proc ", inst_reg_num, //DEBUG info
                 " memory segments starting from segment ",  //DEBUG info
                 inst_address_num);  //DEBUG info
        stage <= `STAGE_SEPARATE_PROCESS;
        if (mmu_start_process_segment == mmu_separate_process_segment) begin
          $display("error");
        end else begin
          // inst_address_num<=inst_address_num+inst_reg_num;
          mmu_separate_process_segment <= mmu_start_process_segment;
        end
      end else begin
        if (inst_op == `OPCODE_JMP) begin
          $display($time, " opcode = jmp to ", inst_address_num);  //DEBUG info
          address_pc[process_index] <= inst_address_num;
        end else if (inst_op == `OPCODE_NUM2REG) begin
          $display($time, " opcode = num2reg value ", inst_address_num, " to reg ",  //DEBUG info
                   inst_reg_num);  //DEBUG info
          registers[process_index][inst_reg_num] <= inst_address_num;
        end else if (inst_op == `OPCODE_REG_PLUS) begin
          $display($time, " opcode = regplusnum value ", inst_address_num, " to reg ",  //DEBUG info
                   inst_reg_num);  //DEBUG info
          registers[process_index][inst_reg_num] <= registers[process_index][inst_reg_num] + inst_address_num;
        end else if (inst_op == `OPCODE_REG_MINUS) begin
          $display($time, " opcode = regminusnum value ", inst_address_num,  //DEBUG info
                   " to reg ",  //DEBUG info
                   inst_reg_num);  //DEBUG info
          registers[process_index][inst_reg_num] <= registers[process_index][inst_reg_num] - inst_address_num;
        end else if (inst_op == `OPCODE_TILL_VALUE ||
            inst_op == `OPCODE_TILL_NON_VALUE ||
            inst_op == `OPCODE_LOOP) begin
          $display($time, " opcode = tillorloop ", inst_address_num % 256,  //DEBUG info
                   " instructions, comp. value ", inst_address_num / 256,  //DEBUG info
                   " reg/loop value ",  //DEBUG info
                   inst_address_num % 256);  //DEBUG info
          loop_reg_num[process_index] <= inst_reg_num;
          loop_comp_value[process_index] <= inst_address_num / 256;
          loop_counter_max[process_index] <= inst_address_num % 256;
          loop_type[process_index] <= inst_op - `OPCODE_TILL_VALUE;
        end else begin
          $display($time, " opcode = ", inst_op);  //DEBUG info
        end
        stage <= `STAGE_READ_PC1_REQUEST;
      end
      if (loop_counter_max[process_index] != 0 && loop_counter_max[process_index] == loop_counter[process_index]) begin
        if ((loop_type[process_index] == `LOOP_TILL_VALUE && 
                registers[process_index][loop_reg_num[process_index]] != loop_comp_value[process_index]) ||
            (loop_type[process_index] == `LOOP_TILL_NON_VALUE && 
                registers[process_index][loop_reg_num[process_index]] == loop_comp_value[process_index]) ||
            (loop_type[process_index] == `LOOP_FOR &&
                loop_comp_value[process_index]>0)) begin
          address_pc[process_index] <= address_pc[process_index] - loop_counter[process_index] * 2;
          loop_counter_max[process_index] <= 0;
          if (loop_type[process_index] == `LOOP_FOR)
            loop_comp_value[process_index] <= loop_comp_value[process_index] - 1;
        end else begin
          loop_counter[process_index] <= 0;
          loop_counter_max[process_index] <= 0;
        end
      end
    end
  end

  //writing to RAM
  always @(posedge clka) begin
    if (stage == `STAGE_SAVE_REG2RAM) begin
      wea   <= 0;
      stage <= `STAGE_READ_PC1_REQUEST;
    end else if (stage == `STAGE_TASK_SWITCHER) begin
      //$display($time, "          switcher save ", task_switcher_stage);
      if (task_switcher_stage == `SWITCHER_STAGE_SAVE_PC) begin
        if (`TASK_SWITCHER_DEBUG === 1) $write($time, " old reg ");  //DEBUG info
        for (i = 0; i <= 10; i = i + 1) begin  //DEBUG info
          if (`TASK_SWITCHER_DEBUG === 1)  //DEBUG info
            $write($sformatf("%02x ", registers[process_index][i]));  //DEBUG info
        end  //DEBUG info
        if (`TASK_SWITCHER_DEBUG === 1) $display("");  //DEBUG info
        if (`TASK_SWITCHER_DEBUG === 1)  //DEBUG info
          $display($time, " old pc ", address_pc[process_index]);  //DEBUG info
        if (`TASK_SWITCHER_DEBUG === 1)  //DEBUG info
          $display(  //DEBUG info
              $time, " old process ", mmu_start_process_segment, start_process_address  //DEBUG info
          );  //DEBUG info
        addra <= start_process_address + `ADDRESS_REG;
        dia <= registers[process_index][0];
        task_switcher_stage <= `SWITCHER_STAGE_SAVE_REG_0;
      end else if (task_switcher_stage >= `SWITCHER_STAGE_SAVE_REG_0 && task_switcher_stage < `SWITCHER_STAGE_SAVE_REG_31) begin
        addra <= addra + 1;
        dia <= registers[process_index][task_switcher_stage-`SWITCHER_STAGE_SAVE_REG_0];
        task_switcher_stage <= task_switcher_stage + 1;
      end else if (task_switcher_stage == `SWITCHER_STAGE_SAVE_REG_31) begin
        addrb <= start_process_address + `ADDRESS_NEXT_PROCESS;
        task_switcher_stage <= `SWITCHER_STAGE_READ_NEW_PROCESS_ADDR;
      end
    end
  end

  //reading from RAM
  always @(negedge clkb) begin
    if (stage == `STAGE_READ_PC1_RESPONSE) begin
      inst_op <= dob[15:8];
      inst_reg_num <= dob[7:0];
      address_pc[process_index] <= address_pc[process_index] + 1;
      if (loop_counter_max[process_index] != 0) begin
        inst_op_cache[process_index][loop_counter[process_index]] <= dob[15:8];
        inst_reg_num_cache[process_index][loop_counter[process_index]] <= dob[7:0];
      end
      stage <= `STAGE_READ_PC2_REQUEST;
    end else if (stage == `STAGE_READ_PC2_RESPONSE) begin
      $display($time, " ", (address_pc[process_index] - 1), "=", inst_op,  //DEBUG info
               inst_reg_num,  //DEBUG info
               dob / 256,  //DEBUG info
               dob % 256);  //DEBUG info
      inst_address_num <= dob;
      if (loop_counter_max[process_index] != 0) begin
        inst_address_num_cache[process_index][loop_counter[process_index]] <= dob;
        loop_counter[process_index] <= loop_counter[process_index] + 1;
      end
      address_pc[process_index] <= address_pc[process_index] + 1;
      stage <= `STAGE_DECODE;
    end else if (stage == `STAGE_READ_RAM2REG) begin
      $display($time, "          reg ", inst_reg_num, " = ", dob);  //DEBUG info
      registers[process_index][inst_reg_num] <= dob;
      stage <= `STAGE_READ_PC1_REQUEST;
    end else if (stage == `STAGE_TASK_SWITCHER) begin
      //$display($time, "          switcher read ", task_switcher_stage);
      if (task_switcher_stage == `SWITCHER_STAGE_READ_NEW_PROCESS_ADDR) begin
        start_process_address <= dob;
        mmu_start_process_segment <= dob / `MMU_PAGE_SIZE;
        addrb <= start_process_address + `ADDRESS_PC;
        task_switcher_stage = `SWITCHER_STAGE_READ_NEW_PC;
      end else if (task_switcher_stage == `SWITCHER_STAGE_READ_NEW_PC) begin
        address_pc[process_index] <= dob;
        addrb <= start_process_address + `ADDRESS_REG;
        task_switcher_stage = `SWITCHER_STAGE_READ_NEW_REG_0;
      end else if (task_switcher_stage >= `SWITCHER_STAGE_READ_NEW_REG_0 && task_switcher_stage < `SWITCHER_STAGE_READ_NEW_REG_31) begin
        registers[process_index][task_switcher_stage-`SWITCHER_STAGE_READ_NEW_REG_0] <= dob;
        addrb <= addrb + 1;
        task_switcher_stage <= task_switcher_stage + 1;
      end else if (task_switcher_stage == `SWITCHER_STAGE_READ_NEW_REG_31) begin
        if (`TASK_SWITCHER_DEBUG === 1) $write($time, " new reg ");  //DEBUG info
        for (i = 0; i <= 10; i = i + 1) begin  //DEBUG info
          if (`TASK_SWITCHER_DEBUG === 1)  //DEBUG info
            $write($sformatf("%02x ", registers[process_index][i]));  //DEBUG info
        end  //DEBUG info
        if (`TASK_SWITCHER_DEBUG === 1) $display("");  //DEBUG info
        if (`TASK_SWITCHER_DEBUG === 1)  //DEBUG info
          $display($time, " new pc ", address_pc[process_index]);  //DEBUG info
        if (`TASK_SWITCHER_DEBUG === 1)  //DEBUG info
          $display(  //DEBUG info
              $time, " new process ", mmu_start_process_segment, start_process_address  //DEBUG info
          );  //DEBUG info
        process_instruction_done <= 0;
        task_switcher_stage <= `SWITCHER_STAGE_WAIT;
        stage <= `STAGE_READ_PC1_REQUEST;
      end
    end
  end
endmodule

// Simple Dual-Port Block RAM with Two Clocks
// simple_dual_two_clocks.v
// standard code
module simple_dual_two_clocks (
    input clka,
    clkb,
    ena,
    enb,
    wea,
    input [9:0] addra,
    addrb,
    input [15:0] dia,
    output reg [15:0] dob
);
  reg [15:0] ram[0:1023];
  initial begin  //DEBUG info
    $readmemh("rom2.mem", ram);  //DEBUG info
  end  //DEBUG info
  always @(posedge clka) begin
    if (ena) begin
      if (wea) ram[addra] <= dia;
      //      if (wea) $display($time, " writing ", dia, " to ",addra); //DEBUG info
    end
  end
  always @(posedge clkb) begin
    if (enb) begin
      dob <= ram[addrb];
      //      $display($time, " reading ", ram[addrb], " from ",addrb); //DEBUG info
    end
  end
endmodule


`timescale 1ns / 1ps

//options below are less important than options higher //DEBUG info
`define WRITE_RAM_DEBUG 0 //1 enabled, 0 disabled //DEBUG info
`define READ_RAM_DEBUG 0 //1 enabled, 0 disabled //DEBUG info
`define REG_CHANGES_DEBUG 0 //1 enabled, 0 disabled //DEBUG info
`define MMU_CHANGES_DEBUG 1 //1 enabled, 0 disabled //DEBUG info
`define MMU_TRANSLATION_DEBUG 0 //1 enabled, 0 disabled //DEBUG info
`define TASK_SWITCHER_DEBUG 1 //1 enabled, 0 disabled //DEBUG info
`define TASK_SPLIT_DEBUG 1 //1 enabled, 0 disabled //DEBUG info

`define MMU_PAGE_SIZE 72 //how many bytes are assigned to one memory page in MMU
`define RAM_SIZE 32767
`define MMU_MAX_INDEX 455 //(`RAM_SIZE+1)/`MMU_PAGE_SIZE;

module cpu (
    input  btnc,
    clk,
    output tx
);

  //RAM
  wire ena, enb, wea;
  wire [9:0] addra, addrb;
  wire [15:0] dia;
  wire [15:0] dob;

  simple_dual_two_clocks simple_dual_two_clocks (
      .clka (clk),
      .clkb (clk),
      .ena  (ena),
      .enb  (enb),
      .wea  (wea),
      .addra(addra),
      .addrb(addrb),
      .dia  (dia),
      .dob  (dob)
  );

  stage1 stage1 (
      .clka(clk),
      .clkb(clk),
      .rst(btnc),
      .ena(ena),
      .enb(enb),
      .wea(wea),
      .addra(addra),
      .addrb(addrb),
      .dia(dia),
      .dob(dob),
      .tx(tx)
  );

endmodule

module stage1 (
    input             clka,
    clkb,
    rst,
    output reg        ena,
    enb,
    wea,
    tx,
    output reg [ 9:0] addra,
    addrb,
    output reg [15:0] dia,
    input      [15:0] dob
);

  integer i;  //DEBUG info

  /* DEBUG info */ `define SHOW_REG_DEBUG(ARG, INFO, ARG2, ARG3) \
/* DEBUG info */     if (ARG == 1) begin \
/* DEBUG info */       $write($time, INFO); \
/* DEBUG info */       for (i = 0; i <= 10; i = i + 1) begin \
/* DEBUG info */         $write($sformatf("%02x ", (i==ARG2?ARG3:registers[process_index][i]))); \
/* DEBUG info */       end \
/* DEBUG info */       $display(""); \
/* DEBUG info */     end

  /* DEBUG info */  `define SHOW_MMU_DEBUG \
/* DEBUG info */     if (`MMU_CHANGES_DEBUG == 1) begin \
/* DEBUG info */       $write($time, " mmu "); \
/* DEBUG info */       for (i = 0; i <= 10; i = i + 1) begin \
/* DEBUG info */         if (mmu_start_process_segment == i && mmu_logical_pages_memory[i]!=0) $write("s"); \
/* DEBUG info */         if (mmu_chain_memory[i] == i && mmu_logical_pages_memory[i]!=0) $write("e"); \
/* DEBUG info */         $write($sformatf("%02x-%02x ", mmu_chain_memory[i], mmu_logical_pages_memory[i])); \
/* DEBUG info */       end \
/* DEBUG info */       $display(""); \
/* DEBUG info */     end

  /* DEBUG info */  `define SHOW_TASK_INFO(ARG) \
/* DEBUG info */     if (`TASK_SWITCHER_DEBUG == 1) begin \
/* DEBUG info */          $write($time, " ",ARG," pc ", address_pc[process_index]); \
/* DEBUG info */          $display( \
/* DEBUG info */              " ",ARG," process seg/addr ", mmu_start_process_segment, process_start_address[process_index], \
/* DEBUG info */              " process index ", process_index \
/* DEBUG info */          ); \
/* DEBUG info */        end

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
  `define STAGE_DELETE_PROCESS 11
  `define STAGE_REG_INT_PROCESS 12
  `define STAGE_INT_PROCESS 14
  `define STAGE_EMPTY 15

  `define SWITCHER_STAGE_WAIT 0
  `define SWITCHER_STAGE_SAVE_PC 1 //save process info. initiated, when we need place in cache
  `define SWITCHER_STAGE_SAVE_REG_0 2 //save register. done, when we need place in cache
  //...
  `define SWITCHER_STAGE_SAVE_REG_31 33
  `define SWITCHER_STAGE_SEARCH_IN_TABLES1 34 //search for new process in cache
  `define SWITCHER_STAGE_SEARCH_IN_TABLES2 35 //search for first free place in cache
  `define SWITCHER_STAGE_READ_NEW_PROCESS_ADDR 36 //reading next process address from RAM
  `define SWITCHER_STAGE_READ_NEW_PC 37 //reading next process data into cache
  `define SWITCHER_STAGE_READ_NEW_REG_0 38
  //...
  `define SWITCHER_STAGE_READ_NEW_REG_31 70
  `define SWITCHER_STAGE_SETUP_NEW_PROCESS_ADDR_OLD 71 //setup new process address in old (existing) process
  `define SWITCHER_STAGE_SETUP_NEW_PROCESS_ADDR_NEW 72 //setup new process address in new (created) process
  `define SWITCHER_STAGE_SETUP_NEW_PROCESS_ADDR_PREV 73 //setup new process address in previous process in chain
  `define SWITCHER_STAGE_SETUP_NEW_PROCESS_ADDR_PREV2 74 //setup new process address in previous process in chain

  `define MMU_STAGE_WAIT 0
  `define MMU_STAGE_SEARCH 1
  `define MMU_STAGE_FOUND 2
  `define MMU_SEPARATE_PROCESS 3
  `define MMU_STAGE_SEARCH2 4
  `define MMU_STAGE_SEARCH3 5


  `define MAX_PROCESS_CACHE_INDEX 7 //0-7 values are saved with 3 bits in all tables below

  reg ram_save_ready;
  reg ram_read_ready;

  //current instruction - we don't need to multiply it among processes, because we don't support partially executed op before process switch
  reg [5:0] stage; //it doesn't need process index - we switch to other process after completing instruction
  reg [5:0] stage_after_mmu; //temporary value - after MMU related stage we switch to another "correct one"
  reg [7:0] inst_op;  //instruction / operation code
  reg [7:0] inst_reg_num;  //in majority cases: processed / affected register number
  reg [15:0] inst_address_num;  //in majority caes: processed / affected memory address

  reg [6:0] process_index; //process related. We cache data about n=8 processes - here we save index value for all other tables
  reg [2:0] new_process_index; //process related. Here we save index value for all other tables used during task switch
  reg [2:0] process_instruction_done; //process related. how many instructions were done for current process

  //values for all processes - need to be separated for every process
  reg process_used[0:`MAX_PROCESS_CACHE_INDEX]; //process related. We cache data about n=8 processes - here we save, if cache slot is used (1) or free (0)
  reg [15:0] process_start_address[0:`MAX_PROCESS_CACHE_INDEX]; //process related. We cache data about n=8 processes - here we save, if cache slot is used or not
  reg [9:0] address_pc[0:`MAX_PROCESS_CACHE_INDEX];  //n=2^3=8 addresses
  reg [15:0] registers[0:`MAX_PROCESS_CACHE_INDEX][0:31];  //64 8-bit registers * n=8 processes = 512 16-bit registers

  //cache used in all loops - needs to be separated for every process
  reg [7:0] inst_op_cache[0:`MAX_PROCESS_CACHE_INDEX][0:255];  // 256 * n=8 processes = 2048
  reg [7:0] inst_reg_num_cache[0:`MAX_PROCESS_CACHE_INDEX][0:255];
  reg [15:0] inst_address_num_cache[0:`MAX_PROCESS_CACHE_INDEX][0:255];

  //loop executions - need to be separate for every process
  reg [7:0] loop_counter[0:`MAX_PROCESS_CACHE_INDEX];
  reg [7:0] loop_counter_max[0:`MAX_PROCESS_CACHE_INDEX];
  reg [5:0] loop_reg_num[0:`MAX_PROCESS_CACHE_INDEX];
  reg [7:0] loop_comp_value[0:`MAX_PROCESS_CACHE_INDEX];
  reg [1:0] loop_type[0:`MAX_PROCESS_CACHE_INDEX];

  reg [15:0] task_switcher_stage;

  //interrupt support
  reg [15:0] int_process_start_segment[7:0];
  reg [15:0] int_pc[7:0];

  //MMU (Memory Management Unit)
  reg [4:0] mmu_stage;
  reg [2:0] mmu_changes_debug;  //DEBUG info

  //  reg [15:0] mmu_suspend_list_start_process_segment;  //processes, which are waiting for something (int, external ports, etc.)
  //  reg mmu_suspend_list_start_process_segment_active;  //is our list empty ?

  reg [15:0] mmu_next_start_process_address;
  reg [15:0] mmu_prev_start_process_segment;  //needs to be updated on process switch
  reg [15:0] mmu_start_process_segment;  //needs to be updated on process switch
  reg [15:0] mmu_chain_memory[0:`MMU_MAX_INDEX];  //values = next physical page index for process (last entry = the same entry)
                                                  //(note: originally last entry 0, but changed because of synth issues)
  reg [15:0] mmu_logical_pages_memory[0:`MMU_MAX_INDEX];  //values = logical process page assigned to physical page; 0 means empty page
                                                          //(in existing processes we setup value > 0 for first page with index 0 and ignore it)
  reg [15:0] mmu_index_start; // this is start index of the loop searching for free memory page; when reserving pages, increase;
                              // when deleting, setup to lowest free value

  reg [9:0] mmu_input_addr;  //address to translate
  reg [15:0] mmu_logical_index_new;  //page from mmu_input_addr
  reg [15:0] mmu_logical_index_old;  //cache with translated address
  reg [15:0] mmu_physical_index_old;  //cache with translated address

  reg [15:0] mmu_last_process_segment;  //used during search (for finding last process segment) und splitting process
  reg [15:0] mmu_old;  //used during search (for finding last process segment) und splitting process
  reg [15:0] mmu_new;  //used during search (for finding last process segment) und splitting process
  reg [15:0] mmu_new_process_start_point_segment;
  reg [15:0] mmu_separate_process_segment;
  reg [15:0] mmu_delete_process_segment;

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
  `define OPCODE_REG_INT 14 //x, int number (8 bit)
  `define OPCODE_INT 15 //x, int number (8 bit)
  `define OPCODE_INT_RET 16 //x, int number
  `define OPCODE_EXIT 17 //exit process

  `define OPCODE_JMP_PLUS 18 //x, how many instructions //todo
  `define OPCODE_JMP_MINUS 19 //x, how many instructions //todo
  `define OPCODE_FREE 20 //free ram pages x-y //todo
  `define OPCODE_FREE_LEVEL 21 //free ram pages allocated after page x (or pages with concrete level) //todo

  reg rst_done = 0;

  reg [15:0] x;
  //main processing
  always @(stage, ram_save_ready, ram_read_ready, rst, mmu_stage, new_process_index, task_switcher_stage, mmu_separate_process_segment, mmu_logical_index_old) begin
    tx <= stage;

    if (mmu_stage == `MMU_STAGE_SEARCH) begin  //searching for MMU page
      if (`MMU_TRANSLATION_DEBUG == 1)  //DEBUG info
        $display(  //DEBUG info
            $time,  //DEBUG info
            " mmu_physical_index_old ",  //DEBUG info
            mmu_physical_index_old,  //DEBUG info
            " mmu_logical_index_old ",  //DEBUG info
            mmu_logical_index_old,  //DEBUG info
            " mmu_start ",  //DEBUG info
            mmu_start_process_segment,  //DEBUG info
            " mmu_logical_index_new ",  //DEBUG info
            mmu_logical_index_new  //DEBUG info
        );  //DEBUG info
      if (mmu_logical_index_old == mmu_logical_index_new) begin
        //we have already translated address. We can use it.
        mmu_stage <= `MMU_STAGE_FOUND;
      end else begin
        //start searching page
        mmu_physical_index_old <= mmu_start_process_segment;
        mmu_logical_index_old <= mmu_logical_index_new;
        mmu_stage <= `MMU_STAGE_SEARCH2;
      end
    end else if (mmu_stage == `MMU_STAGE_FOUND) begin //page found, we can create translated address and exit.
      if (stage == `STAGE_MMU_TRANSLATE_A) begin
        addra <= mmu_physical_index_old * `MMU_PAGE_SIZE + mmu_input_addr % `MMU_PAGE_SIZE; //FIXME: bits moving and concatenation
        wea <= 1;
      end else begin
        addrb <= mmu_physical_index_old * `MMU_PAGE_SIZE + mmu_input_addr % `MMU_PAGE_SIZE;
      end
      mmu_stage <= `MMU_STAGE_WAIT;
      stage <= stage_after_mmu;
      if (`MMU_TRANSLATION_DEBUG == 1)  //DEBUG info
        $display(  //DEBUG info
            $time,  //DEBUG info
            " mmu from ",  //DEBUG info
            mmu_input_addr,  //DEBUG info
            " to ",  //DEBUG info
            (mmu_physical_index_old * `MMU_PAGE_SIZE + mmu_input_addr % `MMU_PAGE_SIZE), //DEBUG info
            " mmu_physical_index_old ",  //DEBUG info
            mmu_physical_index_old,  //DEBUG info
            " mmu_logical_index_old ",  //DEBUG info
            mmu_logical_index_old,  //DEBUG info
            " mmu_start ",  //DEBUG info
            mmu_start_process_segment,  //DEBUG info
            " mmu_logical_index_new ",  //DEBUG info
            mmu_logical_index_new  //DEBUG info
        );  //DEBUG info
      if (mmu_changes_debug == 1) begin  //DEBUG info
        `SHOW_MMU_DEBUG  //DEBUG info
      end  //DEBUG info
      mmu_changes_debug <= 0;  //DEBUG info
    end else if (mmu_stage == `MMU_STAGE_SEARCH2) begin //searching in the process memory and exiting with translated address or switching to searching free memory
      if (mmu_logical_index_new == 0 && mmu_physical_index_old == mmu_start_process_segment) begin
        //value found in current process chain
        mmu_stage <= `MMU_STAGE_FOUND;
      end else if (mmu_physical_index_old != mmu_start_process_segment && mmu_logical_pages_memory[mmu_physical_index_old]==mmu_logical_index_new) begin
        //value found in current process chain
        mmu_stage <= `MMU_STAGE_FOUND;
      end else if (mmu_chain_memory[mmu_physical_index_old] == mmu_physical_index_old) begin
        //we need to start searching first free memory page and allocate it
        mmu_last_process_segment <= mmu_physical_index_old;
        mmu_index_start <= mmu_index_start + 1;
        mmu_stage <= `MMU_STAGE_SEARCH3;
      end else begin
        //go into next memory page in process chain
        mmu_physical_index_old <= mmu_chain_memory[mmu_physical_index_old];
        mmu_logical_index_old <= mmu_logical_pages_memory[mmu_chain_memory[mmu_physical_index_old]];
      end
    end else if (mmu_stage == `MMU_STAGE_SEARCH3) begin  //allocating new memory for process
      if (mmu_logical_pages_memory[mmu_index_start] == 0) begin
        //we have free memory page. Let's allocate it and add to process chain
        if (`MMU_CHANGES_DEBUG == 1) begin  //DEBUG info
          $display($time, " mmu new page ");  //DEBUG info
          mmu_changes_debug <= 1;  //DEBUG info
        end  //DEBUG info
        mmu_chain_memory[mmu_last_process_segment] <= mmu_index_start;
        mmu_chain_memory[mmu_index_start] <= 0;
        mmu_logical_pages_memory[mmu_index_start] <= mmu_logical_index_new;
        mmu_physical_index_old <= mmu_index_start;
        mmu_stage <= `MMU_STAGE_FOUND;
      end else begin
        //FIXME: support for lack of free memory
        mmu_index_start <= mmu_index_start + 1;
      end
    end else if (ram_save_ready == 1) begin
      if (stage == `STAGE_SAVE_REG2RAM) begin
        wea   <= 0;
        stage <= `STAGE_READ_PC1_REQUEST;
      end else if (stage == `STAGE_TASK_SWITCHER) begin
        if (task_switcher_stage == `SWITCHER_STAGE_SAVE_PC) begin
          `SHOW_REG_DEBUG(`TASK_SWITCHER_DEBUG, " old reg ", 0,  //DEBUG info
                          registers[process_index][0])  //DEBUG info
          `SHOW_TASK_INFO("old")  //DEBUG info
          addra <= process_start_address[process_index] + `ADDRESS_REG;
          dia <= registers[process_index][0];
          task_switcher_stage <= `SWITCHER_STAGE_SAVE_REG_0;
        end else if (task_switcher_stage >= `SWITCHER_STAGE_SAVE_REG_0 &&  task_switcher_stage < `SWITCHER_STAGE_SAVE_REG_31) begin
          addra <= addra + 1;
          dia <= registers[process_index][task_switcher_stage-`SWITCHER_STAGE_SAVE_REG_0];
          task_switcher_stage <= task_switcher_stage + 1;
        end else if (task_switcher_stage == `SWITCHER_STAGE_SAVE_REG_31) begin
          //we saved everything. We can read new process info into cache.
          process_start_address[process_index] <= dob;
          mmu_prev_start_process_segment <= mmu_start_process_segment;
          mmu_start_process_segment <= dob / `MMU_PAGE_SIZE;
          addrb <= dob + `ADDRESS_PC;
          task_switcher_stage <= `SWITCHER_STAGE_READ_NEW_PC;
          new_process_index   <= `MAX_PROCESS_CACHE_INDEX; //we setup value != 0 to allow working always(@new_process_index) next time correctly
        end else if (task_switcher_stage == `SWITCHER_STAGE_SETUP_NEW_PROCESS_ADDR_NEW) begin //setup done during task split
          `SHOW_MMU_DEBUG  //DEBUG info
          if (`TASK_SPLIT_DEBUG == 1)  //DEBUG info
            $display(
                $time, " new process next data value = ", dia, " address ", addra
            );  //DEBUG info
          addra <= process_start_address[process_index] + `ADDRESS_NEXT_PROCESS;
          dia <= mmu_new_process_start_point_segment * `MMU_PAGE_SIZE;
          task_switcher_stage <= `SWITCHER_STAGE_SETUP_NEW_PROCESS_ADDR_OLD;
        end else if (task_switcher_stage == `SWITCHER_STAGE_SETUP_NEW_PROCESS_ADDR_OLD) begin //setup done during task split
          if (`TASK_SPLIT_DEBUG == 1)  //DEBUG info
            $display(
                $time, " old process next data value = ", dia, " address ", addra
            );  //DEBUG info
          wea   <= 0;
          stage <= `STAGE_READ_PC1_REQUEST;
        end else if (task_switcher_stage == `SWITCHER_STAGE_SETUP_NEW_PROCESS_ADDR_PREV) begin
          //switch to new process
          //we have next process address already in mmu_next_start_process_address
          wea <= 0;
          stage <= `STAGE_TASK_SWITCHER;
          task_switcher_stage <= `SWITCHER_STAGE_SEARCH_IN_TABLES1;
          new_process_index <= 0;
        end else if (task_switcher_stage == `SWITCHER_STAGE_SETUP_NEW_PROCESS_ADDR_PREV2) begin //int and int_ret setup
          //int process -> next = current process -> next
          addra <= int_process_start_segment[inst_address_num] * `MMU_PAGE_SIZE + `ADDRESS_NEXT_PROCESS;
          if (mmu_next_start_process_address == process_start_address[process_index]) begin
            dia <= int_process_start_segment[inst_address_num] * `MMU_PAGE_SIZE;
          end else begin
            dia <= mmu_next_start_process_address;
          end
          //to force jumping
          mmu_next_start_process_address <= int_process_start_segment[inst_address_num] * `MMU_PAGE_SIZE;
          //replace
          int_process_start_segment[inst_address_num] <= process_start_address[process_index] / `MMU_PAGE_SIZE;
          task_switcher_stage <= `SWITCHER_STAGE_SETUP_NEW_PROCESS_ADDR_PREV;
        end
      end
    end else if (ram_read_ready == 1) begin
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
        $write($time, $sformatf(" %02x: %02x=%02x %02x %02x %02x ",  //DEBUG info
                                process_start_address[process_index],  //DEBUG info
                                (address_pc[process_index] - 1), inst_op,
                                inst_reg_num,  //DEBUG info
                                dob / 256,  //DEBUG info
                                dob % 256), "        ");  //DEBUG info
        inst_address_num <= dob;
        if (loop_counter_max[process_index] != 0) begin
          inst_address_num_cache[process_index][loop_counter[process_index]] <= dob;
          loop_counter[process_index] <= loop_counter[process_index] + 1;
        end
        address_pc[process_index] <= address_pc[process_index] + 1;
        stage <= `STAGE_DECODE;
      end else if (stage == `STAGE_READ_RAM2REG) begin
        `SHOW_REG_DEBUG(`REG_CHANGES_DEBUG, " reg ", inst_reg_num, dob)  //DEBUG info
        registers[process_index][inst_reg_num] <= dob;
        stage <= `STAGE_READ_PC1_REQUEST;
      end else if (task_switcher_stage == `SWITCHER_STAGE_READ_NEW_PROCESS_ADDR) begin
        if (stage == `STAGE_TASK_SWITCHER && process_start_address[process_index] == dob) begin
          task_switcher_stage <= `SWITCHER_STAGE_WAIT;
          stage <= `STAGE_READ_PC1_REQUEST;
        end else if (stage == `STAGE_TASK_SWITCHER && process_start_address[process_index] != dob) begin
          mmu_next_start_process_address <= dob;
          task_switcher_stage <= `SWITCHER_STAGE_SEARCH_IN_TABLES1;
          new_process_index <= 0;
        end else if (stage == `STAGE_REG_INT_PROCESS || stage == `STAGE_DELETE_PROCESS) begin
          mmu_next_start_process_address <= dob;
          mmu_start_process_segment <= mmu_prev_start_process_segment;
          wea <= 1;
          addra <= mmu_prev_start_process_segment * `MMU_PAGE_SIZE + `ADDRESS_NEXT_PROCESS;
          dia <= dob;
          task_switcher_stage <= `SWITCHER_STAGE_SETUP_NEW_PROCESS_ADDR_PREV;
          stage <= `STAGE_TASK_SWITCHER;
        end else if (stage == `STAGE_SEPARATE_PROCESS) begin
          mmu_next_start_process_address <= dob;
          wea <= 1;
          addra <= mmu_separate_process_segment * `MMU_PAGE_SIZE + `ADDRESS_NEXT_PROCESS;
          dia <= dob;
          task_switcher_stage <= `SWITCHER_STAGE_SETUP_NEW_PROCESS_ADDR_NEW;
          stage <= `STAGE_TASK_SWITCHER;
        end else if (stage == `STAGE_INT_PROCESS) begin  //int & int_ret
          mmu_next_start_process_address <= dob;
          //prev -> next = int process
          wea <= 1;
          addra <= mmu_prev_start_process_segment * `MMU_PAGE_SIZE + `ADDRESS_NEXT_PROCESS;
          dia <= int_process_start_segment[inst_address_num] * `MMU_PAGE_SIZE;
          task_switcher_stage <= `SWITCHER_STAGE_SETUP_NEW_PROCESS_ADDR_PREV2;
          stage <= `STAGE_TASK_SWITCHER;
        end
      end else if (stage == `STAGE_TASK_SWITCHER) begin
        if (task_switcher_stage == `SWITCHER_STAGE_READ_NEW_PC) begin
          address_pc[process_index] <= dob;
          addrb <= process_start_address[process_index] + `ADDRESS_REG;
          task_switcher_stage = `SWITCHER_STAGE_READ_NEW_REG_0;
        end else if (task_switcher_stage >= `SWITCHER_STAGE_READ_NEW_REG_0 && task_switcher_stage < `SWITCHER_STAGE_READ_NEW_REG_31) begin
          registers[process_index][task_switcher_stage-`SWITCHER_STAGE_READ_NEW_REG_0] <= dob;
          addrb <= addrb + 1;
          task_switcher_stage <= task_switcher_stage + 1;
        end else if (task_switcher_stage == `SWITCHER_STAGE_READ_NEW_REG_31) begin
          `SHOW_REG_DEBUG(`TASK_SWITCHER_DEBUG, " new reg ", 0,  //DEBUG info
                          registers[process_index][0])  //DEBUG info
          `SHOW_TASK_INFO("new")  //DEBUG info
          process_instruction_done <= 0;
          task_switcher_stage <= `SWITCHER_STAGE_WAIT;
          mmu_logical_index_old <= 1;  //fixme: we assume, that PC is started from seg. 0
          stage <= `STAGE_READ_PC1_REQUEST;
        end
      end
    end else begin
      if (stage == `STAGE_MMU_TRANSLATE_A || stage == `STAGE_MMU_TRANSLATE_B) begin
        if (mmu_changes_debug == 1) begin  //DEBUG info
          `SHOW_MMU_DEBUG  //DEBUG info
        end  //DEBUG info
        mmu_changes_debug <= 0;  //DEBUG info
        mmu_logical_index_new <= mmu_input_addr / `MMU_PAGE_SIZE; //FIXME: it's enough just to take concrete bits
        mmu_stage <= `MMU_STAGE_SEARCH;
      end else if (stage == `STAGE_READ_PC1_REQUEST) begin
        if (inst_op == `OPCODE_INT) begin
          address_pc[process_index] <= int_pc[inst_address_num];
        end
        process_instruction_done <= process_instruction_done + 1;
        if (process_instruction_done == 2) begin
          //time to switch process
          `SHOW_REG_DEBUG(`TASK_SWITCHER_DEBUG, " old reg ", 0,  //DEBUG info
                          registers[process_index][0])  //DEBUG info
          `SHOW_TASK_INFO("old")  //DEBUG info
          //first read next process address and see if we have it in cache
          addrb <= process_start_address[process_index] + `ADDRESS_NEXT_PROCESS;
          task_switcher_stage <= `SWITCHER_STAGE_READ_NEW_PROCESS_ADDR;
          stage <= `STAGE_TASK_SWITCHER;
        end else begin
          if (loop_counter[process_index] > loop_counter_max[process_index]) begin
            inst_op <= inst_op_cache[process_index][loop_counter_max[process_index]];
            inst_reg_num <= inst_reg_num_cache[process_index][loop_counter_max[process_index]];
            inst_address_num <= inst_address_num_cache[process_index][loop_counter_max[process_index]];
            loop_counter_max[process_index] <= loop_counter_max[process_index] + 1;
            address_pc[process_index] <= address_pc[process_index] + 2;
            $write($time,  //DEBUG info
                   $sformatf(" %02x: %02x=%02x %02x %02x %02x ",  //DEBUG info
                             process_start_address[process_index],  //DEBUG info
                             (address_pc[process_index] - 0), inst_op, inst_reg_num,  //DEBUG info
                             inst_address_num / 256,  //DEBUG info
                             inst_address_num % 256, " (cache)"));  //DEBUG info
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
          $display(" opcode = ram2reg address ", inst_address_num, " to reg ",  //DEBUG info
                   inst_reg_num);  //DEBUG info
          if (inst_address_num >= `ADDRESS_PROGRAM) begin
            mmu_input_addr <= inst_address_num;
            stage_after_mmu <= `STAGE_READ_RAM2REG;
            stage <= `STAGE_MMU_TRANSLATE_B;
          end else begin
            stage <= `STAGE_READ_PC1_REQUEST;
          end
        end else if (inst_op == `OPCODE_REG2RAM) begin
          $display(" opcode = reg2ram value ",  //DEBUG info
                   registers[process_index][inst_reg_num],  //DEBUG info
                   " to address ",  //DEBUG info
                   inst_address_num);  //DEBUG info
          if (inst_address_num >= `ADDRESS_PROGRAM) begin
            dia <= registers[process_index][inst_reg_num];
            mmu_input_addr <= inst_address_num;
            stage_after_mmu <= `STAGE_SAVE_REG2RAM;
            stage <= `STAGE_MMU_TRANSLATE_A;
          end else begin
            stage <= `STAGE_READ_PC1_REQUEST;
          end
        end else if (inst_op == `OPCODE_PROC) begin
          $display(" opcode = proc ", inst_reg_num,  //DEBUG info
                   " memory segments starting from segment ",  //DEBUG info
                   inst_address_num);  //DEBUG info
          if (mmu_start_process_segment == mmu_separate_process_segment) begin  //DEBUG info
            $display("error");  //DEBUG info
          end  //DEBUG info
          mmu_separate_process_segment<=  0;
          mmu_new_process_start_point_segment <= mmu_start_process_segment;
          mmu_old <= mmu_start_process_segment;
          mmu_new <= mmu_start_process_segment;
          mmu_separate_process_segment<=  mmu_chain_memory[mmu_start_process_segment];
          stage <= `STAGE_SEPARATE_PROCESS;
        end else if (inst_op == `OPCODE_EXIT) begin
          $display(" opcode = exit ");  //DEBUG info
          if (mmu_start_process_segment != mmu_prev_start_process_segment) begin
            mmu_delete_process_segment <= mmu_start_process_segment;
            stage <= `STAGE_DELETE_PROCESS;
          end
        end else if (inst_op == `OPCODE_REG_INT) begin
          $display(" opcode = reg_int ", inst_address_num);  //DEBUG info
          //setup int table
          int_process_start_segment[inst_address_num] <= mmu_start_process_segment;
          int_pc[inst_address_num] <= address_pc[process_index];
          //read next pc
          addrb <= process_start_address[process_index] + `ADDRESS_NEXT_PROCESS;
          task_switcher_stage <= `SWITCHER_STAGE_READ_NEW_PROCESS_ADDR;
          stage <= `STAGE_REG_INT_PROCESS;
        end else if (inst_op == `OPCODE_INT) begin
          $display(" opcode = int ", inst_address_num);  //DEBUG info
          if (int_process_start_segment[inst_address_num] > 0) begin
            //fixme: memory sharing
            addrb <= process_start_address[process_index] + `ADDRESS_NEXT_PROCESS;
            task_switcher_stage <= `SWITCHER_STAGE_READ_NEW_PROCESS_ADDR;
            stage <= `STAGE_INT_PROCESS;
          end else begin
            stage <= `STAGE_READ_PC1_REQUEST;
          end
        end else if (inst_op == `OPCODE_INT_RET) begin
          $display(" opcode = int_ret ");  //DEBUG info
          //fixme: memory sharing
          addrb <= process_start_address[process_index] + `ADDRESS_NEXT_PROCESS;
          task_switcher_stage <= `SWITCHER_STAGE_READ_NEW_PROCESS_ADDR;
          stage <= `STAGE_INT_PROCESS;
        end else begin
          if (inst_op == `OPCODE_JMP) begin
            $display(" opcode = jmp to ", inst_address_num);  //DEBUG info
            if (inst_address_num >= `ADDRESS_PROGRAM) begin
              address_pc[process_index] <= inst_address_num;
            end
          end else if (inst_op == `OPCODE_NUM2REG) begin
            $display(" opcode = num2reg value ", inst_address_num, " to reg ",  //DEBUG info
                     inst_reg_num);  //DEBUG info
            registers[process_index][inst_reg_num] <= inst_address_num;
          end else if (inst_op == `OPCODE_REG_PLUS) begin
            $display(" opcode = regplusnum value ", inst_address_num, " to reg ",  //DEBUG info
                     inst_reg_num);  //DEBUG info
            registers[process_index][inst_reg_num] <= registers[process_index][inst_reg_num] + inst_address_num;
          end else if (inst_op == `OPCODE_REG_MINUS) begin
            $display(" opcode = regminusnum value ", inst_address_num,  //DEBUG info
                     " to reg ",  //DEBUG info
                     inst_reg_num);  //DEBUG info
            registers[process_index][inst_reg_num] <= registers[process_index][inst_reg_num] - inst_address_num;
          end else if (inst_op == `OPCODE_TILL_VALUE ||
            inst_op == `OPCODE_TILL_NON_VALUE ||
            inst_op == `OPCODE_LOOP) begin
            $display(" opcode = tillorloop ", inst_address_num % 256,  //DEBUG info
                     " instructions, comp. value ", inst_address_num / 256,  //DEBUG info
                     " reg/loop value ",  //DEBUG info
                     inst_address_num % 256);  //DEBUG info
            loop_reg_num[process_index%32] <= inst_reg_num;
            loop_comp_value[process_index] <= inst_address_num / 256;
            loop_counter_max[process_index] <= inst_address_num % 256;
            loop_type[process_index] <= inst_op - `OPCODE_TILL_VALUE;
          end else begin
            $display(" opcode = ", inst_op, " (UNKNOWN)");  //DEBUG info
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
      end else if (stage == `STAGE_TASK_SWITCHER) begin  //task switcher cache search
        if (task_switcher_stage == `SWITCHER_STAGE_SEARCH_IN_TABLES1 && 
        process_used[new_process_index] == 1 && process_start_address[new_process_index] == mmu_next_start_process_address) begin
          //we have this in cache and can use it
          mmu_prev_start_process_segment <= mmu_start_process_segment;
          process_index <= new_process_index;
          mmu_start_process_segment <= process_start_address[process_index] / `MMU_PAGE_SIZE;
          //      `SHOW_REG_DEBUG(`TASK_SWITCHER_DEBUG, " new reg from cache ", 0,  //DEBUG info
          //                      registers[new_process_index][0])  //DEBUG info
          //      `SHOW_TASK_INFO("new")  //DEBUG info
          process_instruction_done <= 0;
          new_process_index   <= `MAX_PROCESS_CACHE_INDEX; //we setup value != 0 to allow working always(@new_process_index) next time correctly
          mmu_logical_index_old <= 1;  //fixme: we assume, that PC is started from seg. 0
          task_switcher_stage <= `SWITCHER_STAGE_WAIT;
          stage <= `STAGE_READ_PC1_REQUEST;
        end else if (task_switcher_stage == `SWITCHER_STAGE_SEARCH_IN_TABLES1 && new_process_index == `MAX_PROCESS_CACHE_INDEX) begin
          //not found. Start searching for first free slot.
          new_process_index   <= 0;
          task_switcher_stage <= `SWITCHER_STAGE_SEARCH_IN_TABLES2;
        end else if (task_switcher_stage == `SWITCHER_STAGE_SEARCH_IN_TABLES2 && process_used[new_process_index] == 0) begin
          //first free slot found. Use it.
          process_used[new_process_index] <= 1;
          process_index <= new_process_index;
          process_instruction_done <= 0;
          //read new process info
          process_start_address[new_process_index] <= mmu_next_start_process_address;
          mmu_prev_start_process_segment <= mmu_start_process_segment;
          mmu_start_process_segment <= mmu_next_start_process_address / `MMU_PAGE_SIZE;
          addrb <= mmu_next_start_process_address + `ADDRESS_PC;
          new_process_index   <= `MAX_PROCESS_CACHE_INDEX; //we setup value != 0 to allow working always(@new_process_index) next time correctly
          task_switcher_stage <= `SWITCHER_STAGE_READ_NEW_PC;
        end else if (task_switcher_stage == `SWITCHER_STAGE_SEARCH_IN_TABLES2 && new_process_index == `MAX_PROCESS_CACHE_INDEX) begin
          //not found. we replace one existing slot.
          process_index <= process_index == `MAX_PROCESS_CACHE_INDEX ? 0 : process_index + 1;
          //we need save data from cache to RAM. First PC
          addra <= process_start_address[process_index == `MAX_PROCESS_CACHE_INDEX ? 0 : process_index + 1] + `ADDRESS_PC;
          dia <= address_pc[process_index==`MAX_PROCESS_CACHE_INDEX?0 : process_index+1];
          wea <= 1;
          task_switcher_stage <= `SWITCHER_STAGE_SAVE_PC;
        end else if (task_switcher_stage == `SWITCHER_STAGE_SEARCH_IN_TABLES1 || task_switcher_stage == `SWITCHER_STAGE_SEARCH_IN_TABLES2) begin
          new_process_index <= new_process_index + 1;
        end
      end else if (stage == `STAGE_DELETE_PROCESS) begin
        mmu_logical_pages_memory[mmu_delete_process_segment] = 0;
        mmu_index_start = mmu_delete_process_segment - 1;
        `SHOW_MMU_DEBUG  //DEBUG info
        if (mmu_chain_memory[mmu_delete_process_segment] != mmu_delete_process_segment) begin
          mmu_delete_process_segment <= mmu_chain_memory[mmu_delete_process_segment];
        end else begin
          process_used[process_index] <= 0;  //mark process cache as free
          //previous process -> next = current process-> next; First read next
          addrb <= process_start_address[process_index] + `ADDRESS_NEXT_PROCESS;
          task_switcher_stage <= `SWITCHER_STAGE_READ_NEW_PROCESS_ADDR;
        end
      end else if (stage == `STAGE_SEPARATE_PROCESS) begin
        if (`TASK_SPLIT_DEBUG == 1)  //DEBUG info
          $display($time, " traversing ", mmu_separate_process_segment);  //DEBUG info
        `SHOW_MMU_DEBUG  //DEBUG info
        if (mmu_logical_pages_memory[mmu_separate_process_segment] == inst_address_num) begin
          if (`TASK_SPLIT_DEBUG == 1)  //DEBUG info
            $display($time, " first ", mmu_separate_process_segment);  //DEBUG info
          mmu_new_process_start_point_segment <= mmu_separate_process_segment;
        end
        if (mmu_chain_memory[mmu_separate_process_segment] != mmu_separate_process_segment) begin
           if (mmu_logical_pages_memory[mmu_separate_process_segment] >= inst_address_num && mmu_logical_pages_memory[mmu_separate_process_segment] < inst_address_num+inst_reg_num) begin
                mmu_chain_memory[mmu_old] <= mmu_chain_memory[mmu_separate_process_segment];
                mmu_new <= mmu_separate_process_segment;
           end else begin
             mmu_old <= mmu_separate_process_segment;
          end        
          mmu_separate_process_segment <= mmu_chain_memory[mmu_separate_process_segment];
        end else if ((mmu_logical_pages_memory[mmu_separate_process_segment] == inst_address_num?mmu_separate_process_segment:mmu_new_process_start_point_segment) == mmu_start_process_segment) begin
          if (`TASK_SPLIT_DEBUG == 1) $display($time, " nothing found error");  //DEBUG info
          mmu_changes_debug <= 1;  //DEBUG info
          task_switcher_stage <= `SWITCHER_STAGE_WAIT;
          stage <= `STAGE_READ_PC1_REQUEST;
        end else if (mmu_chain_memory[mmu_separate_process_segment] == mmu_separate_process_segment) begin
          if (`TASK_SPLIT_DEBUG == 1)  //DEBUG info
            $display($time, " last ", mmu_old, " ", mmu_new);  //DEBUG info
          if (mmu_new != mmu_start_process_segment) begin
            mmu_chain_memory[mmu_new] <= mmu_new;
          end
          if (mmu_old != mmu_start_process_segment) begin
            mmu_chain_memory[mmu_old] <= mmu_old;
          end
          //switch to task switcher updates
          addrb <= process_start_address[process_index] + `ADDRESS_NEXT_PROCESS;
          task_switcher_stage <= `SWITCHER_STAGE_READ_NEW_PROCESS_ADDR;
          stage <= `STAGE_SEPARATE_PROCESS;       
        end
      end else if (rst == 1 && rst_done == 0) begin
        rst_done <= 1;
        enb <= 1;
        ena <= 1;

        //problem: we shouldn't mix blocking and non-blocking
        for (
            process_index = 0;
            process_index < `MAX_PROCESS_CACHE_INDEX;
            process_index = process_index + 1
        ) begin
          process_used[process_index] <= 0;
        end
        process_used[0] <= 1;
        for (process_index = 0; process_index < 32; process_index = process_index + 1) begin
          registers[0][process_index] <= 0;
        end

        process_index <= 0;
        process_instruction_done <= 0;

        address_pc[0] <= `ADDRESS_PROGRAM;
        loop_counter[0] <= 0;
        loop_counter_max[0] <= 0;
        process_start_address[0] <= 0;
        mmu_prev_start_process_segment <= 0;
        mmu_start_process_segment <= 0;
        mmu_index_start <= 0;

        mmu_chain_memory[0] <= 0;
        //problem: we shouldn't mix blocking and non-blocking
        for (
            mmu_logical_index_new = 0;
            mmu_logical_index_new < `MMU_MAX_INDEX;
            mmu_logical_index_new = mmu_logical_index_new + 1
        ) begin
          //value 0 means, that it's empty. in every process on first entry we setup something != 0 and ignore it
          // (first process page is always from segment 0)
          mmu_logical_pages_memory[mmu_logical_index_new] <= 0;
        end
        mmu_logical_pages_memory[0] <= 1;

        //    some more complicated config used for testing //DEBUG info
        //    mmu_chain_memory[0] <= 1;  //DEBUG info
        //    mmu_chain_memory[1] <= 1;  //DEBUG info
        //    mmu_logical_pages_memory[1] <= 1;  //DEBUG info

        //some more complicated config used for testing //DEBUG info
        mmu_chain_memory[0] <= 5;  //DEBUG info
        mmu_chain_memory[5] <= 2;  //DEBUG info
        mmu_chain_memory[2] <= 1;  //DEBUG info
        mmu_chain_memory[1] <= 1;  //DEBUG info
        mmu_logical_pages_memory[5] <= 3;  //DEBUG info
        mmu_logical_pages_memory[2] <= 2;  //DEBUG info
        mmu_logical_pages_memory[1] <= 1;  //DEBUG info

        //    mmu_suspend_list_start_process_segment_active <= 0;

        mmu_changes_debug <= 1;  //DEBUG info
        mmu_stage <= `MMU_STAGE_WAIT;
        task_switcher_stage <= `SWITCHER_STAGE_WAIT;
        stage <= `STAGE_READ_PC1_REQUEST;
      end
    end
  end

  reg [15:0] update_mmu_separate_process_segment;

  //always @(update_mmu_separate_process_segment) begin
  // if (mmu_separate_process_segment!=update_mmu_separate_process_segment==0?mmu_chain_memory[mmu_start_process_segment]:mmu_chain_memory[mmu_separate_process_segment]) begin  
  //      mmu_separate_process_segment<=update_mmu_separate_process_segment==0?mmu_chain_memory[mmu_start_process_segment]:mmu_chain_memory[mmu_separate_process_segment]; //moved outside if...else...end because on synth_design issues
  //end  
  //end

  //writing to RAM
  always @(posedge clka) begin
    ram_save_ready <= ((stage == `STAGE_SAVE_REG2RAM || stage == `STAGE_TASK_SWITCHER) & wea ? 1 : 0);
  end

  //reading from RAM
  always @(negedge clkb) begin
    ram_read_ready <= (stage == `STAGE_READ_PC1_RESPONSE || stage == `STAGE_READ_PC2_RESPONSE || stage == `STAGE_READ_RAM2REG || stage == `STAGE_TASK_SWITCHER ||
        stage == `STAGE_REG_INT_PROCESS || stage == `STAGE_DELETE_PROCESS ||       stage == `STAGE_SEPARATE_PROCESS ||        stage == `STAGE_INT_PROCESS)? 1 : 0;
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

  reg [15:0] ram[0:`RAM_SIZE];

  initial begin  //DEBUG info
    $readmemh("rom4.mem", ram);  //DEBUG info
  end  //DEBUG info

  always @(posedge clka) begin
    if (ena) begin
      if (wea) ram[addra] <= dia;
      if (wea && `WRITE_RAM_DEBUG == 1)  //DEBUG info
        $display($time, " writing ", dia, " to ", addra);  //DEBUG info
    end
  end

  always @(posedge clkb) begin
    if (enb) begin
      dob <= ram[addrb];
      if (`READ_RAM_DEBUG == 1)  //DEBUG info
        $display($time, " reading ", ram[addrb], " from ", addrb);  //DEBUG info
    end
  end
endmodule


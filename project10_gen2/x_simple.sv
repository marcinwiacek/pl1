/* License: GPL3, for other please ask Marcin Wiacek */

`timescale 1ns / 1ps

parameter HOW_MANY_OP_SIMULATE = 0;  //0 means no limit
parameter HOW_MANY_OP_PER_TASK_SIMULATE = 2;
parameter HOW_BIG_PROCESS_CACHE = 3;
parameter MMU_PAGE_SIZE = 100;  //how many bytes are assigned to one memory page in MMU, current program aligned to 100

parameter HARDWARE_WORK_INSTEAD_OF_DEBUG = 1;

//options below are less important than options higher //DEBUG info
parameter HARDWARE_DEBUG = 0;

parameter RAM_WRITE_DEBUG = 0;  //1 enabled, 0 disabled //DEBUG info
parameter RAM_READ_DEBUG = 0;  //1 enabled, 0 disabled //DEBUG info
parameter REG_CHANGES_DEBUG = 0;  //1 enabled, 0 disabled //DEBUG info
parameter MMU_CHANGES_DEBUG = 0;  //1 enabled, 0 disabled //DEBUG info
parameter MMU_TRANSLATION_DEBUG = 0;  //1 enabled, 0 disabled //DEBUG info
parameter TASK_SWITCHER_DEBUG = 0;  //1 enabled, 0 disabled //DEBUG info
parameter TASK_SPLIT_DEBUG = 0;  //1 enabled, 0 disabled //DEBUG info
parameter OTHER_DEBUG = 0;  //1 enabled, 0 disabled //DEBUG info
parameter READ_DEBUG = 0;  //1 enabled, 0 disabled //DEBUG info
parameter STAGE_DEBUG = 0;
parameter OP_DEBUG = 1;
parameter OP2_DEBUG = 0;
parameter ALU_DEBUG = 0;

/* DEBUG info */ `define HARD_DEBUG(ARG) \
/* DEBUG info */     if (reset_uart_buffer_available) uart_buffer_available = 0; \
/* DEBUG info */    // if (!HARDWARE_WORK_INSTEAD_OF_DEBUG) uart_buffer[uart_buffer_available++] = ARG; \
/* DEBUG info */     if (HARDWARE_DEBUG == 1)  $write(ARG);

// verilog_format:off
/* DEBUG info */ `define HARD_DEBUG2(ARG) \
/* DEBUG info */   //  if (reset_uart_buffer_available) uart_buffer_available = 0; \
/* DEBUG info */    // if (!HARDWARE_WORK_INSTEAD_OF_DEBUG) uart_buffer[uart_buffer_available++] = ARG/16>=10? ARG/16 + 65 - 10:ARG/16+ 48; \
/* DEBUG info */    // if (!HARDWARE_WORK_INSTEAD_OF_DEBUG) uart_buffer[uart_buffer_available++] = ARG%16>=10? ARG%16 + 65 - 10:ARG%16+ 48; \
/* DEBUG info */     if (HARDWARE_DEBUG == 1) $write("%c",ARG/16>=10? ARG/16 + 65 - 10:ARG/16+ 48,"%c",ARG%16>=10? ARG%16 + 65 - 10:ARG%16+ 48);
// verilog_format:on

/* DEBUG info */ `define SHOW_REG_DEBUG(ARG, INFO, ARG2, ARG3) \
/* DEBUG info */     if (ARG == 1) begin \
/* DEBUG info */       $write($time, INFO); \
/* DEBUG info */       for (i = 0; i <= 10; i = i + 1) begin \
/* DEBUG info */         $write($sformatf("%02x ", (i==ARG2?ARG3:registers[process_index][i]))); \
/* DEBUG info */       end \
/* DEBUG info */       $display(""); \
/* DEBUG info */     end

/* DEBUG info */  `define SHOW_TASK_INFO(ARG) \
/* DEBUG info */     if (TASK_SWITCHER_DEBUG == 1 && !HARDWARE_DEBUG) begin \
/* DEBUG info */          $write($time, " ",ARG," pc ", address_pc[process_index]); \
/* DEBUG info */          $display( \
/* DEBUG info */              " ",ARG," process seg/addr ", mmu_start_process_page, process_start_address[process_index], \
/* DEBUG info */              " process index ", process_index \
/* DEBUG info */          ); \
/* DEBUG info */        end

//(* use_dsp = "yes" *) 
module plus (
    input clk,
    input [15:0] a,
    input [15:0] b,
    output bit [15:0] c
);

  bit unsigned [15:0] aa, bb, tmp1, tmp2, tmp3, tmp4;

  assign tmp1 = aa + bb;
  assign c    = tmp4;

  always @(posedge clk) begin
    aa   <= a;
    bb   <= b;
    tmp2 <= tmp1;
    tmp3 <= tmp2;
    tmp4 <= tmp3;
  end
endmodule

//(* use_dsp = "yes" *) 
module minus (
    input clk,
    input [15:0] a,
    input [15:0] b,
    output bit [15:0] c
);

  bit unsigned [15:0] aa, bb, tmp1, tmp2, tmp3, tmp4;

  assign tmp1 = aa - bb;
  assign c    = tmp4;

  always @(posedge clk) begin
    aa   <= a;
    bb   <= b;
    tmp2 <= tmp1;
    tmp3 <= tmp2;
    tmp4 <= tmp3;
  end
endmodule

//(* use_dsp = "yes" *) 
module mul (
    input clk,
    input unsigned [15:0] a,
    input unsigned [15:0] b,
    output bit unsigned [15:0] c
);

  bit unsigned [15:0] aa, bb, tmp1, tmp2, tmp3, tmp4;

  assign tmp1 = aa * bb;
  assign c    = tmp4;

  always @(posedge clk) begin
    aa   <= a;
    bb   <= b;
    tmp2 <= tmp1;
    tmp3 <= tmp2;
    tmp4 <= tmp3;
  end
endmodule

//(* use_dsp = "yes" *) 
module div (
    input clk,
    input unsigned [15:0] a,
    input unsigned [15:0] b,
    output bit unsigned [15:0] c
);

  bit unsigned [15:0] aa, bb, tmp1, tmp2, tmp3, tmp4;

  assign tmp1 = aa / bb;
  assign c    = tmp4;

  always @(posedge clk) begin
    aa   <= a;
    bb   <= b;
    tmp2 <= tmp1;
    tmp3 <= tmp2;
    tmp4 <= tmp3;
  end
endmodule

module x_simple (
    input clk,
    input bit btnc,
    output bit uart_rx_out,
    input bit uart_tx_in
);

  bit [31:0] ctn = 0;
  bit reset;

  assign reset = ctn == 1 || btnc;

  always @(posedge clk) begin
    if (ctn < 10) ctn <= ctn + 1;
  end

  bit write_enabled = 0;
  bit [15:0] write_address;
  bit [15:0] write_value;
  bit [15:0] read_address;
  wire [15:0] read_value;
  bit [15:0] read_address2;
  wire [15:0] read_value2;

  single_blockram single_blockram (
      .clk(clk),
      .write_enabled(write_enabled),
      .write_address(write_address),
      .write_value(write_value),
      .read_address(read_address),
      .read_value(read_value),
      .read_address2(read_address2),
      .read_value2(read_value2)
  );

  bit [7:0] uart_buffer[0:200];
  bit [6:0] uart_buffer_available = 0;
  wire reset_uart_buffer_available;
  wire uart_buffer_full;

  uartx_tx_with_buffer uartx_tx_with_buffer (
      .clk(clk),
      .uart_buffer(uart_buffer),
      .uart_buffer_available(uart_buffer_available),
      .reset_uart_buffer_available(reset_uart_buffer_available),
      .uart_buffer_full(uart_buffer_full),
      .tx(uart_rx_out)
  );

  wire [7:0] uart_bb;
  wire uart_bb_ready;
  bit uart_bb_processed = 0;

  uart_rx uart_rx (
      .clk(clk),
      .bb_processed(uart_bb_processed),
      .uartrx(uart_tx_in),
      .bb(uart_bb),
      .bb_ready(uart_bb_ready)
  );

  parameter OPCODE_JMP = 1;  //24 bit target address
  parameter OPCODE_JMP16 = 2;  //x, register num with target addr (we read one reg)
  //  parameter OPCODE_JMP32 = 3;  //x, first register num with target addr (we read two reg)
  //  parameter OPCODE_JMP64 = 4;  //x, first register num with target addr (we read four reg)  
  parameter OPCODE_JMP_PLUS = 5;  //x, 16 bit how many instructions
  parameter OPCODE_JMP_PLUS16 = 6;  //x, register num with info (we read one reg)
  parameter OPCODE_JMP_MINUS = 7;  //x, 16 bit how many instructions  
  parameter OPCODE_JMP_MINUS16 = 8;  //x, register num with info (we read one reg)
  parameter OPCODE_RAM2REG = 9;  //register num (5 bits), how many-1 (3 bits), 16 bit source addr //ram -> reg
  parameter OPCODE_RAM2REG16 = 'ha; //start register num, how many registers, register num with source addr (we read one reg), //ram -> reg  
  //  parameter OPCODE_RAM2REG32 = 11; //start register num, how many registers, first register num with source addr (we read two reg), //ram -> reg
  //  parameter OPCODE_RAM2REG64 = 12; //start register num, how many registers, first register num with source addr (we read four reg), //ram -> reg
  parameter OPCODE_REG2RAM = 'he; //14 //register num (5 bits), how many-1 (3 bits), 16 bit target addr //reg -> ram
  parameter OPCODE_REG2RAM16 = 'hf; //15 //start register num, how many registers, register num with target addr (we read one reg), //reg -> ram
  //  parameter OPCODE_REG2RAM32 = 16; //start register num, how many registers, first register num with target addr (we read two reg), //reg -> ram
  //  parameter OPCODE_REG2RAM64 = 17; //start register num, how many registers, first register num with target addr (we read four reg), //reg -> ram
  parameter OPCODE_NUM2REG = 'h12; //18;  //register num (5 bits), how many-1 (3 bits), 16 bit value //value -> reg
  parameter OPCODE_REG_PLUS = 'h14;//20; //register num (5 bits), how many-1 (3 bits), 16 bit value // reg += value
  parameter OPCODE_REG_MINUS = 'h15; //register num (5 bits), how many-1 (3 bits), 16 bit value  //reg -= value
  parameter OPCODE_REG_MUL = 'h16; //register num (5 bits), how many-1 (3 bits), 16 bit value // reg *= value
  parameter OPCODE_REG_DIV ='h17; //register num (5 bits), how many-1 (3 bits), 16 bit value  //reg /= value
  parameter OPCODE_EXIT = 'h18;  //exit process
  parameter OPCODE_PROC = 'h19;  //new process //how many pages, start page number (16 bit)
  parameter OPCODE_REG_INT = 'h1a;  //int number (8 bit), start memory page, end memory page 
  parameter OPCODE_INT = 'h1b;  //int number (8 bit), start memory page, end memory page
  parameter OPCODE_INT_RET = 'h1c;  //int number
  parameter OPCODE_RAM2OUT = 'h1d;  //port number, 16 bit source address
  parameter OPCODE_REG_IN2RAM = 'h1e;  //port number, 16 bit source address
  parameter OPCODE_IN2RAM_RET = 'h1f;

  parameter OPCODE_TILL_VALUE =23;   //register num (8 bit), value (8 bit), how many instructions (8 bit value) // do..while
  parameter OPCODE_TILL_NON_VALUE=24;   //register num, value, how many instructions (8 bit value) //do..while
  parameter OPCODE_LOOP = 25;  //x, x, how many instructions (8 bit value) //for...
  parameter OPCODE_FREE = 31;  //free ram pages x-y 
  parameter OPCODE_FREE_LEVEL =32; //free ram pages allocated after page x (or pages with concrete level)
  //parameter OPCODE_REG_INT_NON_BLOCKING =33; //int number (8 bit), address to jump in case of int

  parameter STAGE_AFTER_RESET = 1;
  parameter STAGE_GET_1_BYTE = 2;
  parameter STAGE_CHECK_MMU_ADDRESS = 3;
  parameter STAGE_CHECK_MMU_ADDRESS2 = 4;
  parameter STAGE_CHECK_MMU_ADDRESS3 = 5;
  parameter STAGE_SET_PC = 6;  //jump instructions
  parameter STAGE_GET_PARAM_BYTE = 7;
  parameter STAGE_SET_PARAM_BYTE = 8;
  parameter STAGE_GET_RAM_BYTE = 9;
  parameter STAGE_SET_RAM_BYTE = 10;
  parameter STAGE_SET_ONE_RAM_BYTE = 11;
  parameter STAGE_HLT = 12;
  parameter STAGE_ALU = 14;
  parameter STAGE_DELETE_PROCESS = 15;
  parameter STAGE_SPLIT_PROCESS = 16;
  parameter STAGE_SPLIT_PROCESS2 = 17;
  parameter STAGE_SPLIT_PROCESS3 = 18;
  parameter STAGE_SPLIT_PROCESS4 = 19;
  parameter STAGE_SPLIT_PROCESS5 = 20;
  parameter STAGE_SPLIT_PROCESS6 = 21;
  parameter STAGE_REG_INT = 22;
  parameter STAGE_REG_INT2 = 23;
  parameter STAGE_INT = 24;
  parameter STAGE_SET_PORT = 25;
  parameter STAGE_READ_SAVE_PC = 26;
  parameter STAGE_READ_REG = 27;
  parameter STAGE_READ_NEXT_NEXT_PROCESS = 28;
  parameter STAGE_SAVE_NEXT_PROCESS = 29;
  parameter STAGE_SAVE_NEXT_PROCESS2 = 30;
  parameter STAGE_TASK_SWITCHER = 31;
  parameter STAGE_TASK_SWITCHER2 = 32;
  parameter STAGE_TASK_SWITCHER3 = 33;
  parameter STAGE_READ_SAVE_REG_USED = 34;

  parameter STAGE_REG_PORT = 35;

  parameter ALU_ADD = 1;
  parameter ALU_DEC = 2;
  parameter ALU_DIV = 3;
  parameter ALU_MUL = 4;
  parameter ALU_SET = 5;

  parameter ERROR_NONE = 0;
  parameter ERROR_WRONG_ADDRESS = 1;
  parameter ERROR_DIVIDE_BY_ZERO = 2;
  parameter ERROR_WRONG_REG_NUM = 3;
  parameter ERROR_WRONG_OPCODE = 4;

  //offsets for process info in segment 0
  parameter ADDRESS_NEXT_PROCESS = 0;
  parameter ADDRESS_PC = 4;
  parameter ADDRESS_REG_USED = 8;
  parameter ADDRESS_REG = 10;
  parameter ADDRESS_MMU_LEN = ADDRESS_REG + 32;
  parameter ADDRESS_MMU_NEXT_SEGMENT = ADDRESS_REG + 32 + 7;
  parameter ADDRESS_PROGRAM = ADDRESS_REG + 32 + 7 + 1;

  bit [20:0] instructions;  //how many instructions in total were executed
  bit [4:0] how_many = 1;  //how many instructions in current process were executed
  bit rst_can_be_done = 1;

  //all processes (including current)
  bit [15:0]
      pc[0:HOW_BIG_PROCESS_CACHE-1],  //logical pc address
      physical_pc[0:HOW_BIG_PROCESS_CACHE-1],  //physical pc address
      mmu_page_offset[0:HOW_BIG_PROCESS_CACHE-1],  //info, how many bytes till end of memory page
      process_address[0:HOW_BIG_PROCESS_CACHE-1];
  bit process_used[0:2];
  bit [5:0] error_code[0:2];
  bit [15:0] registers[0:2][0:31];  //512 bits = 32 x 16-bit registers
  bit [0:31] registers_updated[0:2];

  //current process
  bit [4:0] process_num = 0, temp_process_num;  //index for tables above
  bit [15:0] prev_process_address = 0, next_process_address = 0;
  bit [0:31] temp_registers_updated;

  //instruction execution
  bit [7:0] stage, stage_after_mmu;
  bit [5:0] ram_read_save_reg_start, ram_read_save_reg_end;
  bit [7:0] alu_op, alu_num;
  bit [7:0] instruction1_1;
  bit [7:0] instruction1_2;
  bit [4:0] instruction1_2_1;
  bit [2:0] instruction1_2_2;
  bit [7:0] instruction2_1;
  bit [7:0] instruction2_2;

  assign instruction1_1   = read_value[15:8];
  assign instruction1_2   = read_value[7:0];
  assign instruction1_2_1 = read_value[4:0];
  assign instruction1_2_2 = read_value[7:5];
  assign instruction2_1   = read_value2[15:8];
  assign instruction2_2   = read_value2[7:0];

  bit unsigned [15:0] mul_a, mul_b;
  wire [15:0] mul_c;
  bit [15:0] div_a, div_b;
  wire [15:0] div_c;
  bit [15:0] plus_a, plus_b;
  wire [15:0] plus_c;
  bit [15:0] minus_a, minus_b;
  wire [15:0] minus_c;

  mul mul (
      .clk(clk),
      .a  (mul_a),
      .b  (mul_b),
      .c  (mul_c)
  );
  div div (
      .clk(clk),
      .a  (div_a),
      .b  (div_b),
      .c  (div_c)
  );
  plus plus (
      .clk(clk),
      .a  (plus_a),
      .b  (plus_b),
      .c  (plus_c)
  );
  minus minus (
      .clk(clk),
      .a  (minus_a),
      .b  (minus_b),
      .c  (minus_c)
  );

  bit [15:0] int_pc[0:255];
  bit [15:0] int_process_address[0:255];

  bit mmu_inside_int = 0;
  bit [15:0]
      mmu_source_start_shared_page,  //caller
      mmu_source_end_shared_page,
      mmu_target_start_shared_page,  //called process
      mmu_target_end_shared_page;
  bit [15:0] mmu_int_num;

  bit mmu_free_page[0:19] = {1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
  bit [15:0] mmu_address_a, mmu_address_b, mmu_address_c, mmu_address_d;
  bit [15:0] mmu_address_segment_to_search;

  assign mmu_address_segment_to_search = mmu_address_a / MMU_PAGE_SIZE;

  bit port_registered[0:255];
  bit [15:0] port_pc[0:255];
  bit [15:0] port_process_address[0:255];
  bit inside_port = 0;

  `define MAKE_MMU_SEARCH(ARG, ARG2) \
      mmu_address_a <= ARG; \
      stage_after_mmu <= ARG2; \
      stage <= STAGE_CHECK_MMU_ADDRESS;

  `define MAKE_MMU_SEARCH2 \
        if (how_many==HOW_MANY_OP_PER_TASK_SIMULATE && process_address[process_num] != next_process_address) begin \
        how_many <= 0; \
        stage <= STAGE_TASK_SWITCHER; \
      end else begin \
        how_many <= how_many + 1; \
        if (mmu_page_offset[process_num] == 2) begin \
          mmu_address_a <= pc[process_num]; \
          stage_after_mmu <= STAGE_GET_1_BYTE; \
          stage <= STAGE_CHECK_MMU_ADDRESS; \
        end else begin \
          mmu_page_offset[process_num] <= mmu_page_offset[process_num] - 2; \
          read_address  <= physical_pc[process_num] + 2; \
          read_address2 <= physical_pc[process_num] + 3; \
          stage <= STAGE_GET_1_BYTE; \
          physical_pc[process_num] <= physical_pc[process_num] + 2; \
        end \
      end

  `define MAKE_SWITCH_TASK(ARG) \
     if (ARG==0) how_many <= 0; \
     if (next_process_address == process_address[process_num] && stage != STAGE_HLT) begin\
       stage <= STAGE_HLT;\
     end else begin\
       if (TASK_SWITCHER_DEBUG && !HARDWARE_DEBUG) \
            $display("\n\n",$time, " TASK SWITCHER from ", process_address[process_num], " to ", next_process_address); \
       for (i=0;i<HOW_BIG_PROCESS_CACHE;i=i+1) begin \
         if (TASK_SWITCHER_DEBUG && !HARDWARE_DEBUG) $display ("cache ",process_used[i]," ", process_address[i]);\
         if (process_used[i]) begin \
           if (process_address[i] == next_process_address) begin \
              prev_process_address <= process_address[process_num]; \
              process_num <= i; \
              if (TASK_SWITCHER_DEBUG && !HARDWARE_DEBUG)   $display ("found ",i);\
           end \
         end else begin \
           temp_process_num<= i; \
         end \
       end \
       write_enabled <= ARG; \
       read_address <= next_process_address + ADDRESS_PC; \
       stage <= STAGE_READ_SAVE_PC; \
       mmu_address_a <= next_process_address / MMU_PAGE_SIZE;\
     end

  integer i;  //DEBUG info

  always @(negedge clk) begin
    if (reset == 1 && rst_can_be_done == 1) begin
      write_enabled   <= 0;
      rst_can_be_done <= 0;
      if (OTHER_DEBUG && !HARDWARE_DEBUG) $display($time, " reset");  //DEBUG info

      error_code <= '{default: 0};
      registers <= '{default: 0};
      registers_updated <= '{default: 0};

      instructions <= 0;

      process_used = '{default: 0};

      stage <= STAGE_AFTER_RESET;
    end else if (stage == STAGE_AFTER_RESET) begin
      temp_process_num <= 0;
      process_num <= 0;
      process_used[0] <= 1;
      process_address[0] <= 0;
      error_code[0] <= ERROR_NONE;
      pc[0] <= ADDRESS_PROGRAM;
      physical_pc[0] <= ADDRESS_PROGRAM;
      mmu_page_offset[0] <= MMU_PAGE_SIZE - ADDRESS_PROGRAM;

      read_address <= ADDRESS_PROGRAM; //we start from page number 0 in first process, don't need MMU translation
      read_address2 <= ADDRESS_PROGRAM + 1;

      next_process_address <= 2 * MMU_PAGE_SIZE;

      uart_buffer_available = 0;
      `HARD_DEBUG("\n");  //DEBUG info
      `HARD_DEBUG("S");  //DEBUG info

      rst_can_be_done <= 1;
      stage <= STAGE_GET_1_BYTE;
    end else if (stage == STAGE_HLT) begin
      if (uart_bb_ready && port_registered[0] && !uart_bb_processed) begin
        next_process_address <= port_process_address[0];
        `MAKE_SWITCH_TASK(1);
      end
    end else if (instructions <= HOW_MANY_OP_SIMULATE && error_code[process_num] == ERROR_NONE) begin
      if (STAGE_DEBUG && !HARDWARE_DEBUG) begin  //DEBUG info
        $write($time, " stage ", stage, " ");  //DEBUG info
        case (stage)  //DEBUG info
          STAGE_AFTER_RESET: $write("STAGE_AFTER_RESET");  //DEBUG info
          STAGE_GET_1_BYTE: $write("STAGE_GET_1_BYTE");  //DEBUG info
          STAGE_CHECK_MMU_ADDRESS: $write("STAGE_CHECK_MMU_ADDRESS");  //DEBUG info
          STAGE_CHECK_MMU_ADDRESS2: $write("STAGE_CHECK_MMU_ADDRESS2");  //DEBUG info
          STAGE_CHECK_MMU_ADDRESS3:
          $write("STAGE_CHECK_MMU_ADDRESS3");  //DEBUG info                    
          STAGE_SET_PC: $write("STAGE_SET_PC");  //DEBUG info
          STAGE_GET_PARAM_BYTE: $write("STAGE_GET_PARAM_BYTE");  //DEBUG info
          STAGE_SET_PARAM_BYTE: $write("STAGE_SET_PARAM_BYTE");  //DEBUG info
          STAGE_GET_RAM_BYTE: $write("STAGE_GET_RAM_BYTE");  //DEBUG info
          STAGE_SET_RAM_BYTE: $write("STAGE_SET_RAM_BYTE");  //DEBUG info
          STAGE_SET_ONE_RAM_BYTE: $write("STAGE_SET_ONE_RAM_BYTE");  //DEBUG info
          STAGE_HLT: $write("STAGE_HLT");  //DEBUG info
          STAGE_ALU: $write("STAGE_ALU");  //DEBUG info
          STAGE_DELETE_PROCESS: $write("STAGE_DELETE_PROCESS");  //DEBUG info
          STAGE_SPLIT_PROCESS: $write("STAGE_SPLIT_PROCESS");  //DEBUG info
          STAGE_SPLIT_PROCESS2: $write("STAGE_SPLIT_PROCESS2");  //DEBUG info
          STAGE_SPLIT_PROCESS3: $write("STAGE_SPLIT_PROCESS3");  //DEBUG info
          STAGE_SPLIT_PROCESS4: $write("STAGE_SPLIT_PROCESS4");  //DEBUG info
          STAGE_SPLIT_PROCESS5: $write("STAGE_SPLIT_PROCESS5");  //DEBUG info
          STAGE_SPLIT_PROCESS6: $write("STAGE_SPLIT_PROCESS6");  //DEBUG info
          STAGE_REG_INT: $write("STAGE_REG_INT");  //DEBUG info
          STAGE_REG_INT2: $write("STAGE_REG_INT2");  //DEBUG info
          STAGE_INT: $write("STAGE_INT");  //DEBUG info
          STAGE_SET_PORT: $write("STAGE_SET_PORT");  //DEBUG info
          STAGE_READ_SAVE_PC: $write("STAGE_READ_SAVE_PC");  //DEBUG info
          STAGE_READ_REG: $write("STAGE_READ_REG");  //DEBUG info
          STAGE_READ_NEXT_NEXT_PROCESS: $write("STAGE_READ_NEXT_NEXT_PROCESS");  //DEBUG info
          STAGE_SAVE_NEXT_PROCESS: $write("STAGE_SAVE_NEXT_PROCESS");  //DEBUG info
          STAGE_SAVE_NEXT_PROCESS2: $write("STAGE_SAVE_NEXT_PROCESS2");  //DEBUG info
          STAGE_TASK_SWITCHER: $write("STAGE_TASK_SWITCHER");  //DEBUG info
          STAGE_TASK_SWITCHER2: $write("STAGE_TASK_SWITCHER2");  //DEBUG info
          STAGE_TASK_SWITCHER3: $write("STAGE_TASK_SWITCHER3");  //DEBUG info
          STAGE_READ_SAVE_REG_USED: $write("STAGE_READ_SAVE_REG_USED");  //DEBUG info          
        endcase  //DEBUG info
        $display(" pc ", pc[process_num]);  //DEBUG info
      end
      // $display($time, process_numbers);  //DEBUG info
      // (*parallel_case *)(*full_case *) 
      case (stage)
        STAGE_GET_1_BYTE: begin
          write_enabled <= 0;
          if (READ_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
            $display(  //DEBUG info
                $time,  //DEBUG info
                " read ready ",  //DEBUG info
                read_address,  //DEBUG info
                "=",  //DEBUG info
                read_value,  //DEBUG info
                " ",  //DEBUG info
                read_address2,  //DEBUG info
                "=",  //DEBUG info
                read_value2  //DEBUG info
            );  //DEBUG info
          `HARD_DEBUG("a");  //DEBUG info
          if (OP_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
            $display(  //DEBUG info
                $time,  //DEBUG info
                process_address[process_num],  //DEBUG info
                " pc ",  //DEBUG info
                (pc[process_num]),  //DEBUG info
                " b1 %c",  //DEBUG info
                instruction1_1 / 16 >= 10 ? instruction1_1 / 16 + 65 - 10 : instruction1_1 / 16 + 48, //DEBUG info
                "%c",  //DEBUG info
                instruction1_1 % 16 >= 10 ? instruction1_1 % 16 + 65 - 10 : instruction1_1 % 16 + 48, //DEBUG info
                "%c",  //DEBUG info
                instruction1_2 / 16 >= 10 ? instruction1_2 / 16 + 65 - 10 : instruction1_2 / 16 + 48, //DEBUG info
                "%c",  //DEBUG info
                instruction1_2 % 16 >= 10 ? instruction1_2 % 16 + 65 - 10 : instruction1_2 % 16 + 48, //DEBUG info
                "h (",  //DEBUG info
                instruction1_2_1,  //DEBUG info
                "-",  //DEBUG info
                instruction1_2_2,  //DEBUG info
                ") b2 ",  //DEBUG info
                read_value2,  //DEBUG info
                " (",
                instruction2_1,
                "-",
                instruction2_2,
                ")"
            );  //DEBUG info
          pc[process_num] <= pc[process_num] + 2;
          `HARD_DEBUG2(instruction1_1);  //DEBUG info
          `HARD_DEBUG2(instruction1_2);  //DEBUG info
          //(*parallel_case *) (*full_case *) 
          case (instruction1_1)
            //24 bit target address
            OPCODE_JMP: begin
              if ((read_value2 + (256 * 256) * instruction1_2) % 2 == 1) begin
                error_code[process_num] <= ERROR_WRONG_ADDRESS;
              end else begin
                if (OP2_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
                  $display(  //DEBUG info
                      $time,
                      " opcode = jmp to ",
                      (read_value2 + (256 * 256) * instruction1_2)  //DEBUG info
                  );  //DEBUG info
                pc[process_num] <= (read_value2 + (256 * 256) * instruction1_2);
                stage <= STAGE_SET_PC;
              end
            end
            //x, register num with target addr (we read one reg)
            OPCODE_JMP16: begin
              if (read_value2 >= 32) begin
                error_code[process_num] <= ERROR_WRONG_REG_NUM;
              end else if ((registers[process_num][read_value2] - 1) % 2 == 1) begin
                error_code[process_num] <= ERROR_WRONG_ADDRESS;
              end else begin
                if (OP2_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
                  $display(  //DEBUG info
                      $time,
                      " opcode = jmp to ",
                      (registers[process_num][read_value2] - 1)  //DEBUG info
                  );  //DEBUG info
                pc[process_num] <= registers[process_num][read_value2];
                stage <= STAGE_SET_PC;
              end
            end
            //x, register num with target addr (we read one reg)
            OPCODE_JMP_PLUS: begin
              if (OP2_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
                $display(  //DEBUG info
                    $time,  //DEBUG info
                    " opcode = jmp plus to ",  //DEBUG info
                    pc[process_num] + read_value2 * 2 - 1,  //DEBUG info
                    " (",  //DEBUG info
                    read_value2,  //DEBUG info
                    " instructions)"  //DEBUG info
                );  //DEBUG info      
              pc[process_num] <= pc[process_num] + read_value2 * 2 - 1;
              stage <= STAGE_SET_PC;
            end
            //x, register num with info (we read one reg)
            OPCODE_JMP_PLUS16: begin
              if (read_value2 >= 32) begin
                error_code[process_num] <= ERROR_WRONG_REG_NUM;
              end else begin
                if (OP2_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
                  $display(  //DEBUG info
                      $time,  //DEBUG info
                      " opcode = jmp plus16 to ",  //DEBUG info
                      pc[process_num] + registers[process_num][read_value2] * 2 - 1,  //DEBUG info
                      " (",  //DEBUG info
                      registers[read_value2],  //DEBUG info
                      " instructions)"  //DEBUG info
                  );  //DEBUG info
                pc[process_num] <= pc[process_num] + registers[process_num][read_value2] * 2 - 1;
                stage <= STAGE_SET_PC;
              end
            end
            //x, 16 bit how many instructions
            OPCODE_JMP_MINUS: begin
              if (pc[process_num] - read_value2 * 2 < ADDRESS_PROGRAM) begin
                error_code[process_num] <= ERROR_WRONG_ADDRESS;
              end else begin
                if (OP2_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
                  $display(  //DEBUG info
                      $time,  //DEBUG info
                      " opcode = jmp minus to ",  //DEBUG info
                      pc[process_num] - read_value2 * 2 - 1,  //DEBUG info
                      " (",  //DEBUG info
                      read_value2,  //DEBUG info
                      " instructions)"  //DEBUG info
                  );  //DEBUG info
                pc[process_num] <= pc[process_num] - read_value2 * 2 - 1;
                stage <= STAGE_SET_PC;
              end
            end
            //x, register num with info (we read one reg)
            OPCODE_JMP_MINUS16: begin
              if (read_value2 >= 32) begin
                error_code[process_num] <= ERROR_WRONG_REG_NUM;
              end else if (pc[process_num] - registers[process_num][read_value2] * 2 < ADDRESS_PROGRAM) begin
                error_code[process_num] <= ERROR_WRONG_ADDRESS;
              end else begin
                if (OP2_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
                  $display(  //DEBUG info
                      $time,  //DEBUG info
                      " opcode = jmp minus16 to ",  //DEBUG info
                      pc[process_num] - registers[process_num][read_value2] * 2 - 1,  //DEBUG info
                      " (",  //DEBUG info
                      registers[read_value2],  //DEBUG info
                      " instructions)"  //DEBUG info
                  );  //DEBUG info
                pc[process_num] <= pc[process_num] - registers[process_num][read_value2] * 2 - 1;
                stage = STAGE_SET_PC;
              end
            end
            //register num (5 bits), how many-1 (3 bits), 16 bit source addr //ram -> reg
            OPCODE_RAM2REG: begin
              if (instruction1_2_1 + instruction1_2_2 >= 32) begin
                error_code[process_num] <= ERROR_WRONG_REG_NUM;
              end else if (read_value2 < ADDRESS_PROGRAM) begin
                error_code[process_num] <= ERROR_WRONG_ADDRESS;
              end else begin
                if (OP2_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
                  $display(  //DEBUG info
                      $time,  //DEBUG info
                      " opcode = ram2reg read value from address ",  //DEBUG info
                      read_value2,  //DEBUG info
                      "+ to reg ",  //DEBUG info
                      instruction1_2_1,  //DEBUG info
                      "-",  //DEBUG info
                      (instruction1_2_1 + instruction1_2_2)  //DEBUG info
                  );  //DEBUG info
                ram_read_save_reg_start <= instruction1_2_1;
                ram_read_save_reg_end   <= instruction1_2_1 + instruction1_2_2;
                `MAKE_MMU_SEARCH(read_value2, STAGE_GET_RAM_BYTE);
              end
            end
            //start register num, how many registers, register num with source addr (we read one reg), //ram -> reg
            OPCODE_RAM2REG16: begin
              if (instruction1_2 + instruction2_1 >= 32 || instruction2_2 >= 32) begin
                error_code[process_num] <= ERROR_WRONG_REG_NUM;
              end else if (read_value2 < ADDRESS_PROGRAM) begin
                error_code[process_num] <= ERROR_WRONG_ADDRESS;
              end else begin
                if (OP2_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
                  $display(  //DEBUG info
                      $time,  //DEBUG info
                      " opcode = ram2reg16 read from ram (address ",  //DEBUG info
                      registers[instruction2_2],  //DEBUG info
                      "+) to reg ",  //DEBUG info
                      instruction1_2,  //DEBUG info
                      "-",  //DEBUG info
                      (instruction1_2 + instruction2_1)  //DEBUG info
                  );  //DEBUG info
                ram_read_save_reg_start <= instruction1_2;
                ram_read_save_reg_end   <= instruction1_2 + instruction2_1;
                `MAKE_MMU_SEARCH(registers[process_num][instruction2_2], STAGE_GET_RAM_BYTE);
              end
            end
            //register num (5 bits), how many-1 (3 bits), 16 bit target addr //reg -> ram
            OPCODE_REG2RAM: begin
              if (instruction1_2_1 + instruction1_2_2 >= 32) begin
                error_code[process_num] <= ERROR_WRONG_REG_NUM;
              end else if (read_value2 < ADDRESS_PROGRAM) begin
                error_code[process_num] <= ERROR_WRONG_ADDRESS;
              end else begin
                if (OP2_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
                  $display(  //DEBUG info
                      $time,  //DEBUG info
                      " opcode = reg2ram save reg ",  //DEBUG info
                      instruction1_2_1,  //DEBUG info
                      "-",  //DEBUG info
                      (instruction1_2_1 + instruction1_2_2),  //DEBUG info
                      " to ram address ",  //DEBUG info
                      read_value2,  //DEBUG info
                      "+"  //DEBUG info
                  );  //DEBUG info
                ram_read_save_reg_start <= instruction1_2_1;
                ram_read_save_reg_end <= instruction1_2_1 + instruction1_2_2;
                write_value <= registers[process_num][instruction1_2_1];
                `MAKE_MMU_SEARCH(read_value2, STAGE_SET_RAM_BYTE);
              end
            end
            //start register num, how many registers, register num with target addr (we read one reg), //reg -> ram
            OPCODE_REG2RAM16: begin
              if (instruction1_2 + instruction2_1 >= 32 || instruction2_2 >= 32) begin
                error_code[process_num] <= ERROR_WRONG_REG_NUM;
              end else if (read_value2 < ADDRESS_PROGRAM) begin
                error_code[process_num] <= ERROR_WRONG_ADDRESS;
              end else begin
                if (OP2_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
                  $display(  //DEBUG info
                      $time,  //DEBUG info
                      " opcode = reg2ram16 save to ram (address ",  //DEBUG info
                      registers[instruction2_2],  //DEBUG info
                      "+) from reg ",  //DEBUG info
                      instruction1_2,  //DEBUG info
                      "-",  //DEBUG info
                      (instruction1_2 + instruction2_1)  //DEBUG info
                  );  //DEBUG info
                ram_read_save_reg_start <= instruction1_2;
                ram_read_save_reg_end <= instruction1_2 + instruction2_1;
                write_value <= registers[process_num][instruction1_2];
                `MAKE_MMU_SEARCH(registers[process_num][instruction2_2], STAGE_SET_RAM_BYTE);
              end
            end
            //register num (5 bits), how many-1 (3 bits), 16 bit value //value -> reg
            OPCODE_NUM2REG: begin
              if (OP2_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
                $display(  //DEBUG info
                    $time,  //DEBUG info
                    " opcode = num2reg save value ",  //DEBUG info
                    read_value2,  //DEBUG info
                    " to reg ",  //DEBUG info
                    instruction1_2_1,  //DEBUG info
                    "-",  //DEBUG info
                    (instruction1_2_1 + instruction1_2_2)  //DEBUG info
                );  //DEBUG info
              alu_op  <= ALU_SET;
              alu_num <= instruction1_2_1;
              stage   <= STAGE_ALU;
            end
            //register num (5 bits), how many-1 (3 bits), 16 bit value // reg += value
            OPCODE_REG_PLUS: begin
              if (OP2_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
                $display(  //DEBUG info
                    $time,  //DEBUG info
                    " opcode = regplus add value ",  //DEBUG info
                    read_value2,  //DEBUG info
                    " to reg ",  //DEBUG info
                    instruction1_2_1,  //DEBUG info
                    "-",  //DEBUG info
                    (instruction1_2_1 + instruction1_2_2)  //DEBUG info
                );  //DEBUG info
              alu_op  <= ALU_ADD;
              alu_num <= 255;
              stage   <= STAGE_ALU;
            end
            //register num (5 bits), how many-1 (3 bits), 16 bit value // reg -= value
            OPCODE_REG_MINUS: begin
              if (OP2_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
                $display(  //DEBUG info
                    $time,  //DEBUG info
                    " opcode = regminus dec value ",  //DEBUG info
                    read_value2,  //DEBUG info
                    " to reg ",  //DEBUG info
                    instruction1_2_1,  //DEBUG info
                    "-",  //DEBUG info
                    (instruction1_2_1 + instruction1_2_2)  //DEBUG info
                );  //DEBUG info
              alu_op  <= ALU_DEC;
              alu_num <= 255;
              stage   <= STAGE_ALU;
            end
            //register num (5 bits), how many-1 (3 bits), 16 bit value // reg *= value
            OPCODE_REG_MUL: begin
              if (OP2_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
                $display(  //DEBUG info
                    $time,  //DEBUG info
                    " opcode = regmul mul value ",  //DEBUG info
                    read_value2,  //DEBUG info
                    " to reg ",  //DEBUG info
                    instruction1_2_1,  //DEBUG info
                    "-",  //DEBUG info
                    (instruction1_2_1 + instruction1_2_2)  //DEBUG info
                );  //DEBUG info
              alu_op  <= ALU_MUL;
              alu_num <= 255;
              stage   <= STAGE_ALU;
            end
            //register num (5 bits), how many-1 (3 bits), 16 bit value // reg /= value
            OPCODE_REG_DIV: begin
              if (read_value2 == 0) begin
                error_code[process_num] <= ERROR_DIVIDE_BY_ZERO;
              end else begin
                if (OP2_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
                  $display(  //DEBUG info
                      $time,  //DEBUG info
                      " opcode = regdiv div value ",  //DEBUG info
                      read_value2,  //DEBUG info
                      " to reg ",  //DEBUG info
                      instruction1_2_1,  //DEBUG info
                      "-",  //DEBUG info
                      (instruction1_2_1 + instruction1_2_2)  //DEBUG info
                  );  //DEBUG info
                alu_op <= ALU_DIV;
                stage  <= STAGE_ALU;
              end
            end
            //exit process
            OPCODE_EXIT: begin
              if (OP2_DEBUG && !HARDWARE_DEBUG) $display($time, " opcode = exit");  //DEBUG info
              write_address <= prev_process_address + ADDRESS_NEXT_PROCESS;
              write_value <= next_process_address;
              write_enabled <= 1;
              stage <= STAGE_DELETE_PROCESS;
            end
            //new process //how many pages, start page number (16 bit
            OPCODE_PROC: begin
              if (OP2_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
                $display(  //DEBUG info
                    $time,  //DEBUG info
                    " opcode = proc, process pages ",  //DEBUG info
                    read_value2,  //DEBUG info
                    "-",  //DEBUG info
                    (read_value2 + instruction1_2 - 1)  //DEBUG info
                );  //DEBUG info
              mmu_address_a <= read_value2 + 1;
              mmu_address_b <= read_value2 + instruction1_2 - 1;
              read_address <= process_address[process_num] + ADDRESS_MMU_LEN + read_value2;
              stage <= STAGE_SPLIT_PROCESS;
            end
            //int number (8 bit), start memory page, end memory page 
            OPCODE_REG_INT: begin
              if (OP2_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
                $display(
                    $time,
                    " opcode = reg_int ",
                    instruction1_2,
                    " logical pages",
                    instruction2_1,
                    "-",
                    instruction2_2
                );  //DEBUG info
              int_pc[instruction1_2] <= pc[process_num] + 2;
              int_process_address[instruction1_2] <= process_address[process_num];
              mmu_target_start_shared_page <= instruction2_1;
              mmu_target_end_shared_page <= instruction2_2;
              //delete process from chain
              write_address <= prev_process_address + ADDRESS_NEXT_PROCESS;
              write_value <= next_process_address;
              write_enabled <= 1;
              stage <= STAGE_REG_INT;
            end
            //int number (8 bit), start memory page, end memory page 
            OPCODE_INT: begin
              if (instruction2_2- instruction2_1 != mmu_source_end_shared_page-mmu_source_start_shared_page) begin
                if (OP2_DEBUG && !HARDWARE_DEBUG)
                  $display(
                      $time,
                      " ",
                      instruction2_2,
                      " ",
                      instruction2_1,
                      " ",
                      mmu_source_end_shared_page,
                      " ",
                      mmu_source_start_shared_page
                  );
                error_code[process_num] <= ERROR_WRONG_ADDRESS;
              end else begin
                if (OP2_DEBUG && !HARDWARE_DEBUG)
                  $display(
                      $time,
                      " ",
                      instruction2_2,
                      " ",
                      instruction2_1,
                      " ",
                      mmu_source_end_shared_page,
                      " ",
                      mmu_source_start_shared_page
                  );
                if (OP2_DEBUG && !HARDWARE_DEBUG)
                  $display(
                      $time,
                      " opcode = int ",
                      instruction1_2,
                      " pages ",
                      instruction2_1,
                      "-",
                      instruction2_2
                  );  //DEBUG info
                //replace current process with int process in the chain 
                write_address <= int_process_address[instruction1_2] + ADDRESS_NEXT_PROCESS;
                write_value <= next_process_address;
                write_enabled <= 1;
                stage <= STAGE_INT;
                //add shared memory from current process to int process       
                mmu_source_start_shared_page <= instruction2_1;
                mmu_source_end_shared_page <= instruction2_2;
                mmu_inside_int <= 1;
                mmu_int_num <= instruction1_2;
              end
            end
            //int number
            OPCODE_INT_RET: begin
              if (OP2_DEBUG && !HARDWARE_DEBUG) $display($time, " opcode = int_ret");  //DEBUG info
              //replace current process with int process in the chain 
              // $display($time, " opcode = int_ret ",pc[process_num]," ",int_pc[instruction1_2]," ",process_address[process_num]," ",next_process_address," ",int_process_address[instruction1_2]);
              write_address <= int_process_address[instruction1_2] + ADDRESS_NEXT_PROCESS;
              write_value <= process_address[process_num]==next_process_address?int_process_address[instruction1_2]:next_process_address;
              write_enabled <= 1;
              next_process_address<=process_address[process_num]==next_process_address?int_process_address[instruction1_2]:next_process_address;
              pc[process_num] <= int_pc[instruction1_2];
              mmu_page_offset[process_num] <= 2;  //signal, that we have to recalculate things with mmu
              stage <= STAGE_INT;
              mmu_inside_int <= 0;
            end
            //port number, 16 bit source address 
            OPCODE_RAM2OUT: begin
              if (read_value2 < ADDRESS_PROGRAM) begin
                error_code[process_num] <= ERROR_WRONG_ADDRESS;
              end else begin
                if (OP2_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
                  $display(  //DEBUG info
                      $time,  //DEBUG info
                      " opcode = ram2out read value from address ",  //DEBUG info
                      read_value2,  //DEBUG info
                      "+ to port ",  //DEBUG info
                      instruction1_2  //DEBUG info
                  );  //DEBUG info          
                `MAKE_MMU_SEARCH(read_value2, STAGE_SET_PORT);
              end
            end
            //port number, 16 bit source address
            OPCODE_REG_IN2RAM: begin
              if (OP2_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
                $display(  //DEBUG info
                    $time,  //DEBUG info
                    " opcode = REG_IN2RAM "  //DEBUG info
                );
              if (port_registered[instruction1_2] == 0) begin
                port_registered[instruction1_2] <= 1;
                port_pc[instruction1_2] <= pc[process_num];
                port_process_address[instruction1_2] <= process_address[process_num];
                //delete process from chain
                write_address <= prev_process_address + ADDRESS_NEXT_PROCESS;
                write_value <= next_process_address;
                write_enabled <= 1;
                if (OP2_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
                  $display(  //DEBUG info
                      $time,  //DEBUG info
                      " first registration "  //DEBUG info
                  );
                stage <= STAGE_REG_PORT;
              end else begin
                if (OP2_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
                  $display(  //DEBUG info
                      $time,  //DEBUG info
                      " executing "  //DEBUG info
                  );
                uart_bb_processed <= 1;
                $display(  //DEBUG info
                    $time, " setting ", uart_bb, " to addr ", read_value2);
                write_value <= uart_bb * 256;
                `MAKE_MMU_SEARCH(read_value2, STAGE_SET_ONE_RAM_BYTE);
              end
            end
            OPCODE_IN2RAM_RET: begin
              if (OP2_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
                $display(  //DEBUG info
                    $time,  //DEBUG info
                    " opcode = IN2RAM_RET "  //DEBUG info
                );
              //delete process from chain
              write_address <= prev_process_address + ADDRESS_NEXT_PROCESS;
              write_value <= next_process_address;
              write_enabled <= 1;

              pc[process_num] <= port_pc[instruction1_2];
              mmu_page_offset[process_num] <= 2;  //signal, that we have to recalculate things with mmu
              uart_bb_processed <= 0;
              `MAKE_SWITCH_TASK(0)
            end
            default: begin
              if (OP2_DEBUG && !HARDWARE_DEBUG) $display($time, " opcode = unknown");  //DEBUG info
              `MAKE_MMU_SEARCH2;
              //if (instructions == HOW_MANY_OP_SIMULATE) search_mmu_address = 0; //DEBUG info
            end
          endcase
          if (HOW_MANY_OP_SIMULATE != 0) instructions <= instructions + 1;
        end
        STAGE_REG_PORT: begin
          mmu_page_offset[process_num] <= 2;  //signal, that we have to recalculate things with mmu
          pc[process_num] <= pc[process_num] - 2;
          `MAKE_SWITCH_TASK(0)
        end
        STAGE_SET_PORT: begin
          if (OP2_DEBUG && !HARDWARE_DEBUG)
            $display($time, read_address, " value ", read_value / 256, " ", read_value % 256);
          if (read_value == 0) begin
            `MAKE_MMU_SEARCH2
          end else begin
            if (HARDWARE_WORK_INSTEAD_OF_DEBUG)
              uart_buffer[uart_buffer_available++] = read_value / 256;
            if (HARDWARE_WORK_INSTEAD_OF_DEBUG)
              uart_buffer[uart_buffer_available++] = read_value % 256;
            read_address <= read_address + 1;
          end
        end
        STAGE_GET_RAM_BYTE: begin
          registers[process_num][ram_read_save_reg_start] <= read_value;
          if (OP2_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
            $display(  //DEBUG info
                $time,  //DEBUG info
                " read value for reg ",  //DEBUG info
                ram_read_save_reg_start,  //DEBUG info
                " from address ",  //DEBUG info
                read_address,  //DEBUG info
                " = ",  //DEBUG info
                read_value  //DEBUG info
            );  //DEBUG info
          if (ram_read_save_reg_start == ram_read_save_reg_end) begin
            `MAKE_MMU_SEARCH2
          end else begin
            ram_read_save_reg_start <= ram_read_save_reg_start + 1;
            `MAKE_MMU_SEARCH(mmu_address_a + 1, STAGE_GET_RAM_BYTE);
          end
        end
        STAGE_SET_RAM_BYTE: begin
          if (ram_read_save_reg_start == ram_read_save_reg_end) begin
            if (OP2_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
              $display(  //DEBUG info
                  $time,  //DEBUG info
                  " save value ",
                  registers[process_num][ram_read_save_reg_start],
                  " from reg ",
                  ram_read_save_reg_start,
                  " to ram address ",
                  mmu_address_a
              );  //DEBUG info
            write_enabled <= 0;
            `MAKE_MMU_SEARCH2
          end else begin
            ram_read_save_reg_start <= ram_read_save_reg_start + 1;
            write_value <= registers[process_num][ram_read_save_reg_start];
            if (OP2_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
              $display(  //DEBUG info
                  $time,  //DEBUG info
                  " save value ",
                  registers[process_num][ram_read_save_reg_start+1],
                  " from reg ",
                  ram_read_save_reg_start + 1,
                  " to ram address ",
                  mmu_address_a + 1
              );  //DEBUG info
            `MAKE_MMU_SEARCH(mmu_address_a + 1, STAGE_SET_RAM_BYTE);
          end
        end
        STAGE_SET_ONE_RAM_BYTE: begin
          write_enabled <= 0;
          `MAKE_MMU_SEARCH2
        end
        STAGE_CHECK_MMU_ADDRESS: begin
          //$display(  //DEBUG info
          // $time, " mmu debug ", mmu_inside_int, " ", mmu_address_segment_to_search, " ",
          //              mmu_source_start_shared_page, " ", mmu_target_start_shared_page, " ",
          //              mmu_address_segment_to_search, " ", mmu_target_end_shared_page, " ",
          //              mmu_target_end_shared_page);
          if (mmu_address_a < MMU_PAGE_SIZE) begin
            if (MMU_TRANSLATION_DEBUG && !HARDWARE_DEBUG)
              $display(  //DEBUG info
                  $time,
                  " process ",
                  process_address[process_num],
                  " logical address ",
                  mmu_address_a,
                  "= physical address from page 0 ",
                  process_address[process_num] + mmu_address_a % MMU_PAGE_SIZE
              );
            mmu_address_c <= process_address[process_num] + mmu_address_a % MMU_PAGE_SIZE;
            if (stage_after_mmu == STAGE_SET_RAM_BYTE || stage_after_mmu == STAGE_SET_ONE_RAM_BYTE) begin
              write_address <= process_address[process_num] + mmu_address_a % MMU_PAGE_SIZE;
              write_enabled <= 1;
            end else begin
              if (stage_after_mmu == STAGE_GET_1_BYTE) begin
                mmu_page_offset[process_num] <= mmu_address_a % MMU_PAGE_SIZE;
                physical_pc[process_num] <=  process_address[process_num] + mmu_address_a % MMU_PAGE_SIZE;
              end
              read_address  <= (process_address[process_num] + mmu_address_a % MMU_PAGE_SIZE);
              read_address2 <= (process_address[process_num] + mmu_address_a % MMU_PAGE_SIZE) + 1;
              write_enabled <= 0;
            end
            stage <= stage_after_mmu;
          end else if (mmu_inside_int==1&& mmu_address_segment_to_search>=mmu_target_start_shared_page && 
             mmu_address_segment_to_search<=mmu_target_end_shared_page) begin
            write_enabled <= 0;
            if (MMU_TRANSLATION_DEBUG && !HARDWARE_DEBUG)
              $display(  //DEBUG info
                  $time, " mmu inside int"
              );
            mmu_address_b <= int_process_address[mmu_int_num];
            mmu_address_d<=mmu_source_start_shared_page + mmu_target_start_shared_page-mmu_address_segment_to_search;
            if (mmu_source_start_shared_page + mmu_target_start_shared_page-mmu_address_segment_to_search<=6) begin
              read_address<=int_process_address[mmu_int_num] + ADDRESS_MMU_LEN + 
              mmu_source_start_shared_page + mmu_target_start_shared_page-mmu_address_segment_to_search;
            end
            read_address2 <= int_process_address[mmu_int_num] + ADDRESS_MMU_LEN + 7;
            stage <= STAGE_CHECK_MMU_ADDRESS2;
          end else begin
            write_enabled <= 0;
            mmu_address_b <= process_address[process_num];
            mmu_address_d <= mmu_address_segment_to_search;
            if (mmu_address_segment_to_search <= 6) begin
              read_address<=process_address[process_num] + ADDRESS_MMU_LEN + mmu_address_segment_to_search;
            end
            read_address2 <= process_address[process_num] + ADDRESS_MMU_LEN + 7;
            stage <= STAGE_CHECK_MMU_ADDRESS2;
          end
        end
        STAGE_CHECK_MMU_ADDRESS2: begin
          if (mmu_address_d <= 6) begin
            if (mmu_address_c != 0 && read_value == 0) begin
              if (MMU_TRANSLATION_DEBUG && !HARDWARE_DEBUG)
                $display(  //DEBUG info
                    $time, " mmu needs new memory page"
                );
            end else begin
              if (MMU_TRANSLATION_DEBUG && !HARDWARE_DEBUG)
                $display(  //DEBUG info
                    $time,
                    " process ",
                    mmu_address_b,
                    " logical address ",
                    mmu_address_a,
                    "= physical address ",
                    read_value * MMU_PAGE_SIZE + mmu_address_a % MMU_PAGE_SIZE
                );
            end
            if (stage_after_mmu != STAGE_SET_RAM_BYTE && stage_after_mmu!= STAGE_SET_ONE_RAM_BYTE) begin
              if (stage_after_mmu == STAGE_GET_1_BYTE) begin
                mmu_page_offset[process_num] <= mmu_address_a % MMU_PAGE_SIZE;
                physical_pc[process_num] <=  read_value * MMU_PAGE_SIZE + mmu_address_a % MMU_PAGE_SIZE;
              end
              read_address  <= read_value * MMU_PAGE_SIZE + mmu_address_a % MMU_PAGE_SIZE;
              read_address2 <= read_value * MMU_PAGE_SIZE + mmu_address_a % MMU_PAGE_SIZE + 1;
            end else begin
              write_address <= read_value * MMU_PAGE_SIZE + mmu_address_a % MMU_PAGE_SIZE;
              write_enabled <= 1;
            end
            stage <= stage_after_mmu;
          end else begin
            if (MMU_TRANSLATION_DEBUG && !HARDWARE_DEBUG)
              $display(  //DEBUG info
                  $time, " mmu needs to traverse, segment ", mmu_address_d
              );
          end
        end
        STAGE_ALU: begin
          if (ALU_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
            $display(  //DEBUG info
                $time,  //DEBUG info
                " alu_num ",  //DEBUG info
                alu_num,  //DEBUG info
                " alu_op ",  //DEBUG info
                alu_op,  //DEBUG info
                " end ",  //DEBUG info
                (instruction1_2_1 + instruction1_2_2)  //DEBUG info
            );  //DEBUG info
          if (instruction1_2_1 + instruction1_2_2 >= 32) begin
            error_code[process_num] <= ERROR_WRONG_REG_NUM;
          end else begin
            if (alu_num == 255) begin
              alu_num <= instruction1_2_1;
            end else begin
              case (alu_op)
                ALU_SET: begin
                  if (OP2_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
                    $display($time, " set reg ", alu_num, " with ", read_value2);  //DEBUG info
                  registers[process_num][alu_num] <= read_value2;
                  registers_updated[process_num][alu_num] <= read_value2 != 0;
                  write_value <= read_value2;
                end
                ALU_ADD: begin
                  registers[process_num][alu_num] <= plus_c;
                  registers_updated[process_num][alu_num] <= plus_c != 0;
                  write_value <= plus_c;
                end
                ALU_DEC: begin
                  registers[process_num][alu_num] <= minus_c;
                  registers_updated[process_num][alu_num] <= minus_c != 0;
                  write_value <= minus_c;
                end
                ALU_MUL: begin
                  registers[process_num][alu_num] <= mul_c;
                  registers_updated[process_num][alu_num] <= mul_c != 0;
                  write_value <= mul_c;
                end
                ALU_DIV: begin
                  registers[process_num][alu_num] <= div_c;
                  registers_updated[process_num][alu_num] <= div_c != 0;
                  write_value <= div_c;
                end
              endcase
              write_address <= process_address[process_num] + ADDRESS_REG + alu_num;
              write_enabled <= 1;
              alu_num <= alu_num + 1;
            end
            if (alu_num == instruction1_2_1 + instruction1_2_2) begin
              `MAKE_MMU_SEARCH2
            end else begin
              case (alu_op)
                ALU_ADD: begin
                  plus_a = registers[process_num][alu_num];
                  plus_b = read_value2;
                end
                ALU_DEC: begin
                  minus_a = registers[process_num][alu_num];
                  minus_b = read_value2;
                end
                ALU_MUL: begin
                  mul_a = registers[process_num][alu_num];
                  mul_b = read_value2;
                end
                ALU_DIV: begin
                  div_a = registers[process_num][alu_num];
                  div_b = read_value2;
                end
              endcase
            end
          end
        end
        STAGE_TASK_SWITCHER: begin
          `HARD_DEBUG("W");
          //  $display($time, " old pc ",pc[process_num]);
          //old process
          write_address <= process_address[process_num] + ADDRESS_PC;
          write_value   <= pc[process_num];
          write_enabled <= 1;

          if (uart_bb_ready && port_registered[0] && !uart_bb_processed) begin
            stage <= STAGE_TASK_SWITCHER2;
          end else begin
            `MAKE_SWITCH_TASK(1);
          end
        end
        STAGE_TASK_SWITCHER2: begin
          write_address <= port_process_address[0] + ADDRESS_NEXT_PROCESS;
          write_value <= next_process_address;
          write_enabled <= 1;
          next_process_address <= port_process_address[0];
          stage <= STAGE_TASK_SWITCHER3;
        end
        STAGE_TASK_SWITCHER3: begin
          write_address <= process_address[process_num] + ADDRESS_NEXT_PROCESS;
          write_value   <= port_process_address[0];
          write_enabled <= 1;
          `MAKE_SWITCH_TASK(1);
        end
        STAGE_READ_SAVE_PC: begin
          if (process_used[process_num] && process_address[process_num] == next_process_address) begin
            write_enabled <= 0;
            if (TASK_SWITCHER_DEBUG && !HARDWARE_DEBUG)
              $display($time, " new process used(cache) ", process_num, " pc ", pc[process_num]);
            //read next process address and finito
            read_address <= next_process_address + ADDRESS_NEXT_PROCESS;
            stage <= STAGE_READ_NEXT_NEXT_PROCESS;
          end else begin
            if (TASK_SWITCHER_DEBUG && !HARDWARE_DEBUG)
              $display($time, " new process used ", temp_process_num, " pc ", read_value);
            //temp_registers_updated
            registers[temp_process_num] <= '{default: 0};
            //new process
            pc[temp_process_num] <= read_value;
            mmu_page_offset[temp_process_num] <= 2;  //signal, that we have to recalculate things with mmu
            read_address <= next_process_address + ADDRESS_REG_USED;
            read_address2 <= next_process_address + ADDRESS_REG_USED + 1;
            if (TASK_SWITCHER_DEBUG && !HARDWARE_DEBUG)
              $display($time, " new pc ", read_value);  //DEBUG info
            //old process
            if (TASK_SWITCHER_DEBUG && !HARDWARE_DEBUG) begin  //DEBUG info
              $write($time, " old registers updated ");  //DEBUG info
              for (i = 0; i < 32; i = i + 1) begin  //DEBUG info
                $write(registers_updated[process_num][i]);  //DEBUG info
              end  //DEBUG info
              $display("");  //DEBUG info
            end  //DEBUG info
            write_address <= process_address[process_num] + ADDRESS_REG_USED;
            write_value <= registers_updated[process_num][0:15];
            write_enabled <= 1;
            stage <= STAGE_READ_SAVE_REG_USED;
            process_used[temp_process_num] <= 1;
            if (TASK_SWITCHER_DEBUG && !HARDWARE_DEBUG)
              $display(" prev_process_address = ", process_address[process_num]);
            prev_process_address <= process_address[process_num];
          end
        end
        STAGE_READ_SAVE_REG_USED: begin
          //new process
          temp_registers_updated[0:15] <= read_value;
          temp_registers_updated[16:31] <= read_value2;
          registers_updated[temp_process_num][0:15] <= read_value;
          registers_updated[temp_process_num][16:31] <= read_value2;
          ram_read_save_reg_start <= read_value[0] ? 0 : 1;
          read_address <= next_process_address + ADDRESS_REG + (read_value[0] ? 0 : 1);
          ram_read_save_reg_end <= read_value2[15] ? 31 : 30;
          read_address2 <= next_process_address + ADDRESS_REG + (read_value2[15] ? 31 : 30);
          //old process
          write_address <= process_address[process_num] + ADDRESS_REG_USED + 1;
          write_value <= registers_updated[process_num][16:31];
          stage <= STAGE_READ_REG;
        end
        STAGE_READ_REG: begin
          if (TASK_SWITCHER_DEBUG && !HARDWARE_DEBUG) begin  //DEBUG info
            $write($time, " new registers updated ");  //DEBUG info
            for (i = 0; i < 32; i = i + 1) begin  //DEBUG info
              $write(temp_registers_updated[i]);  //DEBUG info
            end  //DEBUG info
            $display("");  //DEBUG info
            $display($time, " reading reg ", read_address, " ", ram_read_save_reg_start,
                     "=",  //DEBUG info
                     read_value, " ", read_address2, " ", ram_read_save_reg_end, "=",
                     read_value2,  //DEBUG info
                     " ");  //DEBUG info
          end  //DEBUG info
          registers[temp_process_num][ram_read_save_reg_start] <= read_value;
          registers[temp_process_num][ram_read_save_reg_end]   <= read_value2;
          if (temp_registers_updated == 0) begin
            process_num <= temp_process_num;
            //change process
            process_address[temp_process_num] <= next_process_address;
            //read next process address
            read_address <= next_process_address + ADDRESS_NEXT_PROCESS;
            stage <= STAGE_READ_NEXT_NEXT_PROCESS;
          end else begin
            if (temp_registers_updated[ram_read_save_reg_start+1]) begin
              ram_read_save_reg_start <= ram_read_save_reg_start + 1;
              read_address <= read_address + 1;
              temp_registers_updated[ram_read_save_reg_start+1] <= 0;
            end else if (temp_registers_updated[ram_read_save_reg_start+2]) begin
              ram_read_save_reg_start <= ram_read_save_reg_start + 2;
              read_address <= read_address + 2;
              temp_registers_updated[ram_read_save_reg_start+2] <= 0;
            end else begin
              ram_read_save_reg_start <= ram_read_save_reg_start + 3;
              read_address <= read_address + 3;
              temp_registers_updated[ram_read_save_reg_start+3] <= 0;
            end
            //why going up doesnt work?
            if (temp_registers_updated[ram_read_save_reg_end-1]) begin
              ram_read_save_reg_end <= ram_read_save_reg_end - 1;
              read_address2 <= read_address2 - 1;
              temp_registers_updated[ram_read_save_reg_end-1] <= 0;
            end else if (temp_registers_updated[ram_read_save_reg_end-2]) begin
              ram_read_save_reg_end <= ram_read_save_reg_end - 2;
              read_address2 <= read_address2 - 2;
              temp_registers_updated[ram_read_save_reg_end-2] <= 0;
            end else begin
              ram_read_save_reg_end <= ram_read_save_reg_end - 3;
              read_address2 <= read_address2 - 3;
              temp_registers_updated[ram_read_save_reg_end-3] <= 0;
            end
          end
        end
        STAGE_READ_NEXT_NEXT_PROCESS: begin
          if (!(uart_bb_ready && port_registered[0] && !uart_bb_processed)) begin
            if (TASK_SWITCHER_DEBUG && !HARDWARE_DEBUG)
              $display(
                  $time,
                  " read next next ",
                  read_address,
                  " ",
                  next_process_address,
                  "=",
                  read_value
              );  //DEBUG info
            next_process_address <= read_value;
          end
          if (TASK_SWITCHER_DEBUG && !HARDWARE_DEBUG) $display("\n\n");
          temp_process_num <= process_num;
          `MAKE_MMU_SEARCH2
        end
        STAGE_DELETE_PROCESS: begin
          //todo: deleting from free mmu info
          process_used[process_num] <= 0;
          process_address[process_num] <= prev_process_address;
          `MAKE_SWITCH_TASK(0)
        end
        STAGE_SPLIT_PROCESS: begin
          // $display("split mmu page: ",read_value);
          mmu_address_d <= read_value * MMU_PAGE_SIZE;  //new process address
          write_address <= read_value * MMU_PAGE_SIZE + ADDRESS_MMU_LEN + 1;
          read_address <= read_address + 1;
          stage <= STAGE_SPLIT_PROCESS2;
        end
        STAGE_SPLIT_PROCESS2: begin
          if (mmu_address_a > mmu_address_b) begin
            stage <= STAGE_SPLIT_PROCESS3;
            mmu_address_a <= read_value2;
            write_address <= process_address[process_num] + ADDRESS_MMU_LEN + read_value2;
            write_enabled <= 0;
          end else begin
            //$display("split mmu page: ",read_value);
            read_address  <= read_address + 1;
            write_address <= write_address + 1;
            write_value   <= read_value;
            write_enabled <= 1;
            mmu_address_a <= mmu_address_a + 1;
          end
        end
        STAGE_SPLIT_PROCESS3: begin
          write_address <= write_address + 1;
          write_value   <= 0;
          write_enabled <= 1;
          if (mmu_address_a == mmu_address_b) begin
            stage <= STAGE_SAVE_NEXT_PROCESS;
          end else begin
            mmu_address_a <= mmu_address_a + 1;
          end
        end
        STAGE_SAVE_NEXT_PROCESS: begin
          if (TASK_SWITCHER_DEBUG && !HARDWARE_DEBUG)
            $display(
                $time,
                " save next ",
                mmu_address_d + ADDRESS_NEXT_PROCESS,
                "=",
                next_process_address
            );  //DEBUG info
          write_address <= mmu_address_d + ADDRESS_NEXT_PROCESS;
          write_value <= next_process_address;
          stage <= STAGE_SAVE_NEXT_PROCESS2;
        end
        STAGE_SAVE_NEXT_PROCESS2: begin
          write_enabled <= 0;
          next_process_address <= mmu_address_d;
          `MAKE_MMU_SEARCH2
        end
        STAGE_REG_INT: begin
          //old process
          write_address <= process_address[process_num] + ADDRESS_PC;
          write_value   <= pc[process_num];
          `MAKE_SWITCH_TASK(0)
        end
        STAGE_INT: begin
          write_address <= prev_process_address + ADDRESS_NEXT_PROCESS;
          write_value <= int_process_address[instruction1_2];
          //if (how_many < HOW_MANY_OP_PER_TASK_SIMULATE) begin
          next_process_address <= int_process_address[instruction1_2];
          //end else begin
          //            how_many <= 0;
          //          end
          int_process_address[instruction1_2] <= process_address[process_num];
          stage <= STAGE_TASK_SWITCHER;
        end
        STAGE_SET_PC: begin
        end
      endcase
    end else if (error_code[process_num] != ERROR_NONE) begin
      $display($time, " BSOD ", error_code[process_num]);  //DEBUG info
      `HARD_DEBUG("B");  //DEBUG info
      `HARD_DEBUG("S");  //DEBUG info
      `HARD_DEBUG("O");  //DEBUG info
      `HARD_DEBUG("D");  //DEBUG info
      `HARD_DEBUG2(error_code[process_num]);  //DEBUG info
      if (next_process_address == process_address[process_num]) begin
        stage <= STAGE_HLT;
      end else begin
        write_address <= prev_process_address + ADDRESS_NEXT_PROCESS;
        write_value <= next_process_address;
        write_enabled <= 1;
        stage <= STAGE_DELETE_PROCESS;
      end
      error_code[process_num] <= ERROR_NONE;
    end
  end
endmodule

module single_blockram (
    input clk,
    write_enabled,
    input bit [15:0] write_address,
    write_value,
    read_address,
    read_address2,
    output bit [15:0] read_value,
    read_value2
);

  /*  reg [15:0] ram[0:67];
      initial begin  //DEBUG info
        $readmemh("rom4.mem", ram);  //DEBUG info
      end  //DEBUG info
*/

  // verilog_format:off
   //(* ram_style = "block" *)
   bit [15:0] ram  [0:699]= {  // in Vivado (required by board)
  //  reg [0:559] [15:0] ram = {  // in iVerilog

      //first process - 2 pages (200 elements)
      //page 1 (100 elements)
      16'd0200, 16'h0000,  16'h0000, 16'h0000, //next process address (no MMU) overwritten by CPU, we use first bytes only      
      16'd0050, 16'h0000,  16'h0000, 16'h0000, //PC for this process (overwritten by CPU, we use first bytes only)       

      16'h0000, 16'h0000,  //registers used

      16'h0000, 16'h0000, 16'h0000, 16'h0000, //registers taken "as is"
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      
      16'd0006, //mmu segment length
      16'h0001, //physical segment address for mmu logical page 1 or 0 (not assigned)
      16'h0000, //physical segment address for mmu logical page 2 or 0 (not assigned)
      16'h0000,
      16'h0000,
      16'h0000,
      16'h0000,
      16'h0000, //next mmu address or 0 (not assigned)
      
      16'h1210, 16'd2613, //value to reg // not used for anything usefull, just for debugging
      16'h0e10, 16'd0290, //save to ram // not used for anything usefull, just for debugging
      16'h0911, 16'd0100, //ram to reg // not used for anything usefull, just for debugging
      16'h0e10, 16'd0212, //save to ram // not used for anything usefull, just for debugging
      16'h0c01, 16'h0001, //unknown // not used for anything usefull, just for debugging
      16'h0c01, 16'h0002, //unknown // not used for anything usefull, just for debugging
      16'h1202, 16'h0003, //num2reg // not used for anything usefull, just for debugging
      16'h1800, 16'h0007, //process end
      16'hfb00, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      
      //page 2 (100 elements)
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
                 
      //second process - 3 pages (300 elements) + 2 pages (200 elements) new process nr 3
      //page 3 (100 elements)
      16'h0000, 16'h0000,  16'h0000, 16'h0000, //next process address (no MMU) overwritten by CPU, we use first bytes only
      16'd0050, 16'h0000,  16'h0000, 16'h0000, //PC for this process (overwritten by CPU, we use first bytes only)

      16'h0000, 16'h0000,  //registers used

      16'h0000, 16'h0000, 16'h0000, 16'h0000, //registers taken "as is"
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000, 

      16'd0006, //mmu segment length
      16'h0003, //physical segment address for mmu logical page 1 or 0 (not assigned)
      16'h0004, //physical segment address for mmu logical page 2 or 0 (not assigned)
      16'h0005,
      16'h0006,
      16'h0000,
      16'h0000,
      16'h0000, //next mmu address or 0 (not assigned)

      16'h1210, 16'd2612, //value to reg // not used for anything usefull, just for debugging
      16'h1902, 16'h0003, //split process process pages 3-4 (page 6 & 7)
      //16'h0000, 16'h0000,
      //16'h0000, 16'h0000,
       16'h0911, 16'd0101, //ram to reg // not used for anything usefull, just for debugging
       16'h0911, 16'd0102, //ram to reg // not used for anything usefull, just for debugging
    //  16'h1210, 16'd2615, //value to reg // not used for anything usefull, just for debugging
//      16'h0e10, 16'd0100, //save to ram // not used for anything usefull, just for debugging
      16'h1b37, 16'h0101, //int
      16'h1e00, 16'd0201, //in2ram
      16'h1b37, 16'h0202, //int
      16'h1f00, 16'd0002, //ret in2ram
      16'hfe00, 16'h0000,            
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,

      //page 4 (100 elements)
      16'h0000,"Po",    "zd",    "ro",    "wi",    "en",    "ia",    " z"    ," p",    "ly",
      "ty",    " d",    "la",    " M",    "ic",    "ha",    "la",    16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      
      //page 5 (100 elements)
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
            
      //third process - 2 pages (200 elements)
      //page 6 (100 elements)
      16'h0000, 16'h0000,  16'h0000, 16'h0000, //next process address (no MMU) overwritten by CPU, we use first bytes only
      16'd0050, 16'h0000,  16'h0000, 16'h0000, //PC for this process (overwritten by CPU, we use first bytes only)

      16'h0000, 16'h0000,  //registers used

      16'h0000, 16'h0000, 16'h0000, 16'h0000, //registers taken "as is"
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000,

      16'd0006, //mmu segment length
      16'h0000, //physical segment address for mmu logical page 1 or 0 (not assigned)
      16'h0000, //physical segment address for mmu logical page 2 or 0 (not assigned)
      16'h0000,
      16'h0000,
      16'h0000,
      16'h0000,
      16'h0000, //next mmu address or 0 (not assigned)

      16'h1a37, 16'h0101, //reg int 
      16'h0911, 16'd0150, //ram to reg // not used for anything usefull, just for debugging
      16'h1210, 16'h0a35, //value to reg // not used for anything usefull, just for debugging
      16'h1d10, 16'd0101, //ram2out         
      16'h1c37, 16'd0000, //int ret      
      16'hff00, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      
      //page 7 (100 elements)
      "AB",        "CD",16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000
    };

  // verilog_format:on

  assign read_value  = ram[read_address];
  assign read_value2 = ram[read_address2];

  always @(posedge clk) begin
    // if (write_enabled) 
    if (write_enabled && RAM_WRITE_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
      $display($time, " ram write ", write_address, " = ", write_value);  //DEBUG info
    if (RAM_READ_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
      $display($time, " ram read ", read_address, " = ", ram[read_address]);  //DEBUG info

    if (write_enabled) ram[write_address] <= write_value;
  end
endmodule

module uartx_tx_with_buffer (
    input clk,
    input [7:0] uart_buffer[0:200],
    input [6:0] uart_buffer_available,
    output bit reset_uart_buffer_available,
    output bit uart_buffer_full,
    output bit tx
);

  bit [7:0] input_data;
  bit [6:0] uart_buffer_processed = 0;
  bit [3:0] uart_buffer_state = 0;
  bit start;
  wire complete;

  assign reset_uart_buffer_available = uart_buffer_available != 0 && uart_buffer_available == uart_buffer_processed && uart_buffer_state == 2 && complete?1:0;
  assign uart_buffer_full = uart_buffer_available == 199 ? 1 : 0;
  assign start = uart_buffer_state == 1;

  uart_tx uart_tx (
      .clk(clk),
      .start(start),
      .input_data(input_data),
      .complete(complete),
      .uarttx(tx)
  );

  always @(posedge clk) begin
    if (uart_buffer_state == 0) begin
      if (uart_buffer_available > 0 && uart_buffer_processed < uart_buffer_available) begin
        input_data <= uart_buffer[uart_buffer_processed];
        uart_buffer_state <= uart_buffer_state + 1;
        uart_buffer_processed <= uart_buffer_processed + 1;
      end else if (uart_buffer_processed > uart_buffer_available) begin
        uart_buffer_processed <= 0;
      end
    end else if (uart_buffer_state == 1) begin
      if (!complete) uart_buffer_state <= uart_buffer_state + 1;
    end else if (uart_buffer_state == 2) begin
      if (complete) uart_buffer_state <= 0;
    end
  end
endmodule


//115200, 8 bits (LSB first), 1 stop, no parity
//values on tx: ...1, 0 (start bit), (8 data bits), 1 (stop bit), 1... 
//(we make some delay in the end before next seq; every bit is sent CLK_PER_BIT cycles)
module uart_tx (
    input clk,
    input start,
    input [7:0] input_data,
    output bit complete,
    output bit uarttx
);

  parameter CLK_PER_BIT = 100000000 / 115200;  //100 Mhz / transmission speed in bits per second

  parameter STATE_IDLE = 0;  //1
  parameter STATE_START_BIT = 1;  //0
  parameter STATE_DATA_BIT_0 = 2;
  //...
  parameter STATE_DATA_BIT_7 = 9;
  parameter STATE_STOP_BIT = 10;  //1

  bit [ 5:0] uart_tx_state = STATE_IDLE;
  bit [10:0] counter = CLK_PER_BIT;

  assign uarttx = uart_tx_state == STATE_IDLE || uart_tx_state == STATE_STOP_BIT ? 1:(uart_tx_state == STATE_START_BIT ? 0:input_data[uart_tx_state-STATE_DATA_BIT_0]);
  assign complete = uart_tx_state == STATE_IDLE;

  always @(negedge clk) begin
    if (uart_tx_state == STATE_IDLE) begin
      uart_tx_state <= start ? STATE_START_BIT : STATE_IDLE;
    end else begin
      uart_tx_state <= counter == 0 ? (uart_tx_state== STATE_STOP_BIT? STATE_IDLE : uart_tx_state + 1) : uart_tx_state;
      counter <= counter == 0 ? CLK_PER_BIT : counter - 1;
    end
  end
endmodule

module uart_rx (
    input clk,
    input uartrx,
    input bb_processed,
    output logic [7:0] bb,
    output logic bb_ready = 0
);

  parameter CLK_PER_BYTE = 100000000 / 115200;  //100 Mhz / transmission speed in bps (bits per second)

  parameter STATE_IDLE = 0;  //1
  parameter STATE_START_BIT = 1;  //0
  parameter STATE_DATA_BIT_0 = 2;
  //...
  parameter STATE_DATA_BIT_7 = 9;
  parameter STATE_STOP_BIT = 10;  //1

  reg [ 5:0] uart_tx_state = STATE_IDLE;
  reg [10:0] counter = 0;
  reg uartrxreg, inp;

  //double buffering to avoid metastability
  always @(posedge clk) begin
    uartrxreg <= uartrx;
    inp <= uartrxreg;
  end

  always @(posedge clk) begin
    if (uart_tx_state == STATE_IDLE) begin
      if (bb_processed) bb_ready <= 0;
      if (inp == 0) begin
        counter <= 0;
        uart_tx_state <= uart_tx_state + 1;
      end
    end else if (uart_tx_state == STATE_START_BIT) begin
      if (counter == (CLK_PER_BYTE - 1) / 2) begin
        if (inp == 1) begin
          uart_tx_state <= STATE_IDLE;
        end else begin
          //starting from this point we will be checking RS input value in the middle of the cycle
          uart_tx_state <= uart_tx_state + 1;
          counter <= 0;
        end
      end else begin
        counter <= counter + 1;
      end
    end else if (uart_tx_state >= STATE_DATA_BIT_0 && uart_tx_state <= STATE_DATA_BIT_7) begin
      if (counter == CLK_PER_BYTE) begin
        bb[uart_tx_state-STATE_DATA_BIT_0] <= inp;
        uart_tx_state <= uart_tx_state + 1;
        counter <= 0;
      end else begin
        counter <= counter + 1;
      end
    end else if (uart_tx_state == STATE_STOP_BIT) begin
      if (counter == CLK_PER_BYTE) begin
        bb_ready <= inp;
        uart_tx_state <= STATE_IDLE;
      end else begin
        counter <= counter + 1;
      end
    end
  end
endmodule

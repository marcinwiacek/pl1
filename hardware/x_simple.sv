`timescale 1ns / 1ps

//options below are less important than options higher //DEBUG info
parameter WRITE_RAM_DEBUG = 0;  //1 enabled, 0 disabled //DEBUG info
parameter READ_RAM_DEBUG = 0;  //1 enabled, 0 disabled //DEBUG info
parameter REG_CHANGES_DEBUG = 0;  //1 enabled, 0 disabled //DEBUG info
parameter MMU_CHANGES_DEBUG = 0;  //1 enabled, 0 disabled //DEBUG info
parameter MMU_TRANSLATION_DEBUG = 0;  //1 enabled, 0 disabled //DEBUG info
parameter TASK_SWITCHER_DEBUG = 0;  //1 enabled, 0 disabled //DEBUG info
parameter TASK_SPLIT_DEBUG = 0;  //1 enabled, 0 disabled //DEBUG info
parameter OTHER_DEBUG = 0;  //1 enabled, 0 disabled //DEBUG info
parameter HARDWARE_DEBUG = 1;
parameter READ_DEBUG = 0;  //1 enabled, 0 disabled //DEBUG info
parameter STAGE_DEBUG = 0;
parameter OP_DEBUG = 0;
parameter ALU_DEBUG = 0;

parameter MMU_PAGE_SIZE = 70;  //how many bytes are assigned to one memory page in MMU
parameter RAM_SIZE = 32767;
parameter MMU_MAX_INDEX = 455;  //(`RAM_SIZE+1)/`MMU_PAGE_SIZE;

/* DEBUG info */ `define HARD_DEBUG(ARG) \
/* DEBUG info */     uart_buffer[uart_buffer_available++] = ARG; \
/* DEBUG info */     if (HARDWARE_DEBUG == 1)  $write(ARG); 

/* DEBUG info */ `define HARD_DEBUG2(ARG) \
/* DEBUG info */     uart_buffer[uart_buffer_available++] = ARG/16>10? ARG/16 + 65 - 10:ARG/16+ 48; \
/* DEBUG info */     uart_buffer[uart_buffer_available++] = ARG%16>10? ARG%16 + 65 - 10:ARG%16+ 48; \
/* DEBUG info */     if (HARDWARE_DEBUG == 1) $write("%c",ARG/16>10? ARG/16 + 65 - 10:ARG/16+ 48,"%c",ARG%16>10? ARG%16 + 65 - 10:ARG%16+ 48);

/* DEBUG info */ `define SHOW_REG_DEBUG(ARG, INFO, ARG2, ARG3) \
/* DEBUG info */     if (ARG == 1) begin \
/* DEBUG info */       $write($time, INFO); \
/* DEBUG info */       for (i = 0; i <= 10; i = i + 1) begin \
/* DEBUG info */         $write($sformatf("%02x ", (i==ARG2?ARG3:registers[process_index][i]))); \
/* DEBUG info */       end \
/* DEBUG info */       $display(""); \
/* DEBUG info */     end

/* DEBUG info */  `define SHOW_MMU_DEBUG \
/* DEBUG info */     if (MMU_CHANGES_DEBUG == 1) begin \
/* DEBUG info */       $write($time, " mmu "); \
/* DEBUG info */       for (i = 0; i <= 10; i = i + 1) begin \
/* DEBUG info */         if (mmu_start_process_physical_segment == i && mmu_logical_pages_memory[i]!=0) $write("s"); \
/* DEBUG info */         if (mmu_chain_memory[i] == i && mmu_logical_pages_memory[i]!=0) $write("e"); \
/* DEBUG info */         $write($sformatf("%02x-%02x ", mmu_chain_memory[i], mmu_logical_pages_memory[i])); \
/* DEBUG info */       end \
/* DEBUG info */       $display(""); \
/* DEBUG info */     end

/* DEBUG info */  `define SHOW_TASK_INFO(ARG) \
/* DEBUG info */     if (TASK_SWITCHER_DEBUG == 1) begin \
/* DEBUG info */          $write($time, " ",ARG," pc ", address_pc[process_index]); \
/* DEBUG info */          $display( \
/* DEBUG info */              " ",ARG," process seg/addr ", mmu_start_process_segment, process_start_address[process_index], \
/* DEBUG info */              " process index ", process_index \
/* DEBUG info */          ); \
/* DEBUG info */        end

(* use_dsp = "yes" *) module plus (
    input clk,
    input [15:0] a,
    input [15:0] b,
    output reg [15:0] c
);

  always @(posedge clk) begin
    c = a + b;
  end
endmodule

(* use_dsp = "yes" *) module minus (
    input clk,
    input [15:0] a,
    input [15:0] b,
    output reg [15:0] c
);
  always @(posedge clk) begin
    c = a - b;
  end
endmodule


(* use_dsp = "yes" *) module mul (
    input clk,
    input [15:0] a,
    input [15:0] b,
    output reg [15:0] c
);
  always @(posedge clk) begin
    c = a * b;
  end
endmodule

(* use_dsp = "yes" *) module div (
    input clk,
    input [15:0] a,
    input [15:0] b,
    output reg [15:0] c
);
  always @(posedge clk) begin
    c = a / b;
  end
endmodule

module x_simple (
    input clk,
    input logic btnc,
    output logic uart_rx_out
);

  reg [31:0] ctn = 0;
  reg reset;

  assign reset = ctn == 1 || btnc;

  always @(posedge clk) begin
    if (ctn < 10) ctn <= ctn + 1;
  end

  reg write_enabled;
  reg [15:0] write_address;
  reg [15:0] write_value;
  reg [15:0] read_address;
  wire [15:0] read_value;

  single_ram single_ram (
      .clk(clk),
      .write_enabled(write_enabled),
      .write_address(write_address),
      .write_value(write_value),
      .read_address(read_address),
      .read_value(read_value)
  );

  reg [7:0] uart_buffer[0:128];
  reg [6:0] uart_buffer_available = 0;
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

  parameter OPCODE_JMP = 1;  //24 bit target address
  parameter OPCODE_JMP16 = 2;  //x, register num with target addr (we read one reg)
  //  parameter OPCODE_JMP32 = 3;  //x, first register num with target addr (we read two reg)
  //  parameter OPCODE_JMP64 = 4;  //x, first register num with target addr (we read four reg)  
  parameter OPCODE_JMP_PLUS = 5;  //x, 16 bit how many instructions
  parameter OPCODE_JMP_PLUS16 = 6;  //x, register num with info (we read one reg)
  parameter OPCODE_JMP_MINUS = 7;  //x, 16 bit how many instructions  
  parameter OPCODE_JMP_MINUS16 = 8;  //x, register num with info (we read one reg)
  parameter OPCODE_RAM2REG = 9;  //register num (5 bits), how many-1 (3 bits), 16 bit source addr //ram -> reg
  parameter OPCODE_RAM2REG16 = 10; //start register num, how many registers, register num with source addr (we read one reg), //ram -> reg  
  //  parameter OPCODE_RAM2REG32 = 11; //start register num, how many registers, first register num with source addr (we read two reg), //ram -> reg
  //  parameter OPCODE_RAM2REG64 = 12; //start register num, how many registers, first register num with source addr (we read four reg), //ram -> reg
  parameter OPCODE_REG2RAM = 14;  //register num (5 bits), how many-1 (3 bits), 16 bit target addr //reg -> ram
  parameter OPCODE_REG2RAM16 = 15; //start register num, how many registers, register num with target addr (we read one reg), //reg -> ram
  //  parameter OPCODE_REG2RAM32 = 16; //start register num, how many registers, first register num with target addr (we read two reg), //reg -> ram
  //  parameter OPCODE_REG2RAM64 = 17; //start register num, how many registers, first register num with target addr (we read four reg), //reg -> ram
  parameter OPCODE_NUM2REG = 18;  //register num (5 bits), how many-1 (3 bits), 16 bit value //value -> reg
  parameter OPCODE_REG_PLUS =19; //register num (5 bits), how many-1 (3 bits), 16 bit value // reg += value
  parameter OPCODE_REG_MINUS =20; //register num (5 bits), how many-1 (3 bits), 16 bit value  //reg -= value
  parameter OPCODE_REG_MUL =21; //register num (5 bits), how many-1 (3 bits), 16 bit value // reg *= value
  parameter OPCODE_REG_DIV =22; //register num (5 bits), how many-1 (3 bits), 16 bit value  //reg /= value

  parameter OPCODE_TILL_VALUE =23;   //register num (8 bit), value (8 bit), how many instructions (8 bit value) // do..while
  parameter OPCODE_TILL_NON_VALUE=24;   //register num, value, how many instructions (8 bit value) //do..while
  parameter OPCODE_LOOP = 25;  //x, x, how many instructions (8 bit value) //for...
  parameter OPCODE_PROC = 26;  //new process //how many segments, start segment number (16 bit)
  parameter OPCODE_EXIT = 27;  //exit process
  parameter OPCODE_REG_INT = 28;  //x, int number (8 bit)
  parameter OPCODE_INT = 29;  //x, int number (8 bit)
  parameter OPCODE_INT_RET = 30;  //x, int number
  parameter OPCODE_FREE = 31;  //free ram pages x-y 
  parameter OPCODE_FREE_LEVEL =32; //free ram pages allocated after page x (or pages with concrete level) 

  parameter STAGE_AFTER_RESET = 1;
  parameter STAGE_GET_1_BYTE = 2;
  parameter STAGE_GET_2_BYTE = 3;
  parameter STAGE_CHECK_MMU_ADDRESS = 4;
  parameter STAGE_SEARCH1_MMU_ADDRESS = 5;
  parameter STAGE_SET_PC = 6;
  parameter STAGE_GET_PARAM_BYTE = 7;
  parameter STAGE_SET_PARAM_BYTE = 8;
  parameter STAGE_GET_RAM_BYTE = 9;
  parameter STAGE_HLT = 10;
  parameter STAGE_ALU = 11;
  parameter STAGE_SET_RAM_BYTE = 12;

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

  //offsets for process info
  parameter ADDRESS_NEXT_PROCESS = 0;
  parameter ADDRESS_PC = 4;
  parameter ADDRESS_REG_USED = 8;
  parameter ADDRESS_REG = 14;
  parameter ADDRESS_PROGRAM = ADDRESS_REG + 32;

  reg [8:0] mmu_chain_memory[0:MMU_MAX_INDEX];  //next physical segment index for process (last entry = the same entry)
  reg [8:0] mmu_logical_pages_memory[0:MMU_MAX_INDEX];  //logical process page assigned to physical segment (0 means empty page, we setup value > 0 for first page with logical index 0 and ignore it)
  reg [8:0] mmu_start_process_physical_segment;  //needs to be updated on process switch

  reg [8:0] mmu_address_to_search;
  reg [8:0] mmu_address_to_search_segment;
  reg [8:0] mmu_search_position, mmu_prev_search_position;

  reg rst_can_be_done = 1, working = 1;
  reg [5:0] pc;
  reg [5:0] error_code = 0;
  reg [3:0] stage, stage_after_mmu;
  reg [15:0] registers[0:31];  //512 bits = 32 x 16-bit registers

  reg [5:0] ram_read_save_reg_start, ram_read_save_reg_end;
  reg [7:0] alu_op, alu_num;

  reg   [15:0] instruction1;
  logic [ 7:0] instruction1_1;
  logic [ 7:0] instruction1_2;
  logic [ 4:0] instruction1_2_1;
  logic [ 2:0] instruction1_2_2;
  logic [ 7:0] instruction2_1;
  logic [ 7:0] instruction2_2;

  assign instruction1_1   = instruction1[15:8];
  assign instruction1_2   = instruction1[7:0];
  assign instruction1_2_1 = instruction1[4:0];
  assign instruction1_2_2 = instruction1[7:5];
  assign instruction2_1   = read_value[15:8];
  assign instruction2_2   = read_value[7:0];

  integer i;  //DEBUG info

  reg [15:0] mul_a, mul_b;
  wire [15:0] mul_c;
  reg [15:0] div_a, div_b;
  wire [15:0] div_c;
  reg [15:0] plus_a, plus_b;
  wire [15:0] plus_c;
  reg [15:0] minus_a, minus_b;
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

  always @(negedge clk) begin
    if (reset == 1 && rst_can_be_done == 1) begin
      rst_can_be_done = 0;
      if (OTHER_DEBUG == 1) $display($time, " reset");

      uart_buffer_available = 0;
      `HARD_DEBUG("\n");
      `HARD_DEBUG("S");

      mmu_start_process_physical_segment = 0;

      mmu_chain_memory[0] = 0;
      for (i = 0; i < MMU_MAX_INDEX; i = i + 1) begin
        //value 0 means, that it's empty. in every process on first entry we setup something != 0 and ignore it
        // (first process page starts always from segment 0)
        mmu_logical_pages_memory[i] = 0;
      end

      //some more complicated config used for testing //DEBUG info
      mmu_chain_memory[0] = 5;  //DEBUG info
      mmu_chain_memory[5] = 2;  //DEBUG info
      mmu_chain_memory[2] = 1;  //DEBUG info
      mmu_chain_memory[1] = 1;  //DEBUG info
      mmu_logical_pages_memory[0] = 1;  //DEBUG info
      mmu_logical_pages_memory[5] = 3;  //DEBUG info
      mmu_logical_pages_memory[2] = 2;  //DEBUG info
      mmu_logical_pages_memory[1] = 1;  //DEBUG info
      `SHOW_MMU_DEBUG

      for (i = 0; i < 32; i = i + 1) begin
        registers[i] = 0;
      end

      pc = ADDRESS_PROGRAM;
      read_address = ADDRESS_PROGRAM; //we start from segment number 0 in first process, don't need MMU translation
      stage = STAGE_GET_1_BYTE;

      error_code = ERROR_NONE;
      working = 0;
    end else if (working == 0 && error_code == ERROR_NONE) begin
      working = 1;
      rst_can_be_done = 1;
      if (STAGE_DEBUG) $display($time, " stage ", stage);
      case (stage)
        STAGE_GET_1_BYTE: begin
          if (pc <= 62) begin
            rst_can_be_done = 1;
            if (READ_DEBUG == 1) $display($time, " read ready ", read_address, "=", read_value);
            `HARD_DEBUG("a");
            instruction1 = read_value;
            pc = pc + 1;
            read_address = read_address + 1;
            stage = STAGE_GET_2_BYTE;
          end else begin
            stage = STAGE_HLT;
          end
        end
        STAGE_GET_2_BYTE: begin
          `HARD_DEBUG("b");
          if (READ_DEBUG == 1) $display($time, " read ready2 ", read_address, "=", read_value);
          if (OTHER_DEBUG == 1)
            $display(
                $time,
                mmu_start_process_physical_segment,
                " ",
                (pc - 1),
                " b1: ",
                instruction1_1,
                ":",
                instruction1_2,
                "(",
                instruction1_2_1,
                "-",
                instruction1_2_2,
                ") b2: ",
                read_value
            );
          `HARD_DEBUG2(instruction1_1);
          `HARD_DEBUG2(instruction1_2);
          case (instruction1_1)
            //24 bit target address
            OPCODE_JMP: begin
              if ((read_value + (256 * 256) * instruction1_2) % 2 == 1) begin
                error_code = ERROR_WRONG_ADDRESS;
              end else begin
                if (OP_DEBUG == 1)
                  $display(
                      $time, " opcode = jmp to ", (read_value + (256 * 256) * instruction1_2)
                  );  //DEBUG info    
                pc = (read_value + (256 * 256) * instruction1_2);
                stage = STAGE_SET_PC;
              end
            end
            //x, register num with target addr (we read one reg)
            OPCODE_JMP16: begin
              if (read_value >= 32) begin
                error_code = ERROR_WRONG_REG_NUM;
              end else if ((registers[read_value] - 1) % 2 == 1) begin
                error_code = ERROR_WRONG_ADDRESS;
              end else begin
                if (OP_DEBUG == 1)
                  $display(
                      $time, " opcode = jmp to ", (registers[read_value] - 1)
                  );  //DEBUG info                       
                pc = registers[read_value];
                stage = STAGE_SET_PC;
              end
            end
            //x, register num with target addr (we read one reg)
            OPCODE_JMP_PLUS: begin
              if (OP_DEBUG == 1)
                $display(
                    $time,
                    " opcode = jmp plus to ",
                    pc + read_value * 2 - 1,
                    " (",
                    read_value,
                    " instructions)"
                );  //DEBUG info      
              pc += read_value * 2 - 1;
              stage = STAGE_SET_PC;
            end
            //x, register num with info (we read one reg)
            OPCODE_JMP_PLUS16: begin
              if (read_value >= 32) begin
                error_code = ERROR_WRONG_REG_NUM;
              end else begin
                if (OP_DEBUG == 1)
                  $display(
                      $time,
                      " opcode = jmp plus16 to ",
                      pc + registers[read_value] * 2 - 1,
                      " (",
                      registers[read_value],
                      " instructions)"
                  );  //DEBUG info      
                pc += registers[read_value] * 2 - 1;
                stage = STAGE_SET_PC;
              end
            end
            //x, 16 bit how many instructions
            OPCODE_JMP_MINUS: begin
              if (pc - read_value * 2 < ADDRESS_PROGRAM) begin
                error_code = ERROR_WRONG_ADDRESS;
              end else begin
                if (OP_DEBUG == 1)
                  $display(
                      $time,
                      " opcode = jmp minus to ",
                      pc - read_value * 2 - 1,
                      " (",
                      read_value,
                      " instructions)"
                  );  //DEBUG info      
                pc -= read_value * 2 - 1;
                stage = STAGE_SET_PC;
              end
            end
            //x, register num with info (we read one reg)
            OPCODE_JMP_MINUS16: begin
              if (read_value >= 32) begin
                error_code = ERROR_WRONG_REG_NUM;
              end else if (pc - registers[read_value] * 2 < ADDRESS_PROGRAM) begin
                error_code = ERROR_WRONG_ADDRESS;
              end else begin
                if (OP_DEBUG == 1)
                  $display(
                      $time,
                      " opcode = jmp minus16 to ",
                      pc - registers[read_value] * 2 - 1,
                      " (",
                      registers[read_value],
                      " instructions)"
                  );  //DEBUG info      
                pc -= registers[read_value] * 2 - 1;
                stage = STAGE_SET_PC;
              end
            end
            //register num (5 bits), how many-1 (3 bits), 16 bit source addr //ram -> reg
            OPCODE_RAM2REG: begin
              if (instruction1_2_1 + instruction1_2_2 >= 32) begin
                error_code = ERROR_WRONG_REG_NUM;
              end else if (read_value < ADDRESS_PROGRAM) begin
                error_code = ERROR_WRONG_ADDRESS;
              end else begin
                if (OP_DEBUG == 1)
                  $display(
                      $time,
                      " opcode = ram2reg read value from address ",
                      read_value,
                      "+ to reg ",  //DEBUG info
                      instruction1_2_1,
                      "-",
                      (instruction1_2_1 + instruction1_2_2)
                  );  //DEBUG info
                stage_after_mmu = STAGE_GET_RAM_BYTE;
                mmu_address_to_search = read_value;
                ram_read_save_reg_start = instruction1_2_1;
                ram_read_save_reg_end = instruction1_2_1 + instruction1_2_2;
                stage = STAGE_CHECK_MMU_ADDRESS;
              end
            end
            //start register num, how many registers, register num with source addr (we read one reg), //ram -> reg
            OPCODE_RAM2REG16: begin
              if (instruction1_2 + instruction2_1 >= 32 || instruction2_2 >= 32) begin
                error_code = ERROR_WRONG_REG_NUM;
              end else if (read_value < ADDRESS_PROGRAM) begin
                error_code = ERROR_WRONG_ADDRESS;
              end else begin
                if (OP_DEBUG == 1)
                  $display(
                      $time,
                      " opcode = ram2reg16 read from ram (address ",
                      registers[instruction2_2],
                      "+) to reg ",
                      instruction1_2,
                      "-",
                      (instruction1_2 + instruction2_1)
                  );  //DEBUG info             
                stage_after_mmu = STAGE_GET_RAM_BYTE;
                mmu_address_to_search = registers[instruction2_2];
                ram_read_save_reg_start = instruction1_2;
                ram_read_save_reg_end = instruction1_2 + instruction2_1;
                stage = STAGE_CHECK_MMU_ADDRESS;
              end
            end
            //register num (5 bits), how many-1 (3 bits), 16 bit target addr //reg -> ram
            OPCODE_REG2RAM: begin
              if (instruction1_2_1 + instruction1_2_2 >= 32) begin
                error_code = ERROR_WRONG_REG_NUM;
              end else if (read_value < ADDRESS_PROGRAM) begin
                error_code = ERROR_WRONG_ADDRESS;
              end else begin
                if (OP_DEBUG == 1)
                  $display(
                      $time,
                      " opcode = reg2ram save reg ",
                      instruction1_2_1,
                      "-",
                      (instruction1_2_1 + instruction1_2_2),
                      " to ram address ",
                      read_value,
                      "+"
                  );  //DEBUG info
                write_value = registers[instruction1_2_1];
                stage_after_mmu = STAGE_SET_RAM_BYTE;
                mmu_address_to_search = read_value;
                ram_read_save_reg_start = instruction1_2_1;
                ram_read_save_reg_end = instruction1_2_1 + instruction1_2_2;
                stage = STAGE_CHECK_MMU_ADDRESS;
              end
            end
            //start register num, how many registers, register num with target addr (we read one reg), //reg -> ram
            OPCODE_REG2RAM16: begin
              if (instruction1_2 + instruction2_1 >= 32 || instruction2_2 >= 32) begin
                error_code = ERROR_WRONG_REG_NUM;
              end else if (read_value < ADDRESS_PROGRAM) begin
                error_code = ERROR_WRONG_ADDRESS;
              end else begin
                if (OP_DEBUG == 1)
                  $display(
                      $time,
                      " opcode = reg2ram16 save to ram (address ",
                      registers[instruction2_2],
                      "+) from reg ",
                      instruction1_2,
                      "-",
                      (instruction1_2 + instruction2_1)
                  );  //DEBUG info             
                write_value = registers[instruction1_2];
                stage_after_mmu = STAGE_SET_RAM_BYTE;
                mmu_address_to_search = registers[instruction2_2];
                ram_read_save_reg_start = instruction1_2;
                ram_read_save_reg_end = instruction1_2 + instruction2_1;
                stage = STAGE_CHECK_MMU_ADDRESS;
              end
            end
            //register num (5 bits), how many-1 (3 bits), 16 bit value //value -> reg
            OPCODE_NUM2REG: begin
              if (OP_DEBUG == 1)
                $display(
                    $time,
                    " opcode = num2reg save value ",
                    read_value,
                    " to reg ",  //DEBUG info
                    instruction1_2_1,
                    "-",
                    (instruction1_2_1 + instruction1_2_2)
                );  //DEBUG info
              alu_op  = ALU_SET;
              alu_num = instruction1_2_1;
              stage   = STAGE_ALU;
            end
            //register num (5 bits), how many-1 (3 bits), 16 bit value // reg += value
            OPCODE_REG_PLUS: begin
              if (OP_DEBUG == 1)
                $display(
                    $time,
                    " opcode = regplus add value ",
                    read_value,
                    " to reg ",  //DEBUG info
                    instruction1_2_1,
                    "-",
                    (instruction1_2_1 + instruction1_2_2)
                );  //DEBUG info
              alu_op  = ALU_ADD;
              alu_num = 255;
              stage   = STAGE_ALU;
            end
            //register num (5 bits), how many-1 (3 bits), 16 bit value // reg -= value
            OPCODE_REG_MINUS: begin
              if (OP_DEBUG == 1)
                $display(
                    $time,
                    " opcode = regminus dec value ",
                    read_value,
                    " to reg ",  //DEBUG info
                    instruction1_2_1,
                    "-",
                    (instruction1_2_1 + instruction1_2_2)
                );  //DEBUG info
              alu_op  = ALU_DEC;
              alu_num = 255;
              stage   = STAGE_ALU;
            end
            //register num (5 bits), how many-1 (3 bits), 16 bit value // reg *= value
            OPCODE_REG_MUL: begin
              if (OP_DEBUG == 1)
                $display(
                    $time,
                    " opcode = regmul mul value ",
                    read_value,
                    " to reg ",  //DEBUG info
                    instruction1_2_1,
                    "-",
                    (instruction1_2_1 + instruction1_2_2)
                );  //DEBUG info     
              alu_op  = ALU_MUL;
              alu_num = 255;
              stage   = STAGE_ALU;
            end
            //register num (5 bits), how many-1 (3 bits), 16 bit value // reg /= value
            OPCODE_REG_DIV: begin
              if (read_value == 0) begin
                error_code = ERROR_DIVIDE_BY_ZERO;
              end else begin
                if (OP_DEBUG == 1)
                  $display(
                      $time,
                      " opcode = regdiv div value ",
                      read_value,
                      " to reg ",  //DEBUG info
                      instruction1_2_1,
                      "-",
                      (instruction1_2_1 + instruction1_2_2)
                  );  //DEBUG info
                alu_op = ALU_DIV;
                stage  = STAGE_ALU;
              end
            end
            // default: begin
            //    error_code = ERROR_WRONG_OPCODE;
            // end
          endcase
          if (stage != STAGE_SET_PC) begin
            pc = pc + 1;
          end
          if (stage == STAGE_GET_2_BYTE) begin
            mmu_address_to_search = pc;
            stage_after_mmu = STAGE_GET_1_BYTE;
            stage = STAGE_CHECK_MMU_ADDRESS;
          end
        end
        STAGE_GET_RAM_BYTE: begin
          registers[ram_read_save_reg_start] = read_value;
          if (OP_DEBUG == 1)
            $display(
                $time,
                " read value for reg ",
                ram_read_save_reg_start,
                " from address ",
                read_address,
                " = ",
                read_value
            );
          if (ram_read_save_reg_start == ram_read_save_reg_end) begin
            mmu_address_to_search = pc;
            stage_after_mmu = STAGE_GET_1_BYTE;
          end else begin
            ram_read_save_reg_start = ram_read_save_reg_start + 1;
            mmu_address_to_search = mmu_address_to_search + 1;
            stage_after_mmu = STAGE_GET_RAM_BYTE;
          end
          stage = STAGE_CHECK_MMU_ADDRESS;
        end
        STAGE_SET_RAM_BYTE: begin
          if (ram_read_save_reg_start == ram_read_save_reg_end) begin
            write_enabled = 0;
            mmu_address_to_search = pc;
            stage_after_mmu = STAGE_GET_1_BYTE;
          end else begin
            ram_read_save_reg_start = ram_read_save_reg_start + 1;
            write_value = registers[ram_read_save_reg_start];
            mmu_address_to_search = mmu_address_to_search + 1;
            stage_after_mmu = STAGE_SET_RAM_BYTE;
          end
          stage = STAGE_CHECK_MMU_ADDRESS;
        end
        STAGE_CHECK_MMU_ADDRESS: begin
          `HARD_DEBUG("m");
          mmu_address_to_search_segment = mmu_address_to_search / MMU_PAGE_SIZE;
          if (OTHER_DEBUG == 1)
            $display(
                $time,
                " mmu, address ",
                mmu_address_to_search,
                " segment ",
                mmu_address_to_search_segment
            );
          if (mmu_address_to_search_segment == 0) begin
            `HARD_DEBUG("M");
            if (stage_after_mmu == STAGE_SET_RAM_BYTE) begin
              write_enabled = 1;
              write_address = mmu_address_to_search % MMU_PAGE_SIZE + mmu_start_process_physical_segment*MMU_PAGE_SIZE;
            end else begin
              read_address = mmu_address_to_search % MMU_PAGE_SIZE + mmu_start_process_physical_segment*MMU_PAGE_SIZE;
            end
            stage = stage_after_mmu;
          end else begin
            mmu_search_position = mmu_chain_memory[mmu_start_process_physical_segment];
            stage = STAGE_SEARCH1_MMU_ADDRESS;
          end
        end
        STAGE_SEARCH1_MMU_ADDRESS: begin
          if (mmu_logical_pages_memory[mmu_search_position] == mmu_address_to_search_segment) begin
            `HARD_DEBUG("%");
            if (MMU_TRANSLATION_DEBUG)
              $display($time, " physical segment in position ", mmu_search_position);
            //move found address to the beginning to speed up search in the future       
            if (mmu_chain_memory[mmu_start_process_physical_segment] != mmu_search_position) begin
              if (mmu_chain_memory[mmu_search_position] == mmu_search_position) begin
                mmu_chain_memory[mmu_prev_search_position] = mmu_prev_search_position;
              end
              mmu_chain_memory[mmu_search_position] = mmu_chain_memory[mmu_start_process_physical_segment];
              mmu_chain_memory[mmu_start_process_physical_segment] = mmu_search_position;
              `SHOW_MMU_DEBUG
            end
            if (stage_after_mmu == STAGE_SET_RAM_BYTE) begin
              write_enabled = 1;
              write_address = mmu_address_to_search % MMU_PAGE_SIZE + mmu_search_position * MMU_PAGE_SIZE;
            end else begin
              read_address = mmu_address_to_search % MMU_PAGE_SIZE + mmu_search_position * MMU_PAGE_SIZE;
            end
            stage = stage_after_mmu;
          end else begin
            `HARD_DEBUG("^");
            mmu_prev_search_position = mmu_search_position;
            mmu_search_position = mmu_chain_memory[mmu_search_position];
          end
        end
        STAGE_ALU: begin
          if (ALU_DEBUG == 1)
            $display(
                $time,
                " alu_num ",
                alu_num,
                " alu_op ",
                alu_op,
                " end ",
                (instruction1_2_1 + instruction1_2_2)
            );  //DEBUG info
          if (instruction1_2_1 + instruction1_2_2 >= 32) begin
            error_code = ERROR_WRONG_REG_NUM;
          end else begin
            if (alu_num == 255) begin
              alu_num = instruction1_2_1;
            end else begin
              case (alu_op)
                ALU_SET: begin
                  if (OP_DEBUG == 1) $display($time, " set reg ", alu_num, " with ", read_value);
                  registers[alu_num] = read_value;
                end
                ALU_ADD: begin
                  registers[alu_num] = plus_c;
                end
                ALU_DEC: begin
                  registers[alu_num] = minus_c;
                end
                ALU_MUL: begin
                  registers[alu_num] = mul_c;
                end
                ALU_DIV: begin
                  registers[alu_num] = div_c;
                end
              endcase
              alu_num = alu_num + 1;
            end
            if (alu_num > instruction1_2_1 + instruction1_2_2) begin
              mmu_address_to_search = pc;
              stage_after_mmu = STAGE_GET_1_BYTE;
              stage = STAGE_CHECK_MMU_ADDRESS;
            end else begin
              case (alu_op)
                ALU_ADD: begin
                  plus_a = registers[alu_num];
                  plus_b = read_value;
                end
                ALU_DEC: begin
                  minus_a = registers[alu_num];
                  minus_b = read_value;
                end
                ALU_MUL: begin
                  mul_a = registers[alu_num];
                  mul_b = read_value;
                end
                ALU_DIV: begin
                  div_a = registers[alu_num];
                  div_b = read_value;
                end
              endcase
            end
          end
        end
      endcase
      if (error_code != ERROR_NONE) begin
        // `HARD_DEBUG2(instruction1_1);
        //  `HARD_DEBUG2(instruction1_2);
        `HARD_DEBUG("B");
        `HARD_DEBUG("S");
        `HARD_DEBUG("O");
        `HARD_DEBUG("D");
        `HARD_DEBUG2(error_code);
        stage = STAGE_HLT;
      end
      working = 0;
    end
  end
endmodule

module single_ram (
    input clk,
    input write_enabled,
    input [15:0] write_address,
    input [15:0] write_value,
    input [15:0] read_address,
    output reg [15:0] read_value
);

  /*  reg [15:0] ram[0:67];
      initial begin  //DEBUG info
        $readmemh("rom4.mem", ram);  //DEBUG info
      end  //DEBUG info
*/

  // verilog_format:off

  reg [0:432] [15:0] ram = {
      16'h0110, 16'h0220,  16'h0330, 16'h0440, //next process address (no MMU) overwritten by CPU, we use first bytes only      
      16'h0000, 16'h0000,  16'h0000, 16'h0000, //PC for this process (overwritten by CPU, we use first bytes only)       
      
      16'h0000, 16'h0000,  //registers used (currently ignored)
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,
      
      16'h0000, 16'h0000, 16'h0000, 16'h0000, //registers taken "as is"
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000,

      16'h1210, 16'h0a35, //value to reg
      16'h0e10, 16'h0064, //save to ram
      16'h0911, 16'h0064, //ram to reg
      16'h0e10, 16'h00D4, //save to ram      
      16'h0c01, 16'h0001,  //proc
      16'h0c01, 16'h0002,  //proc
      16'h1202, 16'h0003,  //num2reg
      16'hff02, 16'h0002,  //loop,8'hwith,8'hcache:,8'hloopeqvalue
      16'h1402, 16'h0001,  //regminusnum
      16'h1402, 16'h0000,  //regminusnum
      16'h0201, 16'h0001,  //after,8'hloop:,8'hram2reg
      16'h1201, 16'h0005,  //num2reg
      16'h0E01, 16'h0046,  //reg2ram
      16'h0F00, 16'h0002,  //int,8'h2
      16'h010E, 16'h0030,  //jmp,8'h0x30
      
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000      
  };

  // verilog_format:on

  always @(posedge clk) begin
    if (write_enabled && WRITE_RAM_DEBUG == 1)
      $display($time, " ram write ", write_address, " = ", write_value);
    if (READ_RAM_DEBUG == 1) $display($time, " ram read ", read_address, " = ", ram[read_address]);

    if (write_enabled) ram[write_address] <= write_value;
    read_value <= ram[read_address];
  end
endmodule

module uartx_tx_with_buffer (
    input clk,
    input [7:0] uart_buffer[0:128],
    input [6:0] uart_buffer_available,
    output logic reset_uart_buffer_available,
    output logic uart_buffer_full,
    output logic tx
);

  reg [7:0] input_data;
  reg [6:0] uart_buffer_processed = 0;
  reg [3:0] uart_buffer_state = 0;
  reg start;
  wire complete;

  assign reset_uart_buffer_available = 0; //uart_buffer_available != 0 && uart_buffer_available == uart_buffer_processed && uart_buffer_state == 2 && complete?1:0;
  assign uart_buffer_full = uart_buffer_available == 127 ? 1 : 0;
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
    output logic complete,
    output logic uarttx
);

  parameter CLK_PER_BIT = 100000000 / 115200;  //100 Mhz / transmission speed in bits per second

  parameter STATE_IDLE = 0;  //1
  parameter STATE_START_BIT = 1;  //0
  parameter STATE_DATA_BIT_0 = 2;
  //...
  parameter STATE_DATA_BIT_7 = 9;
  parameter STATE_STOP_BIT = 10;  //1

  reg [ 6:0] uart_tx_state = STATE_IDLE;
  reg [10:0] counter = CLK_PER_BIT;

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

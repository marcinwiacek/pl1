`timescale 1ns / 1ps

//#set_property IOSTANDARD LVCMOS12 [get_ports "x"] ;
//#output delay constraint

parameter HARDWARE_DEBUG = 0;
parameter RAM_WRITE_DEBUG = 0;  //1 enabled, 0 disabled //DEBUG info
parameter RAM_READ_DEBUG = 0;  //1 enabled, 0 disabled //DEBUG info
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

parameter EXECUTE_STATE_NONE = 0;
parameter EXECUTE_STATE_READ_EXECUTE = 1;

module x_out_of_order (
    input clk,

    output reg x
);

  //--------------------------------------------------------- mmu ----------------------------

  reg mmu_input;
  wire mmu_ready;
  reg [15:0] mmu_address_logical;
  wire [15:0] mmu_address_physical_min_in_the_same_page,mmu_address_logical_min_in_the_same_page, mmu_address_logical_max_in_the_same_page;

  mmu mmu (
      .clk(clk),
      .inp(mmu_input),
      .address_logical(mmu_address_logical),

      .ready(mmu_ready),
      .address_physical_min_in_the_same_page(mmu_address_physical_min_in_the_same_page),
      .address_logical_min_in_the_same_page(mmu_address_logical_min_in_the_same_page),
      .address_logical_max_in_the_same_page(mmu_address_logical_max_in_the_same_page)
  );

  parameter MMU_QUEUE_LEN = 10;

  reg [15:0] mmuqueue_q_addr[0:MMU_QUEUE_LEN];
  reg [10:0] mmuqueue_q_new_pos = 0;

  //---------------------------------------------------------decoder--------------------------

  reg [15:0] decoder_input_address;
  reg decoder_inp;
  wire decoder_ready;
  wire [5:0] decoder_instruction_state;
  wire [3:0] decoder_error_code;
  wire [15:0] decoder_start_ram_address_or_numeric;
  wire [15:0] decoder_register_end;
  wire [10:0] decoder_register_start;

  decoder decoder (
      .clk(clk),
      .inp(decoder_inp),
      .address(decoder_input_address),
      .instruction1(read_value),
      .instruction2(read_value2),

      .ready(decoder_ready),
      .state(decoder_instruction_state),
      .error_code(decoder_error_code),
      .start_ram_address_or_numeric(decoder_start_ram_address_or_numeric),
      .register_start(decoder_register_start),
      .register_end(decoder_register_end)
  );

  //------------------------------------------------------------ram---------------------------

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
      .read_address2(read_address2),

      .read_value (read_value),
      .read_value2(read_value2)
  );

  parameter SAVERAM_QUEUE_LEN = 32;

  reg [15:0] saveram_q_addr[0:SAVERAM_QUEUE_LEN];
  reg [15:0] saveram_q_value[0:SAVERAM_QUEUE_LEN];
  reg [7:0] saveram_q_new_pos;

  //--------------------------------------------------------------------process------------------

  reg [15:0] process_hardware_address = 0;
  reg [15:0] pc_logical, pc_physical, pc_physical_min_page, pc_physical_max_page;

  reg jmp_stall_exists = 0, fetch_stall_exists = 0;

  reg [15:0] registers_save[0:31];
  reg [15:0] registers[0:31];
  reg [15:0] registers_src_target_address[0:31];
  reg registers_src_ram_needs_mmu[0:31];  //bool
  reg registers_init[0:31] = {
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
  };  //bool
  //reg [15:0] registers_target_address[0:31];
  reg registers_target_ram_address[0:31];  //bool

  //--------------------------------------------------------------------execute------------------

  reg [5:0] executor_state, executor_instruction_state;
  reg [15:0] executor_register_end;
  reg [10:0] executor_register_start;
  reg [15:0] executor_start_ram_address_or_numeric;

  reg [15:0] register[0:1];
  reg [15:0] register_inside[0:1];

  //----------------------------------------------------------------other---------------------------

  assign x = decoder_inp;  //without this we will have empty circuit

  reg rst = 1;
  reg [7:0] instr_num = 0;  // how many done

  integer i;

  reg [15:0] xx;
  reg [15:0] xy;
  reg xz;

  always @(posedge clk) begin
    if (rst) begin
      read_address <= 52;
      read_address2 <= 53;
      decoder_inp <= 1;
      decoder_input_address <= 52;
      $display($time, "   52 starting initial fetch ");
      pc_logical <= 54;
      pc_physical <= 54;
      pc_physical_min_page <= 0;
      pc_physical_max_page <= 200;
      mmu_input <= 0;
      rst <= 0;
      for (i = 0; i < 32; i = i + 1) begin
        registers_target_ram_address[i] <= 0;
        registers_src_ram_needs_mmu[i]  <= 0;
        registers_src_target_address[i] <= process_hardware_address + ADDRESS_REG + i;
      end
      executor_state <= EXECUTE_STATE_NONE;
    end else if (instr_num < 10) begin
    
      if (decoder_ready || executor_state != EXECUTE_STATE_NONE) begin
        //  if (executor_state == EXECUTE_STATE_NONE && (decoder_instruction_state==OPCODE_JMP_PLUS || decoder_instruction_state== OPCODE_JMP_MINUS)) begin
        //  end else begin
        if (executor_state == EXECUTE_STATE_NONE) begin
          $display($time, pc_logical, " executor1   ", " ", executor_state, " ",
                   decoder_instruction_state, " ", decoder_register_start, " ",
                   decoder_register_end, " ", decoder_start_ram_address_or_numeric, " ",
                   decoder_error_code);
          executor_instruction_state <= decoder_instruction_state;
          executor_register_start <= decoder_register_start;
          executor_register_end <= decoder_register_end;
          executor_start_ram_address_or_numeric <= decoder_start_ram_address_or_numeric;
          instr_num <= instr_num + 1;
          executor_state <= EXECUTE_STATE_NONE;
        end else if (executor_state == EXECUTE_STATE_READ_EXECUTE) begin
          $display($time, pc_logical, " executor2   ", " ", executor_state, " ",
                   executor_instruction_state, " ", executor_register_start, " ",
                   executor_register_end, " ", executor_start_ram_address_or_numeric);
          executor_state <= EXECUTE_STATE_NONE;
          if (register[0] != 50) begin
            $display($time, pc_logical, " no fetch register ", register[0], " with address ",
                     read_address, "=", read_value);
            registers[register[0]] <= read_value;
            registers_init[register[0]] <= 1;
          end
          if (register[1] != 50) begin
            $display($time, pc_logical, " no fetch register ", register[1], " with address ",
                     read_address2, "=", read_value2);
            registers[register[1]] <= read_value2;
            registers_init[register[1]] <= 1;
          end
        end
        register[0] <= 50;
        register[0] <= 50;
        for (i = 0; i < 32; i = i + 1) begin
          if (!registers_init[i] && !registers_src_ram_needs_mmu[i] && !registers_target_ram_address[i]) begin
            if (i % 2 == 0) begin
              read_address <= registers_src_target_address[i];
              register[0]  <= i;
            end else begin
              read_address2 <= registers_src_target_address[i];
              register[1]   <= i;
            end
          end
        end
        fetch_stall_exists = 0;
      end
      write_enabled <= 0;
      for (i = 0; i < 32; i = i + 1) begin
      if (mmu_ready) begin
          $display($time, pc_logical, " ", i, " ", registers_init[i], " ",
                   registers_src_ram_needs_mmu[i], " ", registers_src_target_address[i], " ",
                   mmu_address_logical_min_in_the_same_page, " ",
                   mmu_address_logical_max_in_the_same_page);
          if (!registers_init[i] && registers_src_ram_needs_mmu[i] && 
              registers_src_target_address[i]>=mmu_address_logical_min_in_the_same_page && 
              registers_src_target_address[i]<=mmu_address_logical_max_in_the_same_page) begin
            $display(
                $time, pc_logical, " updating reg ", i, " src address to ",
                mmu_address_physical_min_in_the_same_page + registers_src_target_address[i] - mmu_address_logical_min_in_the_same_page);
            registers_src_target_address[i]<= mmu_address_physical_min_in_the_same_page+registers_src_target_address[i]-mmu_address_logical_min_in_the_same_page;
            registers_src_ram_needs_mmu[i] <= 0;
          end
       end
       if (registers_target_ram_address[i] && !registers_src_ram_needs_mmu[i]) begin
          $display($time, pc_logical, " saving ram ", registers_src_target_address[i], "=",
                   registers[i]);
  write_value   <= registers_save[i];
      write_enabled <= 1;
      write_address <= registers_src_target_address[i];
        end
        if (decoder_ready || executor_state != EXECUTE_STATE_NONE) begin
          if (i >= (executor_state == EXECUTE_STATE_NONE?decoder_register_start:executor_register_start) && i <= 
             (executor_state == EXECUTE_STATE_NONE?decoder_register_end:executor_register_end)) begin
            case ((executor_state == EXECUTE_STATE_NONE?decoder_instruction_state:executor_instruction_state))
              OPCODE_RAM2REG: begin
                if (registers_target_ram_address[i]) begin
                  executor_state <= EXECUTE_STATE_READ_EXECUTE;
                end else begin
                  //next time this register should be read
                  registers_init[i] <= 0;
                  registers_src_target_address[i] <= decoder_start_ram_address_or_numeric;
                  registers_src_ram_needs_mmu[i] <= 0;
                  //should calculate physical address
                  //              mmuqueue_q_addr[mmuqueue_q_new_pos] <= decoder_start_ram_address_or_numeric;
                  //                mmuqueue_q_new_pos <= mmuqueue_q_new_pos + 1;
                end
              end
              OPCODE_NUM2REG: begin
                if (registers_target_ram_address[i]) begin
                  executor_state <= EXECUTE_STATE_READ_EXECUTE;
                end else begin
                  //not important if register had any value earlier
                  registers_init[i] <= 1;
                  registers[i] <= decoder_start_ram_address_or_numeric;
                end
              end
              default: begin
                if (!registers_init[i] && (executor_state == EXECUTE_STATE_NONE || 
                    (executor_state != EXECUTE_STATE_NONE && i != register[0] && i != register[1]))) begin
                  executor_state <= EXECUTE_STATE_READ_EXECUTE;
                  fetch_stall_exists = 1;
                  if (!registers_src_ram_needs_mmu[i] && !registers_target_ram_address[i]) begin
                    if (i % 2 == 0) begin
                      read_address <= registers_src_target_address[i];
                      register[0]  <= i;
                    end else begin
                      read_address2 <= registers_src_target_address[i];
                      register[1]   <= i;
                    end
                  end
                end else begin
                  case (decoder_instruction_state)
                    OPCODE_REG2RAM: begin
                      $display($time, pc_logical, " save ram initiate");
                      registers_target_ram_address[i] <= 1;
                      registers_src_target_address[i]<=decoder_start_ram_address_or_numeric+executor_register_start-i;
                      registers_save[i]<= executor_state != EXECUTE_STATE_NONE && i == register[0]?read_value:
                      (executor_state != EXECUTE_STATE_NONE && i == register[1]?read_value2:registers[i]);
                      //saveram_q_addr[0]<=decoder_start_ram_address_or_numeric+executor_register_start-i;
                      //saveram_q_value[0]<= registers[i];
                      //saveram_q_new_pos <= saveram_q_new_pos + 1;
                      //should calculate physical address
                      //mmuqueue_q_addr[0] <= decoder_start_ram_address_or_numeric;
                      //mmuqueue_q_new_pos <= mmuqueue_q_new_pos + 1;
                    end
                    OPCODE_REG_PLUS:
                    registers[i] <= 
                      executor_state != EXECUTE_STATE_NONE && i == register[0]?read_value:
                      (executor_state != EXECUTE_STATE_NONE && i == register[1]?read_value2:registers[i])
                      +decoder_start_ram_address_or_numeric;
                    OPCODE_REG_MINUS:
                    registers[i] <= 
                      executor_state != EXECUTE_STATE_NONE && i == register[0]?read_value:
                      (executor_state != EXECUTE_STATE_NONE && i == register[1]?read_value2:registers[i])
                      - decoder_start_ram_address_or_numeric;
                    OPCODE_REG_MUL:
                    registers[i] <= 
                      executor_state != EXECUTE_STATE_NONE && i == register[0]?read_value:
                      (executor_state != EXECUTE_STATE_NONE && i == register[1]?read_value2:registers[i])
                      * decoder_start_ram_address_or_numeric;
                    OPCODE_REG_DIV:
                    registers[i] <= 
                      executor_state != EXECUTE_STATE_NONE && i == register[0]?read_value:
                      (executor_state != EXECUTE_STATE_NONE && i == register[1]?read_value2:registers[i])
                      / decoder_start_ram_address_or_numeric;
                  endcase
                end
              end
            endcase
          end
        end
      end
      //end

      if (!jmp_stall_exists && !fetch_stall_exists && pc_physical != 0) begin
        read_address  <= pc_physical;
        read_address2 <= pc_physical + 1;
        $display($time, pc_logical, " starting fetch ", pc_physical);
        decoder_input_address <= pc_logical;
        decoder_inp <= 1;
        pc_logical <= pc_logical + 2;
        pc_physical <= pc_physical + 2;
      end else begin
        decoder_inp <= 0;
      end
      if (mmu_ready) begin
        mmu_input <= 0;
        $display($time, pc_logical, " mmu processing ");
      end
      if (mmuqueue_q_new_pos != 0) begin
        mmu_input <= 1;
        $display($time, pc_logical, " starting mmu ", mmuqueue_q_addr[0]);
        mmu_address_logical <= mmuqueue_q_addr[0];
        mmuqueue_q_addr <= {mmuqueue_q_addr[1:MMU_QUEUE_LEN], mmuqueue_q_addr[0]};
        mmuqueue_q_new_pos <= mmuqueue_q_new_pos - 1;
      end

      //if (saveram_q_new_pos != 0) begin
      //        write_enabled <= 1;
      //        write_address <= saveram_q_addr[0];
      //        write_value   <= saveram_q_value[0];
      //        $display($time, pc_logical, " saving ram ", saveram_q_addr[0], "=", saveram_q_value[0]);
      //        //saveram_q <= {saveram_q[1:SAVERAM_QUEUE_LEN], saveram_q[0]};
      //        saveram_q_new_pos <= saveram_q_new_pos - 1;
      //      end else begin
      //        write_enabled <= 0;
      //      end

    end else begin
      decoder_inp = 0;
    end
  end
endmodule

module decoder (
    input clk,
    input reg [15:0] address,
    input reg [15:0] instruction1,
    instruction2,
    input bit inp,

    output bit ready,
    output bit [5:0] state,
    output bit [3:0] error_code,
    output bit [15:0] start_ram_address_or_numeric,
    output bit [15:0] register_end,
    output bit [10:0] register_start
);

  bit [7:0] instruction1_1;
  bit [7:0] instruction1_2;
  bit [4:0] instruction1_2_1;
  bit [2:0] instruction1_2_2;
  bit [7:0] instruction2_1;
  bit [7:0] instruction2_2;

  assign instruction1_1   = instruction1[15:8];
  assign instruction1_2   = instruction1[7:0];
  assign instruction1_2_1 = instruction1[4:0];
  assign instruction1_2_2 = instruction1[7:5];
  assign instruction2_1   = instruction2[15:8];
  assign instruction2_2   = instruction2[7:0];

  always @(posedge clk) begin
    if (inp) begin
      ready <= inp;
      $display(  //DEBUG info
          $time,  //DEBUG info
          address, " decoder ", " b1 %c",  //DEBUG info
          instruction1_1 / 16 >= 10 ? instruction1_1 / 16 + 65 - 10 : instruction1_1 / 16 + 48,  //DEBUG info
          "%c",  //DEBUG info
          instruction1_1 % 16 >= 10 ? instruction1_1 % 16 + 65 - 10 : instruction1_1 % 16 + 48,  //DEBUG info
          "%c",  //DEBUG info
          instruction1_2 / 16 >= 10 ? instruction1_2 / 16 + 65 - 10 : instruction1_2 / 16 + 48,  //DEBUG info
          "%c",  //DEBUG info
          instruction1_2 % 16 >= 10 ? instruction1_2 % 16 + 65 - 10 : instruction1_2 % 16 + 48,  //DEBUG info
          "h (",  //DEBUG info
          instruction1_2_1,  //DEBUG info
          "-",  //DEBUG info
          instruction1_2_2,  //DEBUG info
          ") b2 ",  //DEBUG info
          instruction2,  //DEBUG info
          " (", instruction2_1, "-", instruction2_2, ") ", instruction1, " ",
          instruction2);  //DEBUG info

      error_code <= 0;
      start_ram_address_or_numeric <= instruction2;
      register_start <= instruction1_2_1;
      register_end <= instruction1_2_1 + instruction1_2_2;
      state <= instruction1_1;

      case (instruction1_1)
        //register num (5 bits), how many-1 (3 bits), 16 bit addr
        OPCODE_RAM2REG, OPCODE_REG2RAM: begin
          if (instruction1_2_1 + instruction1_2_2 >= 32) begin
            error_code <= ERROR_WRONG_REG_NUM;
          end else if (instruction2 < ADDRESS_PROGRAM) begin
            error_code <= ERROR_WRONG_ADDRESS;
          end else if (instruction1_1 == OPCODE_RAM2REG) begin
            $display(  //DEBUG info
                $time,  //DEBUG info
                " opcode = ram2reg read value from logical address ",  //DEBUG info
                instruction2,  //DEBUG info
                "+ to reg ",  //DEBUG info
                instruction1_2_1,  //DEBUG info
                "-",  //DEBUG info
                (instruction1_2_1 + instruction1_2_2)  //DEBUG info
            );  //DEBUG info
          end else begin
            $display(  //DEBUG info
                $time,  //DEBUG info
                " opcode = reg2ram save reg ",  //DEBUG info
                instruction1_2_1,  //DEBUG info
                "-",  //DEBUG info
                (instruction1_2_1 + instruction1_2_2),  //DEBUG info
                " to ram logical address ",  //DEBUG info
                instruction2,  //DEBUG info
                "+"  //DEBUG info
            );  //DEBUG info
          end
        end
        //register num (5 bits), how many-1 (3 bits), 16 bit value
        OPCODE_NUM2REG, OPCODE_REG_PLUS, OPCODE_REG_MUL, OPCODE_REG_DIV: begin
          if (instruction1_2_1 + instruction1_2_2 >= 32) begin
            error_code <= ERROR_WRONG_REG_NUM;
          end else begin
            $display(  //DEBUG info
                $time,  //DEBUG info
                " opcode = ",
                (instruction1_1 == OPCODE_NUM2REG ? "num2reg save" : (instruction1_1 == OPCODE_REG_PLUS ? "regplus add" : (instruction1_1 == OPCODE_REG_MUL ? "regmul mul" : "regdiv div")))
                , " value ",  //DEBUG info
                instruction2,  //DEBUG info
                " to reg ",  //DEBUG info
                instruction1_2_1,  //DEBUG info
                "-",  //DEBUG info
                (instruction1_2_1 + instruction1_2_2)  //DEBUG info
            );  //DEBUG info
          end
        end
        //x, 16 bit how many instructions
        OPCODE_JMP_PLUS, OPCODE_JMP_MINUS: begin
        end
        default: begin
          state                        <= ERROR_WRONG_OPCODE;
          start_ram_address_or_numeric <= 0;
          register_start               <= 0;
          register_end                 <= 0;
        end
      endcase
    end
  end
endmodule

module mmu (
    input clk,
    input inp,
    output bit ready = 0,
    input reg [15:0] address_logical,
    output reg [15:0] address_physical_min_in_the_same_page,
    output reg [15:0] address_logical_min_in_the_same_page,
    output reg [15:0] address_logical_max_in_the_same_page
);

  always @(posedge clk) begin
    ready <= inp;
    if (inp) begin
      address_physical_min_in_the_same_page <= 0;
      address_logical_min_in_the_same_page  <= 0;
      address_logical_max_in_the_same_page  <= 200;
      $display($time, " mmu ", address_logical, " -> ", (0 + address_logical - 0));
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
      16'h1611, 16'd0101, //mul // not used for anything usefull, just for debugging
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
    if (write_enabled && RAM_WRITE_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
      $display($time, " ram write ", write_address, " = ", write_value);  //DEBUG info
    if (RAM_READ_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
      $display($time, " ram read ", read_address, " = ", ram[read_address]);  //DEBUG info

    if (write_enabled) ram[write_address] <= write_value;
  end
endmodule

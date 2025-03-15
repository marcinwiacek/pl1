`timescale 1ns / 1ps

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

parameter OPCODE_REG2REG = 33;


parameter EXECUTE_STATE_START = 0;
parameter EXECUTE_STATE_CONTINUE = 1;
parameter EXECUTE_STATE_MMU = 2;



module x_out_of_order2 (
    input clk,

    output reg x
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

  reg [10:0] saveram_q_num = 0;

  //--------------------------------------------------------- mmu ----------------------------

  // reg mmu_input;
  //wire mmu_ready;
  reg [15:0] mmu_address_logical;
  reg [15:0]
      mmu_address_physical_min_in_the_same_page = 0,
      mmu_address_logical_min_in_the_same_page = 0,
      mmu_address_logical_max_in_the_same_page = 500;

  /*mmu mmu (
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
  reg [15:0] mmuqueue_q_len[0:MMU_QUEUE_LEN];
  reg [10:0] mmuqueue_q_new_pos = 0;
*/

  //---------------------------------------------------------decoder--------------------------

  reg [15:0] decoder_input_address;
  reg decoder_inp;
  wire decoder_ready;
  wire [5:0] decoder_instruction_state;
  wire [3:0] decoder_error_code;
  wire [15:0] decoder_start_ram_address_or_numeric;
  wire [15:0] decoder_register_len;
  wire [10:0] decoder_register_start;
  wire [32:0] decoder_do_op;

  decoder decoder (
      .clk(clk),
      .inp(decoder_inp),
      .address(decoder_input_address),
      .instruction1(read_value),
      .instruction2(read_value2),

      .do_op(decoder_do_op),
      .ready(decoder_ready),
      .state(decoder_instruction_state),
      .error_code(decoder_error_code),
      .start_ram_address_or_numeric(decoder_start_ram_address_or_numeric),
      .register_start(decoder_register_start),
      .register_len(decoder_register_len)
  );

  //--------------------------------------------------------------------executor------------------

  reg [5:0] executor_state, executor_instruction_state;
  reg [6:0] executor_register_len;
  reg [6:0] executor_register_start;
  reg [15:0] executor_start_ram_address_or_numeric;
  reg [32:0] executor_do_op;

  reg [6:0] register[0:1];  //, register2[0:1];
  //reg [15:0] register_inside[0:1];

  reg register_save_lock[0:32];

  parameter RANDOM_SELECTED_EMPTY_VALUE_HIGHER_THAN_32 = 33;

  //--------------------------------------------------------------------process------------------

  reg [ 5:0] reg_instruction_state;
  reg [15:0] reg_register_len;
  reg [10:0] reg_register_start;
  reg [15:0] reg_start_ram_address_or_numeric;
  reg [32:0] reg_do_op;

  assign reg_register_start =  executor_state == EXECUTE_STATE_START?decoder_register_start:executor_register_start;
  assign reg_register_len =  executor_state == EXECUTE_STATE_START ? decoder_register_len : executor_register_len;
  assign reg_instruction_state =  executor_state == EXECUTE_STATE_START?decoder_instruction_state:executor_instruction_state;
  assign reg_start_ram_address_or_numeric = executor_state == EXECUTE_STATE_START?decoder_start_ram_address_or_numeric:executor_start_ram_address_or_numeric;
  assign reg_do_op = executor_state == EXECUTE_STATE_START ? decoder_do_op : executor_do_op;

  parameter REGISTER_NUM = 32;

  reg [15:0] process_hardware_address = 0;
  reg [15:0] pc_logical, pc_physical;

  reg jmp_stall_exists = 0, fetch_stall_exists = 0;

  // reg [6:0] save_counter, save_counter_for_read, save_counter_for_read2;

  reg [15:0] registers[0:REGISTER_NUM-1], registers_save[0:REGISTER_NUM-1];
  // reg [6:0] registers_save_counter[0:REGISTER_NUM-1], registers_save_save_counter[0:REGISTER_NUM-1];
  reg [15:0]
      registers_src_address[0:REGISTER_NUM-1],
      registers_src_address2[0:REGISTER_NUM-1],
      registers_save_address[0:REGISTER_NUM-1],
      registers_save_address2[0:REGISTER_NUM-1];
  reg
      registers_src_mmu_done[0:REGISTER_NUM-1],
      registers_init[0:REGISTER_NUM-1] = {
        // verilog_format:off
        1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1
        // verilog_format:on
      },  //Read from RAM?
      registers_save_ready[0:REGISTER_NUM-1],
      registers_save_mmu_done[0:REGISTER_NUM-1];

  //----------------------------------------------------------------other---------------------------

  assign x = decoder_inp;  //without this we will have empty circuit

  reg rst = 1;
  reg [7:0] instr_num = 0;  // how many done

  integer i, j, z;

  reg [15:0] read_valueee, read_valueee2;
  reg [6:0] registers_save_countereeee, registers_save_countereeee2;
  reg [6:0] p, q;

  /*
  always @(posedge clk) begin
      //registers_save_countereeee2 = 0;
      read_valueee2 = 32; 
      read_valueee = 32;
      for (z = 0; z < REGISTER_NUM; z = z + 1) begin
        //if (read_address2 == registers_save_address[z]) begin// && registers_save_save_counter[z]>registers_save_countereeee2) begin          //if (q >registers_save_countereeee2) begin // &&  q<save_counter_for_read2) begin
            read_valueee2 =read_address2 == registers_save_address[z] && registers_save_save_counter[z]>registers_save_save_counter[registers_save_countereeee2]?z:read_valueee2;
              read_valueee = read_address == registers_save_address[z] && registers_save_save_counter[z]>registers_save_save_counter[read_valueee]?z:read_valueee;
          
            //registers_save_countereeee2=registers_save_save_counter[z];
        //end
      end
  end
*/

  always @(posedge clk) begin
    if (rst) begin
      registers = '{default: 0};
      read_address <= 52;
      read_address2 <= 53;
      decoder_inp <= 1;
      decoder_input_address <= 52;
      $display($sformatf("%02d", $time), "   52 starting initial fetch ");  //DEBUG info
      pc_logical <= 54;
      pc_physical <= 54;
      rst <= 0;
      for (i = 0; i < REGISTER_NUM; i = i + 1) begin
        registers_src_mmu_done[i]  <= 1;
        registers_save_mmu_done[i] <= 0;
        registers_src_address[i]   <= process_hardware_address + ADDRESS_REG + i;
      end
      executor_state <= EXECUTE_STATE_START;
      fetch_stall_exists = 0;
      saveram_q_num <= RANDOM_SELECTED_EMPTY_VALUE_HIGHER_THAN_32;
      // save_counter  <= 0;
      register[0]   <= RANDOM_SELECTED_EMPTY_VALUE_HIGHER_THAN_32;
      register[1]   <= RANDOM_SELECTED_EMPTY_VALUE_HIGHER_THAN_32;
    end else if (instr_num < 10) begin
      $write($sformatf("%02d", $time), " reg");
      for (i = 0; i < 20; i = i + 1) begin
        $write($sformatf(" %02d:%02d:%02d ", i, registers_init[i], registers[i]));
        //if (registers_init[i]) begin
        //          $write($sformatf(" %02d:%02d(- %02d)", i, registers[i], registers_save_save_counter[i]));
        //        end else begin
        //          $write($sformatf(" %02d:-(%02d %02d)", i, registers_save_counter[i],
        //                           registers_save_save_counter[i]));
        //  end
      end
      $display("");
      // $display("save ram ", saveram_q_num, " save counter ", save_counter);
      //save ram              
      write_enabled <= saveram_q_num != RANDOM_SELECTED_EMPTY_VALUE_HIGHER_THAN_32;
      if (saveram_q_num != RANDOM_SELECTED_EMPTY_VALUE_HIGHER_THAN_32) begin
        register_save_lock[saveram_q_num] <= 0;
        registers_save_ready[saveram_q_num] <= 0;
        registers_save_mmu_done[saveram_q_num] <= 0;
        write_address <= registers_save_address2[saveram_q_num];
        write_value <= registers_save[saveram_q_num];
        saveram_q_num <= RANDOM_SELECTED_EMPTY_VALUE_HIGHER_THAN_32;
        // for (i = 0; i < REGISTER_NUM; i = i + 1) begin
        //   registers_save_save_counter[i]<=registers_save_save_counter[i]>0?registers_save_save_counter[i]-1:0;
        //    registers_save_counter[i]<=registers_save_counter[i]>0?registers_save_counter[i]-1:0;
        //  end
        //   save_counter = save_counter > 0 ? save_counter - 1 : 0;
      end else begin
        for (i = 0; i < REGISTER_NUM; i = i + 1) begin
          if (registers_save_ready[i]) begin  // && registers_save_save_counter[i] == 0) begin
            saveram_q_num <= i;
          end
        end
      end


      if (register[0] != RANDOM_SELECTED_EMPTY_VALUE_HIGHER_THAN_32) begin
        $display($sformatf("%02d", $time), pc_logical, " first slot fetch register ", register[0],
                 " with address ",  //DEBUG info
                 read_address, "=", read_value);  //DEBUG info
        registers[register[0]] = read_value; //read_valueee!=32 ? registers_save[read_valueee] : read_value;
        registers_init[register[0]] = 1;
        register[0] <= RANDOM_SELECTED_EMPTY_VALUE_HIGHER_THAN_32;
      end
      if (register[1] != RANDOM_SELECTED_EMPTY_VALUE_HIGHER_THAN_32) begin
        $display($sformatf("%02d", $time), pc_logical, " second slot register ", register[1],
                 " with address ",  //DEBUG info
                 read_address2, "=", read_value2);  //DEBUG info
        registers[register[1]] = read_value2; //read_valueee2!=32? registers_save[read_valueee2] : read_value2;
        registers_init[register[1]] = 1;
        register[1] <= RANDOM_SELECTED_EMPTY_VALUE_HIGHER_THAN_32;
      end
      for (i = 0; i < REGISTER_NUM; i = i + 1) begin
        if (!registers_init[i] && registers_src_mmu_done[i]) begin // && registers_save_counter[i]==0) begin
          if (i % 2 == 0) begin
            read_address <= registers_src_address2[i];
            //   save_counter_for_read <= registers_save_counter[i];
          end else begin
            read_address2 <= registers_src_address2[i];
            //    save_counter_for_read2 <= registers_save_counter[i];
          end
          register[i%2] <= i;
        end
      end

      //executor
      if (decoder_ready || executor_state != EXECUTE_STATE_START) begin
        if (executor_state == EXECUTE_STATE_START) begin
          $display($sformatf("%02d", $time), pc_logical, " executor1   ", " ", executor_state,
                   " ",  //DEBUG info
                   decoder_instruction_state, " ", decoder_register_start, " ",  //DEBUG info
                   decoder_register_len, " ", decoder_start_ram_address_or_numeric,
                   " ",  //DEBUG info
                   decoder_error_code);  //DEBUG info
          executor_instruction_state <= decoder_instruction_state;
          executor_register_start <= decoder_register_start;
          executor_register_len <= decoder_register_len;
          executor_start_ram_address_or_numeric <= decoder_start_ram_address_or_numeric;
          executor_do_op <= decoder_do_op;
          instr_num <= instr_num + 1;
        end else begin
          $display($sformatf("%02d", $time), " executor state ", executor_state, " ", register[0],
                   " ", register[1]);
        end
        case (executor_state)
          EXECUTE_STATE_START, EXECUTE_STATE_CONTINUE: begin
            executor_state <= EXECUTE_STATE_START;
            fetch_stall_exists = 0;

            //cannot join with previous loop
            for (i = 0; i < REGISTER_NUM; i = i + 1) begin
              if (reg_do_op[i]) begin
                case (reg_instruction_state)
                  OPCODE_RAM2REG: begin
                    executor_do_op[i] <= 0;
                    //this register should be read next time
                    registers_init[i] = 0;
                    registers_src_mmu_done[i] <= 0;
                    registers_src_address[i] <= decoder_start_ram_address_or_numeric+i-decoder_register_start;
                    //   registers_save_counter[i] <= save_counter;
                  end
                  OPCODE_NUM2REG: begin
                    executor_do_op[i] <= 0;
                    //not important if register had value earlier
                    registers_init[i] = 1;
                    registers_src_mmu_done[i] <= 1;
                    registers[i] = decoder_start_ram_address_or_numeric;
                    $display($sformatf("%02d", $time), pc_logical, " set reg ", i, " with value ",
                             decoder_start_ram_address_or_numeric);
                  end
                  default: begin
                    if (!registers_init[i]) begin
                      fetch_stall_exists = 1;
                      executor_state <= registers_src_mmu_done[i]?EXECUTE_STATE_CONTINUE:EXECUTE_STATE_MMU;
                      mmu_address_logical <= registers_src_address[i];
                      if (registers_src_mmu_done[i]) begin // && registers_save_counter[i] == 0) begin
                        $display($sformatf("%02d", $time), pc_logical, " need to fetch register ",
                                 i, " src address ", registers_src_address2[i]);
                        if (i % 2 == 0) begin
                          read_address <= registers_src_address2[i];
                          //  save_counter_for_read <= registers_save_counter[i];
                        end else begin
                          read_address2 <= registers_src_address2[i];
                          //   save_counter_for_read2 <= registers_save_counter[i];
                        end
                        register[i%2] <= i;
                      end
                    end else begin
                      case (reg_instruction_state)
                        OPCODE_REG2RAM: begin
                          if (register_save_lock[i]) begin
                            executor_state <= registers_save_mmu_done[i]?EXECUTE_STATE_CONTINUE:EXECUTE_STATE_MMU;
                            mmu_address_logical <= registers_save_address[i];
                            $display($sformatf("%02d", $time), pc_logical, " write memory slot ",
                                     i, " is already filled, stall");
                          end else begin
                            executor_do_op[i] <= 0;
                            registers_save_address[i] <= reg_start_ram_address_or_numeric+i-reg_register_start;
                            register_save_lock[i] <= 1;
                            registers_save[i] <= registers[i];
                            //  registers_save_save_counter[i] <= save_counter;
                          end
                        end
                        OPCODE_REG_PLUS: begin
                          executor_do_op[i] <= 0;
                          $display($sformatf("%02d", $time), pc_logical, " ", register[0], " ",
                                   register[1], " ", read_value, " ", read_value2);
                          $display($sformatf("%02d", $time), pc_logical, " reg ", i,
                                   " plus with value ", reg_start_ram_address_or_numeric, " old ",
                                   registers[i]);
                          registers[i] = registers[i] + reg_start_ram_address_or_numeric;
                        end
                        OPCODE_REG_MINUS: begin
                          executor_do_op[i] <= 0;
                          $display($sformatf("%02d", $time), pc_logical, " reg ", i,
                                   " minus with value ", reg_start_ram_address_or_numeric, " old ",
                                   registers[i]);
                          registers[i] = registers[i] - reg_start_ram_address_or_numeric;
                        end
                      endcase
                    end
                  end
                endcase
              end
            end

          end
          EXECUTE_STATE_MMU: begin
            //mmu
            $display($sformatf("%02d", $time), pc_logical, " mmu processing ");  //DEBUG info
            for (i = 0; i < REGISTER_NUM; i = i + 1) begin
              $display($sformatf("%02d", $time), pc_logical, " ", i, " ", registers_init[i], " ",
                       registers_src_mmu_done[i], " ", registers_src_address[i], " ",
                       mmu_address_logical_min_in_the_same_page, " ",
                       mmu_address_logical_max_in_the_same_page);
              if (!registers_src_mmu_done[i] &&
              registers_src_address[i]>=mmu_address_logical_min_in_the_same_page && 
              registers_src_address[i]<=mmu_address_logical_max_in_the_same_page) begin
                $display(  //DEBUG info
                    $sformatf("%02d", $time), pc_logical, " updating reg ", i,
                    " src address to ",  //DEBUG info
                    mmu_address_physical_min_in_the_same_page + registers_src_address[i] - mmu_address_logical_min_in_the_same_page);  //DEBUG info
                registers_src_address2[i]<= mmu_address_physical_min_in_the_same_page+registers_src_address[i]-mmu_address_logical_min_in_the_same_page;
                registers_src_mmu_done[i] <= 1;
              end
              if (register_save_lock[i] && registers_save_address[i]>=mmu_address_logical_min_in_the_same_page && 
              registers_save_address[i]<=mmu_address_logical_max_in_the_same_page) begin
                $display(  //DEBUG info
                    $sformatf("%02d", $time), pc_logical, " updating save ram ", i,
                    " src address from ");
                registers_save_address2[i]<= mmu_address_physical_min_in_the_same_page+registers_save_address[i]-mmu_address_logical_min_in_the_same_page;
                registers_save_mmu_done[i] <= 1;
                registers_save_ready[i] <= 1;
              end
            end
            executor_state <= EXECUTE_STATE_CONTINUE;
          end
        endcase


      end

      decoder_inp <= 0;
      if (!fetch_stall_exists) begin
        // if (reg_instruction_state == OPCODE_REG2RAM) save_counter = save_counter + 1;
        //decoder            
        read_address  <= pc_physical;
        read_address2 <= pc_physical + 1;
        $display($sformatf("%02d", $time), pc_logical, " starting fetch ", pc_physical);
        decoder_input_address <= pc_logical;
        decoder_inp <= 1;
        pc_logical <= pc_logical + 2;
        pc_physical <= pc_physical + 2;
        register[0] <= RANDOM_SELECTED_EMPTY_VALUE_HIGHER_THAN_32;
        register[1] <= RANDOM_SELECTED_EMPTY_VALUE_HIGHER_THAN_32;
      end
    end else begin
      decoder_inp <= 0;
    end
  end
endmodule

module decoder (
    input clk,
    input reg [15:0] address,
    input reg [15:0] instruction1,
    instruction2,
    input bit inp,

    output bit [32:0] do_op,
    output bit ready,
    output bit [5:0] state,
    output bit [3:0] error_code,
    output bit [15:0] start_ram_address_or_numeric,
    output bit [15:0] register_len,
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

  integer i;

  always @(posedge clk) begin
    if (inp) begin
      ready <= inp;
      $display(  //DEBUG info
          $sformatf("%02d", $time),  //DEBUG info
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
      register_len <= instruction1_2_2;
      state <= instruction1_1;

      for (i = 0; i < 33; i = i + 1) begin
        do_op[i] <= (i >= instruction1_2_1 && i <= instruction1_2_1 + instruction1_2_2) ? 1 : 0;
      end
      case (instruction1_1)
        //register num (5 bits), how many-1 (3 bits), 16 bit addr
        OPCODE_RAM2REG, OPCODE_REG2RAM: begin
          if (instruction1_2_1 + instruction1_2_2 >= 32) begin
            error_code <= ERROR_WRONG_REG_NUM;
          end else if (instruction2 < ADDRESS_PROGRAM) begin
            error_code <= ERROR_WRONG_ADDRESS;
          end else if (instruction1_1 == OPCODE_RAM2REG) begin
            $display(  //DEBUG info
                $sformatf("%02d", $time),  //DEBUG info
                " opcode = ram2reg read value from logical address ",  //DEBUG info
                instruction2,  //DEBUG info
                "+ to reg ",  //DEBUG info
                instruction1_2_1,  //DEBUG info
                "-",  //DEBUG info
                (instruction1_2_1 + instruction1_2_2)  //DEBUG info
            );  //DEBUG info
          end else begin
            $display(  //DEBUG info
                $sformatf("%02d", $time),  //DEBUG info
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
            $write(  //DEBUG info
                $sformatf("%02d", $time),  //DEBUG info
                " opcode = ");  //DEBUG info
            case (instruction1_1)  //DEBUG info
              OPCODE_NUM2REG:  $write("num2reg save");  //DEBUG info
              OPCODE_REG_PLUS: $write("regplus add");  //DEBUG info
              OPCODE_REG_MUL:  $write("regmul mul");  //DEBUG info
              OPCODE_REG_DIV:  $write("regdiv div");  //DEBUG info
            endcase  //DEBUG info
            $display(" value ",  //DEBUG info
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
          register_len                 <= 0;
        end
      endcase
    end
  end
endmodule

/*module mmu (
    input clk,
    input inp,
    output bit ready = 0,
    input reg [15:0] address_logical,
    output reg [15:0] address_physical_min_in_the_same_page,
    output reg [15:0] address_logical_min_in_the_same_page,
    output reg [15:0] address_logical_max_in_the_same_page
);

  always @(negedge clk) begin
    ready <= inp;
    if (inp) begin
      address_physical_min_in_the_same_page <= 0;
      address_logical_min_in_the_same_page  <= 0;
      address_logical_max_in_the_same_page  <= 500;
      $display($sformatf("%02d", $time), " mmu ", address_logical, " -> ",
               (0 + address_logical - 0));
    end
  end
endmodule
*/

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

      16'h1209, 16'd2613, //value to reg // not used for anything usefull, just for debugging
      16'h0e09, 16'd0212, //save to ram // not used for anything usefull, just for debugging
      16'h090b, 16'd0212, //ram to reg // not used for anything usefull, just for debugging
      16'h140b, 16'd0101, //add // not used for anything usefull, just for debugging
      16'h0e09, 16'd0290, //save to ram // not used for anything usefull, just for debugging
      16'h090a, 16'd0100, //ram to reg // not used for anything usefull, just for debugging
      16'h160a, 16'd0101, //mul // not used for anything usefull, just for debugging
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
    if (write_enabled)  // && RAM_WRITE_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
      $display(
          $sformatf("%02d", $time), " ram write ", write_address, " = ", write_value
      );  //DEBUG info
    if (RAM_READ_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
      $display(
          $sformatf("%02d", $time), " ram read ", read_address, " = ", ram[read_address]
      );  //DEBUG info

    if (write_enabled) ram[write_address] <= write_value;
  end
endmodule

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
parameter OPCODE_TILL_VALUE =23;   //register num (8 bit), value (8 bit), how many instructions back (8 bit value) // do..while
parameter OPCODE_TILL_NON_VALUE=24;   //register num, value, how many instructions back (8 bit value) //do..while
parameter OPCODE_LOOP = 25;  //x, x, how many instructions (8 bit value) //for...
parameter OPCODE_FREE = 31;  //free ram pages x-y 
parameter OPCODE_FREE_LEVEL =32; //free ram pages allocated after page x (or pages with concrete level)
//parameter OPCODE_REG_INT_NON_BLOCKING =33; //int number (8 bit), address to jump in case of int

parameter OPCODE_REG2REG = 33;

parameter EXECUTE_STATE_START = 0;
parameter EXECUTE_STATE_CONTINUE = 1;
parameter EXECUTE_STATE_MMU = 2;


parameter REGISTER_NUM = 32;

module x_out_of_order5 (
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

  parameter RANDOM_SELECTED_EMPTY_VALUE_HIGHER_THAN_32 = REGISTER_NUM + 1;

  reg [ 6:0] saveram_q_num = RANDOM_SELECTED_EMPTY_VALUE_HIGHER_THAN_32;

  //--------------------------------------------------------- mmu ----------------------------

  reg [15:0] mmu_address_logical;
  reg [15:0]
      mmu_address_physical_min_in_the_same_page = 0,
      mmu_address_logical_min_in_the_same_page = 0,
      mmu_address_logical_max_in_the_same_page = 500;

  //---------------------------------------------------------decoder--------------------------

  reg decoder_slot;
  reg [15:0] decoder_input_address;
  reg decoder_inp;
  wire decoder_ready;
  wire [5:0] decoder_instruction_state[0:1];
  wire [3:0] decoder_error_code[0:1];
  wire [15:0] decoder_start_ram_address_or_numeric[0:1];
  wire [6:0] decoder_register_len[0:1];
  wire [6:0] decoder_register_start[0:1];
  reg decoder_do_op2[REGISTER_NUM-1:0];
  wire decoder_do_op0[REGISTER_NUM-1:0][0:1];

  decoder decoder (
      .clk(clk),
      .inp(decoder_inp),
      .address(decoder_input_address),
      .instruction1(read_value),
      .instruction2(read_value2),
      .slot(decoder_slot),
      .do_op(decoder_do_op0),
      .ready(decoder_ready),
      .state(decoder_instruction_state),
      .error_code(decoder_error_code),
      .start_ram_address_or_numeric(decoder_start_ram_address_or_numeric),
      .register_start(decoder_register_start),
      .register_len(decoder_register_len)
  );

  //--------------------------------------------------------------------executor------------------

  reg [5:0] executor_state;
  reg [6:0] register[0:1];
  reg register_save_lock[0:REGISTER_NUM];

  //--------------------------------------------------------------------process------------------

  reg [15:0] process_hardware_address = 0;
  reg [15:0] pc_logical, pc_physical;
  reg [15:0] registers_value[0:REGISTER_NUM], registers_save_value[0:REGISTER_NUM];
  reg [15:0]
      registers_src_address[0:REGISTER_NUM],
      registers_src_address2[0:REGISTER_NUM],
      registers_save_address[0:REGISTER_NUM],
      registers_save_address2[0:REGISTER_NUM];
  reg registers_src_mmu_done[0:REGISTER_NUM],
      registers_init[0:REGISTER_NUM] = {
        // verilog_format:off
        1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1
        // verilog_format:on
      },  //Read from RAM?
      registers_save_ready[0:REGISTER_NUM],
      registers_save_mmu_done[0:REGISTER_NUM];

  //----------------------------------------------------------------other---------------------------

  reg rst = 1;
  reg [4:0] instr_num = 0;  // how many done

  assign x = decoder_inp;  //without this we will have empty circuit

  integer i, zz, pp, qq;

  reg [ 6:0] readstallindex;
  reg [15:0] readsaveaddr;
  reg readstallnotprocessed, readstallavail;

  always @(posedge clk) begin
    //$display("decoder slot is ",decoder_slot," ",decoder_start_ram_address_or_numeric[!decoder_slot]);
    readstallavail <= 0;
    if (readstallnotprocessed) begin
      for (zz = 0; zz < REGISTER_NUM; zz = zz + 1) begin
        if (register_save_lock[zz]) begin
          if (registers_save_address[zz] >= decoder_start_ram_address_or_numeric[!decoder_slot]) begin
            if(registers_save_address[zz] <= decoder_start_ram_address_or_numeric[!decoder_slot]+decoder_register_len[!decoder_slot]) begin
              readstallavail <= 1;
              readstallindex <= zz;
              readsaveaddr   <= registers_save_address[zz];
              $display(
                  $sformatf("%02d", $time), pc_logical, " read stall (next cycle) ", zz,
                  " - register, value ", registers_save_address[zz], " between ",
                  decoder_start_ram_address_or_numeric[!decoder_slot], " and ",
                  (decoder_start_ram_address_or_numeric[!decoder_slot] + decoder_register_len[!decoder_slot]));
            end
          end
        end
      end
    end
  end

  always @(posedge clk) begin
    for (qq = 0; qq < REGISTER_NUM; qq = qq + 1) begin
      if (readstallavail) begin
        if (!registers_init[qq]) begin
          if (registers_src_address[qq] == readsaveaddr) begin
            $display($sformatf("%02d", $time), " read register from read stall ", qq,
                     " with value ", registers_save_value[readstallindex]);  //DEBUG info
            registers_value[qq] <= registers_save_value[readstallindex];
          end
        end
      end
      if (register[0] == qq) registers_value[qq] <= read_value;
      if (register[1] == qq) registers_value[qq] <= read_value2;
      if (decoder_ready && executor_state != EXECUTE_STATE_MMU) begin
        if (executor_state == EXECUTE_STATE_START ?decoder_do_op0[qq][!decoder_slot]:decoder_do_op2[qq]) begin
          decoder_do_op2[qq] <= 1;
          if (registers_init[qq] && executor_state != EXECUTE_STATE_MMU) begin
            case (decoder_instruction_state[!decoder_slot])
              OPCODE_NUM2REG: begin
                //not important if register had value earlier
                registers_value[qq] <= decoder_start_ram_address_or_numeric[!decoder_slot];
              end
              OPCODE_REG_PLUS: begin
                decoder_do_op2[qq] <= 0;
                $display($sformatf("%02d", $time), pc_logical, " ", register[0], " ", register[1],
                         " ", read_value, " ", read_value2);
                $display($sformatf("%02d", $time), pc_logical, " reg ", qq, " plus with value ",
                         decoder_start_ram_address_or_numeric, " old ", registers_value[qq]);
                registers_value[qq] <= registers_value[qq][!decoder_slot] + decoder_start_ram_address_or_numeric[!decoder_slot];
              end
              OPCODE_REG_MINUS: begin
                decoder_do_op2[qq] <= 0;
                $display($sformatf("%02d", $time), pc_logical, " reg ", qq, " minus with value ",
                         decoder_start_ram_address_or_numeric, " old ", registers_value[qq]);
                registers_value[qq] <= registers_value[qq] - decoder_start_ram_address_or_numeric[!decoder_slot];
              end
              OPCODE_REG2RAM: begin
                if (!register_save_lock[qq] || saveram_q_num == qq) begin
                  decoder_do_op2[qq] <= 0;
                end
              end
            endcase
          end
        end
      end
    end
  end

  always @(posedge clk) begin
    if (rst) begin
      registers_value <= '{default: 0};
      registers_value[9] <= 1;
      read_address <= 52;
      read_address2 <= 53;
      decoder_inp <= 1;
      decoder_input_address <= 52;
      $display($sformatf("%02d", $time), "   52 starting initial fetch ");  //DEBUG info
      $display("");
      pc_logical <= 52;
      pc_physical <= 52;
      rst <= 0;
      for (i = 0; i < REGISTER_NUM; i = i + 1) begin
        registers_src_mmu_done[i] <= 1;
        //registers_save_ready[i] <= 0;
        registers_src_address2[i] <= process_hardware_address + ADDRESS_REG + i;
        registers_save_address[i] <= 0;
        registers_save_mmu_done[i] <= 0;
        register_save_lock[i] <= 0;
      end
      executor_state <= EXECUTE_STATE_START;
      register[0] <= RANDOM_SELECTED_EMPTY_VALUE_HIGHER_THAN_32;
      register[1] <= RANDOM_SELECTED_EMPTY_VALUE_HIGHER_THAN_32;
      readstallnotprocessed <= 1;
      decoder_slot <= 0;
    end else if (instr_num < 10) begin
      $write($sformatf("%02d", $time), " reg");
      for (i = 0; i < 20; i = i + 1) begin
        $write($sformatf(" %02d:%02d:%02d:%02d:%02d:%02d ", i, registers_init[i],
                         registers_src_address[i], registers_value[i], register_save_lock[i],
                         registers_save_address[i]));
      end
      $display("");
      readstallnotprocessed <= 1;
      write_enabled <= 0;
      saveram_q_num <= RANDOM_SELECTED_EMPTY_VALUE_HIGHER_THAN_32;
      register_save_lock[saveram_q_num] <= 0;
      registers_save_ready[saveram_q_num] <= 0;
      for (pp = 0; pp < REGISTER_NUM; pp = pp + 1) begin
        if (readstallavail) begin
          if (!registers_init[pp]) begin
            if (registers_src_address[pp] == readsaveaddr) begin
              $display($sformatf("%02d", $time), " read register from read stall ", pp,
                       " with value ", registers_save_value[readstallindex]);  //DEBUG info
              registers_init[pp] <= 1;
              registers_src_address[pp] <= 0;
              readstallnotprocessed <= 0;
            end
          end
        end
        if (registers_save_ready[pp]) begin
          saveram_q_num <= pp;
          write_enabled <= 1;
          write_address <= registers_save_address2[pp];
          write_value   <= registers_save_value[pp];
        end
      end

      if (register[0] != RANDOM_SELECTED_EMPTY_VALUE_HIGHER_THAN_32)
        $display(
            $sformatf(
                "%02d", $time
            ),
            " read first slot register ",
            register[0],
            " with address ",  //DEBUG info
            read_address,
            "=",
            read_value
        );  //DEBUG info
      // registers_value[register[0]] <= read_value;
      registers_init[register[0]] <= 1;
      register[0] <= RANDOM_SELECTED_EMPTY_VALUE_HIGHER_THAN_32;

      if (register[1] != RANDOM_SELECTED_EMPTY_VALUE_HIGHER_THAN_32)
        $display(
            $sformatf(
                "%02d", $time
            ),
            " read second slot register ",
            register[1],
            " with address ",  //DEBUG info
            read_address2,
            "=",
            read_value2
        );  //DEBUG info
      // registers_value[register[1]] <= read_value2;
      registers_init[register[1]] <= 1;
      register[1] <= RANDOM_SELECTED_EMPTY_VALUE_HIGHER_THAN_32;

      decoder_inp <= 1;
      decoder_slot <= !decoder_slot;
      read_address <= pc_physical + 2;
      read_address2 <= pc_physical + 3;
      $display($sformatf("%02d", $time), pc_logical, " starting fetch ", pc_physical + 2);
      decoder_input_address <= pc_logical + 2;
      if (decoder_inp) begin
        pc_logical  <= pc_logical + 2;
        pc_physical <= pc_physical + 2;
      end

      $display(
          $sformatf("%02d", $time), pc_logical, " executor1   ",
          (executor_state == EXECUTE_STATE_START ? 1 : 0), "  decoder_slot = ", (decoder_slot),
          " exec_state=", executor_state, " b1 %c%c%c%ch ",  //DEBUG info
          decoder_instruction_state[0] / 16 >= 10 ? decoder_instruction_state[0] / 16 + 65 - 10 : decoder_instruction_state[0] / 16 + 48,
          decoder_instruction_state[0] % 16 >= 10 ? decoder_instruction_state[0] % 16 + 65 - 10 : decoder_instruction_state[0] % 16 + 48,
          decoder_register_start[0] / 16 >= 10 ? decoder_register_start[0] / 16 + 65 - 10 : decoder_register_start[0] / 16 + 48,
          decoder_register_start[0] % 16 >= 10 ? decoder_register_start[0] % 16 + 65 - 10 : decoder_register_start[0] % 16 + 48,
          " b2 ",  //DEBUG info
          decoder_register_len[0], "-", decoder_start_ram_address_or_numeric[0],
          " dec_error_code=",  //DEBUG info
          decoder_error_code[0]);  //DEBUG info
      $display(
          $sformatf("%02d", $time), pc_logical, " executor2   ",
          (executor_state == EXECUTE_STATE_START ? 0 : 1), " exec_state=", executor_state, " ",
          (decoder_slot), " b1 %c%c%c%ch ",  //DEBUG info
          decoder_instruction_state[1] / 16 >= 10 ? decoder_instruction_state[1] / 16 + 65 - 10 : decoder_instruction_state[1] / 16 + 48,
          decoder_instruction_state[1] % 16 >= 10 ? decoder_instruction_state[1] % 16 + 65 - 10 : decoder_instruction_state[1] % 16 + 48,
          decoder_register_start[1] / 16 >= 10 ? decoder_register_start[1] / 16 + 65 - 10 : decoder_register_start[1] / 16 + 48,
          decoder_register_start[1] % 16 >= 10 ? decoder_register_start[1] % 16 + 65 - 10 : decoder_register_start[1] % 16 + 48,
          " b2 ",  //DEBUG info
          decoder_register_len[1], "-", decoder_start_ram_address_or_numeric[1]);
          
      instr_num <= executor_state == EXECUTE_STATE_START ? instr_num + 1 : instr_num;
      executor_state <= readstallavail ? EXECUTE_STATE_CONTINUE : EXECUTE_STATE_START;
      for (i = 0; i < REGISTER_NUM; i = i + 1) begin
        case (executor_state)
          EXECUTE_STATE_MMU: begin
            //mmu
            $display($sformatf("%02d", $time), pc_logical, " mmu processing ");  //DEBUG info

            $display($sformatf("%02d", $time), pc_logical, " ", i, " ", registers_init[i], " ",
                     registers_src_mmu_done[i], " ", registers_src_address[i], " ",
                     mmu_address_logical_min_in_the_same_page, " ",
                     mmu_address_logical_max_in_the_same_page);
            if (!registers_src_mmu_done[i]) begin
              if (registers_src_address[i] >= mmu_address_logical_min_in_the_same_page) begin
                if (registers_src_address[i] <= mmu_address_logical_max_in_the_same_page) begin
                  $display(  //DEBUG info
                      $sformatf("%02d", $time), pc_logical, " updating reg ", i,
                      " src address from ",  //DEBUG info
                      registers_src_address[i], " to ",
                      mmu_address_physical_min_in_the_same_page + registers_src_address[i] - mmu_address_logical_min_in_the_same_page);  //DEBUG info
                  registers_src_address2[i]<= mmu_address_physical_min_in_the_same_page+registers_src_address[i]-mmu_address_logical_min_in_the_same_page;
                  registers_src_mmu_done[i] <= 1;
                end
              end
            end
            if (register_save_lock[i]) begin
              if (registers_save_address[i] >= mmu_address_logical_min_in_the_same_page) begin
                if (registers_save_address[i] <= mmu_address_logical_max_in_the_same_page) begin
                  $display(  //DEBUG info
                      $sformatf("%02d", $time), pc_logical, " updating save ram ", i,
                      " src address from ", registers_save_address[i], " to ",
                      mmu_address_physical_min_in_the_same_page + registers_save_address[i] - mmu_address_logical_min_in_the_same_page);
                  registers_save_address2[i]<= mmu_address_physical_min_in_the_same_page+registers_save_address[i]-mmu_address_logical_min_in_the_same_page;
                  registers_save_mmu_done[i] <= 1;
                  registers_save_ready[i] <= 1;

                  saveram_q_num <= i;
                  write_enabled <= 1;
                  write_address <= mmu_address_physical_min_in_the_same_page+registers_save_address[i]-mmu_address_logical_min_in_the_same_page;
                  write_value <= registers_save_value[i];
                end
              end
            end
            executor_state <= EXECUTE_STATE_CONTINUE;
          end
          default: begin
            if (decoder_ready) begin
              if ((executor_state == EXECUTE_STATE_START ?decoder_do_op0[i][!decoder_slot]:decoder_do_op2[i])) begin
                //  decoder_do_op2[i] <= 1;
                case (decoder_instruction_state[!decoder_slot])
                  OPCODE_TILL_VALUE, OPCODE_TILL_NON_VALUE: begin
                    if ((decoder_instruction_state[!decoder_slot] == OPCODE_TILL_VALUE && registers_value[i] != decoder_start_ram_address_or_numeric[!decoder_slot]) ||
                          (decoder_instruction_state[!decoder_slot] == OPCODE_TILL_NON_VALUE && registers_value[i] == decoder_start_ram_address_or_numeric[!decoder_slot])) begin
                      pc_physical <= pc_physical - decoder_register_len[!decoder_slot] - 2;
                      read_address <= pc_physical - decoder_register_len[!decoder_slot];
                      read_address2 <= pc_physical - decoder_register_len[!decoder_slot] + 1;
                      decoder_input_address <= pc_physical - decoder_register_len[!decoder_slot] - 2;
                    end
                  end
                  OPCODE_RAM2REG: begin
                    $display($sformatf("%02d", $time), pc_logical, " ram2reg saving ", i);
                    //this register should be read next time
                    registers_init[i] <= 0;
                    registers_src_mmu_done[i] <= 0;
                    registers_src_address[i] <= decoder_start_ram_address_or_numeric[!decoder_slot]+i-decoder_register_start[!decoder_slot];
                  end
                  OPCODE_NUM2REG: begin
                    //not important if register had value earlier
                    registers_init[i] <= 1;
                    registers_src_mmu_done[i] <= 1;
                    // registers_value[i] <= decoder_start_ram_address_or_numeric[!decoder_slot];
                    $display($sformatf("%02d", $time), pc_logical, " set reg ", i, " with value ",
                             decoder_start_ram_address_or_numeric);
                  end
                  default: begin
                    if (!registers_init[i]) begin
                      decoder_inp <= 0;
                      decoder_slot <= decoder_slot;
                      executor_state <= EXECUTE_STATE_MMU;
                      mmu_address_logical <= registers_src_address[i];
                      if (readstallavail) begin
                        executor_state <= EXECUTE_STATE_CONTINUE;
                      end else if (registers_src_mmu_done[i]) begin
                        executor_state <= EXECUTE_STATE_CONTINUE;
                        $display($sformatf("%02d", $time), pc_logical, " need to fetch register ",
                                 i, " src address ", registers_src_address2[i]);
                        if (i % 2 == 0) begin
                          read_address <= registers_src_address2[i];
                          register[0]  <= i;
                        end else begin
                          read_address2 <= registers_src_address2[i];
                          register[1]   <= i;
                        end
                      end else begin
                        $display($sformatf("%02d", $time), pc_logical, " starting mmu from read");
                      end
                    end else begin
                      case (decoder_instruction_state[!decoder_slot])
                        OPCODE_REG2RAM: begin
                          if (!register_save_lock[i] || saveram_q_num == i) begin
                            registers_save_value[i] <= registers_value[i];
                            registers_save_address[i] <= decoder_start_ram_address_or_numeric[!decoder_slot]+i-decoder_register_start[!decoder_slot];
                            //  decoder_do_op2[i] <= 0;
                            register_save_lock[i] <= 1;
                          end else begin
                            executor_state <= registers_save_mmu_done[i]?EXECUTE_STATE_CONTINUE:EXECUTE_STATE_MMU;
                            mmu_address_logical <= registers_save_address[i];
                            decoder_inp <= 0;
                            decoder_slot <= decoder_slot;
                            $display($sformatf("%02d", $time), pc_logical, " write memory slot ",
                                     i, " is already filled, stall1 ", saveram_q_num, " ",
                                     register_save_lock[i]);
                            if (!registers_save_mmu_done[i])
                              $display(
                                  $sformatf("%02d", $time), pc_logical, " starting mmu from save"
                              );
                          end
                        end
                      endcase
                    end
                  end
                endcase
              end else begin
                //     decoder_do_op2[i] <= 0;
              end
            end
          end
        endcase
      end
      $display("");
    end else begin
      decoder_inp <= 0;
    end
  end
endmodule

module decoder (
    input clk,
    input reg [15:0] address,
    instruction1,
    instruction2,
    input bit inp,
    input bit slot,

    output bit do_op[REGISTER_NUM-1:0][0:1],
    output bit ready,
    output bit [5:0] state[0:1],
    output bit [3:0] error_code[0:1],
    output bit [15:0] start_ram_address_or_numeric[0:1],
    output bit [6:0] register_len[0:1],
    output bit [6:0] register_start[0:1]
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
      $write(  //DEBUG info
          $sformatf("%02d", $time),  //DEBUG info
          address, " decoder slot ", slot, " b1 %c",  //DEBUG info
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

      error_code[slot] <= 0;
      start_ram_address_or_numeric[slot] <= instruction2;
      register_start[slot] <= instruction1_2_1;
      register_len[slot] <= instruction1_2_2;
      state[slot] <= instruction1_1;

      for (i = 0; i < REGISTER_NUM; i = i + 1) begin
        //(instruction1_1==OPCODE_TILL_VALUE || instruction1_1==OPCODE_TILL_NON_VALUE? i == instruction1_2_1:
        do_op[i][slot] <= (i >= instruction1_2_1 && i <= instruction1_2_1 + instruction1_2_2) ? 1 : 0;
      end

      case (instruction1_1)
        //register num (5 bits), how many-1 instcutions back (3 bits), 16 bit reg value // do..while
        OPCODE_TILL_VALUE: begin
          $write(  //DEBUG info
              " opcode = till_value reg ", instruction1_2_1, "=", instruction2, " jmp ",
              instruction1_2_2  //DEBUG info
          );  //DEBUG info
        end
        OPCODE_TILL_NON_VALUE: begin
          $write(  //DEBUG info
              " opcode = till_non_value reg ", instruction1_2_1, "=", instruction2, " jmp ",
              instruction1_2_2  //DEBUG info
          );  //DEBUG info
        end
        //register num (5 bits), how many-1 (3 bits), 16 bit addr
        OPCODE_RAM2REG, OPCODE_REG2RAM: begin
          if (instruction1_2_1 + instruction1_2_2 >= 32) begin
            error_code[slot] <= ERROR_WRONG_REG_NUM;
          end else if (instruction2 < ADDRESS_PROGRAM) begin
            error_code[slot] <= ERROR_WRONG_ADDRESS;
          end else if (instruction1_1 == OPCODE_RAM2REG) begin
            $write(  //DEBUG info
                " opcode = ram2reg read value from logical address ",  //DEBUG info
                instruction2,  //DEBUG info
                "+ to reg ",  //DEBUG info
                instruction1_2_1,  //DEBUG info
                "-",  //DEBUG info
                (instruction1_2_1 + instruction1_2_2)  //DEBUG info
            );  //DEBUG info
          end else begin
            $write(  //DEBUG info
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
            error_code[slot] <= ERROR_WRONG_REG_NUM;
          end else begin
            $write(  //DEBUG info
                " opcode = ");  //DEBUG info
            case (instruction1_1)  //DEBUG info
              OPCODE_NUM2REG:  $write("num2reg save");  //DEBUG info
              OPCODE_REG_PLUS: $write("regplus add");  //DEBUG info
              OPCODE_REG_MUL:  $write("regmul mul");  //DEBUG info
              OPCODE_REG_DIV:  $write("regdiv div");  //DEBUG info
            endcase  //DEBUG info
            $write(" value ",  //DEBUG info
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
          state[slot]                        <= ERROR_WRONG_OPCODE;
          start_ram_address_or_numeric[slot] <= 0;
          register_start[slot]               <= 0;
          register_len[slot]                 <= 0;
        end
      endcase
      $display("");
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
    // if (RAM_READ_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
    //  $display(
    //  $sformatf("%02d", $time), " ram read ", read_address, " = ", ram[read_address]
    //);  //DEBUG info

    //$display(
    //         $sformatf("%02d", $time), " ram read2 ", read_address2, " = ", ram[read_address2]
    //     );  //DEBUG info

    if (write_enabled) ram[write_address] <= write_value;
  end
endmodule

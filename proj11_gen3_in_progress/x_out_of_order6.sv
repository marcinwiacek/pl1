`timescale 1ns / 1ps

parameter HARDWARE_DEBUG = 1;
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

parameter OPCODE_JMP = 1;  //16 bit target address
parameter OPCODE_JMP_IF1 = 2; //register num (5 bits), how many-1 (3 bits), 16 bit value  //reg -= value
parameter OPCODE_JMP_IF2 = 3; //register num (5 bits), how many-1 (3 bits), 16 bit value  //reg -= value
parameter OPCODE_JMP_IF3 = 4; //register num (5 bits), how many-1 (3 bits), 16 bit value  //reg -= value
parameter OPCODE_JMP_IF4 = 5; //register num (5 bits), how many-1 (3 bits), 16 bit value  //reg -= value
parameter OPCODE_JMP_IF_NOT1 = 6; //register num (5 bits), how many-1 (3 bits), 16 bit value  //reg -= value
parameter OPCODE_JMP_IF_NOT2 = 7; //register num (5 bits), how many-1 (3 bits), 16 bit value  //reg -= value
parameter OPCODE_JMP_IF_NOT3 = 8; //register num (5 bits), how many-1 (3 bits), 16 bit value  //reg -= value
parameter OPCODE_JMP_IF_NOT4 = 9; //register num (5 bits), how many-1 (3 bits), 16 bit value  //reg -= value
parameter OPCODE_RAM2REG = 10;  //register num (4 bits), how many (4 bits), 16 bit source addr //ram -> reg
parameter OPCODE_REG2RAM = 11; //14 //register num (4 bits), how many-1 (4 bits), 16 bit target addr //reg -> ram
parameter OPCODE_NUM2REG = 12; //18;  //register num (4 bits), how many-1 (4 bits), 16 bit value //value -> reg
parameter OPCODE_REG_PLUS = 14;//20; //register num (5 bits), how many-1 (3 bits), 16 bit value // reg += value
parameter OPCODE_REG_MINUS = 15; //register num (5 bits), how many-1 (3 bits), 16 bit value  //reg -= value

//parameter OPCODE_REG_MUL = 'h16; //register num (5 bits), how many-1 (3 bits), 16 bit value // reg *= value
//parameter OPCODE_REG_DIV ='h17; //register num (5 bits), how many-1 (3 bits), 16 bit value  //reg /= value
//parameter OPCODE_EXIT = 'h18;  //exit process
//parameter OPCODE_PROC = 'h19;  //new process //how many pages, start page number (16 bit)
//parameter OPCODE_REG_INT = 'h1a;  //int number (8 bit), start memory page, end memory page 
//parameter OPCODE_INT = 'h1b;  //int number (8 bit), start memory page, end memory page
//parameter OPCODE_INT_RET = 'h1c;  //int number
//parameter OPCODE_RAM2OUT = 'h1d;  //port number, 16 bit source address
//parameter OPCODE_REG_IN2RAM = 'h1e;  //port number, 16 bit source address
//parameter OPCODE_IN2RAM_RET = 'h1f;
//parameter OPCODE_TILL_VALUE =23;   //register num (8 bit), value (8 bit), how many instructions back (8 bit value) // do..while
//parameter OPCODE_TILL_NON_VALUE=24;   //register num, value, how many instructions back (8 bit value) //do..while
//parameter OPCODE_LOOP = 25;  //x, x, how many instructions (8 bit value) //for...
//parameter OPCODE_FREE = 31;  //free ram pages x-y 
//parameter OPCODE_FREE_LEVEL =32; //free ram pages allocated after page x (or pages with concrete level)
//parameter OPCODE_REG_INT_NON_BLOCKING =33; //int number (8 bit), address to jump in case of int
//parameter OPCODE_REG2REG = 33;

parameter EXECUTE_STATE_START = 0;
parameter EXECUTE_STATE_CONTINUE = 1;
parameter EXECUTE_STATE_MMU = 2;

parameter REGISTER_NUM = 15;
parameter RANDOM_SELECTED_EMPTY_VALUE_HIGHER_THAN_32 = REGISTER_NUM + 1;

module x_out_of_order6 (
    input clk,

    output reg x
);

  //------------------------------------------------------------ram---------------------------

  reg [6:0] saveram_q_num;

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
      .read_value(read_value),
      .read_value2(read_value2)
  );

  //--------------------------------------------------------- mmu ----------------------------

  reg [15:0] mmu_address_logical;
  reg [15:0]
      mmu_address_physical_min_in_the_same_page,
      mmu_address_logical_min_in_the_same_page,
      mmu_address_logical_max_in_the_same_page;

  //---------------------------------------------------------decoder--------------------------

  reg decoder_slot;
  reg [15:0] decoder_input_address;
  reg decoder_inp;
  wire decoder_ready;
  wire [3:0] decoder_error_code[0:1];
  wire [7:0] decoder_in1[0:1];
  wire [3:0] decoder_in2[0:1], decoder_in3[0:1];
  wire [15:0] decoder_in3_big[0:1];
  wire [15:0] decoder_in4[0:1];
  wire decoder_do_op0[REGISTER_NUM:0][0:1];
  wire [15:0] decoder_numeric[REGISTER_NUM:0][0:1];

  decoder decoder (
      .clk(clk),
      .inp(decoder_inp),
      .address(decoder_input_address),
      .read1(read_value),
      .read2(read_value2),
      .slot(decoder_slot),
      .do_op(decoder_do_op0),
      .ready(decoder_ready),
      .error_code(decoder_error_code),
      .in1(decoder_in1),
      .in2(decoder_in2),
      .in3(decoder_in3),
      .in3_big(decoder_in3_big),
      .in4(decoder_in4),
      .numeric(decoder_numeric)
  );

  //--------------------------------------------------------------------executor------------------

  reg [5:0] executor_state;
  reg [6:0] register[0:1];
  reg decoder_do_op2[REGISTER_NUM:0];

  //--------------------------------------------------------------------process------------------

  //  reg [15:0] process_hardware_address = 0;

  reg [15:0]
      pc_logical,
      pc_physical,
      registers_value[0:REGISTER_NUM],
      registers_src_address[0:REGISTER_NUM],
      registers_src_address2[0:REGISTER_NUM],
      registers_save_value[0:REGISTER_NUM],
      registers_save_address[0:REGISTER_NUM],
      registers_save_address2[0:REGISTER_NUM];
  reg
      registers_init[0:REGISTER_NUM] = {
        // verilog_format:off
        1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0
        // verilog_format:on
      },  //Read from RAM?
      registers_src_mmu_done[0:REGISTER_NUM],
      register_save_lock[0:REGISTER_NUM],
      registers_save_ready[0:REGISTER_NUM],
      registers_save_mmu_done[0:REGISTER_NUM];

  //----------------------------------------------------------------other---------------------------

  reg rst = 1;
  reg [4:0] instr_num;  // how many done

  assign x = decoder_inp;  //without this we will have empty circuit

  integer i, zz, pp, qq, qqq;

  reg [ 6:0] readstallindex;
  reg [15:0] readsaveaddr;
  reg readstallnotprocessed, readstallavail;

  always @(posedge clk) begin
    readstallavail <= 0;
    for (zz = 0; zz <= REGISTER_NUM; zz = zz + 1) begin
      if (decoder_in1[!decoder_slot] == OPCODE_RAM2REG) begin
        if (registers_save_address[zz] >= decoder_in4[!decoder_slot]) begin
          if (registers_save_address[zz] <= decoder_in3[!decoder_slot]+decoder_in4[!decoder_slot]) begin
            readstallavail <= 1;
            readstallindex <= zz;
            readsaveaddr   <= registers_save_address[zz];
            if (HARDWARE_DEBUG)
              $display(
                  $sformatf(
                      "%02d", $time
                  ),
                  pc_logical,
                  " read stall (next cycle) ",
                  zz,
                  " - register, value ",
                  registers_save_address[zz],
                  " between ",
                  decoder_in4[!decoder_slot],
                  " and ",
                  decoder_in3[!decoder_slot] + decoder_in4[!decoder_slot]
              );
          end
        end
      end
    end
  end

  always @(posedge clk) begin
    if (rst) begin
      registers_value <= '{default: 0};
      registers_value[9] <= 1;
      //decoder_do_op2 <='{default: 1};   
    end else begin
      for (qq = 0; qq <= REGISTER_NUM; qq = qq + 1) begin
        if (!decoder_ready) begin
          decoder_do_op2[qq] <= 1;
        end else if (decoder_in1[!decoder_slot] == OPCODE_NUM2REG) begin
          //not important if register had value earlier
          registers_value[qq] <= decoder_in4[!decoder_slot];
        end else if (decoder_do_op0[qq][!decoder_slot]) begin
          if (decoder_do_op2[qq]) begin
            if (registers_init[qq]) begin
              case (decoder_in1[!decoder_slot])
                OPCODE_NUM2REG: begin
                  //not important if register had value earlier
                  registers_value[qq] <= decoder_in4[!decoder_slot];
                end
                OPCODE_REG_PLUS: begin
                  decoder_do_op2[qq]  <= 0;
                  registers_value[qq] <= registers_value[qq] + decoder_in4[!decoder_slot];
                end
                OPCODE_REG_MINUS: begin
                  decoder_do_op2[qq]  <= 0;
                  registers_value[qq] <= registers_value[qq] - decoder_in4[!decoder_slot];
                end
                OPCODE_REG2RAM: begin
                  if (!register_save_lock[qq] || saveram_q_num == qq) begin
                    decoder_do_op2[qq] <= 0;
                  end
                end
              endcase
            end else if (registers_src_address[qq] == readsaveaddr) begin
              if (HARDWARE_DEBUG)
                $display(
                    $sformatf(
                        "%02d", $time
                    ),
                    " read register from read stall ",
                    qq,
                    " with value ",
                    registers_save_value[readstallindex]
                );  //DEBUG info
              registers_value[qq] <= registers_save_value[readstallindex];
            end else if (register[0] == qq) begin
              registers_value[qq] <= read_value;
            end else if (register[1] == qq) begin
              registers_value[qq] <= read_value2;
            end
          end
        end
      end
    end
  end

  always @(posedge clk) begin
    if (rst) begin
      instr_num <= 0;
      saveram_q_num <= RANDOM_SELECTED_EMPTY_VALUE_HIGHER_THAN_32;
      read_address <= 52;
      read_address2 <= 53;
      decoder_inp <= 1;
      decoder_input_address <= 52;
      if (HARDWARE_DEBUG)
        $display($sformatf("%02d", $time), "   52 starting initial fetch ");  //DEBUG info
      if (HARDWARE_DEBUG) $display("");
      pc_logical <= 52;
      pc_physical <= 52;
      mmu_address_physical_min_in_the_same_page <= 0;
      mmu_address_logical_min_in_the_same_page <= 0;
      mmu_address_logical_max_in_the_same_page <= 500;
      rst <= 0;
      for (i = 0; i <= REGISTER_NUM; i = i + 1) begin
        registers_src_mmu_done[i] <= 1;
        registers_src_address2[i] <= ADDRESS_REG + i;
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
      if (HARDWARE_DEBUG) begin
        $display("time ", $sformatf("%02d", $time), " pc ", pc_physical, ", exec_state ",
                 executor_state, " exec_slot ", !decoder_slot);
        $write("reg");
        for (i = 0; i < 20; i = i + 1) begin
          $write($sformatf(" %02d:%02d:%02d:%02d:%02d:%02d ", i, registers_init[i],
                           registers_src_address[i], registers_value[i], register_save_lock[i],
                           registers_save_address[i]));
        end
        $display("");
      end
      readstallnotprocessed <= 1;
      write_enabled <= 0;
      saveram_q_num <= RANDOM_SELECTED_EMPTY_VALUE_HIGHER_THAN_32;
      register_save_lock[saveram_q_num] <= 0;
      registers_save_ready[saveram_q_num] <= 0;
      for (pp = 0; pp <= REGISTER_NUM; pp = pp + 1) begin
        if (!registers_init[pp]) begin
          if (registers_src_address[pp] == readsaveaddr) begin
            if (HARDWARE_DEBUG)
              $display(
                  $sformatf(
                      "%02d", $time
                  ),
                  " read register from read stall ",
                  pp,
                  " with value ",
                  registers_save_value[readstallindex]
              );  //DEBUG info
            registers_init[pp] <= 1;
            registers_src_address[pp] <= 0;
            readstallnotprocessed <= 0;
          end
        end
        if (registers_save_ready[pp]) begin
          saveram_q_num <= pp;
          write_enabled <= 1;
          write_address <= registers_save_address2[pp];
          write_value   <= registers_save_value[pp];
        end
      end

      if (HARDWARE_DEBUG && register[0] != RANDOM_SELECTED_EMPTY_VALUE_HIGHER_THAN_32)
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
      registers_init[register[0]] <= 1;
      register[0] <= RANDOM_SELECTED_EMPTY_VALUE_HIGHER_THAN_32;

      if (HARDWARE_DEBUG && register[1] != RANDOM_SELECTED_EMPTY_VALUE_HIGHER_THAN_32)
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
      registers_init[register[1]] <= 1;
      register[1] <= RANDOM_SELECTED_EMPTY_VALUE_HIGHER_THAN_32;

      decoder_inp <= 1;
      decoder_slot <= !decoder_slot;
      read_address <= pc_physical + 2;
      read_address2 <= pc_physical + 3;
      if (HARDWARE_DEBUG)
        $display($sformatf("%02d", $time), pc_logical, " starting fetch ", pc_physical + 2);
      decoder_input_address <= pc_logical + 2;
      if (decoder_inp) begin
        pc_logical  <= pc_logical + 2;
        pc_physical <= pc_physical + 2;
      end

      if (HARDWARE_DEBUG) begin
        $display(
            $sformatf("%02d", $time), pc_logical, " executor slot 0 opcode %c%c%c%c",  //DEBUG info
            decoder_in1[0] / 16 >= 10 ? decoder_in1[0] / 16 + 65 - 10 : decoder_in1[0] / 16 + 48,  //DEBUG info
            decoder_in1[0] % 16 >= 10 ? decoder_in1[0] % 16 + 65 - 10 : decoder_in1[0] % 16 + 48,  //DEBUG info
            (decoder_in2[0] * 16 + decoder_in3[0]) / 16 >= 10 ? (decoder_in2[0] * 16 + decoder_in3[0]) / 16 + 65 - 10 : (decoder_in2[0] * 16 + decoder_in3[0]) / 16 + 48,  //DEBUG info
            (decoder_in2[0] * 16 + decoder_in3[0]) % 16 >= 10 ? (decoder_in2[0] * 16 + decoder_in3[0]) % 16 + 65 - 10 : (decoder_in2[0] * 16 + decoder_in3[0]) % 16 + 48,  //DEBUG info
            "h %c%c%c%c",  //DEBUG info
            (decoder_in4[0] / 256) / 16 >= 10 ? (decoder_in4[0] / 256) / 16 + 65 - 10 : (decoder_in4[0] / 256) / 16 + 48,  //DEBUG info
            (decoder_in4[0] / 256) % 16 >= 10 ? (decoder_in4[0] / 256) % 16 + 65 - 10 : (decoder_in4[0] / 256) % 16 + 48,  //DEBUG info
            (decoder_in4[0] % 256) / 16 >= 10 ? (decoder_in4[0] % 256) / 16 + 65 - 10 : (decoder_in4[0] % 256) / 16 + 48,  //DEBUG info
            (decoder_in4[0] % 256) % 16 >= 10 ? (decoder_in4[0] % 256) % 16 + 65 - 10 : (decoder_in4[0] % 256) % 16 + 48,  //DEBUG info
            "h");

        $display(
            $sformatf("%02d", $time), pc_logical, " executor slot 1 opcode %c%c%c%c",  //DEBUG info
            decoder_in1[1] / 16 >= 10 ? decoder_in1[1] / 16 + 65 - 10 : decoder_in1[1] / 16 + 48,  //DEBUG info
            decoder_in1[1] % 16 >= 10 ? decoder_in1[1] % 16 + 65 - 10 : decoder_in1[1] % 16 + 48,  //DEBUG info
            (decoder_in2[1] * 16 + decoder_in3[1]) / 16 >= 10 ? (decoder_in2[1] * 16 + decoder_in3[1]) / 16 + 65 - 10 : (decoder_in2[1] * 16 + decoder_in3[1]) / 16 + 48,  //DEBUG info
            (decoder_in2[1] * 16 + decoder_in3[1]) % 16 >= 10 ? (decoder_in2[1] * 16 + decoder_in3[1]) % 16 + 65 - 10 : (decoder_in2[1] * 16 + decoder_in3[1]) % 16 + 48,  //DEBUG info
            "h %c%c%c%c",  //DEBUG info
            (decoder_in4[1] / 256) / 16 >= 10 ? (decoder_in4[1] / 256) / 16 + 65 - 10 : (decoder_in4[1] / 256) / 16 + 48,  //DEBUG info
            (decoder_in4[1] / 256) % 16 >= 10 ? (decoder_in4[1] / 256) % 16 + 65 - 10 : (decoder_in4[1] / 256) % 16 + 48,  //DEBUG info
            (decoder_in4[1] % 256) / 16 >= 10 ? (decoder_in4[1] % 256) / 16 + 65 - 10 : (decoder_in4[1] % 256) / 16 + 48,  //DEBUG info
            (decoder_in4[1] % 256) % 16 >= 10 ? (decoder_in4[1] % 256) % 16 + 65 - 10 : (decoder_in4[1] % 256) % 16 + 48,  //DEBUG info
            "h");

        $write("numeric");
        for (i = 0; i < 20; i = i + 1) begin
          $write($sformatf(" %02d:%02d ", i, decoder_numeric[i][0]));
        end
        $display("");
        $write("numeric");
        for (i = 0; i < 20; i = i + 1) begin
          $write($sformatf(" %02d:%02d ", i, decoder_numeric[i][1]));
        end
        $display("");
      end

      instr_num <= executor_state == EXECUTE_STATE_START ? instr_num + 1 : instr_num;
      executor_state <= readstallavail ? EXECUTE_STATE_CONTINUE : EXECUTE_STATE_START;
      for (i = 0; i <= REGISTER_NUM; i = i + 1) begin
        case (executor_state)
          EXECUTE_STATE_MMU: begin
            if (!registers_src_mmu_done[i]) begin
              if (registers_src_address[i] >= mmu_address_logical_min_in_the_same_page) begin
                if (registers_src_address[i] <= mmu_address_logical_max_in_the_same_page) begin
                  if (HARDWARE_DEBUG)
                    $display(  //DEBUG info
                        $sformatf(
                            "%02d", $time
                        ),
                        pc_logical,
                        " updating reg ",
                        i,
                        " src address from ",  //DEBUG info
                        registers_src_address[i],
                        " to ",
                        mmu_address_physical_min_in_the_same_page + registers_src_address[i] - mmu_address_logical_min_in_the_same_page
                    );  //DEBUG info
                  registers_src_address2[i]<= mmu_address_physical_min_in_the_same_page+registers_src_address[i]-mmu_address_logical_min_in_the_same_page;
                  registers_src_mmu_done[i] <= 1;
                end
              end
            end
            if (register_save_lock[i]) begin
              if (registers_save_address[i] >= mmu_address_logical_min_in_the_same_page) begin
                if (registers_save_address[i] <= mmu_address_logical_max_in_the_same_page) begin
                  if (HARDWARE_DEBUG)
                    $display(  //DEBUG info
                        $sformatf(
                            "%02d", $time
                        ),
                        pc_logical,
                        " updating save ram ",
                        i,
                        " src address from ",
                        registers_save_address[i],
                        " to ",
                        mmu_address_physical_min_in_the_same_page + registers_save_address[i] - mmu_address_logical_min_in_the_same_page
                    );
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
              if (decoder_do_op0[i][!decoder_slot]) begin
                if (decoder_do_op2[i]) begin
                  case (decoder_in1[!decoder_slot])
                    OPCODE_JMP: begin
                      pc_physical <= decoder_in4[!decoder_slot] - 2;
                      read_address <= decoder_in4[!decoder_slot];
                      read_address2 <= decoder_in4[!decoder_slot] + 1;
                      decoder_input_address <= decoder_in4[!decoder_slot] - 2;
                    end
                    OPCODE_RAM2REG: begin
                      //this register should be read next time
                      registers_init[i] <= 0;
                      registers_src_mmu_done[i] <= 0;
                      registers_src_address[i] <= decoder_numeric[i][!decoder_slot];
                    end
                    OPCODE_NUM2REG: begin
                      registers_init[i] <= 1;
                      registers_src_mmu_done[i] <= 1;
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
                          if (HARDWARE_DEBUG)
                            $display(
                                $sformatf(
                                    "%02d", $time
                                ),
                                pc_logical,
                                " need to fetch register ",
                                i,
                                " src address ",
                                registers_src_address2[i]
                            );
                          if (i % 2 == 0) begin
                            read_address <= registers_src_address2[i];
                            register[0]  <= i;
                          end else begin
                            read_address2 <= registers_src_address2[i];
                            register[1]   <= i;
                          end
                        end else begin
                          if (HARDWARE_DEBUG)
                            $display(
                                $sformatf("%02d", $time), pc_logical, " starting mmu from read"
                            );
                        end
                      end else begin
                        case (decoder_in1[!decoder_slot])
                          OPCODE_JMP_IF1, OPCODE_JMP_IF2, OPCODE_JMP_IF3, OPCODE_JMP_IF4:
                          if (registers_value[i] == decoder_in3_big[!decoder_slot]) begin
                            pc_physical <= decoder_in4[!decoder_slot] - 2;
                            read_address <= decoder_in4[!decoder_slot];
                            read_address2 <= decoder_in4[!decoder_slot] + 1;
                            decoder_input_address <= decoder_in4[!decoder_slot] - 2;
                          end
                          OPCODE_JMP_IF_NOT1:
                          if (registers_value[i] != decoder_in3[!decoder_slot]) begin
                            pc_physical <= decoder_in4[!decoder_slot] - 2;
                            read_address <= decoder_in4[!decoder_slot];
                            read_address2 <= decoder_in4[!decoder_slot] + 1;
                            decoder_input_address <= decoder_in4[!decoder_slot] - 2;
                          end
                          OPCODE_REG2RAM: begin
                            if (!register_save_lock[i] || saveram_q_num == i) begin
                              registers_save_value[i] <= registers_value[i];
                              registers_save_address[i] <= decoder_numeric[i][!decoder_slot];
                              register_save_lock[i] <= 1;
                            end else begin
                              executor_state <= registers_save_mmu_done[i]?EXECUTE_STATE_CONTINUE:EXECUTE_STATE_MMU;
                              mmu_address_logical <= registers_save_address[i];
                              decoder_inp <= 0;
                              decoder_slot <= decoder_slot;
                              if (HARDWARE_DEBUG) begin
                                $display($sformatf("%02d", $time), pc_logical,
                                         " write memory slot ", i, " is already filled, stall1 ",
                                         saveram_q_num, " ", register_save_lock[i]);
                                if (!registers_save_mmu_done[i])
                                  $display(
                                      $sformatf(
                                          "%02d", $time
                                      ),
                                      pc_logical,
                                      " starting mmu from save"
                                  );
                              end
                            end
                          end
                        endcase
                      end
                    end
                  endcase
                end
              end
            end
          end
        endcase
      end
      if (HARDWARE_DEBUG) $display("");
    end else begin
      decoder_inp <= 0;
    end
  end
endmodule

module decoder (
    input clk,
    input reg [15:0] address,
    read1,
    read2,
    input bit inp,
    slot,

    output bit ready,
    output bit [3:0] error_code[0:1],

    output bit do_op[REGISTER_NUM:0][0:1],
    output bit [15:0] numeric[REGISTER_NUM:0][0:1],
    output bit [7:0] in1[0:1],
    output bit [3:0] in2[0:1],
    in3[0:1],
    output bit [15:0] in4[0:1],
    in3_big[0:1]
);

  `define INSTRUCTION1 read1[15:8]
  `define INSTRUCTION2 read1[7:4]
  `define INSTRUCTION3 read1[3:0]
  `define INSTRUCTION4 read2

  integer i;

  always @(posedge clk) begin
    if (inp) begin
      ready <= inp;
      if (HARDWARE_DEBUG) begin
        $write(  //DEBUG info
            $sformatf("%02d", $time),  //DEBUG info
            address, " decoder slot ", slot, " opcode %c%c%c%c",  //DEBUG info
            (read1 / 256) / 16 >= 10 ? (read1 / 256) / 16 + 65 - 10 : (read1 / 256) / 16 + 48,  //DEBUG info
            (read1 / 256) % 16 >= 10 ? (read1 / 256) % 16 + 65 - 10 : (read1 / 256) % 16 + 48,  //DEBUG info
            (read1 % 256) / 16 >= 10 ? (read1 % 256) / 16 + 65 - 10 : (read1 % 256) / 16 + 48,  //DEBUG info
            (read1 % 256) % 16 >= 10 ? (read1 % 256) % 16 + 65 - 10 : (read1 % 256) % 16 + 48,  //DEBUG info
            "h %c%c%c%c",  //DEBUG info
            (read2 / 256) / 16 >= 10 ? (read2 / 256) / 16 + 65 - 10 : (read2 / 256) / 16 + 48,  //DEBUG info
            (read2 / 256) % 16 >= 10 ? (read2 / 256) % 16 + 65 - 10 : (read2 / 256) % 16 + 48,  //DEBUG info
            (read2 % 256) / 16 >= 10 ? (read2 % 256) / 16 + 65 - 10 : (read2 % 256) / 16 + 48,  //DEBUG info
            (read2 % 256) % 16 >= 10 ? (read2 % 256) % 16 + 65 - 10 : (read2 % 256) % 16 + 48,  //DEBUG info
            "h (", read1, " ", read2, ")");

        case (`INSTRUCTION1)
          OPCODE_JMP: $write(" jmp to logical address ", `INSTRUCTION4);  //DEBUG info          
          OPCODE_RAM2REG:
          $write(
              " ram2reg read value from logical address ",
              `INSTRUCTION4,  //DEBUG info
              " to reg ",
              `INSTRUCTION2,
              "-",
              (`INSTRUCTION2 + `INSTRUCTION3)
          );  //DEBUG info
          OPCODE_REG2RAM:
          $write(
              " reg2ram save value from reg ",  //DEBUG info
              `INSTRUCTION2,
              "-",
              (`INSTRUCTION2 + `INSTRUCTION3),  //DEBUG info
              " to logical address ",
              `INSTRUCTION4
          );  //DEBUG info
          OPCODE_NUM2REG:
          $write(
              " num2reg save value ",
              `INSTRUCTION4,  //DEBUG info
              " to reg ",
              `INSTRUCTION2,
              "-",
              (`INSTRUCTION2 + `INSTRUCTION3)
          );  //DEBUG info
          OPCODE_REG_PLUS:
          $write(
              " regplus add value ",
              `INSTRUCTION4,
              " to reg ",
              `INSTRUCTION2,
              "-",
              (`INSTRUCTION2 + `INSTRUCTION3)
          );  //DEBUG info
          OPCODE_REG_MINUS:
          $write(
              " regminus add value ",
              `INSTRUCTION4,
              " to reg ",
              `INSTRUCTION2,
              "-",
              (`INSTRUCTION2 + `INSTRUCTION3)
          );  //DEBUG info
          default: begin
            $write(" unknown");  //DEBUG info
          end
        endcase
      end

      in1[slot] <= `INSTRUCTION1;
      in2[slot] <= `INSTRUCTION2;
      in3[slot] <= `INSTRUCTION3;
      in4[slot] <= `INSTRUCTION4;

      for (i = 0; i <= REGISTER_NUM; i = i + 1) begin
        if (i >= `INSTRUCTION2 && i <= `INSTRUCTION2 + `INSTRUCTION3) begin
          numeric[i][slot] <= `INSTRUCTION4 + i - `INSTRUCTION3;
          do_op[i][slot]   <= 1;
        end else begin
          do_op[i][slot]   <= 0;
          numeric[i][slot] <= 0;
        end
      end
      if (HARDWARE_DEBUG) $display("");
    end
  end

  always @(posedge clk) begin
    if (inp) begin
      in3_big[slot] <= `INSTRUCTION1==OPCODE_JMP_IF1?`INSTRUCTION3:(`INSTRUCTION1==OPCODE_JMP_IF2?`INSTRUCTION3<<4+16:(`INSTRUCTION1==OPCODE_JMP_IF3?`INSTRUCTION3<<8+256:`INSTRUCTION3<<12+4096));

      error_code[slot] <= 0;
      case (`INSTRUCTION1)
        OPCODE_JMP, OPCODE_JMP_IF1,OPCODE_JMP_IF2,OPCODE_JMP_IF3,OPCODE_JMP_IF4,
        OPCODE_JMP_IF_NOT1,OPCODE_JMP_IF_NOT2,OPCODE_JMP_IF_NOT3,OPCODE_JMP_IF_NOT4: begin
        end
        OPCODE_RAM2REG, OPCODE_REG2RAM, OPCODE_NUM2REG, OPCODE_REG_PLUS, OPCODE_REG_MINUS: begin
          if (`INSTRUCTION2 + `INSTRUCTION3 >= REGISTER_NUM) begin
            error_code[slot] <= ERROR_WRONG_REG_NUM;
          end
        end
        default: begin
          error_code[slot] <= ERROR_WRONG_OPCODE;
        end
      endcase
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
    if (write_enabled) begin
      if (HARDWARE_DEBUG)
        $display(
            $sformatf("%02d", $time), " ram write ", write_address, " = ", write_value
        );  //DEBUG info
      ram[write_address] <= write_value;
    end
  end
endmodule

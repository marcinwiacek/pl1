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
parameter ADDRESS_REG = 10;
parameter ADDRESS_MMU_LEN = ADDRESS_REG + 32;
parameter ADDRESS_MMU_NEXT_SEGMENT = ADDRESS_REG + 32 + 7;
parameter ADDRESS_PROGRAM = ADDRESS_REG + 32 + 7 + 1;

parameter OPCODE_JMP = 1;  //16 bit target address
parameter OPCODE_JMP_IF1 = 2; //register num (5 bits), how many-1 (3 bits), 16 bit value  //reg -= value
parameter OPCODE_JMP_IF2 = 3; //register num (5 bits), how many-1 (3 bits), 16 bit value  //reg -= value
parameter OPCODE_JMP_IF3 = 4; //register num (5 bits), how many-1 (3 bits), 16 bit value  //reg -= value
parameter OPCODE_JMP_IF4 = 5; //register num (5 bits), how many-1 (3 bits), 16 bit value  //reg -= value
parameter OPCODE_RAM2REG = 'h0a;  //register num (4 bits), how many (4 bits), 16 bit source addr //ram -> reg
parameter OPCODE_REG2RAM = 'h0b; //14 //register num (4 bits), how many-1 (4 bits), 16 bit target addr //reg -> ram
parameter OPCODE_NUM2REG = 'h0c; //18;  //register num (4 bits), how many-1 (4 bits), 16 bit value //value -> reg
parameter OPCODE_REG_PLUS = 'h0e;//20; //register num (5 bits), how many-1 (3 bits), 16 bit value // reg += value
parameter OPCODE_REG_MINUS = 'h0f; //register num (5 bits), how many-1 (3 bits), 16 bit value  //reg -= value

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
parameter EXECUTE_STATE_MMU = 1;
parameter EXECUTE_STATE_HALT = 2;
parameter EXECUTE_STATE_START2 = 3;
parameter EXECUTE_STATE_START3 = 4;
parameter EXECUTE_STATE_READ_REG_RAM = 5;
parameter EXECUTE_STATE_SAVE_RAM = 6;

parameter REGISTER_NUM = 15;
parameter RANDOM_SELECTED_EMPTY_VALUE_HIGHER_THAN_32 = REGISTER_NUM + 1;

module x_out_of_order7 (
    input clk,

    output reg x
);

  reg rst = 1;
  reg [4:0] instr_num;  // how many done


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
      .read_value(read_value),
      .read_value2(read_value2)
  );

  //--------------------------------------------------------- mmu ----------------------------

  reg [15:0] mmu_read_logical, mmu_read_logical2;
  reg [15:0]
      mmu_address_physical_min_in_the_same_page,
      mmu_address_logical_min_in_the_same_page,
      mmu_address_logical_max_in_the_same_page,
      mmu_address_physical_min_in_the_same_page2,
      mmu_address_logical_min_in_the_same_page2,
      mmu_address_logical_max_in_the_same_page2;

  //--------------------------------------------------------------------executor------------------

  reg [5:0] executor_state, executor_state2;

  //--------------------------------------------------------------------process------------------

  reg [15:0] pc_logical, registers_value[0:REGISTER_NUM];
  reg registers_init[0:REGISTER_NUM];
  reg [5:0] registers_read_num[1:0];
  reg registers_read_now[1:0];
  reg registers_done_op[0:REGISTER_NUM];

  //---------------------------------------------------------decoder--------------------------

  reg decoder_inp;
  wire decoder_ready, decoder_slot0;
  wire [3:0] decoder_error_code[0:1], decoder_in2[0:1], decoder_in3[0:1];
  wire [7:0] decoder_in1[0:1];
  wire [15:0] decoder_in3_big[0:1], decoder_in4[0:1], decoder_numeric[REGISTER_NUM:0][0:1];

  wire decoder_do_op[REGISTER_NUM:0][0:1];

  reg  decoder_slot;

  assign decoder_slot = executor_state == EXECUTE_STATE_START2 ? decoder_slot0 : !decoder_slot0;

  decoder decoder (
      .rst(rst),
      .clk(clk),
      .inp(decoder_inp),
      .address(pc_logical),
      .read1(read_value),
      .read2(read_value2),
      .slot(decoder_slot0),
      .do_op(decoder_do_op),
      .ready(decoder_ready),
      .error_code(decoder_error_code),
      .in1(decoder_in1),
      .in2(decoder_in2),
      .in3(decoder_in3),
      .in3_big(decoder_in3_big),
      .in4(decoder_in4),
      .numeric(decoder_numeric)
  );

  //----------------------------------------------------------------other---------------------------

  assign x = decoder_inp;  //without this we will have empty circuit

  integer i, j;

  reg mmu_miss1;
  assign mmu_miss1 = mmu_read_logical<mmu_address_logical_min_in_the_same_page || mmu_read_logical>mmu_address_logical_max_in_the_same_page;
  reg mmu_miss2;
  assign mmu_miss2 = mmu_read_logical2<mmu_address_logical_min_in_the_same_page2 || mmu_read_logical2>mmu_address_logical_max_in_the_same_page2;

  always @(posedge clk) begin
    if (rst) begin
      instr_num <= 0;
      pc_logical <= ADDRESS_PROGRAM;
      read_address <= ADDRESS_PROGRAM;
      read_address2 <= ADDRESS_PROGRAM + 1;
      executor_state <= EXECUTE_STATE_START;
      mmu_address_physical_min_in_the_same_page <= 0;
      mmu_address_logical_min_in_the_same_page <= 0;
      mmu_address_logical_max_in_the_same_page <= 1024 - 1;  //2^10-1
      mmu_address_physical_min_in_the_same_page2 <= 0;
      mmu_address_logical_min_in_the_same_page2 <= 0;
      mmu_address_logical_max_in_the_same_page2 <= 1024 - 1;  //2^10-1
      rst <= 0;
      decoder_inp <= 1;
      registers_init <= '{default: 0};
      registers_read_now <= '{default: 0};
      write_enabled <= 0;
      $display("rst main");
    end else if (executor_state == EXECUTE_STATE_MMU) begin
      mmu_address_physical_min_in_the_same_page <= read_value * 1024;
      mmu_address_logical_min_in_the_same_page <= mmu_read_logical[9:0];
      mmu_address_logical_max_in_the_same_page <= mmu_read_logical[9:0] + 1024 - 1;
      read_address <= read_value * 1024 + mmu_read_logical[9:0];

      mmu_address_physical_min_in_the_same_page2 <= read_value2 * 1024;
      mmu_address_logical_min_in_the_same_page2 <= mmu_read_logical2[9:0];
      mmu_address_logical_max_in_the_same_page2 <= mmu_read_logical2[9:0] + 1024 - 1;
      read_address2 <= read_value2 * 1024 + mmu_read_logical2[9:0];

      executor_state <= executor_state2;
    end else if (mmu_miss1 || mmu_miss2) begin
      executor_state2 <= executor_state;
      executor_state <= EXECUTE_STATE_MMU;
      read_address <= ADDRESS_MMU_LEN + 1 + mmu_read_logical[9:0];
      read_address2 <= ADDRESS_MMU_LEN + 1 + mmu_read_logical2[9:0];
    end else begin
      case (executor_state)
        EXECUTE_STATE_START: begin
          pc_logical <= pc_logical + 2;
          read_address <= pc_logical + 2;
          read_address2 <= pc_logical + 3;
          instr_num <= instr_num + 1;
          executor_state <= EXECUTE_STATE_START2;
        end
        EXECUTE_STATE_START2, EXECUTE_STATE_START3: begin
          $display($sformatf("%02d", $time), " pc ", pc_logical, ", exec_state ", executor_state,
                   " exec_slot ", !decoder_slot);

          $write($sformatf("%02d", $time), " executor slot 0 ");
          if (!decoder_slot == 0) begin
            $write("active");
          end else begin
            $write("      ");
          end
          $write(
              " opcode %c%c%c%c",  //DEBUG info
              decoder_in1[0] / 16 >= 10 ? decoder_in1[0] / 16 + 65 - 10 : decoder_in1[0] / 16 + 48,  //DEBUG info
              decoder_in1[0] % 16 >= 10 ? decoder_in1[0] % 16 + 65 - 10 : decoder_in1[0] % 16 + 48,  //DEBUG info
              (decoder_in2[0] * 16 + decoder_in3[0]) / 16 >= 10 ? (decoder_in2[0] * 16 + decoder_in3[0]) / 16 + 65 - 10 : (decoder_in2[0] * 16 + decoder_in3[0]) / 16 + 48,  //DEBUG info
              (decoder_in2[0] * 16 + decoder_in3[0]) % 16 >= 10 ? (decoder_in2[0] * 16 + decoder_in3[0]) % 16 + 65 - 10 : (decoder_in2[0] * 16 + decoder_in3[0]) % 16 + 48,  //DEBUG info
              "h %c%c%c%c",  //DEBUG info
              (decoder_in4[0] / 256) / 16 >= 10 ? (decoder_in4[0] / 256) / 16 + 65 - 10 : (decoder_in4[0] / 256) / 16 + 48,  //DEBUG info
              (decoder_in4[0] / 256) % 16 >= 10 ? (decoder_in4[0] / 256) % 16 + 65 - 10 : (decoder_in4[0] / 256) % 16 + 48,  //DEBUG info
              (decoder_in4[0] % 256) / 16 >= 10 ? (decoder_in4[0] % 256) / 16 + 65 - 10 : (decoder_in4[0] % 256) / 16 + 48,  //DEBUG info
              (decoder_in4[0] % 256) % 16 >= 10 ? (decoder_in4[0] % 256) % 16 + 65 - 10 : (decoder_in4[0] % 256) % 16 + 48,  //DEBUG info
              "h ");
          for (i = 0; i <= REGISTER_NUM; i = i + 1) begin
            $write(i, ":", decoder_do_op[i][0], " ");
          end
          $display("");

          $write($sformatf("%02d", $time), " executor slot 1 ");
          if (!decoder_slot == 1) begin
            $write("active");
          end else begin
            $write("      ");
          end
          $write(
              " opcode %c%c%c%c",  //DEBUG info
              decoder_in1[1] / 16 >= 10 ? decoder_in1[1] / 16 + 65 - 10 : decoder_in1[1] / 16 + 48,  //DEBUG info
              decoder_in1[1] % 16 >= 10 ? decoder_in1[1] % 16 + 65 - 10 : decoder_in1[1] % 16 + 48,  //DEBUG info
              (decoder_in2[1] * 16 + decoder_in3[1]) / 16 >= 10 ? (decoder_in2[1] * 16 + decoder_in3[1]) / 16 + 65 - 10 : (decoder_in2[1] * 16 + decoder_in3[1]) / 16 + 48,  //DEBUG info
              (decoder_in2[1] * 16 + decoder_in3[1]) % 16 >= 10 ? (decoder_in2[1] * 16 + decoder_in3[1]) % 16 + 65 - 10 : (decoder_in2[1] * 16 + decoder_in3[1]) % 16 + 48,  //DEBUG info
              "h %c%c%c%c",  //DEBUG info
              (decoder_in4[1] / 256) / 16 >= 10 ? (decoder_in4[1] / 256) / 16 + 65 - 10 : (decoder_in4[1] / 256) / 16 + 48,  //DEBUG info
              (decoder_in4[1] / 256) % 16 >= 10 ? (decoder_in4[1] / 256) % 16 + 65 - 10 : (decoder_in4[1] / 256) % 16 + 48,  //DEBUG info
              (decoder_in4[1] % 256) / 16 >= 10 ? (decoder_in4[1] % 256) / 16 + 65 - 10 : (decoder_in4[1] % 256) / 16 + 48,  //DEBUG info
              (decoder_in4[1] % 256) % 16 >= 10 ? (decoder_in4[1] % 256) % 16 + 65 - 10 : (decoder_in4[1] % 256) % 16 + 48,  //DEBUG info
              "h ");
          for (i = 0; i <= REGISTER_NUM; i = i + 1) begin
            $write(i, ":", decoder_do_op[i][1], " ");
          end
          $display("");

          if (executor_state == EXECUTE_STATE_START2) begin
            instr_num <= instr_num + 1;
            pc_logical <= pc_logical + 2;
            mmu_read_logical <= pc_logical + 2;
            read_address <= mmu_address_physical_min_in_the_same_page + pc_logical[9:0] + 2;
            mmu_read_logical2 <= pc_logical + 3;
            read_address2 <= mmu_address_physical_min_in_the_same_page + pc_logical[9:0] + 3;
          end else begin
            mmu_read_logical <= pc_logical;
            read_address <= mmu_address_physical_min_in_the_same_page + pc_logical[9:0];
            mmu_read_logical2 <= pc_logical + 1;
            read_address2 <= mmu_address_physical_min_in_the_same_page + pc_logical[9:0] + 1;
          end
          executor_state <= instr_num == 10 ? EXECUTE_STATE_HALT : EXECUTE_STATE_START2;
          decoder_inp <= 1;
          registers_done_op <= '{default: 0};

          if (decoder_error_code[!decoder_slot] == 0) begin
            for (i = 0; i <= REGISTER_NUM; i = i + 1) begin
              if (decoder_do_op[i][!decoder_slot]) begin
                case (decoder_in1[!decoder_slot])
                  OPCODE_JMP: begin
                    pc_logical <= decoder_in4[!decoder_slot];
                    mmu_read_logical <= decoder_in4[!decoder_slot];
                    read_address <= mmu_address_physical_min_in_the_same_page+decoder_in4[!decoder_slot][9:0];
                    mmu_read_logical2 <= decoder_in4[!decoder_slot] + 1;
                    read_address2 <= mmu_address_physical_min_in_the_same_page+decoder_in4[!decoder_slot][9:0]+1;
                  end
                  OPCODE_NUM2REG: begin
                    registers_init[i]  <= 1;
                    registers_value[i] <= decoder_in4[!decoder_slot];
                  end
                  default: begin
                    if (!registers_init[i]) begin
                      if (i % 2 == 0) begin
                        read_address <= ADDRESS_REG + i;
                        registers_read_num[0] <= i;
                        registers_read_now[0] <= 1;
                      end else begin
                        read_address2 <= ADDRESS_REG + i;
                        registers_read_num[1] <= i;
                        registers_read_now[1] <= 1;
                      end
                      executor_state <= EXECUTE_STATE_READ_REG_RAM;
                      decoder_inp <= 0;
                      registers_done_op <= registers_done_op;
                    end else if (!registers_done_op[i]) begin
                      case (decoder_in1[!decoder_slot])
                        OPCODE_JMP_IF1, OPCODE_JMP_IF2, OPCODE_JMP_IF3, OPCODE_JMP_IF4: begin
                          if (registers_value[i] == decoder_in3_big[!decoder_slot]) begin
                            pc_logical <= decoder_in4[!decoder_slot];
                            mmu_read_logical <= decoder_in4[!decoder_slot];
                            read_address <= mmu_address_physical_min_in_the_same_page+decoder_in4[!decoder_slot][9:0];
                            mmu_read_logical2 <= decoder_in4[!decoder_slot] + 1;
                            read_address2 <= mmu_address_physical_min_in_the_same_page+decoder_in4[!decoder_slot][9:0]+1;
                          end
                        end
                        OPCODE_RAM2REG: begin
                          if (i % 2 == 0) begin
                            read_address <= decoder_numeric[i][!decoder_slot];
                            registers_read_num[0] <= i;
                            registers_read_now[0] <= 1;
                          end else begin
                            read_address2 <= decoder_numeric[i][!decoder_slot];
                            registers_read_num[1] <= i;
                            registers_read_now[1] <= 1;
                          end
                          executor_state <= EXECUTE_STATE_READ_REG_RAM;
                          decoder_inp <= 0;
                          registers_done_op <= registers_done_op;
                        end
                        OPCODE_REG2RAM: begin
                          $display("reg to ram");
                          write_enabled <= 1;
                          write_address <= decoder_numeric[i][!decoder_slot];
                          write_value <= registers_value[i];
                          registers_read_num[0] <= i;
                          executor_state <= EXECUTE_STATE_SAVE_RAM;
                          decoder_inp <= 0;
                          registers_done_op <= registers_done_op;
                        end
                        OPCODE_REG_PLUS: begin
                          registers_value[i]   <= registers_value[i] + decoder_in4[!decoder_slot];
                          registers_done_op[i] <= 1;
                        end
                        OPCODE_REG_MINUS: begin
                          registers_value[i]   <= registers_value[i] - decoder_in4[!decoder_slot];
                          registers_done_op[i] <= 1;
                        end
                      endcase
                    end
                  end
                endcase
              end
            end
          end
        end
        EXECUTE_STATE_READ_REG_RAM: begin
          if (registers_read_now[0]) begin
            $display($sformatf("%02d", $time), " slot 0: reading reg ", registers_read_num[0]);
            registers_value[registers_read_num[0]] <= read_value;
            registers_init[registers_read_num[0]] <= 1;
            registers_done_op[registers_read_num[0]] <= 1;
          end
          if (registers_read_now[1]) begin
            $display($sformatf("%02d", $time), " slot 1: reading reg ", registers_read_num[1]);
            registers_value[registers_read_num[1]] <= read_value2;
            registers_init[registers_read_num[1]] <= 1;
            registers_done_op[registers_read_num[1]] <= 1;
          end
          registers_read_now <= '{default: 0};
          executor_state <= EXECUTE_STATE_START3;
        end
        EXECUTE_STATE_SAVE_RAM: begin
          $display("reg to ram 2");
          registers_done_op[registers_read_num[0]] <= 1;
          executor_state <= EXECUTE_STATE_START3;
          write_enabled <= 0;
        end
        EXECUTE_STATE_HALT: begin
          decoder_inp <= 0;
        end
      endcase
    end
  end
endmodule

module decoder (
    input clk,
    input bit rst,
    inp,
    input reg [15:0] address,
    read1,
    read2,

    output bit slot,
    ready,
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

  integer j;

  always @(posedge clk) begin
    if (inp) begin
      if (HARDWARE_DEBUG) begin
        $write(  //DEBUG info
            $sformatf("%02d", $time),  //DEBUG info
            " decoder slot ", slot, " pc ", address, " opcode %c%c%c%c",  //DEBUG info
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
          OPCODE_JMP_IF1:
          $write(
              " jmp to address ",
              `INSTRUCTION4,
              " if register ",
              `INSTRUCTION2,
              "=",
              (`INSTRUCTION3)
          );
          OPCODE_JMP_IF2:
          $write(
              " jmp to address ",
              `INSTRUCTION4,
              " if register ",
              `INSTRUCTION2,
              "=",
              (`INSTRUCTION3 << 4 + 16)
          );
          OPCODE_JMP_IF3:
          $write(
              " jmp to address ",
              `INSTRUCTION4,
              " if register ",
              `INSTRUCTION2,
              "=",
              (`INSTRUCTION3 << 8 + 256)
          );
          OPCODE_JMP_IF4:
          $write(
              " jmp to address ",
              `INSTRUCTION4,
              " if register ",
              `INSTRUCTION2,
              "=",
              (`INSTRUCTION3 << 12 + 4096)
          );
          OPCODE_RAM2REG:
          $write(
              " ram2reg read value from logical address ",
              `INSTRUCTION4,  //DEBUG info
              " to reg ",
              `INSTRUCTION2,
              "-",
              (`INSTRUCTION2 + `INSTRUCTION3 - 1)
          );  //DEBUG info
          OPCODE_REG2RAM:
          $write(
              " reg2ram save value from reg ",  //DEBUG info
              `INSTRUCTION2,
              "-",
              (`INSTRUCTION2 + `INSTRUCTION3 - 1),  //DEBUG info
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
              (`INSTRUCTION2 + `INSTRUCTION3 - 1)
          );  //DEBUG info
          OPCODE_REG_PLUS:
          $write(
              " regplus add value ",
              `INSTRUCTION4,
              " to reg ",
              `INSTRUCTION2,
              "-",
              (`INSTRUCTION2 + `INSTRUCTION3 - 1)
          );  //DEBUG info
          OPCODE_REG_MINUS:
          $write(
              " regminus add value ",
              `INSTRUCTION4,
              " to reg ",
              `INSTRUCTION2,
              "-",
              (`INSTRUCTION2 + `INSTRUCTION3 - 1)
          );  //DEBUG info
          default: begin
            $write(" unknown");  //DEBUG info
          end
        endcase
      end

      if (HARDWARE_DEBUG) $display("");
    end
  end

  always @(posedge clk) begin
    if (rst) begin
      slot <= 0;
      $display($sformatf("%02d", $time), "rst decoder");
    end
    //end else 
    if (inp) begin
      slot  <= !slot;
      ready <= inp;

      case (`INSTRUCTION1)
        OPCODE_JMP_IF1, OPCODE_JMP_IF2, OPCODE_JMP_IF3, OPCODE_JMP_IF4: begin
          do_op[`INSTRUCTION2][slot] <= 1;
        end
        default: begin
          for (j = 0; j <= REGISTER_NUM; j = j + 1) begin
            if (j >= `INSTRUCTION2 && j <= `INSTRUCTION2 + `INSTRUCTION3 - 1) begin
              numeric[j][slot] <= `INSTRUCTION4 + j - `INSTRUCTION2;
              do_op[j][slot]   <= 1;
            end else begin
              do_op[j][slot] <= 0;
            end
          end
        end
      endcase

    end
  end

  always @(posedge clk) begin
    if (inp) begin
      in1[slot] <= `INSTRUCTION1;
      in2[slot] <= `INSTRUCTION2;
      in3[slot] <= `INSTRUCTION3;
      in4[slot] <= `INSTRUCTION4;
      in3_big[slot] <= (`INSTRUCTION1==OPCODE_JMP_IF1)?
           `INSTRUCTION3:
           ((`INSTRUCTION1==OPCODE_JMP_IF2)?`INSTRUCTION3<<4+16:
           ((`INSTRUCTION1==OPCODE_JMP_IF3 )?`INSTRUCTION3<<8+256:`INSTRUCTION3<<12+4096));
    end
  end

  always @(posedge clk) begin
    if (inp) begin
      error_code[slot] <= 0;
      case (`INSTRUCTION1)
        OPCODE_JMP, OPCODE_JMP_IF1, OPCODE_JMP_IF2, OPCODE_JMP_IF3, OPCODE_JMP_IF4: begin
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


/*parameter OPCODE_JMP = 1;  //16 bit target address
parameter OPCODE_JMP_IF1 = 2; //register num (5 bits), how many-1 (3 bits), 16 bit value  //reg -= value
parameter OPCODE_JMP_IF2 = 3; //register num (5 bits), how many-1 (3 bits), 16 bit value  //reg -= value
parameter OPCODE_JMP_IF3 = 4; //register num (5 bits), how many-1 (3 bits), 16 bit value  //reg -= value
parameter OPCODE_JMP_IF4 = 5; //register num (5 bits), how many-1 (3 bits), 16 bit value  //reg -= value
parameter OPCODE_JMP_IF_NOT1 = 6; //register num (5 bits), how many-1 (3 bits), 16 bit value  //reg -= value
parameter OPCODE_JMP_IF_NOT2 = 7; //register num (5 bits), how many-1 (3 bits), 16 bit value  //reg -= value
parameter OPCODE_JMP_IF_NOT3 = 8; //register num (5 bits), how many-1 (3 bits), 16 bit value  //reg -= value
parameter OPCODE_JMP_IF_NOT4 = 9; //register num (5 bits), how many-1 (3 bits), 16 bit value  //reg -= value
parameter OPCODE_RAM2REG = 'h0a;  //register num (4 bits), how many (4 bits), 16 bit source addr //ram -> reg
parameter OPCODE_REG2RAM = 'h0b; //14 //register num (4 bits), how many-1 (4 bits), 16 bit target addr //reg -> ram
parameter OPCODE_NUM2REG = 'h0c; //18;  //register num (4 bits), how many-1 (4 bits), 16 bit value //value -> reg
parameter OPCODE_REG_PLUS = 'h0e;//20; //register num (5 bits), how many-1 (3 bits), 16 bit value // reg += value
parameter OPCODE_REG_MINUS = 'h0f; //register num (5 bits), how many-1 (3 bits), 16 bit value  //reg -= value
*/

      16'h0a91, 16'd0112, //value to reg // not used for anything usefull, just for debugging
      16'h0b91, 16'd0212, //save to ram // not used for anything usefull, just for debugging
      16'h0ab1, 16'd0214, //ram to reg // not used for anything usefull, just for debugging
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

    //     $display(
    //            $sformatf("%02d", $time), " ram read ", read_address, " = ", ram[read_address]
    //        );  //DEBUG info
    //       $display(
    //            $sformatf("%02d", $time), " ram read ", read_address2, " = ", ram[read_address2]
    //        );  //DEBUG info

  end
endmodule

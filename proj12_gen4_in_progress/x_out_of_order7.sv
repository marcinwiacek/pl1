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
parameter ADDRESS_MMU_ADDR = ADDRESS_REG + 33;
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
parameter OPCODE_REG2OUT = 'h10;  //register num (4 bits)
parameter OPCODE_IN2REG = 'h11;  //register num (4 bits)
parameter OPCODE_NEW_PROC = 'h12;  //register num (4 bits), how many-1 (4 bits)


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
parameter EXECUTE_STATE_START2 = 1;
parameter EXECUTE_STATE_START3 = 2;
parameter EXECUTE_STATE_MMU = 3;
parameter EXECUTE_STATE_HALT = 4;
parameter EXECUTE_STATE_READ_REG_FROM_RAM = 5;
parameter EXECUTE_STATE_SAVE_REG_TO_RAM = 6;
parameter EXECUTE_STATE_SAVE_REG_TO_RAM2 = 7;
parameter EXECUTE_STATE_SWITCH = 8;
parameter EXECUTE_STATE_SWITCH2 = 9;
parameter EXECUTE_STATE_SWITCH3 = 10;

parameter REGISTER_NUM = 15;

module x_out_of_order7 (
    input clk,
    input bit uart_tx_in,

    output reg x,
    output bit uart_rx_out
);

  reg rst = 1;

  //--------------------------------------------- screen ---------------------------------

  bit [15:0] uart_transmit_bit;
  bit uart_new_bit;
  wire uart_full;

  uartx_tx_with_buffer1 uartx_tx_with_buffer1 (
      .rst(rst),
      .clk(clk),
      .transmit_bit(uart_transmit_bit),
      .uart_full(uart_full),
      .new_bit(uart_new_bit),
      .tx(uart_rx_out)
  );

  //----------------------------------------------------keyboard---------------------------------

  wire [7:0] uart_bb;
  wire uart_bb_ready;
  bit uart_bb_processed;

  uart_rx1 uart_rx1 (
      .rst(rst),
      .clk(clk),
      .bb_processed(uart_bb_processed),
      .uartrx(uart_tx_in),
      .bb(uart_bb),
      .bb_ready(uart_bb_ready)
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
      .read_value(read_value),
      .read_value2(read_value2)
  );

  //--------------------------------------------------------------------process------------------

  reg [15:0] process_start;
  reg [15:0] pc_logical, registers_value[0:REGISTER_NUM];
  reg registers_init[0:REGISTER_NUM], registers_changed[0:REGISTER_NUM];
  reg [6:0] registers_read_num[1:0];
  reg registers_done_op[0:REGISTER_NUM];

  //--------------------------------------------------------------------executor------------------

  integer i;

  reg [7:0] reg_nr;
  reg [5:0] executor_state, executor_state2;
  reg [4:0] instr_num;  // how many done

  reg [2:0] offset;
  assign offset = executor_state == EXECUTE_STATE_START2 ? 2 : 0;

  //---------------------------------------------------------decoder--------------------------

  reg  decoder_inp;

  wire decoder_slot0;
  wire [3:0] decoder_error_code[0:1], decoder_in2[0:1], decoder_in3[0:1];
  wire [7:0] decoder_in1[0:1];
  wire [15:0] decoder_in3_big[0:1], decoder_in4[0:1], decoder_numeric[REGISTER_NUM:0][0:1];
  wire decoder_do_op[REGISTER_NUM:0][0:1];

  reg  decoder_slot;
  assign decoder_slot = executor_state == EXECUTE_STATE_START2 ? !decoder_slot0 : decoder_slot0;

  decoder decoder (
      .rst(rst),
      .clk(clk),
      .inp(decoder_inp),
      .address(pc_logical),
      .read1(read_value),
      .read2(read_value2),
      .slot(decoder_slot0),
      .do_op(decoder_do_op),
      .error_code(decoder_error_code),
      .in1(decoder_in1),
      .in2(decoder_in2),
      .in3(decoder_in3),
      .in3_big(decoder_in3_big),
      .in4(decoder_in4),
      .numeric(decoder_numeric)
  );

  //--------------------------------------------------------- mmu ----------------------------

  reg [15:0]
      mmu_read_logical[1:0],
      mmu_address_physical_min_in_the_same_page,
      mmu_address_logical_min_in_the_same_page,
      mmu_address_logical_max_in_the_same_page,
      mmu_address_physical_min_in_the_same_page2,
      mmu_address_logical_min_in_the_same_page2,
      mmu_address_logical_max_in_the_same_page2;

  reg mmu_miss;
  assign mmu_miss = mmu_read_logical[0]>0 && 
       (mmu_read_logical[0]<mmu_address_logical_min_in_the_same_page || mmu_read_logical[0]>mmu_address_logical_max_in_the_same_page || 
       mmu_read_logical[1]<mmu_address_logical_min_in_the_same_page2 || mmu_read_logical[1]>mmu_address_logical_max_in_the_same_page2);

  //---------------------------------------------------------- other -------------------------

  assign x = decoder_inp;  //without this we will have empty circuit

  always @(posedge clk) begin
    if (rst) begin
      mmu_address_physical_min_in_the_same_page  <= 0;
      mmu_address_logical_min_in_the_same_page   <= 0;
      mmu_address_logical_max_in_the_same_page   <= 256 - 1;  //2^8-1

      mmu_address_physical_min_in_the_same_page2 <= 0;
      mmu_address_logical_min_in_the_same_page2  <= 0;
      mmu_address_logical_max_in_the_same_page2  <= 256 - 1;  //2^8-1
    end else if (executor_state == EXECUTE_STATE_MMU) begin
      mmu_address_physical_min_in_the_same_page  <= read_value[15:8] * 256;
      mmu_address_logical_min_in_the_same_page   <= mmu_read_logical[0][15:8] * 256;
      mmu_address_logical_max_in_the_same_page   <= mmu_read_logical[0][15:8] * 256 + 256 - 1;

      mmu_address_physical_min_in_the_same_page2 <= read_value2[15:8] * 256;
      mmu_address_logical_min_in_the_same_page2  <= mmu_read_logical[1][15:8] * 256;
      mmu_address_logical_max_in_the_same_page2  <= mmu_read_logical[1][15:8] * 256 + 256 - 1;
    end else if (executor_state == EXECUTE_STATE_SWITCH3) begin
      mmu_address_physical_min_in_the_same_page  <= 0;
      mmu_address_logical_min_in_the_same_page   <= read_value;
      mmu_address_logical_max_in_the_same_page   <= read_value + 256 - 1;

      mmu_address_physical_min_in_the_same_page2 <= 0;
      mmu_address_logical_min_in_the_same_page2  <= read_value;
      mmu_address_logical_max_in_the_same_page2  <= read_value + 256 - 1;
    end
  end

  always @(posedge clk) begin
    uart_new_bit <= 0;
    if (rst) begin
      instr_num <= 0;
      pc_logical <= ADDRESS_PROGRAM;
      read_address <= ADDRESS_PROGRAM;
      mmu_read_logical[0] <= 0;
      read_address2 <= ADDRESS_PROGRAM + 1;
      executor_state <= EXECUTE_STATE_START;
      rst <= 0;
      decoder_inp <= 1;
      registers_init <= '{default: 0};
      registers_changed <= '{default: 0};
      write_enabled <= 0;
      registers_done_op <= '{default: 0};
      process_start <= 0;
      uart_bb_processed <= 0;
      //  $display($sformatf("%02d", $time), " rst main");
    end else if (executor_state == EXECUTE_STATE_MMU) begin
      read_address   <= read_value * 256 + mmu_read_logical[0][7:0];
      read_address2  <= read_value2 * 256 + mmu_read_logical[1][7:0];
      executor_state <= executor_state2;
    end else if (mmu_miss) begin
      executor_state2 <= executor_state;
      executor_state <= EXECUTE_STATE_MMU;
      read_address <= process_start + ADDRESS_MMU_ADDR + mmu_read_logical[0][15:8];
      read_address2 <= process_start + ADDRESS_MMU_ADDR + mmu_read_logical[1][15:8];
      if (mmu_miss) $display($sformatf("%02d", $time), " mmu miss");
    end else begin
      if (HARDWARE_DEBUG && executor_state != EXECUTE_STATE_HALT) begin
        $write($sformatf("%02d", $time), " reg ");
        for (i = 0; i < 20; i = i + 1) begin
          $write($sformatf(" %02d:%02d:%02d ", i, registers_init[i], registers_value[i]));
        end
        $display("");
      end
      case (executor_state)
        EXECUTE_STATE_START: begin
          pc_logical <= pc_logical + 2;
          read_address <= pc_logical + 2;
          read_address2 <= pc_logical + 3;
          executor_state <= pc_logical<ADDRESS_PROGRAM?EXECUTE_STATE_HALT:EXECUTE_STATE_START2;
        end
        EXECUTE_STATE_START2, EXECUTE_STATE_START3: begin
          $display($sformatf("%02d", $time), " process ", process_start, " pc ", pc_logical,
                   ", exec_state ", executor_state, " exec_slot ", decoder_slot);

          $write($sformatf("%02d", $time), " executor slot 0 ");
          if (decoder_slot == 0) begin
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
            $write($sformatf("%02d:%02d ", i, decoder_do_op[i][0]));
          end
          $display("");

          $write($sformatf("%02d", $time), " executor slot 1 ");
          if (decoder_slot == 1) begin
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
            $write($sformatf("%02d:%02d ", i, decoder_do_op[i][1]));
          end
          $display("");

          instr_num <= instr_num + offset;
          pc_logical <= pc_logical + offset;
          mmu_read_logical[0] <= pc_logical + offset;
          read_address <= mmu_address_physical_min_in_the_same_page + pc_logical[9:0] + offset;
          mmu_read_logical[1] <= pc_logical + offset + 1;
          read_address2 <= mmu_address_physical_min_in_the_same_page + pc_logical[9:0] + offset + 1;

          executor_state <= instr_num == 20 ? EXECUTE_STATE_SWITCH : EXECUTE_STATE_START2;
          decoder_inp <= 1;

          registers_read_num[0] <= 64;
          registers_read_num[1] <= 64;

          if (decoder_error_code[decoder_slot] == 0) begin
            case (decoder_in1[decoder_slot])
              OPCODE_JMP: begin
                pc_logical <= decoder_in4[decoder_slot];
                mmu_read_logical[0] <= decoder_in4[decoder_slot];
                read_address <= mmu_address_physical_min_in_the_same_page+decoder_in4[decoder_slot][9:0];
                mmu_read_logical[1] <= decoder_in4[decoder_slot] + 1;
                read_address2 <= mmu_address_physical_min_in_the_same_page2+decoder_in4[decoder_slot][9:0]+1;
              end
              OPCODE_NUM2REG: begin
                for (i = REGISTER_NUM - 1; i >= 0; i = i - 1) begin
                  if (decoder_do_op[i][decoder_slot]) begin
                    registers_init[i] <= 1;
                    registers_changed[i] <= 1;
                    registers_value[i] <= decoder_in4[decoder_slot];
                  end
                end
              end
              OPCODE_RAM2REG: begin
                for (i = REGISTER_NUM - 1; i >= 0; i = i - 1) begin
                  if (executor_state == EXECUTE_STATE_START2) begin
                    registers_done_op[i] <= !decoder_do_op[i][decoder_slot];
                  end
                  if (executor_state == EXECUTE_STATE_START2?decoder_do_op[i][decoder_slot]:!registers_done_op[i]) begin
                    $display("ram2reg");
                    if (i % 2 == 0) begin
                      read_address <= mmu_address_physical_min_in_the_same_page+decoder_numeric[i][decoder_slot][9:0];
                    end else begin
                      read_address2 <= mmu_address_physical_min_in_the_same_page2+decoder_numeric[i][decoder_slot][9:0];
                    end
                    mmu_read_logical[i%2] <= decoder_numeric[i][decoder_slot];
                    registers_read_num[i%2] <= i;
                    executor_state <= EXECUTE_STATE_READ_REG_FROM_RAM;
                    decoder_inp <= 0;
                  end
                end
              end
              OPCODE_NEW_PROC: begin
              end
              default: begin
                for (i = REGISTER_NUM - 1; i >= 0; i = i - 1) begin
                  if (executor_state == EXECUTE_STATE_START2) begin
                    registers_done_op[i] <= !decoder_do_op[i][decoder_slot];
                  end
                  if (executor_state == EXECUTE_STATE_START2?decoder_do_op[i][decoder_slot]:!registers_done_op[i]) begin
                    if (!registers_init[i]) begin
                      if (i % 2 == 0) begin
                        read_address <= process_start + ADDRESS_REG + i;
                      end else begin
                        read_address2 <= process_start + ADDRESS_REG + i;
                      end
                      registers_read_num[i%2] <= i;
                      mmu_read_logical[0] <= 0;
                      executor_state <= EXECUTE_STATE_READ_REG_FROM_RAM;
                      decoder_inp <= 0;
                    end else begin
                      case (decoder_in1[decoder_slot])
                        OPCODE_JMP_IF1, OPCODE_JMP_IF2, OPCODE_JMP_IF3, OPCODE_JMP_IF4: begin
                          if (registers_value[i] == decoder_in3_big[decoder_slot]) begin
                            pc_logical <= decoder_in4[decoder_slot];
                            mmu_read_logical[0] <= decoder_in4[decoder_slot];
                            read_address <= mmu_address_physical_min_in_the_same_page+decoder_in4[decoder_slot][9:0];
                            mmu_read_logical[1] <= decoder_in4[decoder_slot] + 1;
                            read_address2 <= mmu_address_physical_min_in_the_same_page2+decoder_in4[decoder_slot][9:0]+1;
                          end
                        end
                        OPCODE_REG2RAM: begin
                          $display("reg to ram");
                          executor_state <= EXECUTE_STATE_SAVE_REG_TO_RAM;
                          registers_read_num[0] <= i;
                          read_address <= mmu_address_physical_min_in_the_same_page+decoder_numeric[i][decoder_slot][9:0];
                          mmu_read_logical[0] <= decoder_numeric[i][decoder_slot];
                          decoder_inp <= 0;
                        end
                        OPCODE_REG_PLUS: begin
                          $display("regplus");
                          registers_changed[i] <= 1;
                          registers_value[i]   <= registers_value[i] + decoder_in4[decoder_slot];
                          registers_done_op[i] <= 1;
                        end
                        OPCODE_REG_MINUS: begin
                          $display("regminus");
                          registers_changed[i] <= 1;
                          registers_value[i]   <= registers_value[i] - decoder_in4[decoder_slot];
                          registers_done_op[i] <= 1;
                        end
                        OPCODE_REG2OUT: begin
                          uart_transmit_bit <= registers_value[i];
                          uart_new_bit <= !uart_full;
                          executor_state <= uart_full ? EXECUTE_STATE_START3 : EXECUTE_STATE_START2;
                        end
                      endcase
                    end
                  end
                end
              end
            endcase
          end
        end
        EXECUTE_STATE_READ_REG_FROM_RAM: begin
          executor_state <= EXECUTE_STATE_START3;
          if (registers_read_num[0] != 64) begin
            $display($sformatf("%02d", $time), " slot 0: reading reg ", registers_read_num[0],
                     " src ", read_address);
            registers_value[registers_read_num[0]] <= read_value;
            registers_changed[registers_read_num[0]] <= 1;
            registers_init[registers_read_num[0]] <= 1;
            if (mmu_read_logical[0] != 0) begin
              registers_done_op[registers_read_num[0]] <= 1;
            end
          end
          if (registers_read_num[1] != 64) begin
            $display($sformatf("%02d", $time), " slot 1: reading reg ", registers_read_num[1],
                     " src ", read_address2);
            registers_value[registers_read_num[1]] <= read_value2;
            registers_init[registers_read_num[1]] <= 1;
            registers_changed[registers_read_num[1]] <= 1;
            if (mmu_read_logical[0] != 0) begin
              registers_done_op[registers_read_num[1]] <= 1;
            end
          end
        end
        EXECUTE_STATE_SAVE_REG_TO_RAM: begin
          write_enabled <= 1;
          write_address <= mmu_address_physical_min_in_the_same_page + mmu_read_logical[0][9:0];
          write_value <= registers_value[registers_read_num[0]];
          executor_state <= EXECUTE_STATE_SAVE_REG_TO_RAM2;
        end
        EXECUTE_STATE_SAVE_REG_TO_RAM2: begin
          $display("reg to ram 2");
          registers_done_op[registers_read_num[0]] <= 1;
          executor_state <= EXECUTE_STATE_START3;
          write_enabled <= 0;
        end
        EXECUTE_STATE_SWITCH: begin
          decoder_inp <= 0;
          executor_state <= EXECUTE_STATE_SWITCH2;
          read_address <= process_start + ADDRESS_NEXT_PROCESS;
          write_address <= process_start + ADDRESS_PC;
          write_value <= pc_logical;
          write_enabled <= 1;
          mmu_read_logical[0] <= 0;
          reg_nr <= 64;
        end
        EXECUTE_STATE_SWITCH2: begin
          executor_state <= EXECUTE_STATE_SWITCH3;
          read_address2  <= read_value + ADDRESS_PC;
          write_enabled  <= 0;
          if (reg_nr != 64) begin
            registers_changed[reg_nr] <= 0;
            registers_init[reg_nr] <= 0;
          end
          for (i = 0; i <= REGISTER_NUM; i = i + 1) begin
            if (reg_nr != i) begin
              if (registers_changed[i]) begin
                executor_state <= EXECUTE_STATE_SWITCH2;
                write_address <= process_start + ADDRESS_REG + i;
                write_value <= registers_value[i];
                write_enabled <= 1;
                reg_nr <= i;
              end
            end
          end
        end
        EXECUTE_STATE_SWITCH3: begin
          if (reg_nr != 64) begin
            registers_changed[reg_nr] <= 0;
            registers_init[reg_nr] <= 0;
          end
          process_start <= read_value;
          pc_logical <= read_value2;
          read_address <= read_value + ADDRESS_PC;
          executor_state <= EXECUTE_STATE_START;
          instr_num <= 0;
        end
        EXECUTE_STATE_HALT: begin
          $display(" pc logical ", pc_logical);
          decoder_inp <= 0;
        end
      endcase
    end
    if (HARDWARE_DEBUG && executor_state != EXECUTE_STATE_HALT) $display("");
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
          OPCODE_REG2OUT:
          $write(
              " save reg ", `INSTRUCTION2, "-", (`INSTRUCTION2 + `INSTRUCTION3 - 1), " to screen"
          );  //DEBUG info
          OPCODE_IN2REG:
          $write(
              " read keyboard to ", `INSTRUCTION2, "-", (`INSTRUCTION2 + `INSTRUCTION3 - 1)
          );  //DEBUG info
          OPCODE_NEW_PROC:
          $write(
              " new process pages ", `INSTRUCTION2, "-", (`INSTRUCTION2 + `INSTRUCTION3 - 1)
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
      //   $display($sformatf("%02d", $time), " rst decoder");
    end else if (inp) begin
      slot <= !slot;
      //  ready <= inp;

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
        OPCODE_JMP, OPCODE_JMP_IF1, OPCODE_JMP_IF2, OPCODE_JMP_IF3, OPCODE_JMP_IF4, OPCODE_NEW_PROC: begin
        end
        OPCODE_RAM2REG, OPCODE_REG2RAM, OPCODE_NUM2REG, OPCODE_REG_PLUS, OPCODE_REG_MINUS, OPCODE_REG2OUT, OPCODE_IN2REG: begin
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
   bit [15:0] ram  [0:511]= {  // in Vivado (required by board)
  //  reg [0:559] [15:0] ram = {  // in iVerilog

      //first process - 1 page (256 elements)
      //page 1 (256 elements)
      16'd0256, 16'h0000,  16'h0000, 16'h0000, //next process address (no MMU) overwritten by CPU, we use first bytes only      
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
      
      //100 elements
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

      //56 elements
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,

      //first process - 1 page (256 elements)
      //page 1 (256 elements)
      16'd0000, 16'h0000,  16'h0000, 16'h0000, //next process address (no MMU) overwritten by CPU, we use first bytes only      
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
      
      //100 elements
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

      //56 elements
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000
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

    //  $display(
    //                $sformatf("%02d", $time), " ram read ", read_address, " = ", ram[read_address]
    //            );  //DEBUG info
    //           $display(
    //                $sformatf("%02d", $time), " ram read ", read_address2, " = ", ram[read_address2]
    //            );  //DEBUG info
  end
endmodule


module uartx_tx_with_buffer1 (
    input rst,
    input clk,
    input [15:0] transmit_bit,
    input new_bit,
    output bit uart_full,
    output bit tx
);

  bit [7:0] uart_tx_buffer[0:50];
  bit [6:0] uart_tx_buffer_available;
  wire reset_uart_tx_buffer_available;

  uartx_tx_with_buffer uartx_tx_with_buffer (
      .rst(rst),
      .clk(clk),
      .uart_buffer(uart_tx_buffer),
      .uart_buffer_available(uart_tx_buffer_available),
      .reset_uart_buffer_available(reset_uart_tx_buffer_available),
      .tx(tx)
  );

  always @(posedge clk) begin
    if (rst || reset_uart_tx_buffer_available) begin
      uart_full <= 0;
      uart_tx_buffer_available <= 0;
    end else if (new_bit) begin
      uart_tx_buffer[uart_tx_buffer_available] <= transmit_bit[7:0];
      //   uart_tx_buffer[uart_tx_buffer_available+1] <= transmit_bit[15:8];
      uart_tx_buffer_available <= uart_tx_buffer_available + 1;
      uart_full <= uart_tx_buffer_available != 48;
    end
  end
endmodule

module uartx_tx_with_buffer (
    input rst,
    input clk,
    input [7:0] uart_buffer[0:50],
    input [6:0] uart_buffer_available,
    output bit reset_uart_buffer_available,
    output bit tx
);

  bit [7:0] input_data;
  bit [6:0] uart_buffer_processed;
  bit [3:0] uart_buffer_state;
  bit start;
  wire complete;

  uart_tx uart_tx (
      .rst(rst),
      .clk(clk),
      .start(start),
      .input_data(input_data),
      .complete(complete),
      .uarttx(tx)
  );

  always @(posedge clk) begin
    if (rst) begin
      uart_buffer_processed <= 0;
      uart_buffer_state <= 0;
      reset_uart_buffer_available <= 0;
    end else begin
      case (uart_buffer_state)
        0: begin
          start <= 0;
          reset_uart_buffer_available <= 0;
          if (uart_buffer_available > 0) begin
            if (uart_buffer_processed < uart_buffer_available) begin
              input_data <= uart_buffer[uart_buffer_processed];
              uart_buffer_state <= 1;
              uart_buffer_processed <= uart_buffer_processed == uart_buffer_available-1?0: uart_buffer_processed + 1;
            end
          end
        end
        1: begin
          start <= 1;
          if (!complete) uart_buffer_state <= 2;
        end
        2: begin
          start <= 0;
          if (complete) begin
            uart_buffer_state <= 0;
            reset_uart_buffer_available <= uart_buffer_available == uart_buffer_processed;
          end
        end
      endcase
    end
  end
endmodule


//115200, 8 bits (LSB first), 1 stop, no parity
//values on tx: ...1, 0 (start bit), (8 data bits), 1 (stop bit), 1... 
//(we make some delay in the end before next seq; every bit is sent CLK_PER_BIT cycles)
module uart_tx (
    input rst,
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

  bit [ 5:0] uart_tx_state;
  bit [10:0] counter;

  always @(posedge clk) begin
    uarttx <= uart_tx_state == STATE_IDLE || uart_tx_state == STATE_STOP_BIT ? 1:(uart_tx_state == STATE_START_BIT ? 0:input_data[uart_tx_state-STATE_DATA_BIT_0]);
  end

  always @(posedge clk) begin
    if (rst) begin
      uart_tx_state <= STATE_IDLE;
      counter <= CLK_PER_BIT;
    end else begin
      case (uart_tx_state)
        STATE_IDLE: begin
          complete <= 1;
          if (start) uart_tx_state <= STATE_START_BIT;
        end
        default: begin
          complete <= 0;
          if (counter == 0) begin
            counter <= CLK_PER_BIT;
            uart_tx_state <= uart_tx_state == STATE_STOP_BIT ? STATE_IDLE : uart_tx_state + 1;
          end else begin
            counter <= counter - 1;
          end
        end
      endcase
    end
  end
endmodule

module uart_rx1 (
    input clk,
    input rst,
    input uartrx,
    input bb_processed,
    output logic [7:0] bb,
    output logic bb_ready
);


uart_rx uart_rx (
    .clk(clk),
    .rst(rst),
    .uartrx(uartrx),
    .bb_processed(bb_processed),
    .bb(bb),
    .bb_ready(bb_ready)
);


endmodule

module uart_rx (
    input clk,
    input rst,
    input uartrx,
    input bb_processed,
    output logic [7:0] bb,
    output logic bb_ready
);

  parameter CLK_PER_BYTE = 100000000 / 115200;  //100 Mhz / transmission speed in bps (bits per second)
parameter CLK_PER_BYTE_HALF = (CLK_PER_BYTE - 1) / 2;

  parameter STATE_IDLE = 0;  //1
  parameter STATE_START_BIT = 1;  //0
  parameter STATE_DATA_BIT_0 = 2;
  //...
  parameter STATE_DATA_BIT_7 = 9;
  parameter STATE_STOP_BIT = 10;  //1

  reg [ 5:0] uart_tx_state;
  reg [10:0] counter;
  //reg uartrxreg, inp;

  //double buffering to avoid metastability
  //always @(posedge clk) begin
//    uartrxreg <= uartrx;
//    inp <= uartrxreg;
//  end
  
  always @(posedge clk) begin
     if (counter == 0) begin
       if (uart_tx_state >= STATE_DATA_BIT_0) begin
        if (uart_tx_state <= STATE_DATA_BIT_7) begin
            bb[uart_tx_state-STATE_DATA_BIT_0] <= uartrx;
            end
            end
     end
  end

  always @(posedge clk) begin
    if (rst) begin
      uart_tx_state <= STATE_IDLE;
      bb_ready <= 0;
    end else begin
      case (uart_tx_state)
        STATE_IDLE: begin
          if (bb_processed) begin
             bb_ready <= 0;
             if (uartrx == 0) begin
               counter <= CLK_PER_BYTE_HALF;
               uart_tx_state <= STATE_START_BIT;
             end
          end
        end
        STATE_START_BIT: begin
          if (counter == 0) begin
            uart_tx_state <= uartrx == 1?STATE_IDLE:STATE_DATA_BIT_0;
            counter <= CLK_PER_BYTE;
          end else begin
            counter <= counter - 1;
          end
        end
        default: begin 
          if (counter == 0) begin       
            bb_ready <= uart_tx_state==STATE_STOP_BIT;
            uart_tx_state <= uart_tx_state==STATE_STOP_BIT?STATE_IDLE:uart_tx_state + 1;
            counter <= CLK_PER_BYTE;
          end else begin
            counter <= counter - 1;
          end
        end
      endcase
    end
  end
endmodule


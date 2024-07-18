`timescale 1ns / 1ps

//options below are less important than options higher //DEBUG info
parameter WRITE_RAM_DEBUG = 0;  //1 enabled, 0 disabled //DEBUG info
parameter READ_RAM_DEBUG = 0;  //1 enabled, 0 disabled //DEBUG info
parameter REG_CHANGES_DEBUG = 0;  //1 enabled, 0 disabled //DEBUG info
parameter MMU_CHANGES_DEBUG = 1;  //1 enabled, 0 disabled //DEBUG info
parameter MMU_TRANSLATION_DEBUG = 0;  //1 enabled, 0 disabled //DEBUG info
parameter TASK_SWITCHER_DEBUG = 1;  //1 enabled, 0 disabled //DEBUG info
parameter TASK_SPLIT_DEBUG = 1;  //1 enabled, 0 disabled //DEBUG info

parameter MMU_PAGE_SIZE = 70;  //how many bytes are assigned to one memory page in MMU
parameter RAM_SIZE = 32767;
parameter MMU_MAX_INDEX = 455;  //(`RAM_SIZE+1)/`MMU_PAGE_SIZE;

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
                         mmu_logical_pages_read_address = i; \
                         mmu_chain_read_address = i; \
/* DEBUG info */         if (mmu_start_process_physical_segment == i && mmu_logical_pages_read_value!=0) $write("s"); \
/* DEBUG info */         if (mmu_chain_read_value == i && mmu_logical_pages_read_value!=0) $write("e"); \
/* DEBUG info */         $write($sformatf("%02x-%02x ", mmu_chain_read_value, mmu_logical_pages_read_value)); \
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

//offsets for process info
parameter ADDRESS_NEXT_PROCESS = 0;
parameter ADDRESS_PC = 4;
parameter ADDRESS_REG_USED = 8;
parameter ADDRESS_REG = 14;
parameter ADDRESS_PROGRAM = ADDRESS_REG + 32;

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
  reg [6:0] uart_buffer_available;
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

  logic [15:0] mmu_chain_write_address;
  logic [15:0] mmu_chain_write_value;
  logic [15:0] mmu_chain_read_address;
  wire  [15:0] mmu_chain_read_value;

  small_ram mmu_chain_memory2 (
      .write_address(mmu_chain_write_address),
      .write_value(mmu_chain_write_value),
      .read_address(mmu_chain_read_address),
      .read_value(mmu_chain_read_value)
  );

  logic [15:0] mmu_logical_pages_write_address;
  logic [15:0] mmu_logical_pages_write_value;
  logic [15:0] mmu_logical_pages_read_address;
  wire  [15:0] mmu_logical_pages_read_value;

  small_ram mmu_logical_pages2 (
      .write_address(mmu_logical_pages_write_address),
      .write_value(mmu_logical_pages_write_value),
      .read_address(mmu_logical_pages_read_address),
      .read_value(mmu_logical_pages_read_value)
  );

  //  reg [8:0] mmu_chain_memory[0:MMU_MAX_INDEX];  //next physical segment index for process (last entry = the same entry)
  //  reg [8:0] mmu_logical_pages_memory[0:MMU_MAX_INDEX];  //logical process page assigned to physical segment (0 means empty page, we setup value > 0 for first page with logical index 0 and ignore it)
  reg [8:0] mmu_start_process_physical_segment;  //needs to be updated on process switch

  reg [8:0] mmu_address_to_search;
  reg [8:0] mmu_address_to_search_segment;
  reg [8:0] mmu_search_position;

  parameter OPCODE_JMP = 1;  //24 bit target address
  parameter OPCODE_JMP16 = 2;  //x, register num with target addr (we read one reg)
  parameter OPCODE_JMP32 = 3;  //x, first register num with target addr (we read two reg)
  parameter OPCODE_JMP64 = 4;  //x, first register num with target addr (we read four reg)  
  parameter OPCODE_RAM2REG = 5;  //register num, 16 bit source addr //ram -> reg
  parameter OPCODE_RAM2REG16 = 6; //start register num, how many registers, register num with source addr (we read one reg), //ram -> reg
  parameter OPCODE_RAM2REG32 = 7; //start register num, how many registers, first register num with source addr (we read two reg), //ram -> reg
  parameter OPCODE_RAM2REG64 = 8; //start register num, how many registers, first register num with source addr (we read four reg), //ram -> reg
  parameter OPCODE_REG2RAM = 9;  //register num, 16 bit target addr //reg -> ram
  parameter OPCODE_REG2RAM16 = 10; //start register num, how many registers, register num with target addr (we read one reg), //reg -> ram
  parameter OPCODE_REG2RAM32 = 11; //start register num, how many registers, first register num with target addr (we read two reg), //reg -> ram
  parameter OPCODE_REG2RAM64 = 12; //start register num, how many registers, first register num with target addr (we read four reg), //reg -> ram
  parameter OPCODE_NUM2REG = 14;  //register num, 16 bit value //value -> reg

  parameter STAGE_AFTER_RESET = 1;
  parameter STAGE_GET_1_BYTE = 2;
  parameter STAGE_GET_2_BYTE = 3;
  parameter STAGE_CHECK_MMU_ADDRESS = 4;
  parameter STAGE_SEARCH1_MMU_ADDRESS = 5;
  parameter STAGE_SEARCH2_MMU_ADDRESS = 6;

  reg [5:0] pc;
  reg rst_can_be_done = 1;
  reg [3:0] stage = 0, stage_after_mmu;
  reg [15:0] registers[0:31];  //512 bits = 32 x 16-bit registers

  reg [15:0] instruction1;
  logic [7:0] instruction1_1;
  logic [7:0] instruction1_2;
  logic [7:0] instruction2_1;
  logic [7:0] instruction2_2;

  assign instruction1_1 = instruction1[15:8];
  assign instruction1_2 = instruction1[7:0];
  assign instruction2_1 = read_value[15:8];
  assign instruction2_2 = read_value[7:0];

  reg [11:0] temp1, temp2, temp3;

  integer i;  //DEBUG info

  always @(negedge clk) begin
    if (reset && rst_can_be_done) begin
      rst_can_be_done = 0;
      $display($time, "reset");

      pc = ADDRESS_PROGRAM;
      //we start from segment number 0 in first process      
      read_address = ADDRESS_PROGRAM;
      stage = STAGE_GET_1_BYTE;

      uart_buffer[uart_buffer_available++] = "S";
      $display($time, "S");

      mmu_start_process_physical_segment = 0;

      mmu_chain_write_value = 0;
      mmu_chain_write_address = 0;
      for (i = 0; i < MMU_MAX_INDEX; i = i + 1) begin
        //value 0 means, that it's empty. in every process on first entry we setup something != 0 and ignore it
        // (first process page starts always from segment 0)
        mmu_logical_pages_write_value   = 0;
        mmu_logical_pages_write_address = i;
      end

      //some more complicated config used for testing //DEBUG info
      mmu_chain_write_value = 5;
      mmu_chain_write_address = 0;
      mmu_chain_write_value = 2;
      mmu_chain_write_address = 5;
      mmu_chain_write_value = 1;
      mmu_chain_write_address = 2;
      mmu_chain_write_value = 1;
      mmu_chain_write_address = 1;
      mmu_logical_pages_write_value = 1;
      mmu_logical_pages_write_address = 0;
      mmu_logical_pages_write_value = 3;
      mmu_logical_pages_write_address = 5;
      mmu_logical_pages_write_value = 2;
      mmu_logical_pages_write_address = 2;
      mmu_logical_pages_write_value = 1;
      mmu_logical_pages_write_address = 1;

      `SHOW_MMU_DEBUG
    end else begin
      case (stage)
        STAGE_SEARCH1_MMU_ADDRESS: begin
          $display($time, "#");
          uart_buffer[uart_buffer_available++] = "#";
          mmu_logical_pages_read_address = mmu_search_position;
          if (mmu_logical_pages_read_value == mmu_address_to_search_segment) begin
            read_address = mmu_address_to_search % MMU_PAGE_SIZE + mmu_search_position * MMU_PAGE_SIZE;
            stage = stage_after_mmu;
          end else begin
            mmu_chain_read_address = mmu_search_position;
            temp1 = mmu_chain_read_value;
            mmu_logical_pages_read_address = mmu_search_position;
            temp2 = mmu_logical_pages_read_value;
            temp3 = mmu_search_position;
            mmu_search_position = mmu_chain_read_value;
            stage = STAGE_SEARCH2_MMU_ADDRESS;
          end
        end
        STAGE_SEARCH2_MMU_ADDRESS: begin
          $display($time, "$");
          uart_buffer[uart_buffer_available++] = "$";
          mmu_logical_pages_read_address = mmu_search_position;
          if (mmu_logical_pages_read_value == mmu_address_to_search_segment) begin
            //move found address to the beginning to speed up search in the future
            $display($time, "swapping");
            mmu_chain_read_address = mmu_search_position;
            mmu_chain_write_value = mmu_chain_read_value;
            mmu_chain_write_address = temp3;
            mmu_chain_write_value = temp1;
            mmu_chain_write_address = mmu_search_position;
            mmu_logical_pages_write_value = temp2;
            mmu_logical_pages_write_address = temp2;
            `SHOW_MMU_DEBUG
            read_address = mmu_address_to_search % MMU_PAGE_SIZE + mmu_search_position * MMU_PAGE_SIZE;
            stage = stage_after_mmu;
          end else begin
            mmu_chain_read_address = mmu_search_position;
            mmu_search_position = mmu_chain_read_value;
          end
        end
        STAGE_GET_1_BYTE: begin
          if (pc <= 59) begin
            rst_can_be_done = 1;
            $display($time, "read ready ", read_address, "=", read_value);
            uart_buffer[uart_buffer_available++] = "a";
            $display($time, "a");
            instruction1 = read_value;
            mmu_address_to_search = pc + 1;
            stage = STAGE_CHECK_MMU_ADDRESS;
            stage_after_mmu = STAGE_GET_2_BYTE;
            pc = pc + 1;
          end
        end
        STAGE_GET_2_BYTE: begin
          $display($time, "read ready2 ", read_address, "=", read_value);
          uart_buffer[uart_buffer_available++] = "b";
          $display($time, " decoding ", (pc - 1), ":", instruction1, " (", instruction1_1, ":",
                   instruction1_2, ") ", read_value);
          if (instruction1_1 == 0) begin
            uart_buffer[uart_buffer_available++] = "0";
          end
          if (instruction1_1 == 1) begin
            uart_buffer[uart_buffer_available++] = "1";
          end
          if (instruction1_1 == 2) begin
            uart_buffer[uart_buffer_available++] = "2";
          end
          if (instruction1_1 == 3) begin
            uart_buffer[uart_buffer_available++] = "3";
          end
          if (instruction1_1 == 4) begin
            uart_buffer[uart_buffer_available++] = "4";
          end
          if (instruction1_1 == 5) begin
            uart_buffer[uart_buffer_available++] = "5";
          end
          if (instruction1_1 == 6) begin
            uart_buffer[uart_buffer_available++] = "6";
          end
          if (instruction1_1 == 7) begin
            uart_buffer[uart_buffer_available++] = "7";
          end
          if (instruction1_1 == 8) begin
            uart_buffer[uart_buffer_available++] = "8";
          end
          if (instruction1_1 == 9) begin
            uart_buffer[uart_buffer_available++] = "9";
          end
          if (instruction1_1 == 10) begin
            uart_buffer[uart_buffer_available++] = "A";
          end
          if (instruction1_1 == 11) begin
            uart_buffer[uart_buffer_available++] = "B";
          end
          if (instruction1_1 == 12) begin
            uart_buffer[uart_buffer_available++] = "C";
          end
          if (instruction1_1 == 13) begin
            uart_buffer[uart_buffer_available++] = "D";
          end
          if (instruction1_1 == 14) begin
            uart_buffer[uart_buffer_available++] = "E";
          end
          if (instruction1_1 == 15) begin
            uart_buffer[uart_buffer_available++] = "F";
          end
          if (instruction1_1 == 16) begin
            uart_buffer[uart_buffer_available++] = "G";
          end
          if (instruction1_1 > 16) begin
            uart_buffer[uart_buffer_available++] = "k";
          end
          if (instruction1_2 == 0) begin
            uart_buffer[uart_buffer_available++] = "0";
          end
          if (instruction1_2 == 1) begin
            uart_buffer[uart_buffer_available++] = "1";
          end
          if (instruction1_2 == 2) begin
            uart_buffer[uart_buffer_available++] = "2";
          end
          if (instruction1_2 == 3) begin
            uart_buffer[uart_buffer_available++] = "3";
          end
          if (instruction1_2 == 4) begin
            uart_buffer[uart_buffer_available++] = "4";
          end
          if (instruction1_2 == 5) begin
            uart_buffer[uart_buffer_available++] = "5";
          end
          if (instruction1_2 == 6) begin
            uart_buffer[uart_buffer_available++] = "6";
          end
          if (instruction1_2 == 7) begin
            uart_buffer[uart_buffer_available++] = "7";
          end
          if (instruction1_2 == 8) begin
            uart_buffer[uart_buffer_available++] = "8";
          end
          if (instruction1_2 == 9) begin
            uart_buffer[uart_buffer_available++] = "9";
          end
          if (instruction1_2 == 10) begin
            uart_buffer[uart_buffer_available++] = "A";
          end
          if (instruction1_2 == 11) begin
            uart_buffer[uart_buffer_available++] = "B";
          end
          if (instruction1_2 == 12) begin
            uart_buffer[uart_buffer_available++] = "C";
          end
          if (instruction1_2 == 13) begin
            uart_buffer[uart_buffer_available++] = "D";
          end
          if (instruction1_2 == 14) begin
            uart_buffer[uart_buffer_available++] = "E";
          end
          if (instruction1_2 == 15) begin
            uart_buffer[uart_buffer_available++] = "F";
          end
          if (instruction1_2 == 16) begin
            uart_buffer[uart_buffer_available++] = "G";
          end
          if (instruction1_2 > 16) begin
            uart_buffer[uart_buffer_available++] = "l";
          end

          case (instruction1_1)
            OPCODE_JMP: begin
              $display(" opcode = jmp to ", read_value);  //DEBUG info         
              uart_buffer[uart_buffer_available++] = "1";
              $display($time, "1");
            end
            OPCODE_RAM2REG: begin
              $display(" opcode = ram2reg value from address ", read_value,
                       " to reg ",  //DEBUG info
                       instruction1_1);  //DEBUG info
              uart_buffer[uart_buffer_available++] = "2";
              $display($time, "2");
            end
            OPCODE_REG2RAM: begin
              $display(" opcode = reg2ram save value ", registers[instruction1_2],
                       " from register ", instruction1_2, " to address ", read_value);
              uart_buffer[uart_buffer_available++] = "3";
              $display($time, "3");
            end
            OPCODE_NUM2REG: begin
              $display(" opcode = num2reg value ", read_value, " to reg ",  //DEBUG info
                       instruction1_2);  //DEBUG info
              registers[instruction1_2] = read_value;
              uart_buffer[uart_buffer_available++] = "4";
              $display($time, "4");
            end
          endcase
          mmu_address_to_search = pc + 1;
          stage = STAGE_CHECK_MMU_ADDRESS;
          stage_after_mmu = STAGE_GET_1_BYTE;
          pc = pc + 1;
        end
      endcase
      if (stage == STAGE_CHECK_MMU_ADDRESS) begin
        $display($time, "*");
        uart_buffer[uart_buffer_available++] = "*";
        mmu_address_to_search_segment = mmu_address_to_search / MMU_PAGE_SIZE;
        if (mmu_address_to_search_segment == 0) begin
          read_address = mmu_address_to_search % MMU_PAGE_SIZE + mmu_start_process_physical_segment*MMU_PAGE_SIZE;
          stage = stage_after_mmu;
        end else begin
          stage = STAGE_SEARCH1_MMU_ADDRESS;
          mmu_chain_read_address = mmu_start_process_physical_segment;
          mmu_search_position = mmu_chain_read_value;
        end
      end
    end
  end
endmodule

module small_ram (
    input [15:0] write_address,
    input [15:0] write_value,
    input [15:0] read_address,
    output reg [15:0] read_value
);

  reg [8:0] ram[0:MMU_MAX_INDEX];

  always @(read_address) begin
    read_value = ram[read_address];
  end

  always @(write_address) begin
    ram[write_address] = write_value;
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

  /*
     reg [15:0] ram[0:67];
      initial begin  //DEBUG info
        $readmemh("rom4.mem", ram);  //DEBUG info
      end  //DEBUG info
*/

  reg [15:0] ram[0:67] = '{
      16'h0110,
      16'h0220,  //next,8'hprocess,8'haddress,8'h(no,8'hMMU),8'hoverwritten,8'hby,8'hCPU
      16'h0330,
      16'h0440,
      16'h0000,
      16'h0000,  //PC,8'hfor,8'hthis,8'hprocess,8'hoverwritten,8'hby,8'hCPU
      16'h0000,
      16'h0000,
      16'h0000,
      16'h0000,  //registers,8'hused,8'h(currently,8'hignored)
      16'h0000,
      16'h0000,
      16'h0000,
      16'h0000,
      16'h0000,
      16'h0000,  //registers,8'htaken,8'h"as,8'his"
      16'h0000,
      16'h0000,
      16'h0000,
      16'h0000,
      16'h0000,
      16'h0000,
      16'h0000,
      16'h0000,
      16'h0000,
      16'h0000,
      16'h0000,
      16'h0000,
      16'h0000,
      16'h0000,
      16'h0000,
      16'h0000,
      16'h0000,
      16'h0000,
      16'h0000,
      16'h0000,
      16'h0000,
      16'h0000,
      16'h0000,
      16'h0000,
      16'h0000,
      16'h0000,
      16'h0000,
      16'h0000,
      16'h0000,
      16'h0000,
      16'h0c01,
      16'h0001,  //proc
      16'h0c01,
      16'h0002,  //proc
      16'h0402,
      16'h0003,  //num2reg
      16'h0902,
      16'h0002,  //loop,8'hwith,8'hcache:,8'hloopeqvalue
      16'h0602,
      16'h0001,  //regminusnum
      16'h0602,
      16'h0000,  //regminusnum
      16'h0201,
      16'h0001,  //after,8'hloop:,8'hram2reg
      16'h0401,
      16'h0005,  //num2reg
      16'h0301,
      16'h0046,  //reg2ram
      16'h0F00,
      16'h0002,  //int,8'h2
      16'h010E,
      16'h0030  //jmp,8'h0x30
  };

  always @(posedge clk) begin
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
//values on tx: ...1, 0 (start bit), (8 data bits), 1 (stop bit), 1... (we make some delay in the end before next seq; every bit is sent CLK_PER_BIT cycles)
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

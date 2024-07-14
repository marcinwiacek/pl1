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
  reg [5:0] write_address;
  reg [15:0] write_value;
  reg [5:0] read_address;
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

  parameter OPCODE_JMP = 1;  //255 or register num for first 16-bits of the address, 16 bit address
  parameter OPCODE_RAM2REG = 2;  //register num, 16 bit source addr //ram -> reg
  parameter OPCODE_REG2RAM = 3;  //register num, 16 bit source addr //reg -> ram
  parameter OPCODE_NUM2REG = 4;  //register num, 16 bit value //value -> reg

  parameter STAGE_AFTER_RESET = 1;
  parameter STAGE_GET_1_BYTE = 2;
  parameter STAGE_GET_2_BYTE = 3;

  reg [5:0] pc;
  reg rst_can_be_done = 1;
  reg [3:0] stage;
  reg [15:0] registers[0:31];  //64 8-bit registers * n=8 processes = 512 16-bit registers

  reg [15:0] instruction1;
  logic [7:0] instruction1_1;
  logic [7:0] instruction1_2;

  assign instruction1_1 = instruction1[15:8];
  assign instruction1_2 = instruction1[7:0];

  always @(reset, clk) begin
    if (reset && rst_can_be_done) begin
      rst_can_be_done = 0;
      $display($time, "reset");
      pc = ADDRESS_PROGRAM;
      read_address = ADDRESS_PROGRAM;
      stage = STAGE_AFTER_RESET;
      uart_buffer[0] = "S";
      $display($time, "S");
      uart_buffer_available = 1;
    end else begin
      case (stage)
        STAGE_AFTER_RESET: begin
          if (!reset) stage = STAGE_GET_1_BYTE;
        end
        STAGE_GET_1_BYTE: begin
          if (pc <= 59 && clk == 0) begin
            rst_can_be_done = 1;
            $display($time, "read ready ", read_address, "=", read_value);
            uart_buffer[uart_buffer_available] = "a";
            $display($time, "a");
            uart_buffer_available = uart_buffer_available + 1;
            instruction1 = read_value;
            read_address = pc + 1;
            pc = pc + 1;
            stage = STAGE_GET_2_BYTE;
          end
        end
        STAGE_GET_2_BYTE: begin
          if (clk == 0) begin
            $display($time, "read ready2 ", read_address, "=", read_value);
            uart_buffer[uart_buffer_available] = "b";
            uart_buffer_available = uart_buffer_available + 1;
            $display($time, " decoding ", (pc - 1), ":", instruction1, " (", instruction1_1, ":",
                     instruction1_2, ") ", read_value);
            if (reset_uart_buffer_available) begin
              uart_buffer_available = 0;
            end else if (!uart_buffer_full) begin
              if (pc - 1 == 46 && instruction1 == 3073 && read_value == 1) begin
                uart_buffer[uart_buffer_available] = "M";
                $display($time, "M");
              end else if (pc - 1 == 48 && instruction1 == 3073 && read_value == 2) begin
                uart_buffer[uart_buffer_available] = "A";
                $display($time, "A");
              end else if (pc - 1 == 50 && instruction1 == 1026) begin
                uart_buffer[uart_buffer_available] = "R";
                $display($time, "R");
              end else begin
                uart_buffer[uart_buffer_available] = "X";
                $display($time, "X");
              end
              uart_buffer_available = uart_buffer_available + 1;
            end
            case (instruction1_1)
              OPCODE_JMP: begin
                $display(" opcode = jmp to ", read_value);  //DEBUG info         
                uart_buffer[uart_buffer_available] = "1";
                uart_buffer_available = uart_buffer_available + 1;
                $display($time, "1");
              end
              OPCODE_RAM2REG: begin
                $display(" opcode = ram2reg value from address ", read_value,
                         " to reg ",  //DEBUG info
                         instruction1_1);  //DEBUG info
                uart_buffer[uart_buffer_available] = "2";
                uart_buffer_available = uart_buffer_available + 1;
                $display($time, "2");
              end
              OPCODE_REG2RAM: begin
                $display(" opcode = reg2ram save value ", registers[instruction1_2],
                         " from register ", instruction1_2, " to address ", read_value);
                uart_buffer[uart_buffer_available] = "3";
                uart_buffer_available = uart_buffer_available + 1;
                $display($time, "3");
              end
              OPCODE_NUM2REG: begin
                $display(" opcode = num2reg value ", read_value, " to reg ",  //DEBUG info
                         instruction1_2);  //DEBUG info
                registers[instruction1_2] = read_value;
                uart_buffer[uart_buffer_available] = "4";
                uart_buffer_available = uart_buffer_available + 1;
                $display($time, "4");
              end
            endcase
            read_address = pc + 1;
            pc = pc + 1;
            stage = STAGE_GET_1_BYTE;
          end
        end
      endcase
    end
  end
endmodule

module single_ram (
    input clk,
    input write_enabled,
    input [5:0] write_address,
    input [15:0] write_value,
    input [5:0] read_address,
    output reg [15:0] read_value
);

  //   reg [15:0] ram[0:67];
  //    initial begin  //DEBUG info
  //      $readmemh("rom4.mem", ram);  //DEBUG info
  //    end  //DEBUG info

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

module mmu (
    input rst,

    input exec,
    input [5:0] address_to_decode,
    output reg [5:0] address_decoded,

    input [5:0] address_to_decode2,
    output reg [5:0] address_decoded2
);

  integer i;

  reg [11:0] mmu_chain_memory[0:4095];  //next physical segment index for process (last entry = the same entry)
  reg [11:0] mmu_logical_pages_memory[0:4095];  //logical process page assigned to physical segment (0 means empty page, we setup value > 0 for first page with logical index 0 and ignore it)
  reg [11:0] mmu_start_process_physical_segment;  //needs to be updated on process switch

  reg mmu_ready = 0;

  always @(posedge rst) begin
    mmu_ready = 0;
    mmu_start_process_physical_segment = 0;

    mmu_chain_memory[0] = 0;
    for (i = 0; i < 4096; i = i + 1) begin
      //value 0 means, that it's empty. in every process on first entry we setup something != 0 and ignore it
      // (first process page is always from segment 0)
      mmu_logical_pages_memory[i] = 0;
    end
    mmu_logical_pages_memory[0] = 1;

    //    some more complicated config used for testing //DEBUG info
    //    mmu_chain_memory[0] <= 1;  //DEBUG info
    //    mmu_chain_memory[1] <= 1;  //DEBUG info
    //    mmu_logical_pages_memory[1] <= 1;  //DEBUG info

    //some more complicated config used for testing //DEBUG info
    mmu_chain_memory[0] = 5;  //DEBUG info
    mmu_chain_memory[5] = 2;  //DEBUG info
    mmu_chain_memory[2] = 1;  //DEBUG info
    mmu_chain_memory[1] = 1;  //DEBUG info
    mmu_logical_pages_memory[5] = 3;  //DEBUG info
    mmu_logical_pages_memory[2] = 2;  //DEBUG info
    mmu_logical_pages_memory[1] = 1;  //DEBUG info

    //some more complicated config used for testing //DEBUG info
    //mmu_chain_memory[0] <= 1;  //DEBUG info
    //mmu_chain_memory[1] <= 1;  //DEBUG info
    //mmu_logical_pages_memory[1] <= 1;  //DEBUG info
    mmu_ready = 1;
    $display($time, "mmu_reset");
  end

  mmu_search mmu_search (
      .mmu_ready(mmu_ready),
      .exec(exec),
      .address_to_decode(address_to_decode),
      .address_decoded(address_decoded),
      .mmu_chain_memory(mmu_chain_memory),
      .mmu_logical_pages_memory(mmu_logical_pages_memory),
      .mmu_start_process_physical_segment(mmu_start_process_physical_segment)
  );

  /*  mmu_search mmu_search2 (
      .address_to_decode(address_to_decode2),
      .address_decoded(address_decoded2),
      .mmu_chain_memory(mmu_chain_memory),
      .mmu_logical_pages_memory(mmu_logical_pages_memory),
      .mmu_start_process_physical_segment(mmu_start_process_physical_segment)
  );*/

endmodule

module mmu_search (
    input exec,
    input mmu_ready,
    input [5:0] address_to_decode,
    output reg [5:0] address_decoded,
    input [11:0] mmu_chain_memory[0:4095],
    input [11:0] mmu_logical_pages_memory[0:4095],
    input [11:0] mmu_start_process_physical_segment
);

  reg [11:0] mmu_logical_seg;
  reg [11:0] mmu_old_physical_segment;
  reg [2:0] mmu_search = 0;

  integer i;  //DEBUG info

  always @(address_to_decode, mmu_old_physical_segment, exec) begin
    if (mmu_search == 1) begin
      $display($time, " mmu search  ", address_to_decode, " logical seg ",
               address_to_decode / MMU_PAGE_SIZE, " ", mmu_old_physical_segment);  //DEBUG info
      if (mmu_logical_seg == mmu_logical_pages_memory[mmu_old_physical_segment]) begin
        $display($time, " mmu search end");  //DEBUG info
        address_decoded <= mmu_old_physical_segment * MMU_PAGE_SIZE + address_to_decode % MMU_PAGE_SIZE;
        mmu_search <= 0;
      end else if (mmu_old_physical_segment == mmu_chain_memory[mmu_old_physical_segment]) begin
        $display($time, " error");  //DEBUG info
      end else begin
        mmu_old_physical_segment <= mmu_chain_memory[mmu_old_physical_segment];
      end
    end else if (mmu_search == 0 && exec == 1 && mmu_ready == 1) begin
      $display($time, " mmu search start from ", address_to_decode, " start segment ",
               mmu_start_process_physical_segment, " logical seg ",
               address_to_decode / MMU_PAGE_SIZE, " ", mmu_old_physical_segment);  //DEBUG info
      `SHOW_MMU_DEBUG
      mmu_logical_seg <= address_to_decode / MMU_PAGE_SIZE;
      if (address_to_decode / MMU_PAGE_SIZE == 0) begin
        address_decoded <= mmu_start_process_physical_segment * MMU_PAGE_SIZE + address_to_decode % MMU_PAGE_SIZE;
        $display($time, " mmu search end");  //DEBUG info
        mmu_search <= 0;
      end else begin
        mmu_search <= 1;
        mmu_old_physical_segment <= mmu_chain_memory[mmu_start_process_physical_segment];
      end
    end
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

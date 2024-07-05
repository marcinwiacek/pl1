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

module x_async (
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

  wire [5:0] read_address, read_read_address, read_address_executor, read_read_address_executor, save_address, save_save_address;
  wire [15:0] read_value, read_value_executor, save_value;
  wire read_address_req, read_address_ack;

  ram ram (
      .clk(clk),
      .rst(reset),

      .read_address_req(read_address_req),
      .read_address(read_address),
      .read_value(read_value),
      .read_address_ack(read_address_ack),

      .read_address_executor(read_address_executor),
      .read_read_address_executor(read_read_address_executor),
      .read_value_executor(read_value_executor),

      .save_value(save_value),
      .save_address(save_address),
      .save_save_address(save_save_address)
  );

  wire executor_exec, executor_exec_confirmed, executor_ready;
  wire [5:0] executor_pc, executor_pc_received;
  wire [15:0] executor_instruction1, executor_instruction2, executor_instruction1_received, executor_instruction2_received;

  stage1_fetcher fetch (
      .clk(clk),
      .rst(reset),
      .tx (uart_rx_out),

      .executor_exec(executor_exec),
      .executor_exec_confirmed(executor_exec_confirmed),
      .executor_pc(executor_pc),
      .executor_instruction1(executor_instruction1),
      .executor_instruction2(executor_instruction2),

      .executor_pc_received(executor_pc_received),
      .executor_instruction1_received(executor_instruction1_received),
      .executor_instruction2_received(executor_instruction2_received),

      .executor_ready(executor_ready),

      .read_address(read_address),
      .read_address_req(read_address_req),
      .read_address_ack(read_address_ack),
      .read_value(read_value)
  );

/*
  stage2_executor execute (
      .clk(clk),
      .rst(reset),
      //.tx (uart_rx_out),

      .exec(executor_exec),
      .pc_received(executor_pc_received),
      .instruction1_received(executor_instruction1_received),
      .instruction2_received(executor_instruction2_received),

      .pc(executor_pc),
      .instruction1(executor_instruction1),
      .instruction2(executor_instruction2),
      .ready(executor_ready),

      .read_address(read_address_executor),
      .read_read_address(read_read_address_executor),
      .read_value(read_value_executor),
      .save_value(save_value),
      .save_address(save_address),
      .save_save_address(save_save_address)
  );
*/

endmodule

module stage1_fetcher (
    input rst,
    clk,
    output logic tx,

    output logic executor_exec,
    input executor_exec_confirmed,
    output logic [5:0] executor_pc,
    input [5:0] executor_pc_received,

    output logic [15:0] executor_instruction1,
    executor_instruction2,
    input [15:0] executor_instruction1_received,
    executor_instruction2_received,

    input executor_ready,

    output logic        read_address_req,
    output logic [ 5:0] read_address,
    input               read_address_ack,
    input        [15:0] read_value
);

  reg [5:0] pc=0;
  reg rst_can_be_done = 1;
 // (* ASYNC_REG = "TRUE" *) 
 reg [5:0] fetcher_stage=0;
  logic [7:0] uart_buffer[0:128];
 // (* ASYNC_REG = "TRUE" *) 
 logic [6:0] uart_buffer_available=0;
  
  wire reset_uart_buffer_available;
  wire uart_buffer_full;
  
  uartx_tx_with_buffer uartx_tx_with_buffer (
      .clk(clk),
      .uart_buffer(uart_buffer),
      .uart_buffer_available(uart_buffer_available),
      .reset_uart_buffer_available(reset_uart_buffer_available),
      .uart_buffer_full(uart_buffer_full),
      .tx(tx)
  );

logic [5:0] cntr=0;
    
    
    logic [6:0] uart_buffer_available0=0;
    
    always @(uart_buffer_available0) begin
      uart_buffer_available = uart_buffer_available0;
    end

    always @(rst, fetcher_stage, uart_buffer_available) begin
      cntr = uart_buffer_available0 == uart_buffer_available?(cntr==10?1:cntr+1):cntr;
    end
    
   always @(rst, cntr) begin
  
    $display($time, "entering main ",fetcher_stage ," ",rst," ", read_address_ack," ",pc);
    
    if (rst && rst_can_be_done) begin
    
          uart_buffer[uart_buffer_available0] <= "A";
    uart_buffer_available0<=uart_buffer_available0+1;
      
      executor_instruction1 <= 0;
      executor_instruction2 <= 0;
      executor_pc <= 0;
     

      $display($time, "stage 1 reset");
      pc <= ADDRESS_PROGRAM;
     
      read_address <= ADDRESS_PROGRAM;
      
        rst_can_be_done <= 0;
          fetcher_stage <= 1;   
    end  else  if (!rst && !rst_can_be_done && fetcher_stage == 1 && pc <49) begin
       
      $display($time, "one");

       pc <= pc+1;

          uart_buffer[uart_buffer_available0] <= "x";
    uart_buffer_available0<=uart_buffer_available0+1;
       fetcher_stage  <= 2;       
    
     end  else if (fetcher_stage  == 2) begin

       $display($time, "two");            

    //      uart_buffer[uart_buffer_available0] <= "y";
 //   uart_buffer_available0<=uart_buffer_available0+1;

       fetcher_stage  <= 1;       
       
     end
  end

endmodule

/*
parameter OPCODE_JMP = 1;  //255 or register num for first 16-bits of the address, 16 bit address
parameter OPCODE_RAM2REG = 2;  //register num, 16 bit source addr //ram -> reg
parameter OPCODE_REG2RAM = 3;  //register num, 16 bit source addr //reg -> ram
parameter OPCODE_NUM2REG = 4;  //register num, 16 bit value //value -> reg

module stage2_executor (
    input clk,
    input rst,
    // output logic tx,

    input exec,
    input [5:0] pc,
    input [15:0] instruction1,
    instruction2,

    output logic [ 5:0] pc_received,
    output logic [15:0] instruction1_received,
    instruction2_received,

    output logic ready,

    output reg [ 5:0] read_address,
    input      [ 5:0] read_read_address,
    input      [15:0] read_value,

    output reg [ 5:0] save_address,
    input      [ 5:0] save_save_address,
    output reg [15:0] save_value
);

  assign pc_received = pc;
  assign instruction1_received = instruction1;
  assign instruction2_received = instruction2;


  reg [3:0] executor_stage;

  reg [15:0] registers[0:31];  //64 8-bit registers * n=8 processes = 512 16-bit registers
  logic [7:0] instruction1_1;
  logic [7:0] instruction1_2;

  /* reg [7:0] uart_buffer[0:128];
  reg [6:0] uart_buffer_available;
  wire reset_uart_buffer_available;
  wire uart_buffer_full;

  uartx_tx_with_buffer uartx_tx_with_buffer (
      .clk(clk),
      .uart_buffer(uart_buffer),
      .uart_buffer_available(uart_buffer_available),
      .reset_uart_buffer_available(reset_uart_buffer_available),
      .uart_buffer_full(uart_buffer_full),
      .tx(tx)
  );*/

/*
  assign instruction1_1 = instruction1[15:8];
  assign instruction1_2 = instruction1[7:0];

  reg rst_can_be_done = 1;

  always @(posedge rst, posedge exec) begin
    if (rst == 1 && rst_can_be_done) begin
      rst_can_be_done = 0;
      $display($time, " stage 2 reset ");
      ready = 1;

      //  uart_buffer[0] = "S";
      $display($time, "S");
      //  uart_buffer_available = 1;
      executor_stage = 1;
    end else if (!rst && exec == 1) begin
      ready = 0;
      rst_can_be_done = 1;
      $display($time, "a ", executor_stage, " ", instruction1, " ", instruction2, " ");

      //   uart_buffer[uart_buffer_available] = "w";
      //   uart_buffer_available = uart_buffer_available + 1;

      $display($time, "b");

      $display($time, " decoding ", pc, ":", instruction1, " (", instruction1_1, ":",
               instruction1_2, ") ", instruction2);

      //  if (reset_uart_buffer_available) begin
      //   uart_buffer_available = 0;
      //  end else if (!uart_buffer_full) begin
      /*  if (pc == 46 && instruction1 == 3073 && instruction2 == 1) begin
        uart_buffer[uart_buffer_available] = "m";
        $display($time, "M");
      end else if (pc == 48 && instruction1 == 3073 && instruction2 == 2) begin
        uart_buffer[uart_buffer_available] = "a";
        $display($time, "A");
      end else if (pc == 50 && instruction1 == 16'h0402) begin
        uart_buffer[uart_buffer_available] = "r";
        $display($time, "R");
      end else begin
        uart_buffer[uart_buffer_available] = "x";
        $display($time, "X");
      end
      uart_buffer_available = uart_buffer_available + 1;*/
      // end

/*
      if (instruction1_1 == OPCODE_JMP) begin
        $display(" opcode = jmp to ", instruction2);  //DEBUG info         
      end else if (instruction1_1 == OPCODE_RAM2REG) begin
        $display(" opcode = ram2reg value from address ", instruction2, " to reg ",  //DEBUG info
                 instruction1_1);  //DEBUG info
        //   uart_buffer[uart_buffer_available] = "2";
        //   uart_buffer_available = uart_buffer_available + 1;
        $display($time, "2");
      end else if (instruction1_1 == OPCODE_REG2RAM) begin
        $display(" opcode = reg2ram save value ", registers[instruction1_2], " from register ",
                 instruction1_2, " to address ", instruction2);
        //    uart_buffer[uart_buffer_available] = "3";
        //    uart_buffer_available = uart_buffer_available + 1;
        $display($time, "3");
      end else if (instruction1_1 == OPCODE_NUM2REG) begin
        $display(" opcode = num2reg value ", instruction2, " to reg ",  //DEBUG info
                 instruction1_2);  //DEBUG info
        registers[instruction1_2] = instruction2;
        //   uart_buffer[uart_buffer_available] = "4";
        //   uart_buffer_available = uart_buffer_available + 1;
        $display($time, "4");
      end
      if (instruction1_1 != OPCODE_REG2RAM && instruction1_1 != OPCODE_JMP) begin
        $display($time, " decoding end ");

      end
      ready = 1;
      executor_stage = 1;

    end
  end
endmodule

*/

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

module ram (
    input rst,
    input clk,
    output reg mmu_ready,

    input read_address_req,
    input [5:0] read_address,
    output logic [15:0] read_value,
    output logic read_address_ack,

    input [5:0] read_address_executor,
    output reg [5:0] read_read_address_executor,
    output reg [15:0] read_value_executor,

    input [5:0] save_address,
    output reg [5:0] save_save_address,
    input [15:0] save_value
);

  reg [5:0] address_to_decode, address_decoded, address_to_decode2, address_decoded2;

  mmu mmu (
      .rst(rst),

      .exec(read_address_exec),
      .address_to_decode(read_address),
      .address_decoded(address_decoded),

      .address_to_decode2(address_to_decode2),
      .address_decoded2  (address_decoded2)
  );

  reg write_enabled;
  reg [5:0] write_address;
  reg [15:0] write_value;
  reg [5:0] get_address;
  wire [15:0] get_value;


  single_ram single_ram (

      .write_enabled(write_enabled),
      .write_address(write_address),
      .write_value  (write_value),

      .read_address_req(read_address_req),
      .read_address(read_address),
      .read_value(read_value),
      .read_address_ack(read_address_ack)
  );

endmodule

module single_ram (
    input write_enabled,
    input [5:0] write_address,
    input [15:0] write_value,

    input read_address_req,
    input [5:0] read_address,
    output logic [15:0] read_value,
    output logic read_address_ack
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

  always @(read_address_req) begin
    $display($time, "ra req ", read_address_req);
  end

  assign read_address_ack = read_address_req;

  always @(read_address_ack) begin
    $display($time, "ra ack ", read_address_ack);
  end

  always @(posedge read_address_req) begin

    if (write_enabled) ram[write_address] = write_value;
    $display($time, "readread ", read_address, " ", ram[read_address]);
    read_value = ram[read_address];

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
      if (uart_buffer_available > 0 &&   uart_buffer_processed < uart_buffer_available) begin
        input_data <= uart_buffer[uart_buffer_processed];
        uart_buffer_state <= uart_buffer_state + 1;
        uart_buffer_processed <= uart_buffer_processed + 1;
      end else if (  uart_buffer_processed > uart_buffer_available) begin
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

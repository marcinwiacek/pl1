`timescale 1ns / 1ps

//options below are less important than options higher //DEBUG info
parameter HARDWARE_DEBUG = 0;

parameter RAM_WRITE_DEBUG = 0;  //1 enabled, 0 disabled //DEBUG info
parameter RAM_READ_DEBUG = 0;  //1 enabled, 0 disabled //DEBUG info
parameter REG_CHANGES_DEBUG = 0;  //1 enabled, 0 disabled //DEBUG info
parameter MMU_CHANGES_DEBUG = 0;  //1 enabled, 0 disabled //DEBUG info
parameter MMU_TRANSLATION_DEBUG = 0;  //1 enabled, 0 disabled //DEBUG info
parameter TASK_SWITCHER_DEBUG = 0;  //1 enabled, 0 disabled //DEBUG info
parameter TASK_SPLIT_DEBUG = 0;  //1 enabled, 0 disabled //DEBUG info
parameter OTHER_DEBUG = 0;  //1 enabled, 0 disabled //DEBUG info
parameter READ_DEBUG = 0;  //1 enabled, 0 disabled //DEBUG info
parameter STAGE_DEBUG =0;
parameter OP_DEBUG = 1;
parameter ALU_DEBUG = 0;

parameter MMU_PAGE_SIZE = 70;  //how many bytes are assigned to one memory page in MMU
parameter RAM_SIZE = 32767;
parameter MMU_MAX_INDEX = 255;  //(`RAM_SIZE+1)/`MMU_PAGE_SIZE;

/* DEBUG info */ `define HARD_DEBUG(ARG) \
/* DEBUG info */     if (reset_uart_buffer_available) uart_buffer_available = 0; \
/* DEBUG info */     uart_buffer[uart_buffer_available++] = ARG; \
/* DEBUG info */     if (HARDWARE_DEBUG == 1)  $write(ARG);

// verilog_format:off
/* DEBUG info */ `define HARD_DEBUG2(ARG) \
/* DEBUG info */   //  if (reset_uart_buffer_available) uart_buffer_available = 0; \
/* DEBUG info */     uart_buffer[uart_buffer_available++] = ARG/16>10? ARG/16 + 65 - 10:ARG/16+ 48; \
/* DEBUG info */     uart_buffer[uart_buffer_available++] = ARG%16>10? ARG%16 + 65 - 10:ARG%16+ 48; \
/* DEBUG info */     if (HARDWARE_DEBUG == 1) $write("%c",ARG/16>10? ARG/16 + 65 - 10:ARG/16+ 48,"%c",ARG%16>10? ARG%16 + 65 - 10:ARG%16+ 48);
// verilog_format:on

/* DEBUG info */ `define SHOW_REG_DEBUG(ARG, INFO, ARG2, ARG3) \
/* DEBUG info */     if (ARG == 1) begin \
/* DEBUG info */       $write($time, INFO); \
/* DEBUG info */       for (i = 0; i <= 10; i = i + 1) begin \
/* DEBUG info */         $write($sformatf("%02x ", (i==ARG2?ARG3:registers[process_index][i]))); \
/* DEBUG info */       end \
/* DEBUG info */       $display(""); \
/* DEBUG info */     end

/* DEBUG info */  `define SHOW_MMU_DEBUG \
/* DEBUG info */     if (MMU_CHANGES_DEBUG == 1 && !HARDWARE_DEBUG) begin \
/* DEBUG info */       $write($time, " mmu "); \
/* DEBUG info */       for (i = 0; i <= 10; i = i + 1) begin \
/* DEBUG info */         if (mmu_start_process_physical_segment == i) $write("s"); \
/* DEBUG info */         if (/* 0,0 on position 0 can be used in theory */ mmu_chain_memory[i] == 0 && mmu_logical_pages_memory[i] == 0) begin \
/* DEBUG info */            $write("f"); \
/* DEBUG info */         end else if (mmu_chain_memory[i] == i) begin \
/* DEBUG info */           $write("e"); \
/* DEBUG info */         end \
/* DEBUG info */         $write($sformatf("%02x-%02x ", mmu_chain_memory[i], mmu_logical_pages_memory[i])); \
/* DEBUG info */       end \
/* DEBUG info */       $display(""); \
/* DEBUG info */     end

/* DEBUG info */  `define SHOW_MMU2(ARG) \
/* DEBUG info */     if (MMU_CHANGES_DEBUG == 1 && !HARDWARE_DEBUG) begin \
/* DEBUG info */       $write($time, " mmu ",ARG," "); \
/* DEBUG info */       for (i = 0; i <= 10; i = i + 1) begin \
/* DEBUG info */         $write($sformatf("%02x ", ram[i])); \
/* DEBUG info */       end \
/* DEBUG info */       $display(""); \
/* DEBUG info */     end


/* DEBUG info */  `define SHOW_TASK_INFO(ARG) \
/* DEBUG info */     if (TASK_SWITCHER_DEBUG == 1 && !HARDWARE_DEBUG) begin \
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
    output bit [15:0] c
);

  bit unsigned [15:0] aa, bb, tmp1, tmp2, tmp3, tmp4;

  assign tmp1 = aa + bb;
  assign c    = tmp4;

  always @(posedge clk) begin
    aa   <= a;
    bb   <= b;
    tmp2 <= tmp1;
    tmp3 <= tmp2;
    tmp4 <= tmp3;
  end
endmodule

(* use_dsp = "yes" *) module minus (
    input clk,
    input [15:0] a,
    input [15:0] b,
    output bit [15:0] c
);

  bit unsigned [15:0] aa, bb, tmp1, tmp2, tmp3, tmp4;

  assign tmp1 = aa - bb;
  assign c    = tmp4;

  always @(posedge clk) begin
    aa   <= a;
    bb   <= b;
    tmp2 <= tmp1;
    tmp3 <= tmp2;
    tmp4 <= tmp3;
  end
endmodule

(* use_dsp = "yes" *) module mul (
    input clk,
    input unsigned [15:0] a,
    input unsigned [15:0] b,
    output bit unsigned [15:0] c
);

  bit unsigned [15:0] aa, bb, tmp1, tmp2, tmp3, tmp4;

  assign tmp1 = aa * bb;
  assign c    = tmp4;

  always @(posedge clk) begin
    aa   <= a;
    bb   <= b;
    tmp2 <= tmp1;
    tmp3 <= tmp2;
    tmp4 <= tmp3;
  end
endmodule

(* use_dsp = "yes" *) module div (
    input clk,
    input unsigned [15:0] a,
    input unsigned [15:0] b,
    output bit unsigned [15:0] c
);

  bit unsigned [15:0] aa, bb, tmp1, tmp2, tmp3, tmp4;

  assign tmp1 = aa / bb;
  assign c    = tmp4;

  always @(posedge clk) begin
    aa   <= a;
    bb   <= b;
    tmp2 <= tmp1;
    tmp3 <= tmp2;
    tmp4 <= tmp3;
  end
endmodule

//chain memory
module mmulutram (
    input clk,
    input [15:0] read_addr,
    output bit [8:0] read_value,
    input [15:0] read_addr2,
    output bit [8:0] read_value2,
    input write_enable,
    input [15:0] write_addr,
    input [8:0] write_value
);

  //(* ram_style = "distributed" *) 
  bit [8:0] ram[0:MMU_MAX_INDEX];

  integer i;

  initial begin
    ram = '{default: 0};

    ram[0] = 1;  //DEBUG info
    ram[1] = 2;  //DEBUG info
    ram[2] = 3;  //DEBUG info
    ram[3] = 3;  //DEBUG info
    //second process
    ram[4] = 5;  //DEBUG info
    ram[5] = 6;  //DEBUG info
    ram[6] = 7;  //DEBUG info
    ram[7] = 7;  //DEBUG info
    `SHOW_MMU2("chain")
    //$display($time, " rst memory mmu");
  end

  always @(negedge clk) begin
    if (write_enable) begin
      ram[write_addr] <= write_value;
      // $display($time, " chain write ", write_addr, "=", write_value);
      `SHOW_MMU2("chain")
    end
    read_value  <= ram[read_addr];
    read_value2 <= ram[read_addr2];
  end
endmodule

//logical pages
module mmulutram2 (
    input clk,
    input [15:0] read_addr,
    output bit [8:0] read_value,
    input [15:0] read_addr2,
    output bit [8:0] read_value2,
    input write_enable,
    input [15:0] write_addr,
    input [8:0] write_value
);

  //(* ram_style = "distributed" *) 
  bit [8:0] ram[0:MMU_MAX_INDEX];

  integer i;

  initial begin
    ram = '{default: 0};

    ram[0] = 0;  //DEBUG info
    ram[1] = 1;  //DEBUG info
    ram[2] = 2;  //DEBUG info
    ram[3] = 3;  //DEBUG info
    //second process
    ram[4] = 0;  //DEBUG info
    ram[5] = 1;  //DEBUG info
    ram[6] = 2;  //DEBUG info
    ram[7] = 3;  //DEBUG info
    `SHOW_MMU2("logical")
    //$display($time, " rst memory mmu");
  end

  always @(negedge clk) begin
    if (write_enable) begin
      ram[write_addr] <= write_value;
      // $display($time, " logical write ", write_addr, "=", write_value);
      `SHOW_MMU2("logical")
    end
    read_value  <= ram[read_addr];
    read_value2 <= ram[read_addr2];
  end
endmodule

module mmu (
    input clk,
    input reset,
    input bit search_mmu_address,
    input bit set_mmu_start_process_physical_segment,
    input bit reset_mmu_start_process_physical_segment,
    input bit mmu_delete_process,
    input bit mmu_split_process,
    input bit [15:0] mmu_address_a,
    mmu_address_b,
    output bit [15:0] mmu_address_c,
    output bit mmu_action_ready
);

  // special cases:
  // mmu_chain_memory == own physical segment (element is pointing to itself) -> end segment
  // mmu_logical_pages_memory == 0 && mmu_chain_memory == 0 -> free segment for all physical segments != 0 (see note in next line)
  // 0,0 can be assigned to process starting from physical segment 0 -> we handle it with mmu_first_possible_free_physical_segment 
  //bit [8:0] mmu_chain_memory[0:MMU_MAX_INDEX];  //next physical segment index for process
  //bit [8:0] mmu_logical_pages_memory[0:MMU_MAX_INDEX];  //logical process page assigned to physical segment

  bit [8:0] mmu_first_possible_free_physical_segment;  //updated on create / delete (when == 0, we assume it must be free; in other cases it's just start index for loop)
  bit [8:0] mmu_start_process_physical_segment;  //updated on process switch and MMU sorting
  bit [8:0] mmu_start_process_physical_segment_zero;  //updated on process switch

  bit [8:0] mmu_address_to_search_segment;
  bit [8:0] mmu_search_position, mmu_prev_search_position, mmu_new_search_position;

  bit [7:0] stage;
  bit rst_can_be_done = 1;
  bit [8:0] temp, temp2;

  integer i;

  bit [15:0] mmu_chain_read_addr;
  wire [8:0] mmu_chain_read_value;
  bit [15:0] mmu_chain_read_addr2;
  wire [8:0] mmu_chain_read_value2;
  bit mmu_chain_write_enable = 0;
  bit [15:0] mmu_chain_write_addr;
  bit [8:0] mmu_chain_write_value;

  mmulutram mmu_chain_memory (
      .clk(clk),
      .read_addr(mmu_chain_read_addr),
      .read_value(mmu_chain_read_value),
      .read_addr2(mmu_chain_read_addr2),
      .read_value2(mmu_chain_read_value2),
      .write_enable(mmu_chain_write_enable),
      .write_addr(mmu_chain_write_addr),
      .write_value(mmu_chain_write_value)
  );

  bit [15:0] mmu_logical_read_addr;
  wire [8:0] mmu_logical_read_value;
  bit [15:0] mmu_logical_read_addr2;
  wire [8:0] mmu_logical_read_value2;
  bit mmu_logical_write_enable = 0;
  bit [15:0] mmu_logical_write_addr;
  bit [8:0] mmu_logical_write_value;

  mmulutram2 mmu_logical_pages_memory (
      .clk(clk),
      .read_addr(mmu_logical_read_addr),
      .read_value(mmu_logical_read_value),
      .read_addr2(mmu_logical_read_addr2),
      .read_value2(mmu_logical_read_value2),
      .write_enable(mmu_logical_write_enable),
      .write_addr(mmu_logical_write_addr),
      .write_value(mmu_logical_write_value)
  );

  parameter MMU_IDLE = 0;
  parameter MMU_SEARCH = 1;
  parameter MMU_INIT = 2;
  parameter MMU_DELETE = 3;
  parameter MMU_SPLIT = 4;
  parameter MMU_SPLIT2 = 5;
  parameter MMU_DELETE2 = 6;
  parameter MMU_INIT2 = 7;
  parameter MMU_INIT3 = 8;
  parameter MMU_INIT4 = 9;
  parameter MMU_SEARCH2 = 10;
  parameter MMU_SET_PROCESS_DATA = 11;
  parameter MMU_SET_PROCESS_DATA2 = 12;
  parameter MMU_SPLIT3 = 14;
  parameter MMU_SPLIT4 = 15;

  always @(posedge clk) begin
    //$display($time, " mmu stage ", stage);
    if (reset == 1 && rst_can_be_done == 1) begin
      rst_can_be_done = 0;
      if (OTHER_DEBUG && !HARDWARE_DEBUG) $display($time, " reset");
      mmu_chain_write_enable = 0;
      mmu_logical_write_enable = 0;
      stage = MMU_INIT;
    end else if (stage == MMU_IDLE) begin
      // $display($time, " idle");
      mmu_chain_write_enable = 0;
      mmu_logical_write_enable = 0;
      mmu_action_ready = 0;
      rst_can_be_done = 1;
      if (search_mmu_address) begin
        mmu_address_to_search_segment = mmu_address_a / MMU_PAGE_SIZE;
        if (MMU_TRANSLATION_DEBUG && !HARDWARE_DEBUG)
          $display(
              $time, " mmu, address ", mmu_address_a, " segment ", mmu_address_to_search_segment
          );
        mmu_search_position = mmu_start_process_physical_segment;
        mmu_chain_read_addr = mmu_start_process_physical_segment;
        mmu_logical_read_addr = mmu_start_process_physical_segment;
        stage = MMU_SEARCH;
      end else if (set_mmu_start_process_physical_segment && reset_mmu_start_process_physical_segment) begin
    //  $display(
     //         $time, " switching mmu with reset"
      //    );
          
        /* first prepare mmu before task switching - start point should point to segment 0 */
        mmu_chain_read_addr = mmu_start_process_physical_segment_zero;
        mmu_chain_read_addr2 = mmu_start_process_physical_segment;
        stage = MMU_SET_PROCESS_DATA;
      end else if (set_mmu_start_process_physical_segment) begin
   //   $display(
    //          $time, " switching mmu without reset"
    //      );
        mmu_start_process_physical_segment = mmu_address_a / MMU_PAGE_SIZE;
        mmu_start_process_physical_segment_zero = mmu_start_process_physical_segment;
        mmu_action_ready = 1;
      end else if (mmu_delete_process) begin
        mmu_search_position = mmu_start_process_physical_segment;
        mmu_chain_read_addr = mmu_start_process_physical_segment;
        stage = MMU_DELETE;
      end else if (mmu_split_process) begin
        //  $display($time, " split start point ", mmu_start_process_physical_segment);
        mmu_search_position = mmu_start_process_physical_segment;
        mmu_chain_read_addr = mmu_start_process_physical_segment;
        mmu_logical_read_addr = mmu_start_process_physical_segment;
        mmu_prev_search_position = mmu_start_process_physical_segment;
        mmu_new_search_position = 0;
        stage = MMU_SPLIT;
      end
    end else if (stage == MMU_SEARCH) begin
      if (mmu_logical_read_value == mmu_address_to_search_segment) begin
        if (MMU_TRANSLATION_DEBUG && !HARDWARE_DEBUG)
          $display($time, " physical segment in position ", mmu_search_position);
        mmu_address_c = mmu_address_a % MMU_PAGE_SIZE + mmu_search_position * MMU_PAGE_SIZE;
        //move found address to the beginning to speed up search in the future       
        if (mmu_start_process_physical_segment != mmu_search_position) begin
          mmu_chain_write_addr = mmu_prev_search_position;
          mmu_chain_write_value = mmu_chain_read_value == mmu_search_position? mmu_prev_search_position:mmu_chain_read_value;
          mmu_chain_write_enable = 1;
          stage = MMU_SEARCH2;
        end else begin
          stage = MMU_IDLE;
          mmu_action_ready = 1;
        end
        //end else if (mmu_chain_memory[mmu_search_position] == mmu_search_position) begin
        //element pointing to itself
        //needs to allocate new segment
      end else begin
        mmu_prev_search_position = mmu_search_position;
        mmu_search_position = mmu_chain_read_value;
        mmu_chain_read_addr = mmu_chain_read_value;
        mmu_logical_read_addr = mmu_chain_read_value;
      end
    end else if (stage == MMU_SEARCH2) begin
      mmu_chain_write_addr = mmu_search_position;
      mmu_chain_write_value = mmu_start_process_physical_segment;
      mmu_start_process_physical_segment = mmu_search_position;
      stage = MMU_IDLE;
      mmu_action_ready = 1;
    end else if (stage == MMU_SET_PROCESS_DATA) begin
      mmu_chain_write_addr = mmu_start_process_physical_segment_zero;
      mmu_chain_write_value = mmu_chain_read_value2;
      mmu_chain_write_enable = 1;
      stage = MMU_SET_PROCESS_DATA2;
    end else if (stage == MMU_SET_PROCESS_DATA2) begin
      mmu_chain_write_addr = mmu_start_process_physical_segment;
      mmu_chain_write_value = mmu_chain_read_value;
      mmu_start_process_physical_segment = mmu_address_a / MMU_PAGE_SIZE;
      mmu_start_process_physical_segment_zero = mmu_start_process_physical_segment;
      mmu_action_ready = 1;
      $display($time, " mmu end ");
      stage = MMU_IDLE;
    end else if (stage == MMU_DELETE) begin
      mmu_first_possible_free_physical_segment = mmu_first_possible_free_physical_segment > mmu_search_position ? 
           mmu_search_position: mmu_first_possible_free_physical_segment;
      mmu_logical_write_addr = mmu_search_position;
      mmu_logical_write_value = 0;
      mmu_logical_write_enable = 1;
      mmu_chain_write_addr = mmu_search_position;
      mmu_chain_write_value = 0;
      mmu_chain_write_enable = 1;
      if (mmu_chain_read_value == mmu_search_position) begin
        mmu_action_ready = 1;
        stage = MMU_IDLE;
      end else begin
        mmu_search_position = mmu_chain_read_value;
        mmu_chain_read_addr = mmu_chain_read_value;
      end
    end else if (stage == MMU_SPLIT) begin
      //  $display($time, " ", mmu_search_position, " ", mmu_logical_read_value, " ", mmu_address_a,
      //          " ", mmu_address_b);
      if (mmu_logical_read_value >= mmu_address_a && mmu_logical_read_value <= mmu_address_b) begin
        //update old process chain
        mmu_chain_write_addr = mmu_prev_search_position;
        mmu_chain_write_value = mmu_chain_read_value;
        mmu_chain_write_enable = 1;
        //update new process chain
        mmu_logical_write_addr = mmu_search_position;
        mmu_logical_write_value = mmu_logical_read_value - mmu_address_a;
        mmu_logical_write_enable = 1;
        mmu_new_search_position = mmu_search_position;
        if (mmu_logical_read_value == mmu_address_a) begin
          mmu_address_c = mmu_search_position;
        end else begin
          stage = MMU_SPLIT2;
        end
      end else begin
        mmu_chain_write_enable   = 0;
        mmu_logical_write_enable = 0;
        mmu_prev_search_position = mmu_search_position;
      end
      if (mmu_chain_read_value == mmu_search_position) begin
        //close both chains     
        stage = MMU_SPLIT3;
      end else begin
        mmu_search_position   = mmu_chain_read_value;
        mmu_chain_read_addr   = mmu_chain_read_value;
        mmu_logical_read_addr = mmu_chain_read_value;
      end
    end else if (stage == MMU_SPLIT2) begin
      mmu_logical_write_enable = 0;
      //update new process chain
      mmu_chain_write_addr = mmu_new_search_position;
      mmu_chain_write_value = mmu_search_position;
      mmu_new_search_position = mmu_search_position;
      if (mmu_chain_read_value == mmu_search_position) begin
        //close both chains     
        stage = MMU_SPLIT3;
      end else begin
        mmu_search_position = mmu_chain_read_value;
        mmu_chain_read_addr = mmu_chain_read_value;
        mmu_logical_read_addr = mmu_chain_read_value;
        stage = MMU_SPLIT;
      end
    end else if (stage == MMU_SPLIT3) begin
      mmu_chain_write_addr = mmu_new_search_position;
      mmu_chain_write_value = mmu_new_search_position;
      stage = MMU_SPLIT4;
    end else if (stage == MMU_SPLIT4) begin
      mmu_chain_write_addr = mmu_prev_search_position;
      mmu_chain_write_value = mmu_prev_search_position;
      mmu_action_ready = 1;
      stage = MMU_IDLE;
    end else if (stage == MMU_INIT) begin
      mmu_start_process_physical_segment = 0;
      mmu_start_process_physical_segment_zero = 0;
      mmu_first_possible_free_physical_segment = 8;
      stage = MMU_IDLE;
    end
  end
endmodule

module x_simple (
    input clk,
    input bit btnc,
    output bit uart_rx_out
);

  bit [31:0] ctn = 0;
  bit reset;

  assign reset = ctn == 1 || btnc;

  always @(posedge clk) begin
    if (ctn < 10) ctn <= ctn + 1;
  end

  bit write_enabled;
  bit [15:0] write_address;
  bit [15:0] write_value;
  bit [15:0] read_address;
  wire [15:0] read_value;

  single_blockram single_blockram (
      .clk(clk),
      .write_enabled(write_enabled),
      .write_address(write_address),
      .write_value(write_value),
      .read_address(read_address),
      .read_value(read_value)
  );

  bit [7:0] uart_buffer[0:128];
  bit [6:0] uart_buffer_available = 0;
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
  parameter OPCODE_PROC = 'h19;  //new process //how many segments, start segment number (16 bit)
  parameter OPCODE_REG_INT = 'h1a;  //x, int number (8 bit)
  parameter OPCODE_INT = 'h1b;  //x, int number (8 bit)
  parameter OPCODE_INT_RET = 'h1c;  //x, int number
  
  parameter OPCODE_TILL_VALUE =23;   //register num (8 bit), value (8 bit), how many instructions (8 bit value) // do..while
  parameter OPCODE_TILL_NON_VALUE=24;   //register num, value, how many instructions (8 bit value) //do..while
  parameter OPCODE_LOOP = 25;  //x, x, how many instructions (8 bit value) //for...
  parameter OPCODE_FREE = 31;  //free ram pages x-y 
  parameter OPCODE_FREE_LEVEL =32; //free ram pages allocated after page x (or pages with concrete level)

  parameter STAGE_AFTER_RESET = 1;
  parameter STAGE_GET_1_BYTE = 2;
  parameter STAGE_GET_2_BYTE = 3;
  parameter STAGE_CHECK_MMU_ADDRESS = 4;
  parameter STAGE_SET_PC = 5;  //jump instructions
  parameter STAGE_GET_PARAM_BYTE = 6;
  parameter STAGE_SET_PARAM_BYTE = 7;
  parameter STAGE_GET_RAM_BYTE = 8;
  parameter STAGE_SET_RAM_BYTE = 9;
  parameter STAGE_HLT = 10;
  parameter STAGE_ALU = 11;
  parameter STAGE_DELETE_PROCESS = 12;
  parameter STAGE_SPLIT_PROCESS = 14;
  /*task switching*/
  parameter STAGE_READ_SAVE_PC = 15;
  parameter STAGE_READ_SAVE_REG = 16;
  parameter STAGE_READ_NEXT_NEXT_PROCESS = 17;
  parameter STAGE_SAVE_NEXT_PROCESS = 20;
  parameter STAGE_SPLIT_PROCESS2 = 21;
  parameter STAGE_SPLIT_PROCESS3 = 22;
  parameter STAGE_SPLIT_PROCESS4 = 23;
  parameter STAGE_SPLIT_PROCESS5 = 24;
  parameter STAGE_SAVE_NEXT_PROCESS2 = 25;

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

  bit [4:0] how_many = 0;
  bit [4:0] process_num = 0;
  bit [15:0] prev_process_address = 0, process_address = 0, next_process_address = 0;
  bit [15:0] pc[0:9];
  bit [5:0] error_code[0:9];
  bit [15:0] registers[0:9][0:31];  //512 bits = 32 x 16-bit registers

  bit rst_can_be_done = 1, working = 1;
  bit [7:0] stage, stage_after_mmu;
  bit [5:0] ram_read_save_reg_start, ram_read_save_reg_end;
  bit [7:0] alu_op, alu_num;
  bit [15:0] instruction1;
  bit [ 7:0] instruction1_1;
  bit [ 7:0] instruction1_2;
  bit [ 4:0] instruction1_2_1;
  bit [ 2:0] instruction1_2_2;
  bit [ 7:0] instruction2_1;
  bit [ 7:0] instruction2_2;

  assign instruction1_1   = instruction1[15:8];
  assign instruction1_2   = instruction1[7:0];
  assign instruction1_2_1 = instruction1[4:0];
  assign instruction1_2_2 = instruction1[7:5];
  assign instruction2_1   = read_value[15:8];
  assign instruction2_2   = read_value[7:0];

  bit unsigned [15:0] mul_a, mul_b;
  wire [15:0] mul_c;
  bit [15:0] div_a, div_b;
  wire [15:0] div_c;
  bit [15:0] plus_a, plus_b;
  wire [15:0] plus_c;
  bit [15:0] minus_a, minus_b;
  wire [15:0] minus_c;

  bit  [ 7:0] instructions;

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

  bit search_mmu_address = 0;
  bit set_mmu_start_process_physical_segment;
  bit reset_mmu_start_process_physical_segment;
  bit mmu_delete_process;
  bit mmu_split_process;
  bit [15:0] mmu_address_a, mmu_address_b;
  wire [15:0] mmu_address_c;
  wire mmu_action_ready;

  mmu mmu (
      .clk(clk),
      .reset(reset),
      .search_mmu_address(search_mmu_address),
      .set_mmu_start_process_physical_segment(set_mmu_start_process_physical_segment),
      .reset_mmu_start_process_physical_segment(reset_mmu_start_process_physical_segment),
      .mmu_delete_process(mmu_delete_process),
      .mmu_split_process(mmu_split_process),
      .mmu_address_a(mmu_address_a),
      .mmu_address_b(mmu_address_b),
      .mmu_address_c(mmu_address_c),
      .mmu_action_ready(mmu_action_ready)
  );

  bit [15:0] int_pc[0:255];
  bit [15:0] int_process_address[0:255];

  `define MAKE_MMU_SEARCH(ARG, ARG2) \
   mmu_address_a = ARG; \
   search_mmu_address = 1; \
   stage_after_mmu = ARG2; \
   stage = STAGE_CHECK_MMU_ADDRESS;

  integer i;  //DEBUG info

  always @(negedge clk) begin
    if (reset == 1 && rst_can_be_done == 1) begin
      rst_can_be_done = 0;
      if (OTHER_DEBUG && !HARDWARE_DEBUG) $display($time, " reset");

      error_code = '{default: 0};
      registers = '{default: 0};

      instructions = 0;

      stage = STAGE_AFTER_RESET;
    end else if (stage == STAGE_AFTER_RESET) begin
      process_num = 0;

      pc[process_num] = ADDRESS_PROGRAM;
      read_address = ADDRESS_PROGRAM; //we start from segment number 0 in first process, don't need MMU translation    

      process_address = 0;
      next_process_address = 4 * MMU_PAGE_SIZE;

      uart_buffer_available = 0;
      `HARD_DEBUG("\n");
      `HARD_DEBUG("S");

      error_code[process_num] = ERROR_NONE;
      working = 0;
      stage = STAGE_GET_1_BYTE;
    end else if (error_code[process_num] == ERROR_NONE) begin
      if (STAGE_DEBUG && !HARDWARE_DEBUG)
        $display($time, " stage ", stage, " pc ", pc[process_num]);
      // (*parallel_case *)(*full_case *) 
      case (stage)
        STAGE_GET_1_BYTE: begin
          if (instructions < 14) begin
            rst_can_be_done = 1;
            if (READ_DEBUG && !HARDWARE_DEBUG)
              $display($time, " read ready ", read_address, "=", read_value);
            `HARD_DEBUG("a");
            instruction1 = read_value;
            pc[process_num] = pc[process_num] + 1;
            read_address = read_address + 1;
            stage = STAGE_GET_2_BYTE;
          end else begin
            stage = STAGE_HLT;
          end
        end
        STAGE_GET_2_BYTE: begin
          instructions = instructions + 1;
          how_many = how_many + 1;
          `HARD_DEBUG("b");
          if (READ_DEBUG && !HARDWARE_DEBUG)
            $display($time, " read ready2 ", read_address, "=", read_value);
          if (OP_DEBUG && !HARDWARE_DEBUG)
            $display(
                $time,
                process_address,
                " pc ",
                (pc[process_num] - 1),
                " b1 %c",
                instruction1_1 / 16 > 10 ? instruction1_1 / 16 + 65 - 10 : instruction1_1 / 16 + 48,
                "%c",
                instruction1_1 % 16 > 10 ? instruction1_1 % 16 + 65 - 10 : instruction1_1 % 16 + 48,
                "%c",
                instruction1_2 / 16 > 10 ? instruction1_2 / 16 + 65 - 10 : instruction1_2 / 16 + 48,
                "%c",
                instruction1_2 % 16 > 10 ? instruction1_2 % 16 + 65 - 10 : instruction1_2 % 16 + 48,
                "h (",
                instruction1_2_1,
                "-",
                instruction1_2_2,
                ") b2 ",
                read_value
            );
          `HARD_DEBUG2(instruction1_1);
          `HARD_DEBUG2(instruction1_2);
          //(*parallel_case *) (*full_case *) 
          case (instruction1_1)
            //24 bit target address
            OPCODE_JMP: begin
              if ((read_value + (256 * 256) * instruction1_2) % 2 == 1) begin
                error_code[process_num] = ERROR_WRONG_ADDRESS;
              end else begin
                if (OP_DEBUG && !HARDWARE_DEBUG)
                  $display(
                      $time, " opcode = jmp to ", (read_value + (256 * 256) * instruction1_2)
                  );  //DEBUG info
                pc[process_num] = (read_value + (256 * 256) * instruction1_2);
                stage = STAGE_SET_PC;
              end
            end
            //x, register num with target addr (we read one reg)
            OPCODE_JMP16: begin
              if (read_value >= 32) begin
                error_code[process_num] = ERROR_WRONG_REG_NUM;
              end else if ((registers[process_num][read_value] - 1) % 2 == 1) begin
                error_code[process_num] = ERROR_WRONG_ADDRESS;
              end else begin
                if (OP_DEBUG && !HARDWARE_DEBUG)
                  $display(
                      $time, " opcode = jmp to ", (registers[process_num][read_value] - 1)
                  );  //DEBUG info
                pc[process_num] = registers[process_num][read_value];
                stage = STAGE_SET_PC;
              end
            end
            //x, register num with target addr (we read one reg)
            OPCODE_JMP_PLUS: begin
              if (OP_DEBUG && !HARDWARE_DEBUG)
                $display(
                    $time,
                    " opcode = jmp plus to ",
                    pc[process_num] + read_value * 2 - 1,
                    " (",
                    read_value,
                    " instructions)"
                );  //DEBUG info      
              pc[process_num] += read_value * 2 - 1;
              stage = STAGE_SET_PC;
            end
            //x, register num with info (we read one reg)
            OPCODE_JMP_PLUS16: begin
              if (read_value >= 32) begin
                error_code[process_num] = ERROR_WRONG_REG_NUM;
              end else begin
                if (OP_DEBUG && !HARDWARE_DEBUG)
                  $display(
                      $time,
                      " opcode = jmp plus16 to ",
                      pc[process_num] + registers[process_num][read_value] * 2 - 1,
                      " (",
                      registers[read_value],
                      " instructions)"
                  );  //DEBUG info
                pc[process_num] += registers[process_num][read_value] * 2 - 1;
                stage = STAGE_SET_PC;
              end
            end
            //x, 16 bit how many instructions
            OPCODE_JMP_MINUS: begin
              if (pc[process_num] - read_value * 2 < ADDRESS_PROGRAM) begin
                error_code[process_num] = ERROR_WRONG_ADDRESS;
              end else begin
                if (OP_DEBUG && !HARDWARE_DEBUG)
                  $display(
                      $time,
                      " opcode = jmp minus to ",
                      pc[process_num] - read_value * 2 - 1,
                      " (",
                      read_value,
                      " instructions)"
                  );  //DEBUG info
                pc[process_num] -= read_value * 2 - 1;
                stage = STAGE_SET_PC;
              end
            end
            //x, register num with info (we read one reg)
            OPCODE_JMP_MINUS16: begin
              if (read_value >= 32) begin
                error_code[process_num] = ERROR_WRONG_REG_NUM;
              end else if (pc[process_num] - registers[process_num][read_value] * 2 < ADDRESS_PROGRAM) begin
                error_code[process_num] = ERROR_WRONG_ADDRESS;
              end else begin
                if (OP_DEBUG && !HARDWARE_DEBUG)
                  $display(
                      $time,
                      " opcode = jmp minus16 to ",
                      pc[process_num] - registers[process_num][read_value] * 2 - 1,
                      " (",
                      registers[read_value],
                      " instructions)"
                  );  //DEBUG info      
                pc[process_num] -= registers[process_num][read_value] * 2 - 1;
                stage = STAGE_SET_PC;
              end
            end
            //register num (5 bits), how many-1 (3 bits), 16 bit source addr //ram -> reg
            OPCODE_RAM2REG: begin
              if (instruction1_2_1 + instruction1_2_2 >= 32) begin
                error_code[process_num] = ERROR_WRONG_REG_NUM;
              end else if (read_value < ADDRESS_PROGRAM) begin
                error_code[process_num] = ERROR_WRONG_ADDRESS;
              end else begin
                if (OP_DEBUG && !HARDWARE_DEBUG)
                  $display(
                      $time,
                      " opcode = ram2reg read value from address ",
                      read_value,
                      "+ to reg ",  //DEBUG info
                      instruction1_2_1,
                      "-",
                      (instruction1_2_1 + instruction1_2_2)
                  );  //DEBUG info
                ram_read_save_reg_start = instruction1_2_1;
                ram_read_save_reg_end   = instruction1_2_1 + instruction1_2_2;
                `MAKE_MMU_SEARCH(read_value, STAGE_GET_RAM_BYTE);
              end
            end
            //start register num, how many registers, register num with source addr (we read one reg), //ram -> reg
            OPCODE_RAM2REG16: begin
              if (instruction1_2 + instruction2_1 >= 32 || instruction2_2 >= 32) begin
                error_code[process_num] = ERROR_WRONG_REG_NUM;
              end else if (read_value < ADDRESS_PROGRAM) begin
                error_code[process_num] = ERROR_WRONG_ADDRESS;
              end else begin
                if (OP_DEBUG && !HARDWARE_DEBUG)
                  $display(
                      $time,
                      " opcode = ram2reg16 read from ram (address ",
                      registers[instruction2_2],
                      "+) to reg ",
                      instruction1_2,
                      "-",
                      (instruction1_2 + instruction2_1)
                  );  //DEBUG info             
                ram_read_save_reg_start = instruction1_2;
                ram_read_save_reg_end   = instruction1_2 + instruction2_1;
                `MAKE_MMU_SEARCH(registers[process_num][instruction2_2], STAGE_GET_RAM_BYTE);
              end
            end
            //register num (5 bits), how many-1 (3 bits), 16 bit target addr //reg -> ram
            OPCODE_REG2RAM: begin
              if (instruction1_2_1 + instruction1_2_2 >= 32) begin
                error_code[process_num] = ERROR_WRONG_REG_NUM;
              end else if (read_value < ADDRESS_PROGRAM) begin
                error_code[process_num] = ERROR_WRONG_ADDRESS;
              end else begin
                if (OP_DEBUG && !HARDWARE_DEBUG)
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
                ram_read_save_reg_start = instruction1_2_1;
                ram_read_save_reg_end = instruction1_2_1 + instruction1_2_2;
                write_value = registers[process_num][instruction1_2_1];
                `MAKE_MMU_SEARCH(read_value, STAGE_SET_RAM_BYTE);
              end
            end
            //start register num, how many registers, register num with target addr (we read one reg), //reg -> ram
            OPCODE_REG2RAM16: begin
              if (instruction1_2 + instruction2_1 >= 32 || instruction2_2 >= 32) begin
                error_code[process_num] = ERROR_WRONG_REG_NUM;
              end else if (read_value < ADDRESS_PROGRAM) begin
                error_code[process_num] = ERROR_WRONG_ADDRESS;
              end else begin
                if (OP_DEBUG && !HARDWARE_DEBUG)
                  $display(
                      $time,
                      " opcode = reg2ram16 save to ram (address ",
                      registers[instruction2_2],
                      "+) from reg ",
                      instruction1_2,
                      "-",
                      (instruction1_2 + instruction2_1)
                  );  //DEBUG info                             
                ram_read_save_reg_start = instruction1_2;
                ram_read_save_reg_end = instruction1_2 + instruction2_1;
                write_value = registers[process_num][instruction1_2];
                `MAKE_MMU_SEARCH(registers[process_num][instruction2_2], STAGE_SET_RAM_BYTE);
              end
            end
            //register num (5 bits), how many-1 (3 bits), 16 bit value //value -> reg
            OPCODE_NUM2REG: begin
              if (OP_DEBUG && !HARDWARE_DEBUG)
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
              if (OP_DEBUG && !HARDWARE_DEBUG)
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
              if (OP_DEBUG && !HARDWARE_DEBUG)
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
              if (OP_DEBUG && !HARDWARE_DEBUG)
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
                error_code[process_num] = ERROR_DIVIDE_BY_ZERO;
              end else begin
                if (OP_DEBUG && !HARDWARE_DEBUG)
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
            //exit process
            OPCODE_EXIT: begin
              if (OP_DEBUG && !HARDWARE_DEBUG) $display($time, " opcode = exit");
              mmu_delete_process = 1;
            write_address = prev_process_address + ADDRESS_NEXT_PROCESS;
          write_value = next_process_address;
          write_enabled = 1;            
              stage = STAGE_DELETE_PROCESS;
            end
            //new process //how many segments, start segment number (16 bit
            OPCODE_PROC: begin
              if (OP_DEBUG && !HARDWARE_DEBUG)
                $display(
                    $time,
                    " opcode = proc, segments ",
                    read_value,
                    "-",
                    (read_value + instruction1_2)
                );
              mmu_address_a = read_value;
              mmu_address_b = read_value + instruction1_2;
              mmu_split_process = 1;
              stage = STAGE_SPLIT_PROCESS;
            end
            //x, int number (8 bit)
            OPCODE_REG_INT: begin
              if (OP_DEBUG && !HARDWARE_DEBUG)
                $display(
                    $time,
                    " opcode = reg_int ",instruction2_2);
              int_pc[instruction2_2] = pc[process_num];
              int_process_address[instruction2_2] = process_address;                    
              //switch to next process                    
              process_address = prev_process_address;
              //in parallel update MMU
              reset_mmu_start_process_physical_segment = 0;
              set_mmu_start_process_physical_segment = 1;
              mmu_address_a = next_process_address;
              //read next pc
              read_address = process_address + ADDRESS_PC;
              //stage = STAGE_READ_PC;              
            end
            //x, int number (8 bit)
            OPCODE_INT: begin
               if (OP_DEBUG && !HARDWARE_DEBUG)
                $display(
                    $time,
                    " opcode = int ",instruction2_2);
               //replace current process with int process in the chain     
            end
            //x, int number
            OPCODE_INT_RET: begin
               if (OP_DEBUG && !HARDWARE_DEBUG)
                $display(
                    $time,
                    " opcode = int_ret");
            end
            // default: begin
            //    error_code = ERROR_WRONG_OPCODE;
            // end
          endcase
          if (stage != STAGE_SET_PC) begin
            // $display("update pc");
            pc[process_num] = pc[process_num] + 1;
          end
          if (stage == STAGE_GET_2_BYTE) begin           
            `MAKE_MMU_SEARCH(pc[process_num], STAGE_GET_1_BYTE);            
          end
        end
        STAGE_GET_RAM_BYTE: begin
          registers[process_num][ram_read_save_reg_start] = read_value;
          if (OP_DEBUG && !HARDWARE_DEBUG)
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
            `MAKE_MMU_SEARCH(pc[process_num], STAGE_GET_1_BYTE);
          end else begin
            ram_read_save_reg_start = ram_read_save_reg_start + 1;
            `MAKE_MMU_SEARCH(mmu_address_a + 1, STAGE_GET_RAM_BYTE);
          end
        end
        STAGE_SET_RAM_BYTE: begin
          if (ram_read_save_reg_start == ram_read_save_reg_end) begin
            write_enabled = 0;
            `MAKE_MMU_SEARCH(pc[process_num], STAGE_GET_1_BYTE);
          end else begin
            ram_read_save_reg_start = ram_read_save_reg_start + 1;
            write_value = registers[process_num][ram_read_save_reg_start];
            `MAKE_MMU_SEARCH(mmu_address_a + 1, STAGE_SET_RAM_BYTE);
          end
        end
        STAGE_CHECK_MMU_ADDRESS: begin
          if (mmu_action_ready) begin
            search_mmu_address = 0;
            if (stage_after_mmu == STAGE_SET_RAM_BYTE) begin
              write_enabled = 1;
              write_address = mmu_address_c;
            end else begin
              read_address = mmu_address_c;
            end
            stage = stage_after_mmu;
          end
        end
        STAGE_ALU: begin
          if (ALU_DEBUG && !HARDWARE_DEBUG)
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
            error_code[process_num] = ERROR_WRONG_REG_NUM;
          end else begin
            if (alu_num == 255) begin
              alu_num = instruction1_2_1;
            end else begin
              case (alu_op)
                ALU_SET: begin
                  if (OP_DEBUG && !HARDWARE_DEBUG)
                    $display($time, " set reg ", alu_num, " with ", read_value);
                  registers[process_num][alu_num] = read_value;
                end
                ALU_ADD: begin
                  registers[process_num][alu_num] = plus_c;
                end
                ALU_DEC: begin
                  registers[process_num][alu_num] = minus_c;
                end
                ALU_MUL: begin
                  registers[process_num][alu_num] = mul_c;
                end
                ALU_DIV: begin
                  registers[process_num][alu_num] = div_c;
                end
              endcase
              alu_num = alu_num + 1;
            end
            if (alu_num > instruction1_2_1 + instruction1_2_2) begin
              `MAKE_MMU_SEARCH(pc[process_num], STAGE_GET_1_BYTE);
            end else begin
              case (alu_op)
                ALU_ADD: begin
                  plus_a = registers[process_num][alu_num];
                  plus_b = read_value;
                end
                ALU_DEC: begin
                  minus_a = registers[process_num][alu_num];
                  minus_b = read_value;
                end
                ALU_MUL: begin
                  mul_a = registers[process_num][alu_num];
                  mul_b = read_value;
                end
                ALU_DIV: begin
                  div_a = registers[process_num][alu_num];
                  div_b = read_value;
                end
              endcase
            end
          end
        end        
        STAGE_READ_SAVE_PC: begin                                       
          set_mmu_start_process_physical_segment = 0;    
          //old process
          write_address = process_address + ADDRESS_REG;
          write_value = registers[process_num][0];
          //new process
          pc[process_num] = read_value;
          $display($time, " new pc ", read_value);
          read_address = next_process_address + ADDRESS_REG;
          //registers
          ram_read_save_reg_start = 0; //counter
          stage = STAGE_READ_SAVE_REG;
        end
        STAGE_READ_SAVE_REG: begin
          if (ram_read_save_reg_start == 32) begin           
            //change process
            prev_process_address = process_address;
            process_address = next_process_address;
            write_enabled = 0;
            //read next process address
            read_address = next_process_address + ADDRESS_NEXT_PROCESS;
            stage = STAGE_READ_NEXT_NEXT_PROCESS;
          end else begin
            //new process  
            registers[process_num][ram_read_save_reg_start] = read_value;
            //old process          
            ram_read_save_reg_start = ram_read_save_reg_start + 1;
            read_address = read_address+1;
            write_address = write_address + 1;
            write_value = registers[process_num][ram_read_save_reg_start];
          end
        end
        STAGE_READ_NEXT_NEXT_PROCESS: begin
        //  if (mmu_action_ready) begin
          
            next_process_address = read_value;
            `MAKE_MMU_SEARCH(pc[process_num], STAGE_GET_1_BYTE);
         // end
        end
        STAGE_DELETE_PROCESS: begin
          mmu_delete_process = 0;
          if (mmu_action_ready) begin
            process_address = prev_process_address;
            write_enabled = 0;            
            //in parallel update MMU
            reset_mmu_start_process_physical_segment = 0;
            set_mmu_start_process_physical_segment = 1;
            mmu_address_a = next_process_address;
            //initiate task switcher with disabled memory write
            //new process
            read_address = next_process_address + ADDRESS_PC;
            stage = STAGE_READ_SAVE_PC;
          end
        end
        STAGE_SPLIT_PROCESS: begin
          mmu_split_process = 0;
          if (mmu_action_ready) begin
            //  $display($time, " new  process chain starts in ", mmu_address_c, " x");            
            mul_a = mmu_address_c;
            mul_b = MMU_PAGE_SIZE;
            stage = STAGE_SPLIT_PROCESS2;
          end
        end
        STAGE_SPLIT_PROCESS2: begin
          stage = STAGE_SPLIT_PROCESS3;
        end
        STAGE_SPLIT_PROCESS3: begin
          stage = STAGE_SPLIT_PROCESS4;
        end
        STAGE_SPLIT_PROCESS4: begin
          stage = STAGE_SPLIT_PROCESS5;
        end
        STAGE_SPLIT_PROCESS5: begin
          write_address = process_address + ADDRESS_NEXT_PROCESS;
          write_value = mul_c;
          write_enabled = 1;
          stage = STAGE_SAVE_NEXT_PROCESS;
        end
        STAGE_SAVE_NEXT_PROCESS: begin
          //  $display($time, " save next ");
          write_address = mul_c + ADDRESS_NEXT_PROCESS;
          write_value = next_process_address;
          stage = STAGE_SAVE_NEXT_PROCESS2;
        end
        STAGE_SAVE_NEXT_PROCESS2: begin
          write_enabled = 0;
          next_process_address = mul_c;
          `MAKE_MMU_SEARCH(pc[process_num], STAGE_GET_1_BYTE);
        end
      endcase
                 if (stage == STAGE_CHECK_MMU_ADDRESS && how_many==2 && process_address != next_process_address) begin
                how_many=0;
                 search_mmu_address = 0;         
            if (TASK_SWITCHER_DEBUG && !HARDWARE_DEBUG) $display($time, " TASK SWITCHER from ",process_address," to ",next_process_address);
            //old process
            write_enabled = 1;
            write_address = process_address + ADDRESS_PC;
            write_value = pc[process_num];
            //new process
            read_address = next_process_address + ADDRESS_PC;
            $display($time, "update mmu");
             //in parallel update MMU
            set_mmu_start_process_physical_segment = 1;
            reset_mmu_start_process_physical_segment = 1; //parameter            
            mmu_address_a = next_process_address;
            stage = STAGE_READ_SAVE_PC;
 end
    end else if (error_code[process_num] != ERROR_NONE) begin
      `HARD_DEBUG("B");
      `HARD_DEBUG("S");
      `HARD_DEBUG("O");
      `HARD_DEBUG("D");
      `HARD_DEBUG2(error_code[process_num]);
      stage = STAGE_HLT;
    end
  end
endmodule

module single_blockram (
    input clk,
    input write_enabled,
    input [15:0] write_address,
    input [15:0] write_value,
    input [15:0] read_address,
    output bit [15:0] read_value
);

  /*  reg [15:0] ram[0:67];
      initial begin  //DEBUG info
        $readmemh("rom4.mem", ram);  //DEBUG info
      end  //DEBUG info
*/

  // verilog_format:off
   (* ram_style = "block" *)  bit [15:0] ram  [0:559]= {  // in Vivado (required by board)
  //  reg [0:559] [15:0] ram = {  // in iVerilog
  
      //first process - 4 pages (280 elements)
      16'h0118, 16'h0000,  16'h0000, 16'h0000, //next process address (no MMU) overwritten by CPU, we use first bytes only      
      16'h002E, 16'h0000,  16'h0000, 16'h0000, //PC for this process (overwritten by CPU, we use first bytes only)       

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

      16'h1210, 16'd2613, //value to reg
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
      
      //second process - 2 pages (140 elements) + 2 pages (140 elements) new process nr 3
      16'h0000, 16'h0000,  16'h0000, 16'h0000, //next process address (no MMU) overwritten by CPU, we use first bytes only      
      16'h002E, 16'h0000,  16'h0000, 16'h0000, //PC for this process (overwritten by CPU, we use first bytes only)       

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

      16'h1210, 16'h0a34, //value to reg
      16'h1800, 16'h0000, //process end
      //16'h0e10, 16'h0064, //save to ram
      //16'h1902, 16'h0002, //split process segments 2-4
      16'h0911, 16'h0065, //ram to reg
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
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      
      //third process - 2 pages (140 elements)
      16'h0000, 16'h0000,  16'h0000, 16'h0000, //next process address (no MMU) overwritten by CPU, we use first bytes only      
      16'h002E, 16'h0000,  16'h0000, 16'h0000, //PC for this process (overwritten by CPU, we use first bytes only)       

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
      16'h1800, 16'h0000, //process end
      //16'h0e10, 16'h0064, //save to ram
      //16'h1902, 16'h0002, //split process segments 2-4
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
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000      
    };

  // verilog_format:on

  always @(posedge clk) begin
    if (write_enabled && RAM_WRITE_DEBUG && !HARDWARE_DEBUG)
      $display($time, " ram write ", write_address, " = ", write_value);
    if (RAM_READ_DEBUG && !HARDWARE_DEBUG)
      $display($time, " ram read ", read_address, " = ", ram[read_address]);

    if (write_enabled) ram[write_address] <= write_value;
    read_value <= ram[read_address];
  end
endmodule

module uartx_tx_with_buffer (
    input clk,
    input [7:0] uart_buffer[0:128],
    input [6:0] uart_buffer_available,
    output bit reset_uart_buffer_available,
    output bit uart_buffer_full,
    output bit tx
);

  bit [7:0] input_data;
  bit [6:0] uart_buffer_processed = 0;
  bit [3:0] uart_buffer_state = 0;
  bit start;
  wire complete;

  assign reset_uart_buffer_available = uart_buffer_available != 0 && uart_buffer_available == uart_buffer_processed && uart_buffer_state == 2 && complete?1:0;
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

  bit [ 6:0] uart_tx_state = STATE_IDLE;
  bit [10:0] counter = CLK_PER_BIT;

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

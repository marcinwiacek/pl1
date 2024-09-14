/* License: GPL3, for other please ask Marcin Wiacek */

`timescale 1ns / 1ps

parameter HOW_MANY_OP_SIMULATE = 22;
parameter HOW_MANY_OP_PER_TASK_SIMULATE = 2;

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
parameter STAGE_DEBUG = 1;
parameter MMU_STAGE_DEBUG = 0;
parameter OP_DEBUG = 1;
parameter OP2_DEBUG = 0;
parameter ALU_DEBUG = 0;

parameter MMU_PAGE_SIZE = 70;  //how many bytes are assigned to one memory page in MMU
//parameter RAM_SIZE = 32767;
parameter MMU_MAX_INDEX = 255;  //(`RAM_SIZE+1)/`MMU_PAGE_SIZE;
parameter MMU_MAX_INDEX_BIT_SIZE = 8;  //256 values can be saved in 8 bits

/* DEBUG info */ `define HARD_DEBUG(ARG) \
/* DEBUG info */     if (reset_uart_buffer_available) uart_buffer_available = 0; \
/* DEBUG info */     uart_buffer[uart_buffer_available++] = ARG; \
/* DEBUG info */     if (HARDWARE_DEBUG == 1)  $write(ARG);

// verilog_format:off
/* DEBUG info */ `define HARD_DEBUG2(ARG) \
/* DEBUG info */   //  if (reset_uart_buffer_available) uart_buffer_available = 0; \
/* DEBUG info */     uart_buffer[uart_buffer_available++] = ARG/16>=10? ARG/16 + 65 - 10:ARG/16+ 48; \
/* DEBUG info */     uart_buffer[uart_buffer_available++] = ARG%16>=10? ARG%16 + 65 - 10:ARG%16+ 48; \
/* DEBUG info */     if (HARDWARE_DEBUG == 1) $write("%c",ARG/16>=10? ARG/16 + 65 - 10:ARG/16+ 48,"%c",ARG%16>=10? ARG%16 + 65 - 10:ARG%16+ 48);
// verilog_format:on

/* DEBUG info */ `define SHOW_REG_DEBUG(ARG, INFO, ARG2, ARG3) \
/* DEBUG info */     if (ARG == 1) begin \
/* DEBUG info */       $write($time-starttime, INFO); \
/* DEBUG info */       for (i = 0; i <= 10; i = i + 1) begin \
/* DEBUG info */         $write($sformatf("%02x ", (i==ARG2?ARG3:registers[process_index][i]))); \
/* DEBUG info */       end \
/* DEBUG info */       $display(""); \
/* DEBUG info */     end

/* DEBUG info */  `define SHOW_MMU_DEBUG \
/* DEBUG info */     if (MMU_CHANGES_DEBUG == 1 && !HARDWARE_DEBUG) begin \
/* DEBUG info */       $write($time-starttime, " mmu "); \
/* DEBUG info */       for (i = 0; i <= 10; i = i + 1) begin \
/* DEBUG info */         if (mmu_start_process_physical_page == i) $write("s"); \
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
/* DEBUG info */       $write($time-starttime, " mmu ",ARG," "); \
/* DEBUG info */       for (i = 0; i <= 10; i = i + 1) begin \
/* DEBUG info */         $write($sformatf("%02x ", ram[i])); \
/* DEBUG info */       end \
/* DEBUG info */       $display(""); \
/* DEBUG info */     end


/* DEBUG info */  `define SHOW_TASK_INFO(ARG) \
/* DEBUG info */     if (TASK_SWITCHER_DEBUG == 1 && !HARDWARE_DEBUG) begin \
/* DEBUG info */          $write($time-starttime, " ",ARG," pc ", address_pc[process_index]); \
/* DEBUG info */          $display( \
/* DEBUG info */              " ",ARG," process seg/addr ", mmu_start_process_page, process_start_address[process_index], \
/* DEBUG info */              " process index ", process_index \
/* DEBUG info */          ); \
/* DEBUG info */        end

//(* use_dsp = "yes" *) 
module plus (
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

//(* use_dsp = "yes" *) 
module minus (
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

//(* use_dsp = "yes" *) 
module mul (
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

//(* use_dsp = "yes" *) 
module div (
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
    input write_enable,
    input [15:0] write_addr,
    input [8:0] write_value,
    input [10:0] starttime
);

  //(* ram_style = "distributed" *)
  //(* ram_style = "block" *)
  (* rw_addr_collision= "yes" *) bit [8:0] ram[0:MMU_MAX_INDEX];

  integer i;

  assign read_value = ram[read_addr];

  always @(negedge clk) begin
    if (write_enable) begin
      ram[write_addr] <= write_value;
      //$display($time-starttime, " chain write ", write_addr, "=", write_value);
      `SHOW_MMU2("chain")
    end
  end
endmodule

//logical pages
module mmulutram2 (
    input clk,
    input [15:0] read_addr,
    output bit [8:0] read_value,
    input write_enable,
    input [15:0] write_addr,
    input [8:0] write_value,
    input [10:0] starttime
);

  //(* ram_style = "distributed" *)
  // (* ram_style = "block" *)
  (* rw_addr_collision= "yes" *) bit [8:0] ram[0:MMU_MAX_INDEX];

  integer i;

  assign read_value = ram[read_addr];

  always @(negedge clk) begin
    if (write_enable) begin
      ram[write_addr] <= write_value;
      // $display($time-starttime, " logical write ", write_addr, "=", write_value);
      `SHOW_MMU2("logical")
    end
  end
endmodule

//big cache memory
module mmulutram3 (
    input clk,
    input [15:0] read_addr,
    output bit [MMU_MAX_INDEX_BIT_SIZE+MMU_MAX_INDEX_BIT_SIZE:0] read_value,
    input write_enable,
    input [15:0] write_addr,
    input [MMU_MAX_INDEX_BIT_SIZE+MMU_MAX_INDEX_BIT_SIZE:0] write_value
);

  //(* ram_style = "distributed" *)
  //(* ram_style = "block" *)
  bit [MMU_MAX_INDEX_BIT_SIZE+MMU_MAX_INDEX_BIT_SIZE:0] ram[0:MMU_MAX_INDEX];

  integer i;

  //initial begin
  //    ram = '{default: 0};
  //  end

  assign read_value = ram[read_addr];

  always @(negedge clk) begin
    if (write_enable) begin
      ram[write_addr] <= write_value;
    end
  end
endmodule

module mmu (
    input clk,
    input reset,
    input bit add_shared_mem,
    input bit delete_shared_mem,
    input bit reg_int,
    input bit search_mmu_address,
    input bit set_mmu_start_process_physical_page,
    input bit mmu_delete_process,
    input bit mmu_split_process,
    input bit [15:0] mmu_address_a,
    mmu_address_b,
    mmu_address_d,
    output bit [15:0] mmu_address_c,
    output bit mmu_action_ready,
    output bit [10:0] starttime
);

  bit [8:0] mmu_first_possible_free_physical_page;  //updated on create / delete (when == 0, we assume it must be free; in other cases it's just start index for loop)
  bit [8:0] mmu_start_process_physical_page;  //updated on process switch and MMU sorting
  bit [8:0] mmu_start_process_physical_page_zero;  //updated on process switch

  bit [8:0] mmu_address_to_search_page;
  bit [8:0] mmu_search_position, mmu_prev_search_position, mmu_new_search_position;

  bit [7:0] stage;
  bit rst_can_be_done = 1;

  integer i;

  // values:
  // mmu_chain_memory - next physical page index for process
  // mmu_logical_pages_memory - logical process page assigned to physical page
  // special cases:
  // mmu_chain_memory == own physical page (element is pointing to itself) -> end page
  // mmu_logical_pages_memory == start point in page 0 when process is not executed
  // mmu_logical_pages_memory == 0 && mmu_chain_memory == 0 -> free page for all physical pages != 0 (see note in next line)
  // 0,0 can be assigned to process starting from physical page 0 -> we handle it with mmu_first_possible_free_physical_page 

  bit [15:0] mmu_chain_read_addr;
  wire [8:0] mmu_chain_read_value;
  bit mmu_chain_write_enable = 0;
  bit [15:0] mmu_chain_write_addr;
  bit [8:0] mmu_chain_write_value;

  mmulutram mmu_chain_memory (
      .clk(clk),
      .read_addr(mmu_chain_read_addr),
      .read_value(mmu_chain_read_value),
      .write_enable(mmu_chain_write_enable),
      .write_addr(mmu_chain_write_addr),
      .write_value(mmu_chain_write_value),
      .starttime(starttime)
  );

  bit [15:0] mmu_logical_read_addr;
  wire [8:0] mmu_logical_read_value;
  bit mmu_logical_write_enable = 0;
  bit [15:0] mmu_logical_write_addr;
  bit [8:0] mmu_logical_write_value;

  mmulutram2 mmu_logical_pages_memory (
      .clk(clk),
      .read_addr(mmu_logical_read_addr),
      .read_value(mmu_logical_read_value),
      .write_enable(mmu_logical_write_enable),
      .write_addr(mmu_logical_write_addr),
      .write_value(mmu_logical_write_value),
      .starttime(starttime)
  );

  //values: process start page + process physical page
  //example: entry 5 contains 6 and 7 values -> process starting with page 6 has got logical page 5 assigned to physical 7
  //updated during searching over mmu_chain_memory and mmu_logical_pages_memory and during process deleting

  //bit [15:0] mmu_cache_read_addr;
  //wire [MMU_MAX_INDEX_BIT_SIZE+MMU_MAX_INDEX_BIT_SIZE:0] mmu_cache_read_value;
  //bit mmu_cache_write_enable = 0;
  //bit [15:0] mmu_cache_write_addr;
  //bit [MMU_MAX_INDEX_BIT_SIZE+MMU_MAX_INDEX_BIT_SIZE:0] mmu_cache_write_value;

  //bit [MMU_MAX_INDEX_BIT_SIZE:0] mmu_cache_read_value_1;
  //bit [MMU_MAX_INDEX_BIT_SIZE:0] mmu_cache_read_value_2;

  //assign mmu_cache_read_value_1 = mmu_cache_read_value[7:0];
  //assign mmu_cache_read_value_2 = mmu_cache_read_value[15:8];

  //mmulutram3 mmu_cache_memory (
  //      .clk(clk),
  //      .read_addr(mmu_cache_read_addr),
  //      .read_value(mmu_cache_read_value),
  //      .write_enable(mmu_cache_write_enable),
  //      .write_addr(mmu_cache_write_addr),
  //      .write_value(mmu_cache_write_value)
  //  );

  parameter MMU_IDLE = 0;
  parameter MMU_SEARCH = 1;
  parameter MMU_SEARCH2 = 2;
  //parameter MMU_SEARCH3 = 3;
  parameter MMU_INIT = 4;
  parameter MMU_INIT2 = 5;
  parameter MMU_INIT3 = 6;
  parameter MMU_INIT4 = 7;
  parameter MMU_DELETE = 8;
  parameter MMU_DELETE2 = 9;
  parameter MMU_SPLIT = 10;
  parameter MMU_SPLIT2 = 11;
  parameter MMU_SPLIT3 = 12;
  parameter MMU_SPLIT4 = 14;
  parameter MMU_SET_PROCESS_DATA = 15;
  parameter MMU_SET_PROCESS_DATA2 = 16;
  parameter MMU_ALLOCATE_NEW = 17;
  parameter MMU_ALLOCATE_NEW2 = 18;
  parameter MMU_SWITCH = 19;

  bit [15:0] mmu_address_to_search_page_cache;

  assign mmu_address_to_search_page_cache = mmu_address_a / MMU_PAGE_SIZE; //fixme: mmu_size / 2^x allows for using assign ... =  

  bit [7:0] int_memory_start_page[0:255], int_memory_end_page[0:255];
  bit int_inside = 0, int_search = 0;
  bit [15:0]
      int_number,
      int_source_process_page,
      int_source_process_page_zero,
      int_source_start_page,
      int_source_end_page;

  bit [7:0] logical_init_ram[0:7] = {0, 1, 2, 3, 4, 1, 2, 3};
  bit [7:0] chain_init_ram  [0:7] = {1, 2, 3, 3, 5, 6, 7, 7};

  always @(posedge clk) begin
    //$display($time-starttime, " mmu stage ", stage);
    if (reset == 1 && rst_can_be_done == 1) begin
      rst_can_be_done <= 0;
      if (OTHER_DEBUG && !HARDWARE_DEBUG) $display($time - starttime, " reset");
      mmu_action_ready <= 0;
      mmu_chain_write_enable <= 1;
      mmu_chain_write_value <= 0;
      mmu_chain_write_addr <= MMU_MAX_INDEX - 1;
      mmu_logical_write_enable <= 1;
      mmu_logical_write_value <= 0;
      mmu_logical_write_addr <= MMU_MAX_INDEX - 1;
      stage <= MMU_INIT;
    end else begin
      if (MMU_STAGE_DEBUG && !HARDWARE_DEBUG && stage != MMU_IDLE) begin
        $write($time - starttime, " mmu stage ", stage, " ");
        case (stage)
          MMU_SEARCH: $write("MMU_SEARCH");
          MMU_SEARCH2: $write("MMU_SEARCH2");
          // MMU_SEARCH3: $write("MMU_SEARCH3");
          MMU_INIT: $write("MMU_INIT");
          MMU_INIT2: $write("MMU_INIT2");
          MMU_INIT3: $write("MMU_INIT3");
          MMU_INIT4: $write("MMU_INIT4");
          MMU_DELETE: $write("MMU_DELETE");
          MMU_DELETE2: $write("MMU_DELETE2");
          MMU_SPLIT: $write("MMU_SPLIT");
          MMU_SPLIT2: $write("MMU_SPLIT2");
          MMU_SPLIT3: $write("MMU_SPLIT3");
          MMU_SPLIT4: $write("MMU_SPLIT4");
          MMU_SET_PROCESS_DATA: $write("MMU_SET_PROCESS_DATA");
          MMU_SET_PROCESS_DATA2: $write("MMU_SET_PROCESS_DATA2");
          MMU_ALLOCATE_NEW: $write("MMU_ALLOCATE_NEW");
          MMU_ALLOCATE_NEW2: $write("MMU_ALLOCATE_NEW2");
          MMU_SWITCH: $write("MMU_SWITCH");
        endcase
        $display("");
      end
      case (stage)
        MMU_IDLE: begin
          // $display($time-starttime, " idle");
          mmu_chain_write_enable   <= 0;
          mmu_logical_write_enable <= 0;
          if (search_mmu_address) begin
            if (int_inside && mmu_address_to_search_page_cache >=int_memory_start_page[int_number] && 
                 mmu_address_to_search_page_cache <=int_memory_start_page[int_number]) begin
              mmu_address_to_search_page <= int_source_start_page+mmu_address_to_search_page_cache-int_memory_start_page[int_number];
              if (MMU_TRANSLATION_DEBUG && !HARDWARE_DEBUG)
                $display(
                    $time - starttime,
                    " mmu, shared address ",
                    mmu_address_a,
                    " page ",
                    (int_source_start_page+mmu_address_to_search_page_cache-int_memory_start_page[int_number]),
                    " entry point ",
                    int_source_process_page,
                    " entry point zero ",
                    int_source_process_page_zero
                );
              mmu_search_position <= int_source_process_page;
              mmu_chain_read_addr <= int_source_process_page;
              mmu_logical_read_addr <= int_source_process_page;
              int_search <= 1;
            end else begin
              mmu_address_to_search_page <= mmu_address_to_search_page_cache;
              //            mmu_cache_read_addr <= mmu_address_to_search_page_cache;
              if (MMU_TRANSLATION_DEBUG && !HARDWARE_DEBUG)
                $display(
                    $time - starttime,
                    " mmu, address ",
                    mmu_address_a,
                    " page ",
                    (mmu_address_to_search_page_cache),
                    " entry point ",
                    mmu_start_process_physical_page,
                    " entry point zero ",
                    mmu_start_process_physical_page_zero
                );
              mmu_search_position <= mmu_start_process_physical_page;
              mmu_chain_read_addr <= mmu_start_process_physical_page;
              mmu_logical_read_addr <= mmu_start_process_physical_page;
              int_search <= 0;
            end
            mmu_action_ready <= 0;
            stage <= MMU_SEARCH;
          end else if (set_mmu_start_process_physical_page) begin
            if (TASK_SWITCHER_DEBUG && !HARDWARE_DEBUG)
              $display(
                  $time - starttime,
                  " switching mmu zero=",
                  mmu_start_process_physical_page_zero,
                  " real start =",
                  mmu_start_process_physical_page
              );
            //old process
            mmu_logical_write_addr <= mmu_start_process_physical_page_zero;
            mmu_logical_write_value <= mmu_start_process_physical_page;
            mmu_logical_write_enable <= 1;
            //new process
            mmu_logical_read_addr <= mmu_address_a;
            mmu_action_ready <= 0;
            stage <= MMU_SWITCH;
          end else if (mmu_delete_process) begin
            mmu_search_position <= mmu_start_process_physical_page;
            mmu_chain_read_addr <= mmu_start_process_physical_page;
            mmu_action_ready <= 0;
            stage <= MMU_DELETE;
          end else if (mmu_split_process) begin
            //  $display($time-starttime, " split start point ", mmu_start_process_physical_page);
            mmu_search_position <= mmu_start_process_physical_page;
            mmu_chain_read_addr <= mmu_start_process_physical_page;
            mmu_logical_read_addr <= mmu_start_process_physical_page;
            mmu_prev_search_position <= mmu_start_process_physical_page;
            mmu_new_search_position <= 0;
            mmu_action_ready <= 0;
            stage <= MMU_SPLIT;
          end else if (add_shared_mem) begin
            int_inside <= 1;
            int_source_process_page_zero <= mmu_start_process_physical_page_zero;
            int_source_process_page <= mmu_start_process_physical_page;
            int_number <= mmu_address_a;
            int_source_start_page <= mmu_address_b;
            int_source_end_page <= mmu_address_d;

            mmu_action_ready <= 1;
          end else if (delete_shared_mem) begin
            int_inside <= 0;

            //old process
            mmu_logical_write_addr <= int_source_process_page_zero;
            mmu_logical_write_value <= int_source_process_page;
            mmu_logical_write_enable <= 1;

            mmu_action_ready <= 1;
          end else if (reg_int) begin
            int_memory_start_page[mmu_address_a] <= mmu_address_b;
            int_memory_end_page[mmu_address_a] <= mmu_address_d;

            mmu_action_ready <= 1;
          end
        end
        MMU_SWITCH: begin
          //new process
          mmu_start_process_physical_page <= mmu_logical_read_value;
          mmu_start_process_physical_page_zero <= mmu_address_a;
          mmu_logical_write_addr <= mmu_address_a;
          mmu_logical_write_value <= 0;
          mmu_action_ready <= 1;

          if (TASK_SWITCHER_DEBUG && !HARDWARE_DEBUG)
            $display(
                $time - starttime,
                " switching mmu end zero=",
                mmu_address_a,
                " real start =",
                mmu_logical_read_value
            );

          stage <= MMU_IDLE;
        end
        MMU_SEARCH: begin
          //          mmu_cache_write_addr <= mmu_search_position;
          //          mmu_cache_write_value <= 256*mmu_start_process_physical_page_zero+mmu_address_to_search_page;
          //          mmu_cache_write_value <= 1;
          //          if (mmu_cache_read_value_1==mmu_start_process_physical_page_zero && mmu_cache_read_value_2!=0) begin
          //            if (MMU_TRANSLATION_DEBUG && !HARDWARE_DEBUG)
          //              $display(
          //                  $time-starttime, " physical page in position (from cache) ", mmu_cache_read_value_2
          //              );
          //            mmu_address_c <= mmu_address_a % MMU_PAGE_SIZE + mmu_cache_read_value_2 * MMU_PAGE_SIZE;
          //            stage <= MMU_IDLE;
          //            mmu_action_ready <= 1;
          //          end else if (mmu_logical_read_value == mmu_address_to_search_page) begin
          if (mmu_logical_read_value == mmu_address_to_search_page) begin
            if (MMU_TRANSLATION_DEBUG && !HARDWARE_DEBUG)
              $display($time - starttime, " physical page in position ", mmu_search_position);
            mmu_address_c <= mmu_address_a % MMU_PAGE_SIZE + mmu_search_position * MMU_PAGE_SIZE;
            //move found address to the beginning to speed up search in the future       
            if ((int_search && int_source_process_page != mmu_search_position) ||            
                (!int_search && mmu_start_process_physical_page != mmu_search_position)) begin
              mmu_chain_write_addr <= mmu_prev_search_position;
              mmu_chain_write_value <= mmu_chain_read_value == mmu_search_position? mmu_prev_search_position:mmu_chain_read_value;
              mmu_chain_write_enable <= 1;
              stage <= MMU_SEARCH2;
            end else begin
              stage <= MMU_IDLE;
              mmu_action_ready <= 1;
            end
          end else if (mmu_chain_read_value == mmu_search_position) begin
            if (MMU_TRANSLATION_DEBUG && !HARDWARE_DEBUG)
              $display($time - starttime, " needs to allocate new memory page");
            stage <= MMU_ALLOCATE_NEW;
          end else begin
            mmu_prev_search_position <= mmu_search_position;
            mmu_search_position <= mmu_chain_read_value;
            mmu_chain_read_addr <= mmu_chain_read_value;
            mmu_logical_read_addr <= mmu_chain_read_value;
          end
        end
        MMU_SEARCH2: begin
          mmu_chain_write_addr <= mmu_search_position;
          mmu_chain_write_value <= int_search? int_source_process_page:mmu_start_process_physical_page;
          if (MMU_TRANSLATION_DEBUG && !HARDWARE_DEBUG)
            $display($time - starttime, " new start entry point ", mmu_search_position);
          if (int_search) begin
            int_source_process_page <= mmu_search_position;
          end else begin
            mmu_start_process_physical_page <= mmu_search_position;
          end
          stage <= MMU_IDLE;
          mmu_action_ready <= 1;
        end
        MMU_ALLOCATE_NEW: begin
          if (mmu_chain_read_value == 0 && mmu_logical_read_value == 0) begin
            //            mmu_cache_write_addr <= mmu_first_possible_free_physical_page;
            //            mmu_cache_write_value <= 256*mmu_start_process_physical_page_zero+mmu_logical_read_value;
            //            mmu_cache_write_value <= 1;

            mmu_chain_write_addr <= mmu_search_position;
            mmu_chain_write_value <= mmu_first_possible_free_physical_page;
            mmu_chain_write_enable <= 1;

            stage <= MMU_ALLOCATE_NEW2;
          end else begin
            //            mmu_cache_write_value <= 0;
            mmu_first_possible_free_physical_page <= mmu_first_possible_free_physical_page + 1;
            mmu_chain_read_addr <= mmu_first_possible_free_physical_page;
            mmu_logical_read_addr <= mmu_first_possible_free_physical_page;
          end
        end
        MMU_ALLOCATE_NEW2: begin
          mmu_chain_write_addr <= mmu_first_possible_free_physical_page;
          mmu_chain_write_value <= mmu_first_possible_free_physical_page;
          mmu_chain_write_enable <= 1;

          mmu_logical_write_addr <= mmu_first_possible_free_physical_page;
          mmu_logical_write_value <= mmu_address_to_search_page;
          mmu_logical_write_enable <= 1;

          if (MMU_TRANSLATION_DEBUG && !HARDWARE_DEBUG)
            $display(
                $time - starttime,
                " physical page in position (new allocated) ",
                mmu_first_possible_free_physical_page
            );
          mmu_address_c <= mmu_address_a % MMU_PAGE_SIZE + mmu_first_possible_free_physical_page * MMU_PAGE_SIZE;
          mmu_first_possible_free_physical_page <= mmu_first_possible_free_physical_page + 1;
          mmu_action_ready <= 1;
          stage <= MMU_IDLE;
        end
        MMU_DELETE: begin
          mmu_first_possible_free_physical_page <= mmu_first_possible_free_physical_page > mmu_search_position ? 
            mmu_search_position: mmu_first_possible_free_physical_page;
          if (mmu_chain_read_value == mmu_search_position) begin
            mmu_logical_write_addr <= mmu_search_position;
            mmu_chain_write_addr <= mmu_search_position;
            mmu_action_ready <= 1;
            stage <= MMU_IDLE;
          end else begin
            mmu_logical_write_addr <= mmu_search_position;
            mmu_chain_write_addr <= mmu_search_position;
            mmu_search_position <= mmu_chain_read_value;
            mmu_chain_read_addr <= mmu_chain_read_value;
          end
          mmu_logical_write_value <= 0;
          mmu_chain_write_value <= 0;
          mmu_logical_write_enable <= 1;
          mmu_chain_write_enable <= 1;

          //          mmu_cache_write_addr <= mmu_search_position;
          //          mmu_cache_write_value <= 0;
          //          mmu_cache_write_value <= 1;
        end
        MMU_SPLIT: begin
          //  $display($time-starttime, " ", mmu_search_position, " ", mmu_logical_read_value, " ", mmu_address_a, //DEBUG info
          //          " ", mmu_address_b); //DEBUG info
          if (mmu_logical_read_value >= mmu_address_a && mmu_logical_read_value <= mmu_address_b) begin
            //update old process chain
            mmu_chain_write_addr <= mmu_prev_search_position;
            mmu_chain_write_value <= mmu_chain_read_value;
            mmu_chain_write_enable <= 1;
            //update new process chain
            mmu_logical_write_addr <= mmu_search_position;
            mmu_logical_write_value <= mmu_logical_read_value == mmu_address_a ? mmu_search_position:mmu_logical_read_value - mmu_address_a;
            mmu_logical_write_enable <= 1;

            mmu_new_search_position <= mmu_search_position;
            if (mmu_logical_read_value == mmu_address_a) begin
              mmu_address_c <= mmu_search_position;
              //update cache
              //              mmu_cache_write_addr <= mmu_search_position;
              //              mmu_cache_write_value <= mmu_logical_read_value == mmu_address_a ? mmu_search_position:mmu_logical_read_value - mmu_address_a;
              //              mmu_cache_write_value <= 1;
            end else begin
              stage <= MMU_SPLIT2;
              //update cache
              //              mmu_cache_write_addr <= mmu_address_c;
              //              mmu_cache_write_value <= mmu_logical_read_value == mmu_address_a ? mmu_search_position:mmu_logical_read_value - mmu_address_a;
              //              mmu_cache_write_value <= 1;
            end
          end else begin
            mmu_chain_write_enable   <= 0;
            mmu_logical_write_enable <= 0;
            mmu_prev_search_position <= mmu_search_position;
          end
          if (mmu_chain_read_value == mmu_search_position) begin
            //close both chains
            stage <= MMU_SPLIT3;
          end else begin
            mmu_search_position   <= mmu_chain_read_value;
            mmu_chain_read_addr   <= mmu_chain_read_value;
            mmu_logical_read_addr <= mmu_chain_read_value;
          end
        end
        MMU_SPLIT2: begin
          mmu_logical_write_enable <= 0;
          //update new process chain
          mmu_chain_write_addr <= mmu_new_search_position;
          mmu_chain_write_value <= mmu_search_position;
          mmu_new_search_position <= mmu_search_position;
          if (mmu_chain_read_value == mmu_search_position) begin
            //close both chains
            stage <= MMU_SPLIT3;
          end else begin
            mmu_search_position <= mmu_chain_read_value;
            mmu_chain_read_addr <= mmu_chain_read_value;
            mmu_logical_read_addr <= mmu_chain_read_value;
            stage <= MMU_SPLIT;
          end
        end
        MMU_SPLIT3: begin
          mmu_chain_write_addr <= mmu_new_search_position;
          mmu_chain_write_value <= mmu_new_search_position;
          stage <= MMU_SPLIT4;
        end
        MMU_SPLIT4: begin
          mmu_chain_write_addr <= mmu_prev_search_position;
          mmu_chain_write_value <= mmu_prev_search_position;
          mmu_action_ready <= 1;
          stage <= MMU_IDLE;
        end
        MMU_INIT: begin
          if (mmu_chain_write_addr > 0) begin
            mmu_chain_write_value<=mmu_chain_write_addr<9?chain_init_ram[mmu_chain_write_addr-1]:0;
            mmu_chain_write_addr <= mmu_chain_write_addr - 1;

            mmu_logical_write_value<=mmu_logical_write_addr<9?logical_init_ram[mmu_logical_write_addr-1]:0;
            mmu_logical_write_addr <= mmu_logical_write_addr - 1;
          end else begin
            mmu_action_ready <= 1;
            mmu_chain_write_enable <= 0;
            mmu_logical_write_enable <= 0;
            mmu_start_process_physical_page <= 0;
            mmu_start_process_physical_page_zero <= 0;
            mmu_first_possible_free_physical_page <= 8;
            rst_can_be_done <= 1;
            starttime <= $time;
            stage <= MMU_IDLE;
          end
        end
      endcase
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
  bit [15:0] read_address2;
  wire [15:0] read_value2;

  single_blockram single_blockram (
      .clk(clk),
      .write_enabled(write_enabled),
      .write_address(write_address),
      .write_value(write_value),
      .read_address(read_address),
      .read_value(read_value),
      .read_address2(read_address2),
      .read_value2(read_value2)
  );

  bit [7:0] uart_buffer[0:200];
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
  parameter OPCODE_PROC = 'h19;  //new process //how many pages, start page number (16 bit)
  parameter OPCODE_REG_INT = 'h1a;  //int number (8 bit), start memory page, end memory page 
  parameter OPCODE_INT = 'h1b;  //int number (8 bit), start memory page, end memory page
  parameter OPCODE_INT_RET = 'h1c;  //int number
  parameter OPCODE_RAM2OUT = 'h1d;  //port number, 16 bit source address 

  parameter OPCODE_TILL_VALUE =23;   //register num (8 bit), value (8 bit), how many instructions (8 bit value) // do..while
  parameter OPCODE_TILL_NON_VALUE=24;   //register num, value, how many instructions (8 bit value) //do..while
  parameter OPCODE_LOOP = 25;  //x, x, how many instructions (8 bit value) //for...
  parameter OPCODE_FREE = 31;  //free ram pages x-y 
  parameter OPCODE_FREE_LEVEL =32; //free ram pages allocated after page x (or pages with concrete level)

  parameter STAGE_AFTER_RESET = 1;
  parameter STAGE_GET_1_BYTE = 2;
  parameter STAGE_CHECK_MMU_ADDRESS = 3;
  parameter STAGE_SET_PC = 4;  //jump instructions
  parameter STAGE_GET_PARAM_BYTE = 5;
  parameter STAGE_SET_PARAM_BYTE = 6;
  parameter STAGE_GET_RAM_BYTE = 7;
  parameter STAGE_SET_RAM_BYTE = 8;
  parameter STAGE_HLT = 9;
  parameter STAGE_ALU = 10;
  parameter STAGE_DELETE_PROCESS = 11;
  parameter STAGE_SPLIT_PROCESS = 12;
  parameter STAGE_REG_INT = 14;
  parameter STAGE_REG_INT2 = 15;
  parameter STAGE_INT = 16;
  /*task switching*/
  parameter STAGE_READ_SAVE_PC = 17;
  parameter STAGE_READ_REG = 18;
  parameter STAGE_READ_NEXT_NEXT_PROCESS = 19;
  parameter STAGE_SAVE_NEXT_PROCESS = 20;
  parameter STAGE_SPLIT_PROCESS2 = 21;
  parameter STAGE_SPLIT_PROCESS3 = 22;
  parameter STAGE_SPLIT_PROCESS4 = 23;
  parameter STAGE_SPLIT_PROCESS5 = 24;
  parameter STAGE_SAVE_NEXT_PROCESS2 = 25;
  parameter STAGE_TASK_SWITCHER = 26;
  parameter STAGE_READ_SAVE_REG_USED = 27;

  parameter STAGE_SET_PORT = 28;

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
  parameter ADDRESS_REG = 10;
  parameter ADDRESS_PROGRAM = ADDRESS_REG + 32;

  bit [4:0] how_many = 1;  //how many instructions were executed
  bit rst_can_be_done = 1;

  //all processes (including current)
  bit [15:0] pc[0:2], physical_pc[0:2], mmu_page_offset[0:2], process_address[0:2];
  bit process_used[0:2];
  bit [5:0] error_code[0:2];
  bit [15:0] registers[0:2][0:31];  //512 bits = 32 x 16-bit registers
bit [0:31] registers_updated[0:2];

  //current process
  bit [4:0] process_num = 0, temp_process_num;  //index for tables above
  bit [15:0] prev_process_address = 0, next_process_address = 0;
  bit [0:31] temp_registers_updated;

  //instruction execution
  bit [7:0] stage, stage_after_mmu;
  bit [5:0] ram_read_save_reg_start, ram_read_save_reg_end;
  bit [7:0] alu_op, alu_num;
  bit [7:0] instruction1_1;
  bit [7:0] instruction1_2;
  bit [4:0] instruction1_2_1;
  bit [2:0] instruction1_2_2;
  bit [7:0] instruction2_1;
  bit [7:0] instruction2_2;

  assign instruction1_1   = read_value[15:8];
  assign instruction1_2   = read_value[7:0];
  assign instruction1_2_1 = read_value[4:0];
  assign instruction1_2_2 = read_value[7:5];
  assign instruction2_1   = read_value2[15:8];
  assign instruction2_2   = read_value2[7:0];

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

  bit mmu_search_address = 0;
  bit mmu_set_start_process_physical_page;
  bit mmu_delete_process;
  bit mmu_split_process;
  bit mmu_add_shared_mem;
  bit mmu_delete_shared_mem;
  bit mmu_reg_int;
  bit [15:0] mmu_address_a, mmu_address_b, mmu_address_d;
  wire [15:0] mmu_address_c;
  wire mmu_action_ready;
  wire [10:0] starttime;

  mmu mmu (
      .clk(clk),
      .reset(reset),
      .search_mmu_address(mmu_search_address),
      .set_mmu_start_process_physical_page(mmu_set_start_process_physical_page),
      .mmu_delete_process(mmu_delete_process),
      .mmu_split_process(mmu_split_process),
      .add_shared_mem(mmu_add_shared_mem),
      .delete_shared_mem(mmu_delete_shared_mem),
      .reg_int(mmu_reg_int),
      .mmu_address_a(mmu_address_a),
      .mmu_address_b(mmu_address_b),
      .mmu_address_c(mmu_address_c),
      .mmu_address_d(mmu_address_d),
      .mmu_action_ready(mmu_action_ready),
      .starttime(starttime)
  );

  bit [15:0] int_pc[0:255];
  bit [15:0] int_process_address[0:255];

  `define MAKE_MMU_SEARCH(ARG, ARG2) \
      mmu_address_a <= ARG; \
      mmu_search_address <= 1; \
      stage_after_mmu <= ARG2; \
      stage <= STAGE_CHECK_MMU_ADDRESS;

  `define MAKE_MMU_SEARCH2 \
        if (how_many==HOW_MANY_OP_PER_TASK_SIMULATE && process_address[process_num] != next_process_address) begin \
        how_many <= 0; \
        stage <= STAGE_TASK_SWITCHER; \
      end else begin \
        how_many <= how_many + 1; \
        if (mmu_page_offset[process_num] == 2) begin \
          mmu_address_a <= pc[process_num]; \
          mmu_search_address <= 1; \
          stage_after_mmu <= STAGE_GET_1_BYTE; \
          stage <= STAGE_CHECK_MMU_ADDRESS; \
        end else begin \
          mmu_page_offset[process_num] <= mmu_page_offset[process_num] - 2; \
          read_address  <= physical_pc[process_num] + 2; \
          read_address2 <= physical_pc[process_num] + 3; \
          stage <= STAGE_GET_1_BYTE; \
          physical_pc[process_num] <= physical_pc[process_num] + 2; \
        end \
      end

  `define MAKE_SWITCH_TASK(ARG) \
     if (ARG==0) how_many <= 0; \
    // if (TASK_SWITCHER_DEBUG && !HARDWARE_DEBUG) \
            $display("\n\n",$time-starttime, " TASK SWITCHER from ", process_address[process_num], " to ", next_process_address); \
     for (i=0;i<3;i=i+1) begin \
       if (process_used[i] && process_address[i] == next_process_address) begin \
            prev_process_address <= process_address[process_num]; \
         process_num <= i; \
       end \
       if (!process_used[i]) temp_process_num<= i; \
     end \
     write_enabled <= ARG; \
     mmu_set_start_process_physical_page <= 1; \
     mmu_address_a <= next_process_address / MMU_PAGE_SIZE; \
     read_address <= next_process_address + ADDRESS_PC; \
     stage <= STAGE_READ_SAVE_PC;

  integer i;  //DEBUG info

  always @(negedge clk) begin
    if (reset == 1 && rst_can_be_done == 1) begin
      rst_can_be_done <= 0;
      if (OTHER_DEBUG && !HARDWARE_DEBUG) $display($time - starttime, " reset");  //DEBUG info

      error_code <= '{default: 0};
      registers <= '{default: 0};
      registers_updated <= '{default: 0};

      instructions <= 0;

      process_used = '{default: 0};

      stage <= STAGE_AFTER_RESET;
    end else if (stage == STAGE_AFTER_RESET) begin
      if (mmu_action_ready) begin
        process_num <= 0;
        process_used[0] <= 1;
        process_address[0] <= 0;
        error_code[0] <= ERROR_NONE;
        pc[0] <= ADDRESS_PROGRAM;
        physical_pc[0] <= ADDRESS_PROGRAM;
        mmu_page_offset[0] <= MMU_PAGE_SIZE - ADDRESS_PROGRAM;

        read_address <= ADDRESS_PROGRAM; //we start from page number 0 in first process, don't need MMU translation
        read_address2 <= ADDRESS_PROGRAM + 1;

        next_process_address <= 4 * MMU_PAGE_SIZE;

        uart_buffer_available = 0;
        `HARD_DEBUG("\n");  //DEBUG info
        `HARD_DEBUG("S");  //DEBUG info

        rst_can_be_done <= 1;
        stage <= STAGE_GET_1_BYTE;
      end
    end else if (instructions < HOW_MANY_OP_SIMULATE && error_code[process_num] == ERROR_NONE) begin
      if (STAGE_DEBUG && !HARDWARE_DEBUG) begin  //DEBUG info
        $write($time - starttime, " stage ", stage, " ");  //DEBUG info
        case (stage)  //DEBUG info
          STAGE_AFTER_RESET: $write("STAGE_AFTER_RESET");  //DEBUG info
          STAGE_GET_1_BYTE: $write("STAGE_GET_1_BYTE");  //DEBUG info
          STAGE_CHECK_MMU_ADDRESS: $write("STAGE_CHECK_MMU_ADDRESS");  //DEBUG info
          STAGE_SET_PC: $write("STAGE_SET_PC");  //DEBUG info
          STAGE_GET_PARAM_BYTE: $write("STAGE_GET_PARAM_BYTE");  //DEBUG info
          STAGE_SET_PARAM_BYTE: $write("STAGE_SET_PARAM_BYTE");  //DEBUG info
          STAGE_GET_RAM_BYTE: $write("STAGE_GET_RAM_BYTE");  //DEBUG info
          STAGE_SET_RAM_BYTE: $write("STAGE_SET_RAM_BYTE");  //DEBUG info
          STAGE_HLT: $write("STAGE_HLT");  //DEBUG info
          STAGE_ALU: $write("STAGE_ALU");  //DEBUG info
          STAGE_DELETE_PROCESS: $write("STAGE_DELETE_PROCESS");  //DEBUG info
          STAGE_SPLIT_PROCESS: $write("STAGE_SPLIT_PROCESS");  //DEBUG info
          STAGE_REG_INT: $write("STAGE_REG_INT");  //DEBUG info
          STAGE_REG_INT2: $write("STAGE_REG_INT2");  //DEBUG info
          STAGE_INT: $write("STAGE_INT");  //DEBUG info
          STAGE_READ_SAVE_PC: $write("STAGE_READ_SAVE_PC");  //DEBUG info
          STAGE_READ_REG: $write("STAGE_READ_REG");  //DEBUG info
          STAGE_READ_NEXT_NEXT_PROCESS: $write("STAGE_READ_NEXT_NEXT_PROCESS");  //DEBUG info
          STAGE_SAVE_NEXT_PROCESS: $write("STAGE_SAVE_NEXT_PROCESS");  //DEBUG info
          STAGE_SPLIT_PROCESS2: $write("STAGE_SPLIT_PROCESS2");  //DEBUG info
          STAGE_SPLIT_PROCESS3: $write("STAGE_SPLIT_PROCESS3");  //DEBUG info
          STAGE_SPLIT_PROCESS4: $write("STAGE_SPLIT_PROCESS4");  //DEBUG info
          STAGE_SPLIT_PROCESS5: $write("STAGE_SPLIT_PROCESS5");  //DEBUG info
          STAGE_SAVE_NEXT_PROCESS2: $write("STAGE_SAVE_NEXT_PROCESS2");  //DEBUG info
          STAGE_TASK_SWITCHER: $write("STAGE_TASK_SWITCHER");  //DEBUG info
          STAGE_READ_SAVE_REG_USED: $write("STAGE_READ_SAVE_REG_USED");  //DEBUG info
        endcase  //DEBUG info
        $display(" pc ", pc[process_num]);  //DEBUG info
      end  //DEBUG info
      // (*parallel_case *)(*full_case *) 
      case (stage)
        STAGE_GET_1_BYTE: begin
          write_enabled <= 0;
          if (READ_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
            $display(  //DEBUG info
                $time - starttime,  //DEBUG info
                " read ready ",  //DEBUG info
                read_address,  //DEBUG info
                "=",  //DEBUG info
                read_value,  //DEBUG info
                " ",  //DEBUG info
                read_address2,  //DEBUG info
                "=",  //DEBUG info
                read_value2  //DEBUG info
            );  //DEBUG info
          `HARD_DEBUG("a");  //DEBUG info
          if (OP_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
            $display(  //DEBUG info
                $time - starttime,  //DEBUG info
                process_address[process_num],  //DEBUG info
                " pc ",  //DEBUG info
                (pc[process_num]),  //DEBUG info
                " b1 %c",  //DEBUG info
                instruction1_1 / 16 >= 10 ? instruction1_1 / 16 + 65 - 10 : instruction1_1 / 16 + 48, //DEBUG info
                "%c",  //DEBUG info
                instruction1_1 % 16 >= 10 ? instruction1_1 % 16 + 65 - 10 : instruction1_1 % 16 + 48, //DEBUG info
                "%c",  //DEBUG info
                instruction1_2 / 16 >= 10 ? instruction1_2 / 16 + 65 - 10 : instruction1_2 / 16 + 48, //DEBUG info
                "%c",  //DEBUG info
                instruction1_2 % 16 >= 10 ? instruction1_2 % 16 + 65 - 10 : instruction1_2 % 16 + 48, //DEBUG info
                "h (",  //DEBUG info
                instruction1_2_1,  //DEBUG info
                "-",  //DEBUG info
                instruction1_2_2,  //DEBUG info
                ") b2 ",  //DEBUG info
                read_value2  //DEBUG info
            );  //DEBUG info
          pc[process_num] <= pc[process_num] + 2;
          `HARD_DEBUG2(instruction1_1);  //DEBUG info
          `HARD_DEBUG2(instruction1_2);  //DEBUG info
          //(*parallel_case *) (*full_case *) 
          case (instruction1_1)
            //24 bit target address
            OPCODE_JMP: begin
              if ((read_value2 + (256 * 256) * instruction1_2) % 2 == 1) begin
                error_code[process_num] <= ERROR_WRONG_ADDRESS;
              end else begin
                if (OP2_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
                  $display(  //DEBUG info
                      $time - starttime,
                      " opcode = jmp to ",
                      (read_value2 + (256 * 256) * instruction1_2)  //DEBUG info
                  );  //DEBUG info
                pc[process_num] <= (read_value2 + (256 * 256) * instruction1_2);
                stage <= STAGE_SET_PC;
              end
            end
            //x, register num with target addr (we read one reg)
            OPCODE_JMP16: begin
              if (read_value2 >= 32) begin
                error_code[process_num] <= ERROR_WRONG_REG_NUM;
              end else if ((registers[process_num][read_value2] - 1) % 2 == 1) begin
                error_code[process_num] <= ERROR_WRONG_ADDRESS;
              end else begin
                if (OP2_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
                  $display(  //DEBUG info
                      $time - starttime,
                      " opcode = jmp to ",
                      (registers[process_num][read_value2] - 1)  //DEBUG info
                  );  //DEBUG info
                pc[process_num] <= registers[process_num][read_value2];
                stage <= STAGE_SET_PC;
              end
            end
            //x, register num with target addr (we read one reg)
            OPCODE_JMP_PLUS: begin
              if (OP2_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
                $display(  //DEBUG info
                    $time - starttime,  //DEBUG info
                    " opcode = jmp plus to ",  //DEBUG info
                    pc[process_num] + read_value2 * 2 - 1,  //DEBUG info
                    " (",  //DEBUG info
                    read_value2,  //DEBUG info
                    " instructions)"  //DEBUG info
                );  //DEBUG info      
              pc[process_num] <= pc[process_num] + read_value2 * 2 - 1;
              stage <= STAGE_SET_PC;
            end
            //x, register num with info (we read one reg)
            OPCODE_JMP_PLUS16: begin
              if (read_value2 >= 32) begin
                error_code[process_num] <= ERROR_WRONG_REG_NUM;
              end else begin
                if (OP2_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
                  $display(  //DEBUG info
                      $time - starttime,  //DEBUG info
                      " opcode = jmp plus16 to ",  //DEBUG info
                      pc[process_num] + registers[process_num][read_value2] * 2 - 1,  //DEBUG info
                      " (",  //DEBUG info
                      registers[read_value2],  //DEBUG info
                      " instructions)"  //DEBUG info
                  );  //DEBUG info
                pc[process_num] <= pc[process_num] + registers[process_num][read_value2] * 2 - 1;
                stage <= STAGE_SET_PC;
              end
            end
            //x, 16 bit how many instructions
            OPCODE_JMP_MINUS: begin
              if (pc[process_num] - read_value2 * 2 < ADDRESS_PROGRAM) begin
                error_code[process_num] <= ERROR_WRONG_ADDRESS;
              end else begin
                if (OP2_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
                  $display(  //DEBUG info
                      $time - starttime,  //DEBUG info
                      " opcode = jmp minus to ",  //DEBUG info
                      pc[process_num] - read_value2 * 2 - 1,  //DEBUG info
                      " (",  //DEBUG info
                      read_value2,  //DEBUG info
                      " instructions)"  //DEBUG info
                  );  //DEBUG info
                pc[process_num] <= pc[process_num] - read_value2 * 2 - 1;
                stage <= STAGE_SET_PC;
              end
            end
            //x, register num with info (we read one reg)
            OPCODE_JMP_MINUS16: begin
              if (read_value2 >= 32) begin
                error_code[process_num] <= ERROR_WRONG_REG_NUM;
              end else if (pc[process_num] - registers[process_num][read_value2] * 2 < ADDRESS_PROGRAM) begin
                error_code[process_num] <= ERROR_WRONG_ADDRESS;
              end else begin
                if (OP2_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
                  $display(  //DEBUG info
                      $time - starttime,  //DEBUG info
                      " opcode = jmp minus16 to ",  //DEBUG info
                      pc[process_num] - registers[process_num][read_value2] * 2 - 1,  //DEBUG info
                      " (",  //DEBUG info
                      registers[read_value2],  //DEBUG info
                      " instructions)"  //DEBUG info
                  );  //DEBUG info
                pc[process_num] <= pc[process_num] - registers[process_num][read_value2] * 2 - 1;
                stage = STAGE_SET_PC;
              end
            end
            //register num (5 bits), how many-1 (3 bits), 16 bit source addr //ram -> reg
            OPCODE_RAM2REG: begin
              if (instruction1_2_1 + instruction1_2_2 >= 32) begin
                error_code[process_num] <= ERROR_WRONG_REG_NUM;
              end else if (read_value2 < ADDRESS_PROGRAM) begin
                error_code[process_num] <= ERROR_WRONG_ADDRESS;
              end else begin
                if (OP2_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
                  $display(  //DEBUG info
                      $time - starttime,  //DEBUG info
                      " opcode = ram2reg read value from address ",  //DEBUG info
                      read_value2,  //DEBUG info
                      "+ to reg ",  //DEBUG info
                      instruction1_2_1,  //DEBUG info
                      "-",  //DEBUG info
                      (instruction1_2_1 + instruction1_2_2)  //DEBUG info
                  );  //DEBUG info
                ram_read_save_reg_start <= instruction1_2_1;
                ram_read_save_reg_end   <= instruction1_2_1 + instruction1_2_2;
                `MAKE_MMU_SEARCH(read_value2, STAGE_GET_RAM_BYTE);
              end
            end
            //start register num, how many registers, register num with source addr (we read one reg), //ram -> reg
            OPCODE_RAM2REG16: begin
              if (instruction1_2 + instruction2_1 >= 32 || instruction2_2 >= 32) begin
                error_code[process_num] <= ERROR_WRONG_REG_NUM;
              end else if (read_value2 < ADDRESS_PROGRAM) begin
                error_code[process_num] <= ERROR_WRONG_ADDRESS;
              end else begin
                if (OP2_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
                  $display(  //DEBUG info
                      $time - starttime,  //DEBUG info
                      " opcode = ram2reg16 read from ram (address ",  //DEBUG info
                      registers[instruction2_2],  //DEBUG info
                      "+) to reg ",  //DEBUG info
                      instruction1_2,  //DEBUG info
                      "-",  //DEBUG info
                      (instruction1_2 + instruction2_1)  //DEBUG info
                  );  //DEBUG info
                ram_read_save_reg_start <= instruction1_2;
                ram_read_save_reg_end   <= instruction1_2 + instruction2_1;
                `MAKE_MMU_SEARCH(registers[process_num][instruction2_2], STAGE_GET_RAM_BYTE);
              end
            end
            //register num (5 bits), how many-1 (3 bits), 16 bit target addr //reg -> ram
            OPCODE_REG2RAM: begin
              if (instruction1_2_1 + instruction1_2_2 >= 32) begin
                error_code[process_num] <= ERROR_WRONG_REG_NUM;
              end else if (read_value2 < ADDRESS_PROGRAM) begin
                error_code[process_num] <= ERROR_WRONG_ADDRESS;
              end else begin
                if (OP2_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
                  $display(  //DEBUG info
                      $time - starttime,  //DEBUG info
                      " opcode = reg2ram save reg ",  //DEBUG info
                      instruction1_2_1,  //DEBUG info
                      "-",  //DEBUG info
                      (instruction1_2_1 + instruction1_2_2),  //DEBUG info
                      " to ram address ",  //DEBUG info
                      read_value2,  //DEBUG info
                      "+"  //DEBUG info
                  );  //DEBUG info
                ram_read_save_reg_start <= instruction1_2_1;
                ram_read_save_reg_end <= instruction1_2_1 + instruction1_2_2;
                write_value <= registers[process_num][instruction1_2_1];
                `MAKE_MMU_SEARCH(read_value2, STAGE_SET_RAM_BYTE);
              end
            end
            //start register num, how many registers, register num with target addr (we read one reg), //reg -> ram
            OPCODE_REG2RAM16: begin
              if (instruction1_2 + instruction2_1 >= 32 || instruction2_2 >= 32) begin
                error_code[process_num] <= ERROR_WRONG_REG_NUM;
              end else if (read_value2 < ADDRESS_PROGRAM) begin
                error_code[process_num] <= ERROR_WRONG_ADDRESS;
              end else begin
                if (OP2_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
                  $display(  //DEBUG info
                      $time - starttime,  //DEBUG info
                      " opcode = reg2ram16 save to ram (address ",  //DEBUG info
                      registers[instruction2_2],  //DEBUG info
                      "+) from reg ",  //DEBUG info
                      instruction1_2,  //DEBUG info
                      "-",  //DEBUG info
                      (instruction1_2 + instruction2_1)  //DEBUG info
                  );  //DEBUG info
                ram_read_save_reg_start <= instruction1_2;
                ram_read_save_reg_end <= instruction1_2 + instruction2_1;
                write_value <= registers[process_num][instruction1_2];
                `MAKE_MMU_SEARCH(registers[process_num][instruction2_2], STAGE_SET_RAM_BYTE);
              end
            end
            //register num (5 bits), how many-1 (3 bits), 16 bit value //value -> reg
            OPCODE_NUM2REG: begin
              if (OP2_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
                $display(  //DEBUG info
                    $time - starttime,  //DEBUG info
                    " opcode = num2reg save value ",  //DEBUG info
                    read_value2,  //DEBUG info
                    " to reg ",  //DEBUG info
                    instruction1_2_1,  //DEBUG info
                    "-",  //DEBUG info
                    (instruction1_2_1 + instruction1_2_2)  //DEBUG info
                );  //DEBUG info
              alu_op  <= ALU_SET;
              alu_num <= instruction1_2_1;
              stage   <= STAGE_ALU;
            end
            //register num (5 bits), how many-1 (3 bits), 16 bit value // reg += value
            OPCODE_REG_PLUS: begin
              if (OP2_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
                $display(  //DEBUG info
                    $time - starttime,  //DEBUG info
                    " opcode = regplus add value ",  //DEBUG info
                    read_value2,  //DEBUG info
                    " to reg ",  //DEBUG info
                    instruction1_2_1,  //DEBUG info
                    "-",  //DEBUG info
                    (instruction1_2_1 + instruction1_2_2)  //DEBUG info
                );  //DEBUG info
              alu_op  <= ALU_ADD;
              alu_num <= 255;
              stage   <= STAGE_ALU;
            end
            //register num (5 bits), how many-1 (3 bits), 16 bit value // reg -= value
            OPCODE_REG_MINUS: begin
              if (OP2_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
                $display(  //DEBUG info
                    $time - starttime,  //DEBUG info
                    " opcode = regminus dec value ",  //DEBUG info
                    read_value2,  //DEBUG info
                    " to reg ",  //DEBUG info
                    instruction1_2_1,  //DEBUG info
                    "-",  //DEBUG info
                    (instruction1_2_1 + instruction1_2_2)  //DEBUG info
                );  //DEBUG info
              alu_op  <= ALU_DEC;
              alu_num <= 255;
              stage   <= STAGE_ALU;
            end
            //register num (5 bits), how many-1 (3 bits), 16 bit value // reg *= value
            OPCODE_REG_MUL: begin
              if (OP2_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
                $display(  //DEBUG info
                    $time - starttime,  //DEBUG info
                    " opcode = regmul mul value ",  //DEBUG info
                    read_value2,  //DEBUG info
                    " to reg ",  //DEBUG info
                    instruction1_2_1,  //DEBUG info
                    "-",  //DEBUG info
                    (instruction1_2_1 + instruction1_2_2)  //DEBUG info
                );  //DEBUG info
              alu_op  <= ALU_MUL;
              alu_num <= 255;
              stage   <= STAGE_ALU;
            end
            //register num (5 bits), how many-1 (3 bits), 16 bit value // reg /= value
            OPCODE_REG_DIV: begin
              if (read_value2 == 0) begin
                error_code[process_num] <= ERROR_DIVIDE_BY_ZERO;
              end else begin
                if (OP2_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
                  $display(  //DEBUG info
                      $time - starttime,  //DEBUG info
                      " opcode = regdiv div value ",  //DEBUG info
                      read_value2,  //DEBUG info
                      " to reg ",  //DEBUG info
                      instruction1_2_1,  //DEBUG info
                      "-",  //DEBUG info
                      (instruction1_2_1 + instruction1_2_2)  //DEBUG info
                  );  //DEBUG info
                alu_op <= ALU_DIV;
                stage  <= STAGE_ALU;
              end
            end
            //exit process
            OPCODE_EXIT: begin
              if (OP2_DEBUG && !HARDWARE_DEBUG)
                $display($time - starttime, " opcode = exit");  //DEBUG info
              mmu_delete_process <= 1;
              write_address <= prev_process_address + ADDRESS_NEXT_PROCESS;
              write_value <= next_process_address;
              write_enabled <= 1;
              stage <= STAGE_DELETE_PROCESS;
            end
            //new process //how many pages, start page number (16 bit
            OPCODE_PROC: begin
              if (OP2_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
                $display(  //DEBUG info
                    $time - starttime,  //DEBUG info
                    " opcode = proc, pages ",  //DEBUG info
                    read_value2,  //DEBUG info
                    "-",  //DEBUG info
                    (read_value2 + instruction1_2)  //DEBUG info
                );  //DEBUG info
              mmu_address_a <= read_value2;
              mmu_address_b <= read_value2 + instruction1_2;
              mmu_split_process <= 1;
              stage <= STAGE_SPLIT_PROCESS;
            end
            //int number (8 bit), start memory page, end memory page 
            OPCODE_REG_INT: begin
              if (OP2_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
                $display(
                    $time - starttime,
                    " opcode = reg_int ",
                    instruction1_2,
                    " logical pages",
                    instruction2_1,
                    "-",
                    instruction2_2
                );  //DEBUG info
              int_pc[instruction1_2] <= pc[process_num];
              int_process_address[instruction1_2] <= process_address[process_num];
              mmu_reg_int <= 1;
              mmu_address_a <= instruction1_2;
              mmu_address_b <= instruction2_1;
              mmu_address_d <= instruction2_2;
              //delete process from chain
              write_address <= prev_process_address + ADDRESS_NEXT_PROCESS;
              write_value <= next_process_address;
              write_enabled <= 1;
              stage <= STAGE_REG_INT;
            end
            //int number (8 bit), start memory page, end memory page 
            OPCODE_INT: begin
              if (OP2_DEBUG && !HARDWARE_DEBUG)
                $display(
                    $time - starttime,
                    " opcode = int ",
                    instruction1_2,
                    " pages ",
                    instruction2_1,
                    "-",
                    instruction2_2
                );  //DEBUG info
              //replace current process with int process in the chain 
              write_address <= int_process_address[instruction1_2] + ADDRESS_NEXT_PROCESS;
              write_value <= next_process_address;
              write_enabled <= 1;
              stage <= STAGE_INT;
              //fixme: add shared memory from current process to int process
              mmu_add_shared_mem <= 1;
              mmu_address_a <= instruction1_2;
              mmu_address_b <= instruction2_1;
              mmu_address_d <= instruction2_2;
            end
            //int number
            OPCODE_INT_RET: begin
              if (OP2_DEBUG && !HARDWARE_DEBUG)
                $display($time - starttime, " opcode = int_ret");  //DEBUG info
              //replace current process with int process in the chain 
              write_address <= int_process_address[instruction1_2] + ADDRESS_NEXT_PROCESS;
              write_value <= next_process_address;
              write_enabled <= 1;
              stage <= STAGE_INT;
              //fixme: remove shared memory from int process
              mmu_delete_shared_mem <= 1;
            end
            //port number, 16 bit source address 
            OPCODE_RAM2OUT: begin
              if (read_value2 < ADDRESS_PROGRAM) begin
                error_code[process_num] <= ERROR_WRONG_ADDRESS;
              end else begin
                if (OP2_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
                  $display(  //DEBUG info
                      $time - starttime,  //DEBUG info
                      " opcode = ram2out read value from address ",  //DEBUG info
                      read_value2,  //DEBUG info
                      "+ to port ",  //DEBUG info
                      instruction1_2  //DEBUG info
                  );  //DEBUG info          
                `MAKE_MMU_SEARCH(read_value2, STAGE_SET_PORT);
              end
            end
            default: begin
              if (OP2_DEBUG && !HARDWARE_DEBUG)
                $display($time - starttime, " opcode = unknown");  //DEBUG info
              `MAKE_MMU_SEARCH2;
              //if (instructions == HOW_MANY_OP_SIMULATE) search_mmu_address = 0; //DEBUG info
            end
          endcase
          instructions <= instructions + 1;
        end
        STAGE_SET_PORT: begin
          if (reset_uart_buffer_available) uart_buffer_available = 0;
          uart_buffer[uart_buffer_available++] = read_value / 256;
          //  $write("value ", read_value/256," ",read_value%256);
          //  $write("value ", read_value2/256," ",read_value2%256);
          `MAKE_MMU_SEARCH2
        end
        STAGE_GET_RAM_BYTE: begin
          registers[process_num][ram_read_save_reg_start] <= read_value;
          if (OP2_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
            $display(  //DEBUG info
                $time - starttime,  //DEBUG info
                " read value for reg ",  //DEBUG info
                ram_read_save_reg_start,  //DEBUG info
                " from address ",  //DEBUG info
                read_address,  //DEBUG info
                " = ",  //DEBUG info
                read_value  //DEBUG info
            );  //DEBUG info
          if (ram_read_save_reg_start == ram_read_save_reg_end) begin
            `MAKE_MMU_SEARCH2
          end else begin
            ram_read_save_reg_start <= ram_read_save_reg_start + 1;
            `MAKE_MMU_SEARCH(mmu_address_a + 1, STAGE_GET_RAM_BYTE);
          end
        end
        STAGE_SET_RAM_BYTE: begin
          if (ram_read_save_reg_start == ram_read_save_reg_end) begin
            if (OP2_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
              $display(  //DEBUG info
                  $time - starttime,  //DEBUG info
                  " save value ",
                  registers[process_num][ram_read_save_reg_start],
                  " from reg ",
                  ram_read_save_reg_start,
                  " to ram address ",
                  mmu_address_a
              );  //DEBUG info
            write_enabled <= 0;
            `MAKE_MMU_SEARCH2
          end else begin
            ram_read_save_reg_start <= ram_read_save_reg_start + 1;
            write_value <= registers[process_num][ram_read_save_reg_start];
            if (OP2_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
              $display(  //DEBUG info
                  $time - starttime,  //DEBUG info
                  " save value ",
                  registers[process_num][ram_read_save_reg_start+1],
                  " from reg ",
                  ram_read_save_reg_start + 1,
                  " to ram address ",
                  mmu_address_a + 1
              );  //DEBUG info

            `MAKE_MMU_SEARCH(mmu_address_a + 1, STAGE_SET_RAM_BYTE);
          end
        end
        STAGE_CHECK_MMU_ADDRESS: begin
          write_enabled <= 0;
          if (mmu_action_ready) begin
            if (stage_after_mmu != STAGE_SET_RAM_BYTE) begin
              if (stage_after_mmu == STAGE_GET_1_BYTE) begin
                mmu_page_offset[process_num] <= mmu_address_c % MMU_PAGE_SIZE;
                physical_pc[process_num] <= mmu_address_c;
              end
              read_address  <= mmu_address_c;
              read_address2 <= mmu_address_c + 1;
            end else begin
              write_address <= mmu_address_c;
              write_enabled <= 1;
            end
            stage <= stage_after_mmu;
          end
          mmu_search_address <= 0;
        end
        STAGE_ALU: begin
          if (ALU_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
            $display(  //DEBUG info
                $time - starttime,  //DEBUG info
                " alu_num ",  //DEBUG info
                alu_num,  //DEBUG info
                " alu_op ",  //DEBUG info
                alu_op,  //DEBUG info
                " end ",  //DEBUG info
                (instruction1_2_1 + instruction1_2_2)  //DEBUG info
            );  //DEBUG info
          if (instruction1_2_1 + instruction1_2_2 >= 32) begin
            error_code[process_num] <= ERROR_WRONG_REG_NUM;
          end else begin
            if (alu_num == 255) begin
              alu_num <= instruction1_2_1;
            end else begin
              case (alu_op)
                ALU_SET: begin
                  if (OP2_DEBUG && !HARDWARE_DEBUG)  //DEBUG info
                    $display(
                        $time - starttime, " set reg ", alu_num, " with ", read_value2
                    );  //DEBUG info
                  registers[process_num][alu_num] <= read_value2;
                  registers_updated[process_num][alu_num] <= read_value2 != 0;
                  write_value <= read_value2;
                end
                ALU_ADD: begin
                  registers[process_num][alu_num] <= plus_c;
                  registers_updated[process_num][alu_num] <= plus_c != 0;
                  write_value <= plus_c;
                end
                ALU_DEC: begin
                  registers[process_num][alu_num] <= minus_c;
                  registers_updated[process_num][alu_num] <= minus_c != 0;
                  write_value <= minus_c;
                end
                ALU_MUL: begin
                  registers[process_num][alu_num] <= mul_c;
                  registers_updated[process_num][alu_num] <= mul_c != 0;
                  write_value <= mul_c;
                end
                ALU_DIV: begin
                  registers[process_num][alu_num] <= div_c;
                  registers_updated[process_num][alu_num] <= div_c != 0;
                  write_value <= div_c;
                end
              endcase
              write_address <= process_address[process_num] + ADDRESS_REG + alu_num;
              write_enabled <= 1;
              alu_num <= alu_num + 1;
            end
            if (alu_num == instruction1_2_1 + instruction1_2_2) begin
              //write_enabled <= 0;
              `MAKE_MMU_SEARCH2
            end else begin
              case (alu_op)
                ALU_ADD: begin
                  plus_a = registers[process_num][alu_num];
                  plus_b = read_value2;
                end
                ALU_DEC: begin
                  minus_a = registers[process_num][alu_num];
                  minus_b = read_value2;
                end
                ALU_MUL: begin
                  mul_a = registers[process_num][alu_num];
                  mul_b = read_value2;
                end
                ALU_DIV: begin
                  div_a = registers[process_num][alu_num];
                  div_b = read_value2;
                end
              endcase
            end
          end
        end
        STAGE_TASK_SWITCHER: begin
          `HARD_DEBUG("W");
          //old process
          write_address <= process_address[process_num] + ADDRESS_PC;
          write_value <= pc[process_num];
          write_enabled <= 1;
          `MAKE_SWITCH_TASK(1);
        end
        STAGE_READ_SAVE_PC: begin
          if (process_address[process_num] == next_process_address) begin
          
            
            $display($time - starttime, " new process used(cache) ",process_num);
            //read next process address and finito
            read_address <= next_process_address + ADDRESS_NEXT_PROCESS;
            stage <= STAGE_READ_NEXT_NEXT_PROCESS;
            mmu_page_offset[process_num] <= 2;  //signal, that we have to recalculate things with mmu
          end else begin
          
          $display($time - starttime, " new process used ",!process_used[temp_process_num]?temp_process_num:process_num);
            //temp_registers_updated
            registers <= '{default: 0};
            //new process
            pc[ !process_used[temp_process_num]?temp_process_num:process_num] <= read_value;
            mmu_page_offset[!process_used[temp_process_num]?temp_process_num:process_num] <= 2;  //signal, that we have to recalculate things with mmu
            read_address <= next_process_address + ADDRESS_REG_USED;
            read_address2 <= next_process_address + ADDRESS_REG_USED + 1;
            if (TASK_SWITCHER_DEBUG && !HARDWARE_DEBUG)
              $display($time - starttime, " new pc ", read_value);  //DEBUG info
            //old process
            if (TASK_SWITCHER_DEBUG && !HARDWARE_DEBUG) begin  //DEBUG info
              $write($time - starttime, " old registers updated ");  //DEBUG info
              for (i = 0; i < 32; i = i + 1) begin  //DEBUG info
                $write(registers_updated[!process_used[temp_process_num]?temp_process_num:process_num][i]);  //DEBUG info
              end  //DEBUG info
              $display("");  //DEBUG info
            end  //DEBUG info
            write_address <= process_address[!process_used[temp_process_num]?temp_process_num:process_num] + ADDRESS_REG_USED;
            write_value <= registers_updated[!process_used[temp_process_num]?temp_process_num:process_num][0:15];
            write_enabled <= 1;
            stage <= STAGE_READ_SAVE_REG_USED;
            process_used[!process_used[temp_process_num]?temp_process_num:process_num]<=1;
            process_num<=!process_used[temp_process_num]?temp_process_num:process_num;
          end
          if (mmu_action_ready) mmu_set_start_process_physical_page <= 0;          
        end
        STAGE_READ_SAVE_REG_USED: begin
          //new process
          temp_registers_updated[0:15] <= read_value;
          temp_registers_updated[16:31] <= read_value2;
          registers_updated[process_num][0:15] <= read_value;
          registers_updated[process_num][16:31] <= read_value2;
          ram_read_save_reg_start <= read_value[0] ? 0 : 1;
          read_address <= next_process_address + ADDRESS_REG + (read_value[0] ? 0 : 1);
          ram_read_save_reg_end <= read_value2[15] ? 31 : 30;
          read_address2 <= next_process_address + ADDRESS_REG + (read_value2[15] ? 31 : 30);
          //old process
          write_address <= process_address[process_num] + ADDRESS_REG_USED + 1;
          write_value <= registers_updated[process_num][16:31];
          stage <= STAGE_READ_REG;
          if (mmu_action_ready) mmu_set_start_process_physical_page <= 0;
        end
        STAGE_READ_REG: begin
          if (TASK_SWITCHER_DEBUG && !HARDWARE_DEBUG) begin  //DEBUG info
            $write($time - starttime, " new registers updated ");  //DEBUG info
            for (i = 0; i < 32; i = i + 1) begin  //DEBUG info
              $write(temp_registers_updated[i]);  //DEBUG info
            end  //DEBUG info
            $display("");  //DEBUG info
            $display($time - starttime, " reading reg ", read_address, " ",
                     ram_read_save_reg_start, "=",  //DEBUG info
                     read_value, " ", read_address2, " ", ram_read_save_reg_end, "=",
                     read_value2,  //DEBUG info
                     " ");  //DEBUG info
          end  //DEBUG info
          registers[process_num][ram_read_save_reg_start] <= read_value;
          registers[process_num][ram_read_save_reg_end]   <= read_value2;
          if (temp_registers_updated == 0) begin
            //change process
            prev_process_address <= process_address[process_num];
            process_address[process_num] <= next_process_address;
            //read next process address
            read_address <= next_process_address + ADDRESS_NEXT_PROCESS;
            stage <= STAGE_READ_NEXT_NEXT_PROCESS;
          end else begin
            if (temp_registers_updated[ram_read_save_reg_start+1]) begin
              ram_read_save_reg_start <= ram_read_save_reg_start + 1;
              read_address <= read_address + 1;
              temp_registers_updated[ram_read_save_reg_start+1] <= 0;
            end else if (temp_registers_updated[ram_read_save_reg_start+2]) begin
              ram_read_save_reg_start <= ram_read_save_reg_start + 2;
              read_address <= read_address + 2;
              temp_registers_updated[ram_read_save_reg_start+2] <= 0;
            end else begin
              ram_read_save_reg_start <= ram_read_save_reg_start + 3;
              read_address <= read_address + 3;
              temp_registers_updated[ram_read_save_reg_start+3] <= 0;
            end
            //why going up doesnt work?
            if (temp_registers_updated[ram_read_save_reg_end-1]) begin
              ram_read_save_reg_end <= ram_read_save_reg_end - 1;
              read_address2 <= read_address2 - 1;
              temp_registers_updated[ram_read_save_reg_end-1] <= 0;
            end else if (temp_registers_updated[ram_read_save_reg_end-2]) begin
              ram_read_save_reg_end <= ram_read_save_reg_end - 2;
              read_address2 <= read_address2 - 2;
              temp_registers_updated[ram_read_save_reg_end-2] <= 0;
            end else begin
              ram_read_save_reg_end <= ram_read_save_reg_end - 3;
              read_address2 <= read_address2 - 3;
              temp_registers_updated[ram_read_save_reg_end-3] <= 0;
            end
          end
        end
        STAGE_READ_NEXT_NEXT_PROCESS: begin
          if (mmu_action_ready) begin
            if (TASK_SWITCHER_DEBUG && !HARDWARE_DEBUG) $display("\n\n");
               $display($time-starttime, " read next next ", next_process_address,"=",read_value); //DEBUG info
            mmu_set_start_process_physical_page <= 0;
            next_process_address <= read_value;
            `MAKE_MMU_SEARCH2
          end
        end
        STAGE_DELETE_PROCESS: begin
          mmu_delete_process = 0;
          if (mmu_action_ready) begin
            process_address[process_num] <= prev_process_address;
            `MAKE_SWITCH_TASK(0)
          end
        end
        STAGE_SPLIT_PROCESS: begin
          mmu_split_process = 0;
          if (mmu_action_ready) begin
            //  $display($time-starttime, " new  process chain starts in ", mmu_address_c, " x"); //DEBUG info            
            mul_a <= mmu_address_c;
            mul_b <= MMU_PAGE_SIZE;
            stage <= STAGE_SPLIT_PROCESS2;
          end
        end
        STAGE_SPLIT_PROCESS2: begin
          stage <= STAGE_SPLIT_PROCESS3;
        end
        STAGE_SPLIT_PROCESS3: begin
          stage <= STAGE_SPLIT_PROCESS4;
        end
        STAGE_SPLIT_PROCESS4: begin
          stage <= STAGE_SPLIT_PROCESS5;
        end
        STAGE_SPLIT_PROCESS5: begin
          write_address <= process_address[process_num] + ADDRESS_NEXT_PROCESS;
          write_value <= mul_c;
          write_enabled <= 1;
          stage <= STAGE_SAVE_NEXT_PROCESS;
        end
        STAGE_SAVE_NEXT_PROCESS: begin
          //       $display($time-starttime, " save next ",mul_c + ADDRESS_NEXT_PROCESS,"=",next_process_address); //DEBUG info
          write_address <= mul_c + ADDRESS_NEXT_PROCESS;
          write_value <= next_process_address;
          stage <= STAGE_SAVE_NEXT_PROCESS2;
        end
        STAGE_SAVE_NEXT_PROCESS2: begin
          write_enabled <= 0;
          next_process_address <= mul_c;
          `MAKE_MMU_SEARCH2
        end
        STAGE_REG_INT: begin
          mmu_reg_int <= 0;
          //old process
          write_address <= process_address[process_num] + ADDRESS_PC;
          write_value <= pc[process_num];
          stage <= STAGE_REG_INT2;
        end
        STAGE_REG_INT2: begin
          process_address[process_num] <= prev_process_address;       
          `MAKE_SWITCH_TASK(0)
        end
        STAGE_INT: begin
          mmu_add_shared_mem <= 0;
          mmu_delete_shared_mem <= 0;
          write_address <= prev_process_address + ADDRESS_NEXT_PROCESS;
          write_value <= int_process_address[instruction1_2];
          if (how_many < HOW_MANY_OP_PER_TASK_SIMULATE) begin
            next_process_address <= int_process_address[instruction1_2];
          end else begin
            how_many <= 0;
          end
          int_process_address[instruction1_2] <= process_address[process_num];
          stage <= STAGE_TASK_SWITCHER;
        end
        STAGE_SET_PC: begin
        end
      endcase
    end else if (error_code[process_num] != ERROR_NONE) begin
      $display($time - starttime, " BSOD ", error_code[process_num]);  //DEBUG info
      `HARD_DEBUG("B");  //DEBUG info
      `HARD_DEBUG("S");  //DEBUG info
      `HARD_DEBUG("O");  //DEBUG info
      `HARD_DEBUG("D");  //DEBUG info
      `HARD_DEBUG2(error_code[process_num]);  //DEBUG info
      mmu_search_address <= 0;
      mmu_set_start_process_physical_page <= 0;
      mmu_split_process <= 0;
      if (next_process_address == process_address[process_num]) begin
        mmu_delete_process <= 0;
        stage <= STAGE_HLT;
      end else begin
        mmu_delete_process <= 1;
        write_address <= prev_process_address + ADDRESS_NEXT_PROCESS;
        write_value <= next_process_address;
        write_enabled <= 1;
        stage <= STAGE_DELETE_PROCESS;
      end
      error_code[process_num] <= ERROR_NONE;
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

  /*  reg [15:0] ram[0:67];
      initial begin  //DEBUG info
        $readmemh("rom4.mem", ram);  //DEBUG info
      end  //DEBUG info
*/

  // verilog_format:off
   //(* ram_style = "block" *)
   bit [15:0] ram  [0:559]= {  // in Vivado (required by board)
  //  reg [0:559] [15:0] ram = {  // in iVerilog

      //first process - 4 pages (280 elements)
      16'h0118, 16'h0000,  16'h0000, 16'h0000, //next process address (no MMU) overwritten by CPU, we use first bytes only      
      16'h002A, 16'h0000,  16'h0000, 16'h0000, //PC for this process (overwritten by CPU, we use first bytes only)       

      16'h0000, 16'h0000,  //registers used

      16'h0000, 16'h0000, 16'h0000, 16'h0000, //registers taken "as is"
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000,

      16'h1210, 16'd2613, //value to reg
      16'h0e10, 16'd0100, //save to ram
      16'h0911, 16'd0100, //ram to reg
      16'h0e10, 16'd0212, //save to ram
      16'h0c01, 16'h0001,  //proc
      16'h0c01, 16'h0002,  //proc
      16'h1202, 16'h0003,  //num2reg
      16'hff02, 16'h0002,  //loop,8'hwith,8'hcache:,8'hloopeqvalue
      16'h1402, 16'h0001,  //regminusnum
      16'h1402, 16'h0000,  //regminusnum
      //16'h0201, 16'h0001,  //after,8'hloop:,8'hram2reg
      16'h1201, 16'h0005,  //num2reg
      16'h1201, 16'h0005,  //num2reg
      16'h0E01, 16'h0046,  //reg2ram
      16'h0F00, 16'h0002,  //int,8'h2
      16'h010E, 16'h0030,  //jmp,8'h0x30
      16'h0000, 16'h0000,
      16'h0000, 16'h0000,

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
      16'h002A, 16'h0000,  16'h0000, 16'h0000, //PC for this process (overwritten by CPU, we use first bytes only)

      16'h0000, 16'h0000,  //registers used

      16'h0000, 16'h0000, 16'h0000, 16'h0000, //registers taken "as is"
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000, 

      16'h1210, 16'd2612, //value to reg
    //  16'h0e10, 16'd0101, //save to ram
      16'h1902, 16'h0002, //split process pages 2-4
       16'h1210, 16'd2615, //value to reg
      16'h0e10, 16'd0100, //save to ram
      16'h1b37, 16'h0101, //int
      //16'h0e10, 16'h00D4, //save to ram
      16'h1800, 16'h0007, //process end
      //16'h0c01, 16'h0001,  //proc
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
      16'h0000, 16'h0000,

      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      //third process - 2 pages (140 elements)
      16'h0000, 16'h0000,  16'h0000, 16'h0000, //next process address (no MMU) overwritten by CPU, we use first bytes only
      16'h002A, 16'h0000,  16'h0000, 16'h0000, //PC for this process (overwritten by CPU, we use first bytes only)

      16'h0000, 16'h0000,  //registers used

      16'h0000, 16'h0000, 16'h0000, 16'h0000, //registers taken "as is"
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000,
      16'h0000, 16'h0000, 16'h0000, 16'h0000,

      16'h1a37, 16'h0101, //reg int 
      16'h0911, 16'd0100, //ram to reg
      16'h1210, 16'h0a35, //value to reg
      16'h1d10, 16'd0052, //ram2out      
      16'h1c37, 16'd0000, //int ret
      "AB","CD",
     // 16'h1800, 16'h0000, //process end
      //16'h0e10, 16'h0064, //save to ram
      //16'h1902, 16'h0002, //split process pages 2-4
      //16'h0911, 16'h0064, //ram to reg
      //16'h0e10, 16'h00D4, //save to ram
      //16'h0c01, 16'h0001,  //proc
      16'h0c01, 16'h0002,  //proc
      16'h1202, 16'h0003,  //num2reg
      16'hff02, 16'h0002,  //loop,8'hwith,8'hcache:,8'hloopeqvalue
      16'h1402, 16'h0001,  //regminusnum
      16'h1402, 16'h0000,  //regminusnum
      16'h0201, 16'h0001,  //after,8'hloop:,8'hram2reg
      16'h1201, 16'h0005,  //num2reg
      16'h0E01, 16'h0046,  //reg2ram
      16'h0F00, 16'h0002,  //int,8'h2
      16'h010E, 16'd0030,  //jmp,8'h0x30      
      16'h0000, 16'h0000,

      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,
      16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000
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

module uartx_tx_with_buffer (
    input clk,
    input [7:0] uart_buffer[0:200],
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
  assign uart_buffer_full = uart_buffer_available == 199 ? 1 : 0;
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

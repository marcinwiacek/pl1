`timescale 1ns / 1ps

//options below are less important than options higher //DEBUG info
`define WRITE_RAM_DEBUG 0 //1 enabled, 0 disabled //DEBUG info
`define READ_RAM_DEBUG 0 //1 enabled, 0 disabled //DEBUG info
`define REG_CHANGES_DEBUG 0 //1 enabled, 0 disabled //DEBUG info
`define MMU_CHANGES_DEBUG 1 //1 enabled, 0 disabled //DEBUG info
`define MMU_TRANSLATION_DEBUG 0 //1 enabled, 0 disabled //DEBUG info
`define TASK_SWITCHER_DEBUG 1 //1 enabled, 0 disabled //DEBUG info
`define TASK_SPLIT_DEBUG 1 //1 enabled, 0 disabled //DEBUG info

`define MMU_PAGE_SIZE 151 //how many bytes are assigned to one memory page in MMU
`define RAM_SIZE 32767*2
`define MMU_MAX_INDEX 455 //(`RAM_SIZE+1)/`MMU_PAGE_SIZE;

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
/* DEBUG info */     if (`MMU_CHANGES_DEBUG == 1) begin \
/* DEBUG info */       $write($time, " mmu "); \
/* DEBUG info */       for (i = 0; i <= 10; i = i + 1) begin \
/* DEBUG info */         if (mmu_start_process_physical_segment == i && mmu_logical_pages_memory[i]!=0) $write("s"); \
/* DEBUG info */         if (mmu_chain_memory[i] == i && mmu_logical_pages_memory[i]!=0) $write("e"); \
/* DEBUG info */         $write($sformatf("%02x-%02x ", mmu_chain_memory[i], mmu_logical_pages_memory[i])); \
/* DEBUG info */       end \
/* DEBUG info */       $display(""); \
/* DEBUG info */     end

/* DEBUG info */  `define SHOW_TASK_INFO(ARG) \
/* DEBUG info */     if (`TASK_SWITCHER_DEBUG == 1) begin \
/* DEBUG info */          $write($time, " ",ARG," pc ", address_pc[process_index]); \
/* DEBUG info */          $display( \
/* DEBUG info */              " ",ARG," process seg/addr ", mmu_start_process_segment, process_start_address[process_index], \
/* DEBUG info */              " process index ", process_index \
/* DEBUG info */          ); \
/* DEBUG info */        end

//offsets for process info
`define ADDRESS_NEXT_PROCESS 0
`define ADDRESS_PC 4*2
`define ADDRESS_REG_USED 8*2
`define ADDRESS_REG 14*2
`define ADDRESS_PROGRAM `ADDRESS_REG+32*2

module cpu (
    input  btnc,
    clk,
    output tx
);

  wire [9:0] read_address, read_read_address, read_address_executor, read_read_address_executor, save_address, save_save_address;
  wire [7:0] read_value, read_value_executor, save_value;

  ram ram (
      .clk(clk),
      .rst(btnc),
      .read_address(read_address),
      .read_read_address(read_read_address),
      .read_value(read_value),
      .read_address_executor(read_address_executor),
      .read_read_address_executor(read_read_address_executor),
      .read_value_executor(read_value_executor),
      .save_value(save_value),
      .save_address(save_address),
      .save_save_address(save_save_address)
  );

  wire [7:0] executor_instruction1, executor_instruction2, executor_instruction3, executor_instruction4;
  wire executor_data_ready, executor_working, executor_new_pc_set;
  wire [9:0] executor_new_pc;

  stage1_fetcher fetch (
      .tx(tx),
      .rst(btnc),
      .executor_instruction1(executor_instruction1),
      .executor_instruction2(executor_instruction2),
      .executor_instruction3(executor_instruction3),
      .executor_instruction4(executor_instruction4),
      .executor_data_ready(executor_data_ready),
      .executor_working(executor_working),
      .read_address(read_address),
      .read_read_address(read_read_address),
      .read_value(read_value),
      .executor_new_pc(executor_new_pc),
      .executor_new_pc_set(executor_new_pc_set)
  );

  stage2_executor execute (
      .instruction1(executor_instruction1),
      .instruction2(executor_instruction2),
      .instruction3(executor_instruction3),
      .instruction4(executor_instruction4),
      .data_ready(executor_data_ready),
      .working(executor_working),
      .rst(rst),
      .executor_new_pc(executor_new_pc),
      .executor_new_pc_set(executor_new_pc_set),
      .read_address(read_address_executor),
      .read_read_address(read_read_address_executor),
      .read_value(read_value_executor),
      .save_value(save_value),
      .save_address(save_address),
      .save_save_address(save_save_address)
  );

endmodule

module stage1_fetcher (
    input      rst,
    output reg tx,

    output reg [7:0] executor_instruction1,
    executor_instruction2,
    executor_instruction3,
    executor_instruction4,
    output reg       executor_data_ready,
    input            executor_working,

    output reg [9:0] read_address,
    input      [9:0] read_read_address,
    input      [7:0] read_value,

    input [9:0] executor_new_pc,
    input       executor_new_pc_set
);

  reg [9:0] pc;
  reg [10:0] fetcher_stage;
  reg [7:0] fetcher_instruction[3:0];
  reg rst_done = 1;

  `define STAGE_READ_PC1_REQUEST 0
  `define STAGE_READ_PC2_REQUEST 1
  `define STAGE_READ_PC3_REQUEST 2
  `define STAGE_READ_PC4_REQUEST 3

  always @(read_read_address, rst, executor_new_pc) begin
    if ((rst == 1 && rst_done == 1) || (executor_new_pc_set == 1 && pc != executor_new_pc)) begin
      fetcher_stage <= 0;
      rst_done <= 0;
      $display($time, " changing address to ", executor_new_pc, " ", pc);
      $display($time, " rst");
      pc <= rst == 1 && rst_done == 1 ? `ADDRESS_PROGRAM : executor_new_pc;
      read_address <= rst == 1 && rst_done == 1 ? `ADDRESS_PROGRAM : executor_new_pc;
    end else if (read_read_address == read_address && (fetcher_stage != 3 || executor_working == 0)) begin
      $display($time, " reading ", read_value, " from ", read_address, " ", pc, " ", fetcher_stage,
               " ", rst);
      fetcher_instruction[fetcher_stage] <= read_value;
      read_address <= read_address + 1;
      fetcher_stage <= fetcher_stage == 3 ? 0 : fetcher_stage + 1;
      tx <= read_value;
      if (fetcher_stage == 3) begin
        if (executor_working == 0) begin
          executor_instruction1 <= fetcher_instruction[0];
          executor_instruction2 <= fetcher_instruction[1];
          executor_instruction3 <= fetcher_instruction[2];
          executor_instruction4 <= read_value;
          executor_data_ready <= 1;
          pc <= pc + 4;
        end
      end else if (fetcher_stage == 0) begin
        executor_data_ready <= 0;
      end
    end
  end

endmodule

`define OPCODE_JMP 1     //255 or register num for first 16-bits of the address, 16 bit address
`define OPCODE_RAM2REG 2 //register num, 16 bit source addr //ram -> reg
`define OPCODE_REG2RAM 3 //register num, 16 bit source addr //reg -> ram
`define OPCODE_NUM2REG 4 //register num, 16 bit value //value -> reg

module stage2_executor (
    input rst,

    input data_ready,
    output reg working,

    input [7:0] instruction1,
    instruction2,
    instruction3,
    instruction4,

    output reg [9:0] executor_new_pc,
    output reg executor_new_pc_set,

    output reg [9:0] read_address,
    input      [9:0] read_read_address,
    input      [7:0] read_value,

    output reg [9:0] save_address,
    output reg [7:0] save_value,
    input      [9:0] save_save_address
);

  reg [15:0] registers[0:31];  //64 8-bit registers * n=8 processes = 512 16-bit registers

  reg working2 = 0, save_processed = 1;

  assign working = working2;

  always @(data_ready, save_save_address) begin
    if (save_save_address == save_address && save_processed == 0) begin
      $display($time, " decoding end after save ");
      save_processed <= 1;
      working2 <= 0;
    end else if (data_ready == 1) begin
      working2 <= 1;
      $display($time, " decoding ", instruction1, " ", instruction2, " ", instruction3, " ",
               instruction4);
      executor_new_pc_set <= 0;
      if (instruction1 == `OPCODE_JMP) begin
        $display(" opcode = jmp to ", instruction3 * 256 + instruction4);  //DEBUG info
        // if (instruction3 * 256 + instruction4 >= `ADDRESS_PROGRAM) begin     
        executor_new_pc <= instruction3 * 256 + instruction4;
        executor_new_pc_set <= 1;
        //  end
      end else if (instruction1 == `OPCODE_RAM2REG) begin
        $display(" opcode = ram2reg value from address ", instruction3 * 256 + instruction4,
                 " to reg ",  //DEBUG info
                 instruction2);  //DEBUG info
        // read_address <= instruction3 * 256 + instruction4;
      end else if (instruction1 == `OPCODE_REG2RAM) begin
        $display(" opcode = reg2ram save value ", registers[instruction2], " from register ",
                 instruction2, " to address ", instruction3 * 256 + instruction4);
        save_processed <= 0;
        save_value <= registers[instruction2];
        save_address <= instruction3 * 256 + instruction4;
      end else if (instruction1 == `OPCODE_NUM2REG) begin
        $display(" opcode = num2reg value ", instruction3 * 256 + instruction4,
                 " to reg ",  //DEBUG info
                 instruction2);  //DEBUG info
        registers[instruction2] <= instruction3 * 256 + instruction4;
      end
      if (instruction1 != `OPCODE_REG2RAM) begin
        $display($time, " decoding end ");
        working2 <= 0;
      end
    end
  end

endmodule

module mmu (
    input rst,

    input [9:0] address_to_decode,
    output reg [9:0] address_decoded,

    input [9:0] address_to_decode2,
    output reg [9:0] address_decoded2
);

  integer i;

  reg [11:0] mmu_chain_memory[0:4095];  //next physical segment index for process (last entry = the same entry)
  reg [11:0] mmu_logical_pages_memory[0:4095];  //logical process page assigned to physical segment (0 means empty page, we setup value > 0 for first page with logical index 0 and ignore it)
  reg [11:0] mmu_start_process_physical_segment;  //needs to be updated on process switch

  reg [11:0] mmu_logical_seg, mmu_logical_seg2;
  reg [11:0] mmu_old_physical_segment, mmu_old_physical_segment2;
  reg mmu_search = 0, mmu_search2 = 0;

  reg rst_done = 0;

  always @(rst) begin
    if (rst == 1 && rst_done == 0) begin
      rst_done <= 1;
      mmu_start_process_physical_segment <= 0;

      mmu_chain_memory[0] <= 0;
      //problem: we shouldn't mix blocking and non-blocking
      for (i = 0; i < 4096; i = i + 1) begin
        //value 0 means, that it's empty. in every process on first entry we setup something != 0 and ignore it
        // (first process page is always from segment 0)
        mmu_logical_pages_memory[i] <= 0;
      end
      mmu_logical_pages_memory[0] <= 1;

      //    some more complicated config used for testing //DEBUG info
      //    mmu_chain_memory[0] <= 1;  //DEBUG info
      //    mmu_chain_memory[1] <= 1;  //DEBUG info
      //    mmu_logical_pages_memory[1] <= 1;  //DEBUG info

      //some more complicated config used for testing //DEBUG info
      mmu_chain_memory[0] <= 5;  //DEBUG info
      mmu_chain_memory[5] <= 2;  //DEBUG info
      mmu_chain_memory[2] <= 1;  //DEBUG info
      mmu_chain_memory[1] <= 1;  //DEBUG info
      mmu_logical_pages_memory[5] <= 3;  //DEBUG info
      mmu_logical_pages_memory[2] <= 2;  //DEBUG info
      mmu_logical_pages_memory[1] <= 1;  //DEBUG info     
    end else begin
      `SHOW_MMU_DEBUG
    end
  end

  always @(address_to_decode, mmu_old_physical_segment) begin
    if (mmu_search == 1) begin
      if (mmu_logical_seg == mmu_logical_pages_memory[mmu_old_physical_segment]) begin
        address_decoded <= mmu_old_physical_segment * `MMU_PAGE_SIZE + address_to_decode % `MMU_PAGE_SIZE;
        mmu_search <= 0;
      end else if (mmu_old_physical_segment == mmu_chain_memory[mmu_old_physical_segment]) begin
        $display($time, " error");  //DEBUG info
      end else begin
        mmu_old_physical_segment <= mmu_chain_memory[mmu_old_physical_segment];
      end
    end else if (mmu_search == 0) begin
      mmu_logical_seg <= address_to_decode / `MMU_PAGE_SIZE;
      if (address_to_decode / `MMU_PAGE_SIZE == 0) begin
        address_decoded <= mmu_start_process_physical_segment * `MMU_PAGE_SIZE + address_to_decode % `MMU_PAGE_SIZE;
      end else begin
        mmu_search <= 1;
        mmu_old_physical_segment <= mmu_chain_memory[mmu_start_process_physical_segment];
      end
    end
  end

  always @(address_to_decode2, mmu_old_physical_segment2) begin
    if (mmu_search2 == 1) begin
      if (mmu_logical_seg2 == mmu_logical_pages_memory[mmu_old_physical_segment2]) begin
        address_decoded2 <= mmu_old_physical_segment2 * `MMU_PAGE_SIZE + address_to_decode2 % `MMU_PAGE_SIZE;
        mmu_search2 <= 0;
      end else if (mmu_old_physical_segment2 == mmu_chain_memory[mmu_old_physical_segment2]) begin
        $display($time, " error");  //DEBUG info
      end else begin
        mmu_old_physical_segment2 <= mmu_chain_memory[mmu_old_physical_segment2];
      end
    end else if (mmu_search2 == 0) begin
      mmu_logical_seg2 <= address_to_decode2 / `MMU_PAGE_SIZE;
      if (address_to_decode2 / `MMU_PAGE_SIZE == 0) begin
        address_decoded2 <= mmu_start_process_physical_segment * `MMU_PAGE_SIZE + address_to_decode2 % `MMU_PAGE_SIZE;
      end else begin
        mmu_search2 <= 1;
        mmu_old_physical_segment2 <= mmu_chain_memory[mmu_start_process_physical_segment];
      end
    end
  end

endmodule

module ram (
    input rst,
    input clk,

    input [9:0] read_address,
    output reg [9:0] read_read_address,
    output reg [7:0] read_value,

    input [9:0] read_address_executor,
    output reg [9:0] read_read_address_executor,
    output reg [7:0] read_value_executor,

    input [9:0] save_address,
    output reg [9:0] save_save_address,
    input reg [7:0] save_value
);

  reg [9:0] address_to_decode, address_decoded, address_to_decode2, address_decoded2;

  mmu mmu (
      .rst(rst),

      .address_to_decode(address_to_decode),
      .address_decoded  (address_decoded),

      .address_to_decode2(address_to_decode2),
      .address_decoded2  (address_decoded2)
  );

  reg ena, enb, wea;
  reg [9:0] addra, addrb;
  reg [7:0] dia, dob;

  simple_dual_two_clocks ram (
      .clka (clk),
      .clkb (clk),
      .ena  (ena),
      .enb  (enb),
      .wea  (wea),
      .addra(addra),
      .addrb(addrb),
      .dia  (dia),
      .dob  (dob)
  );

  reg [9:0] addrbb, addraa;

  always @(posedge rst) begin
    enb <= 1;
  end

  always @(read_address) begin
    address_to_decode <= read_address;
  end

  always @(save_address) begin
    address_to_decode2 <= save_address;
  end

  always @(address_decoded) begin
    addrb  <= address_decoded;
    addrbb <= address_to_decode;
  end

  always @(address_decoded2) begin
    addra  <= address_decoded2;
    addraa <= address_to_decode2;
  end

  reg read_available = 1, save_available = 1;

  always @(posedge clk) begin
    read_available <= !(addrbb == read_address);
    save_available <= !(addraa == save_address);
  end

  always @(negedge clk) begin
    if (read_available == 0 && addrbb == read_address) begin
      read_value <= dob;
      read_read_address <= address_to_decode;
    end
    if (save_available == 0 && addraa == save_address) begin
      save_save_address <= address_to_decode2;
    end
  end

endmodule

// Simple Dual-Port Block RAM with Two Clocks
// simple_dual_two_clocks.v
// standard code
module simple_dual_two_clocks (
    input clka,
    clkb,
    ena,
    enb,
    wea,
    input [9:0] addra,
    addrb,
    input [7:0] dia,
    output reg [7:0] dob
);

  reg [7:0] ram[0:`RAM_SIZE];

  initial begin  //DEBUG info
    $readmemh("rom4.mem", ram);  //DEBUG info
  end  //DEBUG info

  always @(posedge clka) begin
    if (ena) begin
      if (wea) ram[addra] <= dia;
      if (wea && `WRITE_RAM_DEBUG == 1)  //DEBUG info
        $display($time, " writing ", dia, " to ", addra);  //DEBUG info
    end
  end

  always @(posedge clkb) begin
    if (enb) begin
      dob <= ram[addrb];
      if (`READ_RAM_DEBUG == 1)  //DEBUG info
        $display($time, " reading1 ", ram[addrb], " from ", addrb, " ", clkb);  //DEBUG info
    end
  end
endmodule


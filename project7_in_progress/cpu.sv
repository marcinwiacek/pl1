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


  wire [9:0] read_address, read_read_address;
  wire [7:0] read_value;

  ram ram (
      .clk(clk),
      .rst(btnc),
      .read_address(read_address),
      .read_read_address(read_read_address),
      .read_value(read_value)
  );

  wire [7:0] decoder_instruction1, decoder_instruction2, decoder_instruction3, decoder_instruction4;
  wire decoder_data_ready, decoder_working, decoder_new_pc_set;
  wire [9:0] decoder_new_pc;

  stage1_fetcher fetch (
      .tx(tx),
      .rst(btnc),
      .decoder_instruction1(decoder_instruction1),
      .decoder_instruction2(decoder_instruction2),
      .decoder_instruction3(decoder_instruction3),
      .decoder_instruction4(decoder_instruction4),
      .decoder_data_ready(decoder_data_ready),
      .decoder_working(decoder_working),
      .read_address(read_address),
      .read_read_address(read_read_address),
      .read_value(read_value),
      .decoder_new_pc(decoder_new_pc),
      .decoder_new_pc_set(decoder_new_pc_set)
  );

  stage2_decoder decode (
      .instruction1(decoder_instruction1),
      .instruction2(decoder_instruction2),
      .instruction3(decoder_instruction3),
      .instruction4(decoder_instruction4),
      .data_ready(decoder_data_ready),
      .working(decoder_working),
      .rst(rst),
      .decoder_new_pc(decoder_new_pc),
      .decoder_new_pc_set(decoder_new_pc_set)
  );

endmodule

module stage1_fetcher (
    output reg [7:0] decoder_instruction1,
    decoder_instruction2,
    decoder_instruction3,
    decoder_instruction4,
    output reg       decoder_data_ready,
    input            decoder_working,
    output reg [9:0] read_address,
    input      [9:0] read_read_address,
    input      [7:0] read_value,
    input            rst,
    output reg       tx,
    input      [9:0] decoder_new_pc,
    input            decoder_new_pc_set
);

  integer i;  //DEBUG info

  reg [9:0] pc;
  reg [10:0] fetcher_stage;
  reg [7:0] fetcher_instruction[3:0];
  reg rst_done = 1;

  `define STAGE_READ_PC1_REQUEST 0
  `define STAGE_READ_PC2_REQUEST 1
  `define STAGE_READ_PC3_REQUEST 2
  `define STAGE_READ_PC4_REQUEST 3

  always @(read_read_address, rst, decoder_new_pc) begin
    if ((rst == 1 && rst_done == 1)||(decoder_new_pc_set == 1 && pc != decoder_new_pc)) begin
      fetcher_stage <= 0;
    end
    if (rst == 1 && rst_done == 1) begin
      rst_done <= 0;
      $display($time, " rst");
      pc <= `ADDRESS_PROGRAM;
      read_address <= `ADDRESS_PROGRAM;
    end else if (decoder_new_pc_set == 1 && pc != decoder_new_pc) begin
      pc <= decoder_new_pc;
      read_address <= decoder_new_pc;
      $display($time, " changing address to ", decoder_new_pc, " ", pc);
    end else if (read_read_address == read_address && (fetcher_stage != 3 || decoder_working == 0)) begin
      $display($time, " reading ", read_value, " from ", read_address, " ", pc, " ", fetcher_stage,
               " ", rst);
      fetcher_instruction[fetcher_stage] <= read_value;
      read_address <= read_address + 1;
      fetcher_stage <= fetcher_stage == 3 ? 0 : fetcher_stage + 1;
      tx <= read_value;
      if (fetcher_stage == 3) begin
        if (decoder_working == 0) begin
          decoder_instruction1 <= fetcher_instruction[0];
          decoder_instruction2 <= fetcher_instruction[1];
          decoder_instruction3 <= fetcher_instruction[2];
          decoder_instruction4 <= read_value;
          decoder_data_ready <= 1;
          pc <= pc + 4;
        end
      end else if (fetcher_stage == 0) begin
        decoder_data_ready <= 0;
      end
    end
  end

endmodule

`define OPCODE_JMP 1     //255 or register num for first 16-bits of the address, 16 bit address
`define OPCODE_RAM2REG 2 //register num, 16 bit source addr //ram -> reg
`define OPCODE_REG2RAM 3 //register num, 16 bit source addr //reg -> ram
`define OPCODE_NUM2REG 4 //register num, 16 bit value //value -> reg

module stage2_decoder (
    input [7:0] instruction1,
    instruction2,
    instruction3,
    instruction4,
    input data_ready,
    output reg working,
    input rst,
    output reg [9:0] decoder_new_pc,
    output reg decoder_new_pc_set
);

  reg [15:0] registers[0:31];  //64 8-bit registers * n=8 processes = 512 16-bit registers

  reg working2 = 0;

  assign working = working2;

  always @(posedge data_ready) begin
    working2 <= 1;
    $display($time, " decoding ", instruction1, " ", instruction2, " ", instruction3, " ",
             instruction4);
    decoder_new_pc_set <= 0;
    if (instruction1 == `OPCODE_JMP) begin
      $display(" opcode = jmp to ", instruction3 * 256 + instruction4);  //DEBUG info
      // if (instruction3 * 256 + instruction4 >= `ADDRESS_PROGRAM) begin
      decoder_new_pc_set <= 1;
      decoder_new_pc <= instruction3 * 256 + instruction4;
      //  end
    end else if (instruction1 == `OPCODE_NUM2REG) begin
      $display(" opcode = num2reg value ", instruction3 * 256 + instruction4,
               " to reg ",  //DEBUG info
               instruction2);  //DEBUG info
      registers[instruction2] <= instruction3 * 256 + instruction4;
    end
    $display($time, " decoding end ");
    working2 <= 0;
  end

endmodule

module mmu (
    input [9:0] address_to_decode,
    output reg [9:0] address_decoded,
    input rst
);

  integer i;

  reg [11:0] mmu_chain_memory[0:4095];  //next physical segment index for process (last entry = the same entry)
  reg [11:0] mmu_logical_pages_memory[0:4095];  //logical process page assigned to physical segment (0 means empty page, we setup value > 0 for first page with logical index 0 and ignore it)
  reg [11:0] mmu_start_process_physical_segment;  //needs to be updated on process switch
  reg [11:0] mmu_logical_seg;
  reg [11:0] mmu_old_physical_segment;
  reg mmu_search = 0, rst_done = 0;

  always @(address_to_decode, rst, mmu_old_physical_segment) begin
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
    end else if (mmu_search == 1) begin
      `SHOW_MMU_DEBUG
      if (mmu_logical_seg == mmu_logical_pages_memory[mmu_old_physical_segment]) begin
        address_decoded <= mmu_old_physical_segment * `MMU_PAGE_SIZE + address_to_decode % `MMU_PAGE_SIZE;
        mmu_search <= 0;
      end else if (mmu_old_physical_segment == mmu_chain_memory[mmu_old_physical_segment]) begin
        $display($time, " error"); //DEBUG info
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
endmodule

module ram (
    input rst,
    input clk,
    input [9:0] read_address,
    output reg [9:0] read_read_address,
    output reg [7:0] read_value
);

  reg [9:0] address_to_decode, address_decoded;

  mmu mmu (
      .address_to_decode(address_to_decode),
      .address_decoded(address_decoded),
      .rst(rst)
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

  reg [9:0] addrbb;

  always @(posedge rst) begin
    enb <= 1;
  end

  always @(read_address) begin
    address_to_decode <= read_address;
  end

  always @(address_decoded) begin
    addrb  <= address_decoded;
    addrbb <= address_to_decode;
  end

  reg read_available = 1;

  always @(posedge clk) begin
    read_available <= !(addrbb == read_address);
  end

  always @(negedge clk) begin
    if (read_available == 0 && addrbb == read_address) begin
      read_value <= dob;
      read_read_address <= address_to_decode;
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


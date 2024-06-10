`timescale 1ns / 1ps

//options below are less important than options higher //DEBUG info
`define WRITE_RAM_DEBUG 0 //1 enabled, 0 disabled //DEBUG info
`define READ_RAM_DEBUG 0 //1 enabled, 0 disabled //DEBUG info
`define REG_CHANGES_DEBUG 0 //1 enabled, 0 disabled //DEBUG info
`define MMU_CHANGES_DEBUG 1 //1 enabled, 0 disabled //DEBUG info
`define MMU_TRANSLATION_DEBUG 0 //1 enabled, 0 disabled //DEBUG info
`define TASK_SWITCHER_DEBUG 1 //1 enabled, 0 disabled //DEBUG info
`define TASK_SPLIT_DEBUG 1 //1 enabled, 0 disabled //DEBUG info

`define MMU_PAGE_SIZE 72 //how many bytes are assigned to one memory page in MMU
`define RAM_SIZE 32767*2
`define MMU_MAX_INDEX 455 //(`RAM_SIZE+1)/`MMU_PAGE_SIZE;

module cpu (
    input  btnc,
    clk,
    output tx
);

  //RAM
  wire ena, enb, wea;
  wire [9:0] addra, addrb;
  wire [7:0] dia;
  wire [7:0] dob;

  simple_dual_two_clocks simple_dual_two_clocks (
      .clka(clk),
      .clkb(clk),
      .ena(ena),
      .enb(enb),
      .wea(wea),
      .addra(addra),
      .addrb(addrb),
      .dia(dia),
      .dob(dob)
  );

  stage1 stage1 (
      .clka(clk),
      .clkb(clk),
      .rst(btnc),
      .ena(ena),
      .enb(enb),
      .wea(wea),
      .addra(addra),
      .addrb(addrb),
      .dia(dia),
      .dob(dob),
      .tx(tx)
  );

endmodule

module stage1 (
    input            clka,
    clkb,
    rst,
    output reg       ena,
    enb,
    wea,
    tx,
    output reg [9:0] addra,
    addrb,
    output reg [7:0] dia,
    input      [7:0] dob
);

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
/* DEBUG info */         if (mmu_start_process_segment == i && mmu_logical_pages_memory[i]!=0) $write("s"); \
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

  reg [10:0] stage;
  reg [16:0] pc;
  reg [7:0] instruction [3:0];
  
  `define STAGE_READ_PC1_REQUEST 0
  `define STAGE_READ_PC2_REQUEST 1
  `define STAGE_READ_PC3_REQUEST 2
  `define STAGE_READ_PC4_REQUEST 3

reg decoder_data_ready;
 reg decoder_working = 0;
  reg [7:0] decoder_instruction [3:0];
    
  //fetcher
  always @(posedge rst, negedge clkb) begin
    if (rst == 1) begin
      addrb <= `ADDRESS_PROGRAM;
      pc <= `ADDRESS_PROGRAM;
      stage <= 0;
      enb <= 1;
    end else if (clkb == 0) begin
      $display($time, " reading ", dob, " from ", (addrb), " ", pc, " ", stage, " ", rst);
      instruction[stage] <= dob;
      addrb <= pc + 1;
      pc <= pc + 1;
      stage <= stage == 3 ? 0 : stage + 1;
      //fixme: jump instructions
      tx <= dob;
      if (stage == 3) begin
        if (decoder_working == 0) begin
            decoder_instruction[0] <= instruction[0];
            decoder_instruction[1] <= instruction[1];
            decoder_instruction[2] <= instruction[2];
            decoder_instruction[3] <= instruction[3];
            decoder_data_ready <= 1;
        end
      end else if (stage==0) begin
        decoder_data_ready <= 0;
      end
    end
  end
  

  
  always @(negedge decoder_working) begin
    if (stage == 3) begin
       
            decoder_instruction[0] <= instruction[0];
            decoder_instruction[1] <= instruction[1];
            decoder_instruction[2] <= instruction[2];
            decoder_instruction[3] <= instruction[3];
            decoder_data_ready <= 1;
       
      end
  end
  
  always @(posedge decoder_data_ready) begin
      decoder_working <= 1;
      $display($time, " decoding ");
      decoder_working <= 0;
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
        $display($time, " reading1 ", ram[addrb], " from ", addrb, " ",clkb);  //DEBUG info
    end
  end
endmodule


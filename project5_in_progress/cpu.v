`timescale 1ns / 1ps

module cpu (
    input rst,
    input clk
);

  wire clka, clkb, ena, enb, wea;
  wire [9:0] addra, addrb;
  wire [15:0] dia;
  wire [15:0] dob;

  simple_dual_two_clocks simple_dual_two_clocks (
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

  stage1 stage1 (
      .clk  (clk),
      .rst  (rst),
      .ena  (ena),
      .enb  (enb),
      .wea  (wea),
      .addra(addra),
      .addrb(addrb),
      .dia  (dia),
      .dob  (dob)
  );

endmodule

module stage1 (
    input             clk,
    input             rst,
    output reg        ena,
    enb,
    wea,
    output reg [ 9:0] addra,
    addrb,
    input      [15:0] dia,
    input      [15:0] dob
);

  reg [7:0] address = 0;
  reg [7:0] stage;
  reg [15:0] registers[31:0];

  reg [15:0] instruction[1:0];
  wire [7:0] op;
  wire [7:0] inst;

  assign op = instruction[0][15:8];
  assign instr  = instruction[0][7:0];

  `define STAGE_READ_PC1_REQUEST 0
  `define STAGE_READ_PC1_RESPONSE 1
  `define STAGE_READ_PC2_REQUEST 2
  `define STAGE_READ_PC2_RESPONSE 3
  `define STAGE_DECODE 4
  `define STAGE_READ_RAM2REG 5
  `define STAGE_SAVE_REG2RAM 6

  `define OPCODE_JMP 1 //.., 16 bit address
  `define OPCODE_RAM2REG 2 //register num, 16 bit source addr
  `define OPCODE_REG2RAM 3 //register num, 16 bit source addr

  always @(posedge rst) begin
    $display($time, "rst");
    stage <= `STAGE_READ_PC1_REQUEST;
  end

  always @(stage) begin
    if (stage == `STAGE_READ_PC1_REQUEST) begin
      enb   <= 1;
      addrb <= address;
      stage <= `STAGE_READ_PC1_RESPONSE;
    end else if (stage == `STAGE_READ_PC2_REQUEST) begin
      enb   <= 1;
      addrb <= address;
      stage <= `STAGE_READ_PC2_RESPONSE;
    end else if (stage == `STAGE_DECODE) begin
      if (op == `OPCODE_JMP) begin
        $display($time, " opcode = jmp to ",instruction[1]);
        address <= instruction[1];
        stage   <= `STAGE_READ_PC1_REQUEST;
      end else if (op == `OPCODE_RAM2REG) begin
        $display($time, " opcode = ram2reg address ",instruction[1]," to ",instr);
        enb   <= 1;
        addrb <= instruction[1];
        stage <= `STAGE_READ_RAM2REG;
      end else if (op == `OPCODE_REG2RAM) begin
        $display($time, " opcode = reg2ram");
      end else begin
    	$display($time, " opcode = ", op);
        stage <= `STAGE_READ_PC1_RESPONSE;
      end
    end
  end

  always @(negedge clk) begin
    if (stage == `STAGE_READ_PC1_RESPONSE) begin
      $display($time, " 0: ", address, "=", dob / 256, " ", dob % 256);
      instruction[0] <= dob;
      address <= address + 1;
      stage <= `STAGE_READ_PC2_REQUEST;
    end else if (stage == `STAGE_READ_PC2_RESPONSE) begin
      $display($time, " 1: ", address, "=", dob / 256, " ", dob % 256);
      instruction[1] <= dob;
      address <= address + 1;
      stage <= `STAGE_DECODE;
    end else if (stage == `STAGE_READ_RAM2REG) begin
//      $display($time, " 2: reg ",instr," = ",dob);
      registers[instr] <= dob;
      stage <= `STAGE_READ_PC1_REQUEST;
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
    input [15:0] dia,
    output reg [15:0] dob
);
  reg [15:0] ram[1023:0];
  initial begin  //DEBUG info
    $readmemh("rom2.mem", ram);  //DEBUG info
  end  //DEBUG info
  always @(posedge clka) begin
    if (ena) begin
      if (wea) ram[addra] <= dia;
    end
  end
  always @(posedge clkb) begin
    if (enb) begin
      dob <= ram[addrb];
    end
  end
endmodule

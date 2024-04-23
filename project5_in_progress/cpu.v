`timescale 1ns / 1ps

module cpu (
    input rst,
    input clka,
    clkb
);

  wire clka, clkb, ena, enb, wea;
  wire [9:0] addra, addrb;
  wire [15:0] dia;
  wire [15:0] dob;

  simple_dual_two_clocks simple_dual_two_clocks (
      .clka (clka),
      .clkb (clkb),
      .ena  (ena),
      .enb  (enb),
      .wea  (wea),
      .addra(addra),
      .addrb(addrb),
      .dia  (dia),
      .dob  (dob)
  );

  stage1 stage1 (
      .clka (clka),
      .clkb (clkb),
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
    input             clka,
    clkb,
    input             rst,
    output reg        ena,
    enb,
    wea,
    output reg [ 9:0] addra,
    addrb,
    output reg [15:0] dia,
    input      [15:0] dob
);

  reg [9:0] address = 0;
  reg [7:0] stage;
  reg [15:0] registers[31:0];

  reg [15:0] instruction[1:0];
  wire [7:0] op;
  wire [7:0] inst;

  assign op = instruction[0][15:8];
  assign inst = instruction[0][7:0];

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
  `define OPCODE_NUM2REG 4 //register num, 16 bit value

  always @(posedge rst) begin
    $display($time, "rst");
    stage <= `STAGE_READ_PC1_REQUEST;
    enb   <= 1;
    ena   <= 1;
  end

  always @(stage) begin
    if (stage == `STAGE_READ_PC1_REQUEST) begin
      addrb <= address;
      stage <= `STAGE_READ_PC1_RESPONSE;
    end else if (stage == `STAGE_READ_PC2_REQUEST) begin
      addrb <= address;
      stage <= `STAGE_READ_PC2_RESPONSE;
    end else if (stage == `STAGE_DECODE) begin
      if (op == `OPCODE_JMP) begin
        $display($time, " opcode = jmp to ", instruction[1]);
        address <=0;
        stage   <= `STAGE_READ_PC1_REQUEST;
      end else if (op == `OPCODE_RAM2REG) begin
        $display($time, " opcode = ram2reg address ", instruction[1], " to reg ", inst);
        addrb <= instruction[1][9:0];
        stage <= `STAGE_READ_RAM2REG;
      end else if (op == `OPCODE_REG2RAM) begin
        $display($time, " opcode = reg2ram value ", registers[inst], " to address ",
                 instruction[1]);
        addra <= instruction[1][9:0];
        dia   <= registers[inst];
        wea   <= 1;
        stage <= `STAGE_SAVE_REG2RAM;
      end else if (op == `OPCODE_NUM2REG) begin
        $display($time, " opcode = num2reg value ", instruction[1], " to reg ", inst);
        registers[inst] <= instruction[1];
        stage <= `STAGE_READ_PC1_REQUEST;
      end else begin
        $display($time, " opcode = ", op);
        stage <= `STAGE_READ_PC1_REQUEST;
      end
    end
  end

  always @(posedge clka) begin
    if (stage == `STAGE_SAVE_REG2RAM) begin
      wea   <= 0;
      stage <= `STAGE_READ_PC1_REQUEST;
    end
  end

  always @(negedge clkb) begin
    if (stage == `STAGE_READ_PC1_RESPONSE) begin
//      $display($time, " ", address, 
//	    "=",
//             dob / 256, " ", dob % 256);
      instruction[0] <= dob;
      address <= address + 1;
      stage <= `STAGE_READ_PC2_REQUEST;
    end else if (stage == `STAGE_READ_PC2_RESPONSE) begin
      $display($time, " ", address, 
	    "=", instruction[0] / 256, instruction[0] % 256,
               dob / 256, " ", dob % 256);
      instruction[1] <= dob;
      address <= address + 1;
      stage <= `STAGE_DECODE;
    end else if (stage == `STAGE_READ_RAM2REG) begin
      $display($time, "          reg ", inst, " = ", dob);
      registers[inst] <= dob;
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
  reg [15:0] ram[0:1023];
  initial begin  //DEBUG info
    $readmemh("rom2.mem", ram);  //DEBUG info
  end  //DEBUG info
  always @(posedge clka) begin
    if (ena) begin
      if (wea) ram[addra] <= dia;
//      if (wea) $display($time, " writing ", dia, " to ",addra);
    end
  end
  always @(posedge clkb) begin
    if (enb) begin
      dob <= ram[addrb];
//      $display($time, " reading ", ram[addrb], " from ",addrb);
    end
  end
endmodule

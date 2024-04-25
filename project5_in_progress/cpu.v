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

  reg [9:0] address_pc = 0;
  reg [7:0] stage;
  reg [15:0] registers[5:0];  //64 registers

  reg [7:0] inst_op;
  reg [7:0] inst_regnum;
  reg [15:0] inst_address_num;

  reg [7:0] inst_op_cache[255:0];
  reg [7:0] inst_regnum_cache[255:0];
  reg [15:0] inst_address_num_cache[255:0];
  reg [7:0] loop_counter = 0;
  reg [7:0] loop_counter_max = 0;
  reg [5:0] loop_regnum;
  reg [7:0] loop_value;
  reg [1:0] loop_type;

  `define LOOP_TILL_VALUE 1
  `define LOOP_TILL_NON_VALUE 2
  `define LOOP_FOR 3

  `define STAGE_READ_PC1_REQUEST 0
  `define STAGE_READ_PC1_RESPONSE 1
  `define STAGE_READ_PC2_REQUEST 2
  `define STAGE_READ_PC2_RESPONSE 3
  `define STAGE_DECODE 4
  `define STAGE_READ_RAM2REG 5
  `define STAGE_SAVE_REG2RAM 6

  `define OPCODE_JMP 1     //x, 16 bit address
  `define OPCODE_RAM2REG 2 //register num, 16 bit source addr //ram -> reg
  `define OPCODE_REG2RAM 3 //register num, 16 bit source addr //reg -> ram
  `define OPCODE_NUM2REG 4 //register num, 16 bit value //value -> reg
  `define OPCODE_REG_PLUS 5 //register num, 16 bit value // reg += value
  `define OPCODE_REG_MINUS 6 //register num, 16 bit value  //reg -= value
  `define OPCODE_REG_MUL 7 //register num, 16 bit value // reg *= value
  `define OPCODE_REG_DIV 8 //register num, 16 bit value  //reg /= value
  `define OPCODE_TILL_VALUE 9   //register num, value, how many instructions (8 bit value) // do..while
  `define OPCODE_TILL_NON_VALUE 10   //register num, value, how many instructions (8 bit value) //do..while
  `define OPCODE_LOOP 11   //x, x, how many instructions (8 bit value) //for...
  `define OPCODE_PROC 12 //new process
  `define OPCODE_REG_INT 14
  `define OPCODE_INT 15
  `define OPCODE_INT_RET 16

  always @(posedge rst) begin
    $display($time, "rst");
    stage <= `STAGE_READ_PC1_REQUEST;
    enb   <= 1;
    ena   <= 1;
  end

  always @(stage) begin
    if (stage == `STAGE_READ_PC1_REQUEST) begin
      if (loop_counter > loop_counter_max) begin
        inst_op <= inst_op_cache[loop_counter_max];
        inst_regnum <= inst_regnum_cache[loop_counter_max];
        inst_address_num <= inst_address_num_cache[loop_counter_max];
        loop_counter_max <= loop_counter_max + 1;
        address_pc <= address_pc + 2;
        $display($time, (address_pc), "=", inst_op, inst_regnum, inst_address_num / 256,
                 inst_address_num % 256, " (cache)");
        stage <= `STAGE_DECODE;
      end else begin
        addrb <= address_pc;
        stage <= `STAGE_READ_PC1_RESPONSE;
      end
    end else if (stage == `STAGE_READ_PC2_REQUEST) begin
      addrb <= address_pc;
      stage <= `STAGE_READ_PC2_RESPONSE;
    end else if (stage == `STAGE_DECODE) begin
      if (inst_op == `OPCODE_JMP) begin
        $display($time, " opcode = jmp to ", inst_address_num);
        address_pc <= inst_address_num;
        stage <= `STAGE_READ_PC1_REQUEST;
      end else if (inst_op == `OPCODE_RAM2REG) begin
        $display($time, " opcode = ram2reg address ", inst_address_num, " to reg ", inst_regnum);
        addrb <= inst_address_num;
        stage <= `STAGE_READ_RAM2REG;
      end else if (inst_op == `OPCODE_REG2RAM) begin
        $display($time, " opcode = reg2ram value ", registers[inst_regnum], " to address ",
                 inst_address_num);
        addra <= inst_address_num;
        dia   <= registers[inst_regnum];
        wea   <= 1;
        stage <= `STAGE_SAVE_REG2RAM;
      end else if (inst_op == `OPCODE_NUM2REG) begin
        $display($time, " opcode = num2reg value ", inst_address_num, " to reg ", inst_regnum);
        registers[inst_regnum] <= inst_address_num;
        stage <= `STAGE_READ_PC1_REQUEST;
      end else if (inst_op == `OPCODE_REG_PLUS) begin
        $display($time, " opcode = regplusnum value ", inst_address_num, " to reg ", inst_regnum);
        registers[inst_regnum] <= registers[inst_regnum] + inst_address_num;
        stage <= `STAGE_READ_PC1_REQUEST;
      end else if (inst_op == `OPCODE_REG_MINUS) begin
        $display($time, " opcode = regminusnum value ", inst_address_num, " to reg ", inst_regnum);
        registers[inst_regnum] <= registers[inst_regnum] - inst_address_num;
        stage <= `STAGE_READ_PC1_REQUEST;
      end else if (inst_op == `OPCODE_TILL_VALUE) begin
        $display($time, " opcode = looptillvalue ", inst_address_num % 256, " instruction, reg ",
                 inst_regnum);
        loop_counter <= 0;
        loop_regnum <= inst_regnum;
        loop_value <= inst_address_num / 256;
        loop_counter_max <= inst_address_num % 256;
        loop_type <= `LOOP_TILL_VALUE;
        stage <= `STAGE_READ_PC1_REQUEST;
      end else if (inst_op == `OPCODE_TILL_NON_VALUE) begin
        $display($time, " opcode = looptillnonvalue ", inst_address_num % 256,
                 " instruction, reg ", inst_regnum);
        loop_counter <= 0;
        loop_regnum <= inst_regnum;
        loop_value <= inst_address_num / 256;
        loop_counter_max <= inst_address_num % 256;
        loop_type <= `LOOP_TILL_NON_VALUE;
        stage <= `STAGE_READ_PC1_REQUEST;
      end else if (inst_op == `OPCODE_LOOP) begin
        $display($time, " opcode = looploop ", inst_address_num % 256, " instruction, reg ",
                 inst_regnum);
        loop_counter <= 0;
        loop_value <= inst_address_num / 256;
        loop_counter_max <= inst_address_num % 256;
        loop_type <= `LOOP_FOR;
        stage <= `STAGE_READ_PC1_REQUEST;
      end else begin
        $display($time, " opcode = ", inst_op);
        stage <= `STAGE_READ_PC1_REQUEST;
      end
      if (loop_counter_max != 0 && loop_counter_max == loop_counter) begin
        if ((loop_type == `LOOP_TILL_VALUE && registers[loop_regnum] != loop_value) ||
        (loop_type == `LOOP_TILL_NON_VALUE && registers[loop_regnum] == loop_value) ||
        (loop_type == `LOOP_FOR && loop_value>0)) begin
          address_pc <= address_pc - loop_counter * 2;
          loop_counter_max <= 0;
          if (loop_type == `LOOP_FOR) loop_value <= loop_value - 1;
        end else begin
          loop_counter <= 0;
          loop_counter_max <= 0;
          address_pc <= address_pc + 2;
        end
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
      inst_op <= dob[15:8];
      inst_regnum <= dob[7:0];
      address_pc <= address_pc + 1;
      if (loop_counter_max != 0) begin
        inst_op_cache[loop_counter] <= dob[15:8];
        inst_regnum_cache[loop_counter] <= dob[7:0];
      end
      stage <= `STAGE_READ_PC2_REQUEST;
    end else if (stage == `STAGE_READ_PC2_RESPONSE) begin
      $display($time, " ", (address_pc - 1), "=", inst_op, inst_regnum, dob / 256, dob % 256);
      inst_address_num <= dob;
      if (loop_counter_max != 0) begin
        inst_address_num_cache[loop_counter] <= dob;
        loop_counter <= loop_counter + 1;
      end
      address_pc <= address_pc + 1;
      stage <= `STAGE_DECODE;
    end else if (stage == `STAGE_READ_RAM2REG) begin
      $display($time, "          reg ", inst_regnum, " = ", dob);
      registers[inst_regnum] <= dob;
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

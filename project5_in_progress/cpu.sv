`timescale 1ns / 1ps

`define MMU_DEBUG 0

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

  //current instruction - we don't need to multiply it among processes, because we don't support partially executed op. before process switch
  reg [4:0] stage; //it doesn't need process index - we switch to other process after completing instruction
  reg [4:0] stage_after_mmu; //temporary value - after MMU related stage we switch to another "correct one"
  reg [7:0] inst_op;  //instruction / operation code
  reg [7:0] inst_reg_num;  //in majority cases: processed / affected register number
  reg [15:0] inst_address_num;  //in majority caes: processed / affected memory address

  reg [2:0] process_index = 0; //process related. We cache data about n=8 processes - here we save index value for other tables

  //values for all processes - need to be separated for every process
  reg [9:0] address_pc[2:0];  //n=2^3=8 addresses
  reg [15:0] registers[2:0][5:0];  //64 registers * n=8 processes = 512 16-bit registers

  //cache used in all loops - needs to be separated for every process
  reg [7:0] inst_op_cache[2:0][255:0];  // 256 * n=8 processes = 2048
  reg [7:0] inst_reg_num_cache[2:0][255:0];
  reg [15:0] inst_address_num_cache[2:0][255:0];

  //loop executions - need to be separate for every process
  reg [7:0] loop_counter[2:0];
  reg [7:0] loop_counter_max[2:0];
  reg [5:0] loop_reg_num[2:0];
  reg [7:0] loop_comp_value[2:0];
  reg [1:0] loop_type[2:0];

  //MMU (Memory Management Unit)
  reg [9:0] mmu_input_addr;  //address to translate
  reg [15:0] mmu_chain_memory[0:1000];  //values = next physical page index for process; last entry = 0
  reg [15:0] mmu_logical_pages_memory[0:1000];  //values = logical process page assigned to physical page; 0 means empty oage
                                                //(in existing processes - we setup here value > 0 for first page with index 0 and ignore it)
  reg [15:0] mmu_index_start; // this is start index of the loop searching for free memory page; when reserving pages, increase;
                              // when deleting, setup to lowest free value
  reg [15:0] mmu_logical_index_new;
  reg [15:0] mmu_logical_index_old;
  reg [15:0] mmu_physical_index_old;
  reg [15:0] mmu_start_process_segment;  //needs to be updated on process switch
  reg [15:0] mmu_last_process_segment;  //used during search for finding last process segment

  `define MMU_PAGE_SIZE 5

  `define LOOP_TILL_VALUE 0
  `define LOOP_TILL_NON_VALUE 1
  `define LOOP_FOR 2

  `define STAGE_READ_PC1_REQUEST 0
  `define STAGE_READ_PC1_RESPONSE 1
  `define STAGE_READ_PC2_REQUEST 2
  `define STAGE_READ_PC2_RESPONSE 3
  `define STAGE_DECODE 4
  `define STAGE_READ_RAM2REG 5
  `define STAGE_SAVE_REG2RAM 6
  `define STAGE_MMU_B 7
  `define STAGE_MMU_BB 8
  `define STAGE_MMU_BBB 9
  `define STAGE_MMU_A 10
  `define STAGE_MMU_AA 11
  `define STAGE_MMU_AAA 12

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
    $display($time, "rst");  //DEBUG info
    enb <= 1;
    ena <= 1;
    stage <= `STAGE_READ_PC1_REQUEST;
    address_pc[process_index] <= 0;
    loop_counter[process_index] <= 0;
    loop_counter_max[process_index] <= 0;
    mmu_start_process_segment <= 0;
    mmu_index_start <= 0;
    mmu_chain_memory[0] <= 0;
    //problem: we shouldn't mix blocking and non-blocking
    for (
        mmu_logical_index_new = 0;
        mmu_logical_index_new < 1000;
        mmu_logical_index_new = mmu_logical_index_new + 1
    ) begin
      //value 0 means, that it's empty. in every process on first entry we setup something != 0 and ignore it
      // (first process page is always from segment 0)
      mmu_logical_pages_memory[mmu_logical_index_new] = 0;
    end
    mmu_logical_pages_memory[0] = 1;
  end

  always @(mmu_logical_index_old) begin
    if (mmu_logical_index_new === 0 && mmu_physical_index_old === mmu_start_process_segment) begin
      stage <= stage + 1;
    end else if (mmu_physical_index_old !== mmu_start_process_segment && mmu_logical_pages_memory[mmu_physical_index_old]===mmu_logical_index_new) begin
      stage <= stage + 1;
    end else if (mmu_chain_memory[mmu_physical_index_old] === 0) begin
      mmu_last_process_segment <= mmu_physical_index_old;
      mmu_index_start <= mmu_index_start + 1;
    end else begin
      mmu_physical_index_old <= mmu_chain_memory[mmu_physical_index_old];
      mmu_logical_index_old  <= mmu_logical_pages_memory[mmu_chain_memory[mmu_physical_index_old]];
    end
  end

  always @(mmu_index_start) begin
    if (!rst) begin
      if (mmu_logical_pages_memory[mmu_index_start] === 0) begin
        if (`MMU_DEBUG === 1) $display($time, " mmu new page ");  //DEBUG info
        mmu_chain_memory[mmu_last_process_segment] <= mmu_index_start;
        mmu_chain_memory[mmu_index_start] <= 0;
        mmu_logical_pages_memory[mmu_index_start] <= mmu_logical_index_new;
        mmu_physical_index_old <= mmu_index_start;
        stage <= stage + 1;
      end else begin
        mmu_index_start <= mmu_index_start + 1;
      end
    end
  end

  integer i;  //DEBUG info
  string  s;  //DEBUG info

  always @(stage) begin
    if (stage == `STAGE_READ_PC1_REQUEST) begin
      if (loop_counter[process_index] > loop_counter_max[process_index]) begin
        inst_op <= inst_op_cache[process_index][loop_counter_max[process_index]];
        inst_reg_num <= inst_reg_num_cache[process_index][loop_counter_max[process_index]];
        inst_address_num <= inst_address_num_cache[process_index][loop_counter_max[process_index]];
        loop_counter_max[process_index] <= loop_counter_max[process_index] + 1;
        address_pc[process_index] <= address_pc[process_index] + 2;
        $display($time, (address_pc[process_index]), "=", inst_op, inst_reg_num,  //DEBUG info
                 inst_address_num / 256,  //DEBUG info
                 inst_address_num % 256, " (cache)");  //DEBUG info
        stage <= `STAGE_DECODE;
      end else begin
        mmu_input_addr <= address_pc[process_index];
        stage_after_mmu <= `STAGE_READ_PC1_RESPONSE;
        stage <= `STAGE_MMU_B;
      end
    end else if (stage == `STAGE_READ_PC2_REQUEST) begin
      mmu_input_addr <= address_pc[process_index];
      stage_after_mmu <= `STAGE_READ_PC2_RESPONSE;
      stage <= `STAGE_MMU_B;
    end else if (stage == `STAGE_MMU_B || stage == `STAGE_MMU_A) begin
      mmu_logical_index_new <= mmu_input_addr / `MMU_PAGE_SIZE; //FIXME: it's enough just to take concrete bits
      stage <= stage + 1;
    end else if (stage == `STAGE_MMU_BB || stage == `STAGE_MMU_AA) begin
      if (mmu_logical_index_old == mmu_logical_index_new) begin
        //we have already translated address. We can us it
        stage <= stage + 1;
      end else begin
        mmu_physical_index_old <= mmu_start_process_segment;
        mmu_logical_index_old  <= mmu_logical_index_new;
      end
    end else if (stage == `STAGE_MMU_BBB || stage == `STAGE_MMU_AAA) begin
      if (stage == `STAGE_MMU_AAA) begin
        addra <= mmu_physical_index_old * `MMU_PAGE_SIZE + mmu_input_addr % `MMU_PAGE_SIZE; //FIXME: bits moving and concatenation
        wea <= 1;
      end else begin
        addrb <= mmu_physical_index_old * `MMU_PAGE_SIZE + mmu_input_addr % `MMU_PAGE_SIZE;
      end
      stage <= stage_after_mmu;
      if (`MMU_DEBUG === 1) //DEBUG info
        $display( //DEBUG info
            $time, //DEBUG info
            " mmu from ", //DEBUG info
            addr, //DEBUG info
            " to ",  //DEBUG info
            (mmu_physical_index_old * `MMU_PAGE_SIZE + addr % `MMU_PAGE_SIZE) //DEBUG info
        );  //DEBUG info
      s = " mmu ";  //DEBUG info
      for (i = 0; i <= 10; i = i + 1) begin  //DEBUG info
        s = { //DEBUG info
          s, $sformatf("%02x-%02x ", mmu_chain_memory[i], mmu_logical_pages_memory[i]) //DEBUG info
        };  //DEBUG info
      end  //DEBUG info
      if (`MMU_DEBUG === 1) $display($time, s);  //DEBUG info
    end else if (stage == `STAGE_DECODE) begin
      if (inst_op == `OPCODE_JMP) begin
        $display($time, " opcode = jmp to ", inst_address_num);  //DEBUG info
        address_pc[process_index] <= inst_address_num;
        stage <= `STAGE_READ_PC1_REQUEST;
      end else if (inst_op == `OPCODE_RAM2REG) begin
        $display($time, " opcode = ram2reg address ", inst_address_num, " to reg ",  //DEBUG info
                 inst_reg_num);  //DEBUG info
        mmu_input_addr <= inst_address_num;
        stage_after_mmu <= `STAGE_READ_RAM2REG;
        stage <= `STAGE_MMU_B;
      end else if (inst_op == `OPCODE_REG2RAM) begin
        $display($time, " opcode = reg2ram value ",  //DEBUG info
                 registers[process_index][inst_reg_num],  //DEBUG info
                 " to address ",  //DEBUG info
                 inst_address_num);  //DEBUG info
        dia <= registers[process_index][inst_reg_num];
        mmu_input_addr <= inst_address_num;
        stage_after_mmu <= `STAGE_SAVE_REG2RAM;
        stage <= `STAGE_MMU_A;
      end else if (inst_op == `OPCODE_NUM2REG) begin
        $display($time, " opcode = num2reg value ", inst_address_num, " to reg ",  //DEBUG info
                 inst_reg_num);  //DEBUG info
        registers[process_index][inst_reg_num] <= inst_address_num;
        stage <= `STAGE_READ_PC1_REQUEST;
      end else if (inst_op == `OPCODE_REG_PLUS) begin
        $display($time, " opcode = regplusnum value ", inst_address_num, " to reg ",  //DEBUG info
                 inst_reg_num);  //DEBUG info
        registers[process_index][inst_reg_num] <= registers[process_index][inst_reg_num] + inst_address_num;
        stage <= `STAGE_READ_PC1_REQUEST;
      end else if (inst_op == `OPCODE_REG_MINUS) begin
        $display($time, " opcode = regminusnum value ", inst_address_num, " to reg ",  //DEBUG info
                 inst_reg_num);  //DEBUG info
        registers[process_index][inst_reg_num] <= registers[process_index][inst_reg_num] - inst_address_num;
        stage <= `STAGE_READ_PC1_REQUEST;
      end else if (inst_op == `OPCODE_TILL_VALUE || 
            inst_op == `OPCODE_TILL_NON_VALUE || 
            inst_op == `OPCODE_LOOP) begin
        $display($time, " opcode = tillorloop ", inst_address_num % 256,  //DEBUG info
                 " instructions, comp. value ", inst_address_num / 256,  //DEBUG info
                 " reg/loop value ",  //DEBUG info
                 inst_address_num % 256);  //DEBUG info
        loop_reg_num[process_index] <= inst_reg_num;
        loop_comp_value[process_index] <= inst_address_num / 256;
        loop_counter_max[process_index] <= inst_address_num % 256;
        loop_type[process_index] <= inst_op - `OPCODE_TILL_VALUE;
        stage <= `STAGE_READ_PC1_REQUEST;
      end else begin
        $display($time, " opcode = ", inst_op);  //DEBUG info
        stage <= `STAGE_READ_PC1_REQUEST;
      end
      if (loop_counter_max[process_index] != 0 && loop_counter_max[process_index] == loop_counter[process_index]) begin
        if ((loop_type[process_index] == `LOOP_TILL_VALUE && registers[process_index][loop_reg_num[process_index]] != loop_comp_value[process_index]) ||
            (loop_type[process_index] == `LOOP_TILL_NON_VALUE && registers[process_index][loop_reg_num[process_index]] == loop_comp_value[process_index]) ||
            (loop_type[process_index] == `LOOP_FOR && loop_comp_value[process_index]>0)) begin
          address_pc[process_index] <= address_pc[process_index] - loop_counter[process_index] * 2;
          loop_counter_max[process_index] <= 0;
          if (loop_type[process_index] == `LOOP_FOR)
            loop_comp_value[process_index] <= loop_comp_value[process_index] - 1;
        end else begin
          loop_counter[process_index] <= 0;
          loop_counter_max[process_index] <= 0;
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
      inst_reg_num <= dob[7:0];
      address_pc[process_index] <= address_pc[process_index] + 1;
      if (loop_counter_max[process_index] != 0) begin
        inst_op_cache[process_index][loop_counter[process_index]] <= dob[15:8];
        inst_reg_num_cache[process_index][loop_counter[process_index]] <= dob[7:0];
      end
      stage <= `STAGE_READ_PC2_REQUEST;
    end else if (stage == `STAGE_READ_PC2_RESPONSE) begin
      $display($time, " ", (address_pc[process_index] - 1), "=", inst_op,  //DEBUG info
               inst_reg_num,  //DEBUG info
               dob / 256,  //DEBUG info
               dob % 256);  //DEBUG info
      inst_address_num <= dob;
      if (loop_counter_max[process_index] != 0) begin
        inst_address_num_cache[process_index][loop_counter[process_index]] <= dob;
        loop_counter[process_index] <= loop_counter[process_index] + 1;
      end
      address_pc[process_index] <= address_pc[process_index] + 1;
      stage <= `STAGE_DECODE;
    end else if (stage == `STAGE_READ_RAM2REG) begin
      $display($time, "          reg ", inst_reg_num, " = ", dob);  //DEBUG info
      registers[process_index][inst_reg_num] <= dob;
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
      //      if (wea) $display($time, " writing ", dia, " to ",addra); //DEBUG info
    end
  end
  always @(posedge clkb) begin
    if (enb) begin
      dob <= ram[addrb];
      //      $display($time, " reading ", ram[addrb], " from ",addrb); //DEBUG info
    end
  end
endmodule


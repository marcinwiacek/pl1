Welcome to the future or alternative to the mainstream in some scenarios.

Modern hardware architectures (like X86 or ARM) are very impressive, but have
some problems with security, complexity, intellectual property and/or government
control. Risc-V wants to avoid this, but when you look into specs, you will
see, that various elements and/or extensions have potentially doing the same
problems (see words from Linus Torvalds "They’ll have all
the same issues we have on the Arm side and that x86 had before them").

This project contains 1st working generation of the PL SoC (System On Chip).
It was initially created to check, how to create some hardware solutions
(+ to proove, that some hardware based solutions can be better
than software based one).

PL1 allows for creating and running OS and apps:

1. without kernel
2. with full protecting resources (you don't have hypervisor mode and other
stuff, which in the end is always compromised)
3. without various unnecessary operations (like copying memory during
interrupt or dumping things in ineffective way during task switch)

This is done without legacy stuff, which is big advantage (when you don't
have something, it cannot be broken).

Current implementation:

1. has got support for RS-232 output
2. has got OS concept directly in the bootloader
3. doesn't have deep pipelining (planned in short future), asynchrononous design
(planned in longer future) and support for video/SDCard/RS-232 input/Ethernet/DDRx
(planned)
4. has got probably many FPGA design mistakes (they're removed step by step)
5. works in the Artix-7 Nexys Video board

Statistics:

Instruction set

First 8 bits - instruction code
Next 24 bits - instruction parameters

OPCODE_JMP: code 1, 24 bit target address
OPCODE_JMP16: code 2, 8 bits unused, 16 bits with register num with target addr (we read one reg)
OPCODE_JMP32: code 3, 8 bits unused, 16 bits with first register num with target addr (we read two reg)
OPCODE_JMP_PLUS: code 5, 8 bits unused, 16 bit how many instructions
OPCODE_JMP_PLUS16: code 6, 8 bits unused, 16 bits with register num with info (we read one reg)
OPCODE_JMP_MINUS: code 7, 8 bits unused, 16 bit how many instructions
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
  parameter OPCODE_REG_INT = 'h1a;  //int number (8 bit), start memory page, end memory page 
  parameter OPCODE_INT = 'h1b;  //int number (8 bit), start memory page, end memory page
  parameter OPCODE_INT_RET = 'h1c;  //int number


**Welcome to the future or at least alternative to the mainstream.**

Modern hardware architectures (like X86 or ARM) are very impressive, but have
some problems with security, complexity, intellectual property and/or government
control. Risc-V wants to avoid this, but when you look into specs, you will
see, that various elements and/or extensions have potentially doing the same
problems (see words from Linus Torvalds "They’ll have all
the same issues we have on the Arm side and that x86 had before them").

This project contains 1st working generation of the PL SoC (System On Chip).

PL1 currently allows for creating and running OS and apps:

1. without kernel
2. with full protecting resources (you don't have hypervisor mode and other
stuff, which earlier or later is compromised)
3. without various unnecessary operations (like copying memory during
interrupts or dumping things in ineffective way during task switch)

This is done without legacy stuff, which is big advantage (when you don't
have something, it cannot be broken).

# Current implementation:

1. has got support for RS-232 output
2. has got OS concept directly in the bootloader
3. doesn't have deep pipelining (planned in short future), asynchrononous design
(planned in longer future) and support for video/SDCard/RS-232 input/Ethernet/DDRx
(planned)
4. has got probably many FPGA design mistakes (they're removed step by step)
5. works in the Artix-7 Nexys Video board

# Statistics:

# Instruction set

First 8 bits - instruction code
Next 24 bits - instruction parameters

OPCODE_JMP = 1;  //24 bit target address
OPCODE_JMP16 = 2;  //x, register num with target addr (we read one reg)
  // OPCODE_JMP32 = 3;  //x, first register num with target addr (we read two reg)
  // OPCODE_JMP64 = 4;  //x, first register num with target addr (we read four reg)  
OPCODE_JMP_PLUS = 5;  //x, 16 bit how many instructions
OPCODE_JMP_PLUS16 = 6;  //x, register num with info (we read one reg)
OPCODE_JMP_MINUS = 7;  //x, 16 bit how many instructions  
OPCODE_JMP_MINUS16 = 8;  //x, register num with info (we read one reg)
OPCODE_RAM2REG = 9;  //register num (5 bits), how many-1 (3 bits), 16 bit source addr //ram -> reg
OPCODE_RAM2REG16 = 'ha; //start register num, how many registers, register num with source addr (we read one reg), //ram -> reg  
  // OPCODE_RAM2REG32 = 11; //start register num, how many registers, first register num with source addr (we read two reg), //ram -> reg
  // OPCODE_RAM2REG64 = 12; //start register num, how many registers, first register num with source addr (we read four reg), //ram -> reg
OPCODE_REG2RAM = 'he; //14 //register num (5 bits), how many-1 (3 bits), 16 bit target addr //reg -> ram
OPCODE_REG2RAM16 = 'hf; //15 //start register num, how many registers, register num with target addr (we read one reg), //reg -> ram
  // OPCODE_REG2RAM32 = 16; //start register num, how many registers, first register num with target addr (we read two reg), //reg -> ram
  // OPCODE_REG2RAM64 = 17; //start register num, how many registers, first register num with target addr (we read four reg), //reg -> ram
OPCODE_NUM2REG = 'h12; //18;  //register num (5 bits), how many-1 (3 bits), 16 bit value //value -> reg
OPCODE_REG_PLUS = 'h14;//20; //register num (5 bits), how many-1 (3 bits), 16 bit value // reg += value
OPCODE_REG_MINUS = 'h15; //register num (5 bits), how many-1 (3 bits), 16 bit value  //reg -= value
OPCODE_REG_MUL = 'h16; //register num (5 bits), how many-1 (3 bits), 16 bit value // reg *= value
OPCODE_REG_DIV ='h17; //register num (5 bits), how many-1 (3 bits), 16 bit value  //reg /= value
OPCODE_EXIT = 'h18;  //exit process
OPCODE_PROC = 'h19;  //new process //how many segments, start segment number (16 bit)
OPCODE_REG_INT = 'h1a;  //int number (8 bit), start memory page, end memory page 
OPCODE_INT = 'h1b;  //int number (8 bit), start memory page, end memory page
OPCODE_INT_RET = 'h1c;  //int number

# MMU

MMU is handling RAM paging (for testing purposes every page has got 70 bytes) and has got two memories:

* mmu_chain_memory - index: physical RAM page; value: next physical page index for the process (when value is equal to index, it means end of the chain)
* mmu_logical_pages_memory - index: physical RAM page; value: logical process page assigned to physical page (exception: when process is not used, for process page 0 we save index of first element in the process chain)

mmu_logical_pages_memory == 0 && mmu_chain_memory == 0 means, that page is free
(note: 0,0 can be assigned to process starting from physical page 0
and because of it we have mmu_first_possible_free_physical_page saving index of first possible free page).

Every process has got two start points - mmu_start_process_physical_page (index
of the first element in the process chain) and mmu_start_process_physical_page_zero (shows index of the process page 0).

mmu_chain_memory is sorted during each searching for memory page - last
found index is moved into beginning of the chain.

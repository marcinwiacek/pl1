**Welcome to the future or at least some alternative to the mainstream.**

Modern hardware (like X86 or ARM) is very impressive, but has got
some problems with security, complexity, intellectual property and/or government
control. Risc-V wants to avoid this, but when you look into [specs](https://riscv.org/technical/specifications/), you will
see, that various elements and/or extensions are complex or
have potentially the same problems (see words from Linus Torvalds "They’ll have all
the same issues we have on the Arm side and that x86 had before them").

This project contains first working version or generation of the PL1 SoC (System On Chip).

PL1 currently allows for creating and running OS and apps:

1. without kernel
2. with full protecting resources
3. without many unnecessary operations

Applications are communicating with each other using interrupts + memory
sharing. There are no other ways for doing this & you don't have kernel
or hypervisor mode, which is big advantage (when you don't have something, it cannot be broken).

**Current implementation**

1. has got support for RS-232 output
2. has got OS concept directly in the bootloader
3. doesn't have deep pipelining (planned in short future), asynchrononous design and multicore support (planned in longer future) and support for video/SDCard/RS-232 input/Ethernet/DDRx (planned)
4. has got many FPGA design mistakes (they're removed step by step)
5. works in the [Artix-7 Nexys Video FPGA board](https://digilent.com/reference/programmable-logic/nexys-video/reference-manual)

**Statistics**

**Instruction set**

Format:

* First 8 bits - instruction code
* Next 24 bits - instruction parameters

Instructions:

* OPCODE_JMP = 1;  //24 bit target address
* OPCODE_JMP16 = 2;  //x, register num with target addr (we read one reg)
*  // OPCODE_JMP32 = 3;  //x, first register num with target addr (we read two reg)
*  // OPCODE_JMP64 = 4;  //x, first register num with target addr (we read four reg)  
* OPCODE_JMP_PLUS = 5;  //x, 16 bit how many instructions
* OPCODE_JMP_PLUS16 = 6;  //x, register num with info (we read one reg)
* OPCODE_JMP_MINUS = 7;  //x, 16 bit how many instructions  
* OPCODE_JMP_MINUS16 = 8;  //x, register num with info (we read one reg)
* OPCODE_RAM2REG = 9;  //register num (5 bits), how many-1 (3 bits), 16 bit source addr //ram -> reg
* OPCODE_RAM2REG16 = 'ha; //start register num, how many registers, register num with source addr (we read one reg), //ram -> reg  
* // OPCODE_RAM2REG32 = 11; //start register num, how many registers, first register num with source addr (we read two reg), //ram -> reg
* // OPCODE_RAM2REG64 = 12; //start register num, how many registers, first register num with source addr (we read four reg), //ram -> reg
* OPCODE_REG2RAM = 'he; //14 //register num (5 bits), how many-1 (3 bits), 16 bit target addr //reg -> ram
* OPCODE_REG2RAM16 = 'hf; //15 //start register num, how many registers, register num with target addr (we read one reg), //reg -> ram
* // OPCODE_REG2RAM32 = 16; //start register num, how many registers, first register num with target addr (we read two reg), //reg -> ram
* // OPCODE_REG2RAM64 = 17; //start register num, how many registers, first register num with target addr (we read four reg), //reg -> ram
* OPCODE_NUM2REG = 'h12; //18;  //register num (5 bits), how many-1 (3 bits), 16 bit value //value -> reg
* OPCODE_REG_PLUS = 'h14;//20; //register num (5 bits), how many-1 (3 bits), 16 bit value // reg += value
* OPCODE_REG_MINUS = 'h15; //register num (5 bits), how many-1 (3 bits), 16 bit value  //reg -= value
* OPCODE_REG_MUL = 'h16; //register num (5 bits), how many-1 (3 bits), 16 bit value // reg *= value
* OPCODE_REG_DIV ='h17; //register num (5 bits), how many-1 (3 bits), 16 bit value  //reg /= value
* OPCODE_EXIT = 'h18;  //exit process
* OPCODE_PROC = 'h19;  //new process //how many segments, start segment number (16 bit)
* OPCODE_REG_INT = 'h1a;  //int number (8 bit), start memory page, end memory page 
* OPCODE_INT = 'h1b;  //int number (8 bit), start memory page, end memory page
* OPCODE_INT_RET = 'h1c;  //int number

**MMU**

MMU is handling RAM paging (for testing purposes every page has got 70 bytes) and has got two memories:

* mmu_chain_memory - index: physical RAM page; value: next physical page index for the process (when value is equal to index, it means end of the chain)
* mmu_logical_pages_memory - index: physical RAM page; value: logical process page assigned to physical page (exception: when process is not used, for process page 0 we save index of first element in the process chain)

mmu_logical_pages_memory == 0 && mmu_chain_memory == 0 means, that page is free
(note: 0,0 can be assigned to process starting from physical page 0
and because of it we have mmu_first_possible_free_physical_page saving index of first possible free page).

Every process has got two start points:

1. mmu_start_process_physical_page (index of the first element in the process chain saved for process page 0 in mmu_logical_pages_memory when process is not used)
2. mmu_start_process_physical_page_zero (shows index of the process page 0)

Example:

* mmu_chain_memory - 1, 2, 3, 3
* mmu_logical_pages_memory - 0, 1, 2, 3
* mmu_start_process_physical_page - 0

In this case: physical page 0 contains logical page 0, physical page 1 contains logical page 1, physical page 2 contains logical page 2 and physical page 3 contains logical page 3. PL1 is going into index 0, then 1, then 2 and in the end 3.

To speed up things:

1. mmu_chain_memory - sorted during each searching for memory page (last found index is moved into beginning of the chain, which speed up search in the future)
2. new allocated page - saved in the beginning of chain
3. instruction fetch - CPU is calculating page for instruction fetch only when we (potentially) change page (in other cases we have cache with calculated value and just increase it by two)
4. shared memory - when we're inside interrupt, normally we should have shared memory info in the calling process chain. PL1 doesn't waste time to make any updates for it in the interrupt process, but is operating in the calling process chain

Planned:

1. started work on table caching all translations: index - logical page, values - process address & physical page assigned to it in the process
(searching in this table could be done in parallel to search in mmu_chain_memory and mmu_logical_memory)
2. increasing width of MMU memories and, if possible, further parallelization

**Process memory**

In the first process page we save on beginning few elements:

* 4 16-bit bytes with address of next process (current PL1 is using just one byte, other are reserved)
* 4 16-bit bytes with logical PC value
* 2 16-bit bytes with information, which registers have values different than zero (one bit - one register)
* 32 16-bit bytes with register values

**Process switching**

Every modern CPU / OS is running many processes in parallel. Software based switching gives flexibility, but... it can be not so effective like hardware one.

1. PL1 has got tables, where can save state of few processes (when one of them exist in the table, switching length is similiar to executing ONE instruction)
2. when process info is not found in tables, we try to read only these registers from memory, which have value different than zero

PL1 is building in the memory one way list with the process addresses and switching to next one just specified number of instructions (in the future we will count number of cycles and / or have priorities). Process registered for interrupt is excluded during exuection, when we execute interrupt, we switch called process with interrupt process in this chain.

**My development environment**

1. free Ubuntu
2. free Vivado version from https://www.xilinx.com/support/download.html (needs free registration;
after installing needs installing drivers for cables and adding board definition;
update tool can be started with binary xic/xic)
3. board

**It doesn't have any sense**

I will remind you August 1991 and Linus Torvalds:

"I'm doing a (free) operating system (just a hobby, won't be big and professional like gnu) for 386(486) AT clones. This has been brewing since april, and is starting to get ready. I'd like any feedback on things people like/dislike in minix, as my OS resembles it somewhat (same physical layout of the file-system (due to practical reasons) among other things)."

Today we have Linux kernel on desktops, in phones and many other devices.

Who knows, maybe PL1 will help in creating next gen solutions?

Even now it looks very promising + gives very big fun, when works :)

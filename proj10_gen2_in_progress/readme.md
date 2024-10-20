**Welcome to the future or at least alternative to the mainstream.**

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

**Hardware or software? And why FPGA?**

Hardware in PL1 is going rather into RISC (simple, short instructions)... but
it's additionally doing things, which normally are software based in all modern
operating systems (excluding some embedded solutions, you can't find one user operating system working just with one task and you always need kernel with task switcher and this can be done better and faster with hardware).

Some simulators for PL1 ideas were written in very short time and the whole project
could be stopped in this moment (software could be emulated in some ARM and that's it)... but idea was to build the whole system close to real hardware as much as possible.

FPGA is the only choice available with sensible money and Artix-7 board was selected because of architecture, price and extra features ([additionally AMD gives support for it till 2040](https://community.amd.com/t5/adaptive-computing/amd-supports-new-long-lifecycle-fpga-designs-through-2040-2045/ba-p/702533)).

**Current implementation**

1. has got support for RS-232 input/output
2. has got OS concept directly in the bootloader
3. doesn't have pipelining (planned in short future), asynchrononous design and multicore support (planned in longer future) and support for HDMI/SDCard/Ethernet/DDRx (planned)
4. has got probably many FPGA design mistakes (they're removed step by step)
5. works with the [Artix-7 Nexys Video FPGA board](https://digilent.com/reference/programmable-logic/nexys-video/reference-manual)

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

MMU is handling RAM paging (for testing purposes every page has got 100 bytes) and in current memory has got only one memory mmu_free_page, the real mapping is saved in RAM:

In process segment 0 we have

* mmu_segment_length,
* physical segment address for mmu logical page 1 or 0 (not assigned)
* physical segment address for mmu logical page 2 or 0 (not assigned)
* ...
* physical segment address for mmu logical page n or 0 (not assigned)
* address of next mmu segment

Next MMU segments use the whole memory segment just for the MMU:

* mmu_segment_length (how many entries are initialited)
* physical segment address for mmu logical page n+1 or 0 (not assigned)
* physical segment address for mmu logical page n+2 or 0 (not assigned)
* ...
* address of next mmu segment

MMU just needs to find correct page and read value from value indexed by logical page number.

Complexity of search is generally n (n=number of assigned process pages
divided by single MMU page size, which gives 1 with small processes), additionally future PL1 should sort MMU pages (order will be dependent on access order)

**Process memory**

In the first process page we save on beginning few elements:

* 4 16-bit bytes with address of next process (current PL1 is using just one byte, other are reserved)
* 4 16-bit bytes with logical PC value
* 2 16-bit bytes with information, which registers have values different than zero (one bit - one register)
* 32 16-bit bytes with register values
* 8 16-bit bytes with first MMU pages

**Process switching**

Once again: every modern CPU / OS is running many processes in parallel. Software based switching gives flexibility, but... it can be not so effective like hardware one.

1. PL1 has got tables, where can save state of few processes (when one of them exist in the table, switching length is similiar to executing ONE instruction)
2. when process info is not found in tables, we read from RAM only these registers, which have value different than zero

PL1 is building in the memory one way list with the process addresses and switching to next one just specified number of instructions (in the future we will count number of cycles and / or have priorities). Process registered for interrupt is excluded during exuection, when we execute interrupt, we switch called process with interrupt process in this chain.

**My development environment**

1. free Ubuntu
2. free Vivado version from https://www.xilinx.com/support/download.html (needs free registration;
after installing needs installing drivers for cables and adding board definition;
update tool can be started with binary xic/xic)
3. non-free FPGA board (when you look on Artix-7 boards, Nexys Video is not the cheapest one,
but... doesn't have any compromises, seems to be less complicated than Zynq 7000 systems and Ultra96-V2 Zynq UltraScale+ and it's still much cheaper than any industry FPGA board)

In the future things will be probably ported to the cheapest Artix-7 35T, Zynq 7000 or Ultra96-V2 Zynq UltraScale+.

**Why not RISC-V?**

Some things definitely can be done easier. RISC-V contains more and more extensions and possibilities
and it's becoming another ARM or X86 (which is confirmed by this, that physical implementations already had
problems typical for X86)

**It doesn't have any sense**

I will remind August 1991 and Linus Torvalds:

"I'm doing a (free) operating system (just a hobby, won't be big and professional like gnu) for 386(486) AT clones. This has been brewing since april, and is starting to get ready. I'd like any feedback on things people like/dislike in minix, as my OS resembles it somewhat (same physical layout of the file-system (due to practical reasons) among other things)."

Today we have Linux kernel on desktops, in phones and many other devices.

Who knows, maybe PL1 will help in creating next gen solutions?

Even now it looks very promising + gives very big fun, when works :)

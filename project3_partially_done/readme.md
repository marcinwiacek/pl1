Version 2404*

Work in progress

Verilog simulation with System Verilog 2005. 
I'm using here experiences from project 1 (mainly ideas related
to instruction list and processing handling) and project 2 (blocks and signals among them)

Although for example in YouTube it's possible to find some tips about modeling in
concrete software (for example [channel](https://www.youtube.com/playlist?list=PLilenfQGj6CEG6iZ4TQJ10PI7pCWsy1AO)),
I decided to go into plain code first and in the future it will probably end with:

  1. Verilog code
  2. software simulator in JavaScript

You can run Verilog code with run, I'm using Ubuntu.

Todo many things, for example:

  1. PROC implementation
  2. bug hunting
  3. loops (with cache already when possible)
  4. bug hunting
  5. interrupts
  6. bug reporting and process terminating

# Stages

  * stage12 - fetching & decoding (TODO: probably splitting)
  * stage 3 - RAM reading
  * stage 4 - ALU
  * stage 5 - RAM saving

Needs to resolve hazards and implement executing two processes in parallel (like
discussed earlier)

# Synchronous design
Every block (excluding RAM) has got input "exec" signal on positive signal change
from 0 to 1 (it means "start doing something") and output signal "exec ready"
(change from 0 to 1 means "execution done").

One exception is RAM - in real devices there will be the most probably DRAM
used and it needs clock.

Opened questions: will be this correctly synthetized in hardware? what about signal
propagations and for example such situation:

```
change signal 1
change signal 2
change exec ready to 1
```

? (will we have to additionally something proove, that signal 1 and 2 were correctly
changed?)

# Task switching

Every process in memory has the following structure:

  * address of next process (4 bytes)
  * PC register (4 bytes)
  * registers used (8 bytes, every bit contains info about one register)
  * registers (64 bytes = 512 bits)
  * program (code and data)

Program cannot access registers and everything below, they need to start with MMU segment, the same limit is with memory sharing (?).
Processor has got two process lists - one for active process, one for suspended.

We cache some values, for example task_switcher has got internal register set 
"registers_used", which is used during task switching only for saving/getting
really used registers. We have 64 bytes
of registers and in many cases can decrease amount or RAM  read/write operations
(we just read/save 4 extra bytes and we know, what register should be saved/restored)

# Instruction set

Addresses are in the end and are process type (16, 32 or 64 bit) related
(status: todo)

## Process and I/O related:

Done:

 * PROC - new process (todo: We need to say, if process is 16, 32 or 64 bit, additionally need to select data and code border)
 * PROC_END - end process
 * REGINT - register interrupt for current process (partially, without memory sharing)
 * INT - execute interrupt (partially)
 * INTRET - return from interrupt (partially)
 
TODO:

 5. FREERAMBLOCK
 6. REGINPORT - register code for input port support
 7. INPORTRET - return from input port support
 8. INPORT - read from port
 9. OUTPORT - save to port
 10. REGOUTPORT

## Register load/save (needs simple and vector instructions):

Done:

  * LOADFROMRAM - load from memory with specified address, params: target register number, length, source memory address, example: 2, 5, 123 loads data starting from address 123 and load into register 2-7
  * WRITETORAM - save to memory with specified address, params: source register number, length, target memory address
  * READFROMRAM - load from memory from address in register to register, params: target register number, length, register with source address, example: 2, 5, 1 loads data starting from address in register 1 and load into register 2-7
  * SAVETORAM - save to memory with address in register, params: source register number, length, register with target address
  * SETNUM8 - set registers

## Calculations: (needs simple and vector instructions)

Done:

  * ADD8 - add register A and B and save to register "out", 8-bit processing (format: register A start, register B start, register out start, length)
  * ADDNUM8 - add numeric value to registers

Todo:

  3. const DEC = 15; // decrease register with value, start, stop, value
  4. const DIV = 16;
  5. const MUL = 17;
  6. //leftbit
  7. //rightbit
  8. //xor
  9. //and
  10. //or
  11. //neg
  12. //neg2

## Jump:

Done:

  * JUMPPLUS howmany
  * JUMPMINUS howmany

Todo:

  * LOOPEQ howmany, register, value - block has got "howmany" instructions. 
When "register" has got "value", jump outside block else execute next block instructions. With this approach we can say to CPU "cache block instructions" (for normal used 1x it doesn't even have sence to write them into cache, with "howmany" 0 we have conditional jump)
  * LOOPNEQ howmany, register, value - block has got "howmany" instructions. 
When "register" is different than "value", jump outside block else execute next block instructions. With this approach we can say to CPU "cache block instructions" (for normal used 1x it doesn't even have sence to write them into cache, with "howmany" 0 we have conditional jump)

# Cache

# MMU

# INT

int process:

* int_reg - remove from normal list and add address to the int table, register int memory sharing

Calling process:

* int - replace current process with int process in the int table, setup int memory sharing

Int process:

  * execute
  * int_ret - return to int address and replace int process with normal process, delete int memory sharing

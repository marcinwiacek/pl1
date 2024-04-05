Verilog simulation. I'm using here experiences from project 1 (mainly ideas related
to instruction list and processing handling) and project 2 (blocks and signals among them)

Although for example in YouTube it's possible to find some tips about modeling in
concrete software (for example [channel](https://www.youtube.com/playlist?list=PLilenfQGj6CEG6iZ4TQJ10PI7pCWsy1AO)),
I decided to go into plain code first and in the future it will probably end with:

1. Verilog code
2. software simulator in JavaScript

You can run Verilog code with run, I'm using Ubuntu.

# Synchronous design
Every block (excluding RAM) has got input "exec" signal on positive signal change
from 0 to 1 (it means "start doing something") and output signal "exec ready"
(change from 0 to 1 means "execution done").

One exception is RAM - in real devices there will be the most probably DRAM
used and it needs clock.

Opened questions: will be this correctly synthetized in hardware? what about signal
propagations and for example such situation:

```change signal 1
change signal 2
change exec ready to 1```

? (will we have to additionally something proove, that signal 1 and 2 were correctly
changed?)

# Instruction set

Addresses are in the end and are process type (16, 32 or 64 bit) related

Process and I/O related:

 1. REGINT - register interrupt for current process
 2. INT - execute interrupt
 3. INTRET - return from interrupt
 4. PROC - new process. We need to say, if process is 16, 32 or 64 bit, additionally need to select data and code border
 5. FREERAMBLOCK
 6. REGINPORT - register code for input port support
 7. INPORTRET - return from input port support
 8. INPORT - read from port
 9. OUTPORT - save to port
 10. REGOUTPORT

Register load/save (needs simple and vector instructions):

 3. LOADFROMRAM - load from memory with specified address, params: target register number, length, source memory address, example: 2, 5, 123 loads data starting from address 123 and load into register 2-7
 4. WRITETORAM - save to memory with specified address, params: source register number, length, target memory address

 1. READFROMRAM - load from memory from address in register to register, params: target register number, length, register with source address, example: 2, 5, 1 loads data starting from address in register 1 and load into register 2-7
 2. SAVETORAM - save to memory with address in register, params: source register number, length, register with target address

Calculations: (needs simple and vector instructions)

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
 
 14. ADD8 - add register A and B and save to register "out", 8-bit processing (format: register A start, register B start, register out start, length)
 15. ADDNUM8 - add numeric value to registers

Jump:

 1. JUMPPLUS howmany
 2. JUMPMINUS howmany
 3. LOOPEQ howmany, register, value - block has got "howmany" instructions. 
When "register" has got "value", jump outside block else execute next block instructions. With this approach we can say to CPU "cache block instructions" (for normal used 1x it doesn't even have sence to write them into cache, with "howmany" 0 we have conditional jump)
 3. LOOPNEQ howmany, register, value - block has got "howmany" instructions. 
When "register" is different than "value", jump outside block else execute next block instructions. With this approach we can say to CPU "cache block instructions" (for normal used 1x it doesn't even have sence to write them into cache, with "howmany" 0 we have conditional jump)

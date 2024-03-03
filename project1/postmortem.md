Version 20240303

# Hardware switching and other ways to remove typical CPU problems

After creating first primitive software model for PL1 I have found, how
weak it is. Modeling things on the gate level requires total
other approach than software based (I have found such tools like *iverilog* or *vvp* or *gtkwave* and they're not very difficult, from the other hand
they need some extra self-study work). After getting some experiences with this model I decided to make summary
document postmortem document describing more deeply elements for upcoming
version 2.

# Pipelines/stages in CPU

Modern CPU are designed with splitting instruction execution into pipelines.
Unfamous Pentium IV had (too) many stages and because of it required a lot
of energy and was not able to achieve big processing speed. The most typical
approach to this topic is defining five stages:

1. instruction fetching
2. instruction decoding
3. execution (for example ALU operation and address calculating)
4. memory data access
5. register write back

The ideal situation is, that every CPU part (responsible for one stage)
is always executing something. Unfortunately it doesn't happen in 100%. It's possible, that for example:

1. first instruction is making some calculation and second instruction
needs already results (before they're ready)
2. program jumps and CPU knowns it in the end (which makes already fetched
or decoded instructions invalid)

Situations like this are called hazards or pipeline stalls... and CPUs are
trying to avoid it for example by putting some empty instructions between or reordering code order (if possible).

Now let's imagine, that first instruction is totally independent from second
and third and forth and fifth.

My proposal is, that CPU should first execute instruction from first
program/process/task, than (in next cycle) instruction from second program/process/task and so one.
Programs/tasks are normally totally independent. Thanks to this approach:

1. we can have better concurrency illusion (less instructions are stopping CPU and more threads are running smoothly)
2. in theory we will eliminate all types of hazards (if we handle enough tasks between, even jump prediction miss is not visible, because CPU will always know 100% correct address of new instruction).

What is required here?

1. CPU must be built with access to registers from all processed programs/processes/tasks (without delay). It means, that we need enough number of registers or L1 cache memory (access to every register for process can be achieved by getting/setting correct cache address).
2. CPU must handle task switching in hardware way (must know, where we have new instructions for all executed tasks)

What is not resolved here?

When CPU will execute only one task, we will still have stall situations.

Note: we can avoid instruction decoding and immediately read values of internal CPU registers and microcode (saying what should done in instruction) in first stage - this is how does work CPUs without instruction set. Maybe our CPU should have such mode optionally?

# Task switching

Majority/all general usage CPUs and OS are making context switch using some software elements in kernel. But what if CPU itself has got table indicating process status (is it active, what are register values, etc.) and is switching among them periodically?

We have seen some elements of it in the x86.

In the most primitive solution we need instructions for:

1. starting new task
2. ending own task
3. ending other task (possible only, when our process started this task)

and CPU can just switch to new active task after specified amount of time/executed instructions.

In the more advanced version we could have task priorities & schedule tasks and for example specify, that some of them should be resumed after one hour/on the specified time (we could connect scheduler with so called watchdog timer).

Extra profit: when no tasks are active, we could immediately disable CPU.

# Memory protection and sharing

Every process should have own logical memory space with addresses, which are changed on-fly to the hardware based. Normally such task is done by MMU. Sometimes it's independent from CPU, sometimes dependent.

In proposed solution:

1. MMU should use paging and translate every memory address as fast as possible (we will possibly use table with size equal to number of pages and values equal to pair [process number, logical page number in the process])
2. we should save at least one last translated logical-hardware page number pair for every process and it should be our cache (we will not clear it on context switch). Let's imagine, that process is asking for logical address 1 and MMU finds, that this is logical page 0 address assigned to physical page 3. This info should be cached and next time, when process is asking for all addresses from logical page 0 address, MMU should return immediately physical page 3 address.
3. data exchange between two processes should be possible only with memory sharing during interrupt call.
4. every process should have mechanism for blocking executing instruction from data area and this could be achieved with one address location register - all logical addresses below value should be treat as process area (code execution possible, no overwrite) and all logical addresses above value should be treat as data area (no code execution possible, updates possible, using in various code instructions possible).
5. CPU/hardware should define maximal available number of pages for process

For defining:

1. mechanism for saving memory pages to/from disk in virtual memory.
2. algorithm for assigning free memory. Please note, that DRAM needs refreshing & when we will try to avoid using RAM from different physical modules, we could disable unused one and save some power.

# Hardware access protection

CPU should have instructions "reserving" concrete hardware resources into process (let's call it A) and next process (let's call it B) asking for the same resource should be approved by A.

In other words: process A (for example driver) is reserving concrete port and when we want to replace A with next process (for example updated driver), we have to ask A, if it's OK to do it.

# Minimalizing access to memory

RISC architecture simplifies different operations with constant instruction length and decreasing amount of addressing modes.

RISC-V in the classic approch has got 32-bit long instructions. Opened questions:

1. is it possible to decrease length and save everything in 3 bytes?
2. does it have any sense going a little bit into CISC? For example implementing some instructions copying null-ended strings
3. does it have sence to read everytime for example 5 bytes and interpret only part of them as instruction? (have instructions like different length like in CISC)

Some ideas about making instructions shorter: Let's assume, that we define one byte for instruction type and two bytes for address. Is it possible to save with it 32 or 64 bit long addresses? Normally not, but maybe for example defining few instructions with different addressing mode is enough? For example JMP1 address1 is is jumping forward "forward1" bytes from actual executing address, JMP2 address2 is jumping to logical address specified by address2 and JMP3 regnum is jumping to address saved in register "regnum". We could define three instructions changing register, for example SET1 regnum, value1 is changing 0-15 bits of register, SET2 regnum, value2 is changing bits 16-31, SET2 bits 32-47 and SET4 bits 48-63 and SET5, SET6, SET7 are reading 16-bit, 32-bit and 64-bit long values from concrete memory location, etc. In theory we could get longer code (more instructions), but in practise majority programs are not jumping very far or are not changing very often big values.

# Minimal operating system

In proposed solution we don't need user-kernel architecture. Minimal operating system could have such modules:

1. disk driver supporting user app requests for accessing files (created with interrupt) and request for virtual memory pages (also send with interrupt but from MMU). This should allow for some operations (like updates of system binaries) for example to shell process only.
2. keyboard driver sending pressed key info to user apps, which asked for this (they need to submit such request first). This module should implement clipboard.
3. graphic driver displaying something on the screen (speaking with RAM memory)
4. mouse driver
5. (optional) certificate integrity checking module
6. module showing information about errors (called by CPU in case of errors), which could restart drivers
7. shell reading programs from disk and starting them as separate process. Shell should have ability of stopping already started processes (if necessary) and getting their status (active/non-active)

In ideal situation disk/keyboard/graphic drivers (when loaded again) are asking already loaded modules if can them switch (modules are signed and when signature is OK, they replace them on-fly)

In graphic version every process should have graphic driver API for creating windows(s) and graphic driver should register for Ctrl+Tab and just switch from window to window when pressed.

# Registers

Many publications are providing information, that accessing registers needs quite the same time like accessing L1 cache.

Open question: do we really need registers or can we use L1 for saving them like proposed earlier? Please note, that with second approach we could define for example different amount of general purpose registers for every task.

# Asynchronous hardware design

Normal chips are doing something on the edge of clock. There is also more difficult but effective design, in which
every element is informing next element, when this can start processing (and next element is informating previous one, when
does not need input data from it anymore). Chips created with such approach are consuming power only,
when are really doing some work (additionally many times they're faster)

Please note, that such design was for example used in
[CPU in Polish MERA 400](https://www.youtube.com/watch?v=Y59hgZ5_7sk).
If you don't know Polish language and can't translate
[MERA 400 channel](https://www.youtube.com/@MERA400),
read [Introduction to Asynchronous Circuit Design from Jens Sparsø](https://orbit.dtu.dk/en/publications/introduction-to-asynchronous-circuit-design)
or something similar.

# Possible other things

Although it looks like Sci-Fi in this moment:

* taking electromagnetic wave energy for some tasks, which don't need too much A or V
* preparing 3D structure, which has got air channels for cooling (something like
old channels in the car engine)
Version 20240225

# Hardware switching and other ways to remove typical CPU problems

After creating first primitive software model for PL1 I have found, how
weak it is - for example modeling things in the gate level requires total
other approach than software based.

After getting some experiences with first model I decided to make summary
document postmortem document describing more deeply elements for upcoming
version 2.

# Pipelines in CPU

Modern CPU are designed with splitting instruction execution into pipelines.
Unfamous Pentium IV had (too) many stages and because of it required a lot
of energy and was not able to achieve big processing speed. The most typical
approach to this topic is defining five stages:

1. instuction fetching
2. instruction decoding (includes register reading)
3. execution - ALU operation and address calculating
4. memory data access
5. register write back

The ideal situation is, that every CPU part (responsible for one stage)
is executing something. It's possible, that for example:

1. first instruction is making some calculation and second instruction
needs results
2. program jumps and CPU knowns it in the end (which makes already fetched
or decoded instuctions invalid)

Situations like this are called hazards or pipeline stalls... and CPUs are
trying it to avoid for example by putting some empty instructions between.

Now let's imagine, that first instruction is totally independent from second
and third and forth and fifth.

My proposal is, that CPU should first execute instruction from first
program, than (in next cycle) instruction from second program and so one.
Programs are normally totally independent. Thanks to this approach we can have better concurrency illusion and in theory will eliminate all types of hazards (if we handle more tasks at once/between, even jump prediction is not necessary, because CPU will always know 100% correct address of new instruction).

What is required here?

1. CPU must be built this way, that have access to registers from all processed programs (without delay). It means, that we need enough number of registers or L1 cache memory and access to every process register can be achieved by getting/setting correct cache address).
2. CPU must handle task switching in hadrware way

# Task switching

Majority / all general usage CPUs and OS are making context switch using some software elements. But what if CPU itself has got table indicating process status (is it active, what are register values, etc.) and is switching among them periodically.

In the most primitive solution we need instructions for:

1. starting new task
2. ending own task
3. ending other task (possible only, when our process started this task)

and CPU can just switch to new active task after specified amount of time / executed instructions.

# Memory protection and sharing

Every process should have own logical memory space with addresses, which are changed on-fly to the hardware based. Normally such task is done by MMU. Sometimes it's independent from CPU, sometimes dependent.

In proposed solution:

1. MMU should use paging and translate every memory page address.
2. we should save at least one translated logical-hardware page number for every process and it should our cache (we will not clear it on context switch). Let's imagine, that process is asking for logical address 1 and MMU finds, that this is logical page 0 address assigned to physical page 3. This finding should be cached and next time, twhen process is asking for all addresses from logical page 0 address, MMU should return immediately physical page 3 address.
3. data exchange between two processes should be possibly only with memory sharing - process A is preparing in own logical space some memory area and is calling process B with this area (the most probably using software interrupt mechanism) allowing it access to shared memory area only during call.
4. every process should have mechanism for blocking executing instruction from data area and this could be achieved with one address location register - all logical addresses below value should be treat as process area (code execution possible, no overwrite) and all logical addresses above value should be treat as data area (no code execution possible, updates possible, using in various code instructions possible).
5. CPU/hardware should define maximal available number of pages for process

For defining: mechanism for saving memory pages to/from disk in virtual memory.

# Hardware access protection

CPU should have instructions "reserving" concrete hardware resources into process (let's call it A) and next process (let's call it B) asking for the same resource access should be approved by A.

In other words: process A (for example driver) is reserving for example concrete port and when we want to replace A with next process (for example updated driver), we have to ask A, if it's to do it.

# Minimalizing access to memory

RISC architecture simplifies different operations with constant instruction length and decreasing amount of addressing modes.

RISC-V in the classic approch has got 32-bit long instructions. Opened questions:

1. is it possible to decrease length and save everything in 3 bytes? Let's assume, that we define one byte for instruction type and two bytes for address. Is it possible to save with it 32 or 64 bit long addresses? Normally not, but maybe for example defining few instructions with different addressing mode is enough? For example JMP1 address1 is is jumping forward "forward1" bytes from actual executing address, JMP2 address2 is jumping to logical address specified by address2 and JMP3 regnum is jumping to address saved in register "regnum". We could define three instructions changing register, for example SET1 regnum, value1 is changing 0-15 bits of register, SET2 regnum, value2 is changing bits 16-31, SET2 bits 32-47 and SET4 bits 48-63 and SET5, SET6, SET7 are reading 16-bit, 32-bit and 64-bit long values from . In theory we could get longer code, but in practise majority programs are not jumping very far or are not changing very often big values.
2. does it have any sense going little bit into CISC? For example implementing some instructions copying null-ended strings

# Minimal operating system

In proposed solution we should not have user-kernel architecture. Minimal operating system could have such modules:

1. disk driver supporting user app requests for accessing files (created with interrupt) and request for virtual memory pages (from MMU)
2. keyboard driver sending pressed key to user apps, which asked for this (they need to submit such request first). This module should implement clipboard.
3. graphic driver displaying something on the screen
4. mouse driver
5. (optional) certificate integrity checking module
6. shell reading programs from disk and starting them as separate process. Shell should have ability of stopping already started processes (if necessary) and getting their status (active/non-active).

In ideal situation disk/keyboard/graphic drivers (when loaded again) are asking already loaded modules if can them switch (modules are signed and when signature is OK, they replace them on-fly)

# Asynchronous hardware design

Normal chips are doing something on the edge of clock. There is also more difficult but also more effective design, in which
every element is informing next element, when can stop processing (and next element is informating previous one, when
does not need input data from previous element anymore). Chips created with such approach are consuming power only,
when are really doing some work (additionally many times they're faster)

Please note, that such design was for example used in
[CPU in Polish MERA 400](https://www.youtube.com/watch?v=Y59hgZ5_7sk).
If you don't know Polish language and can't translate
[MERA 400 channel](https://www.youtube.com/@MERA400),
read [Introduction to Asynchronous Circuit Design from Jens Sparsø](https://orbit.dtu.dk/en/publications/introduction-to-asynchronous-circuit-design)
or something similar.


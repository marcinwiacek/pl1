Version 240215

#RISC/CISC?

RISC (as much as possible)

#Pipelined?

Too early to speak about it, but in the future yes (probably 5 stages)

#Asynchrononus?

The same like previous point - too early to speak about it now, but in the future yes, yes and yes (chips created with it are consuming power only, when are really working; additionally many times they're faster)

Please note, that such design was for example used in [CPU in Polish MERA 400](https://www.youtube.com/watch?v=Y59hgZ5_7sk). If you don't know Polish language and can't translate [MERA 400 channel](https://www.youtube.com/@MERA400), read [Introduction to Asynchronous Circuit Design from Jens Sparsø](https://orbit.dtu.dk/en/publications/introduction-to-asynchronous-circuit-design) or something similar.

#UMA (Unified Memory Architecture) ?

The same like previous point - too early, but in the future yes

#Process switching

Hardware based. Every task needs 33 bytes (with 12 2-byte registers). I see two possibilities:

1. Let's assume, that CPU will support 1000 processes,
which gives 33000 bytes (around 32KB) - CPU has got L1 cache with it
2. CPU will have table in RAM and data will be cached in "normal" L1
3. Everything will be saved in L2

Every process has got the same amount of CPU cycles (because it's RISC,
theoretically we get similiar time per process). In more advanced version
we could have priorities or allow using also software switching (as addition).

We get speed we get flexibility and CPU can easy find, if needs to make work
(are all processes waiting for something?). We save CPU cycles for context
switches (we don't run instructions for it).

#Memory

Every process has got logical addresses, which are translated to hardware
addresses by MMU. Current MMU doesn't have deep caching (it's just saving
last found value) and doesn't support situation, when page is not in the RAM
(in that case we should generate INT to disk driver and this should allocate
some place in disk and provide us ID of it).

What is important:

* every process on the start has got allocated one page in RAM
* more allocations are done only when we try to access some logical address
assigned to other page

#Processes protection

Full memory separation (when process A has got logical address 0,
it's available in other place than logical address 0 from process B).

Currently we don't support stopping other processes or getting info about them
(in complete design it must done).

Additionally we need:

1. protection against DoS and allocating the same IRQ by
two or more processes (also switching for example to new disk driver should
be possible on-fly and old driver must somehow allow for this)
2. allocating port access
3. access to subprocesses memory maybe

#Kernel

Not required, in final version also not required (exception: device drivers)

#OS

Device drivers, shell (in the future GUI) and libraries with API

#User-kernel mode

What for?

But seriously: separating memory and controlling access to all devices
should be more than enough + we save time on executing code for switching
mode.

#TODO

A lot of things, for example:

* support for abnormal situations
* virtual memory
* port access and generating / support for hardware IRQ
* full instruction set
* memory sharing during IRQ (we should allocate concrete logical memory addresses for both)
* 32 and 64-bits
* instructions are 5-bit long, RISC-V 32-bit is 4-bit long (need compacting)
* data / code pages

#Why JavaScript for emulator? And not Scheme for example?

Because everybody has got browser... and everybody loves Google Chrome / Safari
(just kidding).
#RISC/CISC?

RISC

#Pipelined?

Too early to speak about it, but in the future yes (probably 5 stages)

#Asynchrononus?

The same like previous point - too early, but in the future yes

#UMA (Unified Memory Architecture) ?

The same like previous point - too early, but in the future yes

#Process switching

Hardware based. Every task needs 33 bytes (with 12 2-byte registers). Let's
assume, that CPU will have L1 cache with this and will support 1000 processes,
which gives 33000 bytes (around 32KB, which should be possible in real chip).

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

#Kernel

Not required and in final version also not required (exception: device drivers)

#OS

Device drivers, shell (in the future GUI) and libraries with API

#TODO

A lot of things, for example:

* support for abnormal situations
* virtual memory
* port access and generating / support for hardware IRQ
* full instruction set
* memory sharing during IRQ (we should allocate concrete logical memory addresses
for both)
* current instructions have 6 bytes - later of course there is compacting required
* 32 and 64-bits

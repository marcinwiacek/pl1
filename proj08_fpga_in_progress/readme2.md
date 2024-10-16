Welcome to the future or at least alternative to the mainstream in some scenarios.

Modern hardware architectures (like X86 or ARM) are very impressive, but have
problems with security, complexity, intellectual property and/or government
control. Risc-V wants to avoid this, but when you look into specs, you will
see, that various elements and/or extensions have potentially doing the same
problems (see words from Linus Torvalds "They’ll have all
the same issues we have on the Arm side and that x86 had before them").

This project contains 1st working generation of the PL SoC (System On Chip).

It allows for creating and running OS and apps:

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

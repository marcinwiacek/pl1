Welcome in the future!

Modern hardware architectures (x86, arm, etc.) are beautiful, but they have
big problems with security, complexity, intellectual property and government
control. Risc-V wanted to avoid this, but when you look into specs, you will
see, that various elements are potentially repeating problems again.

This project contains 1st working generation of the PL architecture. CPU allows
for creating OS:

1. without kernel
2. with full protecting resources (you don't have hypervisor mode and other
stuff, which earlier or later is compromised)
3. without various unnecessary operations (like copying memory during
interrupts)

and this is done without legacy stuff (when you don't have something, it cannot
be broken).

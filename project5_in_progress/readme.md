This CPU is based on previous models - the idea is, that code is so simple as possible
(we don't have parallel stages in this moment) and correctly compiled / simulated & supported by Vivado.

It means for example: 

1. System Verilog
2. no more funny while loops (Vivado 2023.2.2 for example crashes the whole PC during synth_design or cannot find while end)
3. no strings (not supported by Vivado with SV2005?)

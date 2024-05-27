This CPU is based on previous models - code is so simple as possible (we don't have parallel stages in this moment), but correctly compiled / simulated & supported by Vivado.

It means for example:

1. System Verilog
2. no more funny while loops (Vivado 2023.2.2 can crash the whole PC during synth_design or cannot find end in while)
3. no strings (not supported by Vivado with SV2005?)
4. code should be testable on FPGA board (we simulate small RAM on the beginning and use DRAM in the future)

Notes:

1. Vivado required changing **-flatten_hierarchy** from **rebuilt** to **full** in some moment in **Project Settings** \ **Synthesis** (note: last working commit with old setting 26 May 22:34)

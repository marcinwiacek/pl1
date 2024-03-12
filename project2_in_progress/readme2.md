Version 240312

This project is based on experiences from version 1 and has got in target
preparing high level pipelined CPU structure, which could be later easy
converted into Verilog. In next versions I concentrate first on building real
blocks and asynchonous design.

# Version 1

Every instruction is done after previous one, every pipeline stage needs
ca. 10 miliseconds.

Executing with:
Version 240312 (WORK IN PROGRESS)

This project is based on experiences from version 1 and has got in target
preparing high level pipelined CPU structure, which could be later easy
converted into Verilog. In next versions I concentrate first on building real
blocks and asynchonous design.

# Version 1

Every instruction is done after previous one, every pipeline stage needs
ca. 10 miliseconds.

Executing with maxcycles=20: 1069 ms

This should look this way: 12345 12345 12345 12345 12345

# Version 2

Pipeline, every stage needs ca. 10 miliseconds (like in version 1)

Executing with maxcycles=20: 278 ms

This should look this way:

```
12345     <- instruction 1
 12345    <- instruction 2
  12345   <- instruction 3
```

Problem: every next instruction can be dependent on previous one

# Version 3

The same like 2, but with preparation for starting instruction from other processes
in every pipeline run (+ every instruction is done after previous one in thread).
This doesn't give any performance improvement in such simulation,
but should provide great help in situations, when instructions from every processes
are dependent on each other.

Executing with maxcycles=20: 278 ms

This should look this way:

```
12345 12345     <- process 1
 12345 12345    <- process 2
  12345 12345   <- process 3
```

(WORK IN PROGRESS)
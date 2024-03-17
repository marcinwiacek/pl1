Version 240312 (WORK IN PROGRESS)

This project is based on experiences from version 1 and has got in target
preparing high level pipelined CPU structure, which could be later easy
converted into Verilog. In next versions I concentrate first on building real
blocks and asynchonous design.

# Version 1

Every instruction is done after previous one, every pipeline stage needs
ca. 10 miliseconds.

Executing with maxcycles=20: 1069 ms

This should look this way (instructions from the same process):

```
12345 12345 12345 12345 12345
```

# Version 2

Pipeline, every stage needs ca. 10 miliseconds (like in version 1)

Executing with maxcycles=20: 278 ms

This should look this way:

```
12345     <- instruction 1
 12345    <- instruction 2 from the same process
  12345   <- instruction 3 from the same process
```

Problem: every next instruction can be dependent on previous one

# Version 3

Big question: how to avoid dependies?


```
12345      <- instruction
 12345     <- instruction from other process
  12345    <- instruction from other process than instruction 2 and 1
   12345   <- instruction from process 4
    12345  <- instruction from process 5
     12345 <- again instruction from process 1
```

The same like 2, but with preparation for starting instruction from other processes
in every pipeline run (we need to fetch instruction after decoding, etc.).

Executing with maxcycles=20: 278ms

This doesn't give any performance improvement in such simulation,
but should provide great help in real situations, when instructions from every processes
are dependent on each other. Single process is slower than in version 2, but in parallel 
(for user) it can give only profits (note: it's probably enough to run 2 processes in parallel).

Remember, that these theoretical designs have every pipeline stage with the same length
(and we have always every pipeline stage, which is not true)

# Version 4

Decreased amount of threads to 2 + more code for instructions.

```
11112345      <- instruction
 11112345     <- instruction from process 2
  11112345    <- instruction from first process
   11112345   <- instruction from process 2
    11112345  <- instruction from first process
     11112345 <- again instruction from process 2
```

# Future version

Example topics for discovering:

1. in stage 2 after checking, that we don't have for example jump, we can already initiate stage 1
(reading new instruction)
2. in stage saving data to RAM we can just dump it to L1 cache and start saving to RAM (without waiting
for confirmation)
3. how to make L1 cache usage? examples:

   * non-associated cache: save to next L1 memory entries, overwrite from address 1 (it has got the oldest data),
     when try to get, start from last saved (when to start getting from RAM?)
   * cache with hash?

4. RAM should be with 2 or 4 channels and we should get the whole instruction at once in stage 1

(WORK IN PROGRESS)
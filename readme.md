# Why it was started

In the market you can find many beautiful and incredible devices, for example
8cm x 8cm x 4,3cm big mini PC (Minisforum EM780), Mac mini, Macbook Air or powerfull
Ryzen 9 / Thread Ripper systems with 16 or more cores (forget about Intel in this moment)
or even 14" laptops with 73Wh battery and weight 1kg, we also hear about next revolutions
waiting on the corner (Snapdragon X Elite).

There are visible few incredible ISAs (Instruction Architecture Sets) in current
mainstream, unfortunately there are some important issues with them:

1. x86 - I was using many laptops (HP Elitebook, Dell Precision, Dell XPS, Hypebook
L14 11gen / Clevo L140MU, Lenovo, Acers, Asus and others), but:

    * they had annoying design decisions (for example with Dell Precision 5510 after
    longer inactivity period, discharging battery and connecting laptop to the charger
    internal keyboard doesn't work very well before Windows login, which suggests some
    power problem and decreasing speed of the internal keyboard controller)
    * in generall they were not able to achieve more than 10-15h in the normal work
    (Clevo L140MU is exception and [sometimes I was able to achieve even 36h](https://mwiacek.com/www/?q=node/480),
    but it has bigger 73Wh battery and requires disabling Wi-Fi, Bluetooth, low brightness, etc.).

    I'm not very suprised with this:

    * x86 was designed in totally different world and it didn't had in mind in first
    place good power energy handling (additionall current mainstream Windows is totally
    different than original Windows NT and even Windows XP)
    * next generations of hardware don't fully allow for controlling behavior and for
    example consume a lot of power during standby (DRAM refresh, NVME standby, etc.)
    * removing obsolete elements is done very slowly (X86S is not mentioned even in Zen 5)
    * big companies built inside chips for monitoring and taking telemetry, which of
    course need some energy (Intel ME or similar elements in AMD)
    * many devices are not optimized, because companies don't have interest in futher
    optimalization (current solutions are "good enough") - you have only initial UEFI/BIOS
    without enabled important options, etc.

2. ARM - it's patented like x86 and currently we see powerfull chips from one company only (Apple),
maybe Snapdragon X will change something here, but using this will still mean vendor lock. How
big companies are working, it's visible for years. I will give just few examples:

    * MacOS, although very nice, simply cannot scale screen elements like Windows (you can only
    change resolution, which in many cases gives strange results)
    * You cannot buy Macbooks with matte screen (and foil is just workaround)
    * Macbook Air M1 has got PWM (hardware screen blinking), in the same time Macbook Air M2 is faster,
    but better speed in many scenarios is achieved with bigger power limits
    * you don't have Macbooks working 30h or more on battery, because it's not required in mainstream
    * planned obsolescence (please look on Rossmann channel in the Youtube)

3. Risc-V - possible future, but please hand in mind, that it will need many years, before chips
will be so good like ARM (second possible scenario is, that Risc-V will be concentrated more on
Internet Things devices) + different chips can be not compatible with each other (it's because
standard allows for implementing only some sets of instructions)

Additionally (regardless of hardware and ISA) often used operating systems are running many
processes in background, which is not nice in terms of effectiviness - when I look in task
managers and see 1-10% CPU usage even, when nothing is done, I know, that something is very wrong.

# Goals

This project have in mind playing a little bit with different solutions abandomed in the most
popular market solutions. I would like to prepare free design of the CPU / hardware, which possibly
could be much more effective than some popular generic solutions (they're very generic and because of it 
slower in various aspects).

During some research I have found project [Antikernel](https://github.com/azonenberg/antikernel).
My some targets are a little similar (for more detailed info please look into docs, 
which are/will be written in next stages):

1. hardware (CPU) should make task switching as effective as possible - I don't want to
have saving / restoring registers every time, additionally I don't want to have scheduler in software
(main argument for software based solution is flexibility, ability of measuring CPU usage, etc.)
2. hardware (CPU) should not give too many ways for communicating processes - memory sharing is
enough and it will avoid unnecesary copying data and other things (process A cannot access process
B, maybe only, when B was created by A)
3. CPU should hardly cooperate with DRAM, USB, etc. and fully disable it, when possible
4. hardware must protect again DoS

# Targets and timeline

This project is separated into stages:

1. Stage 1 - simulating things in software (HTML page)
2. Stage 2 - simulating things in software (VHDL, maybe already with pipelines)
3. Stage 3 - creating real hardware

I don't have plans for replacing the most popular ISAs (there are milions of people behind them
and in the end the most important is not ISA, but software on it). It is possible, that stage 3
will happen in very far future... but if project goals will be achieved,
maybe it will be possible to create much more secure and effective embedded devices. Who knows?

# This is wasting time

Maybe

# Formatting source (info for me in development)
1. ```npm -g install js-beautify```
2. ```npm -g install html-beautify```
3. ```js-beautify -e "\n" ng1.js > x```
4. ```html-beautify -e "\n" project.html > x```
5. ```sudo apt install retext```
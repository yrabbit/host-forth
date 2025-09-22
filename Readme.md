Host-Forth is a practical implementation of the "3-instruction Forth" concept pioneered by Frank Sergeant, designed for embedded systems development. 

The system implements a distributed architecture where computationally intensive tasks like text editing, compilation, and dictionary management run on a powerful host machine, while the target executes only three fundamental primitive operations. This approach dramatically reduces the memory footprint required on embedded hardware while maintaining full Forth interactivity.


# The Three Instruction Philosophy
Frank Sergeant's seminal 1991 paper asked: "How many instructions does it take to make a Forth for target development work?" The astonishing answer: just three carefully chosen primitives can bootstrap a complete interactive programming environment 29.

The three fundamental instructions implemented are:

Instruction	Code	Function
XC@ (fetch)	01	Read byte from target memory address
XC! (store)	02	Write byte to target memory address
XCALL (execute)	03	Call subroutine at target address
This minimal set enables memory inspection, modification, and code execution - the essential operations needed for interactive development. (https://pygmy.utoh.org/3ins4th.html)

In our case, the target architecture is a tiny RISCV implemented for Gowin chips (https://codeberg.org/Mecrisp/femtorv-noram)

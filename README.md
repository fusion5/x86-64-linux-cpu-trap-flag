# x86-64-linux-cpu-trap-flag
A demo implementation of CPU trap functionality under Linux useful for debugging

Tested under: 64 bit Linux

The x86 CPU trap flag generates an interrupt request after each opcode is executed;
this is used, for example, by IDE debuggers to execute programs step by step and to
highlight the current line of source code being executed.

The repository contains two programs that demonstrate the use of the trap flag in Linux, 
one is written in assembly code and the other mostly in C code.

# Usage

```
> mkdir test-trap-flag
> cd test-trap-flag
> git clone https://github.com/fusion5/x86-64-linux-cpu-trap-flag.git .
> # Generate the binaries and run them. Ouptut their binary output in a readable fashion
> # using xxd
> make demo_c.out demo_asm.out
> cat demo_c.out
> cat demo_asm.out
```

An output as below should be shown:

```
00000000: 9090 9090  ....
00000004: 9090 90e8  ....
00000008: 9090 e820  ... 
0000000c: 90e8 2000  .. .
00000010: e820 0000  . ..
00000014: 9c66 8124  .f.$
00000018: 6681 2424  f.$$
0000001c: 9dc3 4889  ..H.
00000020: c348 89f0  .H..
```

Each line shows the next 4 bytes of opcode to be executed each CPU 
instruction is complete. This is achieved by means of a handler function
that gets called after each instruction; the handler receives the 
current execution point of the program as a parameter. (I think we could also
inspect the _IP_ register)

# Background

    Knuth has a chapter on "Trace routines" [1] in which a routine 
takes a program point in the assembly of a program and runs it step by step (in
the MIX language, opcodes are of fixed width so it is easy to advance the 
instruction pointer). The trace routine must deal with jump opcodes as a special 
case, because it mustn't let any jump exit the routine: instead of executing
the jumps, it updates the trace program location in memory with the address of 
the jump.

    Since this is useful in the development of the JIT Forth-like language I'm 
working on, I set out to implement such a routine on the X86, and I discovered the 
difficulty introduced by having variable-length opcodes: it is impossible to know 
how many bytes should be copied in an area for execution and by how many bytes 
should the program position be advanced after the opcode has been executed.

    Fortunately, tracing is still possible (and easier to get right!) on the x86 
CPU thanks to the _TRAP_ CPU flag. CPU flags are certain bits that one can get/set 
to find out about the state of the CPU and to change its behaviour.

# Functionality

    Whenever the TRAP flag is set, the CPU issues an interrupt signal, and 
the code that is installed to handle interrupts catches that and from there 
the programmer can run any piece of code.

    In X86 assembly we set the trap flag in this way:

```
    pushf
    or [rsp], word 0x0100 ; ensure that the CPU trap flag is 1
    popf
    ret
```

    This places all CPU flags on the stack (rsp), then it modifies the word on 
the stack by setting the appropriate bit, and then it writes back the flags from
the stack into the CPU.

    After this happens, the CPU generates an interrupt after each instruction.

    Under 64 bit linux, the handler can be installed in C using the library 
functions for signals to catch SIGTRAP (see man sigaction for more information):

```
#include <signal.h>
static struct sigaction g_new_action = {0};  

// Function declaration of the handler
void my\_sa\_handler (int signo, siginfo\_t \*info, void \*context);

extern void attach\_trap\_handler () {

    g_new_action.sa_sigaction = &my_sa_handler;
    g_new_action.sa_flags = SA_SIGINFO;

    sigaction (SIGTRAP, &g_new_action, NULL);
}
```

This works in practice as follows:

```
    call attach_trap_handler ; Calling the C function from assembly
    call start_trace ; Sets the trap flag (bit 0x0100)
    nop ; Some dummy code that we should see executing. NOP = 0x90
    nop
    nop
    nop
    call stop_trace ; Unsets the trap flag (bit 0x0100)
```

And indeed if we look back at the trace shown above, 

```
00000000: 9090 9090  ....
00000004: 9090 90e8  ....
00000008: 9090 e820  ... 
0000000c: 90e8 2000  .. .
00000010: e820 0000  . ..
00000014: 9c66 8124  .f.$
00000018: 6681 2424  f.$$
0000001c: 9dc3 4889  ..H.
00000020: c348 89f0  .H..
```
we can see on the first line the four 0x90 (NOP) instructions to be executed.
On the next line, one of the four has been executed and there are now only
three 0x90 NOPs to be executed followed by an E8 instruction, which is the call
to `stop_trace`. Basically each line is a looking glass to the next four instructions
to be executed. Using a disassembly function we could basically convert these to 
readable assembly code.


# References

[1]: Knuth, _The Art Of Computer Programming, Volume 1_, 1.4.3.2 Trace Routines

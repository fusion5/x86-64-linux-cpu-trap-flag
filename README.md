# Introduction: x86-64-linux-cpu-trap-flag

The x86 CPU can be configured to generate an interrupt request after each opcode that it
executes; this is used, for example, by IDE debuggers to execute programs step by step, 
highlighting the relevant line of source code.

The repository consists of two programs that demonstrate this behaviour in Linux:
one is written in assembly language (demo\_asm) and the other mostly in C code (demo\_c).

For this README file some familiarity with C code, assembly language and Linux is assumed.
This guide provides an overview of the repository and does not delve into the
details of the Linux system calls and the associated data structures, which are better 
documented elsewhere (see the References section).


## Usage

```
> mkdir test-trap-flag
> cd test-trap-flag
> git clone https://github.com/fusion5/x86-64-linux-cpu-trap-flag.git .
> # Generate the binaries and run them. Ouptut their binary output in a readable fashion
> # using xxd
> make demo_c.out demo_asm.out
```

The .out files should contain some text such as:

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

Each line is output by the interrupt handler called after each CPU instruction. 
The handler receives in a parameter the address of the opcode that 
follows the one just executed, and it outputs 4 bytes from that address on.


## Background

Knuth has a chapter on "Trace routines" [1] in which a routine 
takes a program point of executable code in memory and runs it step by step (in
the MIX language, opcodes are of fixed width so it is easy to advance the 
instruction pointer). The trace routine must deal with jump opcodes as a special 
case, because it mustn't let any jump exit the routine: instead of executing
the jumps, it updates the trace program location in memory with the address of 
the jump.

Since this would be useful in the development of the JIT Forth-like language I'm 
working on, I set out to implement such a routine on the x86, and I discovered the 
difficulty introduced by having variable-length opcodes: it is difficult to calculate
how many bytes should be copied in an area for execution.

Fortunately, tracing is still possible (and easier to get right!) on the x86 
CPU thanks to the _TRAP_ CPU flag [2]. CPU flags are certain bits that one can get/set 
to find out about the state of the CPU and to change its behaviour.


## Functionality

Whenever the TRAP flag is set, the CPU issues the interrupt signal as 
previously mentioned. In x86 assembly, the TRAP flag is set in this way:

```x86asm
pushf                 ; place all CPU flags on the CPU
or [rsp], word 0x0100 ; ensure that the CPU TRAP flag is 1
popf                  ; write back the altered flags to the CPU
ret
```

Under 64 bit Linux, the handler can be installed in C using the library 
functions for signals (`signal.h`) to catch SIGTRAP.
The operating system manages signal handlers for multiple processes, therefore
Linux system interaction is needed to handle TRAP signals within
the current process. This is achieved by means of the `sigaction` system call [3]:

```c
#include <signal.h>
static struct sigaction g_new_action = {0};  

// Function declaration of the handler
void my_sa_handler (int signo, siginfo_t *info, void *context);

extern void attach_trap_handler () 
{
    g_new_action.sa_sigaction = &my_sa_handler;
    g_new_action.sa_flags = SA_SIGINFO;
    sigaction (SIGTRAP, &g_new_action, NULL);
}
```

The procedure `attach_trap_handler` is called by the `main` function defined in 
assembly language (demo\_c\_main.asm) as follows:

```x86asm
main: 
    call attach_trap_handler ; Call the C function from assembly
    call start_trace         ; Set the TRAP CPU flag (bit 0x0100)
    nop                      ; Some example code to see executed (nop = 0x90)
    nop
    nop
    nop
    call stop_trace          ; Unset the TRAP flag (bit 0x0100)
```

And then by comparison against trace shown above:

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

it is clear that on the first line are the four 0x90 (nop) instructions to be 
executed. On the next line, one of the four was consumed and there are now only
three nops to be executed followed by an 0xE8 instruction (which is the call
to `stop_trace`), and so on. 


## Debugging the signal handler

The _strace_ [4] tool has been particularly helpful to debug the code. 

Since the demo is based on system calls, and since they are called from 
assembly language, in which it's easy to make mistakes, I had to verify the 
system calls that are performed and their parameters. To do so, one can run:

    > make demo_asm.strace

This produces the .strace file below which shows the system calls performed
by `demo_asm`:

```
execve("./demo_asm", ["./demo_asm"], 0x7ffffb738b50 /* 62 vars */) = 0
rt_sigaction(SIGTRAP, {sa_handler=0x401048, sa_mask=[], sa_flags=SA_RESTORER|SA_SIGINFO, sa_restorer=0x4010a8}, NULL, 8) = 0
--- SIGTRAP {si_signo=SIGTRAP, si_code=TRAP_TRACE, si_pid=4198422, si_uid=0} ---
write(1, "\220\220\220\220", 4)         = 4
rt_sigreturn({mask=[]})                 = 0

... (a sequence of SIGTRAP signals)

--- SIGTRAP {si_signo=SIGTRAP, si_code=TRAP_TRACE, si_pid=4198471, si_uid=0} ---
write(1, "\303H\211\360", 4)            = 4
rt_sigreturn({mask=[]})                 = 0
exit(0)                                 = ?
+++ exited with 0 +++
```

The .strace file shows first the `rt_sigaction` call that installs the handler; 
then there follows a sequence of SIGTRAP handler calls (note: `rt_sigreturn` 
returns from the handler).


## Conclusion

The code shows how to enable and how to handle TRAP FLAG interrupts under Linux 
in assembly language. C code, which is easier to write was first created; then it
was ported to assembly language.

## References

[1] Donald E. Knuth, _The Art Of Computer Programming, Volume 1_, 1.4.3.2 Trace Routines
[2] Intel(R) 64 and IA-32 Architectures Software Developer's Manual, Volume 1: Basic Architecture, Chapter 3.4.3.3 _System Flags and IOPL Field_
[3] https://man7.org/linux/man-pages/man2/rt_sigaction.2.html 
[4] https://man7.org/linux/man-pages/man1/strace.1.html

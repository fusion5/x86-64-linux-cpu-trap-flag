; Here is the main (entry point) of the C program. Assembly language was 
; chosen here in order to keep a lightweight binary file; its execution 
; can easily be traced using gdb and strace, and the binary file can be 
; disassembled if needed.

section .text

global main

extern attach_trap_handler

main: 
    call attach_trap_handler

    call start_trace
    nop ; Some dummy code that we should see executing
    nop 
    nop
    nop
    call stop_trace

    ret

start_trace:
    pushf
    or [rsp], word 0x0100 ; set CPU trap flag
    popf
    ret
   
stop_trace:
    pushf
    and [rsp], word 0XFEFF ; unset the CPU trap flag
    popf
    ret

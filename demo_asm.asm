; 
; This file generates an entire executable, without external C code.
;
section .text

global main
extern _start

; Strings that help to show that functions are called
msg_hcall db "hcall",0x0A
msg_hatta db "hatta",0x0A

_start:
    call attach_trap_handler
    call start_trace
    nop ; Some dummy code that we should see executing
    nop
    nop
    nop
    call stop_trace

    mov rax, 60 ; sys_exit
    mov rdi, 0  ; exit code
    syscall
    ret

start_trace:
    pushf
    or [rsp], word 0x0100 ; set CPU trap flag
    popf
    ret

stop_trace:
    pushf
    and [rsp], word 0xFEFF ; unset the CPU trap flag
    popf
    ret

handler:
    ; The parameters received from the operating system are:
    ; rdi = int signo
    ; rsi = siginfo_t *info
    ; rdx = void *context

    ; this shows that the handler is called:
    ; mov rsi, msg_hcall ; buffer
    ; mov rax, 1         ; sys_write
    ; mov rdi, 1         ; stdout
    ; mov rdx, 6         ; size 
    ; syscall

    mov rax, rsi      ; rax <- info
    mov rax, [rax+16] ; rax <- rax.si_addr (the si_addr offset is 16, obtained from gcc's compiler asm output )

    mov rsi, rax ; buffer
    mov rax, 1   ; sys_write
    mov rdi, 1   ; stdout
    mov rdx, 4   ; size
    syscall

    ret

attach_trap_handler:
    ; this shows that the handler is attached:
    ; mov rax, 1         ; sys_write
    ; mov rdi, 1         ; stdout
    ; mov rsi, msg_hatta ; buffer
    ; mov rdx, 6         ; size 
    ; syscall
   
    ; sigaction((SIGTRAP=) 5, new_action, old_action)
    mov rax, 13 ; sys_rt_sigaction
    mov rdi, 5  ; SIGTRAP
    mov rsi, new_action
    mov rdx, 0 ; if old_action is non-null, the old action is placed here...
    mov r10, 8 ; I don't know why but it's needed (sigsetsize)
    syscall
    ret 

restorer:
    nop
    mov rax, 0x0F ; sigreturn
    syscall       ; does not return

section .data

; A 'sigaction' C struct value; the field order is different from that
; from the struct definition:
new_action:
    n_sa_handler  dq handler            ; signal callback
    n_sa_flags    dq 0x004000000 | 0x04 ; int SA_RESTORER | SA_SIGINFO
    n_sa_restorer dq restorer           ; restorer callback 
    n_sa_mask     dq 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0
                                        ; an array of _SIGSET_NWORDS=16 ints (__sigset_t)



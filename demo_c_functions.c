//
// This is a static C library exporting a single function. 
// Notice that no main entry point is defined in this file, since the main 
// function is in demo_c_main.asm.
//
// C code is easier for me to write and read than assembly. For example, 
// in dealing with the siginfo_t structure defined in Linux, it is much 
// easier to access the structure's fields.
//
// Therefore, C was used to iterate prototypes and to run tests before 
// settling on a version of code that can be translated in assembly.
//

#include <signal.h>
#include <stddef.h>
#include <unistd.h>

static struct sigaction g_new_action = {0};  

// Function declaration
void my_sa_handler (int signo, siginfo_t *info, void *context);

extern void attach_trap_handler () {

    g_new_action.sa_sigaction = &my_sa_handler;
    g_new_action.sa_flags = SA_SIGINFO;

    sigaction (SIGTRAP, &g_new_action, NULL);
}

// my sig_action handler definition
void my_sa_handler (int signo, siginfo_t *info, void *context)
{
    write (1, info->si_addr, 4);

    /*
    // printf isn't safe to use in general (it's not re-entrant!), but
    // it can be useful to convince ourselves that the output is good
    printf( "  program location: 0x%08X \n"
            "  4 opcode bytes at location: %02X %02X %02X %02X  \n", 
            info->si_addr, 
            ((unsigned char*)info->si_addr)[0], 
            ((unsigned char*)info->si_addr)[1],
            ((unsigned char*)info->si_addr)[2],
            ((unsigned char*)info->si_addr)[3]
            );
    */
}


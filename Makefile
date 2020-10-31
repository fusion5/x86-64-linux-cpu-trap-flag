
# C code to assembly
%.s: %.c
	gcc -S -masm=intel -O0 -o $@ $<

# Assembly to object file with listing generation
%.o: %.asm
	nasm -O0 -f elf64 $< -l $<.listing -o $@

OFILES = demo_c_main.o demo_c_functions.o

# The C demo has two object files: one built from assembly
# and another built from C. 
demo_c: $(OFILES)
	gcc -g -o $@ $(OFILES)

# The assembly demo only derives from demo_asm.asm
demo_asm: demo_asm.o
	ld $< -o $@

# Generate a GDB trace file
# Add "info registers \n\" to show the value of registers at each step
%.gdbtrace: %
	printf "set confirm off \n\
		set logging file "$@" \n\
		set logging overwrite on \n\
		set logging redirect on \n\
		set logging on \n\
		set pagination off \n\
		set disassembly-flavor intel \n\
		set disassemble-next-line on \n\
		starti \n\
		info registers eflags \n\
		while 1 \n\
            stepi \n\
			info registers eflags \n\
		end" | gdb $<

# Generate a system calls trace file
%.strace: %
	strace ./$< 2> $@

%.out: %
	./$< | xxd -c 4 > $@

clean:
	-rm demo_c demo_asm
	-rm *.strace 
	-rm *.out 
	-rm *.gdbtrace 
	-rm *.o 
	-rm *.s 
	-rm *.listing

all:
	

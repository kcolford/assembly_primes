CC = ld
all: test
.asm.s:
	sed -e 's=;=#=g' < $< > $@
clean:
	$(RM) test *.o *.s 
.PHONY: all clean
.SUFFIXES: .asm

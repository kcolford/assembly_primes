CC = ld
all: test
.asm.s:
	sed -e 's=;=#=g' $< > $@
clean:
	$(RM) test
.PHONY: all clean
.SUFFIXES: .asm

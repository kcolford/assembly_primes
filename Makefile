all: test ctest.s
test: test.o
	ld $(LDFLAGS) -o $@ $<
.asm.s:
	sed -e 's=;=#=g' < $< > $@
clean:
	$(RM) test *.o *.s 
.PHONY: all clean
.SUFFIXES: .asm

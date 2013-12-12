;;;; The prime number generator that only works on the linux x86_64

;;;; Copyright (C) 2013 Kieran Colford
;;;;
;;;; This program is free software: you can redistribute it and/or
;;;; modify it under the terms of the GNU General Public License as
;;;; published by the Free Software Foundation, either version 3 of the
;;;; License, or (at your option) any later version.
;;;;
;;;; This program is distributed in the hope that it will be useful,
;;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;;;; General Public License for more details.
;;;;
;;;; You should have received a copy of the GNU General Public License
;;;; along with this program.  If not, see
;;;; <http://www.gnu.org/licenses/>.
;;;;
;;;; The copyright holder can be contacted at <colfordk@gmail.com>.


;;; This is the assembly code for a prime number generator.  It uses a
;;; standard sieve of eratosthenes to do so.
;;;
;;; It runs on the x86_64 microprocessor running linux.  Do not link
;;; using a C compiler, only use the bare standard `ld' command.
;;;
;;; The GNU assembler defines the comment character for the x86_64 as
;;; being a `#' symbol.  This is very problematic and unconventional
;;; and causes problems for my editor.  So you should preprocess this
;;; file to turn `;' into `#'.  In my makefile I use a rule that runs
;;; "sed -e 's=;=#=g'" on it before telling `as' to assemble the
;;; program.

   ;; The size of our table must be known at compile time.
   .set  table_size, 5000
   ;; The maximum value that we can compute given the size of our
   ;; table.
   .set  max, table_size * table_size
   ;; Since our table behaves like a stack, we need to store a
   ;; reference to the top of it.  I've set aside register %r9 for
   ;; that purpose, and it hasn't been clobbered yet by the syscall so
   ;; I assume that it is safe.
   .set  table_top, %r9
   
   ;; Begin the bss section
   .bss                       
;;; This is our table of prime numbers that we've already discovered.
;;; I considered using the runtime stack to provide an infinitely
;;; large table, but that proved too slow to repeatedly push items on
;;; to the stack.
table: 
   .space 8 * table_size
;;; This marks the limit of the table, so if `table_top' ever reaches
;;; this point, we know that there's nothing more that we can do.
limit: 
   .space 8
   
   ;; Time for the actual code.
   .text 
   .global _start
_start:
   ;; It is probably useless to push the base pointer on to the stack
   ;; but I'm doing it anyway for my own sanity.
   push  %rbp 
   mov   %rsp, %rbp            
   lea   (table), table_top
   mov   $2, %rsi
   call  pushnum	        ; Push 2 into our table.
   mov   $3, %rsi
   call  pushnum	        ; Push 3 into our table.
   add   $2, %rsi
.L1:
   lea   (table), %rcx          ;Start the count register %rcx at the
                                ;begining of the table.
.L2:	      
   ;; This this step means that we skip the first number in the table,
   ;; the number 2, but because we only test odd numbers, we're safe.
   add   $8, %rcx	        ;Move to the next prime in the table.
   mov   $0, %rdx
   mov   %rsi, %rax
   divq  (%rcx)
   ;; From what I can decipher, this test is very friendly to branch
   ;; prediction because after the first few prime numbers in the
   ;; table have been tested, it is very unlikely that a larger value
   ;; in the table will sift out the number at hand.  So the
   ;; pipelining benifits we gain when trying to test large numbers
   ;; balance out the number of tests we have to do.
   test  %rdx, %rdx             
   jz    .L3
   ;; This test merely tells us when we can stop testing numbers.  A
   ;; possible alternative to testing the quotient of the `div'
   ;; instruction is to use the builtin `fsqrt' instruction to locate
   ;; the square root and then use loop unwinding.  This was
   ;; unfavourable as it would have created excessive overhead for
   ;; smaller primes and composite numbers (of which there are way
   ;; more of).  Since the quotient is computed at no additional cost,
   ;; this ends up being the best possibility.
   cmp   %rax, (%rcx)
   jle   .L2
   call  pushnum	        ;We found a prime number!
.L3:
   add   $2, %rsi
   cmp   $max, %rsi	        ;Check if we're done yet.
   jl    .L1
   ;; It's weird that the only way to safely exit from a program is to
   ;; perform a syscall rather than a `ret' instruction.  This took a
   ;; lot of searching through system header files and disassembler
   ;; output of test programs written in C.
   mov   $0, %rdi
   mov   $0x3c, %rax
   syscall 
   
;;; We push a number onto the end of the table followed by printing
;;; out a newline character and keeping the %rsi register safe from
;;; being clobbered by the syscall.
;;;
;;; TODO: Implement more buffering of output, into a static array in
;;;       the bss section or something so that we can make fewer calls
;;;       to the kernel.
pushnum:
   lea   (limit), %r8
   cmp   %r8, table_top         ;We don't want to over fill the table.
   jge   .L4
   mov   %rsi, (table_top)      ;Push %rsi.
   add   $8, table_top
.L4:	      
   push  %rsi                   ;Keep %rsi safe from the evil syscall.
   mov   %rsi, %rax
   mov   $0xa, %rdx
   dec   %rsp
   mov   %dl, (%rsp)            ;Push a newline onto the stack.
   mov   $1, %rcx               ;Initialize the count register.
.L5:
   mov   $0, %rdx
   ;; The div instruction only accepts a register as an argument, so
   ;; we put it into %r10 for the time being.
   mov   $10, %r10              
   divq  %r10
   add   $0x30, %rdx            ;Translate remainder to ascii code.
   dec   %rsp                  
   mov   %dl, (%rsp)            ;Push digit onto stack.
   inc   %rcx
   test  %rax, %rax
   jnz   .L5                    ;If we're not done, do it again.
   ;; Now we have to set up all the registers for the syscall.  This
   ;; has so much overhead but I have no idea how else it can be done.
   mov   %rcx, %rdx
   lea   (%rsp), %rsi
   mov   $1, %rdi
   mov   $1, %rax
   push  %rcx                   ;Protect %rcx from clobbering.
   syscall                      ;Do the syscall.
   pop   %rcx                   
   add   %rcx, %rsp             ;Restore the stack.
   pop   %rsi
   ret   

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
;;; using a C compiler, only use the standard `ld' command.
;;;
;;; The GNU assembler defines the comment character for the x86_64 as
;;; being a `#' symbol.  This is very problematic and unconventional
;;; and causes problems for my editor.  So you should preprocess this
;;; file to turn `;' into `#'.  In my makefile I use a rule that runs
;;; "sed -e 's=;=#=g'" on it before telling `as' to assemble the
;;; program.

   ;; Our the size of our table must be known at compile time.
   .set  table_size, 10000
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
   add   $8, %rcx	        ;Move to the next prime in the table.
   mov   $0, %rdx
   mov   %rsi, %rax
   divq  (%rcx)
   test  %rdx, %rdx 
   jz    .L3
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
   mov   $60, %rax
   syscall 
   
;;; We push a number onto the end of the table followed by printing
;;; out a newline character and keeping the %rsi register safe from
;;; being clobbered by the syscall.
;;;
;;; Admittedly, this is probably the least efficient possible method
;;; for doing IO.  I should really have implemented buffered IO but
;;; using recursion in assembly was just too inviting.
pushnum:
   ;; We don't want to over fill the table.
   lea   (limit), %r8
   cmp   %r8, table_top
   jge   .L4
   mov   %rsi, (table_top)      ;Push %rsi.
   add   $8,	%r9
.L4:	      
   push  %rsi                   ;Keep %rsi safe from the evil syscall.
   mov   %rsi, %rax
   call  spitint
   mov   $10, %rax
   call  print
   pop   %rsi
   ret   
   
;;; We print out the number in %rax going digit by digit, recursing to
;;; display the most significant digit then the least significant.
spitint:      
   test  %rax, %rax
   jz    .L5
   mov   $0, %rdx
   ;; The `div' instruction can only accept a register as an argument,
   ;; so we fill %r10 with the value 10 and pass it.
   mov   $10, %r10
   div   %r10
   push  %rdx                   ;Store the digit on the stack for
                                ;after the recursive call.
   call  spitint
   pop   %rax
   add   $48, %rax
   call  print
.L5:	      
   ret   
   
;;; This is a simple routine to print the character in %rax to file
;;; descriptor 1.  The syscall seems to arbitrarily clobber registers
;;; so if I used this in another program I would push all the
;;; registers on to the stack beforehand and then pop them off later.
;;; Luckily though, this program is a special case which makes things
;;; easier.
print:	      
   push  %rax
   mov   $1, %rdx
   lea   (%rsp), %rsi
   mov   $1, %rdi
   mov   $1, %rax               ;The syscall number for write is 1.
                                ;Some times it is different though,
                                ;which just adds even more portability
                                ;problems for my assembly code.
   syscall 
   pop   %rax
   ret   

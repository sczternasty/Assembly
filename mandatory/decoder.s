.text

.include "helloWorld.s"

.global main

# ************************************************************
# Subroutine: decode                                         *
# Description: decodes message as defined in Assignment 3    *
#   - 2 byte unknown                                         *
#   - 4 byte index                                           *
#   - 1 byte amount                                          *
#   - 1 byte character                                       *
# Parameters:                                                *
#   first: the address of the message to read                *
#   return: no return value                                  *
# ************************************************************
decode:
	# prologue
	pushq	%rbp 			# push the base pointer (and align the stack)
	movq	%rsp, %rbp		# copy stack pointer value to base pointer

	pushq	%rbx # save callee-saved register
	pushq	%r12 # save callee-saved register

	movq	%rdi, %r12 # base address of message
	movq	$0, %rbx # current index = 0

decode_loop:

	shlq	$3, %rbx # shift left by 3 = multiply by 8
	addq	%r12, %rbx # base + (index * 8) = current block address

	movq	(%rbx), %rax # load the current block

	movq	%rax, %rdx # copy the block
	shrq	$16, %rdx # shift right 16 bits to get bytes 2-7
	movl	%edx, %edx # clear upper 32 bits to get bytes 2-5
	movq	%rdx, %rbx # move index to rbx for next iteration

	movq	%rax, %rcx # copy the block
	shrq	$8, %rcx # shift right 8 bits
	andq	$0xFF, %rcx # mask to 1 byte

	movq	%rax, %rsi # copy the block
	andq	$0xFF, %rsi # mask to 1 byte

	testq	%rcx, %rcx # check if amount is 0
	jz	termination # if amount is 0, skip printing

print_loop:
	movq	%rsi, %rdi # first parameter for putchar
	pushq 	%rcx 
	call	putchar # call print character
	popq	%rcx
	decq	%rcx # decrement counter
	jnz	print_loop # if not zero, continue printing

termination:
	testq	%rbx, %rbx # check if next index is 0
	jz	decode_exit	# if next index is 0, end decoding
	jmp	decode_loop # otherwise, continue decoding

decode_exit:
	popq	%r12 # restore callee-saved register
	popq	%rbx # restore callee-saved register
	
	# epilogue
	movq	%rbp, %rsp		# clear local variables from stack
	popq	%rbp			# restore base pointer location 
	ret

main:
	pushq	%rbp 			# push the base pointer (and align the stack)
	movq	%rsp, %rbp		# copy stack pointer value to base pointer

	movq	$MESSAGE, %rdi	# first parameter: address of the message
	call	decode			# call decode

	popq	%rbp			# restore base pointer location 
	movq	$0, %rdi		# load program exit code
	call	exit			# exit the program
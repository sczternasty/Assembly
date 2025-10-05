.data
names:      .asciz "Szymon Czternasty, Oliwier Augustynowicz"
netid:      .asciz "sczternasty, oaugustynowicz"
assignment: .asciz "ASSIGNMENT 1: Powers"
format:     .asciz "Names: %s\nNetID: %s\nAssignment: %s\n"
prompt:     .asciz "Enter non-negative base and exponent: "
input:      .asciz "%ld %ld"
output:     .asciz "%ld to the power of %ld is %ld\n"

.text
.global main

main:
    # prologue
    pushq %rbp # save base pointer by pushushing it onto the stack
    movq %rsp, %rbp # set base pointer to current stack pointer
    

    # Print description
    movq $0, %rax   # no floating point arguments
    movq $format, %rdi # first printf argument
    movq $names, %rsi # second printf argument
    movq $netid, %rdx # third printf argument
    movq $assignment, %rcx  # fourth printf argument
    call printf  # call printf

    # Prompt user
    movq $0, %rax  # no floating point arguments
    movq $prompt, %rdi # first printf argument
    call printf # call printf

    # Read input
    subq $16, %rsp # allocate space on stack for 2 long integers
    movq $input, %rdi # first scanf argument
    movq $0, %rax # no floating point arguments
    leaq -8(%rbp), %rsi # load address of base
    leaq -16(%rbp), %rdx  # load address of exponent
    call scanf # call scanf

    # Load input
    movq -8(%rbp), %rdi # copy base to rdi for pow function
    movq -16(%rbp), %rsi # copy exponent to rsi for pow function

    call pow # call pow function

    # Print output
    movq %rax, %rcx # copy result to rcx for printf
    movq $output, %rdi # first printf argument
    movq -8(%rbp), %rsi # copy base to rsi for printf
    movq -16(%rbp), %rdx # copy exponent to rdx for printf
    movq $0, %rax # no floating point arguments
    call printf # call printf

    # epilogue
    movq %rbp, %rsp # restore stack pointer from base pointer
    popq %rbp # restore base pointer 
    movq $0, %rdi # return 0 status
    call exit # call exit


# Power function
pow:
    # prologue
    pushq %rbp # save base pointer by pushing it onto the stack
    movq %rsp, %rbp # set base pointer to current stack pointer
    movq $1, %rax # initialize result to 1
    
    cmpq $0, %rsi # Handle case where exponent is 0
    je pow_exit # if exponent is 0, skip to exit    

pow_loop:

    imulq %rdi, %rax # multiply result by base
    decq %rsi # decrement exponent
    jnz pow_loop # if exponent != 0, repeat loop

pow_exit:

    # epilogue
    movq %rbp, %rsp # restore stack pointer from base pointer
    popq %rbp # restore base pointer
    ret # return to caller
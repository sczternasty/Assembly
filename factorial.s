.data
names:      .asciz "Szymon Czternasty, Oliwier Augustynowicz"
netid:      .asciz "sczternasty, oaugustynowicz"
assignment: .asciz "ASSIGNMENT 1: Factorial"
format:     .asciz "Names: %s\nNetID: %s\nAssignment: %s\n"
prompt:     .asciz "Enter non-negative number: "
input:      .asciz "%ld"
output:     .asciz "The factorial of %ld is %ld\n"

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
    movq $0, %rax # no floating point arguments
    movq $prompt, %rdi # first printf argument
    call printf # call printf
    
    # Read input
    subq $8, %rsp # allocate space on stack for 1 long integer
    movq $input, %rdi # first scanf argument
    leaq -8(%rbp), %rsi # load address of input
    movq $0, %rax # no floating point arguments
    call scanf # call scanf
    
    # Load input and call factorial
    movq -8(%rbp), %rdi # Pass input as parameter in %rdi
    call factorial # call factorial function
    
    # Print output
    movq $output, %rdi # first printf argument
    movq -8(%rbp), %rsi # copy original input number to second argument printf
    movq %rax, %rdx # copy factorial result to third argument printf
    movq $0, %rax # no floating point arguments
    call printf # call printf

    # epilogue
    movq %rbp, %rsp # restore stack pointer from base pointer
    popq %rbp # restore base pointer
    movq $0, %rdi # return 0 status
    call exit # call exit

# Recursive factorial function
factorial:
    # prologue
    pushq %rbp # save base pointer by pushing it onto the stack
    movq %rsp, %rbp # set base pointer to current stack pointer
    
    pushq %rdi # save parameter n

    cmpq $1, %rdi # compare n with 1
    jle base_case # if n <= 1, jump to base_case

    decq %rdi # n - 1
    call factorial # factorial(n-1) -> result in %rax
    
    popq %rdi # restore parameter n

    imulq %rdi, %rax # %rax = n * factorial(n-1)

    # epilogue
    movq %rbp, %rsp # clear local variables from stack
    popq %rbp # restore base pointer location
    ret # return to caller

base_case:

    movq $1, %rax # return 1 for n <= 1
    popq %rdi # restore parameter n

    # epilogue
    movq %rbp, %rsp # clear local variables from stack
    popq %rbp # restore base pointer location
    ret # return to caller

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
    pushq %rbp
    movq %rsp, %rbp
    
    # Print description
    movq $0, %rax
    movq $format, %rdi
    movq $names, %rsi
    movq $netid, %rdx
    movq $assignment, %rcx
    call printf
    
    # Prompt user
    movq $0, %rax
    movq $prompt, %rdi
    call printf
    
    # Read input
    subq $16, %rsp
    movq $input, %rdi
    leaq -8(%rbp), %rsi
    movq $0, %rax
    call scanf
    
    # Load input and call factorial
    movq -8(%rbp), %rdi      # Pass input as parameter in %rdi
    call factorial
    
    # Print output
    movq %rax, %rdx          # result (factorial return value)
    movq $output, %rdi
    movq -8(%rbp), %rsi      # original input number
    movq $0, %rax
    call printf
    
    # epilogue
    movq %rbp, %rsp
    popq %rbp
    movq $0, %rdi
    call exit

# Recursive factorial function
# Input: n in %rdi
# Output: n! in %rax
factorial:
    # prologue
    pushq %rbp
    movq %rsp, %rbp
    
    # Save parameter n (we'll need it after recursive call)
    pushq %rdi
    
    # Base case: if n <= 1, return 1
    cmpq $1, %rdi
    jle base_case
    
    # Recursive case: n * factorial(n-1)
    # Calculate factorial(n-1)
    decq %rdi               # n-1
    call factorial          # factorial(n-1) -> result in %rax
    
    # Restore original n
    popq %rdi
    
    # Multiply n * factorial(n-1)
    imulq %rdi, %rax        # %rax = n * factorial(n-1)
    
    # epilogue
    movq %rbp, %rsp
    popq %rbp
    ret

base_case:
    # Return 1 for n <= 1
    movq $1, %rax
    
    # Clean up saved parameter
    popq %rdi
    
    # epilogue
    movq %rbp, %rsp
    popq %rbp
    ret
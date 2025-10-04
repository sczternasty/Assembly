.data
format:     .ascii "My name is %s. I think I'll get a %u for my exam. What does %r do? And %%?\0"
name:       .ascii "Piet\0"

.text
.global main

main:
    # prologue
    pushq   %rbp                # save base pointer
    movq    %rsp, %rbp          # set base pointer

    movq    $format, %rdi       # format string
    movq    $name, %rsi         # first argument
    movq    $10, %rdx           # second argument
    call    my_printf

    # print newline
    movq    $10, %rax           # newline ASCII code
    call    print_char

    # epilogue
    movq %rbp, %rsp             # restore stack pointer
    popq    %rbp                # restore base pointer

    # exit program
    movq    $60, %rax            # syscall number for exit
    movq    $0, %rdi             # exit code 0
    syscall


my_printf:
    pushq   %rbp
    movq    %rsp, %rbp

    # save arguments and working registers
    pushq   %rsi                # arg1
    pushq   %rdx                # arg2
    pushq   %rcx                # arg3
    pushq   %r8                 # arg4
    pushq   %r9                 # arg5
    pushq   %r10                # working register
    pushq   %r11                # working register

    movq    %rdi, %r10          # pointer to format string
    movq    $0, %r11            # argument index

format_loop:
    movb    (%r10), %al         # load 8 bits (1 char) to lower byte of RAX
    testb   %al, %al            # check if lower byte is 0
    jz      format_done         # jump to done if null terminator

    cmpb    $37, %al            # check for '%'
    je      percent             # jump to percent handler if format specifier found

    call    print_char          # print regular character
    incq    %r10                # move to next character
    jmp     format_loop         # repeat loop

percent:
    incq    %r10                # move to specifier character
    movb    (%r10), %al         # get specifier character

    cmpb    $115, %al           # 's'
    je      string
    cmpb    $100, %al           # 'd'
    je      int
    cmpb    $117, %al           # 'u'
    je      uint
    cmpb    $37, %al          # '%'
    je      double_percent

    # unknown specifier: print '%' and char
    pushq   %rax                   # save specifier char
    movq    $37, %rax              # ASCII for '%'
    call    print_char             # print '%'
    popq    %rax                   # restore specifier char
    call    print_char             # print unknown specifier
    incq    %r10                   # move to next character
    jmp     format_loop            # get back to format loop

string:
    call    get_current_arg        # get argument based on index in r11
    movq    %rax, %rdi             # move argument to rdi for print_string
    call    print_string           # print the string
    incq    %r11                   # increment argument index
    incq    %r10                   # move to next character
    jmp     format_loop            # go back to format loop

int:
    call    get_current_arg        # get argument based on index in r11
    movq    %rax, %rdi             # move argument to rdi for print_signed_int
    call    print_signed_int       # print the signed integer
    incq    %r11                   # increment argument index
    incq    %r10                   # move to next character
    jmp     format_loop            # go back to format loop

uint:
    call    get_current_arg        # get argument based on index in r11
    movq    %rax, %rdi             # move argument to rdi for print_unsigned_int
    call    print_unsigned_int     # print the unsigned integer
    incq    %r11                   # increment argument index
    incq    %r10                   # move to next character
    jmp     format_loop            # go back to format loop

double_percent:
    movq    $37, %rax              # ASCII for '%'
    call    print_char             # print '%'
    incq    %r10                   # move to next character
    jmp     format_loop            # go back to format loop

format_done:
    # restore registers
    popq    %r11
    popq    %r10
    popq    %r9
    popq    %r8
    popq    %rcx
    popq    %rdx
    popq    %rsi
    
    # epilogue
    movq    %rbp, %rsp
    popq    %rbp

    ret 

get_current_arg:
    # determine where the argument is based on index in %r11
    # arguments 0-4 are in registers, 5+ are on stack
    cmpq    $0, %r11          
    je      get_arg0           
    cmpq    $1, %r11
    je      get_arg1
    cmpq    $2, %r11
    je      get_arg2
    cmpq    $3, %r11
    je      get_arg3
    cmpq    $4, %r11
    je      get_arg4

    # For args >= 6 (on stack)
    movq    %r11, %rax             # copy index to rax
    subq    $5, %rax               # adjust index for stack (arg 6 is at index 0 on stack)
    imulq   $8, %rax, %rax         # multiply by 8 (size of each arg)
    addq    $16, %rax              # account for saved rbp and return address
    addq    %rbp, %rax             # get address of argument on stack
    movq    (%rax), %rax           # load argument from stack
    ret

get_arg0: movq -8(%rbp), %rax; ret
get_arg1: movq -16(%rbp), %rax; ret
get_arg2: movq -24(%rbp), %rax; ret
get_arg3: movq -32(%rbp), %rax; ret
get_arg4: movq -40(%rbp), %rax; ret

# print single character
print_char:
    pushq   %rax
    pushq   %rdi
    pushq   %rsi
    pushq   %rdx
    pushq   %r11

    subq    $16, %rsp              # align stack
    movb    %al, (%rsp)            # move char to buffer

    movq    $1, %rax               # sys_write
    movq    $1, %rdi               # stdout
    movq    %rsp, %rsi             # buffer
    movq    $1, %rdx               # length = 1
    syscall

    addq    $16, %rsp
    popq    %r11
    popq    %rdx
    popq    %rsi
    popq    %rdi
    popq    %rax
    ret

# print null-terminated string in RDI
print_string:
    testq   %rdi, %rdi             # check if string pointer is null
    jz      print_string_done      # if null, jump to done

    pushq   %rax
    pushq   %rsi
    pushq   %rdx
    pushq   %r11

    movq    %rdi, %rsi             # copy string pointer
    movq    $0, %rdx               # length = 0

len_loop:
    movb    (%rsi), %al            # load byte
    testb   %al, %al               # check for null terminator
    jz      len_done               # if null, done
    incq    %rsi                   # move to next char
    incq    %rdx                   # increment length
    jmp     len_loop               # repeat

len_done:
    movq    $1, %rax               # sys_write
    pushq   %rdi                   # save original string pointer
    movq    $1, %rdi               # stdout
    popq    %rsi                   # restore string pointer
    syscall

    popq    %r11 
    popq    %rdx
    popq    %rsi
    popq    %rax

print_string_done:
    ret


print_signed_int:
    pushq   %rax
    pushq   %rcx
    pushq   %rdx
    pushq   %rsi
    pushq   %r11

    movq    %rdi, %rax             # copy number to rax
    testq   %rax, %rax             # check if number is negative
    jns     positive_int            

    # negative number
    pushq   %rax                   # save original number
    movq    $45, %rax              # ASCII for '-'
    call    print_char             # print '-'
    popq    %rax                   # restore original number
    negq    %rax                   # make positive

positive_int:
    subq    $32, %rsp              # allocate space for number string
    movq    %rsp, %rsi             # rsi points to buffer
    addq    $31, %rsi              # point to end of buffer
    movb    $0, (%rsi)             # null terminator
    movq    $10, %rcx              # base 10

    testq   %rax, %rax             # check if number is 0
    jnz     digit_loop
    decq    %rsi                   # move back one byte
    movb    $48, (%rsi)            # ASCII for '0'
    jmp     print_int_string 

digit_loop:
    testq   %rax, %rax             # check if number is 0
    jz      print_int_string
    movq    $0, %rdx              # clear rdx for division
    divq    %rcx                  # rax = rax / 10, rdx = rax % 10
    addb    $48, %dl              # convert to ASCII
    decq    %rsi                  # move back one byte
    movb    %dl, (%rsi)           # store digit
    jmp     digit_loop

print_int_string:
    movq    %rsi, %rdi            # move string pointer to rdi
    call    print_string          # print the string
    addq    $32, %rsp             # restore stack pointer

    popq    %r11
    popq    %rsi
    popq    %rdx
    popq    %rcx
    popq    %rax
    ret

print_unsigned_int:
    pushq   %rax
    pushq   %rcx
    pushq   %rdx
    pushq   %rsi
    pushq   %r11

    movq    %rdi, %rax             # copy number to rax
    subq    $32, %rsp              # allocate space for number string
    movq    %rsp, %rsi             # rsi points to buffer
    addq    $31, %rsi              # point to end of buffer
    movb    $0, (%rsi)             # null terminator
    movq    $10, %rcx              # base 10

    testq   %rax, %rax             # check if number is 0
    jnz     udigit_loop
    decq    %rsi                   # move back one byte
    movb    $48, (%rsi)            # ASCII for '0'
    jmp     print_uint_string

udigit_loop:
    testq   %rax, %rax            # check if number is 0
    jz      print_uint_string
    movq    $0, %rdx              # clear rdx for division
    divq    %rcx                  # rax = rax / 10, rdx = rax % 10
    addb    $48, %dl              # convert to ASCII
    decq    %rsi                  # move back one byte
    movb    %dl, (%rsi)           # store digit
    jmp     udigit_loop

print_uint_string:
    movq    %rsi, %rdi           # move string pointer to rdi
    call    print_string         # print the string
    addq    $32, %rsp            # restore stack pointer

    popq    %r11
    popq    %rsi
    popq    %rdx
    popq    %rcx
    popq    %rax
    ret

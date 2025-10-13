.data
format:     .ascii ""

.text
.global main

main:
    # prologue
    pushq   %rbp
    movq    %rsp, %rbp

    movq    $format, %rdi       # format string
    #movq    $name, %rsi         # first argument
    movq    $0, %rsi           # second argument
    call    my_printf

    # print newline
    movq    $10, %rdi           # '\n'
    call    print_char

    # epilogue
    movq    %rbp, %rsp
    popq    %rbp

    movq    $60, %rax           # syscall: exit
    movq    $0, %rdi
    syscall

my_printf:
    # prologue
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
    movq    $0, %rax            # clear rax for safety
    movb    (%r10), %al         # load 8 bits (1 char) to lower byte of RAX
    testb   %al, %al            # check if lower byte is 0
    jz      format_done         # jump to done if null terminator

    cmpb    $37, %al            # check for '%'
    je      percent             # jump to percent handler if format specifier found

    movb    %al, %dil           # put character into %dil (arg for print_char)
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
    cmpb    $37, %al            # '%'
    je      double_percent

    # unknown specifier: print '%' and char
    movb    $37, %dil          # ASCII for '%'
    call    print_char          # print '%'
    movb    %al, %dil           # print unknown specifier
    call    print_char
    incq    %r10                # move to next character
    jmp     format_loop         # get back to format loop

string:
    call    get_current_arg     # get argument based on index in r11
    movq    %rax, %rdi          # move argument to rdi for print_string
    call    print_string        # print the string
    incq    %r11                # increment argument index
    incq    %r10                # move to next character
    jmp     format_loop         # go back to format loop

int:
    call    get_current_arg     # get argument based on index in r11
    movq    %rax, %rdi          # move argument to rdi for print_signed_int
    call    print_signed_int    # print the signed integer
    incq    %r11                # increment argument index
    incq    %r10                # move to next character
    jmp     format_loop         # go back to format loop

uint:
    call    get_current_arg     # get argument based on index in r11
    movq    %rax, %rdi          # move argument to rdi for print_unsigned_int
    call    print_unsigned_int  # print the unsigned integer
    incq    %r11                # increment argument index
    incq    %r10                # move to next character
    jmp     format_loop         # go back to format loop

double_percent:
    movb    $37, %dil          # ASCII for '%'
    call    print_char          # print '%'
    incq    %r10                # move to next character
    jmp     format_loop         # go back to format loop

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
    # arguments 0-4 are in registers (saved on our stack), 5+ are on caller's stack
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

    # For args >= 5
    # addr = rbp + 16 + 8 * (index - 5)
    movq    %r11, %rax        # rax = index
    subq    $5, %rax          # rax = index - 5
    lea     16(%rbp, %rax, 8), %rax   # rax = rbp + 16 + 8*(index-5)
    movq    (%rax), %rax      # load argument from caller stack into rax
    ret

get_arg0: movq -8(%rbp), %rax; ret
get_arg1: movq -16(%rbp), %rax; ret
get_arg2: movq -24(%rbp), %rax; ret
get_arg3: movq -32(%rbp), %rax; ret
get_arg4: movq -40(%rbp), %rax; ret


print_char:
    pushq   %rax
    pushq   %rdi
    pushq   %rsi
    pushq   %rdx
    pushq   %r11

    subq    $16, %rsp              # make space for buffer
    movb    %dil, (%rsp)           # move char to buffer

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
    movq    $0, %rax               # clear rax for safety
    movb    (%rsi), %al            # load 1 byte (char) to lower byte of RAX
    testb   %al, %al
    jz      len_done
    incq    %rsi
    incq    %rdx
    jmp     len_loop

len_done:
    movq    $1, %rax               # sys_write
    pushq   %rdi
    movq    $1, %rdi
    popq    %rsi                   # beginning of string
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
    testq   %rax, %rax
    jns     positive_int

    # negative number
    pushq   %rax                   # save original number
    movb    $45, %dil
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
    movb    $48, (%rsi)           # ASCII for '0'
    jmp     print_int_string

digit_loop:
    testq   %rax, %rax
    jz      print_int_string
    movq    $0, %rdx
    divq    %rcx                   # rax = rax / 10, rdx = rax % 10
    addb    $48, %dl              # convert to ASCII
    decq    %rsi                   # move back one byte
    movb    %dl, (%rsi)            # store digit
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

    movq    %rdi, %rax
    subq    $32, %rsp
    movq    %rsp, %rsi
    addq    $31, %rsi
    movb    $0, (%rsi)
    movq    $10, %rcx

    testq   %rax, %rax
    jnz     udigit_loop
    decq    %rsi
    movb    $48, (%rsi)
    jmp     print_uint_string

udigit_loop:
    testq   %rax, %rax
    jz      print_uint_string
    xorq    %rdx, %rdx
    divq    %rcx
    addb    $48, %dl
    decq    %rsi
    movb    %dl, (%rsi)
    jmp     udigit_loop

print_uint_string:
    movq    %rsi, %rdi
    call    print_string
    addq    $32, %rsp

    popq    %r11
    popq    %rsi
    popq    %rdx
    popq    %rcx
    popq    %rax
    ret

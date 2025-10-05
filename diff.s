.data
file1: .asciz "Hi, this is a testfile.\nTestfile 1 to be precise.\nAnother line here.\n"
file2: .asciz "Hi, this is a testfile.\nTestfile 1 to be precise.\nAnother line here.\n Extra line.\n"

# format strings for output
change_c: .asciz "c"       # change indicator for differing lines
newline:  .asciz "\n"      # newline character
less_than:.asciz "< "      # diff symbol for first file
separator:.asciz "---\n"   # separator between lines
greater:  .asciz "> "      # diff symbol for second file

# Option flags
opt_i:    .asciz "-i"      # ignore case flag
opt_B:    .asciz "-B"      # ignore blank lines flag

.bss
.lcomm line1_buf, 1024         # buffer to hold line from file1
.lcomm line2_buf, 1024         # buffer to hold line from file2
.lcomm line1_processed, 1024   # buffer to hold processed line1
.lcomm line2_processed, 1024   # buffer to hold processed line2

.text
.globl main

main:
    # prologue
    pushq %rbp
    movq %rsp, %rbp

    # save command line args
    movq %rdi, %r14     # argc
    movq %rsi, %r15     # argv

    movq $0, %r12       # flag_i = 0 (ignore case)
    movq $0, %r13       # flag_B = 0 (ignore blank lines)

    cmpq $1, %r14      # if argc <= 1, no options provided
    jle call_diff

    movq $1, %rcx        # start parsing argv

parse_loop:
    cmpq %r14, %rcx       # check if all args processed
    jge call_diff        

    # -i option
    movq (%r15,%rcx,8), %rdi    # argv[rcx]
    leaq opt_i(%rip), %rsi      # memory address of "-i"
    call strcmp                 # compare strings
    testq %rax, %rax            # check if equal
    jz set_i

    # -B option
    movq (%r15,%rcx,8), %rdi   # argv[rcx]
    leaq opt_B(%rip), %rsi           # memory address of "-B"
    call strcmp                # compare strings
    testq %rax, %rax           # check if equal
    jz set_B

    jmp next_arg

set_i:
    movq $1, %r12          # Set ignore-case flag
    jmp next_arg

set_B:
    movq $1, %r13          # Set ignore-blank-lines flag

next_arg:
    incq %rcx               # move to next argument
    jmp parse_loop

call_diff:
    leaq file1(%rip), %rdi  # load address of file1
    leaq file2(%rip), %rsi  # load address of file2
    movq %r12, %rdx         # flag_i
    movq %r13, %rcx         # flag_B
    call diff

    # epilogue
    movq %rbp, %rsp
    popq %rbp
    movq $0, %rdi
    call exit

diff:

    # prologue
    pushq %rbp
    movq %rsp, %rbp


    subq $32, %rsp        # Allocate stack space for arguments
    pushq %r12            
    pushq %r13
    pushq %r14
    pushq %r15
    pushq %rbx

    # save function args on stack
    movq %rdi, -8(%rbp)   # file1 pointer
    movq %rsi, -16(%rbp)  # file2 pointer
    movq %rdx, -24(%rbp)  # flag_i
    movq %rcx, -32(%rbp)  # flag_B

    # line counters
    movq $1, %r14        # line_num1
    movq $1, %r15        # line_num2

diff_loop:
    # read line from file1
    movq -8(%rbp), %rdi         # file1 pointer
    leaq line1_buf(%rip), %rsi  # buffer for line1
    movq $1024, %rdx            # max length
    call get_line               # read line
    movq %rax, %r12             # r12 = number of chars read
    movq %rdx, -8(%rbp)         # Update file1 pointer

    # read line from file2
    movq -16(%rbp), %rdi        # file2 pointer
    leaq line2_buf(%rip), %rsi  # buffer for line2
    movq $1024, %rdx            # max length
    call get_line               # read line
    movq %rax, %r13             # r13 = number of chars read
    movq %rdx, -16(%rbp)        # Update file2 pointer

    # check for EOF
    testq %r12, %r12            # check if file1 ended
    jz check_file2_end
    testq %r13, %r13            # check if file2 ended
    jz check_file1_end
    jmp process_lines

check_file1_end:
    # file2 ended but file1 has more lines
    movq %r14, %rdi             # line number from file1
    call print_num              
    leaq change_c(%rip), %rdi   # change context
    call print_str
    movq %r15, %rdi             # line number from file2
    call print_num
    movq newline, %rdi          
    call print_str
    leaq less_than(%rip), %rdi  
    call print_str
    leaq line1_buf(%rip), %rdi
    call print_str
    leaq separator(%rip), %rdi
    call print_str
    incq %r14                  # increment line number for file1
    jmp diff_loop

check_file2_end:
    testq %r13, %r13           # check if file2 ended
    jz diff_done  
    # file1 ended but file2 has more lines - show as addition
    movq %r14, %rdi            # line number from file1
    call print_num
    leaq change_c(%rip), %rdi  # change context
    call print_str
    movq %r15, %rdi            # line number from file2
    call print_num
    leaq newline(%rip), %rdi
    call print_str
    leaq separator(%rip), %rdi
    call print_str
    leaq greater(%rip), %rdi
    call print_str
    leaq line2_buf(%rip), %rdi
    call print_str
    incq %r15                  # increment line number for file2
    jmp diff_loop

process_lines:
    leaq line1_buf(%rip), %rdi          # address of line1
    leaq line1_processed(%rip), %rsi    # destination buffer
    movq -24(%rbp), %rdx                # flag_i
    movq -32(%rbp), %rcx                # flag_B
    call process_line
    movq %rax, %r12                     # r12 = length of processed line1

    cmpq $0, -32(%rbp)                  # if -B option not set, skip blank line check
    je process_line2
    testq %r12, %r12                    # check if processed line1 is empty
    jnz process_line2
    incq %r14                           # increment line number for file1
    jmp diff_loop

process_line2:
    leaq line2_buf(%rip), %rdi          # address of line2
    leaq line2_processed(%rip), %rsi    # destination buffer
    movq -24(%rbp), %rdx                # flag_i
    movq -32(%rbp), %rcx                # flag_B
    call process_line
    movq %rax, %r13                     # r13 = length of processed line2

    cmpq $0, -32(%rbp)                  # if -B option not set, skip blank line check
    je compare_lines
    testq %r13, %r13                    # check if processed line2 is empty
    jnz compare_lines
    incq %r15                           # increment line number for file2
    jmp diff_loop

compare_lines:
    leaq line1_processed(%rip), %rdi   # processed line1
    leaq line2_processed(%rip), %rsi   # processed line2
    call strcmp
    testq %rax, %rax
    jz lines_equal       # lines are equal, skip printing

    # lines differ
    movq %r14, %rdi            # line number from file1
    call print_num 
    leaq change_c(%rip), %rdi  # change context
    call print_str
    movq %r15, %rdi            # line number from file2
    call print_num
    leaq newline(%rip), %rdi   
    call print_str

    leaq less_than(%rip), %rdi
    call print_str
    leaq line1_buf(%rip), %rdi 
    call print_str

    leaq separator(%rip), %rdi
    call print_str

    leaq greater(%rip), %rdi
    call print_str
    leaq line2_buf(%rip), %rdi
    call print_str

lines_equal:
    incq %r14          # increment line number for file1
    incq %r15          # increment line number for file2
    jmp diff_loop 

diff_done:

    # restore registers
    popq %rbx
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    addq $32, %rsp

    # epilogue
    movq %rbp, %rsp
    popq %rbp
    ret

get_line:

    # prologue
    pushq %rbp
    movq %rsp, %rbp

    movq %rdi, %r8      # source file pointer
    movq %rsi, %r9      # destination buffer
    movq $0, %rax       # Counter for chars read

getline_loop:
    movb (%r8), %cl     # read byte from file
    testb %cl, %cl      # check for EOF
    jz getline_end      # end of string
    movb %cl, (%r9)     # store byte in buffer
    incq %r8            # move to next byte in source
    incq %r9            # move to next byte in buffer
    incq %rax           # increment char count
    cmpb $10, %cl       # check for newline
    je getline_end      # stop at newline
    cmpq %rdx, %rax     # check if max length reached
    jl getline_loop

getline_end:
    movb $0, (%r9)        # null-terminate line
    movq %r8, %rdx        # save new pointer for next call

    # epilogue
    movq %rbp, %rsp
    popq %rbp
    ret

process_line:

    # prologue
    pushq %rbp  
    movq %rsp, %rbp

    pushq %r12            # save callee-saved register
    movq %rdi, %r8        # source line
    movq %rsi, %r9        # destination buffer
    movq %rdx, %r10       # flag_i
    movq %rcx, %r11       # flag_B
    movq $0, %rax         # output counter

process_loop:
    movb (%r8), %cl       # read byte from source
    testb %cl, %cl 
    jz process_done

    cmpb $10, %cl         # newline
    je process_next

    testq %r11, %r11      # -B flag
    jz check_case
    cmpb $32, %cl         # space
    je process_next
    cmpb $9, %cl          # tab
    je process_next

check_case:
    testq %r10, %r10      # -i flag
    jz store_char
    cmpb $65, %cl         # 'A'
    jl store_char
    cmpb $90, %cl         # 'Z'
    jg store_char
    addb $32, %cl         # Convert to lowercase

store_char:
    movb %cl, (%r9)       # store character
    incq %r9              # move to next position in buffer
    incq %rax             # increment output counter

process_next:
    incq %r8              # move to next character in source
    jmp process_loop

process_done:
    movb $0, (%r9)        # null-terminate
    popq %r12             # restore callee-saved register

    # epilogue
    movq %rbp, %rsp
    popq %rbp 
    ret

strcmp:
    # prologue
    pushq %rbp
    movq %rsp, %rbp

strcmp_loop:
    movb (%rdi), %al       # load byte from str1
    movb (%rsi), %bl       # load byte from str2
    cmpb %bl, %al          # if bytes differ, jump to strcmp_diff
    jne strcmp_diff
    testb %al, %al         # check for null terminator
    jz strcmp_equal
    incq %rdi              # move to next byte in str1
    incq %rsi              # move to next byte in str2
    jmp strcmp_loop

strcmp_equal:
    movq $0, %rax          # strings are equal

    # epilogue
    movq %rbp, %rsp
    popq %rbp
    ret

strcmp_diff:
    movzbl %al, %eax        # convert to 32-bit int
    movzbl %bl, %ebx        # convert to 32-bit int
    subl %ebx, %eax         # return difference in rax

    # epilogue
    movq %rbp, %rsp
    popq %rbp
    ret


print_str:

    # prologue
    pushq %rbp
    movq %rsp, %rbp

    movq %rdi, %rsi         # string pointer
    movq $0, %rdx           # length counter

len_loop:
    movb (%rsi,%rdx), %al   # load byte
    testb %al, %al          # check for null terminator
    jz write
    incq %rdx                # increment length
    jmp len_loop

write:
    movq $1, %rax            # sys_write
    movq $1, %rdi            # stdout
    syscall

    # epilogue
    movq %rbp, %rsp
    popq %rbp
    ret

print_num:
    # prologue
    pushq %rbp
    movq %rsp, %rbp

    subq $32, %rsp           # allocate space for number string
    movq %rdi, %rax          # copy number to rax
    leaq 31(%rsp), %rsi      # point to end of buffer
    movb $0, (%rsi)          # null terminator
    movq $10, %rcx           # base 10

num_loop:
    movq $0, %rdx            # clear rdx for division
    divq %rcx                # rax = rax / 10, rdx = rax % 10
    addb $'0', %dl           # convert to ASCII
    decq %rsi                # move back one byte
    movb %dl, (%rsi)         # store digit
    testq %rax, %rax         # check if number is 0
    jnz num_loop

    movq %rsi, %rdi          # move string pointer to rdi
    call print_str

    addq $32, %rsp           # restore stack pointer

    # epilogue
    movq %rbp, %rsp
    popq %rbp
    ret

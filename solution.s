.data
    .globl KEYBOARD
	.global MOUSE
	.global MONITOR
KEYBOARD:
    .byte 0x00    # status
    .byte 0x00    # data in
    .byte 0x00    # data out
MOUSE:
    .byte 0x00
    .byte 0x00
    .byte 0x00
MONITOR:
    .byte 0x00
    .byte 0x00
    .byte 0x00


INTERRUPT_VECTOR:
    .quad keyboard_isr 
    .quad mouse_isr

left_click_str: .ascii "*left click*\0"

right_click_str: .ascii "*right click*\0"

.bss
buffer:
    .quad 0,0,0,0

buffer_index:
    .quad 0                            # current index in buffer

.global buffer
.globl handle_IRQ
.global main_loop

.text
handle_IRQ:
    pushq   %rbp
    movq    %rsp, %rbp
    pushq   %rbx
    pushq   %r12
    movq    $0, %rax                   # clear rax to avoid garbage

    movq    $INTERRUPT_VECTOR, %r12    # load interrupt vector base address

    movq    $KEYBOARD, %rdi            # keyboard address
    movb    (%rdi), %al                # check first byte in keyboard - status
    testb   $0x80, %al                 # check ready bit (bit 7)
    jz      handle_check_mouse
    movq    (%r12), %rbx               # load keyboard ISR address
    call    *%rbx                      # call the ISR
    jmp     handle_done

handle_check_mouse:
    movq    $MOUSE, %rdi               # mouse address
    movb    (%rdi), %al                # check first byte in mouse - status
    testb   $0x80, %al                 # check IRQ bit (bit 7)
    jz      handle_done
    movq    8(%r12), %rbx              # load mouse ISR address
    call    *%rbx                      # call the ISR

handle_done:
    popq    %r12
    popq    %rbx
    leave
    ret

keyboard_isr:
    pushq   %rbp
    movq    %rsp, %rbp
    movq    $0, %rax                   # clear rax to avoid garbage

    movq    $KEYBOARD, %rdi            # address of keyboard
    movb    1(%rdi), %al               # move to second byte - data

    cmpb    $13, %al                   # check if Enter
    je      keyboard_append
    cmpb    $32, %al                   # check if in range of printable (space)
    jb      keyboard_done
    cmpb    $127, %al                  # check if in range of printable (DEL)
    ja      keyboard_done

keyboard_append:
    movq    $buffer_index, %rdx        # load index
    movq    (%rdx), %rdx               # rdx = idx
    cmpq    $32, %rdx                  # check if there is space in buffer
    jae     keyboard_done 

    movq    $buffer, %rdi              # rdi = buffer address pointer
    movb    %al, (%rdi,%rdx)           # store char at buffer+idx

    incq    %rdx                       # advance index
    movq    $buffer_index, %rcx        # load index address
    movq    %rdx, (%rcx)               # store updated index

keyboard_done:
    leave
    ret

mouse_isr:
    pushq   %rbp 
    movq    %rsp, %rbp
    pushq   %rbx
    movq    $0, %rax                   # clear rax to avoid garbage

    movq    $MOUSE, %rdi               # mouse address
    movb    1(%rdi), %al               # move to second byte - data
    cmpb    $1, %al                    # left click
    je      mouse_left
    cmpb    $2, %al                    # right click
    je      mouse_right
    jmp     mouse_done

mouse_left:
    movq    $left_click_str, %rdi      # address of left click string
    movq    $12, %rsi                  # length of string
    jmp     click_append

mouse_right:
    movq    $right_click_str, %rdi     # address of right click string
    movq    $13, %rsi                  # length of string

click_append:
    movq    $buffer_index, %rdx        # buffer_index address pointer
    movq    (%rdx), %rbx               # rbx = idx
    
    movq    %rsi, %rcx                 # length of string to append
    addq    %rbx, %rcx                 # new index after append
    cmpq    $32, %rcx                  # check if new index is not out of buffer size
    ja      mouse_done

    movq    %rdi, %r8                  # source string address
    movq    $buffer, %rdi              # buffer address
    movq    $0, %rax                   # index for source string

append_loop:
    cmpq    %rcx, %rbx                 # compare new index with current length
    jae     append_done
    movb    (%r8,%rax), %dl            # load byte from source
    movb    %dl, (%rdi,%rbx)           # store byte in buffer
    incq    %rbx                       # increment buffer index
    incq    %rax                       # increment source index
    jmp     append_loop
    
append_done:
    movq    $buffer_index, %rdx        # buffer_index address pointer
    movq    %rbx, (%rdx)               # update buffer_index

mouse_done:
    popq    %rbx
    leave
    ret

main_loop:
    pushq   %rbp
    movq    %rsp, %rbp

    pushq   %rbx          
    pushq   %r12
    pushq   %r13
    pushq   %r14

    movq    $buffer_index, %rdx        # buffer_index address pointer
    movq    (%rdx), %r13               # r13 = idx
    cmpq    $0, %r13                   # if no data, skip
    jz      main_done

    movq    $buffer, %r12              # buffer address pointer

    movq    $1, %rax                   # sys_write
    movq    $1, %rdi                   # stdout
    movq    %r12, %rsi                 # buffer address pointer
    movq    %r13, %rdx                 # count
    syscall

    movq    $MONITOR, %r14             # MONITOR address pointer
    movq    $0, %rbx                   # i = 0

monitor_loop:
    cmpq    %r13, %rbx                 # while (i < len)
    jae     clear_buffer

wait_ready:
    movb    (%r14), %al                # MONITOR status
    testb   $0x01, %al                 # ready bit?
    jz      wait_ready

    movb    (%r12,%rbx), %al           # char at buffer + idx
    movb    %al, 2(%r14)               # MONITOR data_out = al
    incq    %rbx                       # advance i
    jmp     monitor_loop

clear_buffer:
    movq    $buffer, %rdi              # buffer address pointer
    movq    $32, %rcx                  # 32 bytes to clear
    movq    $0, %rax                   

zero_loop:
    movb    %al, (%rdi)                # clear byte
    incq    %rdi                       # next byte
    decq    %rcx                       # decrement count
    jnz     zero_loop

    movq    $buffer_index, %rsi        # buffer_index address pointer
    movq    $0, (%rsi)                 # reset index to 0

main_done:
    popq    %r14
    popq    %r13
    popq    %r12
    popq    %rbx
    leave
    ret

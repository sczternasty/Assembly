.data
KEYBOARD:
    .byte 0x00   # status
    .byte 0x00   # data in
    .byte 0x00   # data out

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

left_click: .ascii "*left click*\0"
right_click: .ascii "*right click*\0"


buffer_idx:
    .quad 0                # current position in buffer

.bss
buffer:
    .quad 0, 0, 0, 0      # 32 bytes buffer

.text
.globl main

main:

    pushq %rbp
    movq %rsp, %rbp

    call main_loop

    popq %rbp
    ret

poll_device:

    # prologue
    pushq %rbp
    movq %rsp, %rbp

    movb (%rdi), %al       # load status
    andb $0x80, %al        # check ready bit (7)

    # epilogue
    movq %rbp, %rsp
    popq %rbp
    ret

call_ISR:

    # prologue
    pushq %rbp
    movq %rsp, %rbp

    movq INTERRUPT_VECTOR(,%rdi,8), %rax # load address of isr (rdi = 0 for keyboard, 1 for mouse)
    call *%rax                           # call isr (address in rax)

    # epilogue
    movq %rbp, %rsp
    popq %rbp

    ret

handle_IRQ:
    pushq %rbp
    movq %rsp, %rbp

    movq KEYBOARD, %rdi        # read STATUS byte
    call poll_device
    cmpb $0, %al          # check if data available
    jz next_device
    movq $0, %rdi             # device 0 = keyboard
    call call_ISR
    jmp irq_done

next_device:

    movq MOUSE, %rdi             # check mouse irq
    call poll_device
    cmpb $0, %al                  # check if data available
    jz irq_done
    movq $1, %rdi                 # device 1 = mouse
    call call_ISR

irq_done:
    movq %rbp, %rsp
    popq %rbp
    ret

keyboard_isr:

    pushq %rbp
    movq %rsp, %rbp

    movb KEYBOARD, %al        # read STATUS byte
    testb $0x01, %al          # check if data ready
    je   kbd_done

    movl buffer_idx, %ecx   # load current buffer position
    cmpl $32, %ecx          # check if buffer full
    jge kbd_done            # buffer full

    movb KEYBOARD+1, %al    # read datain

    cmpb $13, %al           # enter
    je kbd_append
    cmpb $32, %al           # ascii out of range (below space)
    jb kbd_done
    cmpb $127, %al          # ascii out of range (above DEL)
    ja kbd_done

kbd_append:
    movb %al, buffer(%ecx)  # append byte
    incl %ecx
    movl %ecx, buffer_idx

kbd_done:

    movq %rbp, %rsp
    popq %rbp
    ret

mouse_isr:

    pushq %rbp
    movq %rsp, %rbp

    movb MOUSE, %al        # read STATUS byte
    testb $0x01, %al       # check if data available
    je   mouse_done

    movl buffer_idx, %ecx   # load current buffer position
    movl $32, %edx           # total buffer size
    subl %ecx, %edx          # remaining buffer space

    movb MOUSE+1, %al    # read datain
    cmpb $1, %al         # left click
    jne check_right     # if not left click, check right click

    cmpl $12, %edx      # check if buffer has space for left click
    jl mouse_done       # not enough space

    leaq buffer(%rcx), %rdi # destination
    movq $left_click, %rsi  # source
    movq $12, %rcx          # length
    movq $0, %rax           # counter
copy_left_click:

    movb (%rsi,%rax), %dl # load byte from source
    movb %dl, (%rdi,%rax) # store byte to destination
    incq %rax               # increment counter
    cmpq %rcx, %rax         # compare with length
    jb copy_left_click      # repeat if not done
    addl $12, buffer_idx    # update buffer index
    jmp mouse_done          

check_right:
    cmpb $2, %al                # right click
    jne mouse_done              # if not right click, exit

    cmpl $13, %edx              # check if buffer has space for right click
    jl mouse_done               # not enough space

    leaq buffer(%rcx), %rdi     # destination
    movq $right_click, %rsi     # source
    movq $13, %rcx              # length
    movq $0, %rax               # counter
copy_right_click:
    movb (%rsi,%rax), %dl     # load byte from source
    movb %dl, (%rdi,%rax)     # store byte to destination
    incq %rax                    # increment counter
    cmpq %rcx, %rax              # compare with length
    jb copy_right_click          # repeat if not done
    addl $13, buffer_idx         # update buffer index

mouse_done:

    movq %rbp, %rsp 
    popq %rbp
    ret

main_loop:
    pushq %rbp
    movq %rsp, %rbp

    movl $0, %ebx            # index = 0

write_loop:
    cmpl buffer_idx, %ebx    # check if all data written
    jge reset_buffer         # if yes, reset buffer

wait_ready:
    movb MONITOR, %al       # read STATUS byte
    testb $0x01, %al        # check if ready
    jz wait_ready        

    movb buffer(%ebx), %al  # load byte from buffer
    movb %al, MONITOR+2     # write to data out
    incl %ebx               # increment index
    jmp write_loop  

reset_buffer:
    movq $buffer, %rdi   # pointer to buffer
    movq $4, %rcx        # 4 qwords = 32 bytes
    movq $0, %rax        

clear_buffer_loop:
    movq %rax, (%rdi)   # clear qword
    addq $8, %rdi      # move to next qword
    decq %rcx 
    jnz clear_buffer_loop


    movl $0, buffer_idx # reset buffer index

    movq %rbp, %rsp
    popq %rbp
    ret

.data
.globl KEYBOARD
.globl MOUSE
.globl MONITOR
KEYBOARD:
	.byte 0x00
	.byte 0x00
	.byte 0x00
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

.bss
buffer:
	.quad 0,0,0,0

buffer_index:
	.quad 0

.global buffer
.global handle_IRQ
.global main_loop

.text
poll_device:
	pushq %rbp
	movq %rsp, %rbp
	
	movb (%rdi), %al       # load status byte
	andb $0x08, %al        # check ready bit (bit 7)

	leave
	ret

call_ISR:
	pushq %rbp
	movq %rsp, %rbp

	push %r12
	
	movq INTERRUPT_VECTOR(,%rdi,8), %rax  # load ISR address
	call *%rax                             # call the ISR
	
	pop %r12
	leave
	ret

handle_IRQ:
	pushq %rbp
	movq %rsp, %rbp
	
	movq $KEYBOARD, %rdi   # check keyboard
	call poll_device
	cmpb $0, %al  			# if not ready
	jz check_mouse
	movq $0, %rdi          # device 0 = keyboard
	call call_ISR
	jmp irq_done

check_mouse:
	movq $MOUSE, %rdi      # check mouse
	call poll_device
	cmpb $0, %al           # if not ready
	jz irq_done
	movq $1, %rdi          # device 1 = mouse
	call call_ISR

irq_done:
	leave
	ret

keyboard_isr:
	pushq %rbp
	movq %rsp, %rbp
	
	movq buffer_index, %r12   # load buffer index from memory
	
	movb KEYBOARD, %al        # read status byte
	testb $0x01, %al          # check data ready bit
	je kbd_done
	
	cmpl $32, %r12d            # check if buffer full
	jge kbd_done
	
	movb KEYBOARD+1, %al      # read data byte
	
	cmpb $13, %al             # enter key
	je kbd_append
	cmpb $32, %al             # below space
	jb kbd_done
	cmpb $127, %al            # above DEL
	ja kbd_done

kbd_append:
	movb %al, buffer(%r12)    # store in buffer
	incq %r12                  # increment buffer index
	movq %r12, buffer_index     # store new index back to memory

kbd_done:
	leave
	ret

mouse_isr:
	pushq %rbp
	movq %rsp, %rbp
	
	movq buffer_index, %r12   # current position in buffer
	movl $32, %edx
	subl %r12d, %edx         # remaining space in buffer
	cmpl $0, %edx            # check if space is available
	jle mouse_done

	movb MOUSE, %al           # read status byte
	testb $0x01, %al          # check data ready
	je mouse_done
	
	movb MOUSE+1, %al         # read data byte
	cmpb $1, %al              # left click
	jne check_right
	
	cmpl $12, %edx            # need 12 bytes
	jl mouse_done
	
	leaq buffer(,%r12,1), %rdi # destination
	movq $left_click, %rsi  # source
	movq $12, %rcx            # length
	movq $0, %rax 		 # index
copy_left:
	movb (%rsi,%rax), %dl  # load byte
	movb %dl, (%rdi,%rax) # store byte
	incq %rax 		   
	cmpq %rcx, %rax 
	jb copy_left

	movq buffer_index, %r12  # reload buffer index
	addq $13, %r12            # update buffer index
	movq %r12, buffer_index   # store back
	jmp mouse_done

check_right:
	cmpb $2, %al              # right click
	jne mouse_done
	
	cmpl $13, %edx            # need 13 bytes
	jl mouse_done

	leaq buffer(,%r12,1), %rdi # destination
	movq $right_click, %rsi # source
	movq $13, %rcx            # length
	movq $0, %rax             # index
copy_right:
	movb (%rsi,%rax), %dl # load byte
	movb %dl, (%rdi,%rax) # store byte
	incq %rax
	cmpq %rcx, %rax
	jb copy_right

	movq buffer_index, %r12
	addq $13, %r12            # update buffer index
	movq %r12, buffer_index

mouse_done:
	leave
	ret

main_loop:
    pushq %rbp
    movq %rsp, %rbp
	
    pushq %rbx                 
    movl $0, %ebx              # index = 0

write_loop:
    movl buffer_index, %r8d   # load the current bound each time

    cmpl %r8d, %ebx            # done if ebx >= buffer_index
    jge reset_buffer

wait_ready:
    movb MONITOR, %al          # read monitor status
    testb $0x01, %al           # check ready bit
    jz wait_ready

    movb buffer(%rbx), %al     # byte to send
    movb %al, MONITOR+2        

    movq $1, %rax 		   # sys_write
    movq $1, %rdi 			# stdout
    leaq buffer(%rbx), %rsi  # address of byte
    movq $1, %rdx 	# length 1
    syscall                    

    incl %ebx
    jmp write_loop

reset_buffer:
    movq $buffer, %rdi         # buffer pointer
    movq $4, %rcx              # 4 qwords = 32 bytes
    movq $0, %rax
clear_loop:
    movq %rax, (%rdi)
    addq $8, %rdi
    decq %rcx
    jnz clear_loop

    movq $0, buffer_index      # reset buffer index

    popq %rbx
    leave
    ret

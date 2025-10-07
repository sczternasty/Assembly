.global sha1_chunk

sha1_chunk:
    # prologue
    pushq   %rbp
    movq    %rsp, %rbp

    pushq   %rbx
    pushq   %r12
    pushq   %r13
    pushq   %r14
    pushq   %r15

    # load initial hash state
    movl    0(%rdi), %r8d    # h0 = a
    movl    4(%rdi), %r9d    # h1 = b
    movl    8(%rdi), %r10d   # h2 = c
    movl    12(%rdi), %r11d  # h3 = d
    movl    16(%rdi), %r12d  # h4 = e

    movl    $16, %ecx  		# i = 16

expand:
    cmpl    $80, %ecx       # check if all 80 words have been expanded 
    jge     rounds_start

    # w[i] = (w[i-3] ^ w[i-8] ^ w[i-14] ^ w[i-16]) <<< 1
    movl    -12(%rsi,%rcx,4), %eax   # w[i-3]
    xorl    -32(%rsi,%rcx,4), %eax   # xor w[i-8]
    xorl    -56(%rsi,%rcx,4), %eax   # xor w[i-14]
    xorl    -64(%rsi,%rcx,4), %eax   # xor w[i-16]
    roll    $1, %eax                 # rotate left by 1
    movl    %eax, 0(%rsi,%rcx,4)     # store w[i]
    incl    %ecx
    jmp     expand

rounds_start:
    # load SHA-1 constants
    movl    $0x5A827999, %r13d   # K0
    movl    $0x6ED9EBA1, %r14d   # K1
    movl    $0x8F1BBCDC, %r15d   # K2
    movl    $0xCA62C1D6, %ebx    # K3

	movl    $0, %ecx             # i = 0

round_0_19:
	cmpl    $20, %ecx             # if i >= 20, jump to next round
	jge     round_20_39
	# f = (b & c) | ((~b) & d)
	movl    %r9d, %edx            # edx = b
	movl    %r9d, %eax            # eax = b
	notl    %eax                  # eax = ~b
	andl    %r11d, %eax           # eax = (~b) & d
	andl    %r10d, %edx           # edx = b & c
	orl     %eax, %edx            # edx = f
	# temp = rol(a,5) + f + e + K0 + w[i]
	movl    %r8d, %eax            # eax = a
	roll    $5, %eax              # eax = rol(a,5)
	addl    %edx, %eax            # eax += f
	addl    %r12d, %eax           # eax += e
	addl    %r13d, %eax           # eax += K0
	addl    0(%rsi,%rcx,4), %eax  # eax += w[i]
	# update 
	movl    %r11d, %r12d          # e = d
	movl    %r10d, %r11d          # d = c
	movl    %r9d, %edx            # edx = b
	roll    $30, %edx              # edx = rol(b,30)
	movl    %edx, %r10d           # c = rol(b,30)
	movl    %r8d, %r9d            # b = a
	movl    %eax, %r8d            # a = temp
    incl    %ecx 			 
    jmp     round_0_19 	


round_20_39:
	cmpl    $40, %ecx                # check if i >= 40
	jge     round_40_59              # jump to next round block
	
	# f = b ^ c ^ d
	movl    %r8d, %eax               # eax = a
	roll    $5, %eax                 # rol(a,5)
	movl    %r9d, %edx               # edx = b
	xorl    %r10d, %edx              # edx ^= c
	xorl    %r11d, %edx              # edx ^= d

	addl    %edx, %eax               # temp += f
	addl    %r12d, %eax              # temp += e
	addl    %r14d, %eax              # temp += k1
	addl    0(%rsi,%rcx,4), %eax     # temp += w[i]

	movl    %r11d, %r12d             # e = d
	movl    %r10d, %r11d             # d = c
	movl    %r9d, %edx               # edx = b
	roll    $30, %edx                # rol(b,30)
	movl    %edx, %r10d              # c = rol(b,30)
	movl    %r8d, %r9d               # b = a
	movl    %eax, %r8d               # a = temp

	incl    %ecx                     # increment i
	jmp     round_20_39              # repeat for next round


round_40_59:
	cmpl    $60, %ecx                # check if i >= 60
	jge     round_60_79              # jump to next round block

	# f = (b & c) | (d & (b | c))
	movl    %r9d, %edx               # edx = b
	andl    %r10d, %edx              # edx &= c
	movl    %r9d, %eax               # eax = b
	orl     %r10d, %eax              # eax |= c
	andl    %r11d, %eax              # eax &= d
	orl     %eax, %edx               # edx |= eax

	movl    %r8d, %eax               # eax = a
	roll    $5, %eax                 # rol(a,5)
	addl    %edx, %eax               # temp += f
	addl    %r12d, %eax              # temp += e
	addl    %r15d, %eax              # temp += k2
	addl    0(%rsi,%rcx,4), %eax     # temp += w[i]

	movl    %r11d, %r12d             # e = d
	movl    %r10d, %r11d             # d = c
	movl    %r9d, %edx               # edx = b
	roll    $30, %edx                 # rol(b,30)
	movl    %edx, %r10d              # c = rol(b,30)
	movl    %r8d, %r9d               # b = a
	movl    %eax, %r8d               # a = temp

	incl    %ecx                     # increment i
	jmp     round_40_59              # repeat for next round

round_60_79:
	cmpl    $80, %ecx                # check if i >= 80
	jge     finish                    # jump to finish block

	# f = b ^ c ^ d
	movl    %r8d, %eax               # eax = a
	roll    $5, %eax                 # rol(a,5)
	movl    %r9d, %edx               # edx = b
	xorl    %r10d, %edx              # edx ^= c
	xorl    %r11d, %edx              # edx ^= d

	addl    %edx, %eax               # temp += f
	addl    %r12d, %eax              # temp += e
	addl    %ebx, %eax               # temp += k3
	addl    0(%rsi,%rcx,4), %eax     # temp += w[i]

	movl    %r11d, %r12d             # e = d
	movl    %r10d, %r11d             # d = c
	movl    %r9d, %edx               # edx = b
	roll    $30, %edx                 # rol(b,30)
	movl    %edx, %r10d              # c = rol(b,30)
	movl    %r8d, %r9d               # b = a
	movl    %eax, %r8d               # a = temp

	incl    %ecx                     # increment i
	jmp     round_60_79              # repeat for next round


finish:
	addl    %r8d, 0(%rdi)            # h0 += a
	addl    %r9d, 4(%rdi)            # h1 += b
	addl    %r10d, 8(%rdi)           # h2 += c
	addl    %r11d, 12(%rdi)          # h3 += d
	addl    %r12d, 16(%rdi)          # h4 += e

	# epilogue
	popq    %r15
	popq    %r14
	popq    %r13
	popq    %r12
	popq    %rbx

	movq    %rbp, %rsp
	popq    %rbp

	ret

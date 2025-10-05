.global sha1_chunk

# void sha1_chunk(uint32_t *h_base, uint32_t *w)
# rdi = h_base (h0..h4), rsi = w (80 words; w[16..79] may be uninitialized)
sha1_chunk:
	# Prologue
	pushq	%rbp
	movq	%rsp, %rbp
	pushq	%rbx
	pushq	%r12
	pushq	%r13
	pushq	%r14
	pushq	%r15

	# Load initial hash state into a..e (r8d..r12d)
	movl	0(%rdi), %r8d    # a = h0
	movl	4(%rdi), %r9d    # b = h1
	movl	8(%rdi), %r10d   # c = h2
	movl	12(%rdi), %r11d  # d = h3
	movl	16(%rdi), %r12d  # e = h4

	# Expand message schedule w[16..79]
	movl	$16, %ecx
1:
	cmpl	$80, %ecx
	jge	2f
	movl	-12(%rsi,%rcx,4), %eax   # w[t-3]
	xorl	-32(%rsi,%rcx,4), %eax   # ^ w[t-8]
	xorl	-56(%rsi,%rcx,4), %eax   # ^ w[t-14]
	xorl	-64(%rsi,%rcx,4), %eax   # ^ w[t-16]
	roll	$1, %eax                  # rol1
	movl	%eax, 0(%rsi,%rcx,4)     # w[t]
	incl	%ecx
	jmp	1b
2:

	# Load constants
	movl	$0x5A827999, %r13d   # K0
	movl	$0x6ED9EBA1, %r14d   # K1
	movl	$0x8F1BBCDC, %r15d   # K2
	movl	$0xCA62C1D6, %ebx    # K3

	# t = 0
	xorl	%ecx, %ecx

	# Rounds 0..19
3:
	cmpl	$20, %ecx
	jge	4f
	# f = (b & c) | ((~b) & d) using eax/edx as scratch
	movl	%r9d, %edx          # edx = b
	movl	%r9d, %eax          # eax = b
	notl	%eax                # ~b
	andl	%r11d, %eax         # ~b & d
	andl	%r10d, %edx         # b & c
	orl	%eax, %edx           # f in edx
	# temp = rol(a,5) + f + e + K0 + w[t]
	movl	%r8d, %eax
	roll	$5, %eax
	addl	%edx, %eax
	addl	%r12d, %eax
	addl	%r13d, %eax
	addl	0(%rsi,%rcx,4), %eax
	movl	%r11d, %r12d
	movl	%r10d, %r11d
	movl	%r9d, %edx
	rorl	$2, %edx
	movl	%edx, %r10d
	movl	%r8d, %r9d
	movl	%eax, %r8d
	incl	%ecx
	jmp	3b
4:
	# Rounds 20..39
	cmpl	$40, %ecx
	jge	5f
	movl	%r8d, %eax
	roll	$5, %eax
	movl	%r9d, %edx
	xorl	%r10d, %edx
	xorl	%r11d, %edx
	addl	%edx, %eax
	addl	%r12d, %eax
	addl	%r14d, %eax
	addl	0(%rsi,%rcx,4), %eax
	movl	%r11d, %r12d
	movl	%r10d, %r11d
	movl	%r9d, %edx
	rorl	$2, %edx
	movl	%edx, %r10d
	movl	%r8d, %r9d
	movl	%eax, %r8d
	incl	%ecx
	jmp	4b
5:
	# Rounds 40..59
	cmpl	$60, %ecx
	jge	6f
	# f = Maj(b,c,d) = (b & c) | (d & (b | c)) using eax/edx
	movl	%r9d, %edx          # edx = b
	andl	%r10d, %edx         # edx = b & c
	movl	%r9d, %eax          # eax = b
	orl	%r10d, %eax          # eax = b | c
	andl	%r11d, %eax         # eax = d & (b | c)
	orl	%eax, %edx           # edx = f
	# temp = rol(a,5) + f + e + K2 + w[t]
	movl	%r8d, %eax
	roll	$5, %eax
	addl	%edx, %eax
	addl	%r12d, %eax
	addl	%r15d, %eax
	addl	0(%rsi,%rcx,4), %eax
	movl	%r11d, %r12d
	movl	%r10d, %r11d
	movl	%r9d, %edx
	rorl	$2, %edx
	movl	%edx, %r10d
	movl	%r8d, %r9d
	movl	%eax, %r8d
	incl	%ecx
	jmp	5b
6:
	# Rounds 60..79
	cmpl	$80, %ecx
	jge	7f
	movl	%r8d, %eax
	roll	$5, %eax
	movl	%r9d, %edx
	xorl	%r10d, %edx
	xorl	%r11d, %edx
	addl	%edx, %eax
	addl	%r12d, %eax
	addl	%ebx, %eax
	addl	0(%rsi,%rcx,4), %eax
	movl	%r11d, %r12d
	movl	%r10d, %r11d
	movl	%r9d, %edx
	rorl	$2, %edx
	movl	%edx, %r10d
	movl	%r8d, %r9d
	movl	%eax, %r8d
	incl	%ecx
	jmp	6b
7:
	# Add this chunk's hash to result
	addl	%r8d, 0(%rdi)
	addl	%r9d, 4(%rdi)
	addl	%r10d, 8(%rdi)
	addl	%r11d, 12(%rdi)
	addl	%r12d, 16(%rdi)

	# Epilogue
	popq	%r15
	popq	%r14
	popq	%r13
	popq	%r12
	popq	%rbx
	leave
	ret

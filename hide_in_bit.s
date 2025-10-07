.data
message: .ascii "The quick brown fox jumps over the lazy dog\0"
lead_pattern: .ascii "CCCCCCCCSSSSEE1111444400000000\0"
trail_pattern: .ascii "CCCCCCCCSSSSEE1111444400000000\0"
msg_encrypted: .ascii "Message encrypted and saved to Bitmap.bmp\n\0"
msg_decrypted: .ascii "Message decrypted: \0"
newline: .ascii "\n\0"
filename: .ascii "Bitmap.bmp\0"

bmp_header:
    .byte 0x42, 0x4D              # signature "BM"
    .long 3126                    # file size = 54 + 3072
    .short 0, 0                   # reserved
    .long 54                      # pixel data offset
    .long 40                      # DIB header size
    .long 32                      # width
    .long 32                      # height (positive => bottom-up)
    .short 1                      # planes
    .short 24                     # bits per pixel
    .long 0                       # compression (BI_RGB)
    .long 3072                    # image size (32x32x3) - no row padding needed
    .long 2835, 2835              # x/y pixels per meter
    .long 0, 0                    # color table info

.bss
    .lcomm full_message, 512      # lead + message + trail
    .lcomm rle_buffer, 1024        # RLE encoded data
    .lcomm barcode_key, 3072       # 32x32 pixels, 3 bytes each
    .lcomm encrypted_data, 3072    # encrypted image data
    .lcomm decrypted_buffer, 512   # RLE decoded data

.text
.globl main

main:
    pushq %rbp
    movq %rsp, %rbp

    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15

    movq $full_message, %rdi  # dest
    movq $lead_pattern, %rsi  # src
    call strcpy_custom # copy lead pattern

    movq $full_message, %rdi # dest
    call strlen       # get length of lead pattern
    movq $full_message, %rdi # dest
    addq %rax, %rdi # move dest pointer to end of lead
    movq $message, %rsi # src
    call strcpy_custom # copy message

    movq $full_message, %rdi # dest
    call strlen      # get length of lead + message
    movq $full_message, %rdi # dest
    addq %rax, %rdi # move dest pointer to end of lead + message
    movq $trail_pattern, %rsi # src
    call strcpy_custom # copy trail pattern

    # zero out rle_buffer
    movq $rle_buffer, %rdi
    movq $1024, %rsi
    call clear_buffer

    # RLE encode full_message to rle_buffer
    movq $full_message, %rdi    # pointer to full message
    movq $rle_buffer, %rsi      # pointer to RLE buffer
    call rle_encode
    movq %rax, %r12                      # RLE length

    movq $barcode_key, %rdi         # dest pointer
    movq $32, %r9                   # rows
barcode_row_loop:
    movq $0, %r10                   # column
barcode_col_loop:
    cmpq $31, %r10                  # last pixel in row?
    je barcode_add_red              # last pixel in row -> red (BGR: 00 00 FF)

    movq %r10, %rax         
    cmpq $8, %rax
    jb pixel_white          # 0..7  (8W)
    cmpq $16, %rax
    jb pixel_black          # 8..15 (8B)
    cmpq $20, %rax
    jb pixel_white          # 16..19 (4W)
    cmpq $24, %rax
    jb pixel_black          # 20..23 (4B)
    cmpq $26, %rax
    jb pixel_white          # 24..25 (2W)
    cmpq $29, %rax
    jb pixel_black          # 26..28 (3B)
    jmp pixel_white         # 29..30 (2W)

pixel_white:
    movb $255, (%rdi)        # B
    movb $255, 1(%rdi)       # G
    movb $255, 2(%rdi)       # R
    addq $3, %rdi
    jmp pixel_done

pixel_black:
    movb $0, (%rdi)          # B
    movb $0, 1(%rdi)         # G
    movb $0, 2(%rdi)         # R
    addq $3, %rdi
    jmp pixel_done

barcode_add_red:
    movb $0, (%rdi)          # B
    movb $0, 1(%rdi)         # G
    movb $255, 2(%rdi)       # R  
    addq $3, %rdi
    jmp barcode_row_done

pixel_done:
    inc %r10                 # next column
    jmp barcode_col_loop

barcode_row_done:
    dec %r9                  # next row
    jnz barcode_row_loop

    movq $barcode_key, %rsi     # source
    movq $encrypted_data, %rdi  # destination
    movq $3072, %rcx            # count
    movq $0, %rax               # counter
copy_loop:
    movb (%rsi), %al        # load byte from source
    movb %al, (%rdi)        # store byte to dest
    inc %rsi                # advance pointers
    inc %rdi
    dec %rcx                # decrement count
    jnz copy_loop           # continue until RCX == 0

    movq $rle_buffer, %rdi          # src  = RLE message
    movq $barcode_key, %rsi         # key  = barcode (unchanged)
    movq $encrypted_data, %rdx      # dest = encrypted image buffer (already a copy)
    movq %r12, %rcx                 # len  = RLE size
    call encrypt

    # open file for writing
    movq $2, %rax                # sys_open
    movq $filename, %rdi          
    movq $0101, %rsi             # O_CREAT | O_WRONLY
    movq $0644, %rdx             # perms
    syscall
    movq %rax, %r13              # file descriptor

    # write BMP header
    movq $1, %rax                # sys_write
    movq %r13, %rdi              # file descriptor
    movq $bmp_header, %rsi       # header pointer
    movq $54, %rdx               # header size
    syscall

    # write pixel data
    movq $1, %rax                # sys_write
    movq %r13, %rdi              # file descriptor
    movq $encrypted_data, %rsi   # data pointer
    movq $3072, %rdx             # data size
    syscall

    # close file
    movq $3, %rax
    movq %r13, %rdi
    syscall

    # print confirmation
    movq $msg_encrypted, %rdi
    call print_string

    # decrypt
    movq $encrypted_data, %rdi    # encrypted bytes (front r12 only used)
    movq $barcode_key, %rsi       # key
    movq $rle_buffer, %rdx        # output buffer for RLE decrypted
    movq %r12, %rcx               # length
    call decrypt

    # Zero out decrypted_buffer
    movq $decrypted_buffer, %rdi
    movq $512, %rsi
    call clear_buffer

    # decode RLE to decrypted_buffer
    movq $rle_buffer, %rdi        # RLE encoded decrypted data
    movq $decrypted_buffer, %rsi  # decode target
    call rle_decode
    movq %rax, %r15               # total decoded bytes (no null)

    # remove lead/trail
    movq $decrypted_buffer, %rdi  # start of full decoded string
    addq $30, %rdi                # skip lead
    movq %rdi, %r14               # r14 = start of real message
    movq %r15, %rax
    subq $60, %rax                # message length = total - 60
    movb $0, (%r14,%rax)          # null terminate after message

    # print decrypted message
    movq $msg_decrypted, %rdi
    call print_string

    # print actual message
    movq %r14, %rdi
    call print_string

    # print newline
    movq $1, %rax
    movq $1, %rdi
    movq $newline, %rsi
    movq $1, %rdx
    syscall

    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbx

    movq %rbp, %rsp
    popq %rbp

    # exit
    movq $60, %rax
    movq $0, %rdi
    syscall

# (src=rdi, dest=rsi)
rle_encode:

    push %rbp
    movq %rsp, %rbp

    movq $0, %rax
    movq $0, %rbx
    movb (%rdi), %bl        # first byte
    cmpb $0, %bl            # check for empty input
    je rle_enc_done
    movq %rsi, %r8         # save start of output buffer
rle_enc_loop:
    movb (%rdi), %al        # load byte
    cmpb $0, %al          # check for null terminator
    je rle_enc_done
    movb %al, %bl           # current byte
    movq $1, %rcx           # count = 1
rle_count_loop:
    inc %rdi                  # advance input pointer
    movb (%rdi), %al          # load next byte
    cmpb %al, %bl             # compare with current byte
    jne rle_write
    inc %rcx                  # increment count
    cmp $255, %rcx            # max count reached?
    jne rle_count_loop
rle_write:
    movb %bl, (%rsi)         # VALUE
    inc %rsi                 # advance output pointer
    movb %cl, (%rsi)         # COUNT
    inc %rsi                 # advance output pointer
    cmpb $0, %al             # check for null terminator
    jne rle_enc_loop
rle_enc_done:
    subq %r8, %rsi          # length = output - start
    movq %rsi, %rax

    movq %rbp, %rsp
    pop %rbp
    ret

# src=rdi, key=rsi, dest=rdx, len=rcx)
encrypt:
    push %rbp
    movq %rsp, %rbp
xor_loop:
    test %rcx, %rcx # check for zero length
    jz xor_done
    movb (%rdi), %al       # load byte
    xorb (%rsi), %al      # XOR with key byte
    movb %al, (%rdx)      # store result
    inc %rdi            # advance pointers
    inc %rsi            # advance key
    inc %rdx            # advance dest
    dec %rcx            # decrement length
    jmp xor_loop
xor_done:
    movq %rbp, %rsp
    pop %rbp
    ret

# (src=rdi, key=rsi, dest=rdx, len=rcx)
decrypt:
    jmp encrypt

# (src=rdi, dest=rsi)
rle_decode:

    push %rbp
    movq %rsp, %rbp

    movq %rsi, %r8           # save start of output buffer
rle_dec_loop:
    movb (%rdi), %al         # VALUE
    cmpb $0, %al             # check for null terminator
    je rle_dec_done 
    inc %rdi                 # advance pointer
    movb (%rdi), %cl         # COUNT
    cmpb $0, %cl             # check for zero COUNT
    je rle_dec_done
    inc %rdi                 # advance pointer
rle_dec_write:
    movb %al, (%rsi)         # write VALUE
    inc %rsi                 # advance pointer
    dec %cl                  # decrement COUNT
    jnz rle_dec_write
    jmp rle_dec_loop 
rle_dec_done:
    movb $0, (%rsi)          # null terminator
    subq %r8, %rsi           # length = output - start
    movq %rsi, %rax          # return length

    movq %rbp, %rsp
    pop %rbp
    ret

clear_buffer:
    push %rbp
    movq %rsp, %rbp
    movq $0, %rax

clear_loop:
    movb %al, (%rdi)     # write 0 into memory
    inc %rdi             # advance pointer
    dec %rsi             # decrease counter
    jnz clear_loop       # repeat until RCX == 0    

clear_buffer_done:
    movq %rbp, %rsp
    popq %rbp
    ret

strcpy_custom:
    push %rbp
    movq %rsp, %rbp
    push %rdi              # save dest

strcpy_loop:
    movb (%rsi), %al      # load byte from source
    movb %al, (%rdi)      # store byte to destination
    inc %rdi               
    inc %rsi
    cmpb $0, %al         # check for null terminator
    jne strcpy_loop
    pop %rdi

    movq %rbp, %rsp
    pop %rbp
    ret

strlen:
    push %rbp
    movq %rsp, %rbp
    movq $0, %rax
str_loop:
    cmpb $0, (%rdi, %rax) # Check for null terminator
    je str_done
    inc %rax          # Increment length counter
    jmp str_loop
str_done:
    movq %rbp, %rsp
    pop %rbp
    ret

print_string:
    push %rdi
    call strlen           # get length
    movq %rax, %rdx              # length in rdx
    pop %rsi                     # string pointer in rsi

    movq $1, %rax                # sys_write
    movq $1, %rdi                # stdout
    syscall
    ret

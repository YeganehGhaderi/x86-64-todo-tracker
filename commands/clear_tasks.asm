section .data
    clear_success_msg db "✅ All tasks cleared.", 0xA, 0

section .text
    global handle_clear

handle_clear:
    push    rax
    push    rdi
    push    r8

    mov     rdi, db_filename       
    call    createFile   
    cmp     rax, 0
    jle     .clear_end 

    mov     r8, rax             

    mov     rdi, r8                ; FD
    call    closeFile

    mov     rsi, clear_success_msg
    call    printString

.clear_end:
    pop     r8
    pop     rdi
    pop     rax
    ret
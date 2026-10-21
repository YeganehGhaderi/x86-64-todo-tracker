section .data
    add_success_msg db "✅ Task added.", 0xA, 0
    add_syntax_err  db '❌ Syntax error. Usage: ADD [!|*|.] "Description"', 0xA, 0

section .bss
    add_priority    resb 1     
    add_desc_buf    resb 256    
    add_buffer      resb 4096   
    add_id_str      resb 16     
    add_record_buf  resb 512    

section .text
    global handle_add

handle_add:
    push    rax
    push    rbx
    push    rcx
    push    rdx
    push    rdi
    push    rsi
    push    r8
    push    r9
    push    r10
    push    r12
    push    r15

    mov     byte [add_priority], '.'   
    mov     r12, 0                     ; length of Description

    mov     rsi, input_buffer
    add     rsi, 3

.add_skip_spaces_1:
    cmp     byte [rsi], ' '
    jne     .add_check_priority
    inc     rsi
    jmp     .add_skip_spaces_1

.add_check_priority:
    cmp     byte [rsi], '!'
    je      .add_is_high
    cmp     byte [rsi], '*'
    je      .add_is_med
    cmp     byte [rsi], '.'
    je      .add_is_low
    jmp     .add_check_quote          

.add_is_high:
    mov     byte [add_priority], '!'
    inc     rsi
    jmp     .add_skip_spaces_2
.add_is_med:
    mov     byte [add_priority], '*'
    inc     rsi
    jmp     .add_skip_spaces_2
.add_is_low:
    inc     rsi

.add_skip_spaces_2:
    cmp     byte [rsi], ' '
    jne     .add_check_quote
    inc     rsi
    jmp     .add_skip_spaces_2

.add_check_quote:
    cmp     byte [rsi], '"'
    jne     .add_syntax_error
    inc     rsi                        

    cmp     byte [rsi], '"'
    je      .add_syntax_error
 
    mov     rdi, add_desc_buf         
.add_copy_desc:
    mov     al, [rsi]
    cmp     al, 0                      
    je      .add_syntax_error
    cmp     al, '"'                    
    je      .add_desc_parsed
    mov     [rdi], al
    inc     rdi
    inc     rsi
    inc     r12                        
    jmp     .add_copy_desc

.add_desc_parsed:
    mov     byte [rdi], 0              
 
    mov     rdi, db_filename
    call    openFile
    cmp     rax, 0
    jle     .add_calc_id_empty         
    mov     r15, rax                   ; FD

    mov     rdi, r15
    mov     rsi, add_buffer
    mov     rdx, 4095
    call    readFile
    mov     r10, rax                   ; number of bytes actually read

    mov     rdi, r15
    call    closeFile

    cmp     r10, 0
    je      .add_calc_id_empty	    

    xor     r8, r8                     
    xor     r9, r9                     
    mov     rsi, add_buffer

.add_id_loop:
    mov     al, [rsi]
    cmp     al, 0
    je      .add_id_done
    cmp     al, '|'                    
    je      .add_pipe_found
    cmp     al, 0xA                    
    je      .add_newline
    
    cmp     al, '0'
    jl      .add_malformed_skip
    cmp     al, '9'
    jg      .add_malformed_skip

    ; current_id = current_id * 10 + digit
    imul    r8, 10
    sub     al, '0'
    movzx   rcx, al
    add     r8, rcx
    inc     rsi
    jmp     .add_id_loop

.add_pipe_found:
    cmp     r8, r9
    cmovg   r9, r8

.add_malformed_skip:
    inc     rsi
    cmp     byte [rsi], 0xA
    jne     .add_malformed_skip

.add_newline:
    xor     r8, r8                    
    inc     rsi
    jmp     .add_id_loop

.add_id_done:
    inc     r9                         
    jmp     .add_build_record

.add_calc_id_empty:
    mov     r9, 1                      

.add_build_record:
    mov     rax, r9                    
    lea     rdi, [add_id_str + 15]     ; Point to end of buffer
    mov     byte [rdi], 0              
    mov     rcx, 10

.add_int_to_str:
    dec     rdi
    xor     rdx, rdx
    div     rcx                        
    add     dl, '0'                    
    mov     byte [rdi], dl
    test    rax, rax
    jnz     .add_int_to_str

    mov     rsi, add_record_buf   
     
.add_copy_id:
    mov     al, [rdi]
    mov     byte [rsi], al
    inc     rdi
    inc     rsi
    cmp     al, 0
    jne     .add_copy_id
    dec     rsi                        

    mov     al, '|'
    mov     byte [rsi], al
    inc     rsi
    
    mov     al, 'P'
    mov     byte [rsi], al
    inc     rsi
    
    mov     al, '|'
    mov     byte [rsi], al
    inc     rsi

    mov     al, [add_priority]
    mov     byte [rsi], al
    inc     rsi

    mov     al, '|'
    mov     byte [rsi], al
    inc     rsi

    mov     rcx, r12                   ; Length of description
    cmp     rcx, 0
    je      .add_skip_desc_copy
    mov     rdi, add_desc_buf
.add_copy_desc_loop:
    mov     al, [rdi]
    mov     byte [rsi], al
    inc     rdi
    inc     rsi
    dec     rcx
    jnz     .add_copy_desc_loop

.add_skip_desc_copy:
    mov     byte [rsi], 0xA
    inc     rsi
    mov     byte [rsi], 0               

    mov     rdi, db_filename
    call    appendFile
    cmp     rax, 0
    jle     .add_syntax_error

    mov     r15, rax		; FD 

    mov     rdi, add_record_buf
    call    GetStrlen             ; output => rdx = lenght of add_record_buf    

    mov     rdi, r15                   
    mov     rsi, add_record_buf        
    call    writeFile

    mov     rdi, r15                   
    call    closeFile

    mov     rsi, add_success_msg
    call    printString
    jmp     .add_end

.add_syntax_error:
    mov     rsi, add_syntax_err
    call    printString

.add_end:
    pop     r15
    pop     r12
    pop     r10
    pop     r9
    pop     r8
    pop     rsi
    pop     rdi
    pop     rdx
    pop     rcx
    pop     rbx
    pop     rax
    ret
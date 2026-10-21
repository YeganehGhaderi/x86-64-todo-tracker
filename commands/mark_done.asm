section .data
    done_success_msg db "✅ Task marked done.", 0xA, 0
    done_syntax_err  db "❌ Syntax error. Usage: DONE <id>", 0xA, 0
    done_not_found   db "❌ Task ID not found.", 0xA, 0

section .bss
    done_id_str_buf   resb 16     
    done_read_buf     resb 4096   
    done_write_buf    resb 4096   
    done_line_id_buf  resb 16     

section .text
    global handle_done

handle_done:
    push    rax
    push    rbx
    push    rcx
    push    rdx
    push    rdi
    push    rsi
    push    r8
    push    r9
    push    r10
    push    r11
    push    r12
    push    r13
    push    r14
    push    r15

    mov     rsi, input_buffer
    add     rsi, 4                     

.done_skip_spaces:
    cmp     byte [rsi], ' '
    jne     .done_check_null
    inc     rsi
    jmp     .done_skip_spaces

.done_check_null:
    cmp     byte [rsi], 0
    je      .done_syntax_error

    mov     rdi, done_id_str_buf
.done_copy_id:
    mov     al, [rsi]
    cmp     al, ' '                    
    je      .done_id_parsed
    cmp     al, 0                     
    je      .done_id_parsed
    mov     [rdi], al
    inc     rdi
    inc     rsi
    jmp     .done_copy_id

.done_id_parsed:
    mov     byte [rdi], 0              

    mov     rdi, db_filename
    call    openFile
    cmp     rax, 0
    jle     .done_not_found           
    mov     r8, rax                   ; FD

    mov     rdi, r8
    mov     rsi, done_read_buf
    mov     rdx, 4095
    call    readFile
    mov     r10, rax                   

    mov     rdi, r8
    call    closeFile

    cmp     r10, 0
    je      .done_not_found            

    xor     r14, r14                   ; Found Flag 
    mov     r12, done_read_buf         
    mov     r13, done_write_buf        

.done_loop_lines:
    cmp     byte [r12], 0
    je      .done_processing_finished

    mov     rsi, r12
    mov     rdi, done_line_id_buf
.done_extract_id:
    mov     al, [rsi]
    cmp     al, '|'                    
    je      .done_id_extracted
    cmp     al, 0xA                    
    je      .done_id_extracted
    cmp     al, 0                      
    je      .done_id_extracted
    mov     [rdi], al
    inc     rdi
    inc     rsi
    jmp     .done_extract_id

.done_id_extracted:
    mov     byte [rdi], 0             

    mov     rdi, done_line_id_buf
    mov     rsi, done_id_str_buf
    call    strcmp
    mov     r15, rax                   

    cmp     r15, 0
    jne     .done_start_copy
    mov     r14, 1                    

.done_start_copy:
    mov     rsi, r12                   
    xor     rbx, rbx                   

.done_copy_char:
    mov     al, [rsi]
    cmp     al, 0xA                    
    je      .done_line_end
    cmp     al, 0                      
    je      .done_line_end

    cmp     r15, 0
    jne     .done_keep_orig
    cmp     rbx, 1
    jne     .done_keep_orig
    cmp     al, 'P'
    jne     .done_keep_orig
    mov     al, 'D'                  
    mov     r15, 1                     

.done_keep_orig:
    cmp     al, '|'
    jne     .done_not_pipe
    inc     rbx

.done_not_pipe:
    mov     [r13], al                 
    inc     r13
    inc     rsi
    jmp     .done_copy_char

.done_line_end:
    mov     byte [r13], 0xA            
    inc     r13
 
    cmp     byte [rsi], 0xA
    jne     .done_check_eof
    inc     rsi
.done_check_eof:
    cmp     byte [rsi], 0
    je      .done_processing_finished
    mov     r12, rsi                   
    jmp     .done_loop_lines

.done_processing_finished:
    cmp     r14, 0
    je      .done_not_found

    mov     rdi, db_filename
    call    createFile                 
    cmp     rax, 0
    jle     .done_not_found

    mov     r8, rax		; FD

    mov     rdx, r13
    sub     rdx, done_write_buf

    mov     rdi, r8
    mov     rsi, done_write_buf
    call    writeFile

    mov     rdi, r8
    call    closeFile

    mov     rsi, done_success_msg
    call    printString
    jmp     .done_end

.done_syntax_error:
    mov     rsi, done_syntax_err
    call    printString
    jmp     .done_end

.done_not_found:
    mov     rsi, done_not_found
    call    printString

.done_end:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     r11
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
section .data
    delete_success_msg db "✅ Task deleted.", 0xA, 0
    delete_syntax_err  db "❌ Syntax error. Usage: DELETE <id>", 0xA, 0
    delete_not_found   db "❌ Task ID not found.", 0xA, 0

section .bss
    delete_id_str_buf   resb 16    
    delete_read_buf     resb 4096   
    delete_write_buf    resb 4096  
    delete_line_id_buf  resb 16     

section .text
    global handle_delete

handle_delete:
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
    add     rsi, 6                     

.delete_skip_spaces:
    cmp     byte [rsi], ' '
    jne     .delete_check_null
    inc     rsi
    jmp     .delete_skip_spaces

.delete_check_null:
    cmp     byte [rsi], 0
    je      .delete_syntax_error

    mov     rdi, delete_id_str_buf
.delete_copy_id:
    mov     al, [rsi]
    cmp     al, ' '                    
    je      .delete_id_parsed
    cmp     al, 0                      
    je      .delete_id_parsed
    mov     [rdi], al
    inc     rdi
    inc     rsi
    jmp     .delete_copy_id

.delete_id_parsed:
    mov     byte [rdi], 0              

    mov     rdi, db_filename
    call    openFile
    cmp     rax, 0
    jle     .delete_not_found 
         
    mov     r8, rax                   ; FD

    mov     rdi, r8
    mov     rsi, delete_read_buf
    mov     rdx, 4095
    call    readFile
    mov     r10, rax                   

    mov     rdi, r8
    call    closeFile

    cmp     r10, 0
    je      .delete_not_found          

    xor     r14, r14                   ; Found Flag 
    mov     r12, delete_read_buf       
    mov     r13, delete_write_buf      

.delete_loop_lines:
    cmp     byte [r12], 0
    je      .delete_processing_finished

    mov     rsi, r12
    mov     rdi, delete_line_id_buf
.delete_extract_id:
    mov     al, [rsi]
    cmp     al, '|'                    
    je      .delete_id_extracted
    cmp     al, 0xA                    
    je      .delete_id_extracted
    cmp     al, 0                      
    je      .delete_id_extracted
    mov     [rdi], al
    inc     rdi
    inc     rsi
    jmp     .delete_extract_id

.delete_id_extracted:
    mov     byte [rdi], 0              

    mov     rdi, delete_line_id_buf
    mov     rsi, delete_id_str_buf
    call    strcmp
    cmp     rax, 0
    jne     .delete_keep_line          

    mov     r14, 1                     
    jmp     .delete_skip_to_next_line

.delete_keep_line:
    mov     rsi, r12
.delete_copy_char:
    mov     al, [rsi]
    cmp     al, 0xA                    ; End of line
    je      .delete_line_copied
    cmp     al, 0                      ; End of buffer
    je      .delete_line_copied
    
    mov     [r13], al                  
    inc     r13
    inc     rsi
    jmp     .delete_copy_char

.delete_line_copied:
    mov     byte [r13], 0xA          
    inc     r13

.delete_skip_to_next_line:
.delete_find_nl:
    cmp     byte [r12], 0xA
    je      .delete_advance_past_nl
    cmp     byte [r12], 0
    je      .delete_processing_finished 
    inc     r12
    jmp     .delete_find_nl

.delete_advance_past_nl:
    inc     r12                        
    jmp     .delete_loop_lines         

.delete_processing_finished:
    cmp     r14, 0
    je      .delete_not_found

    mov     rdi, db_filename
    call    createFile                 
    cmp     rax, 0
    jle     .delete_not_found

    mov     r8, rax

    mov     rdx, r13
    sub     rdx, delete_write_buf

    mov     rdi, r8
    mov     rsi, delete_write_buf
    call    writeFile

    mov     rdi, r8
    call    closeFile

    mov     rsi, delete_success_msg
    call    printString
    jmp     .delete_end

.delete_syntax_error:
    mov     rsi, delete_syntax_err
    call    printString
    jmp     .delete_end

.delete_not_found:
    mov     rsi, delete_not_found
    call    printString

.delete_end:
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
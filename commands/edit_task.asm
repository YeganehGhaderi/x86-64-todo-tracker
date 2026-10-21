section .data
    edit_success_msg db "✅ Task edited.", 0xA, 0
    edit_syntax_err  db '❌ Syntax error. Usage: EDIT <id> "New Description"', 0xA, 0
    edit_not_found   db "❌ Task ID not found.", 0xA, 0

section .bss
    edit_id_str_buf   resb 16     
    edit_new_desc_buf resb 256    
    edit_read_buf     resb 4096   
    edit_write_buf    resb 4096  
    edit_line_id_buf  resb 16    

section .text
    global handle_edit

handle_edit:
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

.edit_skip_spaces_1:
    cmp     byte [rsi], ' '
    jne     .edit_check_id_null
    inc     rsi
    jmp     .edit_skip_spaces_1

.edit_check_id_null:
    cmp     byte [rsi], 0
    je      .edit_syntax_error

    mov     rdi, edit_id_str_buf
.edit_copy_id:
    mov     al, [rsi]
    cmp     al, ' '
    je      .edit_id_parsed
    cmp     al, 0
    je      .edit_syntax_error         
    mov     [rdi], al
    inc     rdi
    inc     rsi
    jmp     .edit_copy_id

.edit_id_parsed:
    mov     byte [rdi], 0

.edit_skip_spaces_2:
    cmp     byte [rsi], ' '
    jne     .edit_check_quote
    inc     rsi
    jmp     .edit_skip_spaces_2

.edit_check_quote:
    cmp     byte [rsi], '"'
    jne      .edit_syntax_error
    inc     rsi                        

    cmp     byte [rsi], '"'
    je      .edit_syntax_error

    mov     rdi, edit_new_desc_buf
    mov     r10, 0                     
.edit_copy_desc:
    mov     al, [rsi]
    cmp     al, 0
    je      .edit_syntax_error        
    cmp     al, '"'
    je      .edit_desc_parsed
    mov     [rdi], al
    inc     rdi
    inc     rsi
    inc     r10
    jmp     .edit_copy_desc

.edit_desc_parsed:
    mov     byte [rdi], 0              

    mov     rdi, db_filename
    call    openFile
    cmp     rax, 0
    jle     .edit_not_found

    mov     r8, rax                   ; FD 

    mov     rdi, r8
    mov     rsi, edit_read_buf
    mov     rdx, 4095
    call    readFile
    mov     r10, rax                   

    mov     rdi, r8
    call    closeFile

    cmp     r10, 0
    je      .edit_not_found

    xor     r14, r14                   ; Found Flag 
    mov     r12, edit_read_buf        
    mov     r13, edit_write_buf        

.edit_loop_lines:
    cmp     byte [r12], 0
    je      .edit_processing_finished

    mov     rsi, r12
    mov     rdi, edit_line_id_buf
.edit_extract_id:
    mov     al, [rsi]
    cmp     al, '|'
    je      .edit_id_extracted
    cmp     al, 0xA
    je      .edit_id_extracted
    cmp     al, 0
    je      .edit_id_extracted
    mov     [rdi], al
    inc     rdi
    inc     rsi
    jmp     .edit_extract_id

.edit_id_extracted:
    mov     byte [rdi], 0

    mov     rdi, edit_line_id_buf
    mov     rsi, edit_id_str_buf
    call    strcmp
    mov     r15, rax                  

    cmp     r15, 0
    jne     .edit_copy_full_line       
    mov     r14, 1                     

    mov     rsi, r12
    xor     r8, r8                     

.edit_copy_prefix:
    mov     al, [rsi]
    cmp     al, 0xA                   
    je      .edit_prefix_done
    cmp     al, 0                      
    je      .edit_prefix_done

    mov     [r13], al                  
    inc     r13
    inc     rsi

    cmp     al, '|'
    jne     .edit_copy_prefix
    inc     r8                         
    cmp     r8, 3
    jne     .edit_copy_prefix

.edit_prefix_done:
    mov     rdi, edit_new_desc_buf

.edit_append_new_desc:
    mov     al, [rdi]
    cmp     al, 0
    je      .edit_finish_line
    mov     [r13], al
    inc     r13
    inc     rdi
    jmp     .edit_append_new_desc

.edit_finish_line:
    mov     byte [r13], 0xA            
    inc     r13

.edit_skip_old_rest:
    cmp     byte [rsi], 0xA
    je      .edit_skip_nl
    cmp     byte [rsi], 0
    je      .edit_processing_finished
    inc     rsi
    jmp     .edit_skip_old_rest

.edit_skip_nl:
    inc     rsi
    mov     r12, rsi                   
    jmp     .edit_loop_lines

.edit_copy_full_line:
    mov     rsi, r12
.edit_copy_char:
    mov     al, [rsi]
    cmp     al, 0xA
    je      .edit_full_line_end
    cmp     al, 0
    je      .edit_full_line_end
    mov     [r13], al
    inc     r13
    inc     rsi
    jmp     .edit_copy_char

.edit_full_line_end:
    mov     byte [r13], 0xA
    inc     r13
    
    cmp     byte [rsi], 0xA
    jne     .edit_check_eof2
    inc     rsi
.edit_check_eof2:
    cmp     byte [rsi], 0
    je      .edit_processing_finished
    mov     r12, rsi
    jmp     .edit_loop_lines

.edit_processing_finished:
    cmp     r14, 0
    je      .edit_not_found

    mov     rdi, db_filename
    call    createFile
    cmp     rax, 0
    jle     .edit_not_found

    mov     r8, rax

    mov     rdx, r13
    sub     rdx, edit_write_buf

    mov     rdi, r8
    mov     rsi, edit_write_buf
    call    writeFile

    mov     rdi, r8
    call    closeFile

    mov     rsi, edit_success_msg
    call    printString
    jmp     .edit_end

.edit_syntax_error:
    mov     rsi, edit_syntax_err
    call    printString
    jmp     .edit_end

.edit_not_found:
    mov     rsi, edit_not_found
    call    printString

.edit_end:
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
section .data
    archive_filename      db "data/archive.txt", 0
    archive_success_msg   db "✅ Completed tasks archived.", 0xA, 0
    archive_empty_msg     db "❌ No completed tasks to archive.", 0xA, 0

section .bss
    archive_read_buf      resb 4096   
    archive_write_buf     resb 4096   

section .text
    global handle_archive

handle_archive:
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

    mov     rdi, db_filename
    call    openFile
    cmp     rax, 0
    jle     .archive_no_tasks 
          
    mov     r8, rax                    ; the FD of ToDo file

    mov     rdi, r8
    mov     rsi, archive_read_buf
    mov     rdx, 4095
    call    readFile
    mov     r10, rax                    

    mov     rdi, r8
    call    closeFile

    cmp     r10, 0
    je      .archive_no_tasks           

    mov     rdi, archive_filename
    call    appendFile
    cmp     rax, 0
    jle     .archive_no_tasks           
    mov     r15, rax                    ; the FD of Archive file

    xor     r14, r14                   ; Found 'D' Flag
    mov     r12, archive_read_buf      
    mov     r13, archive_write_buf     

.archive_loop:
    cmp     byte [r12], 0
    je      .archive_processing_done

    ; Find Status Character 
    mov     rsi, r12
    xor     rbx, rbx                   
    xor     r8, r8                     
    
.archive_find_status:
    cmp     byte [rsi], 0xA
    je      .archive_status_done       
    cmp     byte [rsi], 0
    je      .archive_status_done      
    cmp     byte [rsi], '|'
    jne     .archive_not_pipe
    inc     rbx
    cmp     rbx, 1
    jne     .archive_not_pipe
    inc     rsi                        
    mov     r8b, byte [rsi]            ; Save status in r8b
    jmp     .archive_status_done

.archive_not_pipe:
    inc     rsi
    jmp     .archive_find_status

.archive_status_done:
    mov     rsi, r12
.archive_calc_len:
    cmp     byte [rsi], 0xA
    je      .archive_len_done
    cmp     byte [rsi], 0
    je      .archive_len_done
    inc     rsi
    jmp     .archive_calc_len

.archive_len_done:
    mov     rdx, rsi
    sub     rdx, r12                   ; length of line (without \n)

    cmp     r8b, 'D'
    jne     .archive_keep_line        

    mov     r14, 1                     ; Set found flag
    cmp     byte [rsi], 0xA            
    je      .archive_write_nl
    ; Ends with 0
    mov     rdi, r15
    mov     rsi, r12
    call    writeFile
    jmp     .archive_advance_cursor

.archive_write_nl:
    mov     rdi, r15
    mov     rsi, r12
    inc     rdx                        
    call    writeFile
    jmp     .archive_advance_cursor

.archive_keep_line:
    cmp     rdx, 0                     
    je      .archive_advance_cursor
    
    mov     rsi, r12
    mov     rdi, r13
    mov     rcx, rdx
    rep movsb                          

    mov     byte [rdi], 0xA            
    inc     rdi
    mov     r13, rdi                  

.archive_advance_cursor:
    add     r12, rdx                   
    cmp     byte [r12], 0xA            
    jne     .archive_check_eof
    inc     r12                        
.archive_check_eof:
    cmp     byte [r12], 0
    je      .archive_processing_done
    jmp     .archive_loop

.archive_processing_done:
    mov     rdi, r15
    call    closeFile

    cmp     r14, 0
    je      .archive_no_tasks          

    mov     rdi, db_filename
    call    createFile
    cmp     rax, 0
    jle     .archive_end

    mov     r8, rax

    mov     rdx, r13
    sub     rdx, archive_write_buf 

    mov     rdi, r8
    mov     rsi, archive_write_buf
    call    writeFile

    mov     rdi, r8
    call    closeFile

    mov     rsi, archive_success_msg
    call    printString
    jmp     .archive_end

.archive_no_tasks:
    mov     rsi, archive_empty_msg
    call    printString

.archive_end:
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
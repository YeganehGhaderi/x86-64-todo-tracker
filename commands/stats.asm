section .data
    stats_header      db "--- Task Statistics ---", 0xA, 0
    stats_total_str   db "Total Tasks: ", 0
    stats_done_str    db "Completed: ", 0
    stats_pend_str    db "Pending: ", 0
    stats_perc_str    db "Completion: ", 0
    stats_percent_s   db "%", 0xA, 0
    stats_newline     db 0xA, 0

section .bss
    stats_read_buf    resb 4096   
    stats_num_buf     resb 16    

section .text
    global handle_stats

handle_stats:
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

    xor     r8, r8                ; r8  = Total Tasks
    xor     r9, r9                ; r9  = Completed Tasks
    xor     r10, r10              ; r10 = Pending Tasks
    xor     r11, r11              ; r11 = Completion

    mov     rdi, db_filename
    call    openFile
    cmp     rax, 0
    jle     .stats_print_section  
    mov     r15, rax              ; FD

    mov     rdi, r15
    mov     rsi, stats_read_buf
    mov     rdx, 4095
    call    readFile

    mov     rdi, r15
    call    closeFile

    cmp     byte [stats_read_buf], 0  
    je      .stats_print_section 

    mov     r12, stats_read_buf   

.stats_loop:
    cmp     byte [r12], 0
    je      .stats_calc_percentage

    ; Skip empty lines 
    cmp     byte [r12], 0xA
    je      .stats_next_line

    inc     r8                    

    mov     rsi, r12
    xor     r13, r13              ; Pipe counter
    mov     r14, 0                ; char of Status 

.stats_find_status:
    cmp     byte [rsi], 0xA
    je      .stats_status_done
    cmp     byte [rsi], 0
    je      .stats_status_done
    
    cmp     byte [rsi], '|'
    jne     .stats_not_pipe_s
    inc     r13
    cmp     r13, 1
    jne     .stats_not_pipe_s
    
    inc     rsi
    mov     r14b, byte [rsi]      
    jmp     .stats_status_done

.stats_not_pipe_s:
    inc     rsi
    jmp     .stats_find_status

.stats_status_done:
    cmp     r14b, 'D'
    jne     .stats_check_pending
    inc     r9                    
    jmp     .stats_next_line

.stats_check_pending:
    cmp     r14b, 'P'
    jne     .stats_next_line
    inc     r10                   

.stats_next_line:
    cmp     byte [r12], 0xA
    je      .stats_skip_nl
    cmp     byte [r12], 0
    je      .stats_calc_percentage
    inc     r12
    jmp     .stats_next_line

.stats_skip_nl:
    inc     r12
    jmp     .stats_loop

.stats_calc_percentage:
    cmp     r8, 0                 
    je      .stats_print_section  

    mov     rax, r9              
    mov     rcx, 100
    mul     rcx                   
    xor     rdx, rdx              
    div     r8                    ; rax = (Completed * 100) / Total
    mov     r11, rax              

.stats_print_section:
    push    r11 

    mov     rsi, stats_header
    call    printString

    mov     rsi, stats_total_str
    call    printString
    mov     rax, r8
    call    .stats_print_int
    mov     rsi, stats_newline
    call    printString

    mov     rsi, stats_done_str
    call    printString
    mov     rax, r9
    call    .stats_print_int
    mov     rsi, stats_newline
    call    printString

    mov     rsi, stats_pend_str
    call    printString
    mov     rax, r10
    call    .stats_print_int
    mov     rsi, stats_newline
    call    printString

    mov     rsi, stats_perc_str
    call    printString

    pop     r11
    mov     rax, r11
    call    .stats_print_int
    mov     rsi, stats_percent_s
    call    printString

    jmp     .stats_end

.stats_print_int:
    push    rax
    push    rcx
    push    rdx
    push    rdi
    push    rsi

    lea     rdi, [stats_num_buf + 15]
    mov     byte [rdi], 0         
    mov     rcx, 10              

.stats_int_loop:
    dec     rdi                    
    xor     rdx, rdx              
    div     rcx                   
    add     dl, '0'               
    mov     [rdi], dl             
    test    rax, rax              
    jnz     .stats_int_loop      

    mov     rsi, rdi
    call    printString

    pop     rsi
    pop     rdi
    pop     rdx
    pop     rcx
    pop     rax
    ret

.stats_end:
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
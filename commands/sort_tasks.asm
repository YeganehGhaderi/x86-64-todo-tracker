section .data
    sort_success_msg  db "✅ Tasks sorted.", 0xA, 0
    sort_syntax_err   db "❌ Syntax error. Usage: SORT STATUS or SORT PRIORITY", 0xA, 0
    sort_empty_msg    db "❌ No tasks to sort.", 0xA, 0
    sort_kw_status    db "STATUS", 0
    sort_kw_priority  db "PRIORITY", 0

section .bss
    sort_arg_buf      resb 16     
    sort_read_buf     resb 4096   
    sort_write_buf    resb 4096   

section .text
    global handle_sort

handle_sort:
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

.sort_skip_spaces:
    cmp     byte [rsi], ' '
    jne     .sort_check_arg_null
    inc     rsi
    jmp     .sort_skip_spaces

.sort_check_arg_null:
    cmp     byte [rsi], 0
    je      .sort_syntax_error         

    mov     rdi, sort_arg_buf
.sort_copy_arg:
    mov     al, [rsi]
    cmp     al, ' '
    je      .sort_arg_parsed
    cmp     al, 0
    je      .sort_arg_parsed
    mov     [rdi], al
    inc     rdi
    inc     rsi
    jmp     .sort_copy_arg

.sort_arg_parsed:
    mov     byte [rdi], 0

    mov     rdi, sort_arg_buf
    mov     rsi, sort_kw_status
    call    strcmp
    cmp     rax, 0
    je      .sort_is_status

    mov     rdi, sort_arg_buf
    mov     rsi, sort_kw_priority
    call    strcmp
    cmp     rax, 0
    je      .sort_is_priority

    jmp     .sort_syntax_error         

.sort_is_status:
    mov     r14b, 1                    
    jmp     .sort_read_file

.sort_is_priority:
    mov     r14b, 2                   

.sort_read_file:
    mov     rdi, db_filename
    call    openFile
    cmp     rax, 0
    jle     .sort_empty

    mov     r9, rax

    mov     rdi, r9
    mov     rsi, sort_read_buf
    mov     rdx, 4095
    call    readFile
    mov     r10, rax

    mov     rdi, r9
    call    closeFile

    cmp     r10, 0
    je      .sort_empty

    mov     r12, sort_read_buf
    mov     r13, sort_write_buf

    cmp     r14b, 1
    jne     .sort_do_priority_passes

    mov     cl, 'P'
    call    .do_sort_pass             ; Pass 1: Copy 'P' lines
    mov     r12, sort_read_buf       
    mov     cl, 'D'
    call    .do_sort_pass             ; Pass 2: Copy 'D' lines
    jmp     .sort_do_malformed_pass

.sort_do_priority_passes:
    mov     cl, '!'
    call    .do_sort_pass             ; Pass 1: Copy '!' lines
    mov     r12, sort_read_buf
    mov     cl, '*'
    call    .do_sort_pass             ; Pass 2: Copy '*' lines
    mov     r12, sort_read_buf
    mov     cl, '.'
    call    .do_sort_pass             ; Pass 3: Copy '.' lines

.sort_do_malformed_pass:
    mov     r12, sort_read_buf
    call    .copy_malformed_pass      

    mov     rdi, db_filename
    call    createFile
    cmp     rax, 0
    jle     .sort_end

    mov     r8, rax

    mov     rdx, r13              
    sub     rdx, sort_write_buf

    mov     rdi, r8
    mov     rsi, sort_write_buf
    call    writeFile

    mov     rdi, r8
    call    closeFile

    mov     rsi, sort_success_msg
    call    printString
    jmp     .sort_end

.sort_empty:
    mov     rsi, sort_empty_msg
    call    printString
    jmp     .sort_end

.sort_syntax_error:
    mov     rsi, sort_syntax_err
    call    printString

.sort_end:
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


; =========================================================================
; SUBROUTINE: .do_sort_pass
; Inputs: cl = Target Character ('P', 'D', '!', '*', '.')
;         r14b = Target Pipe Number (1 for status, 2 for priority)
;         r12 = Start of read buffer
;         r13 = Current write pointer
; =========================================================================
.do_sort_pass:
    cmp     byte [r12], 0
    je      .sp_done

.sp_loop:
    cmp     byte [r12], 0
    je      .sp_done
    cmp     byte [r12], 0xA
    je      .sp_skip_empty

    mov     rsi, r12
    xor     rbx, rbx                ; pipe counter
    mov     r15b, 0                 ; valid flag (0 for malformed line)

.sp_find_char:
    cmp     byte [rsi], 0xA
    je      .sp_eol
    cmp     byte [rsi], 0
    je      .sp_eol
    
    cmp     byte [rsi], '|'
    jne     .sp_not_pipe
    inc     rbx
    cmp     rbx, r14                
    jne     .sp_not_pipe
    inc     rsi
    mov     r8b, byte [rsi]         
    mov     r15b, 1                 ; Mark as valid
    jmp     .sp_find_char

.sp_not_pipe:
    inc     rsi
    jmp     .sp_find_char

.sp_eol:
    mov     rdx, rsi
    sub     rdx, r12		; length of line

    cmp     r15b, 0
    je      .sp_no_match            
    cmp     r8b, cl
    jne     .sp_no_match            

    cmp     rdx, 0
    je      .sp_no_match

    push    rcx 
    mov     rsi, r12
    mov     rdi, r13
    mov     rcx, rdx
    rep movsb
    pop     rcx 
                      
    mov     byte [rdi], 0xA        
    inc     rdi
    mov     r13, rdi               

.sp_no_match:
    add     r12, rdx
    cmp     byte [r12], 0xA
    je      .sp_skip_nl
    cmp     byte [r12], 0
    jne     .sp_loop
    ret                            ; Reached end of file
.sp_skip_nl:
    inc     r12
    jmp     .sp_loop

.sp_skip_empty:
    inc     r12
    jmp     .sp_loop

.sp_done:
    ret

; =========================================================================
; SUBROUTINE: .copy_malformed_pass
; Copies any line that did not have valid structure.
; =========================================================================
.copy_malformed_pass:
    cmp     byte [r12], 0
    je      .mp_done

.mp_loop:
    cmp     byte [r12], 0
    je      .mp_done
    cmp     byte [r12], 0xA
    je      .mp_skip_empty

    mov     rsi, r12
    xor     rbx, rbx
    mov     r15b, 0

.mp_find_char:
    cmp     byte [rsi], 0xA
    je      .mp_eol
    cmp     byte [rsi], 0
    je      .mp_eol
    
    cmp     byte [rsi], '|'
    jne     .mp_not_pipe
    inc     rbx
    cmp     rbx, r14
    jne     .mp_not_pipe
    inc     rsi
    mov     r15b, 1                 
    jmp     .mp_find_char

.mp_not_pipe:
    inc     rsi
    jmp     .mp_find_char

.mp_eol:
    mov     rdx, rsi
    sub     rdx, r12		; length of line

    cmp     r15b, 0
    jne     .mp_no_match           

    cmp     rdx, 0
    je      .mp_no_match
    mov     rsi, r12
    mov     rdi, r13
    mov     rcx, rdx
    rep movsb
    mov     byte [rdi], 0xA
    inc     rdi
    mov     r13, rdi

.mp_no_match:
    add     r12, rdx
    cmp     byte [r12], 0xA
    je      .mp_skip_nl
    cmp     byte [r12], 0		; Reached end of line
    jne     .mp_loop
    ret
.mp_skip_nl:
    inc     r12
    jmp     .mp_loop

.mp_skip_empty:
    inc     r12
    jmp     .mp_loop

.mp_done:
    ret
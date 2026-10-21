section .data
    list_header     db "--- To-Do List ---", NL, 0
    list_empty_msg  db "❌ Empty list.", NL, 0
    pending_str     db "[ ] ", 0
    done_str        db "[X] ", 0
    colon_space     db ": ", 0

section .bss
    list_buffer     resb 4096

section .text
    global handle_list

handle_list:
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
    push    r13
    push    r14
    push    r15
 
    mov     rdi, db_filename        
    call    openFile
    cmp     rax, 0
    jle     .empty_list             
    mov     r12, rax                ; FD

    mov     rdi, r12                
    mov     rsi, list_buffer        
    mov     rdx, 4095              
    call    readFile
    mov     r13, rax                ; number of bytes read actually read

    mov     rdi, r12
    call    closeFile

    cmp     r13, 0
    je      .empty_list

    mov     r12, list_buffer
    xor     r15, r15                ; Flag (0 = No task printed yet) 

.parse_loop:
    cmp     byte [r12], 0
    je      .done_parsing

    xor     rbx, rbx                ; pipe count 
    xor     r14, r14                ; character index in the current line 
    mov     rdi, r12                

.find_pipes:
    mov     al, [rdi + r14]         
    cmp     al, 0xA                 
    je      .end_of_line_found
    cmp     al, 0                  
    je      .end_of_line_found
    
    cmp     al, '|'                 
    jne     .not_pipe

    cmp     rbx, 0
    je      .save_pipe1
    cmp     rbx, 1
    je      .save_pipe2
    cmp     rbx, 2
    je      .save_pipe3
    jmp     .not_pipe

.save_pipe1:
    mov     r8, r14                 
    inc     rbx
    jmp     .not_pipe
.save_pipe2:
    mov     r9, r14                 
    inc     rbx
    jmp     .not_pipe
.save_pipe3:
    mov     r10, r14                
    inc     rbx
    jmp     .not_pipe

.not_pipe:
    inc     r14                    
    jmp     .find_pipes

.end_of_line_found:
    cmp     r14, 0                  
    je      .skip_line
    cmp     rbx, 3
    jne     .skip_line              

    cmp     r15, 0
    jne     .skip_header_print
    mov     rsi, list_header
    call    printString
    mov     r15, 1    
              
.skip_header_print:
    lea     rax, [r12 + r8]
    inc     rax                     
    cmp     byte [rax], 'D'
    jne     .is_pending
    
    mov     rsi, done_str
    call    printString
    jmp     .print_id

.is_pending:
    mov     rsi, pending_str
    call    printString

.print_id: 
    mov     rax, 1                  
    mov     rdi, 1                  
    mov     rsi, r12                
    mov     rdx, r8                 
    syscall

    mov     rsi, colon_space
    call    printString

    lea     rsi, [r12 + r10]
    inc     rsi                     
    
    mov     rdx, r14                
    sub     rdx, r10
    dec     rdx                     

    mov     rax, 1                  
    mov     rdi, 1                  
    syscall

    call    newLine

.skip_line:
    add     r12, r14               
    cmp     byte [r12], 0xA         
    jne     .check_null
    inc     r12                     
    jmp     .parse_loop

.check_null:
    cmp     byte [r12], 0           
    je      .done_parsing
    jmp     .parse_loop

.empty_list:
    mov     rsi, list_empty_msg
    call    printString
    jmp     .end_list

.done_parsing:
    cmp     r15, 0
    jne     .end_list
    mov     rsi, list_empty_msg
    call    printString

.end_list:
    pop     r15
    pop     r14
    pop     r13
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
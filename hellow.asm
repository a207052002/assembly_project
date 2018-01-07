;Assembler: NASM (Netwide Assembler)
;OS: unix kernel x86_64 (4.14)
;Using ld to link (No PIC)
;CAN NOT BUILD IN WINDOWS
;
;King of NCU Fucking Words Server v1.00
;FUN :)


AF_INET       equ  2   ; IP family
SOCK_STREAM  equ  1   ; Pure string
IPPROTO_TCP  equ  6   ; TCP to IP

CHAT_PORT equ  9487
TALK_PORT equ  8787

%macro print_len 2
  mov rsi ,%1
  mov rbx, rsi
  mov rdx, %2
  mov rax, 1
  mov rdi, 0
  syscall
%endmacro

STRUC sockaddr_in
.sin_family: RESW 1
.sin_port: RESW 1
.sin_addr: RESD 1
.sin_zero: RESQ 1
ENDSTRUC

STRUC sockaddr_s
 .sin_family RESW 1
 .padding RESW 63
ENDSTRUC

%macro accept 1
  mov rax, 43
  mov rdi, %1
  mov rsi, client_addr
  mov rdx, client_addr_len
  mov qword [rdx], 128
  syscall
%endmacro


%macro fd_zero 1
  mov rsi, %1
  mov rcx, 120
  mov rdx, 0
  %%loop:
  cmp rdx, rcx
  jge %%end_loop
  mov qword [rsi+rdx], 0x0
  add rdx, 8
  jmp %%loop
  %%end_loop:
%endmacro

%macro fd_del 2
  mov rsi, %1
  mov rax, %2
  mov rdx, 0
  mov rbx, 1
  mov rdi, 64
  div rdi          ; rax now is quotient, rdx is remainder
  mov rcx, rdx
  mov rdi, 8
  mul rdi           ; rax is now offset
  shl rbx, cl
  xor qword [rsi+rax], rbx
%endmacro

%macro fd_set 2
  mov rsi, %1
  mov rax, %2
  mov rdx, 0
  mov rbx, 1
  mov rdi, 64
  div rdi          ; rax now is quotient, rdx is remainder
  mov rcx, rdx
  mov rdi, 8
  mul rdi           ; rax is now offset
  shl rbx, cl
  or qword [rsi+rax], rbx
%endmacro

%macro fd_isset 2  ;set, fd
  mov rsi, %1
  mov rax, %2
  mov rdx, 0
  mov rbx, 1
  mov rdi, 64
  div rdi        ; rax now is quotient, rdx is remainder
  mov rcx, rdx
  mov rdi, 8
  mul rdi           ; rax is now offset
  shl rbx, cl
  mov rax, [rsi+rax]
  and rax, rbx
%endmacro

%macro fd_or 2
  mov rsi, %1
  mov rdi, %2
  mov rdx, read_set
  mov rcx, 0
  %%loop_or:
    cmp rcx, [max_fd]
    ja %%loop_or_end
    mov rax, [rsi+rcx]
    or rax, [rdi+rcx]
    mov [read_set+rcx], rax
    add rcx, 8
    jmp %%loop_or
  %%loop_or_end:
%endmacro

%macro print 1
  mov rsi ,%1
  mov rbx, rsi
  xor rdx, rdx
  %%loop:
    cmp byte [rbx], 0x0
    je %%exit
    inc rdx
    inc rbx
    jmp %%loop
  %%exit:
    mov rax, 1
    mov rdi, 0
    syscall
%endmacro

;use kernel version up 4.14


global _start

section .text
_start:
;--------------------------------get fds for chat and talk------------------------
mov rbp, rsp
print sock_message
mov rax, 41
mov rdi, AF_INET
mov rsi, SOCK_STREAM
mov rdx, IPPROTO_TCP
syscall                  ;Getting listener fd

cmp rax, 0
jg sock_success_talk
print sock_failed
_exit:
mov rdi, -1
mov rax, 60
syscall

sock_chat:
print sock_message
mov rax, 41
mov rdi, AF_INET
mov rsi, SOCK_STREAM
mov rdx, IPPROTO_TCP
syscall                  ;Getting listener fd

cmp rax, 0
jg sock_success_chat
print sock_failed
je _exit


sock_success_talk:
mov [listener_talk], rax
mov rbx, 0x1
mov rcx, 0
loop_sock_talk:
  inc rcx
  cmp rcx, rax
  jg loop_sock_talk_end
  shl rbx, 1
  jmp loop_sock_talk
loop_sock_talk_end:
or [master_talk_set] , rbx
jmp sock_chat

sock_success_chat:
mov [listener_chat], rax
mov rbx, 0x1
mov rcx, 0
loop_sock_chat:
  inc rcx
  cmp rcx, rax
  jg loop_sock_chat_end
  shl rbx, 1
  jmp loop_sock_chat
loop_sock_chat_end:
or [master_chat_set], rbx
;---------------------------------bind port---------------------------------

finish_sock:
;start to bind talk
mov rdi, [listener_talk]
mov rax, 49
mov rsi, local_addr_talk
mov rdx, 16
syscall
cmp rax, 0
jge bind_talk_success
print bind_failed_talk
jmp _exit

;chat
bind_talk_success:
mov rdi, [listener_chat]
mov rax, 49
mov rsi, local_addr_chat
mov rdx, 16
syscall
cmp rax, 0
jge bind_success
print bind_failed_chat
jmp _exit



;---------------------------------------------------------------------

;start to listen
bind_success:

mov rax, [listener_chat]
mov [max_fd] ,rax

;start listen chat
print chat_listen_message
mov rax, 50
mov rdi, [listener_chat]
mov rsi, 10
syscall
cmp rax, -1
je _exit

;start listen talk
print talk_listen_message
mov rax, 50
mov rdi, [listener_talk]
mov rsi, 10
syscall
cmp rax, -1
je _exit

select_loop:
fd_zero read_set   ;clean set every single time
fd_or master_chat_set, master_talk_set  ;or to get all fd
select_loop_start:
print select_wait
mov rax, 23
mov rdi, [max_fd]
inc rdi
mov rsi, read_set
mov rdx, 0
mov r10, 0
mov r8 , 0
syscall                       ;select syscall
mov rcx, 0
mov [rbp-0x10], rcx
print new_fd
read_set_check_loop:          ;use rbp-0x10 for loop long
  mov rcx, [rbp-0x10]
  cmp rcx, [max_fd]
  ja select_loop_end
  fd_isset read_set, qword [rbp-0x10]
  test rax, rax
  jz read_set_check_loop_end
  fd_isset master_chat_set, qword [rbp-0x10]
  test rax, rax
  jnz _is_chat_fd
  _is_talk_fd:
    print talk_fd
    mov rcx, [rbp-0x10]
    cmp [listener_talk], rcx
    jne _not_talk_listener
    _is_talk_lisener:
      print new_talk_message
      _accepting_talk:
      accept qword [rbp-0x10]
      cmp rax, 0
      jge success_accept_talk
      print accept_failed
      jmp _exit
      success_accept_talk:
      cmp rax, [max_fd]
      jb _add_talk_set
      mov [max_fd], rax
      _add_talk_set:
      fd_set master_talk_set ,rax
      jmp read_set_check_loop_end
    _not_talk_listener:
      mov rax, 0
      mov rdi, [rbp-0x10]
      mov rsi, buffer
      mov rdx, 0x100
      syscall
      mov [send_len], rax
      cmp rax, 0
      jne _boardcast
      print close
      mov rax, 3
      mov rdi, [rbp-0x10]
      syscall                      ;closed, so close it
      fd_del master_talk_set, qword [rbp-0x10]
      jmp read_set_check_loop_end
      _boardcast:
      print buffer
      mov rcx, 0
      mov [rbp-0x20], rcx
      _board_loop:
        mov rcx, [rbp-0x20]
        cmp rcx, [max_fd]
        ja read_set_check_loop_end
        fd_isset master_chat_set, [rbp-0x20]
        test rax, rax
        jz _board_end_loop
        mov rcx, [rbp-0x20]
        cmp rcx, [listener_chat]
        je _board_end_loop
        mov rax, 1
        mov rdi, [rbp-0x20]
        mov rsi, buffer
        mov rdx, [send_len]
        syscall
      _board_end_loop:
        mov rcx, [rbp-0x20]
        inc rcx
        mov [rbp-0x20], rcx
        jmp _board_loop
  _is_chat_fd:
    print chat_fd
    mov rcx, [rbp-0x10]
    cmp rcx, [listener_chat]
    jne _not_chat_listener
    _is_chat_listener:
      print new_chat_message
      accept qword [rbp-0x10]
      cmp rax, [max_fd]
      jb _add_chat_set
      mov [max_fd], rax
      _add_chat_set:
      fd_set master_chat_set, rax
      jmp read_set_check_loop_end
    _not_chat_listener:          ;must be closed
      print close_chat
      fd_del master_chat_set, qword [rbp-0x10]
      mov rcx, [rbp-0x10]
      mov rax, 3
      mov rdi, rcx
      syscall
  read_set_check_loop_end:
  mov rcx, [rbp-0x10]
  inc rcx
  mov [rbp-0x10], rcx
  jmp read_set_check_loop
select_loop_end:
jmp select_loop

section .data
  sock_message: db "Start to build socket fd...", 0xa, 0
  bind_message: db "Binding port...", 0xa, 0
  talk_listen_message: db "Server is now on, start to listen talking port.", 0xa, 0
  chat_listen_message: db "Server is now on, start to listen chat port", 0xa, 0
  new_talk_message: db "new one talking connection...", 0xa, 0
  new_chat_message: db "new one chat connection...", 0xa, 0
  sock_failed: db "Socket getting failed.", 0xa, 0
  bind_failed_talk: db "Binding talk failed.", 0xa, 0
  bind_failed_chat: db "Binding chat failed,", 0xa, 0
  new_fd: db "There is a new fd change.", 0xa, 0
  talk_fd: db "There is new talking fd.", 0xa, 0
  chat_fd: db "there is new chat fd.", 0xa, 0
  debug: db "here, regconize me", 0xa, 0
  close: db "closed one talk fd.", 0xa, 0
  close_chat: db "closed one chat fd.", 0xa, 0
  master_chat_set: times 0x100 db 0
  master_talk_set: times 0x100 db 0
  master_set:      times 0x100 db 0
  accept_failed: db "accept failed", 0xa, 0
  read_set: times 0x100 db 0
  select_wait: db "now wait for selection.", 0xa, 0
  local_addr_talk: ISTRUC sockaddr_in
    AT sockaddr_in.sin_family, DW AF_INET
    AT sockaddr_in.sin_port, DB 0x22, 0x53
    AT sockaddr_in.sin_addr, DD 0x0
    AT sockaddr_in.sin_zero, DQ 0x0
  IEND
  local_addr_chat: ISTRUC sockaddr_in
    AT sockaddr_in.sin_family, DW AF_INET
    AT sockaddr_in.sin_port, DB 0x25, 0x0f
    AT sockaddr_in.sin_addr, DD 0x0
    AT sockaddr_in.sin_zero, DQ 0x0
  IEND
  client_addr: ISTRUC sockaddr_s
    AT sockaddr_s.sin_family, DW AF_INET
    AT sockaddr_s.padding, times 63 DB 0x0
  IEND
  client_addr_len: db 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
  buffer: times 0x100 db 0
  send_len: dq 0x0
  listener_talk: dq 0
  listener_chat: dq 0
  max_fd: dq 0

section .data
    ; Mensajes de error y información
    error_archivo      db 'Error: No se pudo abrir el archivo', 0Ah, 0
    error_lectura      db 'Error: No se pudo leer el archivo', 0Ah, 0
    exito_lectura      db 'Contenido del archivo:', 0Ah, 0
    nombre_inventario  db 'inventario.txt', 0
    nombre_config      db 'config.ini', 0
    newline            db 0Ah, 0
    
    ; Buffers para lectura
    buffer_inventario  times 256 db 0
    buffer_config      times 256 db 0

section .bss
    ; Descriptores de archivo
    fd_inventario resd 1
    fd_config     resd 1

section .text
    global _start

; ----------------------------------------------------------
; PUNTO DE ENTRADA PRINCIPAL
; ----------------------------------------------------------
_start:
    ; Leer y mostrar archivo de configuración
    mov esi, nombre_config
    mov edi, buffer_config
    mov edx, 256
    call leer_archivo
    call mostrar_contenido_config
    
    ; Leer y mostrar archivo de inventario
    mov esi, nombre_inventario
    mov edi, buffer_inventario
    mov edx, 256
    call leer_archivo
    call mostrar_contenido_inventario
    
    ; Salir del programa
    jmp salir

; ----------------------------------------------------------
; LEER ARCHIVO
; ----------------------------------------------------------
; Parámetros:
;   ESI = nombre del archivo
;   EDI = buffer para almacenar contenido
;   EDX = tamaño del buffer
; ----------------------------------------------------------
leer_archivo:
    pusha
    
    ; Abrir archivo (sys_open)
    mov eax, 5          ; sys_open
    mov ebx, esi        ; nombre del archivo
    mov ecx, 0          ; O_RDONLY (solo lectura)
    int 80h
    
    ; Verificar si se abrió correctamente
    cmp eax, 0
    jl error_apertura
    
    ; Guardar descriptor de archivo
    mov [fd_inventario], eax  ; Usamos la misma variable temporalmente
    
    ; Leer archivo (sys_read)
    mov eax, 3          ; sys_read
    mov ebx, [fd_inventario] ; descriptor
    mov ecx, edi        ; buffer
    mov edx, 256        ; bytes a leer
    int 80h
    
    ; Verificar lectura
    cmp eax, 0
    jl error_lectura_archivo
    
    ; Cerrar archivo (sys_close)
    mov eax, 6          ; sys_close
    mov ebx, [fd_inventario]
    int 80h
    
    popa
    ret

error_apertura:
    mov eax, 4          ; sys_write
    mov ebx, 1          ; stdout
    mov ecx, error_archivo
    mov edx, 33         ; longitud del mensaje
    int 80h
    jmp salir_error

error_lectura_archivo:
    mov eax, 4          ; sys_write
    mov ebx, 1          ; stdout
    mov ecx, error_lectura
    mov edx, 31         ; longitud del mensaje
    int 80h
    jmp salir_error

; ----------------------------------------------------------
; MOSTRAR CONTENIDO - CONFIG.INI
; ----------------------------------------------------------
mostrar_contenido_config:
    pusha
    
    ; Mostrar mensaje de encabezado
    mov eax, 4          ; sys_write
    mov ebx, 1          ; stdout
    mov ecx, exito_lectura
    mov edx, 23         ; longitud
    int 80h
    
    ; Mostrar nombre del archivo
    mov eax, 4
    mov ebx, 1
    mov ecx, nombre_config
    mov edx, 10         ; "config.ini" + null
    int 80h
    
    ; Nueva línea
    mov eax, 4
    mov ebx, 1
    mov ecx, newline
    mov edx, 1
    int 80h
    
    ; Mostrar contenido del buffer
    mov eax, 4
    mov ebx, 1
    mov ecx, buffer_config
    mov edx, 256
    int 80h
    
    ; Nueva línea adicional
    mov eax, 4
    mov ebx, 1
    mov ecx, newline
    mov edx, 1
    int 80h
    
    popa
    ret

; ----------------------------------------------------------
; MOSTRAR CONTENIDO - INVENTARIO.TXT
; ----------------------------------------------------------
mostrar_contenido_inventario:
    pusha
    
    ; Mostrar nombre del archivo
    mov eax, 4          ; sys_write
    mov ebx, 1          ; stdout
    mov ecx, nombre_inventario
    mov edx, 14         ; "inventario.txt" + null
    int 80h
    
    ; Nueva línea
    mov eax, 4
    mov ebx, 1
    mov ecx, newline
    mov edx, 1
    int 80h
    
    ; Mostrar contenido del buffer
    mov eax, 4
    mov ebx, 1
    mov ecx, buffer_inventario
    mov edx, 256
    int 80h
    
    ; Nueva línea adicional
    mov eax, 4
    mov ebx, 1
    mov ecx, newline
    mov edx, 1
    int 80h
    
    popa
    ret

; ----------------------------------------------------------
; SALIR DEL PROGRAMA
; ----------------------------------------------------------
salir:
    mov eax, 1          ; sys_exit
    mov ebx, 0          ; código de salida 0
    int 80h

salir_error:
    mov eax, 1          ; sys_exit
    mov ebx, 1          ; código de salida 1
    int 80h

section .data
    ; Mensajes de error del sistema
    error_archivo      db 'Error: No se pudo abrir el archivo', 0Ah, 0
    error_lectura      db 'Error: No se pudo leer el archivo', 0Ah, 0
    
    ; Nombres de archivos de configuración e inventario
    nombre_inventario  db 'inventario.txt', 0
    nombre_config      db 'config.ini', 0
    
    ; Buffers para almacenar contenido de archivos
    buffer_inventario  times 256 db 0
    buffer_config      times 256 db 0
    
    ; Variables de configuración con valores por defecto
    caracter_barra     db 0xE2, 0x96, 0x88, 0  ; Carácter █ en UTF-8
    color_barra        db '94'                 ; Color azul brillante
    color_fondo        db '40'                 ; Color fondo negro
    
    ; Constantes para formato de salida
    dos_puntos_espacio db ': ', 0
    espacio            db ' ', 0
    nueva_linea        db 0Ah, 0
    
    ; Secuencias de escape ANSI para colores
    secuencia_color_inicio times 16 db 0  ; Buffer para secuencia dinámica
    secuencia_color_len      dd 0         ; Longitud de la secuencia
    secuencia_reset         db 0x1B, '[0m', 0  ; Resetear formato
    reset_len               equ $ - secuencia_reset

section .bss
    ; Descriptores de archivo para operaciones I/O
    fd_inventario resd 1
    fd_config     resd 1
    
    ; Estructuras de datos para almacenar inventario
    items         resb 100   ; 10 items × 10 bytes cada uno
    cantidades    resb 10    ; Array de cantidades (1 byte por item)
    num_items     resb 1     ; Contador de items procesados
    
    ; Buffer auxiliar para conversiones numéricas
    buffer_numero resb 10

section .text
    global _start

; ==================== PROGRAMA PRINCIPAL ====================
_start:
    ; Cargar y procesar archivo de configuración
    mov esi, nombre_config      ; Puntero al nombre del archivo
    mov edi, buffer_config      ; Buffer destino para contenido
    mov edx, 256                ; Tamaño máximo de lectura
    call leer_archivo           ; Leer archivo config.ini
    
    call procesar_config_simple ; Interpretar configuración
    call reconstruir_secuencia_color ; Generar secuencias ANSI
    
    ; Cargar y procesar archivo de inventario
    mov esi, nombre_inventario  ; Puntero al nombre del archivo  
    mov edi, buffer_inventario  ; Buffer destino para contenido
    mov edx, 256                ; Tamaño máximo de lectura
    call leer_archivo           ; Leer archivo inventario.txt
    
    call procesar_inventario    ; Extraer items y cantidades
    call ordenar_items          ; Ordenar alfabéticamente
    call generar_grafico_corregido ; Mostrar visualización
    
    jmp salir                   ; Terminar programa normalmente

; ==================== LECTURA DE ARCHIVOS ====================
leer_archivo:
    pusha                       ; Preservar registros
    ; Abrir archivo (llamada al sistema 5 = sys_open)
    mov eax, 5                  ; Número de syscall para open
    mov ebx, esi                ; Nombre del archivo
    mov ecx, 0                  ; Modo solo lectura (O_RDONLY)
    int 80h                     ; Interrupción al kernel
    
    cmp eax, 0                  ; Verificar éxito de apertura
    jl error_apertura           ; Saltar a error si falló
    
    mov [fd_inventario], eax    ; Guardar descriptor de archivo
    
    ; Leer contenido del archivo (llamada al sistema 3 = sys_read)
    mov eax, 3                  ; Número de syscall para read
    mov ebx, [fd_inventario]    ; Descriptor de archivo
    mov ecx, edi                ; Buffer destino
    mov edx, 256                ; Bytes máximos a leer
    int 80h                     ; Interrupción al kernel
    
    cmp eax, 0                  ; Verificar éxito de lectura
    jl error_lectura_archivo    ; Saltar a error si falló
    
    ; Terminar cadena con null
    mov byte [edi + eax], 0     ; Añadir terminador nulo
    
    ; Cerrar archivo (llamada al sistema 6 = sys_close)
    mov eax, 6                  ; Número de syscall para close
    mov ebx, [fd_inventario]    ; Descriptor a cerrar
    int 80h                     ; Interrupción al kernel
    
    popa                        ; Restaurar registros
    ret                         ; Retornar al caller

; ==================== PROCESAMIENTO DE CONFIGURACIÓN ====================
procesar_config_simple:
    pusha
    mov esi, buffer_config      ; Iniciar en inicio del buffer

.procesar_linea:
    call saltar_espacios        ; Ignorar espacios iniciales
    cmp byte [esi], 0           ; Verificar fin de archivo
    je .fin_procesamiento       ; Terminar si es EOF
    
    ; Buscar clave "caracter_barra:"
    mov edi, .clave_caracter
    call comparar_cadena
    je .procesar_caracter
    
    ; Buscar clave "color_barra:"
    mov edi, .clave_color_barra
    call comparar_cadena
    je .procesar_color_barra
    
    ; Buscar clave "color_fondo:"
    mov edi, .clave_color_fondo
    call comparar_cadena
    je .procesar_color_fondo
    
    call saltar_linea           ; Saltar línea no reconocida
    jmp .procesar_linea         ; Continuar con siguiente línea

.procesar_caracter:
    add esi, 14                 ; Saltar "caracter_barra:"
    call saltar_espacios        ; Ignorar espacios después de ':'
    
    ; Verificar si hay valor definido
    cmp byte [esi], 0Ah         ; Salto de línea?
    je .siguiente_linea         ; Mantener valor por defecto
    cmp byte [esi], 0           ; Fin de archivo?
    je .siguiente_linea         ; Mantener valor por defecto
    
    ; Copiar carácter (puede ser ASCII o UTF-8)
    mov al, [esi]
    mov [caracter_barra], al    ; Copiar primer byte
    
    ; Detectar si es carácter UTF-8 (0xE2 indica inicio)
    cmp al, 0xE2
    jne .caracter_simple        ; Si no es UTF-8, tratar como ASCII
    
    ; Copiar los 3 bytes completos del UTF-8
    mov al, [esi+1]
    mov [caracter_barra+1], al
    mov al, [esi+2]
    mov [caracter_barra+2], al
    jmp .siguiente_linea

.caracter_simple:
    ; Para ASCII, asegurar que bytes extra sean cero
    mov byte [caracter_barra+1], 0
    mov byte [caracter_barra+2], 0
    jmp .siguiente_linea

.procesar_color_barra:
    add esi, 11                 ; Saltar "color_barra:"
    call saltar_espacios        ; Ignorar espacios
    ; Leer código de color de 2 dígitos
    mov al, [esi]
    mov [color_barra], al       ; Primer dígito
    inc esi
    mov al, [esi]
    mov [color_barra + 1], al   ; Segundo dígito
    jmp .siguiente_linea

.procesar_color_fondo:
    add esi, 12                 ; Saltar "color_fondo:"
    call saltar_espacios        ; Ignorar espacios
    ; Leer código de color de 2 dígitos
    mov al, [esi]
    mov [color_fondo], al       ; Primer dígito
    inc esi
    mov al, [esi]
    mov [color_fondo + 1], al   ; Segundo dígito
    jmp .siguiente_linea

.siguiente_linea:
    call saltar_linea           ; Avanzar a siguiente línea
    jmp .procesar_linea         ; Continuar procesamiento

.fin_procesamiento:
    popa
    ret

.clave_caracter      db 'caracter_barra:', 0
.clave_color_barra   db 'color_barra:', 0
.clave_color_fondo   db 'color_fondo:', 0

; ==================== CONSTRUCCIÓN DE SECUENCIAS ANSI ====================
reconstruir_secuencia_color:
    pusha
    mov edi, secuencia_color_inicio ; Buffer destino
    
    ; Construir secuencia: ESC[<fondo>;<texto>m
    mov byte [edi], 0x1B        ; Carácter escape
    mov byte [edi+1], '['       ; Corchete inicial
    
    ; Insertar código de color de fondo (2 dígitos)
    mov al, [color_fondo]
    mov [edi+2], al             ; Primer dígito fondo
    mov al, [color_fondo+1]
    mov [edi+3], al             ; Segundo dígito fondo
    
    mov byte [edi+4], ';'       ; Separador
    
    ; Insertar código de color de texto (2 dígitos)
    mov al, [color_barra]
    mov [edi+5], al             ; Primer dígito texto
    mov al, [color_barra+1]
    mov [edi+6], al             ; Segundo dígito texto
    
    mov byte [edi+7], 'm'       ; Terminador de secuencia
    mov byte [edi+8], 0         ; Null terminator
    
    mov dword [secuencia_color_len], 8 ; Longitud fija de 8 bytes
    popa
    ret

; ==================== CÁLCULO DE LONGITUD DE CADENA ====================
longitud_cadena:
    push edi
    xor eax, eax                ; Contador en cero
.contar:
    cmp byte [edi], 0           ; ¿Fin de cadena?
    je .fin
    inc eax                     ; Incrementar contador
    inc edi                     ; Siguiente carácter
    jmp .contar
.fin:
    pop edi
    ret

; ==================== PROCESAMIENTO DE INVENTARIO ====================
procesar_inventario:
    pusha
    mov esi, buffer_inventario  ; Buffer con contenido
    mov ebx, cantidades         ; Array de cantidades
    mov byte [num_items], 0     ; Inicializar contador

.procesar_linea:
    call saltar_espacios        ; Saltar espacios/tabs
    cmp byte [esi], 0           ; ¿Fin de archivo?
    je .fin_procesamiento

    ; Verificar límite máximo de items (10)
    movzx eax, byte [num_items]
    cmp eax, 10
    jae .fin_procesamiento      ; No procesar más de 10 items

    ; Calcular posición en array de items
    movzx eax, byte [num_items]
    imul eax, eax, 10           ; Cada item ocupa 10 bytes
    add eax, items              ; Dirección destino
    mov edi, eax                ; EDIS = destino para nombre

    ; Copiar nombre (máximo 9 caracteres + null)
    mov ecx, 9                  ; Contador de caracteres

.copiar_nombre:
    mov al, [esi]
    cmp al, ':'                 ; ¿Fin del nombre?
    je .nombre_terminado
    cmp al, 0                   ; ¿Fin de archivo?
    je .fin_procesamiento
    cmp al, 0Ah                 ; ¿Salto de línea?
    je .linea_invalida
    mov [edi], al               ; Copiar carácter
    inc esi
    inc edi
    dec ecx
    jnz .copiar_nombre          ; Continuar hasta 9 caracteres

    ; Si nombre excede 9 chars, saltar resto hasta ':'
.skip_rest_name:
    mov al, [esi]
    cmp al, ':'                 ; ¿Encontró separador?
    je .nombre_terminado
    cmp al, 0                   ; ¿Fin de archivo?
    je .fin_procesamiento
    inc esi
    jmp .skip_rest_name

.nombre_terminado:
    mov byte [edi], 0           ; Terminar string con null
    inc edi

    ; Rellenar con ceros hasta completar 10 bytes por slot
    movzx eax, byte [num_items]
    inc eax
    imul eax, eax, 10           ; Calcular fin del slot
    add eax, items
    mov edx, eax                ; EDX = dirección final

.pad_loop:
    cmp edi, edx                ; ¿Llegamos al final?
    je .after_padding
    mov byte [edi], 0           ; Rellenar con cero
    inc edi
    jmp .pad_loop

.after_padding:
    ; Procesar cantidad después del ':'
    cmp byte [esi], ':'         ; Verificar separador
    je .skip_colon
    jmp .linea_invalida         ; Formato inválido

.skip_colon:
    inc esi                     ; Saltar ':'
    call saltar_espacios        ; Ignorar espacios
    call convertir_a_numero     ; Convertir texto a número
    mov [ebx], al               ; Almacenar cantidad
    inc ebx                     ; Siguiente posición en array

    inc byte [num_items]        ; Incrementar contador de items
    jmp .siguiente_linea

.linea_invalida:
    call saltar_linea           ; Saltar línea mal formada
    jmp .procesar_linea

.siguiente_linea:
    call saltar_linea           ; Avanzar a siguiente línea
    jmp .procesar_linea

.fin_procesamiento:
    popa
    ret

; ==================== ORDENAMIENTO DE ITEMS ====================
ordenar_items:
    pusha
    movzx ecx, byte [num_items]
    dec ecx                     ; n-1 iteraciones para bubble sort
    jle .fin_ordenamiento       ; Si 0 o 1 items, no ordenar

.bucle_externo:
    mov esi, items              ; Primer item
    mov edi, cantidades         ; Primera cantidad
    mov edx, ecx                ; Contador interno

.bucle_interno:
    ; Comparar item actual con siguiente
    mov eax, esi
    add eax, 10                 ; Siguiente item
    call comparar_items         ; Comparar alfabéticamente
    
    jbe .no_intercambiar        ; Si están en orden, no intercambiar
    
    call intercambiar_items     ; Intercambiar si están desordenados

.no_intercambiar:
    add esi, 10                 ; Siguiente item
    inc edi                     ; Siguiente cantidad
    dec edx
    jnz .bucle_interno          ; Continuar comparaciones internas
    
    loop .bucle_externo         ; Siguiente iteración externa

.fin_ordenamiento:
    popa
    ret

; ==================== COMPARACIÓN DE ITEMS ====================
comparar_items:
    push esi
    push eax
    push ebx
.comparar_caracter:
    mov bl, [esi]               ; Carácter del primer item
    mov bh, [eax]               ; Carácter del segundo item
    cmp bl, bh
    jne .fin_comparacion        ; Diferentes → determinar orden
    test bl, bl                 ; ¿Ambos terminaron?
    jz .fin_comparacion         ; Son iguales
    inc esi                     ; Siguiente carácter item1
    inc eax                     ; Siguiente carácter item2
    jmp .comparar_caracter      ; Continuar comparación

.fin_comparacion:
    pop ebx
    pop eax
    pop esi
    ret

; ==================== INTERCAMBIO DE ITEMS ====================
intercambiar_items:
    pusha
    ; Intercambiar nombres (10 bytes)
    mov ecx, 10
.intercambiar_nombres:
    mov bl, [esi]               ; Carácter de item1
    mov bh, [eax]               ; Carácter de item2
    mov [esi], bh               ; item1 ← carácter de item2
    mov [eax], bl               ; item2 ← carácter de item1
    inc esi
    inc eax
    loop .intercambiar_nombres
    
    ; Intercambiar cantidades
    mov bl, [edi]               ; Cantidad de item1
    mov bh, [edi + 1]           ; Cantidad de item2
    mov [edi], bh               ; item1 ← cantidad de item2
    mov [edi + 1], bl           ; item2 ← cantidad de item1
    
    popa
    ret

; ==================== GENERACIÓN DE GRÁFICO ====================
generar_grafico_corregido:
    pusha
    mov esi, items              ; Nombres de items
    mov edi, cantidades         ; Array de cantidades
    movzx ecx, byte [num_items] ; Número de items
    
    test ecx, ecx               ; ¿Hay items para mostrar?
    jz .fin_grafico             ; No → terminar
    
.bucle_items:
    ; Preservar registros para bucle
    push esi
    push edi
    push ecx
    
    ; Imprimir nombre del item
    call imprimir_cadena        ; Imprimir nombre
    mov eax, 4                  ; sys_write
    mov ebx, 1                  ; stdout
    mov ecx, dos_puntos_espacio ; Separador ": "
    mov edx, 2                  ; Longitud fija
    int 80h
    
    ; Aplicar secuencia de color ANSI
    mov eax, 4                  ; sys_write
    mov ebx, 1                  ; stdout
    mov ecx, secuencia_color_inicio ; Secuencia de color
    mov edx, [secuencia_color_len]  ; Longitud calculada
    int 80h
    
    ; Restaurar contadores para barras
    pop ecx
    pop edi
    push edi
    push ecx
    
    ; Obtener cantidad para este item
    movzx ecx, byte [edi]
    test ecx, ecx               ; ¿Cantidad cero?
    jz .sin_barras              ; Saltar impresión de barras
    
.bucle_barras:
    push ecx                    ; Preservar contador
    ; Determinar si es carácter ASCII o UTF-8
    mov eax, 4                  ; sys_write
    mov ebx, 1                  ; stdout
    mov ecx, caracter_barra     ; Carácter a imprimir
    
    cmp byte [caracter_barra], 0xE2 ; ¿Es UTF-8?
    jne .caracter_ascii
    mov edx, 3                  ; 3 bytes para UTF-8
    jmp .imprimir_caracter

.caracter_ascii:
    mov edx, 1                  ; 1 byte para ASCII

.imprimir_caracter:
    int 80h                     ; Imprimir carácter de barra
    pop ecx                     ; Restaurar contador
    loop .bucle_barras          ; Repetir según cantidad

.sin_barras:
    ; Restablecer formato de color
    mov eax, 4                  ; sys_write
    mov ebx, 1                  ; stdout
    mov ecx, secuencia_reset    ; Secuencia reset ANSI
    mov edx, reset_len          ; Longitud fija
    int 80h
    
    ; Imprimir espacio separador
    mov eax, 4                  ; sys_write
    mov ebx, 1                  ; stdout
    mov ecx, espacio            ; Carácter espacio
    mov edx, 1                  ; Longitud 1
    int 80h
    
    ; Restaurar para procesar número
    pop ecx
    pop edi
    pop esi
    push esi
    push edi
    push ecx
    
    ; Convertir cantidad a string e imprimir
    movzx eax, byte [edi]       ; Cargar cantidad
    mov edi, buffer_numero      ; Buffer destino
    call convertir_numero_a_string ; Convertir a ASCII
    
    ; Calcular longitud del número
    mov edi, buffer_numero
    call longitud_cadena        ; EAIS = longitud
    mov edx, eax                ; EDIS = longitud para syscall
    
    mov eax, 4                  ; sys_write
    mov ebx, 1                  ; stdout
    mov ecx, buffer_numero      ; Número en ASCII
    int 80h
    
    ; Nueva línea después de cada item
    mov eax, 4                  ; sys_write
    mov ebx, 1                  ; stdout
    mov ecx, nueva_linea        ; Carácter nueva línea
    mov edx, 1                  ; Longitud 1
    int 80h
    
    ; Preparar siguiente iteración
    pop ecx
    pop edi
    pop esi
    add esi, 10                 ; Siguiente nombre (10 bytes)
    inc edi                     ; Siguiente cantidad
    dec ecx                     ; Decrementar contador
    jnz .bucle_items            ; Continuar si quedan items

.fin_grafico:
    popa
    ret

; ==================== IMPRESIÓN DE CADENAS ====================
imprimir_cadena:
    pusha
    mov edi, esi                ; Copiar puntero para contar
    xor ecx, ecx                ; Contador en cero

.contar_longitud:
    cmp byte [edi], 0           ; ¿Fin de cadena?
    je .imprimir
    inc ecx                     ; Incrementar contador
    inc edi                     ; Siguiente carácter
    jmp .contar_longitud

.imprimir:
    test ecx, ecx               ; ¿Cadena vacía?
    jz .fin_imprimir
    
    mov eax, 4                  ; sys_write
    mov ebx, 1                  ; stdout
    mov edx, ecx                ; Longitud calculada
    mov ecx, esi                ; Cadena a imprimir
    int 80h

.fin_imprimir:
    popa
    ret

; ==================== CONVERSIÓN NÚMERO A STRING ====================
convertir_numero_a_string:
    pusha
    mov ebx, 10                 ; Base decimal
    mov ecx, 0                  ; Contador de dígitos
    test eax, eax               ; ¿Número cero?
    jnz .convertir_digitos
    
    ; Caso especial: número cero
    mov byte [edi], '0'         ; Escribir '0'
    mov byte [edi + 1], 0       ; Terminar string
    jmp .fin_conversion

.convertir_digitos:
    xor edx, edx                ; Limpiar EDX para división
    div ebx                     ; EAIS / 10, residuo en EDX
    add dl, '0'                 ; Convertir a ASCII
    push edx                    ; Guardar dígito en pila
    inc ecx                     ; Contar dígito
    test eax, eax               ; ¿Cociente cero?
    jnz .convertir_digitos      ; Continuar si no es cero
    
    ; Extraer dígitos de la pila (orden inverso)
    mov esi, edi                ; Puntero destino
.extraer_digitos:
    pop eax                     ; Recuperar dígito
    mov [edi], al               ; Almacenar en buffer
    inc edi                     ; Siguiente posición
    loop .extraer_digitos       ; Repetir para todos los dígitos
    
    mov byte [edi], 0           ; Terminar string con null

.fin_conversion:
    popa
    ret

; ==================== FUNCIONES AUXILIARES ====================

; Saltar espacios, tabs y saltos de línea
saltar_espacios:
    cmp byte [esi], ' '         ; ¿Espacio?
    je .saltar
    cmp byte [esi], 0Ah         ; ¿Salto de línea?
    je .saltar
    cmp byte [esi], 0Dh         ; ¿Retorno de carro?
    je .saltar
    cmp byte [esi], 9           ; ¿Tab?
    je .saltar
    ret                         ; No es espacio → retornar
.saltar:
    inc esi                     ; Siguiente carácter
    jmp saltar_espacios         ; Continuar saltando

; Avanzar hasta siguiente línea
saltar_linea:
    cmp byte [esi], 0Ah         ; ¿Encontró newline?
    je .encontro_newline
    cmp byte [esi], 0           ; ¿Fin de archivo?
    je .fin
    inc esi                     ; Siguiente carácter
    jmp saltar_linea
.encontro_newline:
    inc esi                     ; Saltar el newline
.fin:
    ret

; Comparar dos cadenas (ESI vs EDI)
comparar_cadena:
    pusha
.comparar:
    mov al, [esi]               ; Carácter de cadena1
    mov bl, [edi]               ; Carácter de cadena2
    cmp al, bl                  ; ¿Son iguales?
    jne .diferentes             ; No → cadenas diferentes
    test al, al                 ; ¿Ambos terminaron?
    jz .iguales                 ; Sí → cadenas iguales
    inc esi                     ; Siguiente carácter cadena1
    inc edi                     ; Siguiente carácter cadena2
    jmp .comparar               ; Continuar comparación
.iguales:
    popa
    cmp eax, eax                ; Set ZF=1 (iguales)
    ret
.diferentes:
    popa
    or eax, 1                   ; Clear ZF (diferentes)
    ret

; Convertir string a número (ESI → EAIS)
convertir_a_numero:
    push ebx
    xor eax, eax                ; Acumulador en cero
    xor ebx, ebx                ; Limpiar EBX
.convertir:
    mov bl, [esi]               ; Cargar carácter
    cmp bl, '0'                 ; ¿Es dígito?
    jb .fin_conversion          ; No → terminar
    cmp bl, '9'                 ; ¿Es dígito?
    ja .fin_conversion          ; No → terminar
    sub bl, '0'                 ; Convertir ASCII a número
    imul eax, 10                ; Multiplicar acumulador ×10
    add eax, ebx                ; Sumar nuevo dígito
    inc esi                     ; Siguiente carácter
    jmp .convertir              ; Continuar conversión
.fin_conversion:
    pop ebx
    ret

; ==================== MANEJO DE ERRORES ====================
error_apertura:
    mov eax, 4                  ; sys_write
    mov ebx, 1                  ; stdout
    mov ecx, error_archivo      ; Mensaje de error
    mov edx, 33                 ; Longitud del mensaje
    int 80h
    jmp salir_error             ; Salir con error

error_lectura_archivo:
    mov eax, 4                  ; sys_write
    mov ebx, 1                  ; stdout
    mov ecx, error_lectura      ; Mensaje de error
    mov edx, 31                 ; Longitud del mensaje
    int 80h
    jmp salir_error             ; Salir con error

; ==================== SALIDA DEL PROGRAMA ====================
salir:
    mov eax, 1                  ; sys_exit
    mov ebx, 0                  ; Código de éxito
    int 80h

salir_error:
    mov eax, 1                  ; sys_exit
    mov ebx, 1                  ; Código de error
    int 80h

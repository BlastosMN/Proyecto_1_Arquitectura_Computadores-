# Arquitectura de computadores - Proyecto 1: Visualizador de Datos con Ordenamiento para Linux 
abstract: |
  Este documento presenta el informe técnico de un código desarrollado
  en Assembly x86 para la visualización gráfica de inventarios usando
  NASM. El sistema procesa archivos de configuración y datos de
  inventario, implementando algoritmos de ordenamiento y genera una
  representación visual en forma de gráfico de barras.
author:
- Esteban Medina Navarro - 2018163918
date: 22 de setiembre 2025
title: |
  Arquitectura de computadores\
  Proyecto 1: Visualizador de Datos con Ordenamiento para Linux


# Introducción

El proyecto tiene como finalidad desarrollar un sistema de visualización
de datos de inventario que utilice información textual que se encuentra
en los archivos de texto para crear representaciones gráficas
directamente en la terminal de Linux. Implementado completamente en
lenguaje Assembly x86, esta solución aprovecha las capacidades de bajo
nivel del procesador para realizar operaciones de entrada/salida,
procesamiento de cadenas de texto y manipulación directa de memoria,
demostrando que incluso lenguajes considerados de bajo nivel pueden ser
empleados para crear aplicaciones con interfaz visual efectiva.

El código lee archivos de inventario en formato texto, procesa la
información contenida en ellos, organiza los elementos de manera
alfabética mediante un algoritmo de ordenamiento, y finalmente presenta
los datos mediante un gráfico de barras que utiliza caracteres de la
consola para representar visualmente las cantidades. Entre sus
características más relevantes se encuentra el manejo robusto de errores
durante las operaciones de archivo y la generación de visualizaciones
que pueden ser modificadas mediante un archivo de configuración, ya sea
cambiar el caracter que conforma el gráfico o cambiar los colores.

# Estructura del programa

## Estructura General del Programa

El sistema sigue una un flujo para resolver el problema el cual a
grandes rasgos es el siguiente:

1.  **Inicialización**: El programa define y reserva toda la memoria
    estática que utilizará durante su ejecución. En la sección `.data`
    se inicializan los mensajes de error, nombres de archivos, buffers
    de lectura, valores de configuración por defecto y constantes de
    formato.

2.  **Lectura de archivos**: El programa abre y lee secuencialmente los
    archivos `config.ini` y `inventario.txt` utilizando llamadas al
    sistema `sys_open` y `sys_read`. Los contenidos se almacenan en
    buffers de 256 bytes.

3.  **Procesamiento de los datos leídos**: Se parsea el contenido de
    `inventario.txt` línea por línea, extrayendo los nombres de los
    items y sus cantidades.

4.  **Ordenamiento de los datos leídos**: Se implementa el algoritmo
    Bubble Sort para ordenar alfabéticamente los items. El algoritmo
    compara los nombres carácter por carácter y realiza intercambios
    tanto en el array de nombres como en el array paralelo de
    cantidades, manteniendo la correspondencia entre ambos.

5.  **Generación del gráfico**: Para cada item ordenado, se genera una
    línea de output que incluye: el nombre del item, separador \": \",
    la secuencia ANSI de color, la barra gráfica (repitiendo el carácter
    configurado según la cantidad), reset de colores, espacio y el valor
    numérico de la cantidad.

6.  **Salida del programa**: Después de mostrar todos los items del
    inventario en formato gráfico, el programa realiza una terminación
    controlada mediante la llamada al sistema `sys_exit` con código de
    retorno 0. En caso de errores de E/S, muestra el mensaje de error
    correspondiente y termina con código de error 1.

## Diagrama de Flujo del Programa

<img width="2420" height="761" alt="Blank diagram" src="https://github.com/user-attachments/assets/c6b8cda5-de58-4ad2-a96e-b86422b37a66" />


# Implementación de las funciones

## Algoritmo de Ordenamiento: Bubble Sort

El sistema implementa el algoritmo Bubble Sort para ordenar los items
del inventario alfabéticamente.

### Descripción del Algoritmo

    Para i desde 0 hasta n-2:
        Para j desde 0 hasta n-i-2:
            Si items[j] > items[j+1]:
                Intercambiar(items[j], items[j+1])
                Intercambiar(cantidades[j], cantidades[j+1])

### Implementación en Assembly

``` {.[x86masm]Assembler language="[x86masm]Assembler"}
ordenar_items:
    movzx ecx, byte [num_items]
    dec ecx                     ; n-1 iteraciones
    jle .fin_ordenamiento
    
.bucle_externo:
    mov esi, items              ; Primer item
    mov edi, cantidades         ; Primera cantidad
    mov edx, ecx                ; Contador interno
    
.bucle_interno:
    mov eax, esi
    add eax, 10                 ; Siguiente item
    call comparar_items         ; Comparar strings
    jbe .no_intercambiar
    call intercambiar_items     ; Intercambiar si es necesario
.no_intercambiar:
    add esi, 10                 ; Avanzar al siguiente item
    inc edi
    dec edx
    jnz .bucle_interno
    loop .bucle_externo
```

## Visualización Gráfica

El código genera barras utilizando la configuración que está dada en el
archivo `config.ini`.

### Proceso de generación de las barras

1.  Imprimir nombre del item y separador \": \"

2.  Aplicar secuencia de color ANSI

3.  Repetir el carácter de barra según la cantidad de items

4.  Restablecer colores con secuencia de reset

5.  Mostrar valor numérico de la cantidad de items

# Estructuras de Datos

## Organización de Memoria

### Sección .data - Datos Inicializados

``` {.[x86masm]Assembler language="[x86masm]Assembler"}
section .data
    items         resb 100   ; 10 items × 10 bytes cada uno
    cantidades    resb 10    ; Array de cantidades
    num_items     resb 1     ; Contador de items
```

### Valores por Defecto para Configuración

``` {.[x86masm]Assembler language="[x86masm]Assembler"}
caracter_barra     db 0xE2, 0x96, 0x88, 0  ; barra negra por defecto
color_barra        db '94'                 ; Azul brillante por defecto
color_fondo        db '40'                 ; Negro por defecto
```

## Formato de Almacenamiento de Items

Cada item se almacena en una estructura de 10 bytes:

    [Nombre: 9 bytes][Null: 1 byte]

Ejemplo: \"Manzanas\" se almacena como:

    'M''a''n''z''a''n''a''s''\0''\0'

# Manejo de Archivos

## Formato del Archivo de Inventario (inventario.txt)

    manzanas:12
    peras:8
    naranjas:25
    kiwis:5

## Procesamiento de Archivos

El sistema implementa un parser robusto que maneja:

-   Espacios y tabs como separadores

-   Saltos de línea

-   Validación de formatos numéricos

-   Y tiene un límite máximo de 10 items

# Llamadas al Sistema Utilizadas

   **Código**   **Nombre**  **Propósito**
  ------------ ------------ -----------------------------
       5         sys_open   Abrir archivos
       3         sys_read   Leer datos de archivos
       6        sys_close   Cerrar archivos
       4        sys_write   Escribir en salida estándar
       1         sys_exit   Terminar programa

  : Llamadas al sistema utilizadas

# Manejo de Errores

-   Error de apertura de archivo

-   Error de lectura de archivo

-   Formato inválido en archivos de entrada

-   Límite de items excedido (máximo 10)

# Pruebas y Validación

El resultado obtenido del código implementado para el siguiente archivo
de `inventario.txt` se encuentra en la Figura
[2](#results){reference-type="ref" reference="results"}.

## Resultados de Pruebas

    Entrada (inventario.txt):
    manzanas:12
    peras:8
    naranjas:25
    kiwis:5

<img width="368" height="90" alt="results" src="https://github.com/user-attachments/assets/db2ebea0-8da6-4811-92f5-c4781fd28cf0" />


En este resultado se observa que el programa logra ordenar
alfabéticamente los items, grafica la cantidad y lo hace con los colores
y caracteres dados. En la Figura [3](#results2){reference-type="ref"
reference="results2"} se encuentra otra prueba con la siguiente
configuración y inventario.

    caracter_barra:*
    color_barra:92
    color_fondo:41

    Entrada (inventario.txt):
    manzanas:12
    peras:8
    naranjas:25
    kiwis:5
    mangos:3
    fresas:30
    arandanos: 10

<img width="389" height="152" alt="results2" src="https://github.com/user-attachments/assets/980ba182-9f87-45d3-8de8-e63775d9aab9" />


# Conclusiones

# Problema Identificado y Análisis

-   **Problema Principal**: El sistema no utiliza los valores del
    archivo config.ini

-   Los parámetros de visualización están predeterminados en el código

-   No se implementó completamente el parser de config.ini

## Problema Crítico: No Uso de config.ini

El sistema actual lee el archivo config.ini pero no utiliza sus valores
para configurar la visualización. En su lugar, utiliza valores
predeterminados:

``` {.[x86masm]Assembler language="[x86masm]Assembler"}
; VALORES POR DEFECTO (se usan estos en lugar de los de config.ini)
caracter_barra     db 0xE2, 0x96, 0x88, 0  ; barra negra por defecto
color_barra        db '94'                 ; Azul brillante
color_fondo        db '40'                 ; Negro
```

### Impacto

-   El programa ignora completamente las configuraciones de color del
    usuario

-   No se puede personalizar el carácter ni los colores de la barra sin
    cambiar y volver a compilar el código.

-   La salida siempre será idéntica independientemente de config.ini

### Solución Propuesta

Para corregir este issue, se necesitaría:

1.  Modificar la función de procesamiento de configuración para que
    actualice las variables globales

2.  Asegurar que los valores leídos se almacenen en las variables
    correctas

3.  Validar que la secuencia ANSI se reconstruya usando los valores del
    archivo

# Anexos

## Código Fuente

El código fuente completo se encuentra en el archivo `proyecto1.asm`

## Repositorio Git

<https://github.com/BlastosMN/Proyecto_1_Arquitectura_Computadores->

## Diagrama de flujo

<https://lucid.app/lucidchart/6f75b672-81e3-4542-8c21-7f1ab4dfd84a/edit?viewport_loc=538%2C-300%2C3310%2C1572%2C0_0&invitationId=inv_0690a6a2-1c42-4167-97b7-1d569b161cd8>

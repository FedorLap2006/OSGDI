; ----------------------------------------------------------------------
; Загружается файл COREBOOT.BIN (не более 608 кб)
; ----------------------------------------------------------------------


        macro   brk { xchg bx, bx }
        org     7c00h

        ; 3 байтный переход
        jmp     near start

; ----------------------------------------------------------------------
; BIOS Parameter Block
; ----------------------------------------------------------------------

        db      'FLOPPY12'      ; 03 Имя
        dw      200h            ; 0B Байт в секторе (512)
        db      1               ; 0D Секторов на кластер
        dw      1               ; 0E Количество резервированных секторов перед началом FAT (1 - бутсектор)
        db      2               ; 10 Количество FAT
        dw      00E0h           ; 11 Количество записей в ROOT Entries (224 x 32 = 1C00h байт), 14 секторов
        dw      0B40h           ; 13 Всего логических секторов (2880)
        db      0F0h            ; 15 Дескриптор медиа (F0h - флоппи-диск)
        dw      9h              ; 16 Секторов на FAT
        dw      12h             ; 18 Секторов на трек
        dw      2h              ; 1A Количество головок
        dd      0               ; 1C Скрытых секторов (large)
        dd      0               ; 20 Всего секторов (large)
        db      0               ; 24 Номер физического устройства
        db      1               ; 25 Флаги
        db      29h             ; 26 Расширенная сигнатура загрузчика
        dd      07E00000h       ; 27 Serial Number, но на самом деле ES:BX
        db      'BOOT    BIN'   ; 2B Метка тома (совпадает с названием запускного файла)
        db      'FAT12   '      ; 36 Тип файловой системы

; ----------------------------------------------------------------------
; Процедура поиск файла в RootEntries (224 файла, 14 секторов)
; ----------------------------------------------------------------------

start:  cli
        cld
        xor     ax, ax
        mov     ds, ax
        mov     es, ax
        mov     ss, ax
        mov     sp, 7C00h
        mov     ax, 19          ; 19-й сектор - начало RootEntries
dir:    les     bx, [7C27h]     ; ES:BX = 7E0h : 0h
        call    ReadSector
        mov     di, bx
        mov     bp, 16          ; 16 элементов в сектое
item:   mov     si, 7C2Bh       ; ds:si метка тома "loader.bin"
        mov     cx, 12
        push    di
        repe    cmpsb
        pop     di
        jcxz    file_found
        add     di, 32
        dec     bp
        jne     item
        inc     ax               ; К следующему сектору
        sub     word [7C11h], 16 ; Всего 14 секторов в Root (16 x 14 = 224)
        jne     dir
        int     18h              ; Выдать сообщение, что нет загрузочных дисков

; ----------------------------------------------------------------------
; Первый кластер начинается с сектора 33 (сектора начинаются с 0)
; ----------------------------------------------------------------------

file_found:

        mov     ax, [es: di + 1Ah]  ; Найти первый кластер
        mov     [7C22h], word 800h
next:   push    ax                  ; Прочесть очередной кластер (1 сектор)
        add     ax, 31              ; 33 - 2
        les     bx, [7C20h]         ; Заполнять c 0800h : 0000h
        call    ReadSector
        add     [7C22h], word 20h   ; + 512
        pop     ax
        mov     bx, 3               ; Каждый элемент занимает 12 бит (3/2 байта)
        mul     bx
        push    ax
        shr     ax, 1 + 9           ; cluster*3/2 -> номер байта / 512 -> номер сектора
        inc     ax                  ; FAT начинается с сектора 1 (второй сектор)
        mov     si, ax
        les     bx, [7C27h]         ; ES:BX = 07E0h : 0000h
        call    ReadSector
        pop     ax
        mov     bp, ax
        mov     di, ax              ; Отыскать указатель на следующий кластер
        shr     di, 1
        and     di, 0x1FF
        mov     ax, [es: di]
        cmp     di, 0x1FF           ; Случай, когда требуется 4/8 бит из следующего сектора
        jne     @f
        push    ax
        xchg    ax, si
        inc     ax
        call    ReadSector
        pop     ax
        mov     ah, [es: bx]
@@:     test    bp, 1               ; Сдвинуто на 4 бита?
        jz      @f
        shr     ax, 4               ; Выровнять из старшего байта >> 4
@@:     and     ax, 0x0FFF          ; Срезать лишние биты
        cmp     ax, 0x0FF0
        jb      next

; ---------------------------------------------------------------------
; Инициализация загрузки kernel именно отсюда
; ---------------------------------------------------------------------

        ; Переход в графический режим из бутсектора
        mov     ax, 0012h        
        int     10h            
                
        ; Загрузка регистра GDT/IDT
        lgdt    [GDTR]      
        lidt    [IDTR] 

        ; Вход в Protected Mode
        mov     eax, cr0
        or      al, 1
        mov     cr0, eax
        jmp     10h : pm        

; ----------------------------------------------------------------------
; Загрузка сектора AX в ES:BX (32 байта)
; ----------------------------------------------------------------------

ReadSector:

        push    ax
        mov     cx, 12h     ; 12h (секторов на треке)
        cwd
        div     cx          ; ax - номер трека, dl - номер сектора
        xchg    ax, cx
        mov     dh, cl
        and     dh, 1       ; Дорожка (Disk Head) = 0..1, TrackNum % 2
        shr     cx, 1
        xchg    ch, cl      ; CH-младший, CL[7:6] - старшие 2 бита
        shl     cl, 6
        inc     dx
        or      cl, dl      ; Номер сектора
        mov     dl, 0       ; disk a:/
        mov     ax, 0201h
        int     13h
        pop     ax
        ret

; ----------------------------------------------------------------------
GDTR:   dw 3*8 - 1                  ; Лимит GDT (размер - 1)
        dq GDT                      ; Линейный адрес GDT 
IDTR:   dw 256*8 - 1                ; Лимит GDT (размер - 1)
        dq 0                        ; Линейный адрес GDT          
GDT:    dw 0,      0,    0,     0   ; 00 NULL-дескриптор
        dw 0FFFFh, 0, 9200h, 00CFh  ; 08 32-битный дескриптор данных
        dw 0FFFFh, 0, 9A00h, 00CFh  ; 10 32-bit код
; ----------------------------------------------------------------------

        use32        
        
        ; Установка сегментов
pm:     mov     ax, 8
        mov     ds, ax
        mov     es, ax
        mov     ss, ax
        mov     fs, ax
        mov     gs, ax

        ; Переход в ОС
        jmp     0010h : 8000h

; ----------------------------------------------------------------------
; ОСТАТОК МЕСТА ЗАПОЛНИТЬ ЗАГЛУШКОЙ
; ----------------------------------------------------------------------

        ; Заполнить FFh
        times 7c00h + (512 - 2) - $ db 255

        ; Сигнатура
        dw 0xAA55

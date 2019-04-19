#!/bin/sh

# sudo mount disk.img -t vfat -o loop,rw,uid="`whoami`",sync,offset=$[1048576] disk
# sudo mount floppy.img -t vfat -o loop,rw,uid="`whoami`",sync,offset=$[0] floppy 
# qemu-system-i386 -drive format=raw,file=disk.img

# Для kernel.c
if (nasm -felf32 -o startup.o startup.asm)
then

# Компиляция ядра -msse -msse2
if (clang -Os -ffreestanding -m32 -march=i386 -mno-sse -c -o kernel.o kernel.c)
then

# Выгрузка бинарного файла :: код располагается в $9000, данные в $180000, стек под данными
if (ld -m elf_i386 -nostdlib -nodefaultlibs --oformat binary -Ttext=0x9000 -Tdata=0x280000 startup.o kernel.o -o kernel.c.bin)
then

# Собрать Loader -- главный загрузчик
if (fasm loader.asm >> /dev/null)
then

# Выгрузка на диск
if (mv loader.bin disk/boot.bin)
then

    # Повтор для floppy-диска
    cp disk/boot.bin floppy/boot.bin

    rm *.o
    rm kernel.c.bin
    #bochs -f c.bxrc -q >> /dev/null 2>&1
    bochs -f a.bxrc -q

fi
fi
fi
fi
fi


#!/bin/sh

# sudo mount floppy.img -t vfat -o loop,rw,uid="`whoami`",sync,offset=$[0] floppy 
# sudo mount disk.img -t vfat -o loop,rw,uid="`whoami`",sync,offset=$[1048576] disk
# qemu-system-i386 -drive format=raw,file=disk.img

# Для kernel.c
if (nasm -felf32 -o startup.o assembly/startup.asm)
then

# Компиляция ядра -msse -msse2
if (clang -Os -ffreestanding -m32 -march=i386 -mno-sse -c -o kernel.o kernel.c)
then

# Выгрузка бинарного файла :: код располагается в $8000, данные в $280000, стек под данными
if (ld -m elf_i386 -nostdlib -nodefaultlibs --oformat binary -Ttext=0x8000 -Tdata=0x280000 startup.o kernel.o -o boot.bin)
then

    cp boot.bin floppy/boot.bin
    cp boot.bin disk/boot.bin

    rm *.o
    rm boot.bin

    bochs -f a.bxrc -q
    #bochs -f c.bxrc -q >> /dev/null 2>&1

fi
fi
fi


#!/bin/bash

# 1. Garante que a raiz está limpa de tentativas anteriores
[ -f Makefile ] && make distclean

# 2. Gera os scripts (usa autogen.sh se existir no repo do pxlib, senão autoreconf)
if [ -f "./autogen.sh" ]; then
    ./autogen.sh
else
    autoreconf -fiv
fi

# 3. Cria a pasta de build isolada e compila
rm -rf build32
mkdir build32 && cd build32

../configure --host=i686-w64-mingw32 --prefix=/c/devprg/pxlib32
make
make install

cd ..
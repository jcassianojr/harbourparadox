#!/bin/bash

# 1. Garante que a raiz está limpa de tentativas anteriores
[ -f Makefile ] && make distclean

# 2. Gera os scripts
if [ -f "./autogen.sh" ]; then
    ./autogen.sh
else
    autoreconf -fiv
fi

# 3. Cria a pasta de build isolada e compila
rm -rf build64
mkdir build64 && cd build64

../configure --host=x86_64-w64-mingw32 --prefix=/c/devprg/pxlib64
make
make install

cd ..
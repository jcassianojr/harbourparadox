#!/bin/bash
# limpar e recopiar pxlib para home/pxlib e andar para cd pxlib

# 1. Limpa compilações e configurações anteriores
make distclean 2>/dev/null || true

# 2. Re-gera o sistema de build
autoreconf -fiv

# 3. Configura e compila diretamente na raiz
./configure --host=x86_64-w64-mingw32 --prefix=/c/devprg/pxlib64
make
make install
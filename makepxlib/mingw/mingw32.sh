#!/bin/bash
# limpar e recopiar  pxlib para home/pxlib e andar para cd pxlib

# 1. Limpa compilações e configurações anteriores
make distclean 2>/dev/null || true

# 2. Re-gera o sistema de build
autoreconf -fiv

# 3. Configura e compila diretamente na raiz
./configure --host=i686-w64-mingw32 --prefix=/c/devprg/pxlib32
make
make install
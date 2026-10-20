@echo off
TITLE Compilando pxlib para 32-bits (MSVC)
color 0B

:: Configura o ambiente do MSVC para 32-bits (x86)
rem CALL "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars32.bat"
call "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\VsDevCmd.bat" -arch=x86

:: Define a pasta de destino final
SET DEST_DIR=C:\devprg\pxlib32

IF NOT EXIST "%DEST_DIR%\include" MKDIR "%DEST_DIR%\include"
IF NOT EXIST "%DEST_DIR%\lib" MKDIR "%DEST_DIR%\lib"
IF NOT EXIST "%DEST_DIR%\bin" MKDIR "%DEST_DIR%\bin"

echo.
echo [1/3] Entrando na pasta src e compilando os fontes para DLL (32-bits)...
CD src

:: Limpa resquícios anteriores na pasta src
DEL /Q *.obj *.ilk *.pdb *.exp *.idb *.manifest sources.txt 2>nul

:: Cria uma lista com todos os arquivos C para evitar erros de linha longa
dir /b *.c > sources.txt

:: Compila usando o arquivo de resposta (@sources.txt), eliminando o limite de tamanho da linha
cl /LD /O2 /std:c11 /D "ssize_t=int" /D "_CRT_SECURE_NO_WARNINGS" /D "NOMINMAX" /FI"stdint.h" /FI"compat.h" @sources.txt /I. /I..\include /Fe:pxlib.dll /link /DEF:..\pxlib.def

if %errorlevel% neq 0 (
    echo.
    echo ERRO na compilacao!
    DEL sources.txt 2>nul
    CD ..
    pause
    exit /b %errorlevel%
)

:: Remove o arquivo temporário de fontes
DEL sources.txt 2>nul

echo.
echo [2/3] Organizando os arquivos para a pasta de destino (%DEST_DIR%)...
MOVE /Y pxlib.dll "%DEST_DIR%\bin\"
MOVE /Y pxlib.lib "%DEST_DIR%\lib\"
MOVE /Y pxlib.exp "%DEST_DIR%\lib\"
COPY /Y ..\include\*.h "%DEST_DIR%\include\"

:: Volta para a pasta raiz
CD ..

echo.
echo ==========================================
echo  Compilacao 32-bits concluida com sucesso!
echo  Destino: %DEST_DIR%
echo ==========================================
pause
@echo off
set "PXLIB_ROOT=C:\harbour\hb3rd\pxlib32"
set "PXLIB_INCLUDE=%PXLIB_ROOT%\include"
set "HB_WITH_PXLIB=yes"

if not exist "%PXLIB_INCLUDE%\paradox.h" (
    echo ERRO: nao foi encontrado "%PXLIB_INCLUDE%\paradox.h".
    exit /b 1
)
if not exist "%PXLIB_ROOT%\bin\pxlib.dll" (
    echo ERRO: nao foi encontrada "%PXLIB_ROOT%\bin\pxlib.dll".
    exit /b 1
)

call D:\devprg\hb\hb32msys.bat
rem if errorlevel 1 exit /b %errorlevel%
call C:\devprg\hb\hb32msys_C.bat
rem if errorlevel 1 exit /b %errorlevel%

hbmk2.exe harbourparadox.hbp
if errorlevel 1 exit /b %errorlevel%

if not exist "%~dp0lib\win\mingw\libpxlib.a" (
    echo ERRO: hbmk2 nao gerou "%~dp0lib\win\mingw\libpxlib.a".
    exit /b 1
)

exit /b 0

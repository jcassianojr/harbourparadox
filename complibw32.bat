@echo off
set "PXLIB_ROOT=C:\harbour\hb3rd\pxlib32"
set "PXLIB_INCLUDE=%PXLIB_ROOT%\include"

if not exist "%PXLIB_INCLUDE%\paradox.h" (
    echo ERRO: nao foi encontrado "%PXLIB_INCLUDE%\paradox.h".
    exit /b 1
)

call D:\devprg\hb\hb32msys.bat
rem if errorlevel 1 exit /b %errorlevel%
call C:\devprg\hb\hb32msys_C.bat
rem if errorlevel 1 exit /b %errorlevel%

hbmk2.exe -I"%PXLIB_INCLUDE%" harbourparadox.hbp
exit /b %errorlevel%

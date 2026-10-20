@echo off
call "%~dp0..\complibw32.bat"
if errorlevel 1 exit /b %errorlevel%

hbmk2.exe testepx.prg "%~dp0..\lib\win\mingw\libpxlib.a" -I.. -I"C:\harbour\hb3rd\pxlib32\include"
exit /b %errorlevel%

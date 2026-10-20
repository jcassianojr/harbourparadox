@echo off
call "%~dp0..\complibw32.bat"
if errorlevel 1 exit /b %errorlevel%

hbmk2.exe pxrddteste.prg pxrdd.prg "%~dp0..\lib\win\mingw\libpxlib.a" -I"C:\harbour\hb3rd\pxlib32\include" -I.. xhb.hbc paradoxpxlib.prg
exit /b %errorlevel%

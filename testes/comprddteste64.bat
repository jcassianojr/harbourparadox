@echo off
call "%~dp0..\complibw64.bat"
if errorlevel 1 exit /b %errorlevel%

hbmk2.exe pxrddteste.prg pxrdd.prg "%~dp0..\lib\win\mingw64\libpxlib.a" -I"C:\harbour\hb3rd\pxlib64\include" -I.. xhb.hbc paradoxpxlib.prg
exit /b %errorlevel%

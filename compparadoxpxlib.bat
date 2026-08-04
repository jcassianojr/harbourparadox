call d:\devprg\hb\hb32msys.bat
call c:\devprg\hb\hb32msys_c.bat
rem hbmk2.exe paradoxpxlib.prg -Ic:\harbour\hb3rd\pxlib\include\ -hblib
REM hbmk2.exe paradoxclasse.prg hbct.hbc -hblib
rem hbmk2.exe paradoxlib01.prg -hblib
rem hbmk2.exe paradoxlib02.prg hbct.hbc -hblib
hbmk2.exe paradoxpxlib.prg paradoxclasse.prg paradoxlib01.prg paradoxlib02.prg -Ic:\harbour\hb3rd\pxlib\include\ -hblib -inc

@echo off
rem chon_firmware.bat <ten> : chon firmware nap vao RAM (copy firmware\<ten>\*.mif -> mem\)
cd /d "%~dp0"
if "%~1"=="" goto usage
if not exist "firmware\%~1\bank0.mif" goto notfound
copy /Y "firmware\%~1\bank0.mif" "mem\bank0.mif" >nul
copy /Y "firmware\%~1\bank1.mif" "mem\bank1.mif" >nul
echo Da chon firmware: %~1
echo Trong Quartus: Processing - Update Memory Initialization File,
echo roi Processing - Start - Start Assembler, sau do nap lai output_files\de2_soc.sof
goto :eof
:usage
echo Cach dung: chon_firmware.bat ^<ten^>   (vi du: chon_firmware.bat board_demo)
echo Cac firmware co san:
dir /b firmware
goto :eof
:notfound
echo Khong tim thay firmware\%~1
dir /b firmware

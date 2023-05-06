@echo off
git diff --cached --name-status | findstr /S /I /C:"@DoNotCommit" *.jai
if %errorLevel% equ 0 exit /B 1
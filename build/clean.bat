@echo off
pushd %~dp0%
setlocal enableExtensions

if exist "..\intermediates"                rmdir /S /Q "..\intermediates"
if exist "..\output"                       rmdir /S /Q "..\output"
if exist "..\vtune"                        rmdir /S /Q "..\vtune"
if exist ".\.build"                        rmdir /S /Q ".\.build"
if exist "..\source\assets\meshes\runtime" rmdir /S /Q "..\source\assets\meshes\runtime"
if exist ".\windows.manifest"              del /AH ".\windows.manifest"

endlocal
popd
exit /B %errorLevel%

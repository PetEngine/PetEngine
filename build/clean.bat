@echo off
pushd %~dp0%
setlocal enableExtensions

if exist "..\intermediates"                rmdir /S /Q "..\intermediates"
if exist "..\output"                       rmdir /S /Q "..\output"
if exist "..\vtune"                        rmdir /S /Q "..\vtune"
if exist ".\.build"                        rmdir /S /Q ".\.build"
if exist "..\source\assets\meshes\runtime" rmdir /S /Q "..\source\assets\meshes\runtime"

endlocal
popd
exit /B %errorLevel%

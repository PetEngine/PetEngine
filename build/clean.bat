@echo off
pushd %~dp0%
setlocal enableExtensions

if exist "..\intermediates"                  rmdir /S /Q "..\intermediates"
if exist "..\output"                         rmdir /S /Q "..\output"
if exist "..\vtune"                          rmdir /S /Q "..\vtune"
if exist ".\.build"                          rmdir /S /Q ".\.build"
if exist "..\source\assets\meshes\runtime"   rmdir /S /Q "..\source\assets\meshes\runtime"
if exist "..\source\assets\textures\runtime" rmdir /S /Q "..\source\assets\textures\runtime"
if exist "..\source\assets\textures\test"    rmdir /S /Q "..\source\assets\textures\test"

endlocal
popd
exit /B %errorLevel%

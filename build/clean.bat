@echo off

setlocal enableExtensions

pushd %~dp0%
    if exist "..\intermediates" rmdir /S /Q "..\intermediates"
    if exist "..\output"        rmdir /S /Q "..\output"
    if exist "..\vtune"         rmdir /S /Q "..\vtune"
    if exist ".\.build"         rmdir /S /Q ".\.build"
popd

exit /B %errorLevel%
endlocal

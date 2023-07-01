@echo off

setlocal enableExtensions

pushd %~dp0%
    if exist "..\output"        rmdir /S /Q "..\output"
    if exist "..\intermediates" rmdir /S /Q "..\intermediates"
    if exist ".\.build"         rmdir /S /Q ".\.build"
popd

exit /B %errorLevel%
endlocal
